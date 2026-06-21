abstract final class DatabaseSchema {
  static const databaseName = 'context_words.db';
  static const databaseVersion = 5;

  static const wordsTable = 'words';
  static const dailyPlansTable = 'daily_plans';
  static const dailyPlanWordsTable = 'daily_plan_words';
  static const readingPassagesTable = 'reading_passages';
  static const studyLogsTable = 'study_logs';
  static const wordBooksTable = 'word_books';
  static const wordBookItemsTable = 'word_book_items';
  static const confusingWordGroupsTable = 'confusing_word_groups';
  static const confusingWordGroupItemsTable = 'confusing_word_group_items';
  static const collectionPassagesTable = 'collection_passages';

  static const createWordsTable =
      '''
CREATE TABLE $wordsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  word TEXT NOT NULL UNIQUE,
  phonetic TEXT,
  part_of_speech TEXT,
  meaning_cn TEXT,
  meaning_en TEXT,
  example_sentence TEXT,
  phrase TEXT,
  synonyms TEXT,
  difficulty TEXT,
  source TEXT,
  is_starred INTEGER NOT NULL DEFAULT 0 CHECK (is_starred IN (0, 1)),
  ai_generated INTEGER NOT NULL DEFAULT 0 CHECK (ai_generated IN (0, 1)),
  created_at TEXT,
  updated_at TEXT
)
''';

  static const createDailyPlansTable =
      '''
CREATE TABLE $dailyPlansTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL UNIQUE,
  word_count INTEGER,
  status TEXT,
  created_at TEXT
)
''';

  static const createDailyPlanWordsTable =
      '''
CREATE TABLE $dailyPlanWordsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  word_id INTEGER NOT NULL,
  batch_no INTEGER NOT NULL DEFAULT 1 CHECK (batch_no >= 1),
  memory_status TEXT NOT NULL DEFAULT 'new',
  review_count INTEGER NOT NULL DEFAULT 0,
  last_reviewed_at TEXT,
  FOREIGN KEY (plan_id) REFERENCES $dailyPlansTable (id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES $wordsTable (id) ON DELETE CASCADE,
  UNIQUE (plan_id, word_id)
)
''';

  static const createReadingPassagesTable =
      '''
CREATE TABLE $readingPassagesTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  batch_no INTEGER NOT NULL DEFAULT 1 CHECK (batch_no >= 1),
  round INTEGER NOT NULL CHECK (round IN (1, 2)),
  title TEXT,
  content TEXT,
  used_words TEXT,
  title_cn TEXT,
  translation_cn TEXT,
  translated_at TEXT,
  ai_generated INTEGER NOT NULL DEFAULT 0 CHECK (ai_generated IN (0, 1)),
  created_at TEXT,
  FOREIGN KEY (plan_id) REFERENCES $dailyPlansTable (id) ON DELETE CASCADE,
  UNIQUE (plan_id, batch_no, round)
)
''';

  static const createStudyLogsTable =
      '''
CREATE TABLE $studyLogsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  batch_no INTEGER NOT NULL DEFAULT 1 CHECK (batch_no >= 1),
  round INTEGER NOT NULL CHECK (round BETWEEN 1 AND 3),
  completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
  completed_at TEXT,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (plan_id) REFERENCES $dailyPlansTable (id) ON DELETE CASCADE,
  UNIQUE (plan_id, batch_no, round)
)
''';

  static const createWordBooksTable =
      '''
CREATE TABLE $wordBooksTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT,
  created_at TEXT,
  updated_at TEXT
)
''';

  static const createWordBookItemsTable =
      '''
CREATE TABLE $wordBookItemsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  word_book_id INTEGER NOT NULL,
  word_id INTEGER NOT NULL,
  created_at TEXT,
  FOREIGN KEY (word_book_id) REFERENCES $wordBooksTable (id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES $wordsTable (id) ON DELETE CASCADE,
  UNIQUE (word_book_id, word_id)
)
''';

  static const createConfusingWordGroupsTable =
      '''
CREATE TABLE $confusingWordGroupsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT,
  analysis TEXT,
  created_at TEXT,
  updated_at TEXT
)
''';

  static const createConfusingWordGroupItemsTable =
      '''
CREATE TABLE $confusingWordGroupItemsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL,
  word_id INTEGER NOT NULL,
  created_at TEXT,
  FOREIGN KEY (group_id) REFERENCES $confusingWordGroupsTable (id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES $wordsTable (id) ON DELETE CASCADE,
  UNIQUE (group_id, word_id)
)
''';

  static const createCollectionPassagesTable =
      '''
CREATE TABLE IF NOT EXISTS $collectionPassagesTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_type TEXT NOT NULL CHECK (source_type IN ('word_book', 'confusing_group')),
  source_id INTEGER NOT NULL,
  title TEXT,
  content TEXT,
  used_words TEXT,
  title_cn TEXT,
  translation_cn TEXT,
  translated_at TEXT,
  created_at TEXT NOT NULL
)
''';

  static const version5TranslationColumns = <String, List<String>>{
    readingPassagesTable: <String>[
      'title_cn',
      'translation_cn',
      'translated_at',
    ],
    collectionPassagesTable: <String>[
      'title_cn',
      'translation_cn',
      'translated_at',
    ],
  };

  static const createCollectionPassagesSourceIndex =
      '''
CREATE INDEX IF NOT EXISTS idx_collection_passages_source
ON $collectionPassagesTable (source_type, source_id, created_at DESC)
''';

  static const version4CreateStatements = <String>[
    createCollectionPassagesTable,
    createCollectionPassagesSourceIndex,
  ];

  static const createDailyPlanWordsPlanIndex =
      '''
CREATE INDEX idx_daily_plan_words_plan_id
ON $dailyPlanWordsTable (plan_id)
''';

  static const createDailyPlanWordsWordIndex =
      '''
CREATE INDEX idx_daily_plan_words_word_id
ON $dailyPlanWordsTable (word_id)
''';

  static const createDailyPlanWordsBatchIndex =
      '''
CREATE INDEX idx_daily_plan_words_plan_batch
ON $dailyPlanWordsTable (plan_id, batch_no)
''';

  static const createReadingPassagesPlanIndex =
      '''
CREATE INDEX idx_reading_passages_plan_batch_v3
ON $readingPassagesTable (plan_id)
''';

  static const createStudyLogsPlanIndex =
      '''
CREATE INDEX idx_study_logs_plan_batch_v3
ON $studyLogsTable (plan_id)
''';

  static const addBatchNoToDailyPlanWords =
      '''
ALTER TABLE $dailyPlanWordsTable
ADD COLUMN batch_no INTEGER NOT NULL DEFAULT 1 CHECK (batch_no >= 1)
''';

  static const renameReadingPassagesV2 =
      '''
ALTER TABLE $readingPassagesTable RENAME TO reading_passages_v2_backup
''';

  static const copyReadingPassagesFromV2 =
      '''
INSERT INTO $readingPassagesTable (
  id, plan_id, batch_no, round, title, content, used_words,
  ai_generated, created_at
)
SELECT
  id, plan_id, 1, round, title, content, used_words,
  ai_generated, created_at
FROM reading_passages_v2_backup
''';

  static const renameStudyLogsV2 =
      '''
ALTER TABLE $studyLogsTable RENAME TO study_logs_v2_backup
''';

  static const copyStudyLogsFromV2 =
      '''
INSERT INTO $studyLogsTable (
  id, plan_id, batch_no, round, completed, completed_at, duration_seconds
)
SELECT
  id, plan_id, 1, round, completed, completed_at, duration_seconds
FROM study_logs_v2_backup
''';

  static const createWordBookItemsBookIndex =
      '''
CREATE INDEX idx_word_book_items_word_book_id
ON $wordBookItemsTable (word_book_id)
''';

  static const createWordBookItemsWordIndex =
      '''
CREATE INDEX idx_word_book_items_word_id
ON $wordBookItemsTable (word_id)
''';

  static const createConfusingWordGroupItemsGroupIndex =
      '''
CREATE INDEX idx_confusing_word_group_items_group_id
ON $confusingWordGroupItemsTable (group_id)
''';

  static const createConfusingWordGroupItemsWordIndex =
      '''
CREATE INDEX idx_confusing_word_group_items_word_id
ON $confusingWordGroupItemsTable (word_id)
''';

  static const version2CreateStatements = <String>[
    createWordBooksTable,
    createWordBookItemsTable,
    createConfusingWordGroupsTable,
    createConfusingWordGroupItemsTable,
    createWordBookItemsBookIndex,
    createWordBookItemsWordIndex,
    createConfusingWordGroupItemsGroupIndex,
    createConfusingWordGroupItemsWordIndex,
  ];

  static const createStatements = <String>[
    createWordsTable,
    createDailyPlansTable,
    createDailyPlanWordsTable,
    createReadingPassagesTable,
    createStudyLogsTable,
    createDailyPlanWordsPlanIndex,
    createDailyPlanWordsWordIndex,
    createDailyPlanWordsBatchIndex,
    createReadingPassagesPlanIndex,
    createStudyLogsPlanIndex,
    ...version2CreateStatements,
    ...version4CreateStatements,
  ];
}
