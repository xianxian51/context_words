import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

final class AiMarkdownBody extends StatelessWidget {
  const AiMarkdownBody({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MarkdownBody(
      data: data,
      selectable: true,
      fitContent: true,
      onTapLink: (_, _, _) {},
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: textTheme.bodyMedium?.copyWith(height: 1.55),
        h1: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        h2: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        listBullet: textTheme.bodyMedium,
        blockSpacing: 10,
      ),
    );
  }
}
