import 'package:context_words/core/services/deepseek_service.dart';
import 'package:context_words/models/word_model.dart';
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

  test('parses passage translations from JSON fences and text fallback', () {
    final parsed = DeepSeekService.parsePassageTranslation('''
说明如下：
```json
{"title_cn":"校园生活","translation_cn":"语境能帮助我们记忆词汇。"}
```
''');
    final fallback = DeepSeekService.parsePassageTranslation(
      '中文标题：练习\n中文翻译：这是一段自然的中文翻译。',
    );

    expect(parsed.titleCn, '校园生活');
    expect(parsed.translationCn, '语境能帮助我们记忆词汇。');
    expect(fallback.titleCn, '练习');
    expect(fallback.translationCn, '这是一段自然的中文翻译。');
  });

  test('translation prompt contains passage data but no API key', () {
    const apiKey = 'secret-key-must-stay-out-of-the-prompt';
    final prompt = DeepSeekService.translationPrompt(
      title: 'Campus',
      content: 'Context helps memory.',
    );

    expect(prompt, contains('Campus'));
    expect(prompt, contains('Context helps memory.'));
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
  });
}
