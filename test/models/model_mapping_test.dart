import 'package:context_words/models/daily_plan_model.dart';
import 'package:context_words/models/reading_passage_model.dart';
import 'package:context_words/models/word_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WordModel', () {
    test('round-trips SQLite values', () {
      final createdAt = DateTime.utc(2026, 6, 15, 8);
      final model = WordModel(
        id: 7,
        word: 'context',
        phonetic: '/ˈkɒntekst/',
        meaningCn: '语境',
        isStarred: true,
        aiGenerated: true,
        createdAt: createdAt,
      );

      final restored = WordModel.fromMap(model.toMap());

      expect(restored.id, 7);
      expect(restored.word, 'context');
      expect(restored.meaningCn, '语境');
      expect(restored.isStarred, isTrue);
      expect(restored.aiGenerated, isTrue);
      expect(restored.createdAt, createdAt);
    });
  });

  group('DailyPlanModel', () {
    test('stores a date as a stable date-only key', () {
      final model = DailyPlanModel(
        id: 2,
        date: DateTime(2026, 6, 15, 23, 59),
        wordCount: 20,
      );

      final map = model.toMap();
      final restored = DailyPlanModel.fromMap(map);

      expect(map['date'], '2026-06-15');
      expect(restored.date, DateTime(2026, 6, 15));
      expect(restored.wordCount, 20);
      expect(restored.status, 'pending');
    });
  });

  group('ReadingPassageModel', () {
    test('encodes and decodes used words as JSON', () {
      const model = ReadingPassageModel(
        id: 3,
        planId: 2,
        round: 1,
        title: 'Morning Context',
        usedWords: <String>['context', 'memory'],
      );

      final restored = ReadingPassageModel.fromMap(model.toMap());

      expect(restored.usedWords, <String>['context', 'memory']);
      expect(restored.round, 1);
    });

    test('rejects malformed used_words data', () {
      expect(
        () => ReadingPassageModel.fromMap(<String, Object?>{
          'plan_id': 2,
          'round': 1,
          'used_words': '{not-json}',
          'ai_generated': 0,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
