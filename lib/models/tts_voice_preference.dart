enum TtsVoicePreference {
  american('american', '美式发音 en-US', 'en-US'),
  british('british', '英式发音 en-GB', 'en-GB'),
  system('system', '跟随系统', null);

  const TtsVoicePreference(this.storageValue, this.label, this.targetLanguage);

  final String storageValue;
  final String label;
  final String? targetLanguage;

  static const defaultValue = TtsVoicePreference.american;

  static TtsVoicePreference fromStorage(String? value) {
    return TtsVoicePreference.values.firstWhere(
      (preference) => preference.storageValue == value,
      orElse: () => defaultValue,
    );
  }
}
