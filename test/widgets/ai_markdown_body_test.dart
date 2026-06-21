import 'package:context_words/widgets/ai_markdown_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders assistant headings, lists, and emphasis as Markdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiMarkdownBody(
            data: '# Context\n\n- **Meaning:** 语境\n- Example sentence',
          ),
        ),
      ),
    );

    expect(find.text('Context'), findsOneWidget);
    expect(find.textContaining('Meaning:'), findsOneWidget);
    expect(find.textContaining('Example sentence'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
