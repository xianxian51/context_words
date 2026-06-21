import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/confusing_word_group_model.dart';
import '../../models/word_model.dart';
import '../../providers/app_controller.dart';
import '../../widgets/app_snack_bar.dart';
import 'confusing_word_group_detail_page.dart';

final class ConfusingWordsPage extends StatefulWidget {
  const ConfusingWordsPage({super.key});

  @override
  State<ConfusingWordsPage> createState() => _ConfusingWordsPageState();
}

final class _ConfusingWordsPageState extends State<ConfusingWordsPage> {
  static const _pageSize = 50;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _queryController = TextEditingController();
  final _selected = <int, WordModel>{};
  List<WordModel> _results = const <WordModel>[];
  late Future<List<ConfusingWordGroupModel>> _groupsFuture;
  bool _isSearching = false;
  bool _isCreating = false;
  int _totalCount = 0;
  bool _prefixOnly = true;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _groupsFuture = _loadGroups();
    _queryController.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    final query = _queryController.text.trim();
    if (query == _lastQuery) {
      return;
    }
    setState(() {
      _results = const <WordModel>[];
      _selected.clear();
      _totalCount = 0;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<List<ConfusingWordGroupModel>> _loadGroups() {
    return context.read<AppController>().getAllConfusingGroups();
  }

  void _reloadGroups() {
    setState(() => _groupsFuture = _loadGroups());
  }

  Future<void> _search({
    required bool prefixOnly,
    bool loadMore = false,
  }) async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      showAppSnackBar(context, '请输入要搜索的前缀或单词。');
      return;
    }
    setState(() => _isSearching = true);
    try {
      final app = context.read<AppController>();
      final reset =
          !loadMore || query != _lastQuery || prefixOnly != _prefixOnly;
      final result = await app.searchSimilarWords(
        query: query,
        prefixOnly: prefixOnly,
        limit: _pageSize,
        offset: reset ? 0 : _results.length,
      );
      if (mounted) {
        setState(() {
          _lastQuery = query;
          _prefixOnly = prefixOnly;
          _results = reset
              ? result.items
              : <WordModel>[..._results, ...result.items];
          _totalCount = result.totalCount;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _createGroup() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showAppSnackBar(context, '请输入易混词组标题。');
      return;
    }
    if (_selected.length < 2) {
      showAppSnackBar(context, '至少选择 2 个单词创建易混词组。');
      return;
    }
    setState(() => _isCreating = true);
    try {
      final group = await context.read<AppController>().createConfusingGroup(
        title,
        _selected.values.toList(growable: false),
        description: _descriptionController.text,
      );
      _titleController.clear();
      _descriptionController.clear();
      _selected.clear();
      _results = const <WordModel>[];
      _totalCount = 0;
      _lastQuery = '';
      _reloadGroups();
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '易混词组已创建。', type: AppSnackBarType.success);
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ConfusingWordGroupDetailPage(groupId: group.id!),
        ),
      );
      _reloadGroups();
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

  Future<void> _deleteGroup(ConfusingWordGroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除易混词组？'),
        content: Text('将删除“${group.title}”和已生成的辨析内容，不会删除词库里的单词。'),
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
    if (confirmed != true || !mounted || group.id == null) {
      return;
    }
    try {
      await context.read<AppController>().deleteConfusingGroup(group.id!);
      _reloadGroups();
      if (mounted) {
        showAppSnackBar(context, '易混词组已删除。', type: AppSnackBarType.success);
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
      appBar: AppBar(title: const Text('易混词组')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _CreateGroupCard(
              titleController: _titleController,
              descriptionController: _descriptionController,
              queryController: _queryController,
              results: _results,
              selected: _selected,
              isSearching: _isSearching,
              isCreating: _isCreating,
              totalCount: _totalCount,
              onPrefixSearch: () => _search(prefixOnly: true),
              onSearch: () => _search(prefixOnly: false),
              onLoadMore: () =>
                  _search(prefixOnly: _prefixOnly, loadMore: true),
              onCreate: _createGroup,
              onToggleWord: (word) {
                final id = word.id;
                if (id == null) {
                  return;
                }
                setState(() {
                  if (_selected.containsKey(id)) {
                    _selected.remove(id);
                  } else {
                    _selected[id] = word;
                  }
                });
              },
            ),
            const SizedBox(height: 18),
            Text('已创建的词组', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<List<ConfusingWordGroupModel>>(
              future: _groupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final groups =
                    snapshot.data ?? const <ConfusingWordGroupModel>[];
                if (groups.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('还没有易混词组，可以先搜索相似词并创建一个。'),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Card(
                      child: ListTile(
                        onTap: group.id == null
                            ? null
                            : () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ConfusingWordGroupDetailPage(
                                          groupId: group.id!,
                                        ),
                                  ),
                                );
                                _reloadGroups();
                              },
                        leading: const Icon(Icons.compare_arrows_rounded),
                        title: Text(group.title),
                        subtitle: Text(
                          group.description?.isNotEmpty == true
                              ? '${group.description} · ${group.wordCount} 个词'
                              : '${group.wordCount} 个词',
                        ),
                        trailing: IconButton(
                          tooltip: '删除',
                          onPressed: () => _deleteGroup(group),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final class _CreateGroupCard extends StatelessWidget {
  const _CreateGroupCard({
    required this.titleController,
    required this.descriptionController,
    required this.queryController,
    required this.results,
    required this.selected,
    required this.isSearching,
    required this.isCreating,
    required this.totalCount,
    required this.onPrefixSearch,
    required this.onSearch,
    required this.onLoadMore,
    required this.onCreate,
    required this.onToggleWord,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController queryController;
  final List<WordModel> results;
  final Map<int, WordModel> selected;
  final bool isSearching;
  final bool isCreating;
  final int totalCount;
  final VoidCallback onPrefixSearch;
  final VoidCallback onSearch;
  final VoidCallback onLoadMore;
  final VoidCallback onCreate;
  final ValueChanged<WordModel> onToggleWord;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('创建易混词组', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '词组标题，例如 con- 易混词',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: queryController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: '搜索词库，例如 con 或 context',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isSearching ? null : onPrefixSearch,
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: Text(isSearching ? '搜索中…' : '前缀查询'),
                ),
                OutlinedButton.icon(
                  onPressed: isSearching ? null : onSearch,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('普通搜索'),
                ),
              ],
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final word in selected.values)
                    InputChip(
                      label: Text(word.word),
                      onDeleted: () => onToggleWord(word),
                    ),
                ],
              ),
            ],
            if (results.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('搜索结果', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final word = results[index];
                  final id = word.id;
                  final checked = id != null && selected.containsKey(id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (_) => onToggleWord(word),
                    title: Text(word.word),
                    subtitle: Text(
                      '${word.partOfSpeech ?? '暂无'}  ${word.meaningCn ?? '暂无'}',
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text('已显示 ${results.length} 个 / 共 $totalCount 个'),
              if (results.length < totalCount) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isSearching ? null : onLoadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text(isSearching ? '加载中…' : '显示更多'),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('已全部显示。'),
                ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isCreating ? null : onCreate,
                icon: const Icon(Icons.add_rounded),
                label: Text(isCreating ? '正在创建…' : '创建词组'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
