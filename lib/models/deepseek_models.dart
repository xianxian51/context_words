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
  const PassageTranslation({this.titleCn, required this.translationCn});

  final String? titleCn;
  final String translationCn;
}
