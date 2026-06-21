import 'package:shared_preferences/shared_preferences.dart';

import '../../models/word_selection_mode.dart';

final class SettingsService {
  static const _apiKeyKey = 'deepseek_api_key';
  static const _dailyWordCountKey = 'daily_word_count';
  static const _wordSelectionModeKey = 'word_selection_mode';
  static const _autoPrepareDailyKey = 'auto_prepare_daily';
  static const _autoGenerateReadingsKey = 'auto_generate_readings';
  static const defaultDailyWordCount = 20;
  static const defaultWordSelectionMode = WordSelectionMode.random;
  static const defaultAutoPrepareDaily = true;
  static const defaultAutoGenerateReadings = true;

  Future<String> getApiKey() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_apiKeyKey)?.trim() ?? '';
  }

  Future<void> saveApiKey(String apiKey) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_apiKeyKey, apiKey.trim());
  }

  Future<int> getDailyWordCount() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_dailyWordCountKey) ?? defaultDailyWordCount;
  }

  Future<void> saveDailyWordCount(int count) async {
    if (count < 1 || count > 100) {
      throw ArgumentError.value(count, 'count', 'Must be between 1 and 100.');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_dailyWordCountKey, count);
  }

  Future<WordSelectionMode> getWordSelectionMode() async {
    final preferences = await SharedPreferences.getInstance();
    return WordSelectionMode.fromStorage(
      preferences.getString(_wordSelectionModeKey),
    );
  }

  Future<void> saveWordSelectionMode(WordSelectionMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_wordSelectionModeKey, mode.storageValue);
  }

  Future<bool> getAutoPrepareDaily() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoPrepareDailyKey) ?? defaultAutoPrepareDaily;
  }

  Future<void> saveAutoPrepareDaily(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoPrepareDailyKey, enabled);
  }

  Future<bool> getAutoGenerateReadings() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoGenerateReadingsKey) ??
        defaultAutoGenerateReadings;
  }

  Future<void> saveAutoGenerateReadings(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoGenerateReadingsKey, enabled);
  }
}
