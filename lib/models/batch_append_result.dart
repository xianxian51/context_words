import 'daily_plan_model.dart';

final class BatchAppendResult {
  const BatchAppendResult({
    required this.batchNo,
    required this.addedCount,
    required this.remainingAvailableCount,
    required this.todayTotalWordCount,
    this.plan,
  });

  final DailyPlanModel? plan;
  final int batchNo;
  final int addedCount;
  final int remainingAvailableCount;
  final int todayTotalWordCount;
}
