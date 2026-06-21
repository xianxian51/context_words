import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/plan_word_model.dart';
import '../../providers/app_controller.dart';
import '../../widgets/add_to_word_book_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/tappable_english_text.dart';
import '../../widgets/word_detail_bottom_sheet.dart';

final class ReviewPage extends StatelessWidget {
  const ReviewPage({required this.batchNo, super.key});

  final int batchNo;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, app, _) {
        final words = app.todayWords;
        return Scaffold(
          appBar: AppBar(title: Text('第$batchNo组 · 单词复习')),
          body: words.isEmpty
              ? const Center(child: Text('今日没有复习单词，请先生成计划。'))
              : Column(
                  children: [
                    _Statistics(words: words),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: words.length,
                        itemBuilder: (context, index) {
                          final item = words[index];
                          return Card(
                            child: ExpansionTile(
                              title: Text(
                                item.word.word,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(_statusText(item.memoryStatus)),
                              trailing: IconButton(
                                tooltip: item.word.isStarred ? '取消星标' : '星标',
                                onPressed: () => app.toggleStar(item.word),
                                icon: Icon(
                                  item.word.isStarred
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: item.word.isStarred
                                      ? Colors.amber.shade700
                                      : null,
                                ),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: '发音',
                                      onPressed: () async {
                                        try {
                                          await app.speakWord(item.word.word);
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
                                    Expanded(
                                      child: Text(
                                        '${item.word.partOfSpeech ?? '暂无'}  ${item.word.meaningCn ?? '暂无'}',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          showWordDetailBottomSheet(
                                            context,
                                            item.word,
                                          ),
                                      child: const Text('完整详情'),
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => showAddWordToWordBookSheet(
                                      context,
                                      item.word,
                                    ),
                                    icon: const Icon(Icons.library_add_rounded),
                                    label: const Text('加入单词本'),
                                  ),
                                ),
                                if (item.word.exampleSentence?.isNotEmpty ==
                                    true)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: TappableEnglishText(
                                        text: item.word.exampleSentence!,
                                        targetWords: [item.word],
                                        onWordResolved: (context, word) =>
                                            showWordDetailBottomSheet(
                                              context,
                                              word,
                                            ),
                                      ),
                                    ),
                                  ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _StatusChip(
                                      item: item,
                                      value: 'known',
                                      label: '已掌握',
                                    ),
                                    _StatusChip(
                                      item: item,
                                      value: 'uncertain',
                                      label: '模糊',
                                    ),
                                    _StatusChip(
                                      item: item,
                                      value: 'unknown',
                                      label: '不认识',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              await app.completeRound(3, batchNo: batchNo);
                              if (context.mounted) {
                                showAppSnackBar(
                                  context,
                                  '晚间复习已完成。',
                                  type: AppSnackBarType.success,
                                );
                              }
                            },
                            icon: const Icon(Icons.done_all_rounded),
                            label: Text(
                              app.completedRounds.contains(3)
                                  ? '复习已完成'
                                  : '完成本轮复习',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

final class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.item,
    required this.value,
    required this.label,
  });

  final PlanWordModel item;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final selected = item.memoryStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) =>
          context.read<AppController>().setMemoryStatus(item, value),
    );
  }
}

final class _Statistics extends StatelessWidget {
  const _Statistics({required this.words});

  final List<PlanWordModel> words;

  @override
  Widget build(BuildContext context) {
    int count(String status) =>
        words.where((word) => word.memoryStatus == status).length;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(label: '总数', value: words.length),
            _Stat(label: '已掌握', value: count('known')),
            _Stat(label: '模糊', value: count('uncertain')),
            _Stat(label: '不认识', value: count('unknown')),
          ],
        ),
      ),
    );
  }
}

final class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

String _statusText(String status) {
  return switch (status) {
    'known' => '已掌握',
    'uncertain' => '模糊',
    'unknown' => '不认识',
    _ => '未复习',
  };
}
