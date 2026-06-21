import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../models/word_model.dart';
import '../models/paged_words_result.dart';
import '../models/wordbook_upgrade_result.dart';

final class WordRepository {
  WordRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<WordModel> create(WordModel word) async {
    final database = await _databaseHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final values = word.toMap(includeId: false)
      ..['created_at'] ??= now
      ..['updated_at'] ??= now;

    final id = await database.insert(
      DatabaseSchema.wordsTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return WordModel.fromMap(<String, Object?>{...values, 'id': id});
  }

  Future<WordModel?> findById(int id) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.wordsTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : WordModel.fromMap(rows.first);
  }

  Future<WordModel?> findByWord(String word) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.wordsTable,
      where: 'word = ? COLLATE NOCASE',
      whereArgs: <Object?>[word.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : WordModel.fromMap(rows.first);
  }

  Future<int> count() async {
    final database = await _databaseHelper.database;
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${DatabaseSchema.wordsTable}',
    );
    return (result.first['count']! as num).toInt();
  }

  Future<List<WordModel>> findMissingDetails() async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.wordsTable,
      where:
          "phonetic IS NULL OR phonetic = '' OR meaning_cn IS NULL OR meaning_cn = '' OR example_sentence IS NULL OR example_sentence = ''",
      orderBy: 'id ASC',
    );
    return rows.map(WordModel.fromMap).toList(growable: false);
  }

  Future<List<WordModel>> findByIds(List<int> ids) async {
    if (ids.isEmpty) {
      return const <WordModel>[];
    }
    final database = await _databaseHelper.database;
    final placeholders = List<String>.filled(ids.length, '?').join(',');
    final rows = await database.rawQuery(
      'SELECT * FROM ${DatabaseSchema.wordsTable} WHERE id IN ($placeholders) ORDER BY id ASC',
      ids,
    );
    return rows.map(WordModel.fromMap).toList(growable: false);
  }

  Future<List<WordModel>> search({
    String query = '',
    bool starredOnly = false,
    int? limit,
    int? offset,
  }) async {
    final result = await searchPaged(
      query: query,
      starredOnly: starredOnly,
      limit: limit,
      offset: offset ?? 0,
    );
    return result.items;
  }

  Future<PagedWordsResult> searchPaged({
    String query = '',
    bool starredOnly = false,
    int? limit = 100,
    int offset = 0,
  }) async {
    final trimmed = query.trim();
    final database = await _databaseHelper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (starredOnly) {
      where.add('is_starred = ?');
      args.add(1);
    }
    if (trimmed.isNotEmpty) {
      where.add('''(
word LIKE ? ESCAPE '\\' COLLATE NOCASE OR
meaning_cn LIKE ? ESCAPE '\\' OR
meaning_en LIKE ? ESCAPE '\\' COLLATE NOCASE OR
part_of_speech LIKE ? ESCAPE '\\' COLLATE NOCASE
)''');
      final pattern = _containsPattern(trimmed);
      args.addAll(<Object?>[pattern, pattern, pattern, pattern]);
    }
    final whereClause = where.isEmpty ? null : where.join(' AND ');
    final countRows = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${DatabaseSchema.wordsTable}'
      '${whereClause == null ? '' : ' WHERE $whereClause'}',
      args,
    );
    final rows = await database.query(
      DatabaseSchema.wordsTable,
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'word COLLATE NOCASE ASC',
      limit: limit,
      offset: limit == null ? null : offset,
    );
    return PagedWordsResult(
      items: rows.map(WordModel.fromMap).toList(growable: false),
      totalCount: (countRows.single['count']! as num).toInt(),
      offset: offset,
    );
  }

  Future<List<WordModel>> findByPrefix(
    String prefix, {
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await searchSimilarWords(
      query: prefix,
      prefixOnly: true,
      limit: limit,
      offset: offset,
    );
    return result.items;
  }

  Future<PagedWordsResult> searchSimilarWords({
    required String query,
    bool prefixOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return const PagedWordsResult(items: <WordModel>[], totalCount: 0);
    }
    final database = await _databaseHelper.database;
    final pattern = prefixOnly
        ? '${_escapeLike(trimmed)}%'
        : _containsPattern(trimmed);
    final condition = prefixOnly
        ? "word LIKE ? ESCAPE '\\' COLLATE NOCASE"
        : '''(
word LIKE ? ESCAPE '\\' COLLATE NOCASE OR
meaning_cn LIKE ? ESCAPE '\\' OR
meaning_en LIKE ? ESCAPE '\\' COLLATE NOCASE
)''';
    final args = prefixOnly
        ? <Object?>[pattern]
        : <Object?>[pattern, pattern, pattern];
    final countRows = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM ${DatabaseSchema.wordsTable} WHERE $condition',
      args,
    );
    final rows = await database.query(
      DatabaseSchema.wordsTable,
      where: condition,
      whereArgs: args,
      orderBy: 'word COLLATE NOCASE ASC',
      limit: limit,
      offset: offset,
    );
    return PagedWordsResult(
      items: rows.map(WordModel.fromMap).toList(growable: false),
      totalCount: (countRows.single['count']! as num).toInt(),
      offset: offset,
    );
  }

  Future<List<WordModel>> findAll({
    bool starredOnly = false,
    int? limit,
    int? offset,
  }) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.wordsTable,
      where: starredOnly ? 'is_starred = ?' : null,
      whereArgs: starredOnly ? const <Object?>[1] : null,
      orderBy: 'word COLLATE NOCASE ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(WordModel.fromMap).toList(growable: false);
  }

  Future<({int imported, int duplicates})> importManySkippingExisting(
    List<WordModel> words,
  ) async {
    if (words.isEmpty) {
      return (imported: 0, duplicates: 0);
    }
    final database = await _databaseHelper.database;
    return database.transaction((transaction) async {
      final normalizedWords = words
          .map((word) => word.word.trim().toLowerCase())
          .where((word) => word.isNotEmpty)
          .toSet();
      final existing = <String>{};
      final all = normalizedWords.toList(growable: false);
      const chunkSize = 500;
      for (var start = 0; start < all.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, all.length);
        final chunk = all.sublist(start, end);
        final placeholders = List<String>.filled(chunk.length, '?').join(',');
        final rows = await transaction.rawQuery(
          'SELECT word FROM ${DatabaseSchema.wordsTable} WHERE lower(word) IN ($placeholders)',
          chunk,
        );
        existing.addAll(
          rows.map((row) => (row['word']! as String).toLowerCase()),
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final batch = transaction.batch();
      var imported = 0;
      for (final word in words) {
        final normalized = word.word.trim().toLowerCase();
        if (normalized.isEmpty || existing.contains(normalized)) {
          continue;
        }
        existing.add(normalized);
        final values = word.toMap(includeId: false)
          ..['created_at'] ??= now
          ..['updated_at'] ??= now;
        batch.insert(DatabaseSchema.wordsTable, values);
        imported++;
      }
      await batch.commit(noResult: true);
      return (imported: imported, duplicates: words.length - imported);
    });
  }

  Future<WordbookUpgradeResult> mergeBuiltinWords(List<WordModel> words) async {
    final uniqueWords = <String, WordModel>{};
    for (final word in words) {
      final normalized = word.word.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        uniqueWords.putIfAbsent(normalized, () => word);
      }
    }
    final database = await _databaseHelper.database;
    return database.transaction((transaction) async {
      final existingByWord = <String, Map<String, Object?>>{};
      final normalizedWords = uniqueWords.keys.toList(growable: false);
      const chunkSize = 500;
      for (var start = 0; start < normalizedWords.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, normalizedWords.length);
        final chunk = normalizedWords.sublist(start, end);
        final placeholders = List<String>.filled(chunk.length, '?').join(',');
        final rows = await transaction.rawQuery(
          'SELECT * FROM ${DatabaseSchema.wordsTable} '
          'WHERE lower(word) IN ($placeholders)',
          chunk,
        );
        for (final row in rows) {
          existingByWord[(row['word']! as String).toLowerCase()] = row;
        }
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final batch = transaction.batch();
      var imported = 0;
      var existing = 0;
      var enrichedFields = 0;
      for (final entry in uniqueWords.entries) {
        final incoming = entry.value;
        final current = existingByWord[entry.key];
        if (current == null) {
          final values = incoming.toMap(includeId: false)
            ..['word'] = entry.key
            ..['created_at'] ??= now
            ..['updated_at'] ??= now;
          batch.insert(DatabaseSchema.wordsTable, values);
          imported++;
          continue;
        }

        existing++;
        final incomingMap = incoming.toMap(includeId: false);
        final updates = <String, Object?>{};
        for (final column in const <String>[
          'phonetic',
          'part_of_speech',
          'meaning_cn',
          'meaning_en',
          'example_sentence',
          'phrase',
          'synonyms',
          'difficulty',
          'source',
        ]) {
          if (_isBlank(current[column]) && !_isBlank(incomingMap[column])) {
            updates[column] = incomingMap[column];
            enrichedFields++;
          }
        }
        if (updates.isNotEmpty) {
          updates['updated_at'] = now;
          batch.update(
            DatabaseSchema.wordsTable,
            updates,
            where: 'id = ?',
            whereArgs: <Object?>[current['id']],
          );
        }
      }
      await batch.commit(noResult: true);
      final countRows = await transaction.rawQuery(
        'SELECT COUNT(*) AS count FROM ${DatabaseSchema.wordsTable}',
      );
      return WordbookUpgradeResult(
        builtinCount: uniqueWords.length,
        imported: imported,
        existing: existing,
        enrichedFields: enrichedFields,
        totalWordCount: (countRows.single['count']! as num).toInt(),
      );
    });
  }

  Future<bool> update(WordModel word) async {
    final id = word.id;
    if (id == null) {
      throw ArgumentError('A word id is required for update.');
    }

    final database = await _databaseHelper.database;
    final values = word.toMap(includeId: false)
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    final changed = await database.update(
      DatabaseSchema.wordsTable,
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return changed == 1;
  }

  Future<bool> setStarred({required int id, required bool isStarred}) async {
    final database = await _databaseHelper.database;
    final changed = await database.update(
      DatabaseSchema.wordsTable,
      <String, Object?>{
        'is_starred': isStarred ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return changed == 1;
  }

  Future<bool> deleteById(int id) async {
    final database = await _databaseHelper.database;
    final changed = await database.delete(
      DatabaseSchema.wordsTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return changed == 1;
  }
}

bool _isBlank(Object? value) {
  return value == null || (value is String && value.trim().isEmpty);
}

String _escapeLike(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('%', '\\%')
    .replaceAll('_', '\\_');

String _containsPattern(String value) => '%${_escapeLike(value)}%';
