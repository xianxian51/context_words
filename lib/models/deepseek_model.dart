enum DeepSeekModel {
  highQuality('deepseek-v4-pro', '高质量模式'),
  fast('deepseek-v4-flash', '快速省钱模式');

  const DeepSeekModel(this.apiName, this.label);

  final String apiName;
  final String label;

  static const defaultValue = DeepSeekModel.highQuality;

  static DeepSeekModel fromStorage(String? value) {
    return DeepSeekModel.values.firstWhere(
      (model) => model.apiName == value,
      orElse: () => defaultValue,
    );
  }
}
