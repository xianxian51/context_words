import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../models/confusing_word_group_model.dart';
import '../models/word_model.dart';

final class ConfusingWordGroupRepository {
  ConfusingWordGroupRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<ConfusingWordGroupModel> createGroup(
    String title,
    List<int> wordIds, {
    String? description,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Confusing word group title cannot be empty.');
    }
    final database = await _databaseHelper.database;
    return database.transaction((transaction) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final values = <String, Object?>{
        'title': normalizedTitle,
        'description': _blankToNull(description),
        'analysis': null,
        'created_at': now,
        'updated_at': now,
      };
      final id = await transaction.insert(
        DatabaseSchema.confusingWordGroupsTable,
        values,
      );
      for (final wordId in wordIds.toSet()) {
        await transaction.insert(
          DatabaseSchema.confusingWordGroupItemsTable,
          <String, Object?>{
            'group_id': id,
            'word_id': wordId,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      return ConfusingWordGroupModel.fromMap(<String, Object?>{
        ...values,
        'id': id,
        'word_count': wordIds.toSet().length,
      });
    });
  }

  Future<bool> addWordToGroup(int groupId, int wordId) async {
    final database = await _databaseHelper.database;
    final id = await database.insert(
      DatabaseSchema.confusingWordGroupItemsTable,
      <String, Object?>{
        'group_id': groupId,
        'word_id': wordId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (id > 0) {
      await _touchGroup(database, groupId);
    }
    return id > 0;
  }

  Future<bool> removeWordFromGroup(int groupId, int wordId) async {
    final database = await _databaseHelper.database;
    final changed = await database.delete(
      DatabaseSchema.confusingWordGroupItemsTable,
      where: 'group_id = ? AND word_id = ?',
      whereArgs: <Object?>[groupId, wordId],
    );
    if (changed > 0) {
      await _touchGroup(database, groupId);
    }
    return changed > 0;
  }

  Future<List<ConfusingWordGroupModel>> getAllGroups() async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery('''
SELECT g.*, COUNT(i.id) AS word_count
FROM ${DatabaseSchema.confusingWordGroupsTable} g
LEFT JOIN ${DatabaseSchema.confusingWordGroupItemsTable} i
  ON i.group_id = g.id
GROUP BY g.id
ORDER BY g.updated_at DESC, g.id DESC
''');
    return rows.map(ConfusingWordGroupModel.fromMap).toList(growable: false);
  }

  Future<ConfusingWordGroupModel?> findById(int id) async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery(
      '''
SELECT g.*, COUNT(i.id) AS word_count
FROM ${DatabaseSchema.confusingWordGroupsTable} g
LEFT JOIN ${DatabaseSchema.confusingWordGroupItemsTable} i
  ON i.group_id = g.id
WHERE g.id = ?
GROUP BY g.id
LIMIT 1
''',
      <Object?>[id],
    );
    return rows.isEmpty ? null : ConfusingWordGroupModel.fromMap(rows.single);
  }

  Future<List<WordModel>> getWordsInGroup(int groupId) async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery(
      '''
SELECT w.*
FROM ${DatabaseSchema.confusingWordGroupItemsTable} i
JOIN ${DatabaseSchema.wordsTable} w ON w.id = i.word_id
WHERE i.group_id = ?
ORDER BY w.word COLLATE NOCASE ASC
''',
      <Object?>[groupId],
    );
    return rows.map(WordModel.fromMap).toList(growable: false);
  }

  Future<bool> saveAnalysis(int groupId, String analysis) async {
    final database = await _databaseHelper.database;
    final changed = await database.update(
      DatabaseSchema.confusingWordGroupsTable,
      <String, Object?>{
        'analysis': analysis.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[groupId],
    );
    return changed == 1;
  }

  Future<bool> deleteGroup(int groupId) async {
    final database = await _databaseHelper.database;
    final changed = await database.delete(
      DatabaseSchema.confusingWordGroupsTable,
      where: 'id = ?',
      whereArgs: <Object?>[groupId],
    );
    return changed == 1;
  }

  Future<void> _touchGroup(DatabaseExecutor database, int groupId) {
    return database.update(
      DatabaseSchema.confusingWordGroupsTable,
      <String, Object?>{'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: <Object?>[groupId],
    );
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
