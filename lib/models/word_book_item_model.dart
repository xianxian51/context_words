final class WordBookItemModel {
  const WordBookItemModel({
    required this.wordBookId,
    required this.wordId,
    this.id,
    this.createdAt,
  });

  final int? id;
  final int wordBookId;
  final int wordId;
  final DateTime? createdAt;

  factory WordBookItemModel.fromMap(Map<String, Object?> map) {
    return WordBookItemModel(
      id: (map['id'] as num?)?.toInt(),
      wordBookId: (map['word_book_id']! as num).toInt(),
      wordId: (map['word_id']! as num).toInt(),
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'word_book_id': wordBookId,
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
