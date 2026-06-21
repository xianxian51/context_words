import 'package:context_words/models/word_model.dart';
import 'package:context_words/widgets/highlighted_passage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('highlights whole target words without matching substrings', (
    tester,
  ) async {
    WordModel? tapped;
    const target = WordModel(word: 'art');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HighlightedPassage(
            content: 'Art matters, but article is a different word.',
            words: const <WordModel>[target],
            onWordTap: (word) => tapped = word,
          ),
        ),
      ),
    );

    expect(find.text('Art'), findsOneWidget);
    expect(find.text('article'), findsNothing);
    await tester.tap(find.text('Art'));
    expect(tapped?.word, 'art');
  });
}
