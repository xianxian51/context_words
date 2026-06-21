import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/import_result.dart';
import '../../providers/app_controller.dart';
import '../../widgets/app_snack_bar.dart';
import '../settings/settings_page.dart';

final class ImportWordsPage extends StatefulWidget {
  const ImportWordsPage({super.key});

  @override
  State<ImportWordsPage> createState() => _ImportWordsPageState();
}

final class _ImportWordsPageState extends State<ImportWordsPage> {
  final _textController = TextEditingController();
  ImportResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_textController.text.trim().isEmpty) {
      _show('请先粘贴单词。');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await context.read<AppController>().importWords(
        _textController.text,
      );
      if (mounted) {
        setState(() => _result = result);
        _show('导入完成。');
      }
    } catch (error) {
      if (mounted) {
        _show(error.toString(), type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _completeDetails() async {
    final app = context.read<AppController>();
    if (!app.hasApiKey) {
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('需要 API Key'),
          content: const Text('请先在设置页填写 DeepSeek API Key。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );
      if (goToSettings == true && mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final count = await app.completeMissingWordDetails();
      if (mounted) {
        _show(
          count == 0 ? '没有需要补全的单词。' : '已补全 $count 个单词。',
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        _show(error.toString(), type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _show(String message, {AppSnackBarType type = AppSnackBarType.info}) {
    showAppSnackBar(context, message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入单词')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('每行一个单词，可附带中文释义；支持空格或逗号分隔。'),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            minLines: 10,
            maxLines: 18,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'abandon\nacademic 学术的\nadequate, 足够的',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.file_download_done_rounded),
            label: const Text('导入单词'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _completeDetails,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_busy ? '正在补全释义…' : 'AI 补全释义'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_result case final result?) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Count(label: '成功', value: result.imported),
                    _Count(label: '重复', value: result.duplicates),
                    _Count(label: '失败', value: result.failed),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.headlineSmall),
        Text(label),
      ],
    );
  }
}
