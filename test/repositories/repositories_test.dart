import 'package:context_words/core/database/database_helper.dart';
import 'package:context_words/core/database/database_schema.dart';
import 'package:context_words/core/services/settings_service.dart';
import 'package:context_words/models/daily_plan_model.dart';
import 'package:context_words/models/collection_passage_model.dart';
import 'package:context_words/models/reading_passage_model.dart';
import 'package:context_words/models/word_model.dart';
import 'package:context_words/models/word_selection_mode.dart';
import 'package:context_words/repositories/confusing_word_group_repository.dart';
import 'package:context_words/repositories/collection_passage_repository.dart';
import 'package:context_words/repositories/daily_plan_repository.dart';
import 'package:context_words/repositories/reading_repository.dart';
import 'package:context_words/repositories/word_book_repository.dart';
import 'package:context_words/repositories/word_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late WordRepository wordRepository;
  late DailyPlanRepository dailyPlanRepository;
  late ReadingRepository readingRepository;
  late WordBookRepository wordBookRepository;
  late ConfusingWordGroupRepository confusingWordGroupRepository;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    databaseHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    wordRepository = WordRepository(databaseHelper: databaseHelper);
    dailyPlanRepository = DailyPlanRepository(databaseHelper: databaseHelper);
    readingRepository = ReadingRepository(databaseHelper: databaseHelper);
    wordBookRepository = WordBookRepository(databaseHelper: databaseHelper);
    confusingWordGroupRepository = ConfusingWordGroupRepository(
      databaseHelper: databaseHelper,
    );
  });

  tearDown(() => databaseHelper.close());

  test('WordRepository creates, finds, and stars a word', () async {
    final created = await wordRepository.create(
      const WordModel(word: 'context', meaningCn: '语境'),
    );

    expect(created.id, isNotNull);
    expect((await wordRepository.findByWord('context'))?.meaningCn, '语境');

    await wordRepository.setStarred(id: created.id!, isStarred: true);
    final starred = await wordRepository.findAll(starredOnly: true);

    expect(starred, hasLength(1));
    expect(starred.single.isStarred, isTrue);
  });

  test(
    'WordRepository imports many words and supports library search',
    () async {
      final result = await wordRepository
          .importManySkippingExisting(const <WordModel>[
            WordModel(word: 'academic', meaningCn: '学术的', difficulty: 'cet6'),
            WordModel(word: 'adequate', meaningCn: '足够的', difficulty: 'cet6'),
            WordModel(word: 'academic', meaningCn: '重复', difficulty: 'cet6'),
          ]);

      expect(result.imported, 2);
      expect(result.duplicates, 1);
      expect(await wordRepository.count(), 2);
      expect(
        (await wordRepository.search(query: '学术')).single.word,
        'academic',
      );

      final adequate = await wordRepository.findByWord('adequate');
      await wordRepository.setStarred(id: adequate!.id!, isStarred: true);
      expect(
        (await wordRepository.search(starredOnly: true)).single.word,
        'adequate',
      );
    },
  );

  test('WordRepository searches all detail fields with pagination', () async {
    await wordRepository.importManySkippingExisting(const <WordModel>[
      WordModel(word: 'academic', meaningCn: '学术的', partOfSpeech: 'adj.'),
      WordModel(word: 'context', meaningEn: 'surrounding situation'),
      WordModel(word: 'memory', meaningCn: '记忆'),
    ]);

    expect((await wordRepository.searchPaged(query: 'academic')).totalCount, 1);
    expect(
      (await wordRepository.searchPaged(query: '学术')).items.single.word,
      'academic',
    );
    expect(
      (await wordRepository.searchPaged(query: 'situation')).items.single.word,
      'context',
    );
    expect(
      (await wordRepository.searchPaged(query: 'adj.')).items.single.word,
      'academic',
    );

    final page = await wordRepository.searchPaged(limit: 2, offset: 0);
    expect(page.items, hasLength(2));
    expect(page.totalCount, 3);
    expect(page.hasMore, isTrue);
  });

  test('WordRepository finds similar words by prefix', () async {
    await wordRepository.importManySkippingExisting(const <WordModel>[
      WordModel(word: 'condition'),
      WordModel(word: 'context'),
      WordModel(word: 'contrast'),
      WordModel(word: 'memory'),
    ]);

    final results = await wordRepository.findByPrefix('con');

    expect(results.map((word) => word.word), <String>[
      'condition',
      'context',
      'contrast',
    ]);
  });

  test('similar word search supports loading more results', () async {
    await wordRepository.importManySkippingExisting(
      List<WordModel>.generate(
        55,
        (index) => WordModel(word: 'con${index.toString().padLeft(2, '0')}'),
      ),
    );

    final first = await wordRepository.searchSimilarWords(
      query: 'con',
      prefixOnly: true,
      limit: 20,
    );
    final second = await wordRepository.searchSimilarWords(
      query: 'con',
      prefixOnly: true,
      limit: 20,
      offset: 20,
    );

    expect(first.totalCount, 55);
    expect(first.items, hasLength(20));
    expect(second.items, hasLength(20));
    expect(
      first.items
          .map((word) => word.id)
          .toSet()
          .intersection(second.items.map((word) => word.id).toSet()),
      isEmpty,
    );
  });

  test(
    'WordBookRepository creates books and prevents duplicate items',
    () async {
      final contextWord = await wordRepository.create(
        const WordModel(word: 'context'),
      );
      final memoryWord = await wordRepository.create(
        const WordModel(word: 'memory'),
      );
      final book = await wordBookRepository.createWordBook(
        '易混词',
        description: '容易混淆的词',
      );

      expect(
        await wordBookRepository.addWordToBook(book.id!, contextWord.id!),
        isTrue,
      );
      expect(
        await wordBookRepository.addWordToBook(book.id!, contextWord.id!),
        isFalse,
      );
      await wordBookRepository.addWordToBook(book.id!, memoryWord.id!);

      final books = await wordBookRepository.getAllWordBooks();
      expect(books.single.wordCount, 2);
      expect(
        (await wordBookRepository.getWordsInBook(
          book.id!,
        )).map((word) => word.word),
        <String>['context', 'memory'],
      );
      expect(
        (await wordBookRepository.getBooksContainingWord(
          contextWord.id!,
        )).single.name,
        '易混词',
      );

      expect(await wordBookRepository.deleteWordBook(book.id!), isTrue);
      expect(await wordBookRepository.getWordsInBook(book.id!), isEmpty);
    },
  );

  test(
    'ConfusingWordGroupRepository creates groups and stores analysis',
    () async {
      final condition = await wordRepository.create(
        const WordModel(word: 'condition'),
      );
      final context = await wordRepository.create(
        const WordModel(word: 'context'),
      );
      final group = await confusingWordGroupRepository.createGroup(
        'con- 易混词',
        <int>[condition.id!, context.id!, condition.id!],
      );

      expect(group.wordCount, 2);
      expect(
        (await confusingWordGroupRepository.getWordsInGroup(
          group.id!,
        )).map((word) => word.word),
        <String>['condition', 'context'],
      );

      expect(
        await confusingWordGroupRepository.saveAnalysis(group.id!, '辨析内容'),
        isTrue,
      );
      expect(
        (await confusingWordGroupRepository.findById(group.id!))?.analysis,
        '辨析内容',
      );

      expect(
        await confusingWordGroupRepository.removeWordFromGroup(
          group.id!,
          context.id!,
        ),
        isTrue,
      );
      expect(await confusingWordGroupRepository.deleteGroup(group.id!), isTrue);
    },
  );

  test(
    'CollectionPassageRepository stores and reads the latest passage',
    () async {
      final repository = CollectionPassageRepository(
        databaseHelper: databaseHelper,
      );
      final book = await wordBookRepository.createWordBook('阅读生词');
      await repository.create(
        CollectionPassageModel(
          sourceType: 'word_book',
          sourceId: book.id!,
          title: 'First',
          content: 'First context.',
          usedWords: const <String>['context'],
          createdAt: DateTime.utc(2026, 6, 20, 8),
        ),
      );
      await repository.create(
        CollectionPassageModel(
          sourceType: 'word_book',
          sourceId: book.id!,
          title: 'Latest',
          content: 'Latest context.',
          usedWords: const <String>['context'],
          createdAt: DateTime.utc(2026, 6, 20, 9),
        ),
      );

      final latest = await repository.findLatest(
        sourceType: 'word_book',
        sourceId: book.id!,
      );
      expect(latest?.title, 'Latest');
      expect(latest?.usedWords, <String>['context']);

      final translated = await repository.saveTranslation(
        id: latest!.id!,
        titleCn: '最新语境',
        translationCn: '最新的语境。',
        translatedAt: DateTime.utc(2026, 6, 20, 10),
      );
      expect(translated.titleCn, '最新语境');
      expect(translated.translationCn, '最新的语境。');

      await repository.create(
        CollectionPassageModel(
          sourceType: 'word_book',
          sourceId: book.id!,
          title: 'Regenerated',
          content: 'A newly generated passage.',
          createdAt: DateTime.utc(2026, 6, 20, 11),
        ),
      );
      final regenerated = await repository.findLatest(
        sourceType: 'word_book',
        sourceId: book.id!,
      );
      expect(regenerated?.title, 'Regenerated');
      expect(regenerated?.translationCn, isNull);
    },
  );

  test('DailyPlanRepository links words and updates review progress', () async {
    final word = await wordRepository.create(const WordModel(word: 'memory'));
    final plan = await dailyPlanRepository.create(
      DailyPlanModel(date: DateTime(2026, 6, 15), wordCount: 1),
    );

    await dailyPlanRepository.addWord(planId: plan.id!, wordId: word.id!);
    expect(await dailyPlanRepository.getWordIds(plan.id!), <int>[word.id!]);

    final reviewedAt = DateTime.utc(2026, 6, 15, 20);
    final updated = await dailyPlanRepository.updateWordProgress(
      planId: plan.id!,
      wordId: word.id!,
      memoryStatus: 'learning',
      reviewCount: 1,
      lastReviewedAt: reviewedAt,
    );
    expect(updated, isTrue);

    final database = await databaseHelper.database;
    final relation = (await database.query(
      DatabaseSchema.dailyPlanWordsTable,
    )).single;
    expect(relation['memory_status'], 'learning');
    expect(relation['review_count'], 1);
    expect(relation['last_reviewed_at'], reviewedAt.toIso8601String());
  });

  test('ReadingRepository stores one passage per plan round', () async {
    final plan = await dailyPlanRepository.create(
      DailyPlanModel(date: DateTime(2026, 6, 15)),
    );
    final created = await readingRepository.create(
      ReadingPassageModel(
        planId: plan.id!,
        round: 1,
        title: 'Morning reading',
        content: 'Context makes vocabulary memorable.',
        usedWords: const <String>['context', 'vocabulary'],
      ),
    );

    final restored = await readingRepository.findByPlanAndRound(
      planId: plan.id!,
      round: 1,
    );

    expect(created.id, isNotNull);
    expect(restored?.title, 'Morning reading');
    expect(restored?.usedWords, <String>['context', 'vocabulary']);

    final translated = await readingRepository.saveTranslation(
      id: created.id!,
      titleCn: '晨读',
      translationCn: '语境让词汇更容易记住。',
      translatedAt: DateTime.utc(2026, 6, 15, 9),
    );
    expect(translated.translationCn, '语境让词汇更容易记住。');
  });

  test(
    'prioritizes unplanned words and fills shortages from review candidates',
    () async {
      await wordRepository.create(const WordModel(word: 'first'));
      await wordRepository.create(const WordModel(word: 'second'));
      await wordRepository.create(const WordModel(word: 'third'));

      final firstDay = await dailyPlanRepository.generateForDate(
        date: DateTime(2026, 6, 15),
        requestedCount: 2,
      );
      final repeated = await dailyPlanRepository.generateForDate(
        date: DateTime(2026, 6, 15),
        requestedCount: 2,
      );
      final firstDayWords = await dailyPlanRepository.getPlanWords(
        firstDay.plan!.id!,
      );
      final unplannedWord = <String>{
        'first',
        'second',
        'third',
      }.difference(firstDayWords.map((item) => item.word.word).toSet()).single;
      final secondDay = await dailyPlanRepository.generateForDate(
        date: DateTime(2026, 6, 16),
        requestedCount: 2,
      );

      expect(firstDay.actualCount, 2);
      expect(repeated.alreadyExisted, isTrue);
      expect(secondDay.actualCount, 2);
      expect(secondDay.hasShortage, isFalse);
      final secondDayWords = await dailyPlanRepository.getPlanWords(
        secondDay.plan!.id!,
      );
      expect(
        secondDayWords.map((item) => item.word.word),
        contains(unplannedWord),
      );
    },
  );

  test('defaults to random selection and keeps the saved plan order', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect(
      await SettingsService().getWordSelectionMode(),
      WordSelectionMode.random,
    );
    expect(await SettingsService().getAutoPrepareDaily(), isTrue);
    expect(await SettingsService().getAutoGenerateReadings(), isTrue);
    await wordRepository.importManySkippingExisting(
      List<WordModel>.generate(
        50,
        (index) =>
            WordModel(word: 'randomword${index.toString().padLeft(2, '0')}'),
      ),
    );

    final generated = await dailyPlanRepository.generateForDate(
      date: DateTime(2026, 6, 19),
      requestedCount: 10,
    );
    final firstRead = await dailyPlanRepository.getPlanWords(
      generated.plan!.id!,
    );
    final secondRead = await dailyPlanRepository.getPlanWords(
      generated.plan!.id!,
    );
    final selected = firstRead.map((item) => item.word.word).toList();

    expect(
      selected,
      isNot(
        List<String>.generate(
          10,
          (index) => 'randomword${index.toString().padLeft(2, '0')}',
        ),
      ),
    );
    expect(secondRead.map((item) => item.word.word).toList(), selected);
  });

  test('sequential selection keeps the original id order', () async {
    await wordRepository.importManySkippingExisting(
      List<WordModel>.generate(
        6,
        (index) => WordModel(word: 'sequenceword$index'),
      ),
    );

    final generated = await dailyPlanRepository.generateForDate(
      date: DateTime(2026, 6, 19),
      requestedCount: 3,
      selectionMode: WordSelectionMode.sequential,
    );
    final words = await dailyPlanRepository.getPlanWords(generated.plan!.id!);

    expect(words.map((item) => item.word.word), <String>[
      'sequenceword0',
      'sequenceword1',
      'sequenceword2',
    ]);
  });

  test('appends batch 2 without changing batch 1 progress', () async {
    await wordRepository.importManySkippingExisting(
      List<WordModel>.generate(
        45,
        (index) => WordModel(word: 'batchword$index'),
      ),
    );
    final date = DateTime(2026, 6, 18);
    final first = await dailyPlanRepository.generateForDate(
      date: date,
      requestedCount: 20,
    );
    final planId = first.plan!.id!;
    final firstBatch = await dailyPlanRepository.getPlanWordsByBatch(planId, 1);
    await dailyPlanRepository.setMemoryStatus(
      planId: planId,
      wordId: firstBatch.first.word.id!,
      batchNo: 1,
      memoryStatus: 'known',
    );

    final appended = await dailyPlanRepository.appendTodayBatch(20, date: date);
    final allWords = await dailyPlanRepository.getPlanWords(planId);
    final firstBatchAfter = await dailyPlanRepository.getPlanWordsByBatch(
      planId,
      1,
    );
    final secondBatch = await dailyPlanRepository.getPlanWordsByBatch(
      planId,
      2,
    );

    expect(appended.batchNo, 2);
    expect(appended.addedCount, 20);
    expect(appended.todayTotalWordCount, 40);
    expect(await dailyPlanRepository.getTodayTotalWordCount(date: date), 40);
    expect(await dailyPlanRepository.getTodayBatches(date: date), <int>[1, 2]);
    expect(firstBatchAfter, hasLength(20));
    expect(firstBatchAfter.first.memoryStatus, 'known');
    expect(secondBatch, hasLength(20));
    expect(allWords.map((item) => item.word.id).toSet(), hasLength(40));
  });

  test('appendTodayBatch uses random selection by default', () async {
    await wordRepository.importManySkippingExisting(
      List<WordModel>.generate(
        60,
        (index) =>
            WordModel(word: 'appendword${index.toString().padLeft(2, '0')}'),
      ),
    );
    final date = DateTime(2026, 6, 20);
    final first = await dailyPlanRepository.generateForDate(
      date: date,
      requestedCount: 10,
      selectionMode: WordSelectionMode.sequential,
    );

    await dailyPlanRepository.appendTodayBatch(10, date: date);
    final secondBatch = await dailyPlanRepository.getPlanWordsByBatch(
      first.plan!.id!,
      2,
    );

    expect(
      secondBatch.map((item) => item.word.word).toList(),
      isNot(
        List<String>.generate(
          10,
          (index) => 'appendword${(index + 10).toString().padLeft(2, '0')}',
        ),
      ),
    );
  });

  test('repeated appends select distinct words for each batch', () async {
    await wordRepository.importManySkippingExisting(
      List<WordModel>.generate(
        9,
        (index) => WordModel(word: 'repeatword$index'),
      ),
    );
    final date = DateTime(2026, 6, 18);
    final first = await dailyPlanRepository.generateForDate(
      date: date,
      requestedCount: 3,
    );
    await dailyPlanRepository.appendTodayBatch(3, date: date);
    await dailyPlanRepository.appendTodayBatch(3, date: date);

    final words = await dailyPlanRepository.getPlanWords(first.plan!.id!);
    expect(words, hasLength(9));
    expect(words.map((item) => item.word.id).toSet(), hasLength(9));
    expect(words.map((item) => item.batchNo).toSet(), <int>{1, 2, 3});
  });

  test('stores reading passages independently for each batch', () async {
    await wordRepository.importManySkippingExisting(const <WordModel>[
      WordModel(word: 'firstbatch'),
      WordModel(word: 'secondbatch'),
    ]);
    final date = DateTime(2026, 6, 18);
    final first = await dailyPlanRepository.generateForDate(
      date: date,
      requestedCount: 1,
    );
    await dailyPlanRepository.appendTodayBatch(1, date: date);
    final planId = first.plan!.id!;
    final batch2Words = await dailyPlanRepository.getPlanWordsByBatch(
      planId,
      2,
    );

    await readingRepository.create(
      ReadingPassageModel(
        planId: planId,
        batchNo: 1,
        round: 1,
        content: 'First batch reading.',
      ),
    );
    await readingRepository.create(
      ReadingPassageModel(
        planId: planId,
        batchNo: 2,
        round: 1,
        content: 'Second batch uses ${batch2Words.single.word.word}.',
        usedWords: <String>[batch2Words.single.word.word],
      ),
    );

    final batch1Passage = await readingRepository.findByPlanAndRound(
      planId: planId,
      batchNo: 1,
      round: 1,
    );
    final batch2Passage = await readingRepository.findByPlanAndRound(
      planId: planId,
      batchNo: 2,
      round: 1,
    );
    expect(batch1Passage?.content, 'First batch reading.');
    expect(batch2Passage?.usedWords, <String>[batch2Words.single.word.word]);
  });

  test('deletes only the requested date so today can be rebuilt', () async {
    await wordRepository.importManySkippingExisting(const <WordModel>[
      WordModel(word: 'first'),
      WordModel(word: 'second'),
      WordModel(word: 'third'),
    ]);

    final today = await dailyPlanRepository.generateForDate(
      date: DateTime(2026, 6, 15),
      requestedCount: 1,
    );
    await readingRepository.create(
      ReadingPassageModel(
        planId: today.plan!.id!,
        round: 1,
        title: 'Old',
        content: 'Old reading.',
      ),
    );
    await dailyPlanRepository.completeRound(planId: today.plan!.id!, round: 1);

    expect(
      await dailyPlanRepository.deleteByDate(DateTime(2026, 6, 15)),
      isTrue,
    );
    final rebuilt = await dailyPlanRepository.generateForDate(
      date: DateTime(2026, 6, 15),
      requestedCount: 2,
    );

    expect(rebuilt.actualCount, 2);
    expect(await readingRepository.findByPlan(rebuilt.plan!.id!), isEmpty);
    expect(
      await dailyPlanRepository.getCompletedRounds(rebuilt.plan!.id!),
      isEmpty,
    );
  });

  test('stores review status and completed learning rounds', () async {
    final word = await wordRepository.create(const WordModel(word: 'review'));
    final plan = await dailyPlanRepository.create(
      DailyPlanModel(date: DateTime(2026, 6, 15), wordCount: 1),
    );
    await dailyPlanRepository.addWord(planId: plan.id!, wordId: word.id!);

    await dailyPlanRepository.setMemoryStatus(
      planId: plan.id!,
      wordId: word.id!,
      memoryStatus: 'uncertain',
    );
    await dailyPlanRepository.completeRound(planId: plan.id!, round: 1);
    await dailyPlanRepository.completeRound(planId: plan.id!, round: 2);
    await dailyPlanRepository.completeRound(planId: plan.id!, round: 3);

    final planWord = (await dailyPlanRepository.getPlanWords(plan.id!)).single;
    expect(planWord.memoryStatus, 'uncertain');
    expect(planWord.reviewCount, 1);
    expect(await dailyPlanRepository.getCompletedRounds(plan.id!), <int>{
      1,
      2,
      3,
    });
    expect((await dailyPlanRepository.findById(plan.id!))?.status, 'completed');
  });

  test('changing daily word count does not clear an existing plan', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await wordRepository.importManySkippingExisting(const <WordModel>[
      WordModel(word: 'settingone'),
      WordModel(word: 'settingtwo'),
    ]);
    final date = DateTime(2026, 6, 18);
    final plan = await dailyPlanRepository.generateForDate(
      date: date,
      requestedCount: 2,
    );

    await SettingsService().saveDailyWordCount(50);

    expect(await SettingsService().getDailyWordCount(), 50);
    expect(
      await dailyPlanRepository.getPlanWords(plan.plan!.id!),
      hasLength(2),
    );
  });
}
