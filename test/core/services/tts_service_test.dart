import 'package:context_words/core/services/tts_service.dart';
import 'package:context_words/models/tts_voice_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('American preference selects en-US before every fallback', () {
    final diagnostics = TtsService.diagnoseLanguages(<String>[
      'en',
      'en-GB',
      'en-US',
    ], TtsVoicePreference.american);

    expect(diagnostics.preferredLanguage, 'en-US');
    expect(diagnostics.resolvedLanguage, 'en-US');
    expect(diagnostics.isExactMatch, isTrue);
    expect(diagnostics.isFallbackToGenericEnglish, isFalse);
    expect(diagnostics.warningMessage, isNull);
  });

  test('American preference never selects generic en before en-GB', () {
    final diagnostics = TtsService.diagnoseLanguages(<String>[
      'en',
      'zh-CN',
      'en-GB',
    ], TtsVoicePreference.american);

    expect(diagnostics.resolvedLanguage, 'en-GB');
    expect(diagnostics.isFallbackToGenericEnglish, isFalse);
    expect(diagnostics.warningMessage, contains('en-US'));
  });

  test('American aliases and regional variants are preferred', () {
    expect(
      TtsService.diagnoseLanguages(<String>[
        'en',
        'en_US',
      ], TtsVoicePreference.american).resolvedLanguage,
      'en_US',
    );
    expect(
      TtsService.diagnoseLanguages(<String>[
        'en',
        'en-US-x-tpf',
      ], TtsVoicePreference.american).resolvedLanguage,
      'en-US-x-tpf',
    );
  });

  test('British preference selects en-GB before en-US and en', () {
    final diagnostics = TtsService.diagnoseLanguages(<String>[
      'en',
      'en-US',
      'en_GB',
    ], TtsVoicePreference.british);

    expect(diagnostics.resolvedLanguage, 'en_GB');
    expect(diagnostics.isExactMatch, isTrue);
  });

  test('generic en is explicitly marked as a warned fallback', () {
    final diagnostics = TtsService.diagnoseLanguages(<String>[
      'zh-CN',
      'en',
    ], TtsVoicePreference.american);

    expect(diagnostics.availableLanguages, <String>['zh-CN', 'en']);
    expect(diagnostics.resolvedLanguage, 'en');
    expect(diagnostics.isFallbackToGenericEnglish, isTrue);
    expect(diagnostics.warningMessage, isNotNull);
    expect(diagnostics.warningMessage, contains('发音可能不标准'));
  });

  test(
    'getTtsDiagnostics reports the configured and resolved languages',
    () async {
      final service = TtsService(
        engine: _FakeTtsEngine(languages: <String>['en']),
        preferenceLoader: () async => TtsVoicePreference.american,
      );

      final diagnostics = await service.getTtsDiagnostics();

      expect(diagnostics.availableLanguages, <String>['en']);
      expect(diagnostics.preferredLanguage, 'en-US');
      expect(diagnostics.resolvedLanguage, 'en');
      expect(diagnostics.isExactMatch, isFalse);
      expect(diagnostics.isFallbackToGenericEnglish, isTrue);
      expect(diagnostics.warningMessage, isNotNull);
    },
  );

  test('configures speech using a specific regional fallback', () async {
    final engine = _FakeTtsEngine(languages: <String>['en', 'en-GB']);
    final service = TtsService(
      engine: engine,
      preferenceLoader: () async => TtsVoicePreference.american,
    );

    await service.speakWord('academic');

    expect(engine.languageAttempts.first, 'en-GB');
    expect(engine.awaitCompletion, isFalse);
    expect(engine.volume, 1.0);
    expect(engine.rate, 0.45);
    expect(engine.pitch, 1.0);
    expect(engine.spoken, <String>['academic']);
  });

  test('tries the next language when setLanguage is rejected', () async {
    final engine = _FakeTtsEngine(
      languages: <String>['en-US', 'en-GB', 'en'],
      rejectedLanguages: <String>{'en-US'},
    );
    final service = TtsService(
      engine: engine,
      preferenceLoader: () async => TtsVoicePreference.american,
    );

    await service.speakWord('academic');

    expect(engine.languageAttempts, <String>['en-US', 'en-GB']);
    expect(service.status.language, 'en-GB');
    expect(service.status.warningMessage, contains('en-US'));
  });

  test('does not initialize or speak for an empty word', () async {
    var preferenceReads = 0;
    final engine = _FakeTtsEngine(languages: <String>['en-US']);
    final service = TtsService(
      engine: engine,
      preferenceLoader: () async {
        preferenceReads++;
        return TtsVoicePreference.american;
      },
    );

    await service.speakWord('   ');

    expect(preferenceReads, 0);
    expect(engine.getLanguagesCalls, 0);
    expect(engine.spoken, isEmpty);
  });

  test('turns platform speech failures into a readable error', () async {
    final engine = _FakeTtsEngine(languages: <String>['en-US'], speakResult: 0);
    final service = TtsService(
      engine: engine,
      preferenceLoader: () async => TtsVoicePreference.american,
    );

    expect(
      () => service.speakWord('academic'),
      throwsA(
        isA<TtsException>().having(
          (error) => error.message,
          'message',
          TtsService.failureMessage,
        ),
      ),
    );
  });

  test('reports a readable error when every language is rejected', () async {
    final engine = _FakeTtsEngine(
      languages: <String>['en-US'],
      rejectedLanguages: <String>{'en-US', 'en'},
    );
    final service = TtsService(
      engine: engine,
      preferenceLoader: () async => TtsVoicePreference.american,
    );

    await expectLater(
      service.speakWord('academic'),
      throwsA(
        isA<TtsException>().having(
          (error) => error.message,
          'message',
          TtsService.failureMessage,
        ),
      ),
    );
    expect(engine.spoken, isEmpty);
  });
}

final class _FakeTtsEngine implements TtsEngine {
  _FakeTtsEngine({
    required this.languages,
    this.speakResult = 1,
    this.rejectedLanguages = const <String>{},
  });

  final List<String> languages;
  final dynamic speakResult;
  final Set<String> rejectedLanguages;
  int getLanguagesCalls = 0;
  bool? awaitCompletion;
  double? rate;
  double? volume;
  double? pitch;
  final List<String> languageAttempts = <String>[];
  final List<String> spoken = <String>[];

  @override
  Future<dynamic> getLanguages() async {
    getLanguagesCalls++;
    return languages;
  }

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {
    this.awaitCompletion = awaitCompletion;
    return 1;
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    languageAttempts.add(language);
    return rejectedLanguages.contains(language) ? 0 : 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    this.rate = rate;
    return 1;
  }

  @override
  Future<dynamic> setVolume(double volume) async {
    this.volume = volume;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    this.pitch = pitch;
    return 1;
  }

  @override
  Future<dynamic> speak(String text) async {
    spoken.add(text);
    return speakResult;
  }

  @override
  Future<dynamic> stop() async => 1;
}
