import 'word_model.dart';

final class PlanWordModel {
  const PlanWordModel({
    required this.word,
    this.batchNo = 1,
    this.memoryStatus = 'new',
    this.reviewCount = 0,
    this.lastReviewedAt,
  });

  final WordModel word;
  final int batchNo;
  final String memoryStatus;
  final int reviewCount;
  final DateTime? lastReviewedAt;

  PlanWordModel copyWith({
    WordModel? word,
    int? batchNo,
    String? memoryStatus,
    int? reviewCount,
    DateTime? lastReviewedAt,
  }) {
    return PlanWordModel(
      word: word ?? this.word,
      batchNo: batchNo ?? this.batchNo,
      memoryStatus: memoryStatus ?? this.memoryStatus,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}
