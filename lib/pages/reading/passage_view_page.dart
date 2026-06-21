import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/collection_passage_model.dart';
import '../../models/word_model.dart';
import '../../providers/app_controller.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/passage_translation_panel.dart';
import '../../widgets/tappable_english_text.dart';
import '../../widgets/word_detail_bottom_sheet.dart';

Future<void> openCollectionPassage({
  required BuildContext context,
  required String sourceType,
  required int sourceId,
  required String sourceName,
  required List<WordModel> words,
}) async {
  if (sourceType == 'word_book' && words.isEmpty) {
    showAppSnackBar(context, '单词本为空，无法生成短文。');
    return;
  }
  if (sourceType == 'confusing_group' && words.length < 2) {
    showAppSnackBar(context, '至少需要 2 个词。');
    return;
  }
  final selectedWords = words
      .take(sourceType == 'word_book' ? 20 : 30)
      .toList(growable: false);
  final app = context.read<AppController>();
  var passage = await app.getLatestCollectionPassage(
    sourceType: sourceType,
    sourceId: sourceId,
  );
  if (!context.mounted) {
    return;
  }
  if (passage == null) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sourceType == 'word_book' ? '生成记忆短文？' : '生成对比短文？'),
        content: Text(
          '将使用 ${selectedWords.length} 个单词生成短文，会消耗 DeepSeek token，是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('生成'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      passage = await app.generateCollectionPassage(
        sourceType: sourceType,
        sourceId: sourceId,
        sourceName: sourceName,
        words: selectedWords,
      );
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
      return;
    }
  }
  if (!context.mounted) {
    return;
  }
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => PassageViewPage(
        initialPassage: passage!,
        sourceName: sourceName,
        targetWords: selectedWords,
      ),
    ),
  );
}

final class PassageViewPage extends StatefulWidget {
  const PassageViewPage({
    required this.initialPassage,
    required this.sourceName,
    required this.targetWords,
    super.key,
  });

  final CollectionPassageModel initialPassage;
  final String sourceName;
  final List<WordModel> targetWords;

  @override
  State<PassageViewPage> createState() => _PassageViewPageState();
}

final class _PassageViewPageState extends State<PassageViewPage> {
  late CollectionPassageModel _passage = widget.initialPassage;

  Future<void> _regenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新生成短文？'),
        content: const Text('重新生成会再次消耗 DeepSeek token，已保存的旧短文不会影响学习数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      final passage = await context
          .read<AppController>()
          .generateCollectionPassage(
            sourceType: _passage.sourceType,
            sourceId: _passage.sourceId,
            sourceName: widget.sourceName,
            words: widget.targetWords,
          );
      if (mounted) {
        setState(() => _passage = passage);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: Text(_passage.title ?? '记忆短文')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            TappableEnglishText(
              text: _passage.content ?? '',
              targetWords: widget.targetWords,
              onWordResolved: (context, word) =>
                  showWordDetailBottomSheet(context, word),
            ),
            const SizedBox(height: 20),
            PassageTranslationPanel(
              key: ValueKey<int?>(_passage.id),
              initialTitleCn: _passage.titleCn,
              initialTranslationCn: _passage.translationCn,
              onTranslate: ({required force}) async {
                final translation = await context
                    .read<AppController>()
                    .translateCollectionPassage(_passage, force: force);
                if (mounted) {
                  setState(
                    () => _passage = _passage.copyWith(
                      titleCn: translation.titleCn,
                      translationCn: translation.translationCn,
                      translatedAt: DateTime.now().toUtc(),
                    ),
                  );
                }
                return translation;
              },
            ),
            const SizedBox(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('目标词（${widget.targetWords.length}）'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final word in widget.targetWords)
                        ActionChip(
                          label: Text(word.word),
                          onPressed: () =>
                              showWordDetailBottomSheet(context, word),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _passage.content ?? ''),
                    );
                    if (context.mounted) {
                      showAppSnackBar(
                        context,
                        '短文已复制。',
                        type: AppSnackBarType.success,
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('复制全文'),
                ),
                FilledButton.tonalIcon(
                  onPressed: app.isBusy ? null : _regenerate,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(app.isBusy ? '正在生成…' : '重新生成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
