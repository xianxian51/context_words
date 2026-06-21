import 'dart:io';

import 'package:context_words/core/database/database_helper.dart';
import 'package:context_words/core/database/database_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    databaseHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    database = await databaseHelper.database;
  });

  tearDown(() => databaseHelper.close());

  test('creates learning, word book, and confusing-word tables', () async {
    final rows = await database.query(
      'sqlite_master',
      columns: const <String>['name'],
      where: 'type = ?',
      whereArgs: const <Object?>['table'],
    );
    final tableNames = rows.map((row) => row['name']).toSet();

    expect(
      tableNames,
      containsAll(<String>{
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
      }),
    );

    final foreignKeys = await database.rawQuery('PRAGMA foreign_keys');
    expect(foreignKeys.single.values.single, 1);
  });

  test('applies word defaults and enforces unique words', () async {
    await database.insert(DatabaseSchema.wordsTable, <String, Object?>{
      'word': 'context',
    });
    final row = (await database.query(DatabaseSchema.wordsTable)).single;

    expect(row['is_starred'], 0);
    expect(row['ai_generated'], 0);

    expect(
      () => database.insert(DatabaseSchema.wordsTable, <String, Object?>{
        'word': 'context',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('rejects daily plan word rows without valid parents', () async {
    expect(
      () => database.insert(
        DatabaseSchema.dailyPlanWordsTable,
        <String, Object?>{'plan_id': 99, 'word_id': 88},
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('migrates version 2 learning data into batch 1', () async {
    final databasePath =
        '${Directory.systemTemp.path}/context_words_v2_${DateTime.now().microsecondsSinceEpoch}.db';
    final oldDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: (database, version) async {
          await database.execute(DatabaseSchema.createWordsTable);
          await database.execute(DatabaseSchema.createDailyPlansTable);
          await database.execute('''
CREATE TABLE daily_plan_words (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  word_id INTEGER NOT NULL,
  memory_status TEXT NOT NULL DEFAULT 'new',
  review_count INTEGER NOT NULL DEFAULT 0,
  last_reviewed_at TEXT,
  FOREIGN KEY (plan_id) REFERENCES daily_plans (id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES words (id) ON DELETE CASCADE,
  UNIQUE (plan_id, word_id)
)
''');
          await database.execute('''
CREATE TABLE reading_passages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  round INTEGER NOT NULL,
  title TEXT,
  content TEXT,
  used_words TEXT,
  ai_generated INTEGER NOT NULL DEFAULT 0,
  created_at TEXT,
  FOREIGN KEY (plan_id) REFERENCES daily_plans (id) ON DELETE CASCADE,
  UNIQUE (plan_id, round)
)
''');
          await database.execute('''
CREATE TABLE study_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  round INTEGER NOT NULL,
  completed INTEGER NOT NULL DEFAULT 0,
  completed_at TEXT,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (plan_id) REFERENCES daily_plans (id) ON DELETE CASCADE,
  UNIQUE (plan_id, round)
)
''');
          await database.execute(
            'CREATE INDEX idx_reading_passages_plan_id '
            'ON reading_passages (plan_id)',
          );
          await database.execute(
            'CREATE INDEX idx_study_logs_plan_id ON study_logs (plan_id)',
          );
          for (final statement in DatabaseSchema.version2CreateStatements) {
            await database.execute(statement);
          }
        },
      ),
    );
    final wordId = await oldDatabase.insert(DatabaseSchema.wordsTable, {
      'word': 'legacy',
    });
    final planId = await oldDatabase.insert(DatabaseSchema.dailyPlansTable, {
      'date': '2026-06-17',
      'word_count': 1,
      'status': 'pending',
    });
    await oldDatabase.insert(DatabaseSchema.dailyPlanWordsTable, {
      'plan_id': planId,
      'word_id': wordId,
      'memory_status': 'known',
    });
    await oldDatabase.insert(DatabaseSchema.readingPassagesTable, {
      'plan_id': planId,
      'round': 1,
      'content': 'Legacy passage.',
      'used_words': '[]',
    });
    await oldDatabase.insert(DatabaseSchema.studyLogsTable, {
      'plan_id': planId,
      'round': 1,
      'completed': 1,
    });
    await oldDatabase.close();

    final migratingHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final migrated = await migratingHelper.database;

    expect(
      (await migrated.query(
        DatabaseSchema.dailyPlanWordsTable,
      )).single['batch_no'],
      1,
    );
    expect(
      (await migrated.query(
        DatabaseSchema.readingPassagesTable,
      )).single['batch_no'],
      1,
    );
    expect(
      (await migrated.query(DatabaseSchema.studyLogsTable)).single['batch_no'],
      1,
    );
    expect(
      (await migrated.query(
        DatabaseSchema.readingPassagesTable,
      )).single['content'],
      'Legacy passage.',
    );
    expect(
      (await migrated.query(
        DatabaseSchema.dailyPlanWordsTable,
      )).single['memory_status'],
      'known',
    );
    final migratedTables = await migrated.query(
      'sqlite_master',
      columns: const <String>['name'],
      where: 'type = ?',
      whereArgs: const <Object?>['table'],
    );
    expect(
      migratedTables.map((row) => row['name']),
      containsAll(<String>[
        'reading_passages_v2_backup',
        'study_logs_v2_backup',
      ]),
    );

    await migratingHelper.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
  });

  test('migrates version 4 passages without losing existing content', () async {
    final databasePath =
        '${Directory.systemTemp.path}/context_words_v4_${DateTime.now().microsecondsSinceEpoch}.db';
    final oldDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (database, version) async {
          await database.execute('''
CREATE TABLE reading_passages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  batch_no INTEGER NOT NULL DEFAULT 1,
  round INTEGER NOT NULL,
  title TEXT,
  content TEXT,
  used_words TEXT,
  ai_generated INTEGER NOT NULL DEFAULT 0,
  created_at TEXT
)
''');
          await database.execute('''
CREATE TABLE collection_passages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_type TEXT NOT NULL,
  source_id INTEGER NOT NULL,
  title TEXT,
  content TEXT,
  used_words TEXT,
  created_at TEXT NOT NULL
)
''');
        },
      ),
    );
    await oldDatabase.insert(DatabaseSchema.readingPassagesTable, {
      'plan_id': 1,
      'round': 1,
      'content': 'Legacy daily passage.',
    });
    await oldDatabase.insert(DatabaseSchema.collectionPassagesTable, {
      'source_type': 'word_book',
      'source_id': 1,
      'content': 'Legacy collection passage.',
      'created_at': DateTime.utc(2026, 6, 20).toIso8601String(),
    });
    await oldDatabase.close();

    final migratingHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final migrated = await migratingHelper.database;
    final daily = (await migrated.query(
      DatabaseSchema.readingPassagesTable,
    )).single;
    final collection = (await migrated.query(
      DatabaseSchema.collectionPassagesTable,
    )).single;

    expect(daily['content'], 'Legacy daily passage.');
    expect(daily['translation_cn'], isNull);
    expect(collection['content'], 'Legacy collection passage.');
    expect(collection['translation_cn'], isNull);

    await migratingHelper.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
  });
}
