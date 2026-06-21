final class ImportResult {
  const ImportResult({
    required this.imported,
    required this.duplicates,
    required this.failed,
  });

  final int imported;
  final int duplicates;
  final int failed;
}

final class ImportedWordEntry {
  const ImportedWordEntry({required this.word, this.meaningCn});

  final String word;
  final String? meaningCn;
}
