import 'dart:convert';

final class CollectionPassageModel {
  const CollectionPassageModel({
    this.id,
    required this.sourceType,
    required this.sourceId,
    this.title,
    this.content,
    this.usedWords = const <String>[],
    this.titleCn,
    this.translationCn,
    this.translatedAt,
    this.createdAt,
  });

  final int? id;
  final String sourceType;
  final int sourceId;
  final String? title;
  final String? content;
  final List<String> usedWords;
  final String? titleCn;
  final String? translationCn;
  final DateTime? translatedAt;
  final DateTime? createdAt;

  Map<String, Object?> toMap({bool includeId = true}) => <String, Object?>{
    if (includeId) 'id': id,
    'source_type': sourceType,
    'source_id': sourceId,
    'title': title,
    'content': content,
    'used_words': jsonEncode(usedWords),
    'title_cn': titleCn,
    'translation_cn': translationCn,
    'translated_at': translatedAt?.toUtc().toIso8601String(),
    'created_at': createdAt?.toUtc().toIso8601String(),
  };

  factory CollectionPassageModel.fromMap(Map<String, Object?> map) {
    final rawWords = map['used_words'];
    Object? decoded = const <Object?>[];
    if (rawWords is String && rawWords.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(rawWords);
      } on FormatException {
        decoded = const <Object?>[];
      }
    }
    return CollectionPassageModel(
      id: (map['id'] as num?)?.toInt(),
      sourceType: map['source_type']! as String,
      sourceId: (map['source_id']! as num).toInt(),
      title: map['title'] as String?,
      content: map['content'] as String?,
      usedWords: decoded is List
          ? decoded.whereType<String>().toList(growable: false)
          : const <String>[],
      titleCn: map['title_cn'] as String?,
      translationCn: map['translation_cn'] as String?,
      translatedAt: DateTime.tryParse(map['translated_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }

  CollectionPassageModel copyWith({
    String? titleCn,
    String? translationCn,
    DateTime? translatedAt,
  }) {
    return CollectionPassageModel(
      id: id,
      sourceType: sourceType,
      sourceId: sourceId,
      title: title,
      content: content,
      usedWords: usedWords,
      titleCn: titleCn ?? this.titleCn,
      translationCn: translationCn ?? this.translationCn,
      translatedAt: translatedAt ?? this.translatedAt,
      createdAt: createdAt,
    );
  }
}
