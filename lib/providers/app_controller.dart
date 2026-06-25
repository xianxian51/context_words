import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/services/deepseek_service.dart';
import '../core/services/backup_service.dart';
import '../core/services/settings_service.dart';
import '../core/services/tts_settings_launcher.dart';
import '../core/services/tts_service.dart';
import '../core/services/update_service.dart';
import '../core/services/word_import_parser.dart';
import '../core/services/word_lookup_service.dart';
import '../core/services/wordbook_service.dart';
import '../models/batch_append_result.dart';
import '../models/app_release.dart';
import '../models/assistant_message.dart';
import '../models/collection_passage_model.dart';
import '../models/daily_plan_model.dart';
import '../models/deepseek_model.dart';
import '../models/deepseek_models.dart';
import '../models/confusing_word_group_model.dart';
import '../models/history_day_model.dart';
import '../models/import_result.dart';
import '../models/plan_generation_result.dart';
import '../models/paged_words_result.dart';
import '../models/plan_word_model.dart';
import '../models/reading_passage_model.dart';
import '../models/tts_voice_preference.dart';
import '../models/word_book_model.dart';
import '../models/word_model.dart';
import '../models/word_selection_mode.dart';
import '../models/wordbook_upgrade_result.dart';
import '../repositories/confusing_word_group_repository.dart';
import '../repositories/collection_passage_repository.dart';
import '../repositories/daily_plan_repository.dart';
import '../repositories/reading_repository.dart';
import '../repositories/word_book_repository.dart';
import '../repositories/word_repository.dart';

final class AppController extends ChangeNotifier {
  AppController({
    WordRepository? wordRepository,
    DailyPlanRepository? dailyPlanRepository,
    ReadingRepository? readingRepository,
    SettingsService? settingsService,
    DeepSeekService? deepSeekService,
    TtsService? ttsService,
    TtsSettingsLauncher? ttsSettingsLauncher,
    WordbookService? wordbookService,
    WordLookupService? wordLookupService,
    WordBookRepository? wordBookRepository,
    ConfusingWordGroupRepository? confusingWordGroupRepository,
    BackupService? backupService,
    CollectionPassageRepository? collectionPassageRepository,
    UpdateService? updateService,
  }) : _wordRepository = wordRepository ?? WordRepository(),
       _dailyPlanRepository = dailyPlanRepository ?? DailyPlanRepository(),
       _readingRepository = readingRepository ?? ReadingRepository(),
       _settingsService = settingsService ?? SettingsService(),
       _deepSeekService = deepSeekService ?? DeepSeekService(),
       _ttsService = ttsService ?? TtsService(),
       _ttsSettingsLauncher = ttsSettingsLauncher ?? TtsSettingsLauncher(),
       _wordBookRepository = wordBookRepository ?? WordBookRepository(),
       _confusingWordGroupRepository =
           confusingWordGroupRepository ?? ConfusingWordGroupRepository(),
       _collectionPassageRepository =
           collectionPassageRepository ?? CollectionPassageRepository(),
       _updateService = updateService ?? UpdateService(),
       _wordbookService =
           wordbookService ?? WordbookService(wordRepository: wordRepository) {
    _backupService =
        backupService ?? BackupService(settingsService: _settingsService);
    _wordLookupService =
        wordLookupService ??
        WordLookupService(
          wordRepository: _wordRepository,
          settingsService: _settingsService,
          deepSeekService: _deepSeekService,
        );
  }

  final WordRepository _wordRepository;
  final DailyPlanRepository _dailyPlanRepository;
  final ReadingRepository _readingRepository;
  final SettingsService _settingsService;
  final DeepSeekService _deepSeekService;
  final TtsService _ttsService;
  final TtsSettingsLauncher _ttsSettingsLauncher;
  final WordBookRepository _wordBookRepository;
  final ConfusingWordGroupRepository _confusingWordGroupRepository;
  final CollectionPassageRepository _collectionPassageRepository;
  final UpdateService _updateService;
  final WordbookService _wordbookService;
  late final BackupService _backupService;
  late final WordLookupService _wordLookupService;

  bool isLoading = true;
  bool isBusy = false;
  String? activeOperation;
  String? slowOperationMessage;
  String? actionMessage;
  bool actionMessageIsError = false;
  int totalWordCount = 0;
  int builtinCet6Count = 0;
  int dailyWordCount = SettingsService.defaultDailyWordCount;
  WordSelectionMode wordSelectionMode =
      SettingsService.defaultWordSelectionMode;
  bool hasApiKey = false;
  bool autoPrepareDaily = SettingsService.defaultAutoPrepareDaily;
  bool autoGenerateReadings = SettingsService.defaultAutoGenerateReadings;
  DeepSeekModel deepSeekModel = SettingsService.defaultDeepSeekModel;
  bool checkUpdatesOnLaunch = SettingsService.defaultCheckUpdatesOnLaunch;
  bool isPreparingToday = false;
  bool isGeneratingPassage = false;
  String? preparationStatus;
  String? lastPreparedDate;
  TtsStatus ttsStatus = const TtsStatus(TtsAvailability.checking);
  TtsVoicePreference ttsVoicePreference =
      SettingsService.defaultTtsVoicePreference;
  DailyPlanModel? todayPlan;
  List<PlanWordModel> allTodayWords = const <PlanWordModel>[];
  List<PlanWordModel> todayWords = const <PlanWordModel>[];
  List<int> todayBatches = const <int>[];
  int selectedBatchNo = 1;
  Map<int, ReadingPassageModel> passages = const <int, ReadingPassageModel>{};
  Set<int> completedRounds = const <int>{};
  Map<int, Set<int>> completedRoundsByBatch = const <int, Set<int>>{};
  bool _batchSelectionInitialized = false;

  Future<void> initialize() async {
    await refresh();
    await prepareTodayLearning();
    await refreshTtsStatus();
  }

  Future<void> refresh({bool selectLatestBatch = false}) async {
    isLoading = true;
    notifyListeners();
    try {
      totalWordCount = await _wordRepository.count();
      if (builtinCet6Count == 0) {
        builtinCet6Count = await _wordbookService.getBuiltinCet6Count();
      }
      dailyWordCount = await _settingsService.getDailyWordCount();
      wordSelectionMode = await _settingsService.getWordSelectionMode();
      autoPrepareDaily = await _settingsService.getAutoPrepareDaily();
      autoGenerateReadings = await _settingsService.getAutoGenerateReadings();
      deepSeekModel = await _settingsService.getDeepSeekModel();
      checkUpdatesOnLaunch = await _settingsService.getCheckUpdatesOnLaunch();
      ttsVoicePreference = await _settingsService.getTtsVoicePreference();
      hasApiKey = (await _settingsService.getApiKey()).isNotEmpty;
      todayPlan = await _dailyPlanRepository.findByDate(DateTime.now());
      final planId = todayPlan?.id;
      if (planId == null) {
        allTodayWords = const <PlanWordModel>[];
        todayWords = const <PlanWordModel>[];
        todayBatches = const <int>[];
        selectedBatchNo = 1;
        passages = const <int, ReadingPassageModel>{};
        completedRounds = const <int>{};
        completedRoundsByBatch = const <int, Set<int>>{};
        _batchSelectionInitialized = false;
      } else {
        allTodayWords = await _dailyPlanRepository.getPlanWords(planId);
        todayBatches = await _dailyPlanRepository.getPlanBatches(planId);
        if (todayBatches.isNotEmpty &&
            (selectLatestBatch ||
                !_batchSelectionInitialized ||
                !todayBatches.contains(selectedBatchNo))) {
          selectedBatchNo = todayBatches.last;
        }
        _batchSelectionInitialized = true;
        todayWords = allTodayWords
            .where((item) => item.batchNo == selectedBatchNo)
            .toList(growable: false);
        final passageList = await _readingRepository.findByPlanAndBatch(
          planId,
          selectedBatchNo,
        );
        passages = <int, ReadingPassageModel>{
          for (final passage in passageList) passage.round: passage,
        };
        completedRoundsByBatch = await _dailyPlanRepository
            .getCompletedRoundsByBatch(planId);
        completedRounds = completedRoundsByBatch[selectedBatchNo] ?? <int>{};
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectTodayBatch(int batchNo) async {
    final planId = todayPlan?.id;
    if (planId == null || !todayBatches.contains(batchNo)) {
      return;
    }
    selectedBatchNo = batchNo;
    todayWords = allTodayWords
        .where((item) => item.batchNo == batchNo)
        .toList(growable: false);
    final passageList = await _readingRepository.findByPlanAndBatch(
      planId,
      batchNo,
    );
    passages = <int, ReadingPassageModel>{
      for (final passage in passageList) passage.round: passage,
    };
    completedRounds = completedRoundsByBatch[batchNo] ?? <int>{};
    notifyListeners();
  }

  Future<ImportResult> importWords(String input) async {
    return _runBusy('正在导入单词…', () async {
      final entries = WordImportParser.parse(input);
      var imported = 0;
      var duplicates = 0;
      var failed = 0;
      for (final entry in entries) {
        if (entry.word.isEmpty) {
          failed++;
          continue;
        }
        try {
          final existing = await _wordRepository.findByWord(entry.word);
          if (existing != null) {
            duplicates++;
            continue;
          }
          await _wordRepository.create(
            WordModel(
              word: entry.word,
              meaningCn: entry.meaningCn,
              source: 'manual',
            ),
          );
          imported++;
        } on DatabaseException {
          duplicates++;
        } catch (_) {
          failed++;
        }
      }
      await refresh();
      return ImportResult(
        imported: imported,
        duplicates: duplicates,
        failed: failed,
      );
    });
  }

  Future<int> completeMissingWordDetails() async {
    return _runBusy('正在补全释义…', showDeepSeekSlowMessage: true, () async {
      final apiKey = await _requiredApiKey();
      final missing = await _wordRepository.findMissingDetails();
      var updated = 0;
      for (var start = 0; start < missing.length; start += 20) {
        final end = (start + 20).clamp(0, missing.length);
        final batch = missing.sublist(start, end);
        final details = await _deepSeekService.completeWordDetails(
          batch.map((word) => word.word).toList(growable: false),
          apiKey: apiKey,
          model: deepSeekModel,
        );
        final byWord = <String, WordModel>{
          for (final word in batch) word.word.toLowerCase(): word,
        };
        for (final detail in details) {
          final original = byWord[detail.word.toLowerCase()];
          if (original == null) {
            continue;
          }
          final changed = await _wordRepository.update(
            original.copyWith(
              phonetic: detail.phonetic,
              partOfSpeech: detail.partOfSpeech,
              meaningCn: detail.meaningCn,
              meaningEn: detail.meaningEn,
              exampleSentence: detail.exampleSentence,
              phrase: detail.phrases.join(', '),
              synonyms: detail.synonyms.join(', '),
              source: 'deepseek',
              aiGenerated: true,
            ),
          );
          if (changed) {
            updated++;
          }
        }
      }
      await refresh();
      return updated;
    });
  }

  Future<PlanGenerationResult> generateTodayPlan() async {
    return _runBusy('正在生成今日计划…', () async {
      final result = await _dailyPlanRepository.generateForDate(
        date: DateTime.now(),
        requestedCount: dailyWordCount,
        selectionMode: wordSelectionMode,
      );
      await refresh(selectLatestBatch: true);
      return result;
    });
  }

  Future<BatchAppendResult> appendTodayBatch(int count) async {
    final result = await _runBusy('正在追加新一组…', () async {
      final result = await _dailyPlanRepository.appendTodayBatch(
        count,
        selectionMode: wordSelectionMode,
      );
      await refresh(selectLatestBatch: true);
      return result;
    });
    if (result.addedCount > 0 && autoGenerateReadings) {
      await prepareTodayLearning(manualRetry: true, createPlan: false);
      final planId = todayPlan?.id;
      if (planId != null) {
        final generated = await _readingRepository.findByPlanAndBatch(
          planId,
          result.batchNo,
        );
        if (generated.map((passage) => passage.round).toSet().length == 2) {
          setActionMessage(
            '第 ${result.batchNo} 组已准备好，共 ${result.addedCount} 个单词。',
          );
        }
      }
    } else if (result.addedCount > 0 && !autoGenerateReadings) {
      setActionMessage('第 ${result.batchNo} 组单词已准备好，可从高级操作生成阅读。');
    }
    return result;
  }

  Future<void> prepareTodayLearning({
    bool manualRetry = false,
    bool createPlan = true,
  }) async {
    if (isPreparingToday) {
      return;
    }
    if (!manualRetry && !autoPrepareDaily) {
      return;
    }
    final dateKey = _dateKey(DateTime.now());
    if (!manualRetry &&
        lastPreparedDate == dateKey &&
        todayPlan != null &&
        passages.length == 2) {
      return;
    }
    isPreparingToday = true;
    actionMessage = null;
    preparationStatus = '正在准备今日单词…';
    notifyListeners();
    try {
      if (todayPlan == null && createPlan) {
        if (totalWordCount == 0) {
          setActionMessage('词库为空，请先在高级操作中初始化六级词库。');
          return;
        }
        await _dailyPlanRepository.generateForDate(
          date: DateTime.now(),
          requestedCount: dailyWordCount,
          selectionMode: wordSelectionMode,
        );
        await refresh(selectLatestBatch: true);
      }
      if (todayPlan == null || todayWords.isEmpty) {
        return;
      }
      if (!autoGenerateReadings && !manualRetry) {
        setActionMessage('今日单词已准备好，自动生成阅读已关闭。');
        lastPreparedDate = dateKey;
        return;
      }
      final apiKey = await _settingsService.getApiKey();
      hasApiKey = apiKey.isNotEmpty;
      if (apiKey.isEmpty) {
        setActionMessage('今日单词已准备好。请在设置页填写 DeepSeek API Key 后生成阅读。');
        lastPreparedDate = dateKey;
        return;
      }
      final originalBatch = selectedBatchNo;
      for (final batchNo in todayBatches) {
        await selectTodayBatch(batchNo);
        await _generateMissingPassages();
      }
      if (todayBatches.contains(originalBatch)) {
        await selectTodayBatch(originalBatch);
      }
      lastPreparedDate = dateKey;
      setActionMessage('今日学习已准备好。');
    } catch (error) {
      setActionMessage('阅读生成失败，可稍后重试：$error', isError: true);
    } finally {
      isPreparingToday = false;
      preparationStatus = null;
      notifyListeners();
    }
  }

  Future<void> retryMissingReadings() {
    return prepareTodayLearning(manualRetry: true, createPlan: true);
  }

  Future<void> _generateMissingPassages() async {
    final planId = todayPlan?.id;
    if (planId == null) {
      return;
    }
    var existing = await _readingRepository.findByPlanAndBatch(
      planId,
      selectedBatchNo,
    );
    final existingRounds = existing.map((passage) => passage.round).toSet();
    if (!existingRounds.contains(1)) {
      preparationStatus = '正在生成第 $selectedBatchNo 组阅读预热…';
      notifyListeners();
      await generatePassage(1);
    }
    existing = await _readingRepository.findByPlanAndBatch(
      planId,
      selectedBatchNo,
    );
    if (!existing.any((passage) => passage.round == 2)) {
      preparationStatus = '正在生成第 $selectedBatchNo 组语境强化…';
      notifyListeners();
      await generatePassage(2);
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<PlanGenerationResult> rebuildTodayPlan() async {
    return _runBusy('正在重建今日计划…', () async {
      await _dailyPlanRepository.deleteByDate(DateTime.now());
      _batchSelectionInitialized = false;
      final result = await _dailyPlanRepository.generateForDate(
        date: DateTime.now(),
        requestedCount: dailyWordCount,
        selectionMode: wordSelectionMode,
      );
      await refresh(selectLatestBatch: true);
      return result;
    });
  }

  Future<WordbookUpgradeResult> initializeBuiltinCet6Wordbook() async {
    return _runBusy('正在初始化六级词库…', () async {
      final result = await _wordbookService.importBuiltinCet6IfNeeded();
      await refresh();
      return result;
    });
  }

  Future<int> getBuiltinCet6Count() {
    return _wordbookService.getBuiltinCet6Count();
  }

  Future<List<WordModel>> searchWords({
    String query = '',
    bool starredOnly = false,
  }) {
    return _wordRepository.search(query: query, starredOnly: starredOnly);
  }

  Future<PagedWordsResult> searchWordsPage({
    String query = '',
    bool starredOnly = false,
    int limit = 100,
    int offset = 0,
  }) {
    return _wordRepository.searchPaged(
      query: query,
      starredOnly: starredOnly,
      limit: limit,
      offset: offset,
    );
  }

  Future<PagedWordsResult> searchSimilarWords({
    required String query,
    bool prefixOnly = false,
    int limit = 50,
    int offset = 0,
  }) {
    return _wordRepository.searchSimilarWords(
      query: query,
      prefixOnly: prefixOnly,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<WordModel>> findSimilarWordsByPrefix(String prefix) {
    return _wordRepository.findByPrefix(prefix);
  }

  Future<WordModel?> lookupWord(
    String rawWord, {
    required bool allowRemoteLookup,
  }) async {
    final word = await _wordLookupService.lookupWord(
      rawWord,
      allowRemoteLookup: allowRemoteLookup,
    );
    if (word != null && allowRemoteLookup) {
      totalWordCount = await _wordRepository.count();
      notifyListeners();
    }
    return word;
  }

  Future<ReadingPassageModel> generatePassage(int round) async {
    if (isGeneratingPassage) {
      throw const AppException('阅读正在生成中，请稍候。');
    }
    isGeneratingPassage = true;
    notifyListeners();
    try {
      return await _runBusy(
        '正在生成第$round篇阅读…',
        showDeepSeekSlowMessage: true,
        () async {
          if (round != 1 && round != 2) {
            throw const AppException('阅读轮次必须是 1 或 2。');
          }
          final plan = todayPlan;
          final planId = plan?.id;
          if (planId == null || todayWords.isEmpty) {
            throw const AppException('请先生成今日计划。');
          }
          final existing = passages[round];
          if (existing != null) {
            throw AppException('第$round篇阅读已经存在。');
          }
          if (round == 2 && passages[1] == null) {
            throw const AppException('请先生成第一篇阅读。');
          }
          final apiKey = await _requiredApiKey();
          final words = todayWords
              .map((item) => item.word.word)
              .toList(growable: false);
          final generated = round == 1
              ? await _deepSeekService.generateMorningPassage(
                  words,
                  apiKey: apiKey,
                  model: deepSeekModel,
                )
              : await _deepSeekService.generateAfternoonPassage(
                  words,
                  apiKey: apiKey,
                  model: deepSeekModel,
                  morningTitle: passages[1]?.title,
                );
          final normalized = _normalizeGeneratedPassage(generated, words);
          final passage = await _readingRepository.create(
            ReadingPassageModel(
              planId: planId,
              batchNo: selectedBatchNo,
              round: round,
              title: normalized.title,
              content: normalized.content,
              usedWords: normalized.usedWords,
              aiGenerated: true,
            ),
          );
          await refresh();
          return passage;
        },
      );
    } finally {
      isGeneratingPassage = false;
      notifyListeners();
    }
  }

  Future<PassageTranslation> translateReadingPassage(
    ReadingPassageModel passage, {
    bool force = false,
  }) async {
    final cached = passage.translationCn?.trim();
    if (!force && cached != null && cached.isNotEmpty) {
      return PassageTranslation(
        titleCn: passage.titleCn,
        translationCn: cached,
        sentencePairs: decodeTranslationSentencePairs(
          passage.sentencePairsJson,
        ),
        keyWordNotes: decodeTranslationKeyWordNotes(passage.keyWordNotesJson),
      );
    }
    return _runBusy('正在翻译全文…', showDeepSeekSlowMessage: true, () async {
      final id = passage.id;
      final content = passage.content?.trim();
      if (id == null || content == null || content.isEmpty) {
        throw const AppException('短文内容为空，无法翻译。');
      }
      final apiKey = await _requiredApiKey();
      try {
        final translation = await _deepSeekService.translatePassageToChinese(
          title: passage.title ?? '',
          content: content,
          targetWords: passage.usedWords,
          apiKey: apiKey,
          model: deepSeekModel,
        );
        final saved = await _readingRepository.saveTranslation(
          id: id,
          titleCn: translation.titleCn,
          translationCn: translation.translationCn,
          sentencePairsJson: encodeTranslationSentencePairs(
            translation.sentencePairs,
          ),
          keyWordNotesJson: encodeTranslationKeyWordNotes(
            translation.keyWordNotes,
          ),
          translatedAt: DateTime.now().toUtc(),
        );
        if (saved.batchNo == selectedBatchNo) {
          passages = <int, ReadingPassageModel>{
            ...passages,
            saved.round: saved,
          };
          notifyListeners();
        }
        return PassageTranslation(
          titleCn: saved.titleCn,
          translationCn: saved.translationCn!,
          sentencePairs: decodeTranslationSentencePairs(
            saved.sentencePairsJson,
          ),
          keyWordNotes: decodeTranslationKeyWordNotes(saved.keyWordNotesJson),
        );
      } on DeepSeekException catch (error) {
        throw AppException(error.message);
      }
    });
  }

  GeneratedPassage _normalizeGeneratedPassage(
    GeneratedPassage generated,
    List<String> words,
  ) {
    final content = generated.content;
    final contentWords = words.where(
      (word) => _containsWholeWord(content, word),
    );
    final usedWords = <String>{
      ...generated.usedWords.map((word) => word.toLowerCase()),
      ...contentWords.map((word) => word.toLowerCase()),
    }.toList()..sort();
    final missing = words
        .where((word) => !usedWords.contains(word.toLowerCase()))
        .toList(growable: false);
    if (missing.length == words.length) {
      throw const AppException('DeepSeek 返回的文章没有包含今日目标单词，请重试。');
    }
    return GeneratedPassage(
      title: generated.title,
      content: generated.content,
      usedWords: usedWords,
    );
  }

  @visibleForTesting
  GeneratedPassage normalizeGeneratedPassageForTesting(
    GeneratedPassage generated,
    List<String> words,
  ) {
    return _normalizeGeneratedPassage(generated, words);
  }

  bool _containsWholeWord(String content, String word) {
    final pattern = RegExp(
      r'\b' + RegExp.escape(word) + r'\b',
      caseSensitive: false,
    );
    return pattern.hasMatch(content);
  }

  Future<void> completeRound(
    int round, {
    required int batchNo,
    int durationSeconds = 0,
  }) async {
    final planId = todayPlan?.id;
    if (planId == null) {
      throw const AppException('今日计划不存在。');
    }
    await _dailyPlanRepository.completeRound(
      planId: planId,
      batchNo: batchNo,
      round: round,
      durationSeconds: durationSeconds,
    );
    final updatedRounds = <int>{
      ...(completedRoundsByBatch[batchNo] ?? const <int>{}),
      round,
    };
    completedRoundsByBatch = <int, Set<int>>{
      ...completedRoundsByBatch,
      batchNo: updatedRounds,
    };
    if (batchNo == selectedBatchNo) {
      completedRounds = updatedRounds;
    }
    notifyListeners();
  }

  Future<void> setMemoryStatus(PlanWordModel item, String status) async {
    final planId = todayPlan?.id;
    final wordId = item.word.id;
    if (planId == null || wordId == null) {
      return;
    }
    await _dailyPlanRepository.setMemoryStatus(
      planId: planId,
      wordId: wordId,
      batchNo: item.batchNo,
      memoryStatus: status,
    );
    allTodayWords = allTodayWords
        .map(
          (entry) => entry.word.id == wordId && entry.batchNo == item.batchNo
              ? entry.copyWith(
                  memoryStatus: status,
                  reviewCount: entry.reviewCount + 1,
                  lastReviewedAt: DateTime.now().toUtc(),
                )
              : entry,
        )
        .toList(growable: false);
    todayWords = allTodayWords
        .where((entry) => entry.batchNo == selectedBatchNo)
        .toList(growable: false);
    notifyListeners();
  }

  Future<WordModel> toggleStar(WordModel word) async {
    final id = word.id;
    if (id == null) {
      return word;
    }
    final updated = word.copyWith(isStarred: !word.isStarred);
    await _wordRepository.setStarred(id: id, isStarred: updated.isStarred);
    allTodayWords = allTodayWords
        .map((item) => item.word.id == id ? item.copyWith(word: updated) : item)
        .toList(growable: false);
    todayWords = allTodayWords
        .where((item) => item.batchNo == selectedBatchNo)
        .toList(growable: false);
    notifyListeners();
    return updated;
  }

  Future<List<WordModel>> getStarredWords() {
    return _wordRepository.findAll(starredOnly: true);
  }

  Future<List<WordBookModel>> getAllWordBooks() {
    return _wordBookRepository.getAllWordBooks();
  }

  Future<WordBookModel?> getWordBook(int id) {
    return _wordBookRepository.findById(id);
  }

  Future<WordBookModel> createWordBook(
    String name, {
    String? description,
  }) async {
    final wordBook = await _wordBookRepository.createWordBook(
      name,
      description: description,
    );
    notifyListeners();
    return wordBook;
  }

  Future<bool> updateWordBook(WordBookModel wordBook) async {
    final changed = await _wordBookRepository.updateWordBook(wordBook);
    notifyListeners();
    return changed;
  }

  Future<bool> deleteWordBook(int id) async {
    final changed = await _wordBookRepository.deleteWordBook(id);
    notifyListeners();
    return changed;
  }

  Future<int> addWordsToWordBooks(
    List<WordModel> words,
    List<int> wordBookIds,
  ) async {
    final wordIds = words
        .map((word) => word.id)
        .whereType<int>()
        .toList(growable: false);
    if (wordIds.isEmpty || wordBookIds.isEmpty) {
      return 0;
    }
    var added = 0;
    for (final wordBookId in wordBookIds.toSet()) {
      added += await _wordBookRepository.addWordsToBook(wordBookId, wordIds);
    }
    notifyListeners();
    return added;
  }

  Future<bool> removeWordFromBook(int wordBookId, int wordId) async {
    final changed = await _wordBookRepository.removeWordFromBook(
      wordBookId,
      wordId,
    );
    notifyListeners();
    return changed;
  }

  Future<List<WordModel>> getWordsInBook(int wordBookId, {String query = ''}) {
    return _wordBookRepository.getWordsInBook(wordBookId, query: query);
  }

  Future<List<WordBookModel>> getBooksContainingWord(int wordId) {
    return _wordBookRepository.getBooksContainingWord(wordId);
  }

  Future<List<ConfusingWordGroupModel>> getAllConfusingGroups() {
    return _confusingWordGroupRepository.getAllGroups();
  }

  Future<ConfusingWordGroupModel?> getConfusingGroup(int id) {
    return _confusingWordGroupRepository.findById(id);
  }

  Future<ConfusingWordGroupModel> createConfusingGroup(
    String title,
    List<WordModel> words, {
    String? description,
  }) async {
    final wordIds = words
        .map((word) => word.id)
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    if (wordIds.length < 2) {
      throw const AppException('至少选择 2 个单词创建易混词组。');
    }
    final group = await _confusingWordGroupRepository.createGroup(
      title,
      wordIds,
      description: description,
    );
    notifyListeners();
    return group;
  }

  Future<bool> deleteConfusingGroup(int groupId) async {
    final changed = await _confusingWordGroupRepository.deleteGroup(groupId);
    notifyListeners();
    return changed;
  }

  Future<bool> addWordToConfusingGroup(int groupId, int wordId) async {
    final changed = await _confusingWordGroupRepository.addWordToGroup(
      groupId,
      wordId,
    );
    notifyListeners();
    return changed;
  }

  Future<bool> removeWordFromConfusingGroup(int groupId, int wordId) async {
    final changed = await _confusingWordGroupRepository.removeWordFromGroup(
      groupId,
      wordId,
    );
    notifyListeners();
    return changed;
  }

  Future<List<WordModel>> getWordsInConfusingGroup(int groupId) {
    return _confusingWordGroupRepository.getWordsInGroup(groupId);
  }

  Future<String> generateConfusingWordsAnalysis(
    ConfusingWordGroupModel group,
  ) async {
    return _runBusy('正在生成易混词辨析…', showDeepSeekSlowMessage: true, () async {
      final groupId = group.id;
      if (groupId == null) {
        throw const AppException('易混词组不存在。');
      }
      final words = await _confusingWordGroupRepository.getWordsInGroup(
        groupId,
      );
      try {
        DeepSeekService.validateConfusingWordsForAnalysis(words);
      } on DeepSeekException catch (error) {
        throw AppException(error.message);
      }
      final apiKey = await _requiredApiKey();
      try {
        final analysis = await _deepSeekService.generateConfusingWordsAnalysis(
          words,
          apiKey: apiKey,
          model: deepSeekModel,
        );
        await _confusingWordGroupRepository.saveAnalysis(groupId, analysis);
        notifyListeners();
        return analysis;
      } on DeepSeekException catch (error) {
        throw AppException(error.message);
      }
    });
  }

  Future<String> askEnglishAssistant(List<AssistantMessage> messages) {
    return _runBusy('英语助手正在思考…', showDeepSeekSlowMessage: true, () async {
      final apiKey = await _requiredApiKey();
      try {
        return await _deepSeekService.answerEnglishQuestion(
          messages,
          apiKey: apiKey,
          model: deepSeekModel,
        );
      } on DeepSeekException catch (error) {
        throw AppException(error.message);
      }
    });
  }

  Future<CollectionPassageModel?> getLatestCollectionPassage({
    required String sourceType,
    required int sourceId,
  }) {
    return _collectionPassageRepository.findLatest(
      sourceType: sourceType,
      sourceId: sourceId,
    );
  }

  Future<CollectionPassageModel> generateCollectionPassage({
    required String sourceType,
    required int sourceId,
    required String sourceName,
    required List<WordModel> words,
  }) {
    return _runBusy('正在生成记忆短文…', showDeepSeekSlowMessage: true, () async {
      if (sourceType == 'word_book' && words.isEmpty) {
        throw const AppException('单词本为空，无法生成短文。');
      }
      if (sourceType == 'confusing_group' && words.length < 2) {
        throw const AppException('至少需要 2 个词。');
      }
      if (words.length > 30) {
        throw const AppException('一次最多使用 30 个词生成短文。');
      }
      final apiKey = await _requiredApiKey();
      try {
        final wordValues = words
            .map((word) => word.word)
            .toList(growable: false);
        final generated = await _deepSeekService.generatePassageForWords(
          words: wordValues,
          purpose: sourceType,
          sourceName: sourceName,
          apiKey: apiKey,
          model: deepSeekModel,
        );
        final normalized = _normalizeGeneratedPassage(generated, wordValues);
        return _collectionPassageRepository.create(
          CollectionPassageModel(
            sourceType: sourceType,
            sourceId: sourceId,
            title: normalized.title,
            content: normalized.content,
            usedWords: normalized.usedWords,
          ),
        );
      } on DeepSeekException catch (error) {
        throw AppException(error.message);
      }
    });
  }

  Future<PassageTranslation> translateCollectionPassage(
    CollectionPassageModel passage, {
    bool force = false,
  }) async {
    final cached = passage.translationCn?.trim();
    if (!force && cached != null && cached.isNotEmpty) {
      return PassageTranslation(
        titleCn: passage.titleCn,
        translationCn: cached,
        sentencePairs: decodeTranslationSentencePairs(
          passage.sentencePairsJson,
        ),
        keyWordNotes: decodeTranslationKeyWordNotes(passage.keyWordNotesJson),
      );
    }
    return _runBusy('正在翻译全文…', showDeepSeekSlowMessage: true, () async {
      final id = passage.id;
      final content = passage.content?.trim();
      if (id == null || content == null || content.isEmpty) {
        throw const AppException('短文内容为空，无法翻译。');
      }
      final apiKey = await _requiredApiKey();
      try {
        final translation = await _deepSeekService.translatePassageToChinese(
          title: passage.title ?? '',
          content: content,
          targetWords: passage.usedWords,
          apiKey: apiKey,
          model: deepSeekModel,
        );
        final saved = await _collectionPassageRepository.saveTranslation(
          id: id,
          titleCn: translation.titleCn,
          translationCn: translation.translationCn,
          sentencePairsJson: encodeTranslationSentencePairs(
            translation.sentencePairs,
          ),
          keyWordNotesJson: encodeTranslationKeyWordNotes(
            translation.keyWordNotes,
          ),
          translatedAt: DateTime.now().toUtc(),
        );
        return PassageTranslation(
          titleCn: saved.titleCn,
          translationCn: saved.translationCn!,
          sentencePairs: decodeTranslationSentencePairs(
            saved.sentencePairsJson,
          ),
          keyWordNotes: decodeTranslationKeyWordNotes(saved.keyWordNotesJson),
        );
      } on DeepSeekException catch (error) {
        throw AppException(error.message);
      }
    });
  }

  Future<List<HistoryDayModel>> getHistory() async {
    final plans = await _dailyPlanRepository.findAll();
    final history = <HistoryDayModel>[];
    for (final plan in plans) {
      final id = plan.id;
      if (id == null) {
        continue;
      }
      history.add(
        HistoryDayModel(
          plan: plan,
          words: await _dailyPlanRepository.getPlanWords(id),
          completedRoundsByBatch: await _dailyPlanRepository
              .getCompletedRoundsByBatch(id),
        ),
      );
    }
    return history;
  }

  Future<String> loadApiKey() => _settingsService.getApiKey();

  Future<void> saveSettings({
    required String apiKey,
    required int wordCount,
    required WordSelectionMode selectionMode,
    required bool autoPrepareDaily,
    required bool autoGenerateReadings,
    required DeepSeekModel deepSeekModel,
    required bool checkUpdatesOnLaunch,
  }) async {
    await _settingsService.saveApiKey(apiKey);
    await _settingsService.saveDailyWordCount(wordCount);
    await _settingsService.saveWordSelectionMode(selectionMode);
    await _settingsService.saveAutoPrepareDaily(autoPrepareDaily);
    await _settingsService.saveAutoGenerateReadings(autoGenerateReadings);
    await _settingsService.saveDeepSeekModel(deepSeekModel);
    await _settingsService.saveCheckUpdatesOnLaunch(checkUpdatesOnLaunch);
    hasApiKey = apiKey.trim().isNotEmpty;
    dailyWordCount = wordCount;
    wordSelectionMode = selectionMode;
    this.autoPrepareDaily = autoPrepareDaily;
    this.autoGenerateReadings = autoGenerateReadings;
    this.deepSeekModel = deepSeekModel;
    this.checkUpdatesOnLaunch = checkUpdatesOnLaunch;
    notifyListeners();
  }

  Future<AppRelease?> checkForUpdate() async {
    try {
      return await _updateService.checkForUpdate();
    } on UpdateException catch (error) {
      throw AppException(error.message);
    }
  }

  Future<void> openRelease(AppRelease release) async {
    try {
      await _updateService.openRelease(release);
    } on UpdateException catch (error) {
      throw AppException(error.message);
    }
  }

  Future<BackupExportResult> exportLearningData() {
    return _runBusy('正在导出学习数据…', _backupService.exportAndShare);
  }

  Future<String?> pickBackupJson() => _backupService.pickBackupJson();

  Future<BackupRestoreResult> restoreLearningData(String source) {
    return _runBusy('正在合并学习数据…', () async {
      final result = await _backupService.restoreBackupJson(source);
      await refresh(selectLatestBatch: true);
      return result;
    });
  }

  Future<void> testDeepSeekConnection(String apiKey, {DeepSeekModel? model}) {
    return _deepSeekService.testConnection(
      apiKey.trim(),
      model: model ?? deepSeekModel,
    );
  }

  Future<void> speakWord(String word) async {
    try {
      await _ttsService.speakWord(word);
      ttsStatus = _ttsService.status;
      notifyListeners();
    } on TtsException catch (error) {
      throw AppException(error.message);
    }
  }

  Future<void> testSpeech() => speakWord('academic');

  Future<void> setTtsVoicePreference(TtsVoicePreference preference) async {
    await _settingsService.saveTtsVoicePreference(preference);
    ttsVoicePreference = preference;
    await refreshTtsStatus();
  }

  Future<void> refreshTtsStatus() async {
    ttsStatus = const TtsStatus(TtsAvailability.checking);
    notifyListeners();
    ttsStatus = await _ttsService.detectStatus(refresh: true);
    notifyListeners();
  }

  Future<bool> openTtsVoiceDataSettings() {
    return _ttsSettingsLauncher.openInstallTtsData();
  }

  void setActionMessage(String message, {bool isError = false}) {
    actionMessage = message;
    actionMessageIsError = isError;
    notifyListeners();
  }

  void clearActionMessage() {
    actionMessage = null;
    actionMessageIsError = false;
    notifyListeners();
  }

  Future<String> _requiredApiKey() async {
    final apiKey = await _settingsService.getApiKey();
    if (apiKey.isEmpty) {
      throw const AppException('请先在设置页填写 DeepSeek API Key。');
    }
    return apiKey;
  }

  Future<T> _runBusy<T>(
    String message,
    Future<T> Function() action, {
    bool showDeepSeekSlowMessage = false,
  }) async {
    isBusy = true;
    activeOperation = message;
    slowOperationMessage = null;
    notifyListeners();
    final timer = showDeepSeekSlowMessage
        ? Timer(const Duration(seconds: 15), () {
            if (isBusy) {
              slowOperationMessage = deepSeekModel == DeepSeekModel.highQuality
                  ? 'DeepSeek 响应较慢，请稍等。当前使用 deepseek-v4-pro，可在设置中切换 deepseek-v4-flash 快速模式。'
                  : 'DeepSeek 响应较慢，请稍等或稍后重试。';
              notifyListeners();
            }
          })
        : null;
    try {
      return await action();
    } finally {
      timer?.cancel();
      isBusy = false;
      activeOperation = null;
      slowOperationMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_ttsService.dispose());
    super.dispose();
  }
}

final class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
