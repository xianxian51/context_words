import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../models/batch_append_result.dart';
import '../models/daily_plan_model.dart';
import '../models/plan_generation_result.dart';
import '../models/plan_word_model.dart';
import '../models/word_model.dart';
import '../models/word_selection_mode.dart';

final class DailyPlanRepository {
  DailyPlanRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<DailyPlanModel> create(DailyPlanModel plan) async {
    final database = await _databaseHelper.database;
    final values = plan.toMap(includeId: false)
      ..['created_at'] ??= DateTime.now().toUtc().toIso8601String();
    final id = await database.insert(
      DatabaseSchema.dailyPlansTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return DailyPlanModel.fromMap(<String, Object?>{...values, 'id': id});
  }

  Future<DailyPlanModel?> findById(int id) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.dailyPlansTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : DailyPlanModel.fromMap(rows.first);
  }

  Future<DailyPlanModel?> findByDate(DateTime date) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.dailyPlansTable,
      where: 'date = ?',
      whereArgs: <Object?>[DailyPlanModel.dateKey(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : DailyPlanModel.fromMap(rows.first);
  }

  Future<DailyPlanModel?> getTodayPlan({DateTime? date}) {
    return findByDate(date ?? DateTime.now());
  }

  Future<List<DailyPlanModel>> findAll() async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.dailyPlansTable,
      orderBy: 'date DESC',
    );
    return rows.map(DailyPlanModel.fromMap).toList(growable: false);
  }

  Future<PlanGenerationResult> generateForDate({
    required DateTime date,
    required int requestedCount,
    WordSelectionMode selectionMode = WordSelectionMode.random,
  }) async {
    if (requestedCount < 1) {
      throw ArgumentError.value(requestedCount, 'requestedCount');
    }
    final database = await _databaseHelper.database;
    return database.transaction((transaction) async {
      final dateKey = DailyPlanModel.dateKey(date);
      final existingRows = await transaction.query(
        DatabaseSchema.dailyPlansTable,
        where: 'date = ?',
        whereArgs: <Object?>[dateKey],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        final plan = DailyPlanModel.fromMap(existingRows.first);
        return PlanGenerationResult(
          plan: plan,
          alreadyExisted: true,
          requestedCount: requestedCount,
          actualCount: plan.wordCount,
        );
      }

      final selectedIds = await _selectWordIds(
        transaction,
        requestedCount,
        selectionMode: selectionMode,
      );
      if (selectedIds.isEmpty) {
        return PlanGenerationResult(
          requestedCount: requestedCount,
          actualCount: 0,
        );
      }

      final createdAt = DateTime.now().toUtc().toIso8601String();
      final planId = await transaction
          .insert(DatabaseSchema.dailyPlansTable, <String, Object?>{
            'date': dateKey,
            'word_count': selectedIds.length,
            'status': 'pending',
            'created_at': createdAt,
          });
      final batch = transaction.batch();
      for (final wordId in selectedIds) {
        batch.insert(DatabaseSchema.dailyPlanWordsTable, <String, Object?>{
          'plan_id': planId,
          'word_id': wordId,
          'batch_no': 1,
        });
      }
      await batch.commit(noResult: true);
      return PlanGenerationResult(
        plan: DailyPlanModel(
          id: planId,
          date: date,
          wordCount: selectedIds.length,
          createdAt: DateTime.parse(createdAt),
        ),
        requestedCount: requestedCount,
        actualCount: selectedIds.length,
      );
    });
  }

  Future<BatchAppendResult> appendTodayBatch(
    int count, {
    DateTime? date,
    WordSelectionMode selectionMode = WordSelectionMode.random,
  }) async {
    if (count < 1 || count > 100) {
      throw ArgumentError.value(count, 'count', 'Must be between 1 and 100.');
    }
    final targetDate = date ?? DateTime.now();
    final database = await _databaseHelper.database;
    return database.transaction((transaction) async {
      final dateKey = DailyPlanModel.dateKey(targetDate);
      final planRows = await transaction.query(
        DatabaseSchema.dailyPlansTable,
        where: 'date = ?',
        whereArgs: <Object?>[dateKey],
        limit: 1,
      );
      final existingPlan = planRows.isEmpty
          ? null
          : DailyPlanModel.fromMap(planRows.single);
      final existingPlanId = existingPlan?.id;
      final maxRows = existingPlanId == null
          ? const <Map<String, Object?>>[]
          : await transaction.rawQuery(
              '''
SELECT COALESCE(MAX(batch_no), 0) AS max_batch
FROM ${DatabaseSchema.dailyPlanWordsTable}
WHERE plan_id = ?
''',
              <Object?>[existingPlanId],
            );
      final currentMax = maxRows.isEmpty
          ? 0
          : (maxRows.single['max_batch']! as num).toInt();
      final batchNo = currentMax + 1;

      final selectedIds = await _selectWordIds(
        transaction,
        count,
        selectionMode: selectionMode,
        excludedPlanId: existingPlanId,
      );

      if (selectedIds.isEmpty) {
        final todayTotal = existingPlanId == null
            ? 0
            : await _countPlanWords(transaction, existingPlanId);
        return BatchAppendResult(
          plan: existingPlan,
          batchNo: batchNo,
          addedCount: 0,
          remainingAvailableCount: 0,
          todayTotalWordCount: todayTotal,
        );
      }

      final createdAt = DateTime.now().toUtc().toIso8601String();
      final planId =
          existingPlanId ??
          await transaction.insert(
            DatabaseSchema.dailyPlansTable,
            <String, Object?>{
              'date': dateKey,
              'word_count': 0,
              'status': 'pending',
              'created_at': createdAt,
            },
          );
      final batch = transaction.batch();
      for (final wordId in selectedIds) {
        batch.insert(DatabaseSchema.dailyPlanWordsTable, <String, Object?>{
          'plan_id': planId,
          'word_id': wordId,
          'batch_no': batchNo,
        });
      }
      await batch.commit(noResult: true);
      final todayTotal = await _countPlanWords(transaction, planId);
      await transaction.update(
        DatabaseSchema.dailyPlansTable,
        <String, Object?>{'word_count': todayTotal, 'status': 'pending'},
        where: 'id = ?',
        whereArgs: <Object?>[planId],
      );
      final remainingRows = await transaction.rawQuery('''
SELECT COUNT(*) AS count
FROM ${DatabaseSchema.wordsTable} AS w
WHERE NOT EXISTS (
  SELECT 1 FROM ${DatabaseSchema.dailyPlanWordsTable} AS dpw
  WHERE dpw.word_id = w.id
)
''');
      return BatchAppendResult(
        plan: DailyPlanModel(
          id: planId,
          date: targetDate,
          wordCount: todayTotal,
          status: 'pending',
          createdAt: existingPlan?.createdAt ?? DateTime.parse(createdAt),
        ),
        batchNo: batchNo,
        addedCount: selectedIds.length,
        remainingAvailableCount: (remainingRows.single['count']! as num)
            .toInt(),
        todayTotalWordCount: todayTotal,
      );
    });
  }

  Future<int> getTodayTotalWordCount({DateTime? date}) async {
    final plan = await findByDate(date ?? DateTime.now());
    final planId = plan?.id;
    if (planId == null) {
      return 0;
    }
    final database = await _databaseHelper.database;
    return _countPlanWords(database, planId);
  }

  Future<List<int>> getTodayBatches({DateTime? date}) async {
    final plan = await findByDate(date ?? DateTime.now());
    final planId = plan?.id;
    return planId == null ? const <int>[] : getPlanBatches(planId);
  }

  Future<List<int>> getPlanBatches(int planId) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.dailyPlanWordsTable,
      distinct: true,
      columns: const <String>['batch_no'],
      where: 'plan_id = ?',
      whereArgs: <Object?>[planId],
      orderBy: 'batch_no ASC',
    );
    return rows
        .map((row) => (row['batch_no'] as num?)?.toInt() ?? 1)
        .toList(growable: false);
  }

  Future<int> addWord({
    required int planId,
    required int wordId,
    int batchNo = 1,
    String memoryStatus = 'new',
  }) async {
    if (memoryStatus.trim().isEmpty) {
      throw ArgumentError.value(memoryStatus, 'memoryStatus');
    }

    final database = await _databaseHelper.database;
    return database.insert(
      DatabaseSchema.dailyPlanWordsTable,
      <String, Object?>{
        'plan_id': planId,
        'word_id': wordId,
        'batch_no': batchNo,
        'memory_status': memoryStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<int>> getWordIds(int planId) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.dailyPlanWordsTable,
      columns: const <String>['word_id'],
      where: 'plan_id = ?',
      whereArgs: <Object?>[planId],
      orderBy: 'id ASC',
    );
    return rows
        .map((row) => (row['word_id']! as num).toInt())
        .toList(growable: false);
  }

  Future<List<PlanWordModel>> getPlanWords(int planId) async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery(
      '''
SELECT w.*, dpw.batch_no, dpw.memory_status, dpw.review_count,
       dpw.last_reviewed_at
FROM ${DatabaseSchema.dailyPlanWordsTable} AS dpw
JOIN ${DatabaseSchema.wordsTable} AS w ON w.id = dpw.word_id
WHERE dpw.plan_id = ?
ORDER BY dpw.id ASC
''',
      <Object?>[planId],
    );
    return rows
        .map(
          (row) => PlanWordModel(
            word: WordModel.fromMap(row),
            batchNo: (row['batch_no'] as num?)?.toInt() ?? 1,
            memoryStatus: row['memory_status'] as String? ?? 'new',
            reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
            lastReviewedAt: _parseDate(row['last_reviewed_at']),
          ),
        )
        .toList(growable: false);
  }

  Future<List<PlanWordModel>> getPlanWordsByBatch(
    int planId,
    int batchNo,
  ) async {
    final database = await _databaseHelper.database;
    final rows = await database.rawQuery(
      '''
SELECT w.*, dpw.batch_no, dpw.memory_status, dpw.review_count,
       dpw.last_reviewed_at
FROM ${DatabaseSchema.dailyPlanWordsTable} AS dpw
JOIN ${DatabaseSchema.wordsTable} AS w ON w.id = dpw.word_id
WHERE dpw.plan_id = ? AND dpw.batch_no = ?
ORDER BY dpw.id ASC
''',
      <Object?>[planId, batchNo],
    );
    return rows
        .map(
          (row) => PlanWordModel(
            word: WordModel.fromMap(row),
            batchNo: (row['batch_no'] as num?)?.toInt() ?? 1,
            memoryStatus: row['memory_status'] as String? ?? 'new',
            reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
            lastReviewedAt: _parseDate(row['last_reviewed_at']),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> updateWordProgress({
    required int planId,
    required int wordId,
    int batchNo = 1,
    required String memoryStatus,
    required int reviewCount,
    DateTime? lastReviewedAt,
  }) async {
    final database = await _databaseHelper.database;
    final changed = await database.update(
      DatabaseSchema.dailyPlanWordsTable,
      <String, Object?>{
        'memory_status': memoryStatus,
        'review_count': reviewCount,
        'last_reviewed_at': lastReviewedAt?.toIso8601String(),
      },
      where: 'plan_id = ? AND word_id = ? AND batch_no = ?',
      whereArgs: <Object?>[planId, wordId, batchNo],
    );
    return changed == 1;
  }

  Future<bool> setMemoryStatus({
    required int planId,
    required int wordId,
    int batchNo = 1,
    required String memoryStatus,
  }) async {
    if (!const <String>{
      'known',
      'uncertain',
      'unknown',
    }.contains(memoryStatus)) {
      throw ArgumentError.value(memoryStatus, 'memoryStatus');
    }
    final database = await _databaseHelper.database;
    final changed = await database.rawUpdate(
      '''
UPDATE ${DatabaseSchema.dailyPlanWordsTable}
SET memory_status = ?, review_count = review_count + 1, last_reviewed_at = ?
WHERE plan_id = ? AND word_id = ? AND batch_no = ?
''',
      <Object?>[
        memoryStatus,
        DateTime.now().toUtc().toIso8601String(),
        planId,
        wordId,
        batchNo,
      ],
    );
    return changed == 1;
  }

  Future<void> completeRound({
    required int planId,
    required int round,
    int batchNo = 1,
    int durationSeconds = 0,
  }) async {
    if (round < 1 || round > 3) {
      throw ArgumentError.value(round, 'round');
    }
    final database = await _databaseHelper.database;
    await database.transaction((transaction) async {
      await transaction.insert(
        DatabaseSchema.studyLogsTable,
        <String, Object?>{
          'plan_id': planId,
          'batch_no': batchNo,
          'round': round,
          'completed': 1,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
          'duration_seconds': durationSeconds,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final batchCountRows = await transaction.rawQuery(
        '''
SELECT COUNT(DISTINCT batch_no) AS count
FROM ${DatabaseSchema.dailyPlanWordsTable}
WHERE plan_id = ?
''',
        <Object?>[planId],
      );
      final completedRows = await transaction.rawQuery(
        '''
SELECT COUNT(*) AS count
FROM ${DatabaseSchema.studyLogsTable}
WHERE plan_id = ? AND completed = 1
''',
        <Object?>[planId],
      );
      final batchCount = (batchCountRows.single['count']! as num).toInt();
      final completedCount = (completedRows.single['count']! as num).toInt();
      await transaction.update(
        DatabaseSchema.dailyPlansTable,
        <String, Object?>{
          'status': batchCount > 0 && completedCount >= batchCount * 3
              ? 'completed'
              : 'pending',
        },
        where: 'id = ?',
        whereArgs: <Object?>[planId],
      );
    });
  }

  Future<Set<int>> getCompletedRounds(int planId, {int batchNo = 1}) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.studyLogsTable,
      columns: const <String>['round'],
      where: 'plan_id = ? AND batch_no = ? AND completed = 1',
      whereArgs: <Object?>[planId, batchNo],
    );
    return rows.map((row) => (row['round']! as num).toInt()).toSet();
  }

  Future<Map<int, Set<int>>> getCompletedRoundsByBatch(int planId) async {
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.studyLogsTable,
      columns: const <String>['batch_no', 'round'],
      where: 'plan_id = ? AND completed = 1',
      whereArgs: <Object?>[planId],
      orderBy: 'batch_no ASC, round ASC',
    );
    final result = <int, Set<int>>{};
    for (final row in rows) {
      final batchNo = (row['batch_no'] as num?)?.toInt() ?? 1;
      result
          .putIfAbsent(batchNo, () => <int>{})
          .add((row['round']! as num).toInt());
    }
    return result;
  }

  Future<bool> deleteById(int id) async {
    final database = await _databaseHelper.database;
    final changed = await database.delete(
      DatabaseSchema.dailyPlansTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return changed == 1;
  }

  Future<bool> deleteByDate(DateTime date) async {
    final database = await _databaseHelper.database;
    final changed = await database.delete(
      DatabaseSchema.dailyPlansTable,
      where: 'date = ?',
      whereArgs: <Object?>[DailyPlanModel.dateKey(date)],
    );
    return changed > 0;
  }
}

Future<List<int>> _selectWordIds(
  DatabaseExecutor database,
  int count, {
  required WordSelectionMode selectionMode,
  int? excludedPlanId,
}) async {
  final selectedIds = <int>[];
  final orderBy = selectionMode == WordSelectionMode.random
      ? 'RANDOM()'
      : 'w.id ASC';

  Future<void> addCandidates(String eligibility) async {
    final remaining = count - selectedIds.length;
    if (remaining <= 0) {
      return;
    }
    final conditions = <String>[eligibility];
    final arguments = <Object?>[];
    if (excludedPlanId != null) {
      conditions.add('''
NOT EXISTS (
  SELECT 1 FROM ${DatabaseSchema.dailyPlanWordsTable} AS today_words
  WHERE today_words.plan_id = ? AND today_words.word_id = w.id
)''');
      arguments.add(excludedPlanId);
    }
    if (selectedIds.isNotEmpty) {
      conditions.add(
        'w.id NOT IN (${List<String>.filled(selectedIds.length, '?').join(',')})',
      );
      arguments.addAll(selectedIds);
    }
    arguments.add(remaining);
    final rows = await database.rawQuery('''
SELECT w.id
FROM ${DatabaseSchema.wordsTable} AS w
WHERE ${conditions.join(' AND ')}
ORDER BY $orderBy
LIMIT ?
''', arguments);
    selectedIds.addAll(rows.map((row) => (row['id']! as num).toInt()));
  }

  await addCandidates('''
NOT EXISTS (
  SELECT 1 FROM ${DatabaseSchema.dailyPlanWordsTable} AS history
  WHERE history.word_id = w.id
)''');
  await addCandidates('''
EXISTS (
  SELECT 1 FROM ${DatabaseSchema.dailyPlanWordsTable} AS history
  WHERE history.word_id = w.id
)
AND NOT EXISTS (
  SELECT 1 FROM ${DatabaseSchema.dailyPlanWordsTable} AS mastered
  WHERE mastered.word_id = w.id AND mastered.memory_status = 'known'
)''');
  await addCandidates('1 = 1');

  return selectedIds;
}

Future<int> _countPlanWords(DatabaseExecutor database, int planId) async {
  final rows = await database.rawQuery(
    '''
SELECT COUNT(*) AS count
FROM ${DatabaseSchema.dailyPlanWordsTable}
WHERE plan_id = ?
''',
    <Object?>[planId],
  );
  return (rows.single['count']! as num).toInt();
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
