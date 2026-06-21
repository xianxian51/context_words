import 'package:flutter/material.dart';

import '../models/word_model.dart';

final class HighlightedPassage extends StatelessWidget {
  const HighlightedPassage({
    required this.content,
    required this.words,
    required this.onWordTap,
    super.key,
  });

  final String content;
  final List<WordModel> words;
  final ValueChanged<WordModel> onWordTap;

  @override
  Widget build(BuildContext context) {
    final byWord = <String, WordModel>{
      for (final word in words) word.word.toLowerCase(): word,
    };
    final alternatives = byWord.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (alternatives.isEmpty) {
      return Text(content, style: Theme.of(context).textTheme.bodyLarge);
    }
    final pattern = alternatives.map(RegExp.escape).join('|');
    final expression = RegExp(
      r'\b(?:' + pattern + r')\b',
      caseSensitive: false,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in expression.allMatches(content)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: content.substring(cursor, match.start)));
      }
      final text = content.substring(match.start, match.end);
      final word = byWord[text.toLowerCase()];
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: word == null ? null : () => onWordTap(word),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < content.length) {
      spans.add(TextSpan(text: content.substring(cursor)));
    }
    return Text.rich(
      TextSpan(children: spans),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8),
    );
  }
}
