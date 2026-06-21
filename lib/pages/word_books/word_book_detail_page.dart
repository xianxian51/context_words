import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/word_book_model.dart';
import '../../models/word_model.dart';
import '../../providers/app_controller.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/word_detail_bottom_sheet.dart';
import '../reading/passage_view_page.dart';

final class WordBookDetailPage extends StatefulWidget {
  const WordBookDetailPage({required this.wordBookId, super.key});

  final int wordBookId;

  @override
  State<WordBookDetailPage> createState() => _WordBookDetailPageState();
}

final class _WordBookDetailPageState extends State<WordBookDetailPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late Future<WordBookModel?> _bookFuture;
  late Future<List<WordModel>> _wordsFuture;

  @override
  void initState() {
    super.initState();
    _bookFuture = _loadBook();
    _wordsFuture = _loadWords();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<WordBookModel?> _loadBook() {
    return context.read<AppController>().getWordBook(widget.wordBookId);
  }

  Future<List<WordModel>> _loadWords() {
    return context.read<AppController>().getWordsInBook(
      widget.wordBookId,
      query: _searchController.text,
    );
  }

  void _reload() {
    setState(() {
      _bookFuture = _loadBook();
      _wordsFuture = _loadWords();
    });
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _reload);
  }

  Future<void> _remove(WordModel word) async {
    final id = word.id;
    if (id == null) {
      return;
    }
    try {
      await context.read<AppController>().removeWordFromBook(
        widget.wordBookId,
        id,
      );
      _reload();
      if (mounted) {
        showAppSnackBar(context, '已从单词本移除。', type: AppSnackBarType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    }
  }

  Future<void> _toggleStar(WordModel word) async {
    await context.read<AppController>().toggleStar(word);
    _reload();
  }

  Future<void> _openMemoryPassage(WordBookModel book) async {
    final words = await context.read<AppController>().getWordsInBook(
      widget.wordBookId,
    );
    if (!mounted) {
      return;
    }
    await openCollectionPassage(
      context: context,
      sourceType: 'word_book',
      sourceId: widget.wordBookId,
      sourceName: book.name,
      words: words,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    return FutureBuilder<WordBookModel?>(
      future: _bookFuture,
      builder: (context, bookSnapshot) {
        final book = bookSnapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(book?.name ?? '单词本详情')),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (book != null)
                        Text(
                          book.description?.isNotEmpty == true
                              ? '${book.description} · ${book.wordCount} 个词'
                              : '${book.wordCount} 个词',
                        ),
                      if (book != null) ...[
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed: app.isBusy
                              ? null
                              : () => _openMemoryPassage(book),
                          icon: const Icon(Icons.auto_stories_rounded),
                          label: const Text('生成记忆短文'),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: '搜索本单词本',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '清空',
                                  onPressed: _searchController.clear,
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<WordModel>>(
                    future: _wordsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final words = snapshot.data ?? const <WordModel>[];
                      if (words.isEmpty) {
                        return const Center(child: Text('这个单词本暂时没有单词。'));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: words.length,
                        itemBuilder: (context, index) {
                          final word = words[index];
                          return Card(
                            child: ListTile(
                              onTap: () async {
                                await showWordDetailBottomSheet(context, word);
                                _reload();
                              },
                              leading: IconButton(
                                tooltip: '发音',
                                onPressed: () async {
                                  try {
                                    await app.speakWord(word.word);
                                  } catch (error) {
                                    if (context.mounted) {
                                      showAppSnackBar(
                                        context,
                                        error.toString(),
                                        type: AppSnackBarType.error,
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.volume_up_rounded),
                              ),
                              title: Text(word.word),
                              subtitle: Text(
                                '${word.partOfSpeech ?? '暂无'}  ${word.meaningCn ?? '暂无'}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: word.isStarred ? '取消星标' : '星标',
                                    onPressed: () => _toggleStar(word),
                                    icon: Icon(
                                      word.isStarred
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: word.isStarred
                                          ? Colors.amber.shade700
                                          : null,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '移出单词本',
                                    onPressed: () => _remove(word),
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
