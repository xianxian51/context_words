import 'dart:convert';
import 'dart:typed_data';

import 'package:context_words/core/services/deepseek_service.dart';
import 'package:context_words/models/deepseek_model.dart';
import 'package:context_words/models/word_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses word detail arrays wrapped in a markdown code fence', () {
    final details = DeepSeekService.parseWordDetails('''
```json
[
  {
    "word": "academic",
    "phonetic": "/academic/",
    "part_of_speech": "adj.",
    "meaning_cn": "学术的",
    "meaning_en": "related to study",
    "example_sentence": "Academic work takes time.",
    "phrase": ["academic work"],
    "synonyms": ["scholarly"]
  }
]
```
''');

    expect(details, hasLength(1));
    expect(details.single.word, 'academic');
    expect(details.single.phrases, <String>['academic work']);
    expect(details.single.synonyms, <String>['scholarly']);
  });

  test('parses a generated passage and rejects incomplete JSON', () {
    final passage = DeepSeekService.parsePassage(
      'Result: {"title":"Campus","content":"A short story.","usedWords":["story"]}',
    );

    expect(passage.title, 'Campus');
    expect(passage.usedWords, <String>['story']);
    expect(
      () => DeepSeekService.parsePassage('{"title":"Missing content"}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('uses dynamic passage length ranges based on target word count', () {
    expect(DeepSeekService.passageLengthRange(1).targetMin, 80);
    expect(DeepSeekService.passageLengthRange(5).targetMax, 150);
    expect(DeepSeekService.passageLengthRange(6).targetMin, 120);
    expect(DeepSeekService.passageLengthRange(15).targetMax, 200);
    expect(DeepSeekService.passageLengthRange(16).targetMin, 160);
    expect(DeepSeekService.passageLengthRange(30).targetMax, 260);
  });

  test('parses a single word object from explanatory text', () {
    final detail = DeepSeekService.parseSingleWord('''
Here is the JSON:
```json
{
  "word": "context",
  "phonetic": "/ˈkɒntekst/",
  "part_of_speech": "n.",
  "meaning_cn": "语境；上下文",
  "meaning_en": "the situation around a word",
  "example_sentence": "Guess the meaning from context.",
  "phrase": ["in context"],
  "synonyms": ["setting"]
}
```
''');

    expect(detail.word, 'context');
    expect(detail.meaningCn, '语境；上下文');
    expect(detail.phrases, <String>['in context']);
  });

  test(
    'parses learning passage translations from JSON fences and text fallback',
    () {
      final parsed = DeepSeekService.parsePassageTranslation('''
说明如下：
```json
{"title_cn":"校园生活","translation_cn":"语境能帮助我们记忆词汇。","sentence_pairs":[{"en":"Context helps memory.","zh":"语境能帮助记忆。"}],"key_word_notes":[{"word":"context","meaning_in_context":"语境","sentence":"Context helps memory."}]}
```
''');
      final fallback = DeepSeekService.parsePassageTranslation(
        '中文标题：练习\n中文翻译：这是一段自然的中文翻译。',
      );

      expect(parsed.titleCn, '校园生活');
      expect(parsed.translationCn, '语境能帮助我们记忆词汇。');
      expect(parsed.sentencePairs.single.en, 'Context helps memory.');
      expect(parsed.keyWordNotes.single.word, 'context');
      expect(fallback.titleCn, '练习');
      expect(fallback.translationCn, '这是一段自然的中文翻译。');
    },
  );

  test('translation prompt requests sentence pairs and key word notes', () {
    const apiKey = 'secret-key-must-stay-out-of-the-prompt';
    final prompt = DeepSeekService.translationPrompt(
      title: 'Campus',
      content: 'Context helps memory.',
      targetWords: const <String>['context'],
    );

    expect(prompt, contains('Campus'));
    expect(prompt, contains('Context helps memory.'));
    expect(prompt, contains('逐句翻译'));
    expect(prompt, contains('sentence_pairs'));
    expect(prompt, contains('key_word_notes'));
    expect(prompt, contains('context'));
    expect(prompt, isNot(contains(apiKey)));
  });

  test('validates confusing-word analysis size before network calls', () {
    expect(
      () => DeepSeekService.validateConfusingWordsForAnalysis(const <WordModel>[
        WordModel(word: 'context'),
      ]),
      throwsA(isA<DeepSeekException>()),
    );

    expect(
      () => DeepSeekService.validateConfusingWordsForAnalysis(
        List<WordModel>.generate(21, (index) => WordModel(word: 'word$index')),
      ),
      throwsA(isA<DeepSeekException>()),
    );
  });

  test('builds confusing-word analysis prompt without API key', () {
    const apiKey = 'secret-token-should-not-appear';
    final prompt =
        DeepSeekService.confusingWordsAnalysisPrompt(const <WordModel>[
          WordModel(word: 'context', meaningCn: '语境'),
          WordModel(word: 'content', meaningCn: '内容'),
        ]);

    expect(prompt, contains('context'));
    expect(prompt, contains('content'));
    expect(prompt, isNot(contains(apiKey)));
    expect(prompt, isNot(contains('小测验')));
  });

  test('sends the selected centralized model in chat requests', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.deepseek.com'))
      ..httpClientAdapter = adapter;
    final service = DeepSeekService(dio: dio);

    await service.testConnection('test-key', model: DeepSeekModel.fast);

    expect(adapter.requestData?['model'], DeepSeekModel.fast.apiName);
  });

  test('maps common DeepSeek HTTP errors to readable messages', () async {
    final cases = <int, String>{
      401: 'API Key 无效',
      402: '余额不足',
      429: '请求太频繁',
      500: '服务繁忙',
    };
    for (final entry in cases.entries) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.deepseek.com'))
        ..httpClientAdapter = _StatusAdapter(entry.key);
      final service = DeepSeekService(dio: dio);

      await expectLater(
        service.testConnection('test-key', model: DeepSeekModel.fast),
        throwsA(
          isA<DeepSeekException>().having(
            (error) => error.message,
            'message',
            contains(entry.value),
          ),
        ),
      );
    }
  });

  test('timeout errors suggest switching v4 pro to v4 flash', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.deepseek.com'))
      ..httpClientAdapter = _ThrowingAdapter(DioExceptionType.receiveTimeout);
    final service = DeepSeekService(dio: dio);

    await expectLater(
      service.testConnection('test-key', model: DeepSeekModel.highQuality),
      throwsA(
        isA<DeepSeekException>().having(
          (error) => error.message,
          'message',
          allOf(contains('响应超时'), contains('deepseek-v4-flash')),
        ),
      ),
    );
  });
}

final class _CaptureAdapter implements HttpClientAdapter {
  Map<String, Object?>? requestData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestData = Map<String, Object?>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode(<String, Object>{
        'choices': <Object>[
          <String, Object>{
            'message': <String, Object>{'content': '{"ok":true}'},
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

final class _StatusAdapter implements HttpClientAdapter {
  const _StatusAdapter(this.statusCode);

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"error":"failed"}',
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _ThrowingAdapter implements HttpClientAdapter {
  const _ThrowingAdapter(this.type);

  final DioExceptionType type;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException(requestOptions: options, type: type);
  }

  @override
  void close({bool force = false}) {}
}
