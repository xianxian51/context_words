import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/deepseek_model.dart';
import '../../models/tts_voice_preference.dart';
import '../../models/word_selection_mode.dart';
import '../database/database_helper.dart';
import '../database/database_schema.dart';
import 'settings_service.dart';

final class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class BackupExportResult {
  const BackupExportResult({required this.path, required this.shareOpened});

  final String path;
  final bool shareOpened;
}

final class BackupRestoreResult {
  const BackupRestoreResult({
    required this.insertedRows,
    required this.mergedRows,
  });

  final int insertedRows;
  final int mergedRows;
}

final class BackupService {
  BackupService({
    DatabaseHelper? databaseHelper,
    SettingsService? settingsService,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       _settingsService = settingsService ?? SettingsService();

  static const format = 'context_words_backup';
  static const schemaVersion = 1;
  static const maxImportBytes = 50 * 1024 * 1024;

  static const _tables = <String>[
    DatabaseSchema.wordsTable,
    DatabaseSchema.dailyPlansTable,
    DatabaseSchema.dailyPlanWordsTable,
    DatabaseSchema.readingPassagesTable,
    DatabaseSchema.studyLogsTable,
    DatabaseSchema.wordBooksTable,
    DatabaseSchema.wordBookItemsTable,
    DatabaseSchema.confusingWordGroupsTable,
    DatabaseSchema.confusingWordGroupItemsTable,
    DatabaseSchema.collectionPassagesTable,
  ];

  final DatabaseHelper _databaseHelper;
  final SettingsService _settingsService;

  Future<String> createBackupJson() async {
    final database = await _databaseHelper.database;
    final tables = <String, Object?>{};
    for (final table in _tables) {
      tables[table] = await database.query(table, orderBy: 'id ASC');
    }
    final payload = <String, Object?>{
      'format': format,
      'schema_version': schemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'database_name': DatabaseSchema.databaseName,
      'tables': tables,
      'settings': <String, Object?>{
        'daily_word_count': await _settingsService.getDailyWordCount(),
        'word_selection_mode':
            (await _settingsService.getWordSelectionMode()).storageValue,
        'auto_prepare_daily': await _settingsService.getAutoPrepareDaily(),
        'auto_generate_readings': await _settingsService
            .getAutoGenerateReadings(),
        'deepseek_model': (await _settingsService.getDeepSeekModel()).apiName,
        'check_updates_on_launch': await _settingsService
            .getCheckUpdatesOnLaunch(),
        'tts_voice_preference':
            (await _settingsService.getTtsVoicePreference()).storageValue,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<BackupExportResult> exportAndShare() async {
    final json = await createBackupJson();
    final directory = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(path.join(directory.path, 'backups'));
    await backupDirectory.create(recursive: true);
    final fileName =
        'context_words_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';
    final file = File(path.join(backupDirectory.path, fileName));
    await file.writeAsString(json, flush: true);

    var shareOpened = true;
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: '语境单词本学习数据备份',
          text: '请将此 JSON 备份文件保存到安全位置。',
          files: <XFile>[XFile(file.path)],
        ),
      );
    } catch (_) {
      shareOpened = false;
    }
    return BackupExportResult(path: file.path, shareOpened: shareOpened);
  }

  Future<String?> pickBackupJson() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: '选择语境单词本备份',
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) {
      return null;
    }
    final file = picked.files.single;
    if (file.size > maxImportBytes) {
      throw const BackupException('备份文件过大，最大支持 50 MB。');
    }
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      throw const BackupException('无法读取所选备份文件。');
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const BackupException('备份文件不是有效的 UTF-8 JSON。');
    }
  }

  Future<BackupRestoreResult> restoreBackupJson(String source) async {
    if (utf8.encode(source).length > maxImportBytes) {
      throw const BackupException('备份文件过大，最大支持 50 MB。');
    }
    final root = _decodeRoot(source);
    final tables = root['tables'];
    if (tables is! Map) {
      throw const BackupException('备份缺少 tables 数据。');
    }

    final database = await _databaseHelper.database;
    var insertedRows = 0;
    var mergedRows = 0;
    await database.transaction((transaction) async {
      final wordIds = <int, int>{};
      for (final row in _tableRows(tables, DatabaseSchema.wordsTable)) {
        final oldId = _asInt(row['id']);
        final word = _asString(row['word'])?.trim().toLowerCase();
        if (oldId == null || word == null || !_validWord(word)) {
          continue;
        }
        final existing = await transaction.query(
          DatabaseSchema.wordsTable,
          where: 'word = ? COLLATE NOCASE',
          whereArgs: <Object?>[word],
          limit: 1,
        );
        if (existing.isEmpty) {
          final values = _copyFields(row, _wordFields)..['word'] = word;
          final newId = await transaction.insert(
            DatabaseSchema.wordsTable,
            values,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (newId > 0) {
            wordIds[oldId] = newId;
            insertedRows++;
          }
        } else {
          final current = existing.single;
          final id = _asInt(current['id'])!;
          wordIds[oldId] = id;
          final updates = <String, Object?>{};
          for (final field in _fillableWordFields) {
            if (_isBlank(current[field]) && !_isBlank(row[field])) {
              updates[field] = row[field];
            }
          }
          if (!_asBool(current['is_starred']) && _asBool(row['is_starred'])) {
            updates['is_starred'] = 1;
          }
          if (!_asBool(current['ai_generated']) &&
              _asBool(row['ai_generated'])) {
            updates['ai_generated'] = 1;
          }
          if (updates.isNotEmpty) {
            await transaction.update(
              DatabaseSchema.wordsTable,
              updates,
              where: 'id = ?',
              whereArgs: <Object?>[id],
            );
            mergedRows++;
          }
        }
      }

      final planIds = <int, int>{};
      for (final row in _tableRows(tables, DatabaseSchema.dailyPlansTable)) {
        final oldId = _asInt(row['id']);
        final date = _asString(row['date']);
        if (oldId == null || date == null || !_datePattern.hasMatch(date)) {
          continue;
        }
        final existing = await transaction.query(
          DatabaseSchema.dailyPlansTable,
          where: 'date = ?',
          whereArgs: <Object?>[date],
          limit: 1,
        );
        if (existing.isEmpty) {
          final id = await transaction.insert(
            DatabaseSchema.dailyPlansTable,
            _copyFields(row, _dailyPlanFields),
          );
          planIds[oldId] = id;
          insertedRows++;
        } else {
          final current = existing.single;
          final id = _asInt(current['id'])!;
          planIds[oldId] = id;
          final wordCount = _maxInt(
            _asInt(current['word_count']),
            _asInt(row['word_count']),
          );
          final status =
              current['status'] == 'completed' || row['status'] == 'completed'
              ? 'completed'
              : current['status'] ?? row['status'];
          await transaction.update(
            DatabaseSchema.dailyPlansTable,
            <String, Object?>{'word_count': wordCount, 'status': status},
            where: 'id = ?',
            whereArgs: <Object?>[id],
          );
          mergedRows++;
        }
      }

      for (final row in _tableRows(
        tables,
        DatabaseSchema.dailyPlanWordsTable,
      )) {
        final planId = planIds[_asInt(row['plan_id'])];
        final wordId = wordIds[_asInt(row['word_id'])];
        if (planId == null || wordId == null) {
          continue;
        }
        final existing = await transaction.query(
          DatabaseSchema.dailyPlanWordsTable,
          where: 'plan_id = ? AND word_id = ?',
          whereArgs: <Object?>[planId, wordId],
          limit: 1,
        );
        final values = <String, Object?>{
          'plan_id': planId,
          'word_id': wordId,
          'batch_no': _atLeastOneInt(row['batch_no'], fallback: 1),
          'memory_status': _memoryStatus(row['memory_status']),
          'review_count': _positiveInt(row['review_count'], fallback: 0),
          'last_reviewed_at': row['last_reviewed_at'],
        };
        if (existing.isEmpty) {
          await transaction.insert(DatabaseSchema.dailyPlanWordsTable, values);
          insertedRows++;
        } else if (_shouldUseBackupProgress(existing.single, values)) {
          await transaction.update(
            DatabaseSchema.dailyPlanWordsTable,
            <String, Object?>{
              'memory_status': values['memory_status'],
              'review_count': values['review_count'],
              'last_reviewed_at': values['last_reviewed_at'],
            },
            where: 'id = ?',
            whereArgs: <Object?>[existing.single['id']],
          );
          mergedRows++;
        }
      }

      for (final row in _tableRows(
        tables,
        DatabaseSchema.readingPassagesTable,
      )) {
        final planId = planIds[_asInt(row['plan_id'])];
        final round = _asInt(row['round']);
        if (planId == null || round == null || round < 1 || round > 2) {
          continue;
        }
        final batchNo = _atLeastOneInt(row['batch_no'], fallback: 1);
        final existing = await transaction.query(
          DatabaseSchema.readingPassagesTable,
          where: 'plan_id = ? AND batch_no = ? AND round = ?',
          whereArgs: <Object?>[planId, batchNo, round],
          limit: 1,
        );
        final values = _copyFields(row, _readingFields)
          ..['plan_id'] = planId
          ..['batch_no'] = batchNo
          ..['round'] = round;
        if (existing.isEmpty) {
          await transaction.insert(DatabaseSchema.readingPassagesTable, values);
          insertedRows++;
        } else {
          final updates = _fillBlankValues(existing.single, values);
          if (updates.isNotEmpty) {
            await transaction.update(
              DatabaseSchema.readingPassagesTable,
              updates,
              where: 'id = ?',
              whereArgs: <Object?>[existing.single['id']],
            );
            mergedRows++;
          }
        }
      }

      for (final row in _tableRows(tables, DatabaseSchema.studyLogsTable)) {
        final planId = planIds[_asInt(row['plan_id'])];
        final round = _asInt(row['round']);
        if (planId == null || round == null || round < 1 || round > 3) {
          continue;
        }
        final batchNo = _atLeastOneInt(row['batch_no'], fallback: 1);
        final existing = await transaction.query(
          DatabaseSchema.studyLogsTable,
          where: 'plan_id = ? AND batch_no = ? AND round = ?',
          whereArgs: <Object?>[planId, batchNo, round],
          limit: 1,
        );
        final values = <String, Object?>{
          'plan_id': planId,
          'batch_no': batchNo,
          'round': round,
          'completed': _asBool(row['completed']) ? 1 : 0,
          'completed_at': row['completed_at'],
          'duration_seconds': _positiveInt(
            row['duration_seconds'],
            fallback: 0,
          ),
        };
        if (existing.isEmpty) {
          await transaction.insert(DatabaseSchema.studyLogsTable, values);
          insertedRows++;
        } else {
          final current = existing.single;
          await transaction.update(
            DatabaseSchema.studyLogsTable,
            <String, Object?>{
              'completed':
                  _asBool(current['completed']) || _asBool(values['completed'])
                  ? 1
                  : 0,
              'completed_at': _latestDateString(
                current['completed_at'],
                values['completed_at'],
              ),
              'duration_seconds': _maxInt(
                _asInt(current['duration_seconds']),
                _asInt(values['duration_seconds']),
              ),
            },
            where: 'id = ?',
            whereArgs: <Object?>[current['id']],
          );
          mergedRows++;
        }
      }

      final bookIds = await _restoreNamedParents(
        transaction,
        _tableRows(tables, DatabaseSchema.wordBooksTable),
        table: DatabaseSchema.wordBooksTable,
        titleField: 'name',
        fields: _wordBookFields,
        onInserted: () => insertedRows++,
        onMerged: () => mergedRows++,
      );
      insertedRows += await _restoreLinks(
        transaction,
        _tableRows(tables, DatabaseSchema.wordBookItemsTable),
        table: DatabaseSchema.wordBookItemsTable,
        parentColumn: 'word_book_id',
        parentIds: bookIds,
        wordIds: wordIds,
      );

      final groupIds = await _restoreNamedParents(
        transaction,
        _tableRows(tables, DatabaseSchema.confusingWordGroupsTable),
        table: DatabaseSchema.confusingWordGroupsTable,
        titleField: 'title',
        fields: _confusingGroupFields,
        onInserted: () => insertedRows++,
        onMerged: () => mergedRows++,
      );
      insertedRows += await _restoreLinks(
        transaction,
        _tableRows(tables, DatabaseSchema.confusingWordGroupItemsTable),
        table: DatabaseSchema.confusingWordGroupItemsTable,
        parentColumn: 'group_id',
        parentIds: groupIds,
        wordIds: wordIds,
      );

      for (final row in _tableRows(
        tables,
        DatabaseSchema.collectionPassagesTable,
      )) {
        final sourceType = _asString(row['source_type']);
        final oldSourceId = _asInt(row['source_id']);
        final sourceId = sourceType == 'word_book'
            ? bookIds[oldSourceId]
            : sourceType == 'confusing_group'
            ? groupIds[oldSourceId]
            : null;
        final content = _asString(row['content']);
        if (sourceId == null || content == null || content.trim().isEmpty) {
          continue;
        }
        final existing = await transaction.query(
          DatabaseSchema.collectionPassagesTable,
          where: 'source_type = ? AND source_id = ? AND content = ?',
          whereArgs: <Object?>[sourceType, sourceId, content],
          limit: 1,
        );
        final values = <String, Object?>{
          'source_type': sourceType,
          'source_id': sourceId,
          'title': _asString(row['title']),
          'content': content,
          'used_words': _asString(row['used_words']) ?? '[]',
          'title_cn': _asString(row['title_cn']),
          'translation_cn': _asString(row['translation_cn']),
          'translated_at': _asString(row['translated_at']),
          'created_at':
              _asString(row['created_at']) ??
              DateTime.now().toUtc().toIso8601String(),
        };
        if (existing.isEmpty) {
          await transaction.insert(
            DatabaseSchema.collectionPassagesTable,
            values,
          );
          insertedRows++;
        } else {
          final updates = _fillBlankValues(existing.single, values);
          if (updates.isNotEmpty) {
            await transaction.update(
              DatabaseSchema.collectionPassagesTable,
              updates,
              where: 'id = ?',
              whereArgs: <Object?>[existing.single['id']],
            );
            mergedRows++;
          }
        }
      }
    });

    final settings = root['settings'];
    if (settings is Map) {
      final count = _asInt(settings['daily_word_count']);
      if (count != null && count >= 1 && count <= 100) {
        await _settingsService.saveDailyWordCount(count);
      }
      await _settingsService.saveWordSelectionMode(
        WordSelectionMode.fromStorage(
          _asString(settings['word_selection_mode']),
        ),
      );
      final autoPrepare = settings['auto_prepare_daily'];
      if (autoPrepare is bool) {
        await _settingsService.saveAutoPrepareDaily(autoPrepare);
      }
      final autoReadings = settings['auto_generate_readings'];
      if (autoReadings is bool) {
        await _settingsService.saveAutoGenerateReadings(autoReadings);
      }
      await _settingsService.saveDeepSeekModel(
        DeepSeekModel.fromStorage(_asString(settings['deepseek_model'])),
      );
      final checkUpdates = settings['check_updates_on_launch'];
      if (checkUpdates is bool) {
        await _settingsService.saveCheckUpdatesOnLaunch(checkUpdates);
      }
      final ttsPreference = _asString(settings['tts_voice_preference']);
      if (ttsPreference != null) {
        await _settingsService.saveTtsVoicePreference(
          TtsVoicePreference.fromStorage(ttsPreference),
        );
      }
    }
    return BackupRestoreResult(
      insertedRows: insertedRows,
      mergedRows: mergedRows,
    );
  }

  Map<String, Object?> _decodeRoot(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map || decoded['format'] != format) {
        throw const BackupException('不是语境单词本备份文件。');
      }
      final version = _asInt(decoded['schema_version']);
      if (version == null || version < 1 || version > schemaVersion) {
        throw const BackupException('备份版本不受支持。');
      }
      return decoded.cast<String, Object?>();
    } on BackupException {
      rethrow;
    } on FormatException {
      throw const BackupException('备份 JSON 格式无效。');
    }
  }
}

const _wordFields = <String>{
  'word',
  'phonetic',
  'part_of_speech',
  'meaning_cn',
  'meaning_en',
  'example_sentence',
  'phrase',
  'synonyms',
  'difficulty',
  'source',
  'is_starred',
  'ai_generated',
  'created_at',
  'updated_at',
};
const _fillableWordFields = <String>{
  'phonetic',
  'part_of_speech',
  'meaning_cn',
  'meaning_en',
  'example_sentence',
  'phrase',
  'synonyms',
  'difficulty',
  'source',
  'created_at',
  'updated_at',
};
const _dailyPlanFields = <String>{'date', 'word_count', 'status', 'created_at'};
const _readingFields = <String>{
  'plan_id',
  'batch_no',
  'round',
  'title',
  'content',
  'used_words',
  'title_cn',
  'translation_cn',
  'translated_at',
  'ai_generated',
  'created_at',
};
const _wordBookFields = <String>{
  'name',
  'description',
  'created_at',
  'updated_at',
};
const _confusingGroupFields = <String>{
  'title',
  'description',
  'analysis',
  'created_at',
  'updated_at',
};
final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _wordPattern = RegExp(r"^[a-z][a-z0-9]*(?:[-'][a-z0-9]+)*$");

List<Map<String, Object?>> _tableRows(Map tables, String name) {
  final value = tables[name];
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  return value
      .whereType<Map>()
      .map((row) => row.cast<String, Object?>())
      .toList(growable: false);
}

Map<String, Object?> _copyFields(Map row, Set<String> fields) {
  return <String, Object?>{
    for (final field in fields)
      if (row.containsKey(field) && _isSqlValue(row[field]))
        field: _sqlValue(row[field]),
  };
}

Map<String, Object?> _fillBlankValues(
  Map<String, Object?> current,
  Map<String, Object?> backup,
) {
  return <String, Object?>{
    for (final entry in backup.entries)
      if (!const <String>{'plan_id', 'batch_no', 'round'}.contains(entry.key) &&
          _isBlank(current[entry.key]) &&
          !_isBlank(entry.value))
        entry.key: entry.value,
  };
}

Future<Map<int, int>> _restoreNamedParents(
  DatabaseExecutor database,
  List<Map<String, Object?>> rows, {
  required String table,
  required String titleField,
  required Set<String> fields,
  required void Function() onInserted,
  required void Function() onMerged,
}) async {
  final ids = <int, int>{};
  for (final row in rows) {
    final oldId = _asInt(row['id']);
    final title = _asString(row[titleField])?.trim();
    if (oldId == null || title == null || title.isEmpty || title.length > 200) {
      continue;
    }
    final existing = await database.query(
      table,
      where: '$titleField = ? COLLATE NOCASE',
      whereArgs: <Object?>[title],
      limit: 1,
    );
    final values = _copyFields(row, fields)..[titleField] = title;
    if (existing.isEmpty) {
      final id = await database.insert(table, values);
      ids[oldId] = id;
      onInserted();
    } else {
      final current = existing.single;
      final id = _asInt(current['id'])!;
      ids[oldId] = id;
      final updates = _fillBlankValues(current, values);
      if (updates.isNotEmpty) {
        await database.update(
          table,
          updates,
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        onMerged();
      }
    }
  }
  return ids;
}

Future<int> _restoreLinks(
  DatabaseExecutor database,
  List<Map<String, Object?>> rows, {
  required String table,
  required String parentColumn,
  required Map<int, int> parentIds,
  required Map<int, int> wordIds,
}) async {
  var inserted = 0;
  for (final row in rows) {
    final parentId = parentIds[_asInt(row[parentColumn])];
    final wordId = wordIds[_asInt(row['word_id'])];
    if (parentId == null || wordId == null) {
      continue;
    }
    final id = await database.insert(table, <String, Object?>{
      parentColumn: parentId,
      'word_id': wordId,
      'created_at': row['created_at'],
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    if (id > 0) {
      inserted++;
    }
  }
  return inserted;
}

bool _shouldUseBackupProgress(
  Map<String, Object?> current,
  Map<String, Object?> backup,
) {
  final currentCount = _asInt(current['review_count']) ?? 0;
  final backupCount = _asInt(backup['review_count']) ?? 0;
  if (backupCount != currentCount) {
    return backupCount > currentCount;
  }
  return _isLater(backup['last_reviewed_at'], current['last_reviewed_at']);
}

String _memoryStatus(Object? value) {
  final status = _asString(value);
  return const <String>{'new', 'known', 'uncertain', 'unknown'}.contains(status)
      ? status!
      : 'new';
}

bool _validWord(String word) =>
    word.length <= 100 && _wordPattern.hasMatch(word);

bool _asBool(Object? value) => value == true || value == 1;

int? _asInt(Object? value) => value is num ? value.toInt() : null;

int _positiveInt(Object? value, {required int fallback}) {
  final parsed = _asInt(value);
  return parsed != null && parsed >= 0 ? parsed : fallback;
}

int _atLeastOneInt(Object? value, {required int fallback}) {
  final parsed = _asInt(value);
  return parsed != null && parsed >= 1 ? parsed : fallback;
}

int _maxInt(int? first, int? second) =>
    (first ?? 0) >= (second ?? 0) ? first ?? 0 : second ?? 0;

String? _asString(Object? value) => value is String ? value : null;

bool _isBlank(Object? value) => value == null || value == '';

bool _isSqlValue(Object? value) =>
    value == null || value is String || value is num || value is bool;

Object? _sqlValue(Object? value) => value is bool ? (value ? 1 : 0) : value;

bool _isLater(Object? candidate, Object? current) {
  final candidateDate = candidate is String
      ? DateTime.tryParse(candidate)
      : null;
  final currentDate = current is String ? DateTime.tryParse(current) : null;
  return candidateDate != null &&
      (currentDate == null || candidateDate.isAfter(currentDate));
}

Object? _latestDateString(Object? first, Object? second) {
  return _isLater(second, first) ? second : first ?? second;
}
