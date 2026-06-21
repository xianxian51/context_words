final class ConfusingWordGroupItemModel {
  const ConfusingWordGroupItemModel({
    required this.groupId,
    required this.wordId,
    this.id,
    this.createdAt,
  });

  final int? id;
  final int groupId;
  final int wordId;
  final DateTime? createdAt;

  factory ConfusingWordGroupItemModel.fromMap(Map<String, Object?> map) {
    return ConfusingWordGroupItemModel(
      id: (map['id'] as num?)?.toInt(),
      groupId: (map['group_id']! as num).toInt(),
      wordId: (map['word_id']! as num).toInt(),
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'group_id': groupId,
      'word_id': wordId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
