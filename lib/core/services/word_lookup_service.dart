import 'package:sqflite/sqflite.dart';

import '../../models/deepseek_models.dart';
import '../../models/word_model.dart';
import '../../repositories/word_repository.dart';
import 'deepseek_service.dart';
import 'settings_service.dart';

final class WordLookupService {
  WordLookupService({
    required WordRepository wordRepository,
    required SettingsService settingsService,
    required DeepSeekService deepSeekService,
  }) : this._(wordRepository, settingsService, deepSeekService);

  WordLookupService._(
    this._wordRepository,
    this._settingsService,
    this._deepSeekService,
  );

  final WordRepository _wordRepository;
  final SettingsService _settingsService;
  final DeepSeekService _deepSeekService;
  final Map<String, Future<WordModel?>> _inFlight =
      <String, Future<WordModel?>>{};

  static const ignoredWords = <String>{
    'a',
    'an',
    'the',
    'is',
    'are',
    'am',
    'was',
    'were',
    'be',
    'been',
    'being',
    'to',
    'of',
    'in',
    'on',
    'at',
    'for',
    'and',
    'or',
    'but',
  };

  static String? normalizeWord(String rawWord) {
    var value = rawWord.trim().toLowerCase().replaceAll('’', "'");
    value = value.replaceAll(RegExp(r"^[^a-z]+|[^a-z]+$"), '');
    if (value.isEmpty || !RegExp(r'[a-z]').hasMatch(value)) {
      return null;
    }
    return value;
  }

  static bool shouldIgnore(String rawWord) {
    final normalized = normalizeWord(rawWord);
    return normalized == null ||
        normalized.length <= 1 ||
        ignoredWords.contains(normalized);
  }

  Future<WordModel?> lookupWord(
    String rawWord, {
    required bool allowRemoteLookup,
  }) async {
    final normalized = normalizeWord(rawWord);
    if (normalized == null || shouldIgnore(normalized)) {
      return null;
    }

    final local = await _wordRepository.findByWord(normalized);
    if (local != null) {
      return local;
    }
    if (!allowRemoteLookup) {
      return null;
    }

    return _inFlight.putIfAbsent(normalized, () async {
      try {
        final apiKey = await _settingsService.getApiKey();
        if (apiKey.trim().isEmpty) {
          throw const DeepSeekException('请先在设置页填写 DeepSeek API Key。');
        }
        final detail = await _deepSeekService.lookupSingleWord(
          normalized,
          apiKey: apiKey,
        );
        return _saveLookupResult(detail, fallbackWord: normalized);
      } finally {
        _inFlight.remove(normalized);
      }
    });
  }

  Future<WordModel> _saveLookupResult(
    DeepSeekWordDetails detail, {
    required String fallbackWord,
  }) async {
    final normalized = normalizeWord(detail.word) ?? fallbackWord;
    final existing = await _wordRepository.findByWord(normalized);
    if (existing != null) {
      return existing;
    }

    final word = WordModel(
      word: normalized,
      phonetic: detail.phonetic,
      partOfSpeech: detail.partOfSpeech,
      meaningCn: detail.meaningCn,
      meaningEn: detail.meaningEn,
      exampleSentence: detail.exampleSentence,
      phrase: detail.phrases.join(', '),
      synonyms: detail.synonyms.join(', '),
      source: 'ai_lookup',
      aiGenerated: true,
    );
    try {
      return await _wordRepository.create(word);
    } on DatabaseException {
      final duplicated = await _wordRepository.findByWord(normalized);
      if (duplicated != null) {
        return duplicated;
      }
      rethrow;
    }
  }
}
