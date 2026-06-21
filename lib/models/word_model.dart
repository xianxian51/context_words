final class WordModel {
  const WordModel({
    required this.word,
    this.id,
    this.phonetic,
    this.partOfSpeech,
    this.meaningCn,
    this.meaningEn,
    this.exampleSentence,
    this.phrase,
    this.synonyms,
    this.difficulty,
    this.source,
    this.isStarred = false,
    this.aiGenerated = false,
    this.createdAt,
    this.updatedAt,
  }) : assert(word != '');

  final int? id;
  final String word;
  final String? phonetic;
  final String? partOfSpeech;
  final String? meaningCn;
  final String? meaningEn;
  final String? exampleSentence;
  final String? phrase;
  final String? synonyms;
  final String? difficulty;
  final String? source;
  final bool isStarred;
  final bool aiGenerated;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory WordModel.fromMap(Map<String, Object?> map) {
    return WordModel(
      id: (map['id'] as num?)?.toInt(),
      word: map['word']! as String,
      phonetic: map['phonetic'] as String?,
      partOfSpeech: map['part_of_speech'] as String?,
      meaningCn: map['meaning_cn'] as String?,
      meaningEn: map['meaning_en'] as String?,
      exampleSentence: map['example_sentence'] as String?,
      phrase: map['phrase'] as String?,
      synonyms: map['synonyms'] as String?,
      difficulty: map['difficulty'] as String?,
      source: map['source'] as String?,
      isStarred: map['is_starred'] == 1,
      aiGenerated: map['ai_generated'] == 1,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'word': word,
      'phonetic': phonetic,
      'part_of_speech': partOfSpeech,
      'meaning_cn': meaningCn,
      'meaning_en': meaningEn,
      'example_sentence': exampleSentence,
      'phrase': phrase,
      'synonyms': synonyms,
      'difficulty': difficulty,
      'source': source,
      'is_starred': isStarred ? 1 : 0,
      'ai_generated': aiGenerated ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  WordModel copyWith({
    String? phonetic,
    String? partOfSpeech,
    String? meaningCn,
    String? meaningEn,
    String? exampleSentence,
    String? phrase,
    String? synonyms,
    String? difficulty,
    String? source,
    bool? isStarred,
    bool? aiGenerated,
  }) {
    return WordModel(
      id: id,
      word: word,
      phonetic: phonetic ?? this.phonetic,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      meaningCn: meaningCn ?? this.meaningCn,
      meaningEn: meaningEn ?? this.meaningEn,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      phrase: phrase ?? this.phrase,
      synonyms: synonyms ?? this.synonyms,
      difficulty: difficulty ?? this.difficulty,
      source: source ?? this.source,
      isStarred: isStarred ?? this.isStarred,
      aiGenerated: aiGenerated ?? this.aiGenerated,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
