import 'package:context_words/models/deepseek_models.dart';
import 'package:context_words/widgets/passage_translation_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new translation requires confirmation before the request', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassageTranslationPanel(
            onTranslate: ({required force}) async {
              calls++;
              return const PassageTranslation(
                titleCn: '校园',
                translationCn: '语境帮助记忆。',
              );
            },
          ),
        ),
      ),
    );

    expect(calls, 0);
    await tester.tap(find.text('全文翻译'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(calls, 0);

    await tester.tap(find.text('全文翻译'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '翻译'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('校园'), findsOneWidget);
    expect(find.text('语境帮助记忆。'), findsOneWidget);
  });

  testWidgets('cached translation opens locally without a request', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassageTranslationPanel(
            initialTranslationCn: '本地缓存翻译。',
            onTranslate: ({required force}) async {
              calls++;
              return const PassageTranslation(translationCn: '远程翻译。');
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('查看翻译'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.text('本地缓存翻译。'), findsOneWidget);
    expect(find.text('收起翻译'), findsOneWidget);
  });
}
