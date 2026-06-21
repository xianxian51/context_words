final class WordBookModel {
  const WordBookModel({
    required this.name,
    this.id,
    this.description,
    this.wordCount = 0,
    this.createdAt,
    this.updatedAt,
  }) : assert(name != '');

  final int? id;
  final String name;
  final String? description;
  final int wordCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory WordBookModel.fromMap(Map<String, Object?> map) {
    return WordBookModel(
      id: (map['id'] as num?)?.toInt(),
      name: map['name']! as String,
      description: map['description'] as String?,
      wordCount: (map['word_count'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  WordBookModel copyWith({
    String? name,
    String? description,
    int? wordCount,
    DateTime? updatedAt,
  }) {
    return WordBookModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
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
