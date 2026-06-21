import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/plan_word_model.dart';
import '../../providers/app_controller.dart';
import '../../widgets/add_to_word_book_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/word_detail_bottom_sheet.dart';

final class TodayWordsPage extends StatelessWidget {
  const TodayWordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, app, _) {
        final plan = app.todayPlan;
        final words = app.allTodayWords;
        return Scaffold(
          appBar: AppBar(title: const Text('今日单词')),
          body: plan == null
              ? const Center(child: Text('请先生成今日计划。'))
              : SafeArea(
                  child: Column(
                    children: [
                      _TodayWordsHeader(
                        dateText:
                            '${plan.date.year}年${plan.date.month}月${plan.date.day}日',
                        count: words.length,
                      ),
                      Expanded(
                        child: words.isEmpty
                            ? const Center(child: Text('今日计划中还没有单词。'))
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  16,
                                ),
                                itemCount: app.todayBatches.length,
                                itemBuilder: (context, index) {
                                  final batchNo = app.todayBatches[index];
                                  final batchWords = words
                                      .where((item) => item.batchNo == batchNo)
                                      .toList(growable: false);
                                  final completed =
                                      (app
                                              .completedRoundsByBatch[batchNo]
                                              ?.length ??
                                          0) ==
                                      3;
                                  return _BatchSection(
                                    batchNo: batchNo,
                                    words: batchWords,
                                    completed: completed,
                                    selected: app.selectedBatchNo == batchNo,
                                    onSelect: () =>
                                        app.selectTodayBatch(batchNo),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

final class _BatchSection extends StatelessWidget {
  const _BatchSection({
    required this.batchNo,
    required this.words,
    required this.completed,
    required this.selected,
    required this.onSelect,
  });

  final int batchNo;
  final List<PlanWordModel> words;
  final bool completed;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '第 $batchNo 组 · ${words.length} 个',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (completed)
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('三轮已完成'),
                  )
                else if (selected)
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('当前组'),
                  )
                else
                  TextButton(onPressed: onSelect, child: const Text('设为当前组')),
              ],
            ),
          ),
          for (final item in words) _TodayWordCard(item: item),
        ],
      ),
    );
  }
}

final class _TodayWordsHeader extends StatelessWidget {
  const _TodayWordsHeader({required this.dateText, required this.count});

  final String dateText;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.event_note_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateText,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('今日共 $count 个单词'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TodayWordCard extends StatelessWidget {
  const _TodayWordCard({required this.item});

  final PlanWordModel item;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final word = item.word;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showWordDetailBottomSheet(context, word),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            word.word,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: item.memoryStatus),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_fallback(word.phonetic)),
                    const SizedBox(height: 6),
                    Text(
                      '${_fallback(word.partOfSpeech)}  ${_meaning(word.meaningCn)}',
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '加入单词本',
                onPressed: () => showAddWordToWordBookSheet(context, word),
                icon: const Icon(Icons.library_add_rounded),
              ),
              IconButton(
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
              IconButton(
                tooltip: word.isStarred ? '取消星标' : '加入重点词册',
                onPressed: () => app.toggleStar(word),
                icon: Icon(
                  word.isStarred
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: word.isStarred ? Colors.amber.shade700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(_statusText(status)),
      backgroundColor: colorScheme.secondaryContainer,
      labelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
    );
  }
}

String _fallback(String? value) =>
    value == null || value.trim().isEmpty ? '暂无' : value;

String _meaning(String? value) =>
    value == null || value.trim().isEmpty ? '暂无释义，可使用 AI 查询或 AI 补全。' : value;

String _statusText(String status) {
  return switch (status) {
    'known' => '已掌握',
    'uncertain' => '模糊',
    'unknown' => '不认识',
    _ => '未复习',
  };
}
