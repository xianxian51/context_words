import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/deepseek_models.dart';
import 'app_snack_bar.dart';

typedef PassageTranslationLoader =
    Future<PassageTranslation> Function({required bool force});

final class PassageTranslationPanel extends StatefulWidget {
  const PassageTranslationPanel({
    required this.onTranslate,
    this.initialTitleCn,
    this.initialTranslationCn,
    this.initialSentencePairsJson,
    this.initialKeyWordNotesJson,
    super.key,
  });

  final String? initialTitleCn;
  final String? initialTranslationCn;
  final String? initialSentencePairsJson;
  final String? initialKeyWordNotesJson;
  final PassageTranslationLoader onTranslate;

  @override
  State<PassageTranslationPanel> createState() =>
      _PassageTranslationPanelState();
}

final class _PassageTranslationPanelState
    extends State<PassageTranslationPanel> {
  late String? _titleCn = _normalized(widget.initialTitleCn);
  late String? _translationCn = _normalized(widget.initialTranslationCn);
  late List<TranslationSentencePair> _sentencePairs =
      decodeTranslationSentencePairs(widget.initialSentencePairsJson);
  late List<TranslationKeyWordNote> _keyWordNotes =
      decodeTranslationKeyWordNotes(widget.initialKeyWordNotesJson);
  bool _showTranslation = false;
  bool _translating = false;
  String? _error;

  @override
  void didUpdateWidget(covariant PassageTranslationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTitleCn != widget.initialTitleCn ||
        oldWidget.initialTranslationCn != widget.initialTranslationCn ||
        oldWidget.initialSentencePairsJson != widget.initialSentencePairsJson ||
        oldWidget.initialKeyWordNotesJson != widget.initialKeyWordNotesJson) {
      _titleCn = _normalized(widget.initialTitleCn);
      _translationCn = _normalized(widget.initialTranslationCn);
      _sentencePairs = decodeTranslationSentencePairs(
        widget.initialSentencePairsJson,
      );
      _keyWordNotes = decodeTranslationKeyWordNotes(
        widget.initialKeyWordNotesJson,
      );
    }
  }

  Future<void> _requestTranslation({required bool force}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(force ? '重新翻译？' : '全文翻译？'),
        content: Text(
          force
              ? '重新翻译会覆盖当前翻译并消耗 DeepSeek token，是否继续？'
              : '全文翻译会消耗 DeepSeek token，是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('翻译'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _translating = true;
      _error = null;
    });
    try {
      final translated = await widget.onTranslate(force: force);
      if (!mounted) {
        return;
      }
      setState(() {
        _titleCn = _normalized(translated.titleCn);
        _translationCn = translated.translationCn.trim();
        _sentencePairs = translated.sentencePairs;
        _keyWordNotes = translated.keyWordNotes;
        _showTranslation = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _translating = false);
      }
    }
  }

  Future<void> _copyTranslation() async {
    final copyText = _copyableTranslation();
    if (copyText == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: copyText));
    if (mounted) {
      showAppSnackBar(context, '翻译已复制。', type: AppSnackBarType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTranslation = _translationCn != null;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _translating
                  ? null
                  : hasTranslation
                  ? () => setState(() => _showTranslation = !_showTranslation)
                  : () => _requestTranslation(force: false),
              icon: _translating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      hasTranslation && _showTranslation
                          ? Icons.visibility_off_rounded
                          : Icons.translate_rounded,
                    ),
              label: Text(
                _translating
                    ? '正在翻译…'
                    : hasTranslation
                    ? (_showTranslation ? '收起翻译' : '查看翻译')
                    : '全文翻译',
              ),
            ),
            if (hasTranslation)
              TextButton.icon(
                onPressed: _translating
                    ? null
                    : () => _requestTranslation(force: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新翻译'),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ],
        if (hasTranslation && _showTranslation) ...[
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '学习翻译',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: _copyTranslation,
                        tooltip: '复制翻译',
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                  if (_titleCn != null) ...[
                    Text(
                      _titleCn!,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_sentencePairs.isNotEmpty)
                    ..._sentencePairs.indexed.map(
                      (entry) => _SentencePairCard(
                        index: entry.$1 + 1,
                        pair: entry.$2,
                      ),
                    )
                  else
                    SelectableText(
                      _translationCn!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.75),
                    ),
                  if (_keyWordNotes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '目标词提示',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final note in _keyWordNotes)
                      _KeyWordNoteTile(note: note),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String? _copyableTranslation() {
    final translation = _translationCn;
    if (translation == null) {
      return null;
    }
    final buffer = StringBuffer();
    if (_titleCn != null) {
      buffer.writeln(_titleCn);
      buffer.writeln();
    }
    if (_sentencePairs.isNotEmpty) {
      for (final entry in _sentencePairs.indexed) {
        buffer.writeln('原句 ${entry.$1 + 1}：${entry.$2.en}');
        buffer.writeln('译文：${entry.$2.zh}');
        buffer.writeln();
      }
    } else {
      buffer.writeln(translation);
      buffer.writeln();
    }
    if (_keyWordNotes.isNotEmpty) {
      buffer.writeln('目标词提示：');
      for (final note in _keyWordNotes) {
        buffer.writeln(
          '${note.word}：${note.meaningInContext}（${note.sentence}）',
        );
      }
    }
    return buffer.toString().trim();
  }
}

String? _normalized(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

final class _SentencePairCard extends StatelessWidget {
  const _SentencePairCard({required this.index, required this.pair});

  final int index;
  final TranslationSentencePair pair;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '原句 $index',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(pair.en, style: textTheme.bodyMedium),
              const SizedBox(height: 10),
              Text(
                '译文',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                pair.zh,
                style: textTheme.bodyLarge?.copyWith(height: 1.65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _KeyWordNoteTile extends StatelessWidget {
  const _KeyWordNoteTile({required this.note});

  final TranslationKeyWordNote note;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.tertiaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.word,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.onTertiaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(note.meaningInContext),
              if (note.sentence.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.sentence,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
