import 'package:context_words/core/database/database_helper.dart';
import 'package:context_words/core/services/deepseek_service.dart';
import 'package:context_words/core/services/settings_service.dart';
import 'package:context_words/core/services/word_lookup_service.dart';
import 'package:context_words/models/word_model.dart';
import 'package:context_words/repositories/word_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late WordRepository wordRepository;
  late int deepSeekRequests;
  late WordLookupService service;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'deepseek_api_key': 'test-key',
    });
    databaseHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    wordRepository = WordRepository(databaseHelper: databaseHelper);
    deepSeekRequests = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            deepSeekRequests++;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );
    service = WordLookupService(
      wordRepository: wordRepository,
      settingsService: SettingsService(),
      deepSeekService: DeepSeekService(dio: dio),
    );
  });

  tearDown(() => databaseHelper.close());

  test('returns local words without calling DeepSeek', () async {
    await wordRepository.create(
      const WordModel(word: 'context', meaningCn: '语境'),
    );

    final result = await service.lookupWord(
      'Context,',
      allowRemoteLookup: true,
    );

    expect(result?.meaningCn, '语境');
    expect(deepSeekRequests, 0);
  });

  test('does not call DeepSeek when remote lookup is not allowed', () async {
    final result = await service.lookupWord(
      'unknown',
      allowRemoteLookup: false,
    );

    expect(result, isNull);
    expect(deepSeekRequests, 0);
  });

  test('ignores common short words', () async {
    final result = await service.lookupWord('the', allowRemoteLookup: true);

    expect(result, isNull);
    expect(deepSeekRequests, 0);
  });
}
