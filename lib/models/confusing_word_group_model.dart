final class ConfusingWordGroupModel {
  const ConfusingWordGroupModel({
    required this.title,
    this.id,
    this.description,
    this.analysis,
    this.wordCount = 0,
    this.createdAt,
    this.updatedAt,
  }) : assert(title != '');

  final int? id;
  final String title;
  final String? description;
  final String? analysis;
  final int wordCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ConfusingWordGroupModel.fromMap(Map<String, Object?> map) {
    return ConfusingWordGroupModel(
      id: (map['id'] as num?)?.toInt(),
      title: map['title']! as String,
      description: map['description'] as String?,
      analysis: map['analysis'] as String?,
      wordCount: (map['word_count'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'title': title,
      'description': description,
      'analysis': analysis,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ConfusingWordGroupModel copyWith({
    String? title,
    String? description,
    String? analysis,
    int? wordCount,
    DateTime? updatedAt,
  }) {
    return ConfusingWordGroupModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      analysis: analysis ?? this.analysis,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
