import 'daily_plan_model.dart';

final class PlanGenerationResult {
  const PlanGenerationResult({
    this.plan,
    this.alreadyExisted = false,
    this.requestedCount = 0,
    this.actualCount = 0,
  });

  final DailyPlanModel? plan;
  final bool alreadyExisted;
  final int requestedCount;
  final int actualCount;

  bool get hasShortage => actualCount < requestedCount;
}
