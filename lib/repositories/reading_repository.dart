import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../models/reading_passage_model.dart';

final class ReadingRepository {
  ReadingRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<ReadingPassageModel> create(ReadingPassageModel passage) async {
    _validateRound(passage.round);
    final database = await _databaseHelper.database;
    final values = passage.toMap(includeId: false)
      ..['created_at'] ??= DateTime.now().toUtc().toIso8601String();
    final id = await database.insert(
      DatabaseSchema.readingPassagesTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return ReadingPassageModel.fromMap(<String, Object?>{...values, 'id': id});
  }

  Future<ReadingPassageModel?> findByPlanAndRound({
    required int planId,
    required int round,
    int batchNo = 1,
  }) async {
    _validateRound(round);
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.readingPassagesTable,
      where: 'plan_id = ? AND batch_no = ? AND round = ?',
      whereArgs: <Object?>[planId, batchNo, round],
      limit: 1,
    );
    return rows.isEmpty ? null : ReadingPassageModel.fromMap(rows.first);
  }

  Future<List<ReadingPassageModel>> findByPlan(int planId) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.readingPassagesTable,
      where: 'plan_id = ?',
      whereArgs: <Object?>[planId],
      orderBy: 'batch_no ASC, round ASC',
    );
    return rows.map(ReadingPassageModel.fromMap).toList(growable: false);
  }

  Future<List<ReadingPassageModel>> findByPlanAndBatch(
    int planId,
    int batchNo,
  ) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.readingPassagesTable,
      where: 'plan_id = ? AND batch_no = ?',
      whereArgs: <Object?>[planId, batchNo],
      orderBy: 'round ASC',
    );
    return rows.map(ReadingPassageModel.fromMap).toList(growable: false);
  }

  Future<bool> update(ReadingPassageModel passage) async {
    final id = passage.id;
    if (id == null) {
      throw ArgumentError('A reading passage id is required for update.');
    }
    _validateRound(passage.round);

    final database = await _databaseHelper.database;
    final changed = await database.update(
      DatabaseSchema.readingPassagesTable,
      passage.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return changed == 1;
  }

  Future<ReadingPassageModel> saveTranslation({
    required int id,
    required String? titleCn,
    required String translationCn,
    required String sentencePairsJson,
    required String keyWordNotesJson,
    required DateTime translatedAt,
  }) async {
    final database = await _databaseHelper.database;
    final changed = await database.update(
      DatabaseSchema.readingPassagesTable,
      <String, Object?>{
        'title_cn': titleCn,
        'translation_cn': translationCn,
        'sentence_pairs_json': sentencePairsJson,
        'key_word_notes_json': keyWordNotesJson,
        'translated_at': translatedAt.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (changed != 1) {
      throw StateError('Reading passage not found.');
    }
    final rows = await database.query(
      DatabaseSchema.readingPassagesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return ReadingPassageModel.fromMap(rows.single);
  }

  Future<bool> deleteById(int id) async {
    final database = await _databaseHelper.database;
    final changed = await database.delete(
      DatabaseSchema.readingPassagesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return changed == 1;
  }

  void _validateRound(int round) {
    if (round != 1 && round != 2) {
      throw ArgumentError.value(round, 'round', 'Must be 1 or 2.');
    }
  }
}
