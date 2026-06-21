import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/word_model.dart';
import '../../providers/app_controller.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/word_detail_bottom_sheet.dart';

final class StarredWordsPage extends StatefulWidget {
  const StarredWordsPage({super.key});

  @override
  State<StarredWordsPage> createState() => _StarredWordsPageState();
}

final class _StarredWordsPageState extends State<StarredWordsPage> {
  late Future<List<WordModel>> _words;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _words = context.read<AppController>().getStarredWords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('重点词册')),
      body: FutureBuilder<List<WordModel>>(
        future: _words,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final words = snapshot.data ?? const <WordModel>[];
          if (words.isEmpty) {
            return const Center(child: Text('还没有星标单词。'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: words.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final word = words[index];
              return Card(
                child: ListTile(
                  onTap: () async {
                    await showWordDetailBottomSheet(context, word);
                    if (mounted) {
                      setState(_reload);
                    }
                  },
                  title: Text(word.word),
                  subtitle: Text(
                    '${word.partOfSpeech ?? '暂无'}  ${word.meaningCn ?? '暂无'}',
                  ),
                  leading: IconButton(
                    tooltip: '发音',
                    onPressed: () async {
                      try {
                        await context.read<AppController>().speakWord(
                          word.word,
                        );
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
                  trailing: IconButton(
                    tooltip: '取消星标',
                    onPressed: () async {
                      await context.read<AppController>().toggleStar(word);
                      if (mounted) {
                        setState(_reload);
                      }
                    },
                    icon: Icon(
                      Icons.star_rounded,
                      color: Colors.amber.shade700,
                    ),
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
