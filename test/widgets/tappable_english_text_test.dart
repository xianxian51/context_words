import 'package:context_words/widgets/tappable_english_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses English words while preserving punctuation and spaces', () {
    const text = 'Art matters, but article is different.';
    final segments = parseTappableEnglishText(
      text,
      targetWords: const <String>{'art'},
    );

    expect(segments.map((segment) => segment.text).join(), text);
    final art = segments.firstWhere((segment) => segment.text == 'Art');
    final article = segments.firstWhere((segment) => segment.text == 'article');
    final but = segments.firstWhere((segment) => segment.text == 'but');

    expect(art.isWord, isTrue);
    expect(art.isTarget, isTrue);
    expect(art.isClickable, isTrue);
    expect(article.isTarget, isFalse);
    expect(article.isClickable, isTrue);
    expect(but.isIgnored, isTrue);
    expect(but.isClickable, isFalse);
  });
}
