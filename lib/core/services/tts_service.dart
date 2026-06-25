import 'package:flutter_tts/flutter_tts.dart';

import '../../models/tts_voice_preference.dart';
import 'settings_service.dart';

enum TtsAvailability { checking, englishAvailable, noEnglishLanguage, failed }

final class TtsDiagnostics {
  const TtsDiagnostics({
    required this.availableLanguages,
    required this.preferredLanguage,
    required this.resolvedLanguage,
    required this.isExactMatch,
    required this.isFallbackToGenericEnglish,
    required this.warningMessage,
  });

  final List<String> availableLanguages;
  final String preferredLanguage;
  final String? resolvedLanguage;
  final bool isExactMatch;
  final bool isFallbackToGenericEnglish;
  final String? warningMessage;
}

final class TtsStatus {
  const TtsStatus(this.availability, {this.language, this.diagnostics});

  final TtsAvailability availability;
  final String? language;
  final TtsDiagnostics? diagnostics;

  String? get warningMessage => diagnostics?.warningMessage;

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

typedef TtsPreferenceLoader = Future<TtsVoicePreference> Function();

final class TtsService {
  TtsService({TtsEngine? engine, TtsPreferenceLoader? preferenceLoader})
    : _engine = engine ?? FlutterTtsEngine(),
      _preferenceLoader =
          preferenceLoader ?? SettingsService().getTtsVoicePreference;

  static const failureMessage = '发音失败，请检查系统文字转语音设置。';

  final TtsEngine _engine;
  final TtsPreferenceLoader _preferenceLoader;
  TtsStatus _status = const TtsStatus(TtsAvailability.checking);
  List<String>? _availableLanguages;
  bool _detectionFailed = false;

  TtsStatus get status => _status;

  Future<TtsDiagnostics> getTtsDiagnostics({bool refresh = false}) async {
    final preference = await _preferenceLoader();
    return _getTtsDiagnosticsFor(preference, refresh: refresh);
  }

  Future<TtsDiagnostics> _getTtsDiagnosticsFor(
    TtsVoicePreference preference, {
    bool refresh = false,
  }) async {
    if (_availableLanguages == null || refresh) {
      try {
        final rawLanguages = await _engine.getLanguages();
        _availableLanguages = _parseLanguages(rawLanguages);
        _detectionFailed = false;
      } catch (_) {
        _availableLanguages = const <String>[];
        _detectionFailed = true;
      }
    }
    return diagnoseLanguages(_availableLanguages!, preference);
  }

  Future<TtsStatus> detectStatus({bool refresh = false}) async {
    final diagnostics = await getTtsDiagnostics(refresh: refresh);
    final availability = _detectionFailed
        ? TtsAvailability.failed
        : diagnostics.resolvedLanguage == null
        ? TtsAvailability.noEnglishLanguage
        : TtsAvailability.englishAvailable;
    _status = TtsStatus(
      availability,
      language: diagnostics.resolvedLanguage,
      diagnostics: diagnostics,
    );
    return _status;
  }

  Future<void> speakWord(String word) async {
    final normalizedWord = word.trim();
    if (normalizedWord.isEmpty) {
      return;
    }
    final preference = await _preferenceLoader();
    final diagnostics = await _getTtsDiagnosticsFor(preference);
    final candidates = _orderedCandidates(
      diagnostics.availableLanguages,
      preference,
    ).toList(growable: true);
    if (candidates.isEmpty) {
      candidates.addAll(<String>[?preference.targetLanguage, 'en']);
    } else if (!candidates.any(_isGenericEnglish)) {
      candidates.add('en');
    }

    try {
      await _engine.awaitSpeakCompletion(false);
      String? selectedLanguage;
      for (final language in candidates) {
        final result = await _engine.setLanguage(language);
        if (_isAccepted(result)) {
          selectedLanguage = language;
          break;
        }
      }
      if (selectedLanguage == null) {
        throw const TtsException(failureMessage);
      }
      final selectedDiagnostics = _diagnosticsForResolved(
        diagnostics.availableLanguages,
        preference,
        selectedLanguage,
      );
      _status = TtsStatus(
        TtsAvailability.englishAvailable,
        language: selectedLanguage,
        diagnostics: selectedDiagnostics,
      );
      await _engine.setVolume(1.0);
      await _engine.setSpeechRate(0.45);
      await _engine.setPitch(1.0);
      final result = await _engine.speak(normalizedWord);
      if (!_isAccepted(result)) {
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

  static TtsDiagnostics diagnoseLanguages(
    Iterable<String> languages,
    TtsVoicePreference preference,
  ) {
    final parsed = languages
        .map((language) => language.trim())
        .where((language) => language.isNotEmpty)
        .toList(growable: false);
    final candidates = _orderedCandidates(parsed, preference);
    return _diagnosticsForResolved(parsed, preference, candidates.firstOrNull);
  }

  static String? selectEnglishLanguage(Iterable<String> languages) {
    return diagnoseLanguages(
      languages,
      TtsVoicePreference.american,
    ).resolvedLanguage;
  }

  static Iterable<String> _orderedCandidates(
    Iterable<String> languages,
    TtsVoicePreference preference,
  ) {
    final entries = languages
        .map(
          (language) =>
              (original: language, normalized: _normalizeLanguage(language)),
        )
        .where(
          (entry) =>
              entry.normalized == 'en' || entry.normalized.startsWith('en-'),
        )
        .toList(growable: false);
    final ranked = switch (preference) {
      TtsVoicePreference.american =>
        <Iterable<({String original, String normalized})>>[
          entries.where((entry) => _matchesUsEnglish(entry.normalized)),
          entries.where((entry) => _matchesBritishEnglish(entry.normalized)),
          entries.where(
            (entry) =>
                entry.normalized != 'en' &&
                !_matchesUsEnglish(entry.normalized) &&
                !_matchesBritishEnglish(entry.normalized),
          ),
          entries.where((entry) => entry.normalized == 'en'),
        ],
      TtsVoicePreference.british =>
        <Iterable<({String original, String normalized})>>[
          entries.where((entry) => _matchesBritishEnglish(entry.normalized)),
          entries.where((entry) => _matchesUsEnglish(entry.normalized)),
          entries.where(
            (entry) =>
                entry.normalized != 'en' &&
                !_matchesUsEnglish(entry.normalized) &&
                !_matchesBritishEnglish(entry.normalized),
          ),
          entries.where((entry) => entry.normalized == 'en'),
        ],
      TtsVoicePreference.system =>
        <Iterable<({String original, String normalized})>>[
          entries.where((entry) => entry.normalized == 'en'),
          entries.where((entry) => entry.normalized != 'en'),
        ],
    };
    return ranked
        .expand((group) => group)
        .map((entry) => entry.original)
        .toSet();
  }

  static TtsDiagnostics _diagnosticsForResolved(
    List<String> availableLanguages,
    TtsVoicePreference preference,
    String? resolvedLanguage,
  ) {
    final normalized = resolvedLanguage == null
        ? null
        : _normalizeLanguage(resolvedLanguage);
    final target = preference.targetLanguage;
    final isExact = target != null && normalized == target.toLowerCase();
    final isGeneric = normalized == 'en';
    return TtsDiagnostics(
      availableLanguages: List<String>.unmodifiable(availableLanguages),
      preferredLanguage: target ?? 'system',
      resolvedLanguage: resolvedLanguage,
      isExactMatch: isExact,
      isFallbackToGenericEnglish: isGeneric,
      warningMessage: _warningMessage(preference, resolvedLanguage, isGeneric),
    );
  }

  static String? _warningMessage(
    TtsVoicePreference preference,
    String? resolvedLanguage,
    bool isGeneric,
  ) {
    if (resolvedLanguage == null) {
      return '当前手机未检测到可用英语 TTS，请安装或启用文字转语音引擎。';
    }
    if (isGeneric) {
      return switch (preference) {
        TtsVoicePreference.american =>
          '当前手机未检测到 en-US 美式英语语音包，已使用系统默认英语 en，发音可能不标准。请在安卓系统设置中下载或切换英语（美国）文字转语音语音包。',
        TtsVoicePreference.british =>
          '当前手机未检测到 en-GB 英式英语语音包，已使用系统默认英语 en，发音可能不标准。请在系统文字转语音设置中下载 en-GB 语音包。',
        TtsVoicePreference.system =>
          '当前设备只提供泛英语 en，发音可能和标准美式/英式不同。建议在系统文字转语音设置中下载美式英语 en-US 语音包。',
      };
    }
    final normalized = _normalizeLanguage(resolvedLanguage);
    if (preference == TtsVoicePreference.american &&
        !_matchesUsEnglish(normalized)) {
      return '当前手机未检测到 en-US 美式英语语音包，已临时使用 $resolvedLanguage。建议在系统文字转语音设置中下载 en-US。';
    }
    if (preference == TtsVoicePreference.british &&
        !_matchesBritishEnglish(normalized)) {
      return '当前手机未检测到 en-GB 英式英语语音包，已临时使用 $resolvedLanguage。建议在系统文字转语音设置中下载 en-GB。';
    }
    return null;
  }

  static List<String> _parseLanguages(dynamic rawLanguages) {
    return rawLanguages is Iterable
        ? rawLanguages
              .where((value) => value != null)
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : const <String>[];
  }

  static bool _isAccepted(dynamic result) => result == 1 || result == true;

  static bool _isGenericEnglish(String language) =>
      _normalizeLanguage(language) == 'en';

  static String _normalizeLanguage(String language) =>
      language.trim().replaceAll('_', '-').toLowerCase();

  static bool _matchesUsEnglish(String normalized) {
    final parts = normalized.split('-');
    return normalized.startsWith('en-') && parts.contains('us');
  }

  static bool _matchesBritishEnglish(String normalized) {
    final parts = normalized.split('-');
    return normalized.startsWith('en-') &&
        (parts.contains('gb') || parts.contains('uk'));
  }
}
