import 'package:context_words/core/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects en-US, then en-GB, then another English language', () {
    expect(
      TtsService.selectEnglishLanguage(<String>['zh-CN', 'en_GB', 'en-US']),
      'en-US',
    );
    expect(
      TtsService.selectEnglishLanguage(<String>['zh-CN', 'en_GB']),
      'en_GB',
    );
    expect(
      TtsService.selectEnglishLanguage(<String>['zh-CN', 'en-AU']),
      'en-AU',
    );
  });

  test('configures speech and captures the accepted speak result', () async {
    final engine = _FakeTtsEngine(languages: <String>['zh-CN', 'en-GB']);
    final service = TtsService(engine: engine);

    await service.speakWord('hello');

    expect(engine.language, 'en-GB');
    expect(engine.awaitCompletion, isFalse);
    expect(engine.volume, 1.0);
    expect(engine.rate, 0.45);
    expect(engine.pitch, 1.0);
    expect(engine.spoken, <String>['hello']);
  });

  test('does not initialize or speak for an empty word', () async {
    final engine = _FakeTtsEngine(languages: <String>['en-US']);
    final service = TtsService(engine: engine);

    await service.speakWord('   ');

    expect(engine.getLanguagesCalls, 0);
    expect(engine.spoken, isEmpty);
  });

  test('turns platform speech failures into a readable error', () async {
    final engine = _FakeTtsEngine(languages: <String>['en-US'], speakResult: 0);
    final service = TtsService(engine: engine);

    expect(
      () => service.speakWord('hello'),
      throwsA(
        isA<TtsException>().having(
          (error) => error.message,
          'message',
          TtsService.failureMessage,
        ),
      ),
    );
  });
}

final class _FakeTtsEngine implements TtsEngine {
  _FakeTtsEngine({required this.languages, this.speakResult = 1});

  final List<String> languages;
  final dynamic speakResult;
  int getLanguagesCalls = 0;
  bool? awaitCompletion;
  String? language;
  double? rate;
  double? volume;
  double? pitch;
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
    this.language = language;
    return 1;
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
