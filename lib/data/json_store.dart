import 'dart:convert';

import 'progress_store.dart';

/// Progression en mémoire, sauvegardée en un texte JSON à chaque écriture.
///
/// Utilisée par la version navigateur (fichier HTML autonome) : le texte est
/// rangé dans le `localStorage` du navigateur. Les réglages suivent la même
/// voie. Un texte illisible est ignoré (on repart d'une progression vide).
class JsonProgressStore extends MemoryProgressStore {
  JsonProgressStore({String? initial, required this.save}) {
    if (initial != null && initial.isNotEmpty) {
      try {
        _load(jsonDecode(initial) as Map<String, dynamic>);
      } catch (_) {
        // Données abîmées : on garde une progression vide.
      }
    }
  }

  /// Reçoit le JSON complet après chaque modification.
  final void Function(String json) save;

  static const formatVersion = 1;

  void _load(Map<String, dynamic> m) {
    for (final a in (m['answers'] as List? ?? const [])) {
      final r = a as Map<String, dynamic>;
      super.addAnswers([
        AnswerRecord(
          questionId: r['q'] as String,
          chapterId: r['c'] as String,
          domainId: r['d'] as String,
          concept: r['k'] as String,
          chosen: {for (final i in r['ch'] as List) i as int},
          correct: r['ok'] as bool,
          mode: SessionMode.parse(r['m'] as String),
          answeredAt: DateTime.parse(r['at'] as String),
          sessionId: r['s'] as int?,
        ),
      ]);
    }
    for (final s in (m['sessions'] as List? ?? const [])) {
      final r = s as Map<String, dynamic>;
      super.addSession(
        SessionRecord(
          mode: SessionMode.parse(r['m'] as String),
          chapterId: r['c'] as String?,
          correctCount: r['ok'] as int,
          total: r['n'] as int,
          durationSeconds: r['sec'] as int,
          finishedAt: DateTime.parse(r['at'] as String),
        ),
      );
    }
    for (final c in (m['cards'] as List? ?? const [])) {
      final r = c as Map<String, dynamic>;
      super.saveCard(
        CardState(
          cardId: r['id'] as String,
          ease: (r['e'] as num).toDouble(),
          intervalDays: r['i'] as int,
          repetitions: r['r'] as int,
          lapses: r['l'] as int,
          due: DateTime.parse(r['due'] as String),
        ),
      );
    }
    final read = m['lessons'] as Map<String, dynamic>? ?? const {};
    for (final e in read.entries) {
      _readAt[e.key] = DateTime.parse(e.value as String);
      super.markLessonRead(e.key, _readAt[e.key]!);
    }
    final settings = m['settings'] as Map<String, dynamic>? ?? const {};
    for (final e in settings.entries) {
      _settingsCopy[e.key] = e.value as String;
      super.setSetting(e.key, e.value as String);
    }
  }

  final _readAt = <String, DateTime>{};
  final _settingsCopy = <String, String>{};

  Future<String> toJson() async {
    return jsonEncode({
      'v': formatVersion,
      'answers': [
        for (final a in await answers())
          {
            'q': a.questionId,
            'c': a.chapterId,
            'd': a.domainId,
            'k': a.concept,
            'ch': a.chosen.toList()..sort(),
            'ok': a.correct,
            'm': a.mode.name,
            'at': a.answeredAt.toIso8601String(),
            if (a.sessionId != null) 's': a.sessionId,
          },
      ],
      'sessions': [
        for (final s in await sessions())
          {
            'm': s.mode.name,
            'c': s.chapterId,
            'ok': s.correctCount,
            'n': s.total,
            'sec': s.durationSeconds,
            'at': s.finishedAt.toIso8601String(),
          },
      ],
      'cards': [
        for (final c in (await cards()).values)
          {
            'id': c.cardId,
            'e': c.ease,
            'i': c.intervalDays,
            'r': c.repetitions,
            'l': c.lapses,
            'due': c.due.toIso8601String(),
          },
      ],
      'lessons': {
        for (final id in await readLessons())
          id: (_readAt[id] ?? DateTime.fromMillisecondsSinceEpoch(0))
              .toIso8601String(),
      },
      'settings': _settingsCopy,
    });
  }

  Future<void> _persist() async => save(await toJson());

  @override
  Future<void> setSetting(String key, String value) async {
    await super.setSetting(key, value);
    _settingsCopy[key] = value;
    await _persist();
  }

  @override
  Future<void> addAnswers(List<AnswerRecord> answers) async {
    await super.addAnswers(answers);
    await _persist();
  }

  @override
  Future<int> addSession(SessionRecord session) async {
    final id = await super.addSession(session);
    await _persist();
    return id;
  }

  @override
  Future<void> saveCard(CardState state) async {
    await super.saveCard(state);
    await _persist();
  }

  @override
  Future<void> markLessonRead(String lessonId, DateTime at) async {
    _readAt.putIfAbsent(lessonId, () => at);
    await super.markLessonRead(lessonId, at);
    await _persist();
  }

  @override
  Future<void> clear() async {
    await super.clear();
    _readAt.clear();
    await _persist();
  }
}
