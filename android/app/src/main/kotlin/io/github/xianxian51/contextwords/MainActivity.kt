package io.github.xianxian51.contextwords

import android.content.Intent
import android.provider.Settings
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.xianxian51.contextwords/tts_settings",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openInstallTtsData" -> result.success(openInstallTtsData())
                else -> result.notImplemented()
            }
        }
    }

    private fun openInstallTtsData(): Boolean {
        return openIntent(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)) ||
            openIntent(Intent(Settings.ACTION_SETTINGS))
    }

    private fun openIntent(intent: Intent): Boolean {
        return try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: Exception) {
            false
        }
    }
}
