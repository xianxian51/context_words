import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/word_model.dart';
import '../../providers/app_controller.dart';
import '../../widgets/add_to_word_book_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/builtin_wordbook_manager.dart';
import '../../widgets/word_detail_bottom_sheet.dart';
import '../import_words/import_words_page.dart';
import '../today_words/today_words_page.dart';
import '../word_books/word_books_page.dart';

final class WordLibraryPage extends StatefulWidget {
  const WordLibraryPage({super.key});

  @override
  State<WordLibraryPage> createState() => _WordLibraryPageState();
}

final class _WordLibraryPageState extends State<WordLibraryPage> {
  static const _pageSize = 100;

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<WordModel> _words = const <WordModel>[];
  bool _starredOnly = false;
  bool _loading = true;
  int _totalCount = 0;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    if (mounted) {
      setState(() {});
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(reset: true),
    );
  }

  Future<void> _load({required bool reset}) async {
    final requestId = ++_requestId;
    final offset = reset ? 0 : _words.length;
    setState(() => _loading = true);
    try {
      final result = await context.read<AppController>().searchWordsPage(
        query: _searchController.text,
        starredOnly: _starredOnly,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _words = reset ? result.items : <WordModel>[..._words, ...result.items];
        _totalCount = result.totalCount;
      });
    } catch (error) {
      if (mounted && requestId == _requestId) {
        showAppSnackBar(context, error.toString(), type: AppSnackBarType.error);
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _initializeWordbook() async {
    final app = context.read<AppController>();
    final completed = await runBuiltinWordbookUpgrade(context, app);
    if (completed && mounted) {
      await _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('词库')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Column(
                children: [
                  BuiltinWordbookManagerCard(
                    app: app,
                    onCompleted: () => _load(reset: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(reset: true),
                    decoration: InputDecoration(
                      labelText: '搜索英文、中文释义、词性或英文释义',
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text('只看星标'),
                        selected: _starredOnly,
                        onSelected: (value) {
                          setState(() => _starredOnly = value);
                          _load(reset: true);
                        },
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openTodayWords(app),
                        icon: const Icon(Icons.list_alt_rounded),
                        label: const Text('查看今日单词'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const WordBooksPage(),
                          ),
                        ),
                        icon: const Icon(Icons.collections_bookmark_rounded),
                        label: const Text('我的单词本'),
                      ),
                      Text('找到 $_totalCount 个词'),
                    ],
                  ),
                ],
              ),
            ),
            if (_loading || (app.isBusy && app.activeOperation == '正在初始化六级词库…'))
              const LinearProgressIndicator(),
            Expanded(child: _buildResults(app)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AppController app) {
    if (_loading && _words.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_words.isEmpty && app.totalWordCount == 0) {
      return _EmptyLibraryState(onInitialize: _initializeWordbook);
    }
    if (_words.isEmpty) {
      return const Center(child: Text('未找到相关单词。'));
    }
    final hasMore = _words.length < _totalCount;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _words.length + 1,
      itemBuilder: (context, index) {
        if (index == _words.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: hasMore
                  ? OutlinedButton(
                      onPressed: _loading ? null : () => _load(reset: false),
                      child: Text('显示更多（${_words.length}/$_totalCount）'),
                    )
                  : Text('已显示 ${_words.length} 个 / 共 $_totalCount 个'),
            ),
          );
        }
        final word = _words[index];
        return Card(
          child: ListTile(
            onTap: () => showWordDetailBottomSheet(context, word),
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
              '${word.partOfSpeech ?? '暂无'}  ${word.meaningCn ?? '暂无释义'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '加入单词本',
                  onPressed: () => showAddWordToWordBookSheet(context, word),
                  icon: const Icon(Icons.library_add_rounded),
                ),
                IconButton(
                  tooltip: word.isStarred ? '取消星标' : '星标',
                  onPressed: () async {
                    await app.toggleStar(word);
                    if (mounted) {
                      await _load(reset: true);
                    }
                  },
                  icon: Icon(
                    word.isStarred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: word.isStarred ? Colors.amber.shade700 : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTodayWords(AppController app) async {
    if (app.todayPlan == null) {
      showAppSnackBar(context, '请先生成今日计划。');
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const TodayWordsPage()),
    );
    await app.refresh();
  }
}

final class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState({required this.onInitialize});

  final VoidCallback onInitialize;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_books_rounded, size: 56),
            const SizedBox(height: 14),
            Text('词库为空', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('可以先初始化内置六级词库，也可以导入自己的单词。'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: app.isBusy ? null : onInitialize,
              icon: const Icon(Icons.download_done_rounded),
              label: Text(app.isBusy ? '正在初始化…' : '初始化/升级六级词库'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: app.isBusy
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ImportWordsPage(),
                      ),
                    ),
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('导入自定义单词'),
            ),
          ],
        ),
      ),
    );
  }
}
