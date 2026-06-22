import 'package:context_words/pages/home/home_page.dart';
import 'package:context_words/pages/settings/settings_page.dart';
import 'package:context_words/providers/app_controller.dart';
import 'package:context_words/core/services/tts_service.dart';
import 'package:context_words/models/daily_plan_model.dart';
import 'package:context_words/models/plan_word_model.dart';
import 'package:context_words/models/word_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('shows the usable home screen and empty-library guidance', (
    tester,
  ) async {
    final controller = AppController()
      ..isLoading = false
      ..totalWordCount = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const MaterialApp(home: HomePage()),
      ),
    );

    expect(find.text('语境单词本'), findsOneWidget);
    expect(find.text('三遍语境记忆'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -550));
    await tester.pumpAndSettle();
    expect(find.textContaining('更多 / 管理 / 高级操作'), findsWidgets);
    expect(find.text('开始学习'), findsOneWidget);
    expect(find.text('导入单词'), findsNothing);

    controller.dispose();
  });

  testWidgets('shows current batch selector and append-batch action', (
    tester,
  ) async {
    final controller = AppController()
      ..isLoading = false
      ..totalWordCount = 5406
      ..builtinCet6Count = 5406
      ..todayPlan = DailyPlanModel(date: DateTime(2026, 6, 18), wordCount: 2)
      ..todayBatches = const <int>[1, 2]
      ..selectedBatchNo = 2
      ..allTodayWords = const <PlanWordModel>[
        PlanWordModel(word: WordModel(word: 'first'), batchNo: 1),
        PlanWordModel(word: WordModel(word: 'second'), batchNo: 2),
      ]
      ..todayWords = const <PlanWordModel>[
        PlanWordModel(word: WordModel(word: 'second'), batchNo: 2),
      ];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const MaterialApp(home: HomePage()),
      ),
    );

    expect(find.text('当前学习组'), findsOneWidget);
    expect(find.text('第 2 组'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('再来一组'), findsOneWidget);
    expect(find.text('更多学习入口'), findsOneWidget);
    expect(find.text('导入单词'), findsNothing);

    controller.dispose();
  });

  testWidgets('settings exposes selection, TTS, and data management controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = AppController()
      ..isLoading = false
      ..ttsStatus = const TtsStatus(
        TtsAvailability.englishAvailable,
        language: 'en',
        diagnostics: TtsDiagnostics(
          availableLanguages: <String>['en'],
          preferredLanguage: 'en-US',
          resolvedLanguage: 'en',
          isExactMatch: false,
          isFallbackToGenericEnglish: true,
          warningMessage: '当前手机未检测到 en-US 美式英语语音包。',
        ),
      );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('抽词模式'), findsOneWidget);
    expect(find.text('随机抽取'), findsOneWidget);
    expect(find.text('DeepSeek 模型'), findsOneWidget);
    expect(find.text('每日首次打开自动准备学习内容'), findsOneWidget);
    expect(find.text('启动时检查更新'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('自动生成阅读'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('自动生成阅读'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('测试发音 academic'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('已检测到英文 TTS'), findsOneWidget);
    expect(find.text('发音设置'), findsOneWidget);
    expect(find.text('美式发音 en-US'), findsOneWidget);
    expect(find.text('当前使用：en'), findsOneWidget);
    expect(find.textContaining('未检测到 en-US'), findsOneWidget);
    expect(find.text('测试发音 academic'), findsOneWidget);
    expect(find.text('刷新 TTS 状态'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('导出学习数据'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('导出学习数据'), findsOneWidget);
    expect(find.text('导入学习数据'), findsOneWidget);

    controller.dispose();
  });
}
