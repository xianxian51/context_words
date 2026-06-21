import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/word_selection_mode.dart';
import '../../providers/app_controller.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/builtin_wordbook_manager.dart';

final class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

final class _SettingsPageState extends State<SettingsPage> {
  final _apiKeyController = TextEditingController();
  final _wordCountController = TextEditingController();
  bool _obscureApiKey = true;
  bool _busy = false;
  late WordSelectionMode _selectionMode;
  late bool _autoPrepareDaily;
  late bool _autoGenerateReadings;

  @override
  void initState() {
    super.initState();
    final controller = context.read<AppController>();
    _selectionMode = controller.wordSelectionMode;
    _autoPrepareDaily = controller.autoPrepareDaily;
    _autoGenerateReadings = controller.autoGenerateReadings;
    _wordCountController.text = controller.dailyWordCount.toString();
    controller.loadApiKey().then((value) {
      if (mounted) {
        _apiKeyController.text = value;
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _wordCountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final count = int.tryParse(_wordCountController.text.trim());
    if (count == null || count < 1 || count > 100) {
      _show('每日单词数量请输入 1-100。');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppController>().saveSettings(
        apiKey: _apiKeyController.text,
        wordCount: count,
        selectionMode: _selectionMode,
        autoPrepareDaily: _autoPrepareDaily,
        autoGenerateReadings: _autoGenerateReadings,
      );
      if (mounted) {
        _show('设置已保存，仅存储在本机。', type: AppSnackBarType.success);
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

  Future<void> _testConnection() async {
    if (_apiKeyController.text.trim().isEmpty) {
      _show('请先填写 DeepSeek API Key。');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppController>().testDeepSeekConnection(
        _apiKeyController.text,
      );
      if (mounted) {
        _show('DeepSeek 连接成功。', type: AppSnackBarType.success);
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

  Future<void> _testSpeech() async {
    setState(() => _busy = true);
    try {
      await context.read<AppController>().testSpeech();
      if (mounted) {
        _show('已播放 hello。', type: AppSnackBarType.success);
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

  Future<void> _detectSpeech() async {
    setState(() => _busy = true);
    try {
      await context.read<AppController>().refreshTtsStatus();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportData() async {
    setState(() => _busy = true);
    try {
      final result = await context.read<AppController>().exportLearningData();
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('学习数据已导出'),
            content: SelectableText(
              result.shareOpened
                  ? '备份已生成，请在系统分享面板中保存。\n\n${result.path}'
                  : '备份已生成，但未能打开分享面板。\n\n${result.path}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
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

  Future<void> _importData() async {
    String? source;
    try {
      source = await context.read<AppController>().pickBackupJson();
    } catch (error) {
      if (mounted) {
        _show(error.toString(), type: AppSnackBarType.error);
      }
      return;
    }
    if (source == null || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入学习数据？'),
        content: const Text('导入备份会合并数据，可能覆盖同名单词的部分学习信息，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('合并导入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await context.read<AppController>().restoreLearningData(
        source,
      );
      if (mounted) {
        _show(
          '导入完成：新增 ${result.insertedRows} 条，合并 ${result.mergedRows} 条。',
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
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'DeepSeek API Key',
              helperText: '仅保存在本机，不会写入代码或上传。',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
                icon: Icon(
                  _obscureApiKey
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _wordCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '每日单词数量',
              helperText: '默认 20，允许 1-100。只影响下次生成计划或“再来一组”。',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text('修改每日单词数量不会影响已经生成的今日计划；如需继续学习，请在首页点击“再来一组”。'),
          const SizedBox(height: 20),
          DropdownButtonFormField<WordSelectionMode>(
            initialValue: _selectionMode,
            decoration: const InputDecoration(
              labelText: '抽词模式',
              border: OutlineInputBorder(),
            ),
            items: WordSelectionMode.values
                .map(
                  (mode) => DropdownMenuItem<WordSelectionMode>(
                    value: mode,
                    child: Text(mode.label),
                  ),
                )
                .toList(growable: false),
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectionMode = value);
                    }
                  },
          ),
          const SizedBox(height: 8),
          const Text('随机抽取可以避免连续背同一字母开头的单词，更适合长期记忆。'),
          const SizedBox(height: 20),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('每日首次打开自动准备学习内容'),
            subtitle: const Text('每天自动生成今日计划，并按下方设置准备阅读。'),
            value: _autoPrepareDaily,
            onChanged: _busy
                ? null
                : (value) => setState(() => _autoPrepareDaily = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('自动生成阅读'),
            subtitle: const Text('关闭后只自动准备今日单词，不调用 DeepSeek。'),
            value: _autoGenerateReadings,
            onChanged: _busy
                ? null
                : (value) => setState(() => _autoGenerateReadings = value),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('保存设置'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _testConnection,
            icon: const Icon(Icons.cloud_done_outlined),
            label: const Text('测试 DeepSeek 连接'),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TTS 发音',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(app.ttsStatus.label),
                  if (app.ttsStatus.language != null) ...[
                    const SizedBox(height: 4),
                    Text('当前语言：${app.ttsStatus.language}'),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('test-speech-button'),
                        onPressed: _busy ? null : _testSpeech,
                        icon: const Icon(Icons.volume_up_rounded),
                        label: const Text('测试发音'),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : _detectSpeech,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重新检测'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('数据管理', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('备份包含学习记录、星标、单词本和易混词组，不包含 DeepSeek API Key。'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        key: const Key('export-learning-data-button'),
                        onPressed: _busy ? null : _exportData,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('导出学习数据'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('import-learning-data-button'),
                        onPressed: _busy ? null : _importData,
                        icon: const Icon(Icons.file_open_rounded),
                        label: const Text('导入学习数据'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          BuiltinWordbookManagerCard(app: app),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
