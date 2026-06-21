import 'package:context_words/core/services/word_import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses plain, whitespace, and comma-separated word lines', () {
    final entries = WordImportParser.parse(
      'abandon\nacademic 学术的\nadequate, 足够的\n',
    );

    expect(entries, hasLength(3));
    expect(entries[0].word, 'abandon');
    expect(entries[0].meaningCn, isNull);
    expect(entries[1].word, 'academic');
    expect(entries[1].meaningCn, '学术的');
    expect(entries[2].word, 'adequate');
    expect(entries[2].meaningCn, '足够的');
  });

  test('marks invalid lines without rejecting valid lines', () {
    final entries = WordImportParser.parse('valid\n123bad\nhello world');

    expect(entries.map((entry) => entry.word), <String>['valid', '', 'hello']);
  });
}
