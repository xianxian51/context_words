import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home/home_page.dart';
import 'providers/app_controller.dart';

final class ContextWordsApp extends StatelessWidget {
  const ContextWordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppController>(
      create: (_) => AppController()..initialize(),
      child: MaterialApp(
        title: '语境单词本',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF28766B)),
          scaffoldBackgroundColor: const Color(0xFFF7F9F7),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
