enum WordSelectionMode {
  random,
  sequential;

  String get storageValue => name;

  String get label => switch (this) {
    WordSelectionMode.random => '随机抽取',
    WordSelectionMode.sequential => '顺序抽取',
  };

  static WordSelectionMode fromStorage(String? value) {
    return WordSelectionMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => WordSelectionMode.random,
    );
  }
}
