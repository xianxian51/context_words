final class WordbookUpgradeResult {
  const WordbookUpgradeResult({
    required this.builtinCount,
    required this.imported,
    required this.existing,
    required this.enrichedFields,
    required this.totalWordCount,
  });

  final int builtinCount;
  final int imported;
  final int existing;
  final int enrichedFields;
  final int totalWordCount;
}
