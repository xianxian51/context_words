import 'package:flutter_tts/flutter_tts.dart';

enum TtsAvailability { checking, englishAvailable, noEnglishLanguage, failed }

final class TtsStatus {
  const TtsStatus(this.availability, {this.language});

  final TtsAvailability availability;
  final String? language;

  String get label => switch (availability) {
    TtsAvailability.checking => '正在检测 TTS…',
    TtsAvailability.englishAvailable => '已检测到英文 TTS',
    TtsAvailability.noEnglishLanguage => '未检测到英文 TTS',
    TtsAvailability.failed => 'TTS 检测失败',
  };
}

final class TtsException implements Exception {
  const TtsException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class TtsEngine {
  Future<dynamic> getLanguages();
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion);
  Future<dynamic> setLanguage(String language);
  Future<dynamic> setSpeechRate(double rate);
  Future<dynamic> setVolume(double volume);
  Future<dynamic> setPitch(double pitch);
  Future<dynamic> speak(String text);
  Future<dynamic> stop();
}

final class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine([FlutterTts? flutterTts])
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  @override
  Future<dynamic> getLanguages() => _flutterTts.getLanguages;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) =>
      _flutterTts.awaitSpeakCompletion(awaitCompletion);

  @override
  Future<dynamic> setLanguage(String language) =>
      _flutterTts.setLanguage(language);

  @override
  Future<dynamic> setSpeechRate(double rate) => _flutterTts.setSpeechRate(rate);

  @override
  Future<dynamic> setVolume(double volume) => _flutterTts.setVolume(volume);

  @override
  Future<dynamic> setPitch(double pitch) => _flutterTts.setPitch(pitch);

  @override
  Future<dynamic> speak(String text) => _flutterTts.speak(text, focus: true);

  @override
  Future<dynamic> stop() => _flutterTts.stop();
}

final class TtsService {
  TtsService({TtsEngine? engine}) : _engine = engine ?? FlutterTtsEngine();

  static const failureMessage = '发音失败，请检查手机系统文字转语音设置和媒体音量。';

  final TtsEngine _engine;
  TtsStatus _status = const TtsStatus(TtsAvailability.checking);
  bool _hasDetectedLanguages = false;

  TtsStatus get status => _status;

  Future<TtsStatus> detectStatus({bool refresh = false}) async {
    if (_hasDetectedLanguages && !refresh) {
      return _status;
    }
    try {
      final rawLanguages = await _engine.getLanguages();
      final languages = rawLanguages is Iterable
          ? rawLanguages
                .where((value) => value != null)
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      final language = selectEnglishLanguage(languages);
      _status = language == null
          ? const TtsStatus(
              TtsAvailability.noEnglishLanguage,
              language: 'en-US',
            )
          : TtsStatus(TtsAvailability.englishAvailable, language: language);
    } catch (_) {
      _status = const TtsStatus(TtsAvailability.failed, language: 'en-US');
    }
    _hasDetectedLanguages = true;
    return _status;
  }

  Future<void> speakWord(String word) async {
    final normalized = word.trim();
    if (normalized.isEmpty) {
      return;
    }
    final currentStatus = await detectStatus();
    try {
      await _engine.awaitSpeakCompletion(false);
      await _engine.setLanguage(currentStatus.language ?? 'en-US');
      await _engine.setVolume(1.0);
      await _engine.setSpeechRate(0.45);
      await _engine.setPitch(1.0);
      final result = await _engine.speak(normalized);
      if (result != 1 && result != true) {
        throw const TtsException(failureMessage);
      }
    } on TtsException {
      rethrow;
    } catch (_) {
      throw const TtsException(failureMessage);
    }
  }

  Future<void> dispose() async {
    try {
      await _engine.stop();
    } catch (_) {
      // Best-effort cleanup only; disposal must not crash the app.
    }
  }

  static String? selectEnglishLanguage(Iterable<String> languages) {
    final entries = languages
        .map(
          (language) => (
            original: language,
            normalized: language.replaceAll('_', '-').toLowerCase(),
          ),
        )
        .toList(growable: false);
    for (final preferred in const <String>['en-us', 'en-gb']) {
      for (final entry in entries) {
        if (entry.normalized == preferred) {
          return entry.original;
        }
      }
    }
    for (final entry in entries) {
      if (entry.normalized == 'en' || entry.normalized.startsWith('en-')) {
        return entry.original;
      }
    }
    return null;
  }
}
