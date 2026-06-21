import 'package:flutter/material.dart';

import '../models/wordbook_upgrade_result.dart';
import '../providers/app_controller.dart';
import 'app_snack_bar.dart';

String builtinWordbookActionLabel(AppController app) {
  return app.totalWordCount < 5000 ? '初始化/升级六级词库' : '重新检查词库';
}

String wordbookUpgradeResultMessage(WordbookUpgradeResult result) {
  return '内置词库：${result.builtinCount}\n'
      '新增导入：${result.imported}\n'
      '已存在跳过：${result.existing}\n'
      '补全字段：${result.enrichedFields}\n'
      '当前词库总数：${result.totalWordCount}';
}

Future<bool> runBuiltinWordbookUpgrade(
  BuildContext context,
  AppController app,
) async {
  try {
    final result = await app.initializeBuiltinCet6Wordbook();
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('六级词库处理完成'),
          content: Text(wordbookUpgradeResultMessage(result)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
    }
    return false;
  }
}

final class BuiltinWordbookManagerCard extends StatelessWidget {
  const BuiltinWordbookManagerCard({
    required this.app,
    this.onCompleted,
    super.key,
  });

  final AppController app;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final builtinCount = app.builtinCet6Count == 0
        ? 5406
        : app.builtinCet6Count;
    final upgrading = app.isBusy && app.activeOperation == '正在初始化六级词库…';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('词库管理', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('当前词库：${app.totalWordCount}'),
            Text('内置六级：$builtinCount'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: app.isBusy
                    ? null
                    : () async {
                        final completed = await runBuiltinWordbookUpgrade(
                          context,
                          app,
                        );
                        if (completed) {
                          onCompleted?.call();
                        }
                      },
                icon: upgrading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_alt_rounded),
                label: Text(
                  upgrading ? '正在初始化六级词库…' : builtinWordbookActionLabel(app),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
