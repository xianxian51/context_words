import 'package:context_words/core/services/tts_settings_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'io.github.xianxian51.contextwords/tts_settings_test',
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('opens the native TTS install/settings entry', () async {
    var method = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          method = call.method;
          return true;
        });
    final launcher = TtsSettingsLauncher(channel: channel);

    final opened = await launcher.openInstallTtsData();

    expect(opened, isTrue);
    expect(method, 'openInstallTtsData');
  });

  test('returns false when the native TTS entry cannot be opened', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'unavailable');
        });
    final launcher = TtsSettingsLauncher(channel: channel);

    expect(await launcher.openInstallTtsData(), isFalse);
  });
}
