import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/word_model.dart';
import '../../models/wordbook_upgrade_result.dart';
import '../../repositories/word_repository.dart';

final class WordbookService {
  WordbookService({WordRepository? wordRepository})
    : _wordRepository = wordRepository ?? WordRepository();

  static const builtinCet6Asset = 'assets/wordbooks/cet6.json';

  final WordRepository _wordRepository;

  Future<List<WordModel>> loadBuiltinCet6Wordbook() async {
    final text = await rootBundle.loadString(builtinCet6Asset);
    final decoded = jsonDecode(text);
    if (decoded is! List) {
      throw const FormatException('内置六级词库格式错误。');
    }
    return decoded
        .map((item) {
          if (item is! Map) {
            throw const FormatException('内置六级词库条目格式错误。');
          }
          final map = Map<String, Object?>.from(item);
          return WordModel(
            word: _requiredString(map, 'word').toLowerCase(),
            phonetic: _optionalString(map['phonetic']),
            partOfSpeech: _optionalString(map['part_of_speech']),
            meaningCn: _optionalString(map['meaning_cn']),
            meaningEn: _optionalString(map['meaning_en']),
            exampleSentence: _optionalString(map['example_sentence']),
            phrase: _joinStringList(map['phrase']),
            synonyms: _joinStringList(map['synonyms']),
            difficulty: _optionalString(map['difficulty']) ?? 'cet6',
            source: _optionalString(map['source']) ?? 'cet6_builtin',
          );
        })
        .toList(growable: false);
  }

  Future<int> getBuiltinCet6Count() async {
    return (await loadBuiltinCet6Wordbook()).length;
  }

  Future<WordbookUpgradeResult> importBuiltinCet6IfNeeded() async {
    final words = await loadBuiltinCet6Wordbook();
    return _wordRepository.mergeBuiltinWords(words);
  }

  String _requiredString(Map<String, Object?> map, String key) {
    final value = _optionalString(map[key]);
    if (value == null) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  String? _optionalString(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  String? _joinStringList(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value.trim().isEmpty ? null : value.trim();
    }
    if (value is! List || value.any((item) => item is! String)) {
      throw const FormatException('Expected a string array.');
    }
    final joined = value
        .cast<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join(', ');
    return joined.isEmpty ? null : joined;
  }
}
