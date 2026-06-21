import 'dart:convert';
import 'dart:typed_data';

import 'package:context_words/models/deepseek_models.dart';
import 'package:context_words/models/daily_plan_model.dart';
import 'package:context_words/core/database/database_helper.dart';
import 'package:context_words/core/services/settings_service.dart';
import 'package:context_words/core/services/deepseek_service.dart';
import 'package:context_words/models/reading_passage_model.dart';
import 'package:context_words/models/word_model.dart';
import 'package:context_words/providers/app_controller.dart';
import 'package:context_words/repositories/daily_plan_repository.dart';
import 'package:context_words/repositories/reading_repository.dart';
import 'package:context_words/repositories/word_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'normalizes usable passages without length or partial-missing warnings',
    () {
      final controller = AppController();

      final normalized = controller.normalizeGeneratedPassageForTesting(
        const GeneratedPassage(
          title: 'Short',
          content: 'Context helps memory.',
          usedWords: <String>[],
        ),
        const <String>['context', 'academic'],
      );

      expect(normalized.usedWords, contains('context'));
      expect(controller.actionMessage, isNull);
    },
  );

  test('rejects passages that contain no target words at all', () {
    final controller = AppController();

    expect(
      () => controller.normalizeGeneratedPassageForTesting(
        const GeneratedPassage(
          title: 'No targets',
          content: 'This passage is readable but misses everything.',
          usedWords: <String>[],
        ),
        const <String>['context'],
      ),
      throwsA(isA<AppException>()),
    );
  });

  test(
    'auto preparation creates one plan and skips readings without API key',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final helper = DatabaseHelper.forTesting(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final words = WordRepository(databaseHelper: helper);
      await words.create(const WordModel(word: 'context'));
      final plans = DailyPlanRepository(databaseHelper: helper);
      final readings = ReadingRepository(databaseHelper: helper);
      final controller = AppController(
        wordRepository: words,
        dailyPlanRepository: plans,
        readingRepository: readings,
        settingsService: SettingsService(),
      );

      await controller.refresh();
      await controller.prepareTodayLearning();
      final firstPlan = controller.todayPlan;
      await controller.prepareTodayLearning();

      expect(firstPlan, isNotNull);
      expect(controller.todayPlan?.id, firstPlan?.id);
      expect(controller.todayWords, hasLength(1));
      expect(await readings.findByPlan(firstPlan!.id!), isEmpty);
      expect(controller.actionMessage, contains('API Key'));
      controller.dispose();
      await helper.close();
    },
  );

  test(
    'auto preparation does not regenerate existing reading rounds',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'deepseek_api_key': 'not-used-because-readings-exist',
      });
      final helper = DatabaseHelper.forTesting(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final words = WordRepository(databaseHelper: helper);
      await words.create(const WordModel(word: 'context'));
      final plans = DailyPlanRepository(databaseHelper: helper);
      final generated = await plans.generateForDate(
        date: DateTime.now(),
        requestedCount: 1,
      );
      final readings = ReadingRepository(databaseHelper: helper);
      for (final round in const <int>[1, 2]) {
        await readings.create(
          ReadingPassageModel(
            planId: generated.plan!.id!,
            round: round,
            title: 'Existing $round',
            content: 'Context remains saved.',
            usedWords: const <String>['context'],
          ),
        );
      }
      final controller = AppController(
        wordRepository: words,
        dailyPlanRepository: plans,
        readingRepository: readings,
        settingsService: SettingsService(),
      );

      await controller.refresh();
      await controller.prepareTodayLearning();

      expect(await readings.findByPlan(generated.plan!.id!), hasLength(2));
      expect(controller.actionMessage, '今日学习已准备好。');
      controller.dispose();
      await helper.close();
    },
  );

  test(
    'collection passage generation enforces word count limits before API calls',
    () async {
      final controller = AppController();
      await expectLater(
        controller.generateCollectionPassage(
          sourceType: 'confusing_group',
          sourceId: 1,
          sourceName: 'too small',
          words: const <WordModel>[WordModel(word: 'context')],
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        controller.generateCollectionPassage(
          sourceType: 'word_book',
          sourceId: 1,
          sourceName: 'too large',
          words: List<WordModel>.generate(
            31,
            (index) => WordModel(word: 'word$index'),
          ),
        ),
        throwsA(isA<AppException>()),
      );
      controller.dispose();
    },
  );

  test(
    'auto preparation and append create only missing batch readings',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'deepseek_api_key': 'test-key',
        'daily_word_count': 2,
      });
      final helper = DatabaseHelper.forTesting(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final words = WordRepository(databaseHelper: helper);
      for (final word in const <String>['alpha', 'beta', 'gamma', 'delta']) {
        await words.create(WordModel(word: word));
      }
      final plans = DailyPlanRepository(databaseHelper: helper);
      final readings = ReadingRepository(databaseHelper: helper);
      final adapter = _PassageAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.deepseek.com'))
        ..httpClientAdapter = adapter;
      final controller = AppController(
        wordRepository: words,
        dailyPlanRepository: plans,
        readingRepository: readings,
        settingsService: SettingsService(),
        deepSeekService: DeepSeekService(dio: dio),
      );

      await controller.refresh();
      await controller.prepareTodayLearning();
      expect(adapter.calls, 2);
      await controller.prepareTodayLearning();
      expect(adapter.calls, 2);

      final planId = controller.todayPlan!.id!;
      final firstBatchPassages = await readings.findByPlanAndBatch(planId, 1);
      final appended = await controller.appendTodayBatch(2);
      final secondBatchPassages = await readings.findByPlanAndBatch(planId, 2);

      expect(appended.batchNo, 2);
      expect(adapter.calls, 4);
      expect(firstBatchPassages, hasLength(2));
      expect(secondBatchPassages, hasLength(2));
      controller.dispose();
      await helper.close();
    },
  );

  test('cached reading translation never calls DeepSeek', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final helper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final plans = DailyPlanRepository(databaseHelper: helper);
    final plan = await plans.create(
      DailyPlanModel(date: DateTime.now(), wordCount: 0),
    );
    final readings = ReadingRepository(databaseHelper: helper);
    final passage = await readings.create(
      ReadingPassageModel(
        planId: plan.id!,
        round: 1,
        content: 'Context helps memory.',
        titleCn: '语境',
        translationCn: '语境帮助记忆。',
      ),
    );
    final adapter = _TranslationAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.deepseek.com'))
      ..httpClientAdapter = adapter;
    final controller = AppController(
      dailyPlanRepository: plans,
      readingRepository: readings,
      settingsService: SettingsService(),
      deepSeekService: DeepSeekService(dio: dio),
    );

    final translation = await controller.translateReadingPassage(passage);

    expect(translation.translationCn, '语境帮助记忆。');
    expect(adapter.calls, 0);
    controller.dispose();
    await helper.close();
  });

  test('new reading translation is requested once and persisted', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'deepseek_api_key': 'test-key',
    });
    final helper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final plans = DailyPlanRepository(databaseHelper: helper);
    final plan = await plans.create(
      DailyPlanModel(date: DateTime.now(), wordCount: 0),
    );
    final readings = ReadingRepository(databaseHelper: helper);
    final passage = await readings.create(
      ReadingPassageModel(
        planId: plan.id!,
        round: 1,
        title: 'Campus',
        content: 'Context helps memory.',
      ),
    );
    final adapter = _TranslationAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.deepseek.com'))
      ..httpClientAdapter = adapter;
    final controller = AppController(
      dailyPlanRepository: plans,
      readingRepository: readings,
      settingsService: SettingsService(),
      deepSeekService: DeepSeekService(dio: dio),
    );

    final translation = await controller.translateReadingPassage(passage);
    final saved = await readings.findByPlanAndRound(planId: plan.id!, round: 1);

    expect(translation.titleCn, '校园');
    expect(saved?.translationCn, '语境帮助记忆。');
    expect(adapter.calls, 1);
    controller.dispose();
    await helper.close();
  });
}

final class _TranslationAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(<String, Object>{
        'choices': <Object>[
          <String, Object>{
            'message': <String, Object>{
              'content': jsonEncode(<String, String>{
                'title_cn': '校园',
                'translation_cn': '语境帮助记忆。',
              }),
            },
          },
        ],
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _PassageAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final passage = jsonEncode(<String, Object>{
      'title': 'Generated $calls',
      'content': 'Alpha beta gamma delta appear naturally in this context.',
      'usedWords': <String>['alpha', 'beta', 'gamma', 'delta'],
    });
    return ResponseBody.fromString(
      jsonEncode(<String, Object>{
        'choices': <Object>[
          <String, Object>{
            'message': <String, Object>{'content': passage},
          },
        ],
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
