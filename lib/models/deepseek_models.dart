import 'dart:convert';

final class DeepSeekWordDetails {
  const DeepSeekWordDetails({
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    this.meaningCn,
    this.meaningEn,
    this.exampleSentence,
    this.phrases = const <String>[],
    this.synonyms = const <String>[],
  });

  final String word;
  final String? phonetic;
  final String? partOfSpeech;
  final String? meaningCn;
  final String? meaningEn;
  final String? exampleSentence;
  final List<String> phrases;
  final List<String> synonyms;
}

final class GeneratedPassage {
  const GeneratedPassage({
    required this.title,
    required this.content,
    required this.usedWords,
  });

  final String title;
  final String content;
  final List<String> usedWords;
}

final class PassageTranslation {
  const PassageTranslation({
    this.titleCn,
    required this.translationCn,
    this.sentencePairs = const <TranslationSentencePair>[],
    this.keyWordNotes = const <TranslationKeyWordNote>[],
  });

  final String? titleCn;
  final String translationCn;
  final List<TranslationSentencePair> sentencePairs;
  final List<TranslationKeyWordNote> keyWordNotes;
}

final class TranslationSentencePair {
  const TranslationSentencePair({required this.en, required this.zh});

  final String en;
  final String zh;
}

final class TranslationKeyWordNote {
  const TranslationKeyWordNote({
    required this.word,
    required this.meaningInContext,
    required this.sentence,
  });

  final String word;
  final String meaningInContext;
  final String sentence;
}

String encodeTranslationSentencePairs(
  List<TranslationSentencePair> sentencePairs,
) {
  return jsonEncode(
    sentencePairs
        .map((pair) => <String, String>{'en': pair.en, 'zh': pair.zh})
        .toList(growable: false),
  );
}

String encodeTranslationKeyWordNotes(List<TranslationKeyWordNote> notes) {
  return jsonEncode(
    notes
        .map(
          (note) => <String, String>{
            'word': note.word,
            'meaning_in_context': note.meaningInContext,
            'sentence': note.sentence,
          },
        )
        .toList(growable: false),
  );
}

List<TranslationSentencePair> decodeTranslationSentencePairs(String? source) {
  if (source == null || source.trim().isEmpty) {
    return const <TranslationSentencePair>[];
  }
  try {
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      return const <TranslationSentencePair>[];
    }
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .map(
          (item) => TranslationSentencePair(
            en: _asNonEmptyString(item['en']),
            zh: _asNonEmptyString(item['zh']),
          ),
        )
        .where((pair) => pair.en.isNotEmpty && pair.zh.isNotEmpty)
        .toList(growable: false);
  } on FormatException {
    return const <TranslationSentencePair>[];
  }
}

List<TranslationKeyWordNote> decodeTranslationKeyWordNotes(String? source) {
  if (source == null || source.trim().isEmpty) {
    return const <TranslationKeyWordNote>[];
  }
  try {
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      return const <TranslationKeyWordNote>[];
    }
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .map(
          (item) => TranslationKeyWordNote(
            word: _asNonEmptyString(item['word']).toLowerCase(),
            meaningInContext: _asNonEmptyString(item['meaning_in_context']),
            sentence: _asNonEmptyString(item['sentence']),
          ),
        )
        .where((note) => note.word.isNotEmpty)
        .toList(growable: false);
  } on FormatException {
    return const <TranslationKeyWordNote>[];
  }
}

String _asNonEmptyString(Object? value) {
  if (value is! String) {
    return '';
  }
  return value.trim();
}
