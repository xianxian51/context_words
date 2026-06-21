import 'word_model.dart';

final class PagedWordsResult {
  const PagedWordsResult({
    required this.items,
    required this.totalCount,
    this.offset = 0,
  });

  final List<WordModel> items;
  final int totalCount;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
