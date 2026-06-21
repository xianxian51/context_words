import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/word_book_model.dart';
import '../../providers/app_controller.dart';
import '../../widgets/app_snack_bar.dart';
import 'word_book_detail_page.dart';

final class WordBooksPage extends StatefulWidget {
  const WordBooksPage({super.key});

  @override
  State<WordBooksPage> createState() => _WordBooksPageState();
}

final class _WordBooksPageState extends State<WordBooksPage> {
  late Future<List<WordBookModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<WordBookModel>> _load() {
    return context.read<AppController>().getAllWordBooks();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openBook(WordBookModel book) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WordBookDetailPage(wordBookId: book.id!),
      ),
    );
    _reload();
  }

  Future<void> _showBookDialog({WordBookModel? book}) async {
    final nameController = TextEditingController(text: book?.name ?? '');
    final descriptionController = TextEditingController(
      text: book?.description ?? '',
    );
    final result = await showDialog<({String name, String description})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(book == null ? '新建单词本' : '编辑单词本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '描述（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                return;
              }
              Navigator.pop(context, (
                name: name,
                description: descriptionController.text.trim(),
              ));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (result == null || !mounted) {
      return;
    }
    final app = context.read<AppController>();
    try {
      if (book == null) {
        await app.createWordBook(result.name, description: result.description);
      } else {
        await app.updateWordBook(
          book.copyWith(name: result.name, description: result.description),
        );
      }
      _reload();
      if (mounted) {
        showAppSnackBar(
          context,
          book == null ? '单词本已创建。' : '单词本已更新。',
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    }
  }

  Future<void> _deleteBook(WordBookModel book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除单词本？'),
        content: Text('将删除“${book.name}”及其收录关系，不会删除词库里的单词。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || book.id == null) {
      return;
    }
    try {
      await context.read<AppController>().deleteWordBook(book.id!);
      _reload();
      if (mounted) {
        showAppSnackBar(context, '单词本已删除。', type: AppSnackBarType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的单词本')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBookDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建'),
      ),
      body: FutureBuilder<List<WordBookModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final books = snapshot.data ?? const <WordBookModel>[];
          if (books.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('你还没有创建单词本，可以创建“易混词”“作文高级词”等。'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return Card(
                child: ListTile(
                  onTap: book.id == null ? null : () => _openBook(book),
                  leading: const Icon(Icons.collections_bookmark_rounded),
                  title: Text(book.name),
                  subtitle: Text(
                    book.description?.isNotEmpty == true
                        ? '${book.description} · ${book.wordCount} 个词'
                        : '${book.wordCount} 个词',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showBookDialog(book: book);
                      }
                      if (value == 'delete') {
                        _deleteBook(book);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
