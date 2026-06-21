import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_book_model.dart';
import '../models/word_model.dart';
import '../providers/app_controller.dart';
import 'app_snack_bar.dart';

Future<void> showAddWordToWordBookSheet(BuildContext context, WordModel word) {
  return showAddWordsToWordBookSheet(context, <WordModel>[word]);
}

Future<void> showAddWordsToWordBookSheet(
  BuildContext context,
  List<WordModel> words,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddToWordBookContent(words: words),
  );
}

final class _AddToWordBookContent extends StatefulWidget {
  const _AddToWordBookContent({required this.words});

  final List<WordModel> words;

  @override
  State<_AddToWordBookContent> createState() => _AddToWordBookContentState();
}

final class _AddToWordBookContentState extends State<_AddToWordBookContent> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _selectedIds = <int>{};
  late Future<List<WordBookModel>> _future;
  bool _isSaving = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<List<WordBookModel>> _load() async {
    final app = context.read<AppController>();
    final books = await app.getAllWordBooks();
    final singleWordId = widget.words.length == 1
        ? widget.words.single.id
        : null;
    if (singleWordId != null && _selectedIds.isEmpty) {
      final containing = await app.getBooksContainingWord(singleWordId);
      _selectedIds.addAll(containing.map((book) => book.id).whereType<int>());
    }
    return books;
  }

  Future<void> _createBook() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, '请输入单词本名称。');
      return;
    }
    setState(() => _isCreating = true);
    try {
      final book = await context.read<AppController>().createWordBook(
        name,
        description: _descriptionController.text,
      );
      final id = book.id;
      if (id != null) {
        _selectedIds.add(id);
      }
      _nameController.clear();
      _descriptionController.clear();
      setState(() => _future = _load());
      if (mounted) {
        showAppSnackBar(context, '单词本已创建。', type: AppSnackBarType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _save() async {
    if (_selectedIds.isEmpty) {
      showAppSnackBar(context, '请选择至少一个单词本。');
      return;
    }
    final savedWords = widget.words.where((word) => word.id != null).toList();
    if (savedWords.isEmpty) {
      showAppSnackBar(context, '该单词尚未加入本地词库。', type: AppSnackBarType.error);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<AppController>().addWordsToWordBooks(
        savedWords,
        _selectedIds.toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      showAppSnackBar(context, '已加入单词本。', type: AppSnackBarType.success);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.words.length == 1
                    ? '加入单词本：${widget.words.single.word}'
                    : '将 ${widget.words.length} 个单词加入单词本',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '快速新建单词本',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isCreating ? null : _createBook,
                    child: Text(_isCreating ? '创建中…' : '创建'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<WordBookModel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final books = snapshot.data ?? const <WordBookModel>[];
                    if (books.isEmpty) {
                      return const Center(child: Text('还没有单词本，可以先在上方创建一个。'));
                    }
                    return ListView.builder(
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        final id = book.id;
                        final selected =
                            id != null && _selectedIds.contains(id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: id == null
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value ?? false) {
                                      _selectedIds.add(id);
                                    } else {
                                      _selectedIds.remove(id);
                                    }
                                  });
                                },
                          title: Text(book.name),
                          subtitle: Text(
                            book.description?.isNotEmpty == true
                                ? '${book.description} · ${book.wordCount} 个词'
                                : '${book.wordCount} 个词',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.library_add_rounded),
                  label: Text(_isSaving ? '正在加入…' : '加入选中的单词本'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
