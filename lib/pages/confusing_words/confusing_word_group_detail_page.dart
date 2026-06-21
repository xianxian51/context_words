import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/confusing_word_group_model.dart';
import '../../models/word_model.dart';
import '../../providers/app_controller.dart';
import '../../widgets/add_to_word_book_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/word_detail_bottom_sheet.dart';
import '../reading/passage_view_page.dart';

final class ConfusingWordGroupDetailPage extends StatefulWidget {
  const ConfusingWordGroupDetailPage({required this.groupId, super.key});

  final int groupId;

  @override
  State<ConfusingWordGroupDetailPage> createState() =>
      _ConfusingWordGroupDetailPageState();
}

final class _ConfusingWordGroupDetailPageState
    extends State<ConfusingWordGroupDetailPage> {
  late Future<ConfusingWordGroupModel?> _groupFuture;
  late Future<List<WordModel>> _wordsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _groupFuture = context.read<AppController>().getConfusingGroup(
      widget.groupId,
    );
    _wordsFuture = context.read<AppController>().getWordsInConfusingGroup(
      widget.groupId,
    );
  }

  void _setReload() {
    setState(_reload);
  }

  Future<void> _removeWord(WordModel word) async {
    final id = word.id;
    if (id == null) {
      return;
    }
    try {
      await context.read<AppController>().removeWordFromConfusingGroup(
        widget.groupId,
        id,
      );
      _setReload();
      if (mounted) {
        showAppSnackBar(context, '已从易混词组移除。', type: AppSnackBarType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    }
  }

  Future<void> _generateAnalysis(
    ConfusingWordGroupModel group,
    List<WordModel> words,
  ) async {
    if (words.length < 2) {
      showAppSnackBar(context, '至少需要 2 个单词才能生成辨析。');
      return;
    }
    if (words.length > 20) {
      showAppSnackBar(context, '一次最多分析 20 个单词，请拆成多个词组。');
      return;
    }
    final hasExisting = group.analysis?.trim().isNotEmpty == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hasExisting ? '重新生成辨析？' : '生成 AI 辨析？'),
        content: Text(
          hasExisting
              ? '这会再次调用 DeepSeek 并覆盖当前辨析内容，会消耗 token。是否继续？'
              : '将调用 DeepSeek 分析 ${words.length} 个单词，会消耗 token。是否继续？',
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
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await context.read<AppController>().generateConfusingWordsAnalysis(group);
      _setReload();
      if (mounted) {
        showAppSnackBar(context, '辨析已生成。', type: AppSnackBarType.success);
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
    return FutureBuilder<ConfusingWordGroupModel?>(
      future: _groupFuture,
      builder: (context, groupSnapshot) {
        final group = groupSnapshot.data;
        return FutureBuilder<List<WordModel>>(
          future: _wordsFuture,
          builder: (context, wordsSnapshot) {
            final words = wordsSnapshot.data ?? const <WordModel>[];
            return Scaffold(
              appBar: AppBar(title: Text(group?.title ?? '易混词组')),
              body:
                  groupSnapshot.connectionState != ConnectionState.done ||
                      wordsSnapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : group == null
                  ? const Center(child: Text('易混词组不存在。'))
                  : SafeArea(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _HeaderCard(group: group, words: words),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: app.isBusy
                                    ? null
                                    : () => _generateAnalysis(group, words),
                                icon:
                                    app.isBusy &&
                                        app.activeOperation == '正在生成易混词辨析…'
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.auto_awesome_rounded),
                                label: Text(
                                  group.analysis?.trim().isNotEmpty == true
                                      ? '重新生成辨析'
                                      : '生成辨析',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: words.isEmpty
                                    ? null
                                    : () => showAddWordsToWordBookSheet(
                                        context,
                                        words,
                                      ),
                                icon: const Icon(Icons.library_add_rounded),
                                label: const Text('整组加入单词本'),
                              ),
                              OutlinedButton.icon(
                                onPressed: app.isBusy || words.length < 2
                                    ? null
                                    : () => openCollectionPassage(
                                        context: context,
                                        sourceType: 'confusing_group',
                                        sourceId: group.id!,
                                        sourceName: group.title,
                                        words: words,
                                      ),
                                icon: const Icon(Icons.auto_stories_rounded),
                                label: const Text('生成对比短文'),
                              ),
                            ],
                          ),
                          if (app.slowOperationMessage case final message?) ...[
                            const SizedBox(height: 10),
                            Text(message),
                          ],
                          const SizedBox(height: 18),
                          Text(
                            '组内单词',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (words.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(18),
                                child: Text('这个词组还没有单词。'),
                              ),
                            )
                          else
                            for (final word in words)
                              _WordRow(word: word, onRemove: _removeWord),
                          const SizedBox(height: 18),
                          Text(
                            'AI 辨析',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                group.analysis?.trim().isNotEmpty == true
                                    ? group.analysis!.trim()
                                    : '还没有生成辨析。点击“生成辨析”后，DeepSeek 会对这组词做中文释义、词形差异、例句和小测验分析。',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

final class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.group, required this.words});

  final ConfusingWordGroupModel group;
  final List<WordModel> words;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.title, style: Theme.of(context).textTheme.titleLarge),
            if (group.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(group.description!),
            ],
            const SizedBox(height: 8),
            Text('${words.length} 个单词'),
          ],
        ),
      ),
    );
  }
}

final class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.onRemove});

  final WordModel word;
  final ValueChanged<WordModel> onRemove;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    return Card(
      child: ListTile(
        onTap: () => showWordDetailBottomSheet(context, word),
        leading: IconButton(
          tooltip: '发音',
          onPressed: () async {
            try {
              await app.speakWord(word.word);
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
        title: Text(word.word),
        subtitle: Text(
          '${word.partOfSpeech ?? '暂无'}  ${word.meaningCn ?? '暂无'}',
        ),
        trailing: IconButton(
          tooltip: '移出词组',
          onPressed: () => onRemove(word),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
      ),
    );
  }
}
