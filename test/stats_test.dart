import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/logic/badges.dart';
import 'package:cisso_academy/logic/stats.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;
  final now = DateTime(2026, 11, 16, 10);

  setUpAll(() async => library = await loadRealContent());

  AnswerRecord answer(Question q, bool correct, {int minutes = 0}) =>
      AnswerRecord(
        questionId: q.id,
        chapterId: q.chapterId,
        domainId: q.domainId,
        concept: q.concept,
        chosen: correct ? q.correct : {9},
        correct: correct,
        mode: SessionMode.practice,
        answeredAt: now.add(Duration(minutes: minutes)),
      );

  ProgressStats compute({
    List<AnswerRecord> answers = const [],
    List<SessionRecord> sessions = const [],
    Map<String, CardState> cards = const {},
    Set<String> read = const {},
  }) => ProgressStats.compute(
    library: library,
    answers: answers,
    sessions: sessions,
    cards: cards,
    readLessons: read,
    now: now,
  );

  test('sans historique : rien de commencé, première leçon recommandée', () {
    final s = compute();
    expect(s.overallProgress, 0);
    expect(s.averageScore, isNull);
    expect(s.recommendation.kind, RecommendationKind.lesson);
    expect(s.recommendation.targetId, 'm1c1-l1');
    final pilot = s.chapters.firstWhere((c) => c.chapter.id == 'm1c1');
    expect(pilot.status, ChapterStatus.notStarted);
  });

  test('la dernière réponse à une question fait foi', () {
    final q = library.chapter('m1c1').questions.first;
    final s = compute(answers: [answer(q, false), answer(q, true, minutes: 1)]);
    expect(s.wrongQuestionIds, isEmpty);
    expect(s.distinctQuestions, 1);
    expect(s.totalAnswers, 2);
    final concept = s.concepts.firstWhere((c) => c.concept == q.concept);
    expect(concept.errors, 1);
    expect(concept.openErrors, isEmpty);
  });

  test(
    'deux erreurs ouvertes sur une notion = lacune récurrente, recommandée',
    () {
      final qs = library.chapter('m1c1').questions;
      final q = qs.firstWhere((x) => x.concept == 'ALE');
      final s = compute(
        answers: [answer(q, false), answer(q, false, minutes: 1)],
        read: library.chapter('m1c1').lessons.map((l) => l.id).toSet(),
      );
      expect(s.weakConcepts.first.concept, 'ALE');
      expect(s.weakConcepts.first.recurrent, isTrue);
      expect(s.recommendation.kind, RecommendationKind.retryErrors);
    },
  );

  test('chapitre maîtrisé à 80 % de couverture et 80 % de réussite', () {
    final ch = library.chapter('m1c1');
    final qs = ch.questions;
    final cutoff = (qs.length * 0.85).ceil();
    final answers = [
      for (var i = 0; i < qs.length; i++) answer(qs[i], i < cutoff),
    ];
    final s = compute(
      answers: answers,
      read: ch.lessons.map((l) => l.id).toSet(),
    );
    final pilot = s.chapters.firstWhere((c) => c.chapter.id == 'm1c1');
    expect(pilot.accuracy, greaterThanOrEqualTo(0.8));
    expect(pilot.status, ChapterStatus.mastered);
    expect(pilot.progress, greaterThan(0.9));
  });

  test('chapitre à revoir sous 80 % de réussite', () {
    final ch = library.chapter('m1c1');
    final answers = [
      for (final (i, q) in ch.questions.take(10).indexed) answer(q, i < 5),
    ];
    final s = compute(answers: answers);
    final pilot = s.chapters.firstWhere((c) => c.chapter.id == 'm1c1');
    expect(pilot.status, ChapterStatus.toReview);
  });

  test('score moyen et cartes échues', () {
    final s = compute(
      sessions: [
        SessionRecord(
          mode: SessionMode.practice,
          chapterId: 'm1c1',
          correctCount: 8,
          total: 10,
          durationSeconds: 60,
          finishedAt: now,
        ),
        SessionRecord(
          mode: SessionMode.exam,
          chapterId: null,
          correctCount: 6,
          total: 10,
          durationSeconds: 60,
          finishedAt: now,
        ),
      ],
      cards: {
        'm1c1-f01': CardState(
          cardId: 'm1c1-f01',
          ease: 2.5,
          intervalDays: 1,
          repetitions: 1,
          lapses: 0,
          due: now.subtract(const Duration(hours: 1)),
        ),
      },
    );
    expect(s.averageScore, 70);
    expect(s.dueCardCount, 1);
    expect(s.recommendation.kind, RecommendationKind.flashcards);
  });

  test('objectif du jour, série de jours et badges', () {
    final qs = library.questions.take(3).toList();
    AnswerRecord on(Question q, int daysAgo) => AnswerRecord(
      questionId: q.id,
      chapterId: q.chapterId,
      domainId: q.domainId,
      concept: q.concept,
      chosen: q.correct,
      correct: true,
      mode: SessionMode.practice,
      answeredAt: now.subtract(Duration(days: daysAgo)),
    );
    final s = compute(
      answers: [on(qs[0], 2), on(qs[1], 1), on(qs[2], 0), on(qs[2], 0)],
    );
    expect(s.answersToday, 2);
    expect(s.streakDays, 3);

    // Pas encore révisé aujourd'hui : la série d'hier compte toujours.
    final yesterday = compute(answers: [on(qs[0], 2), on(qs[1], 1)]);
    expect(yesterday.answersToday, 0);
    expect(yesterday.streakDays, 2);

    // Trou d'un jour : la série repart.
    expect(compute(answers: [on(qs[0], 3), on(qs[1], 0)]).streakDays, 1);

    final badges = {for (final b in computeAchievements(s)) b.title: b.earned};
    expect(badges['Premier pas'], isTrue);
    expect(badges['Régularité'], isTrue);
    expect(badges['Objectif du jour'], isFalse);
    expect(badges['Examen blanc'], isFalse);
    expect(computeAchievements(compute()).where((b) => b.earned), isEmpty);
  });
}
