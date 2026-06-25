import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_controller.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/passage_translation_panel.dart';
import '../../widgets/tappable_english_text.dart';
import '../../widgets/word_detail_bottom_sheet.dart';

final class ReadingPage extends StatefulWidget {
  const ReadingPage({required this.round, required this.batchNo, super.key});

  final int round;
  final int batchNo;

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

final class _ReadingPageState extends State<ReadingPage> {
  late final DateTime _startedAt = DateTime.now();
  bool _completing = false;

  Future<void> _complete() async {
    setState(() => _completing = true);
    try {
      await context.read<AppController>().completeRound(
        widget.round,
        batchNo: widget.batchNo,
        durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          '第${widget.round}轮学习已完成。',
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _completing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, app, _) {
        final passage = app.passages[widget.round];
        return Scaffold(
          appBar: AppBar(
            title: Text(
              '第${widget.batchNo}组 · '
              '${widget.round == 1 ? '阅读预热' : '语境强化'}',
            ),
          ),
          body: passage == null
              ? const Center(child: Text('本轮阅读还没有生成，请先回首页生成。'))
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Text(
                              passage.title ?? '未命名阅读',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 18),
                            TappableEnglishText(
                              text: passage.content ?? '',
                              targetWords: app.todayWords
                                  .map((item) => item.word)
                                  .toList(),
                              onWordResolved: (context, word) =>
                                  showWordDetailBottomSheet(context, word),
                            ),
                            const SizedBox(height: 20),
                            PassageTranslationPanel(
                              key: ValueKey<int?>(passage.id),
                              initialTitleCn: passage.titleCn,
                              initialTranslationCn: passage.translationCn,
                              initialSentencePairsJson:
                                  passage.sentencePairsJson,
                              initialKeyWordNotesJson: passage.keyWordNotesJson,
                              onTranslate: ({required force}) =>
                                  app.translateReadingPassage(
                                    passage,
                                    force: force,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _completing ? null : _complete,
                            icon: Icon(
                              app.completedRounds.contains(widget.round)
                                  ? Icons.check_circle_rounded
                                  : Icons.task_alt_rounded,
                            ),
                            label: Text(
                              app.completedRounds.contains(widget.round)
                                  ? '本轮已完成，再次记录'
                                  : '完成本轮学习',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
