import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/word_lookup_service.dart';
import '../models/word_model.dart';
import '../providers/app_controller.dart';
import 'app_snack_bar.dart';

typedef WordResolvedCallback =
    FutureOr<void> Function(BuildContext context, WordModel word);

final class TappableEnglishText extends StatelessWidget {
  const TappableEnglishText({
    required this.text,
    required this.onWordResolved,
    this.targetWords = const <WordModel>[],
    this.style,
    this.textScaleFactor,
    super.key,
  });

  final String text;
  final List<WordModel> targetWords;
  final WordResolvedCallback onWordResolved;
  final TextStyle? style;
  final double? textScaleFactor;

  @override
  Widget build(BuildContext context) {
    final targetByWord = <String, WordModel>{};
    for (final word in targetWords) {
      final normalized = WordLookupService.normalizeWord(word.word);
      if (normalized != null) {
        targetByWord[normalized] = word;
      }
    }
    final segments = parseTappableEnglishText(
      text,
      targetWords: targetByWord.keys.toSet(),
    );
    final baseStyle = style ?? Theme.of(context).textTheme.bodyLarge;
    return Text.rich(
      TextSpan(
        children: [
          for (final segment in segments)
            if (!segment.isClickable)
              TextSpan(text: segment.text)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _TappableWord(
                  text: segment.text,
                  isTarget: segment.isTarget,
                  style: baseStyle,
                  onTap: () => _handleTap(
                    context,
                    segment.text,
                    targetByWord: targetByWord,
                  ),
                ),
              ),
        ],
      ),
      textScaler: textScaleFactor == null
          ? null
          : TextScaler.linear(textScaleFactor!),
      style: baseStyle?.copyWith(height: 1.75),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    String rawWord, {
    required Map<String, WordModel> targetByWord,
  }) async {
    final normalized = WordLookupService.normalizeWord(rawWord);
    if (normalized == null || WordLookupService.shouldIgnore(normalized)) {
      return;
    }

    final target = targetByWord[normalized];
    if (target != null) {
      await onWordResolved(context, target);
      return;
    }

    final app = context.read<AppController>();
    try {
      final local = await app.lookupWord(normalized, allowRemoteLookup: false);
      if (!context.mounted) {
        return;
      }
      if (local != null) {
        await onWordResolved(context, local);
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('查询 $normalized？'),
          content: const Text('本地词库暂无该词，是否使用 DeepSeek 查询？这会消耗 token。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('查询'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _LookupLoadingDialog(),
      );
      WordModel? remote;
      try {
        remote = await app.lookupWord(normalized, allowRemoteLookup: true);
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
      if (!context.mounted) {
        return;
      }
      if (remote == null) {
        showAppSnackBar(context, '查询失败，请稍后重试。', type: AppSnackBarType.error);
        return;
      }
      await onWordResolved(context, remote);
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          error.toString().trim().isEmpty ? '查询失败，请稍后重试。' : error.toString(),
          type: AppSnackBarType.error,
        );
      }
    }
  }
}

final class TappableTextSegment {
  const TappableTextSegment({
    required this.text,
    required this.isWord,
    required this.isTarget,
    required this.isIgnored,
  });

  final String text;
  final bool isWord;
  final bool isTarget;
  final bool isIgnored;

  bool get isClickable => isWord && !isIgnored;
}

List<TappableTextSegment> parseTappableEnglishText(
  String text, {
  Set<String> targetWords = const <String>{},
}) {
  final normalizedTargets = targetWords
      .map(WordLookupService.normalizeWord)
      .nonNulls
      .toSet();
  final segments = <TappableTextSegment>[];
  final expression = RegExp(r"[A-Za-z]+(?:[-'’][A-Za-z]+)*");
  var cursor = 0;
  for (final match in expression.allMatches(text)) {
    if (match.start > cursor) {
      segments.add(
        TappableTextSegment(
          text: text.substring(cursor, match.start),
          isWord: false,
          isTarget: false,
          isIgnored: true,
        ),
      );
    }
    final value = text.substring(match.start, match.end);
    final normalized = WordLookupService.normalizeWord(value);
    segments.add(
      TappableTextSegment(
        text: value,
        isWord: true,
        isTarget: normalized != null && normalizedTargets.contains(normalized),
        isIgnored: WordLookupService.shouldIgnore(value),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.add(
      TappableTextSegment(
        text: text.substring(cursor),
        isWord: false,
        isTarget: false,
        isIgnored: true,
      ),
    );
  }
  return segments;
}

final class _TappableWord extends StatelessWidget {
  const _TappableWord({
    required this.text,
    required this.isTarget,
    required this.onTap,
    this.style,
  });

  final String text;
  final bool isTarget;
  final VoidCallback onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = (style ?? DefaultTextStyle.of(context).style).copyWith(
      color: isTarget ? colorScheme.onPrimaryContainer : null,
      fontWeight: isTarget ? FontWeight.w700 : null,
      decoration: TextDecoration.underline,
      decorationStyle: isTarget
          ? TextDecorationStyle.solid
          : TextDecorationStyle.dotted,
    );
    final child = Text(text, style: textStyle);
    if (!isTarget) {
      return InkWell(
        borderRadius: BorderRadius.circular(3),
        onTap: onTap,
        child: child,
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: child,
        ),
      ),
    );
  }
}

final class _LookupLoadingDialog extends StatelessWidget {
  const _LookupLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('正在查询…')),
        ],
      ),
    );
  }
}
