import 'package:sqlite3/sqlite3.dart';

import 'progress_store.dart';

/// Stockage SQLite local (Android, Windows, macOS, Linux).
///
/// SQLite est embarqué dans l'application par le paquet `sqlite3` :
/// aucune dépendance système ni connexion n'est nécessaire.
class SqliteProgressStore implements ProgressStore {
  SqliteProgressStore._(this._db);

  /// Ouvre (ou crée) la base au chemin donné. `:memory:` pour les tests.
  factory SqliteProgressStore.open(String path) {
    final db = sqlite3.open(path);
    final store = SqliteProgressStore._(db);
    store._migrate();
    return store;
  }

  final Database _db;

  static const schemaVersion = 2;

  void _migrate() {
    final version = _db.select('PRAGMA user_version').first.values.first as int;
    if (version < 1) {
      _db.execute('''
        CREATE TABLE IF NOT EXISTS answers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question_id TEXT NOT NULL,
          chapter_id TEXT NOT NULL,
          domain_id TEXT NOT NULL,
          concept TEXT NOT NULL,
          chosen TEXT NOT NULL,
          correct INTEGER NOT NULL,
          mode TEXT NOT NULL,
          session_id INTEGER,
          answered_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_answers_question ON answers(question_id);
        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mode TEXT NOT NULL,
          chapter_id TEXT,
          correct_count INTEGER NOT NULL,
          total INTEGER NOT NULL,
          duration_seconds INTEGER NOT NULL,
          finished_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS cards (
          card_id TEXT PRIMARY KEY,
          ease REAL NOT NULL,
          interval_days INTEGER NOT NULL,
          repetitions INTEGER NOT NULL,
          lapses INTEGER NOT NULL,
          due INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS lessons_read (
          lesson_id TEXT PRIMARY KEY,
          read_at INTEGER NOT NULL
        );
        PRAGMA user_version = 1;
      ''');
    }
    if (version < 2) {
      _db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
        PRAGMA user_version = 2;
      ''');
    }
  }

  @override
  Future<void> addAnswers(List<AnswerRecord> answers) async {
    final stmt = _db.prepare('''
      INSERT INTO answers (question_id, chapter_id, domain_id, concept, chosen,
        correct, mode, session_id, answered_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    _db.execute('BEGIN');
    try {
      for (final a in answers) {
        stmt.execute([
          a.questionId,
          a.chapterId,
          a.domainId,
          a.concept,
          (a.chosen.toList()..sort()).join(','),
          a.correct ? 1 : 0,
          a.mode.name,
          a.sessionId,
          a.answeredAt.millisecondsSinceEpoch,
        ]);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      stmt.close();
    }
  }

  @override
  Future<List<AnswerRecord>> answers() async {
    final rows = _db.select('SELECT * FROM answers ORDER BY answered_at, id');
    return [
      for (final r in rows)
        AnswerRecord(
          questionId: r['question_id'] as String,
          chapterId: r['chapter_id'] as String,
          domainId: r['domain_id'] as String,
          concept: r['concept'] as String,
          chosen: (r['chosen'] as String)
              .split(',')
              .where((s) => s.isNotEmpty)
              .map(int.parse)
              .toSet(),
          correct: r['correct'] == 1,
          mode: SessionMode.parse(r['mode'] as String),
          sessionId: r['session_id'] as int?,
          answeredAt: DateTime.fromMillisecondsSinceEpoch(
            r['answered_at'] as int,
          ),
        ),
    ];
  }

  @override
  Future<int> addSession(SessionRecord s) async {
    _db.execute(
      '''
      INSERT INTO sessions (mode, chapter_id, correct_count, total,
        duration_seconds, finished_at) VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [
        s.mode.name,
        s.chapterId,
        s.correctCount,
        s.total,
        s.durationSeconds,
        s.finishedAt.millisecondsSinceEpoch,
      ],
    );
    return _db.lastInsertRowId;
  }

  @override
  Future<List<SessionRecord>> sessions() async {
    final rows = _db.select('SELECT * FROM sessions ORDER BY finished_at, id');
    return [
      for (final r in rows)
        SessionRecord(
          id: r['id'] as int,
          mode: SessionMode.parse(r['mode'] as String),
          chapterId: r['chapter_id'] as String?,
          correctCount: r['correct_count'] as int,
          total: r['total'] as int,
          durationSeconds: r['duration_seconds'] as int,
          finishedAt: DateTime.fromMillisecondsSinceEpoch(
            r['finished_at'] as int,
          ),
        ),
    ];
  }

  @override
  Future<void> saveCard(CardState c) async {
    _db.execute(
      '''
      INSERT INTO cards (card_id, ease, interval_days, repetitions, lapses, due)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(card_id) DO UPDATE SET ease = excluded.ease,
        interval_days = excluded.interval_days,
        repetitions = excluded.repetitions, lapses = excluded.lapses,
        due = excluded.due
    ''',
      [
        c.cardId,
        c.ease,
        c.intervalDays,
        c.repetitions,
        c.lapses,
        c.due.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<Map<String, CardState>> cards() async {
    final rows = _db.select('SELECT * FROM cards');
    return {
      for (final r in rows)
        r['card_id'] as String: CardState(
          cardId: r['card_id'] as String,
          ease: (r['ease'] as num).toDouble(),
          intervalDays: r['interval_days'] as int,
          repetitions: r['repetitions'] as int,
          lapses: r['lapses'] as int,
          due: DateTime.fromMillisecondsSinceEpoch(r['due'] as int),
        ),
    };
  }

  @override
  Future<void> markLessonRead(String lessonId, DateTime at) async {
    _db.execute(
      'INSERT OR IGNORE INTO lessons_read (lesson_id, read_at) VALUES (?, ?)',
      [lessonId, at.millisecondsSinceEpoch],
    );
  }

  @override
  Future<Set<String>> readLessons() async => _db
      .select('SELECT lesson_id FROM lessons_read')
      .map((r) => r['lesson_id'] as String)
      .toSet();

  @override
  Future<String?> setting(String key) async {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    _db.execute(
      'INSERT INTO settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

  @override
  Future<void> clear() async {
    _db.execute('''
      DELETE FROM answers; DELETE FROM sessions; DELETE FROM cards;
      DELETE FROM lessons_read;
    ''');
  }

  @override
  Future<void> close() async => _db.close();
}
