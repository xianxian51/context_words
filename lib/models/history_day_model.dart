import 'daily_plan_model.dart';
import 'plan_word_model.dart';

final class HistoryDayModel {
  const HistoryDayModel({
    required this.plan,
    required this.words,
    required this.completedRoundsByBatch,
  });

  final DailyPlanModel plan;
  final List<PlanWordModel> words;
  final Map<int, Set<int>> completedRoundsByBatch;
}
