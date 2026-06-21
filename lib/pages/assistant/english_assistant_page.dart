import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/assistant_message.dart';
import '../../providers/app_controller.dart';
import '../../widgets/ai_markdown_body.dart';
import '../../widgets/app_snack_bar.dart';

final class EnglishAssistantPage extends StatefulWidget {
  const EnglishAssistantPage({super.key});

  @override
  State<EnglishAssistantPage> createState() => _EnglishAssistantPageState();
}

final class _EnglishAssistantPageState extends State<EnglishAssistantPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <AssistantMessage>[];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _inputController.text.trim();
    if (question.isEmpty || _sending) {
      return;
    }
    if (!context.read<AppController>().hasApiKey) {
      showAppSnackBar(context, '请先在设置页填写 DeepSeek API Key。');
      return;
    }
    _inputController.clear();
    setState(() {
      _messages.add(
        AssistantMessage(role: AssistantRole.user, content: question),
      );
      _error = null;
    });
    await _requestReply();
  }

  Future<void> _requestReply() async {
    if (_sending ||
        _messages.isEmpty ||
        _messages.last.role != AssistantRole.user) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    _scrollToBottom();
    try {
      final reply = await context.read<AppController>().askEnglishAssistant(
        List<AssistantMessage>.unmodifiable(_messages),
      );
      if (mounted) {
        setState(() {
          _messages.add(
            AssistantMessage(role: AssistantRole.assistant, content: reply),
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('英语助手')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const _AssistantEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const _LoadingBubble();
                        }
                        return _MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            if (_error != null)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(_error!)),
                      TextButton(
                        onPressed: _sending ? null : _requestReply,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 4000,
                        decoration: const InputDecoration(
                          hintText: '问单词、易混词、长难句或作文表达…',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: '发送',
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_outlined, size: 52),
            const SizedBox(height: 12),
            Text('英语助手', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              '可以解释单词、辨析易混词、拆解长难句或优化作文表达。只有点击发送后才会调用 DeepSeek。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

final class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AssistantRole.user;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: isUser ? colors.primaryContainer : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: isUser
            ? SelectableText(message.content)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: AiMarkdownBody(data: message.content)),
                  IconButton(
                    tooltip: '复制回复',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: message.content),
                      );
                      if (context.mounted) {
                        showAppSnackBar(
                          context,
                          '回复已复制。',
                          type: AppSnackBarType.success,
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 19),
                  ),
                ],
              ),
      ),
    );
  }
}

final class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('英语助手正在思考…'),
          ],
        ),
      ),
    );
  }
}
