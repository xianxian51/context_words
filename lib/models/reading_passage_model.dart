import 'dart:convert';

final class ReadingPassageModel {
  const ReadingPassageModel({
    required this.planId,
    required this.round,
    this.batchNo = 1,
    this.id,
    this.title,
    this.content,
    this.usedWords = const <String>[],
    this.titleCn,
    this.translationCn,
    this.translatedAt,
    this.aiGenerated = false,
    this.createdAt,
  }) : assert(round == 1 || round == 2);

  final int? id;
  final int planId;
  final int batchNo;
  final int round;
  final String? title;
  final String? content;
  final List<String> usedWords;
  final String? titleCn;
  final String? translationCn;
  final DateTime? translatedAt;
  final bool aiGenerated;
  final DateTime? createdAt;

  factory ReadingPassageModel.fromMap(Map<String, Object?> map) {
    return ReadingPassageModel(
      id: (map['id'] as num?)?.toInt(),
      planId: (map['plan_id']! as num).toInt(),
      batchNo: (map['batch_no'] as num?)?.toInt() ?? 1,
      round: (map['round']! as num).toInt(),
      title: map['title'] as String?,
      content: map['content'] as String?,
      usedWords: _decodeUsedWords(map['used_words']),
      titleCn: map['title_cn'] as String?,
      translationCn: map['translation_cn'] as String?,
      translatedAt: _parseDateTime(map['translated_at']),
      aiGenerated: map['ai_generated'] == 1,
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'plan_id': planId,
      'batch_no': batchNo,
      'round': round,
      'title': title,
      'content': content,
      'used_words': jsonEncode(usedWords),
      'title_cn': titleCn,
      'translation_cn': translationCn,
      'translated_at': translatedAt?.toIso8601String(),
      'ai_generated': aiGenerated ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  ReadingPassageModel copyWith({
    String? titleCn,
    String? translationCn,
    DateTime? translatedAt,
  }) {
    return ReadingPassageModel(
      id: id,
      planId: planId,
      batchNo: batchNo,
      round: round,
      title: title,
      content: content,
      usedWords: usedWords,
      titleCn: titleCn ?? this.titleCn,
      translationCn: translationCn ?? this.translationCn,
      translatedAt: translatedAt ?? this.translatedAt,
      aiGenerated: aiGenerated,
      createdAt: createdAt,
    );
  }
}

List<String> _decodeUsedWords(Object? value) {
  if (value == null || value == '') {
    return const <String>[];
  }
  if (value is! String) {
    throw const FormatException('used_words must be a JSON string');
  }

  final decoded = jsonDecode(value);
  if (decoded is! List<Object?> || decoded.any((item) => item is! String)) {
    throw const FormatException('used_words must be a JSON string list');
  }
  return List<String>.unmodifiable(decoded.cast<String>());
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
