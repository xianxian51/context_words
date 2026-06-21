import 'package:context_words/core/database/database_helper.dart';
import 'package:context_words/core/services/wordbook_service.dart';
import 'package:context_words/models/word_model.dart';
import 'package:context_words/repositories/word_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late WordbookService wordbookService;
  late WordRepository wordRepository;

  setUpAll(sqfliteFfiInit);
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    databaseHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    wordRepository = WordRepository(databaseHelper: databaseHelper);
    wordbookService = WordbookService(wordRepository: wordRepository);
  });

  tearDown(() => databaseHelper.close());

  test('loads the bundled CET-6 wordbook asset', () async {
    final words = await wordbookService.loadBuiltinCet6Wordbook();

    expect(words.length, 5406);
    expect(words.first.word, 'abandon');
    expect(words.every((word) => word.difficulty == 'cet6'), isTrue);
    expect(words.every((word) => word.source == 'cet6_builtin'), isTrue);
    expect(
      words.where((word) => word.meaningCn?.isNotEmpty == true).length,
      5406,
    );
  });

  test(
    'imports the bundled CET-6 wordbook once and skips duplicates',
    () async {
      final first = await wordbookService.importBuiltinCet6IfNeeded();
      final second = await wordbookService.importBuiltinCet6IfNeeded();

      expect(first.imported, 5406);
      expect(first.existing, 0);
      expect(second.imported, 0);
      expect(second.existing, 5406);
      expect(second.enrichedFields, 0);
      expect(await wordRepository.count(), 5406);
    },
  );

  test(
    'upgrade fills blank fields without overwriting starred state',
    () async {
      final existing = await wordRepository.create(
        const WordModel(word: 'abandon', isStarred: true, source: 'manual'),
      );

      final result = await wordbookService.importBuiltinCet6IfNeeded();
      final upgraded = await wordRepository.findById(existing.id!);

      expect(result.imported, 5405);
      expect(result.existing, 1);
      expect(result.enrichedFields, greaterThan(0));
      expect(upgraded?.isStarred, isTrue);
      expect(upgraded?.source, 'manual');
      expect(upgraded?.meaningCn, isNotEmpty);
    },
  );
}
