import 'package:flutter/services.dart';

final class TtsSettingsLauncher {
  TtsSettingsLauncher({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('io.github.xianxian51.contextwords/tts_settings');

  final MethodChannel _channel;

  Future<bool> openInstallTtsData() async {
    try {
      return await _channel.invokeMethod<bool>('openInstallTtsData') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
