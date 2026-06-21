import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../providers/app_controller.dart';
import 'add_to_word_book_sheet.dart';
import 'app_snack_bar.dart';
import 'tappable_english_text.dart';

Future<void> showWordDetailBottomSheet(BuildContext context, WordModel word) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _WordDetailContent(initialWord: word),
  );
}

final class _WordDetailContent extends StatefulWidget {
  const _WordDetailContent({required this.initialWord});

  final WordModel initialWord;

  @override
  State<_WordDetailContent> createState() => _WordDetailContentState();
}

final class _WordDetailContentState extends State<_WordDetailContent> {
  late WordModel _word = widget.initialWord;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _word.word,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: '发音',
                  onPressed: () async {
                    try {
                      await controller.speakWord(_word.word);
                    } catch (error) {
                      if (context.mounted) {
                        showAppSnackBar(
                          context,
                          error.toString(),
                          type: AppSnackBarType.error,
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.volume_up_rounded),
                ),
                IconButton(
                  tooltip: _word.isStarred ? '取消星标' : '加入重点词册',
                  onPressed: () async {
                    final updated = await controller.toggleStar(_word);
                    if (mounted) {
                      setState(() => _word = updated);
                    }
                  },
                  icon: Icon(
                    _word.isStarred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: _word.isStarred ? Colors.amber.shade700 : null,
                  ),
                ),
              ],
            ),
            Text(_value(_word.phonetic)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_word.id == null ? '未加入词库' : '已加入词库'),
                ),
                OutlinedButton.icon(
                  onPressed: _word.id == null
                      ? null
                      : () => showAddWordToWordBookSheet(context, _word),
                  icon: const Icon(Icons.library_add_rounded),
                  label: const Text('加入单词本'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Detail(label: '词性', value: _word.partOfSpeech),
            _Detail(label: '中文释义', value: _word.meaningCn),
            _Detail(
              label: '英文释义',
              value: _word.meaningEn,
              targetWords: [_word],
              onWordResolved: _replaceWord,
            ),
            _Detail(
              label: '例句',
              value: _word.exampleSentence,
              targetWords: [_word],
              onWordResolved: _replaceWord,
            ),
            _Detail(
              label: '常见搭配',
              value: _word.phrase,
              targetWords: [_word],
              onWordResolved: _replaceWord,
            ),
            _Detail(
              label: '同义词',
              value: _word.synonyms,
              targetWords: [_word],
              onWordResolved: _replaceWord,
            ),
          ],
        ),
      ),
    );
  }

  void _replaceWord(BuildContext context, WordModel word) {
    if (mounted) {
      setState(() => _word = word);
    }
  }
}

final class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    this.targetWords = const <WordModel>[],
    this.onWordResolved,
  });

  final String label;
  final String? value;
  final List<WordModel> targetWords;
  final WordResolvedCallback? onWordResolved;

  @override
  Widget build(BuildContext context) {
    final text = _value(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          onWordResolved == null || text == '暂无'
              ? Text(text, style: Theme.of(context).textTheme.bodyLarge)
              : TappableEnglishText(
                  text: text,
                  targetWords: targetWords,
                  onWordResolved: onWordResolved!,
                ),
        ],
      ),
    );
  }
}

String _value(String? value) =>
    value == null || value.trim().isEmpty ? '暂无' : value;
