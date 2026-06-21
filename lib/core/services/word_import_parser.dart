import '../../models/import_result.dart';

abstract final class WordImportParser {
  static final _wordPattern = RegExp(r"^[A-Za-z][A-Za-z'-]*$");

  static List<ImportedWordEntry> parse(String input) {
    final entries = <ImportedWordEntry>[];
    for (final rawLine in input.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final commaIndex = line.indexOf(',');
      final whitespace = RegExp(r'\s+').firstMatch(line);
      final parts = commaIndex >= 0
          ? <String>[
              line.substring(0, commaIndex),
              line.substring(commaIndex + 1),
            ]
          : whitespace == null
          ? <String>[line]
          : <String>[
              line.substring(0, whitespace.start),
              line.substring(whitespace.end),
            ];
      final word = parts.first.trim().toLowerCase();
      if (!_wordPattern.hasMatch(word)) {
        entries.add(ImportedWordEntry(word: ''));
        continue;
      }
      final meaning = parts.length > 1 ? parts[1].trim() : '';
      entries.add(
        ImportedWordEntry(
          word: word,
          meaningCn: meaning.isEmpty ? null : meaning,
        ),
      );
    }
    return entries;
  }
}
