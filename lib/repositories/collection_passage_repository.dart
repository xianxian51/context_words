import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../models/collection_passage_model.dart';

final class CollectionPassageRepository {
  CollectionPassageRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<CollectionPassageModel> create(CollectionPassageModel passage) async {
    _validateSource(passage.sourceType, passage.sourceId);
    final database = await _databaseHelper.database;
    final createdAt = passage.createdAt ?? DateTime.now().toUtc();
    final id = await database.insert(
      DatabaseSchema.collectionPassagesTable,
      passage.toMap(includeId: false)
        ..['created_at'] = createdAt.toIso8601String(),
    );
    return CollectionPassageModel(
      id: id,
      sourceType: passage.sourceType,
      sourceId: passage.sourceId,
      title: passage.title,
      content: passage.content,
      usedWords: passage.usedWords,
      titleCn: passage.titleCn,
      translationCn: passage.translationCn,
      translatedAt: passage.translatedAt,
      createdAt: createdAt,
    );
  }

  Future<CollectionPassageModel> saveTranslation({
    required int id,
    required String? titleCn,
    required String translationCn,
    required DateTime translatedAt,
  }) async {
    final database = await _databaseHelper.database;
    final changed = await database.update(
      DatabaseSchema.collectionPassagesTable,
      <String, Object?>{
        'title_cn': titleCn,
        'translation_cn': translationCn,
        'translated_at': translatedAt.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (changed != 1) {
      throw StateError('Collection passage not found.');
    }
    final rows = await database.query(
      DatabaseSchema.collectionPassagesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return CollectionPassageModel.fromMap(rows.single);
  }

  Future<CollectionPassageModel?> findLatest({
    required String sourceType,
    required int sourceId,
  }) async {
    _validateSource(sourceType, sourceId);
    final database = await _databaseHelper.database;
    final rows = await database.query(
      DatabaseSchema.collectionPassagesTable,
      where: 'source_type = ? AND source_id = ?',
      whereArgs: <Object?>[sourceType, sourceId],
      orderBy: 'created_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : CollectionPassageModel.fromMap(rows.single);
  }

  static void _validateSource(String sourceType, int sourceId) {
    if (sourceType != 'word_book' && sourceType != 'confusing_group') {
      throw ArgumentError.value(sourceType, 'sourceType');
    }
    if (sourceId < 1) {
      throw ArgumentError.value(sourceId, 'sourceId');
    }
  }
}
