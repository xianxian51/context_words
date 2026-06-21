import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/plan_generation_result.dart';
import '../../models/word_selection_mode.dart';
import '../../providers/app_controller.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/builtin_wordbook_manager.dart';
import '../confusing_words/confusing_words_page.dart';
import '../history/history_page.dart';
import '../import_words/import_words_page.dart';
import '../library/word_library_page.dart';
import '../reading/reading_page.dart';
import '../review/review_page.dart';
import '../settings/settings_page.dart';
import '../starred/starred_words_page.dart';
import '../today_words/today_words_page.dart';
import '../word_books/word_books_page.dart';

final class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, app, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('语境单词本'),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: app.isLoading ? null : app.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: app.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: app.refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _TodayCard(app: app),
                      if (app.actionMessage case final message?) ...[
                        const SizedBox(height: 10),
                        _InlineMessage(
                          message: message,
                          isError: app.actionMessageIsError,
                          onClose: app.clearActionMessage,
                        ),
                      ],
                      if (app.slowOperationMessage case final message?) ...[
                        const SizedBox(height: 10),
                        _InlineMessage(message: message, isError: false),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        '三遍语境记忆',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      _RoundCard(
                        round: 1,
                        title: '第一遍：阅读预热',
                        subtitle: _readingSubtitle(app, 1),
                        completed: app.completedRounds.contains(1),
                        onTap: () => _openReading(context, app, 1),
                      ),
                      _RoundCard(
                        round: 2,
                        title: '第二遍：语境强化',
                        subtitle: _readingSubtitle(app, 2),
                        completed: app.completedRounds.contains(2),
                        onTap: () => _openReading(context, app, 2),
                      ),
                      _RoundCard(
                        round: 3,
                        title: '第三遍：单词复习',
                        subtitle: _reviewSubtitle(app),
                        completed: app.completedRounds.contains(3),
                        onTap: () => _openReview(context, app),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '今天从这里开始',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      _ActionGrid(app: app),
                    ],
                  ),
                ),
        );
      },
    );
  }

  static Future<void> _openReading(
    BuildContext context,
    AppController app,
    int round,
  ) async {
    if (app.todayPlan == null) {
      showAppSnackBar(context, '请先生成今日计划。');
      return;
    }
    if (!app.passages.containsKey(round)) {
      await app.retryMissingReadings();
      if (!context.mounted || !app.passages.containsKey(round)) {
        return;
      }
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReadingPage(round: round, batchNo: app.selectedBatchNo),
      ),
    );
    await app.refresh();
  }

  static Future<void> _openReview(
    BuildContext context,
    AppController app,
  ) async {
    if (app.todayPlan == null) {
      showAppSnackBar(context, '请先生成今日计划。');
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReviewPage(batchNo: app.selectedBatchNo),
      ),
    );
    await app.refresh();
  }

  static Future<void> openTodayWords(
    BuildContext context,
    AppController app,
  ) async {
    if (app.todayPlan == null) {
      showAppSnackBar(context, '请先生成今日计划。');
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const TodayWordsPage()),
    );
    await app.refresh();
  }

  static String _readingSubtitle(AppController app, int round) {
    if (app.todayPlan == null) {
      return '请先生成今日计划';
    }
    if (!app.passages.containsKey(round)) {
      return app.hasApiKey ? '阅读正在准备，可稍后进入' : '设置 API Key 后即可准备阅读';
    }
    if (app.completedRounds.contains(round)) {
      return '已完成';
    }
    return round == 1 ? '可以开始第一遍阅读' : '第二遍稍后进行';
  }

  static String _reviewSubtitle(AppController app) {
    if (app.todayPlan == null) {
      return '请先生成今日计划';
    }
    if (app.completedRounds.contains(3)) {
      return '已完成';
    }
    return '晚上复习 ${app.todayWords.length} 个单词';
  }
}

final class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = '${now.year}年${now.month}月${now.day}日';
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              app.isPreparingToday
                  ? app.preparationStatus ?? '正在准备今日学习…'
                  : app.todayPlan != null && app.passages.length == 2
                  ? '今日已准备好'
                  : app.todayPlan != null
                  ? '今日单词已准备好'
                  : '今天也从一小步开始',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: '当前组进度',
                    value: '${app.completedRounds.length}/3',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '今日单词',
                    value: '${app.allTodayWords.length}',
                    onTap: () => HomePage.openTodayWords(context, app),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '词库总数',
                    value: '${app.totalWordCount}',
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const WordLibraryPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '每日目标：${app.dailyWordCount} 个',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (app.todayBatches.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: app.selectedBatchNo,
                decoration: const InputDecoration(
                  labelText: '当前学习组',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final batchNo in app.todayBatches)
                    DropdownMenuItem<int>(
                      value: batchNo,
                      child: Text('第 $batchNo 组'),
                    ),
                ],
                onChanged: app.isBusy
                    ? null
                    : (batchNo) {
                        if (batchNo != null) {
                          app.selectTodayBatch(batchNo);
                        }
                      },
              ),
            ],
            if (app.totalWordCount == 0) ...[
              const SizedBox(height: 14),
              const Text('词库为空，请从下方“更多 / 管理 / 高级操作”初始化六级词库。'),
            ],
          ],
        ),
      ),
    );
  }
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
    if (onTap == null) {
      return child;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(4), child: child),
    );
  }
}

final class _RoundCard extends StatelessWidget {
  const _RoundCard({
    required this.round,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.onTap,
  });

  final int round;
  final String title;
  final String subtitle;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text('$round')),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          completed ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
          color: completed ? Colors.green.shade700 : null,
        ),
      ),
    );
  }
}

final class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final secondaryActions = <_HomeAction>[
      _HomeAction(
        icon: Icons.library_books_rounded,
        label: '词库',
        onTap: () => _push(context, const WordLibraryPage()),
      ),
      _HomeAction(
        icon: Icons.collections_bookmark_rounded,
        label: '我的单词本',
        onTap: () => _push(context, const WordBooksPage()),
      ),
      _HomeAction(
        icon: Icons.compare_arrows_rounded,
        label: '易混词组',
        onTap: () => _push(context, const ConfusingWordsPage()),
      ),
      _HomeAction(
        icon: Icons.star_rounded,
        label: '重点词册',
        onTap: () => _push(context, const StarredWordsPage()),
      ),
      _HomeAction(
        icon: Icons.history_rounded,
        label: '历史记录',
        onTap: () => _push(context, const HistoryPage()),
      ),
      _HomeAction(
        icon: Icons.settings_rounded,
        label: '设置',
        onTap: () => _push(context, const SettingsPage()),
      ),
    ];
    final advancedActions = <_HomeAction>[
      _HomeAction(
        icon: Icons.playlist_add_rounded,
        label: '导入单词',
        onTap: () => _push(context, const ImportWordsPage()),
      ),
      _HomeAction(
        icon: Icons.today_rounded,
        label: app.todayPlan == null ? '手动生成今日计划' : '重建今日计划',
        onTap: () => app.todayPlan == null
            ? _generatePlan(context)
            : _confirmRebuildPlan(context),
      ),
      _HomeAction(
        icon: Icons.auto_stories_rounded,
        label: '重试生成阅读',
        onTap: () => _retryReadings(context),
      ),
      _HomeAction(
        icon: Icons.system_update_alt_rounded,
        label: builtinWordbookActionLabel(app),
        onTap: () => runBuiltinWordbookUpgrade(context, app),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('start-learning-button'),
          onPressed: app.isBusy || app.isPreparingToday
              ? null
              : () => _startLearning(context),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(app.todayPlan == null ? '开始学习' : '继续学习'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: app.isBusy
                    ? null
                    : () => HomePage.openTodayWords(context, app),
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('今日单词'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: app.isBusy || app.todayPlan == null
                    ? null
                    : () => _appendBatch(context),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('再来一组'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('更多学习入口', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _HomeActionGrid(actions: secondaryActions, app: app),
        const SizedBox(height: 10),
        Card(
          child: ExpansionTile(
            key: const Key('advanced-actions-tile'),
            leading: const Icon(Icons.tune_rounded),
            title: const Text('更多 / 管理 / 高级操作'),
            subtitle: const Text('导入、重建、阅读重试与词库升级'),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [_HomeActionGrid(actions: advancedActions, app: app)],
          ),
        ),
        if (app.isBusy || app.isPreparingToday) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          Text(app.preparationStatus ?? app.activeOperation ?? '处理中，请稍候…'),
        ],
      ],
    );
  }

  Future<void> _startLearning(BuildContext context) async {
    if (app.todayPlan == null || app.passages.length < 2) {
      await app.retryMissingReadings();
      if (!context.mounted || app.todayPlan == null) {
        return;
      }
    }
    if (!app.passages.containsKey(1)) {
      return;
    }
    if (!app.completedRounds.contains(1)) {
      await HomePage._openReading(context, app, 1);
      return;
    }
    if (!app.passages.containsKey(2)) {
      return;
    }
    if (!app.completedRounds.contains(2)) {
      await HomePage._openReading(context, app, 2);
      return;
    }
    await HomePage._openReview(context, app);
  }

  Future<void> _retryReadings(BuildContext context) async {
    await app.retryMissingReadings();
    if (context.mounted && app.passages.length == 2) {
      showAppSnackBar(context, '今日学习已准备好。', type: AppSnackBarType.success);
    }
  }

  Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    await app.refresh();
  }

  Future<void> _generatePlan(BuildContext context) async {
    if (app.totalWordCount == 0) {
      showAppSnackBar(context, '请先导入单词或初始化六级词库。');
      return;
    }
    try {
      final result = await app.generateTodayPlan();
      if (context.mounted) {
        showAppSnackBar(
          context,
          _planMessage(result),
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        app.setActionMessage(error.toString(), isError: true);
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    }
  }

  Future<void> _confirmRebuildPlan(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重建今日计划？'),
        content: const Text(
          '这会删除今天所有学习组、阅读文章和复习记录，然后重新生成。'
          '已经完成的今日学习记录也会被清空。如果只是想继续背新词，请使用“再来一组”。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认重建'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final result = await app.rebuildTodayPlan();
      if (context.mounted) {
        showAppSnackBar(
          context,
          _planMessage(result),
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        app.setActionMessage(error.toString(), isError: true);
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    }
  }

  Future<void> _appendBatch(BuildContext context) async {
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('再来一组？'),
        content: const Text('这会在今天追加一组新的单词，不会删除你之前已经学习的单词和记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, -1),
            child: const Text('自定义数量'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, app.dailyWordCount),
            child: Text('追加 ${app.dailyWordCount} 个'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) {
      return;
    }
    final count = choice == -1 ? await _askCustomBatchCount(context) : choice;
    if (count == null || !context.mounted) {
      return;
    }
    try {
      final result = await app.appendTodayBatch(count);
      if (!context.mounted) {
        return;
      }
      if (result.addedCount == 0) {
        showAppSnackBar(context, '没有可追加的单词。');
        return;
      }
      showAppSnackBar(
        context,
        '第 ${result.batchNo} 组已${app.wordSelectionMode == WordSelectionMode.random ? '随机' : '按顺序'}'
        '添加 ${result.addedCount} 个单词，'
        '今日共 ${result.todayTotalWordCount} 个。',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    }
  }

  Future<int?> _askCustomBatchCount(BuildContext context) async {
    final controller = TextEditingController(
      text: app.dailyWordCount.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义追加数量'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '单词数量（1-100）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 1 && value <= 100) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _planMessage(PlanGenerationResult result) {
    if (result.alreadyExisted) {
      return '今日计划已存在。';
    }
    if (result.actualCount == 0) {
      return '没有尚未安排的单词。';
    }
    if (result.hasShortage) {
      return app.wordSelectionMode == WordSelectionMode.random
          ? '词库可用词不足，已随机生成 ${result.actualCount} 个。'
          : '词库可用词不足，已按顺序生成 ${result.actualCount} 个。';
    }
    return app.wordSelectionMode == WordSelectionMode.random
        ? '已随机生成今日单词 ${result.actualCount} 个。'
        : '已按顺序生成今日单词 ${result.actualCount} 个。';
  }
}

final class _HomeAction {
  const _HomeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

final class _HomeActionGrid extends StatelessWidget {
  const _HomeActionGrid({required this.actions, required this.app});

  final List<_HomeAction> actions;
  final AppController app;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 620 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: constraints.maxWidth < 380 ? 1.8 : 2.25,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return OutlinedButton.icon(
              onPressed: app.isBusy || app.isPreparingToday
                  ? null
                  : action.onTap,
              icon: Icon(action.icon),
              label: Text(action.label, textAlign: TextAlign.center),
            );
          },
        );
      },
    );
  }
}

final class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.isError,
    this.onClose,
  });

  final String message;
  final bool isError;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: isError
          ? colorScheme.errorContainer
          : colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            if (onClose != null)
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
