import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;

import 'database_schema.dart';

final class DatabaseHelper {
  DatabaseHelper._({
    sqflite.DatabaseFactory? databaseFactory,
    this._databasePath,
  }) : _databaseFactory = databaseFactory ?? sqflite.databaseFactory,
       assert(_databasePath == null || _databasePath != '');

  factory DatabaseHelper.forTesting({
    required sqflite.DatabaseFactory databaseFactory,
    required String databasePath,
  }) {
    return DatabaseHelper._(
      databaseFactory: databaseFactory,
      databasePath: databasePath,
    );
  }

  static final DatabaseHelper instance = DatabaseHelper._();

  final sqflite.DatabaseFactory _databaseFactory;
  final String? _databasePath;

  sqflite.Database? _database;

  Future<sqflite.Database> get database async {
    final openDatabase = _database;
    if (openDatabase != null) {
      return openDatabase;
    }

    final createdDatabase = await _openDatabase();
    _database = createdDatabase;
    return createdDatabase;
  }

  Future<sqflite.Database> _openDatabase() async {
    final resolvedPath =
        _databasePath ??
        path.join(
          await sqflite.getDatabasesPath(),
          DatabaseSchema.databaseName,
        );

    return _databaseFactory.openDatabase(
      resolvedPath,
      options: sqflite.OpenDatabaseOptions(
        version: DatabaseSchema.databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          final batch = database.batch();
          for (final statement in DatabaseSchema.createStatements) {
            batch.execute(statement);
          }
          await batch.commit(noResult: true);
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            final batch = database.batch();
            for (final statement in DatabaseSchema.version2CreateStatements) {
              batch.execute(statement);
            }
            await batch.commit(noResult: true);
          }
          if (oldVersion < 3) {
            await database.execute(DatabaseSchema.addBatchNoToDailyPlanWords);
            await database.execute(
              DatabaseSchema.createDailyPlanWordsBatchIndex,
            );

            await database.execute(DatabaseSchema.renameReadingPassagesV2);
            await database.execute(DatabaseSchema.createReadingPassagesTable);
            await database.execute(DatabaseSchema.copyReadingPassagesFromV2);
            await database.execute(
              DatabaseSchema.createReadingPassagesPlanIndex,
            );

            await database.execute(DatabaseSchema.renameStudyLogsV2);
            await database.execute(DatabaseSchema.createStudyLogsTable);
            await database.execute(DatabaseSchema.copyStudyLogsFromV2);
            await database.execute(DatabaseSchema.createStudyLogsPlanIndex);
          }
          if (oldVersion < 4) {
            for (final statement in DatabaseSchema.version4CreateStatements) {
              await database.execute(statement);
            }
          }
          if (oldVersion < 5) {
            await _addPassageTranslationColumns(database);
          }
          if (oldVersion < 6) {
            await _addColumns(
              database,
              DatabaseSchema.version6LearningTranslationColumns,
            );
          }
        },
      ),
    );
  }

  Future<void> _addPassageTranslationColumns(sqflite.Database database) async {
    await _addColumns(database, DatabaseSchema.version5TranslationColumns);
  }

  Future<void> _addColumns(
    sqflite.Database database,
    Map<String, List<String>> columnsByTable,
  ) async {
    for (final entry in columnsByTable.entries) {
      final existingColumns = (await database.rawQuery(
        'PRAGMA table_info(${entry.key})',
      )).map((row) => row['name']).whereType<String>().toSet();
      for (final column in entry.value) {
        if (!existingColumns.contains(column)) {
          await database.execute(
            'ALTER TABLE ${entry.key} ADD COLUMN $column TEXT',
          );
        }
      }
    }
  }

  Future<void> close() async {
    final openDatabase = _database;
    _database = null;
    await openDatabase?.close();
  }
}
