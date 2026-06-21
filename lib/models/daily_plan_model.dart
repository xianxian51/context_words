final class DailyPlanModel {
  const DailyPlanModel({
    required this.date,
    this.id,
    this.wordCount = 0,
    this.status = 'pending',
    this.createdAt,
  });

  final int? id;
  final DateTime date;
  final int wordCount;
  final String status;
  final DateTime? createdAt;

  factory DailyPlanModel.fromMap(Map<String, Object?> map) {
    return DailyPlanModel(
      id: (map['id'] as num?)?.toInt(),
      date: DateTime.parse(map['date']! as String),
      wordCount: (map['word_count'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'pending',
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'date': dateKey(date),
      'word_count': wordCount,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  static String dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
