import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../models/word_book_model.dart';
import '../models/word_model.dart';

final class WordBookRepository {
  WordBookRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<WordBookModel> createWordBook(
    String name, {
    String? description,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Word book name cannot be empty.');
    }
    final database = await _databaseHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final values = <String, Object?>{
      'name': normalizedName,
      'description': _blankToNull(description),
      'created_at': now,
      'updated_at': now,
    };
    final id = await database.insert(DatabaseSchema.wordBooksTable, values);
    return WordBookModel.fromMap(<String, Object?>{...values, 'id': id});
  }

  Future<bool> updateWordBook(WordBookModel wordBook) async {
    final id = wordBook.id;
    if (id == null) {
      throw ArgumentError('A word book id is required for update.');
    }
    final database = await _databaseHelper.database;
    final changed = await database.update(
      DatabaseSchema.wordBooksTable,
      <String, Object?>{
        'name': wordBook.name.trim(),
        'description': _blankToNull(wordBook.description),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return changed == 1;
  }

  Future<bool> deleteWordBook(int id) async {
    final database = await _databaseHelper.database;
    final changed = await database.delete(
      DatabaseSchema.wordBooksTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return changed == 1;
  }

  Future<List<WordBookModel>> getAllWordBooks() async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery('''
SELECT b.*, COUNT(i.id) AS word_count
FROM ${DatabaseSchema.wordBooksTable} b
LEFT JOIN ${DatabaseSchema.wordBookItemsTable} i
  ON i.word_book_id = b.id
GROUP BY b.id
ORDER BY b.updated_at DESC, b.id DESC
''');
    return rows.map(WordBookModel.fromMap).toList(growable: false);
  }

  Future<WordBookModel?> findById(int id) async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery(
      '''
SELECT b.*, COUNT(i.id) AS word_count
FROM ${DatabaseSchema.wordBooksTable} b
LEFT JOIN ${DatabaseSchema.wordBookItemsTable} i
  ON i.word_book_id = b.id
WHERE b.id = ?
GROUP BY b.id
LIMIT 1
''',
      <Object?>[id],
    );
    return rows.isEmpty ? null : WordBookModel.fromMap(rows.single);
  }

  Future<bool> addWordToBook(int wordBookId, int wordId) async {
    final database = await _databaseHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = await database.insert(
      DatabaseSchema.wordBookItemsTable,
      <String, Object?>{
        'word_book_id': wordBookId,
        'word_id': wordId,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (id > 0) {
      await _touchWordBook(database, wordBookId);
    }
    return id > 0;
  }

  Future<int> addWordsToBook(int wordBookId, List<int> wordIds) async {
    if (wordIds.isEmpty) {
      return 0;
    }
    final database = await _databaseHelper.database;
    return database.transaction((transaction) async {
      final now = DateTime.now().toUtc().toIso8601String();
      var added = 0;
      for (final wordId in wordIds.toSet()) {
        final id = await transaction.insert(
          DatabaseSchema.wordBookItemsTable,
          <String, Object?>{
            'word_book_id': wordBookId,
            'word_id': wordId,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (id > 0) {
          added++;
        }
      }
      if (added > 0) {
        await _touchWordBook(transaction, wordBookId);
      }
      return added;
    });
  }

  Future<bool> removeWordFromBook(int wordBookId, int wordId) async {
    final database = await _databaseHelper.database;
    final changed = await database.delete(
      DatabaseSchema.wordBookItemsTable,
      where: 'word_book_id = ? AND word_id = ?',
      whereArgs: <Object?>[wordBookId, wordId],
    );
    if (changed > 0) {
      await _touchWordBook(database, wordBookId);
    }
    return changed > 0;
  }

  Future<List<WordModel>> getWordsInBook(
    int wordBookId, {
    String query = '',
  }) async {
    final trimmed = query.trim();
    final database = await _databaseHelper.database;
    final where = <String>['i.word_book_id = ?'];
    final args = <Object?>[wordBookId];
    if (trimmed.isNotEmpty) {
      where.add('(w.word LIKE ? COLLATE NOCASE OR w.meaning_cn LIKE ?)');
      args
        ..add('%$trimmed%')
        ..add('%$trimmed%');
    }
    final rows = await database.rawQuery('''
SELECT w.*
FROM ${DatabaseSchema.wordBookItemsTable} i
JOIN ${DatabaseSchema.wordsTable} w ON w.id = i.word_id
WHERE ${where.join(' AND ')}
ORDER BY w.word COLLATE NOCASE ASC
''', args);
    return rows.map(WordModel.fromMap).toList(growable: false);
  }

  Future<List<WordBookModel>> getBooksContainingWord(int wordId) async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery(
      '''
SELECT b.*, COUNT(all_items.id) AS word_count
FROM ${DatabaseSchema.wordBooksTable} b
JOIN ${DatabaseSchema.wordBookItemsTable} target
  ON target.word_book_id = b.id AND target.word_id = ?
LEFT JOIN ${DatabaseSchema.wordBookItemsTable} all_items
  ON all_items.word_book_id = b.id
GROUP BY b.id
ORDER BY b.updated_at DESC, b.id DESC
''',
      <Object?>[wordId],
    );
    return rows.map(WordBookModel.fromMap).toList(growable: false);
  }

  Future<void> _touchWordBook(DatabaseExecutor database, int wordBookId) {
    return database.update(
      DatabaseSchema.wordBooksTable,
      <String, Object?>{'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: <Object?>[wordBookId],
    );
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
