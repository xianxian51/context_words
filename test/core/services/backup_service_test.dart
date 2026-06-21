import 'dart:convert';
import 'dart:io';

import 'package:context_words/core/database/database_helper.dart';
import 'package:context_words/core/services/backup_service.dart';
import 'package:context_words/core/services/settings_service.dart';
import 'package:context_words/models/word_model.dart';
import 'package:context_words/models/collection_passage_model.dart';
import 'package:context_words/models/word_selection_mode.dart';
import 'package:context_words/repositories/confusing_word_group_repository.dart';
import 'package:context_words/repositories/collection_passage_repository.dart';
import 'package:context_words/repositories/daily_plan_repository.dart';
import 'package:context_words/repositories/reading_repository.dart';
import 'package:context_words/models/reading_passage_model.dart';
import 'package:context_words/repositories/word_book_repository.dart';
import 'package:context_words/repositories/word_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'deepseek_api_key': 'must-not-be-exported',
    });
  });

  test('exports all learning tables without the DeepSeek API key', () async {
    final database = _testDatabase();
    final helper = database.helper;
    final wordRepository = WordRepository(databaseHelper: helper);
    final word = await wordRepository.create(
      const WordModel(word: 'context', isStarred: true),
    );
    final wordBooks = WordBookRepository(databaseHelper: helper);
    final book = await wordBooks.createWordBook('重点');
    await wordBooks.addWordToBook(book.id!, word.id!);
    await CollectionPassageRepository(databaseHelper: helper).create(
      CollectionPassageModel(
        sourceType: 'word_book',
        sourceId: book.id!,
        content: 'Context in a saved passage.',
        translationCn: '已保存短文中的语境。',
      ),
    );
    await ConfusingWordGroupRepository(
      databaseHelper: helper,
    ).createGroup('易混', <int>[word.id!]);
    final settings = SettingsService();
    await settings.saveDailyWordCount(30);
    await settings.saveWordSelectionMode(WordSelectionMode.sequential);

    final json = await BackupService(
      databaseHelper: helper,
      settingsService: settings,
    ).createBackupJson();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;

    expect(json, isNot(contains('must-not-be-exported')));
    expect(
      decoded['settings'],
      isNot(containsPair('deepseek_api_key', anything)),
    );
    expect(
      tables.keys,
      containsAll(<String>[
        'words',
        'daily_plans',
        'daily_plan_words',
        'reading_passages',
        'study_logs',
        'word_books',
        'word_book_items',
        'confusing_word_groups',
        'confusing_word_group_items',
        'collection_passages',
      ]),
    );
    expect(tables['word_books'], hasLength(1));
    expect(tables['word_book_items'], hasLength(1));
    expect(tables['confusing_word_groups'], hasLength(1));
    expect(tables['confusing_word_group_items'], hasLength(1));
    expect(tables['collection_passages'], hasLength(1));
    expect(
      (tables['collection_passages'] as List).single['translation_cn'],
      '已保存短文中的语境。',
    );
    await helper.close();
    await databaseFactoryFfi.deleteDatabase(database.path);
  });

  test('restores by merging and never clears existing data', () async {
    final sourceDatabase = _testDatabase();
    final sourceHelper = sourceDatabase.helper;
    final sourceWords = WordRepository(databaseHelper: sourceHelper);
    final backupWord = await sourceWords.create(
      const WordModel(
        word: 'context',
        meaningCn: '语境',
        isStarred: true,
        source: 'manual',
      ),
    );
    final sourceBooks = WordBookRepository(databaseHelper: sourceHelper);
    final sourceBook = await sourceBooks.createWordBook('备份词本');
    await sourceBooks.addWordToBook(sourceBook.id!, backupWord.id!);
    await CollectionPassageRepository(databaseHelper: sourceHelper).create(
      CollectionPassageModel(
        sourceType: 'word_book',
        sourceId: sourceBook.id!,
        title: 'Backup passage',
        content: 'Context survives restore.',
        usedWords: const <String>['context'],
        titleCn: '备份短文',
        translationCn: '语境在恢复后仍然存在。',
        translatedAt: DateTime.utc(2026, 6, 20, 10),
      ),
    );
    await ConfusingWordGroupRepository(
      databaseHelper: sourceHelper,
    ).createGroup('备份易混组', <int>[backupWord.id!]);
    final sourcePlans = DailyPlanRepository(databaseHelper: sourceHelper);
    final sourcePlan = await sourcePlans.generateForDate(
      date: DateTime(2026, 6, 20),
      requestedCount: 1,
      selectionMode: WordSelectionMode.sequential,
    );
    await sourcePlans.setMemoryStatus(
      planId: sourcePlan.plan!.id!,
      wordId: backupWord.id!,
      memoryStatus: 'known',
    );
    await sourcePlans.completeRound(planId: sourcePlan.plan!.id!, round: 1);
    await ReadingRepository(databaseHelper: sourceHelper).create(
      ReadingPassageModel(
        planId: sourcePlan.plan!.id!,
        round: 1,
        content: 'Context matters.',
        titleCn: '语境很重要',
        translationCn: '语境很重要。',
        translatedAt: DateTime.utc(2026, 6, 20, 11),
      ),
    );
    final backup = await BackupService(
      databaseHelper: sourceHelper,
    ).createBackupJson();

    final targetDatabase = _testDatabase();
    final targetHelper = targetDatabase.helper;
    final targetWords = WordRepository(databaseHelper: targetHelper);
    await targetWords.create(const WordModel(word: 'existing'));
    await targetWords.create(const WordModel(word: 'context'));
    final result = await BackupService(
      databaseHelper: targetHelper,
    ).restoreBackupJson(backup);

    expect(await targetWords.count(), 2);
    expect((await targetWords.findByWord('existing')), isNotNull);
    expect((await targetWords.findByWord('context'))?.isStarred, isTrue);
    expect(
      await WordBookRepository(databaseHelper: targetHelper).getAllWordBooks(),
      hasLength(1),
    );
    expect(
      await ConfusingWordGroupRepository(
        databaseHelper: targetHelper,
      ).getAllGroups(),
      hasLength(1),
    );
    final restoredBook = (await WordBookRepository(
      databaseHelper: targetHelper,
    ).getAllWordBooks()).single;
    final restoredCollection = await CollectionPassageRepository(
      databaseHelper: targetHelper,
    ).findLatest(sourceType: 'word_book', sourceId: restoredBook.id!);
    expect(restoredCollection?.title, 'Backup passage');
    expect(restoredCollection?.translationCn, '语境在恢复后仍然存在。');
    final restoredPlan = await DailyPlanRepository(
      databaseHelper: targetHelper,
    ).findByDate(DateTime(2026, 6, 20));
    expect(restoredPlan, isNotNull);
    expect(
      (await DailyPlanRepository(
        databaseHelper: targetHelper,
      ).getPlanWords(restoredPlan!.id!)).single.memoryStatus,
      'known',
    );
    expect(
      (await ReadingRepository(
        databaseHelper: targetHelper,
      ).findByPlan(restoredPlan.id!)).single.content,
      'Context matters.',
    );
    expect(
      (await ReadingRepository(
        databaseHelper: targetHelper,
      ).findByPlan(restoredPlan.id!)).single.translationCn,
      '语境很重要。',
    );
    expect(result.insertedRows, greaterThan(0));

    await sourceHelper.close();
    await targetHelper.close();
    await databaseFactoryFfi.deleteDatabase(sourceDatabase.path);
    await databaseFactoryFfi.deleteDatabase(targetDatabase.path);
  });
}

var _databaseCounter = 0;

({DatabaseHelper helper, String path}) _testDatabase() {
  final databasePath =
      '${Directory.systemTemp.path}/context_words_backup_test_${_databaseCounter++}.db';
  return (
    helper: DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    ),
    path: databasePath,
  );
}
