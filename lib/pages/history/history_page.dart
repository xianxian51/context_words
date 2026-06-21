import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/history_day_model.dart';
import '../../providers/app_controller.dart';
import '../../widgets/word_detail_bottom_sheet.dart';

final class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: FutureBuilder<List<HistoryDayModel>>(
        future: context.read<AppController>().getHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }
          final history = snapshot.data ?? const <HistoryDayModel>[];
          if (history.isEmpty) {
            return const Center(child: Text('还没有学习记录。'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final day = history[index];
              return Card(
                child: ExpansionTile(
                  title: Text(_date(day.plan.date)),
                  subtitle: Text(
                    '${day.words.length} 个单词 · '
                    '${day.words.map((item) => item.batchNo).toSet().length} 组',
                  ),
                  children: _historyChildren(context, day),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

List<Widget> _historyChildren(BuildContext context, HistoryDayModel day) {
  final batches = day.words.map((item) => item.batchNo).toSet().toList()
    ..sort();
  return <Widget>[
    for (final batchNo in batches) ...[
      ListTile(
        title: Text('第 $batchNo 组'),
        subtitle: Text(
          '${day.words.where((item) => item.batchNo == batchNo).length} 个单词',
        ),
        trailing: Text(
          _roundSummary(day.completedRoundsByBatch[batchNo] ?? const <int>{}),
        ),
      ),
      for (final item in day.words.where((item) => item.batchNo == batchNo))
        ListTile(
          contentPadding: const EdgeInsets.only(left: 32, right: 16),
          title: Text(item.word.word),
          subtitle: Text(item.word.meaningCn ?? '暂无释义'),
          trailing: Text(_memoryText(item.memoryStatus)),
          onTap: () => showWordDetailBottomSheet(context, item.word),
        ),
    ],
  ];
}

String _date(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _roundSummary(Set<int> rounds) {
  return '第一轮${rounds.contains(1) ? '✓' : '○'} '
      '第二轮${rounds.contains(2) ? '✓' : '○'} '
      '第三轮${rounds.contains(3) ? '✓' : '○'}';
}

String _memoryText(String status) {
  return switch (status) {
    'known' => '已掌握',
    'uncertain' => '模糊',
    'unknown' => '不认识',
    _ => '未复习',
  };
}
