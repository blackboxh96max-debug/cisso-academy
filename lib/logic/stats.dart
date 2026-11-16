import '../data/progress_store.dart';
import '../models/content.dart';
import 'spaced_repetition.dart';

/// Seuil de validation d'un chapitre (règle de la formation : 8/10).
const masteryThreshold = 0.8;

enum ChapterStatus {
  notStarted('Non commencé'),
  inProgress('En cours'),
  toReview('À revoir'),
  mastered('Maîtrisé');

  const ChapterStatus(this.label);
  final String label;
}

class ChapterStats {
  const ChapterStats({
    required this.chapter,
    required this.lessonsRead,
    required this.questionsSeen,
    required this.correctLatest,
  });

  final Chapter chapter;
  final int lessonsRead;

  /// Questions du chapitre auxquelles l'apprenant a répondu au moins une fois.
  final int questionsSeen;

  /// Parmi elles, celles dont la dernière réponse est juste.
  final int correctLatest;

  int get lessonCount => chapter.lessons.length;
  int get questionCount => chapter.questions.length;

  double get coverage => questionCount == 0 ? 0 : questionsSeen / questionCount;

  /// Taux de réussite sur la dernière réponse à chaque question vue.
  double get accuracy => questionsSeen == 0 ? 0 : correctLatest / questionsSeen;

  /// Progression : 40 % leçons lues, 30 % questions vues, 30 % réussite.
  double get progress {
    if (!chapter.available) return 0;
    final lessons = lessonCount == 0 ? 1.0 : lessonsRead / lessonCount;
    return 0.4 * lessons + 0.3 * coverage + 0.3 * accuracy * coverage;
  }

  ChapterStatus get status {
    if (lessonsRead == 0 && questionsSeen == 0) return ChapterStatus.notStarted;
    if (coverage >= masteryThreshold && accuracy >= masteryThreshold) {
      return ChapterStatus.mastered;
    }
    if (questionsSeen >= 5 && accuracy < masteryThreshold) {
      return ChapterStatus.toReview;
    }
    return ChapterStatus.inProgress;
  }
}

class ConceptStats {
  ConceptStats(this.concept, this.chapterId);

  final String concept;
  final String chapterId;
  int attempts = 0;
  int errors = 0;

  /// Questions de cette notion dont la dernière réponse est fausse.
  final Set<String> openErrors = {};

  double get errorRate => attempts == 0 ? 0 : errors / attempts;

  /// Lacune récurrente : au moins deux erreurs et une erreur encore ouverte.
  bool get recurrent => errors >= 2 && openErrors.isNotEmpty;
}

/// Recommandation de la prochaine révision.
class Recommendation {
  const Recommendation(this.kind, this.title, this.detail, {this.targetId});

  final RecommendationKind kind;
  final String title;
  final String detail;
  final String? targetId;
}

enum RecommendationKind { flashcards, retryErrors, lesson, practice, exam }

/// Statistiques calculées à partir du contenu et de l'historique local.
class ProgressStats {
  ProgressStats._({
    required this.chapters,
    required this.concepts,
    required this.sessions,
    required this.totalAnswers,
    required this.distinctQuestions,
    required this.wrongQuestionIds,
    required this.dueCardCount,
    required this.masteredCardCount,
    required this.domainAccuracy,
    required this.recommendation,
    this.answersToday = 0,
    this.streakDays = 0,
  });

  final List<ChapterStats> chapters;
  final List<ConceptStats> concepts;
  final List<SessionRecord> sessions;
  final int totalAnswers;
  final int distinctQuestions;

  /// Questions dont la dernière réponse est fausse (reprise des erreurs).
  final List<String> wrongQuestionIds;
  final int dueCardCount;
  final int masteredCardCount;

  /// Réussite (dernière réponse) par domaine officiel : id → (justes, vues).
  final Map<String, (int, int)> domainAccuracy;
  final Recommendation recommendation;

  /// Réponses données aujourd'hui (objectif de révision quotidien).
  final int answersToday;

  /// Jours consécutifs avec au moins une réponse, jusqu'à aujourd'hui
  /// (ou hier, si l'apprenant n'a pas encore révisé aujourd'hui).
  final int streakDays;

  Iterable<ChapterStats> get availableChapters =>
      chapters.where((c) => c.chapter.available);

  /// Progression globale sur l'ensemble du programme (chapitres à venir inclus).
  double get overallProgress => chapters.isEmpty
      ? 0
      : chapters.fold<double>(0, (s, c) => s + c.progress) / chapters.length;

  double moduleProgress(String moduleId) {
    final list = chapters.where((c) => c.chapter.moduleId == moduleId).toList();
    if (list.isEmpty) return 0;
    return list.fold<double>(0, (s, c) => s + c.progress) / list.length;
  }

  /// Score moyen des sessions terminées (sur 100), null si aucune.
  int? get averageScore => sessions.isEmpty
      ? null
      : (sessions.fold<int>(0, (s, r) => s + r.score) / sessions.length)
            .round();

  /// Notions faibles, de la plus fragile à la moins fragile.
  List<ConceptStats> get weakConcepts =>
      concepts.where((c) => c.openErrors.isNotEmpty).toList()..sort((a, b) {
        final byOpen = b.openErrors.length.compareTo(a.openErrors.length);
        return byOpen != 0 ? byOpen : b.errorRate.compareTo(a.errorRate);
      });

  static ProgressStats compute({
    required ContentLibrary library,
    required List<AnswerRecord> answers,
    required List<SessionRecord> sessions,
    required Map<String, CardState> cards,
    required Set<String> readLessons,
    required DateTime now,
  }) {
    final latest = <String, AnswerRecord>{};
    final concepts = <String, ConceptStats>{};
    for (final a in answers) {
      latest[a.questionId] = a;
      final c = concepts.putIfAbsent(
        a.concept,
        () => ConceptStats(a.concept, a.chapterId),
      );
      c.attempts++;
      if (!a.correct) c.errors++;
    }
    for (final a in latest.values) {
      if (!a.correct) concepts[a.concept]?.openErrors.add(a.questionId);
    }

    final chapterStats = [
      for (final ch in library.chapters)
        ChapterStats(
          chapter: ch,
          lessonsRead: ch.lessons
              .where((l) => readLessons.contains(l.id))
              .length,
          questionsSeen: ch.questions
              .where((q) => latest.containsKey(q.id))
              .length,
          correctLatest: ch.questions
              .where((q) => latest[q.id]?.correct ?? false)
              .length,
        ),
    ];

    final domainAccuracy = <String, (int, int)>{};
    for (final a in latest.values) {
      final (ok, seen) = domainAccuracy[a.domainId] ?? (0, 0);
      domainAccuracy[a.domainId] = (ok + (a.correct ? 1 : 0), seen + 1);
    }

    final knownQuestions = library.questions.map((q) => q.id).toSet();
    final wrong = latest.values
        .where((a) => !a.correct && knownQuestions.contains(a.questionId))
        .map((a) => a.questionId)
        .toList();

    final cardIds = library.flashcards.map((f) => f.id).toList();
    final due = dueCards(
      cardIds,
      cards,
      now,
    ).where((id) => cards.containsKey(id)).length;
    final mastered = cards.values.where((c) => c.mastered).length;

    final base = ProgressStats._(
      chapters: chapterStats,
      concepts: concepts.values.toList(),
      sessions: sessions,
      totalAnswers: answers.length,
      distinctQuestions: latest.length,
      wrongQuestionIds: wrong,
      dueCardCount: due,
      masteredCardCount: mastered,
      domainAccuracy: domainAccuracy,
      recommendation: const Recommendation(RecommendationKind.exam, '', ''),
      answersToday: answers.where((a) => _sameDay(a.answeredAt, now)).length,
      streakDays: _streak(answers.map((a) => a.answeredAt), now),
    );
    return base._withRecommendation(_recommend(base, readLessons));
  }

  ProgressStats _withRecommendation(Recommendation r) => ProgressStats._(
    chapters: chapters,
    concepts: concepts,
    sessions: sessions,
    totalAnswers: totalAnswers,
    distinctQuestions: distinctQuestions,
    wrongQuestionIds: wrongQuestionIds,
    dueCardCount: dueCardCount,
    masteredCardCount: masteredCardCount,
    domainAccuracy: domainAccuracy,
    recommendation: r,
    answersToday: answersToday,
    streakDays: streakDays,
  );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _streak(Iterable<DateTime> times, DateTime now) {
    final days = {for (final t in times) DateTime(t.year, t.month, t.day)};
    var day = DateTime(now.year, now.month, now.day);
    if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    var n = 0;
    while (days.contains(day)) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  /// Ordre de priorité : cartes échues, erreurs récurrentes, leçon non lue,
  /// entraînement sur un chapitre non maîtrisé, puis examen blanc.
  static Recommendation _recommend(ProgressStats s, Set<String> readLessons) {
    if (s.dueCardCount > 0) {
      return Recommendation(
        RecommendationKind.flashcards,
        'Réviser ${s.dueCardCount} flashcard${s.dueCardCount > 1 ? 's' : ''}',
        'Ces cartes arrivent à échéance : les revoir maintenant fixe la mémoire.',
      );
    }
    final recurrent = s.weakConcepts.where((c) => c.recurrent).toList();
    if (recurrent.isNotEmpty) {
      return Recommendation(
        RecommendationKind.retryErrors,
        'Reprendre vos erreurs',
        'Notion fragile : « ${recurrent.first.concept} » '
            '(${recurrent.first.errors} erreurs).',
      );
    }
    for (final c in s.availableChapters) {
      final unread = c.chapter.lessons.where(
        (l) => !readLessons.contains(l.id),
      );
      if (unread.isNotEmpty) {
        final lesson = unread.first;
        return Recommendation(
          RecommendationKind.lesson,
          'Lire « ${lesson.title} »',
          '${c.chapter.title}, environ ${lesson.minutes} minutes.',
          targetId: lesson.id,
        );
      }
    }
    for (final c in s.availableChapters) {
      if (c.status != ChapterStatus.mastered) {
        return Recommendation(
          RecommendationKind.practice,
          'S\'entraîner : ${c.chapter.title}',
          c.questionsSeen == 0
              ? 'Aucune question traitée pour l\'instant.'
              : 'Réussite actuelle ${(c.accuracy * 100).round()} %, '
                    'objectif ${(masteryThreshold * 100).round()} %.',
          targetId: c.chapter.id,
        );
      }
    }
    if (s.wrongQuestionIds.isNotEmpty) {
      return Recommendation(
        RecommendationKind.retryErrors,
        'Reprendre vos erreurs',
        '${s.wrongQuestionIds.length} question(s) encore ratée(s).',
      );
    }
    return const Recommendation(
      RecommendationKind.exam,
      'Passer un examen blanc',
      'Les chapitres disponibles sont maîtrisés : testez-vous en conditions d\'examen.',
    );
  }
}
