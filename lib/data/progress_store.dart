/// Données de progression de l'apprenant, stockées uniquement sur l'appareil.
library;

enum SessionMode {
  practice,
  exam,
  retry;

  static SessionMode parse(String v) =>
      SessionMode.values.firstWhere((m) => m.name == v);

  String get label => switch (this) {
    SessionMode.practice => 'Entraînement',
    SessionMode.exam => 'Examen blanc',
    SessionMode.retry => 'Reprise des erreurs',
  };
}

/// Une réponse donnée à une question.
class AnswerRecord {
  const AnswerRecord({
    required this.questionId,
    required this.chapterId,
    required this.domainId,
    required this.concept,
    required this.chosen,
    required this.correct,
    required this.mode,
    required this.answeredAt,
    this.sessionId,
  });

  final String questionId;
  final String chapterId;
  final String domainId;
  final String concept;
  final Set<int> chosen;
  final bool correct;
  final SessionMode mode;
  final DateTime answeredAt;
  final int? sessionId;
}

/// Une série de questions terminée (entraînement ou examen blanc).
class SessionRecord {
  const SessionRecord({
    this.id,
    required this.mode,
    required this.chapterId,
    required this.correctCount,
    required this.total,
    required this.durationSeconds,
    required this.finishedAt,
  });

  final int? id;
  final SessionMode mode;

  /// Null pour un examen blanc multi-chapitres.
  final String? chapterId;
  final int correctCount;
  final int total;
  final int durationSeconds;
  final DateTime finishedAt;

  /// Score sur 100.
  int get score => total == 0 ? 0 : (correctCount * 100 / total).round();

  SessionRecord withId(int newId) => SessionRecord(
    id: newId,
    mode: mode,
    chapterId: chapterId,
    correctCount: correctCount,
    total: total,
    durationSeconds: durationSeconds,
    finishedAt: finishedAt,
  );
}

/// État de répétition espacée d'une flashcard.
class CardState {
  const CardState({
    required this.cardId,
    required this.ease,
    required this.intervalDays,
    required this.repetitions,
    required this.lapses,
    required this.due,
  });

  final String cardId;
  final double ease;
  final int intervalDays;
  final int repetitions;
  final int lapses;
  final DateTime due;

  factory CardState.initial(String cardId, DateTime now) => CardState(
    cardId: cardId,
    ease: 2.5,
    intervalDays: 0,
    repetitions: 0,
    lapses: 0,
    due: now,
  );

  /// Carte considérée comme maîtrisée : intervalle d'au moins 21 jours.
  bool get mastered => intervalDays >= 21;
}

/// Accès au stockage local de la progression.
abstract class ProgressStore {
  Future<void> addAnswers(List<AnswerRecord> answers);
  Future<List<AnswerRecord>> answers();

  /// Enregistre une session et renvoie son identifiant.
  Future<int> addSession(SessionRecord session);
  Future<List<SessionRecord>> sessions();

  Future<void> saveCard(CardState state);
  Future<Map<String, CardState>> cards();

  Future<void> markLessonRead(String lessonId, DateTime at);
  Future<Set<String>> readLessons();

  /// Efface toute la progression (réinitialisation).
  Future<void> clear();

  Future<void> close();
}

/// Implémentation en mémoire : tests et aperçu web.
class MemoryProgressStore implements ProgressStore {
  final _answers = <AnswerRecord>[];
  final _sessions = <SessionRecord>[];
  final _cards = <String, CardState>{};
  final _lessons = <String>{};

  @override
  Future<void> addAnswers(List<AnswerRecord> answers) async =>
      _answers.addAll(answers);

  @override
  Future<List<AnswerRecord>> answers() async => List.unmodifiable(_answers);

  @override
  Future<int> addSession(SessionRecord session) async {
    final id = _sessions.length + 1;
    _sessions.add(session.withId(id));
    return id;
  }

  @override
  Future<List<SessionRecord>> sessions() async => List.unmodifiable(_sessions);

  @override
  Future<void> saveCard(CardState state) async => _cards[state.cardId] = state;

  @override
  Future<Map<String, CardState>> cards() async => Map.unmodifiable(_cards);

  @override
  Future<void> markLessonRead(String lessonId, DateTime at) async =>
      _lessons.add(lessonId);

  @override
  Future<Set<String>> readLessons() async => Set.unmodifiable(_lessons);

  @override
  Future<void> clear() async {
    _answers.clear();
    _sessions.clear();
    _cards.clear();
    _lessons.clear();
  }

  @override
  Future<void> close() async {}
}
