import 'dart:math';

import 'package:cisso_academy/logic/quiz_engine.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:flutter_test/flutter_test.dart';

Question _q(
  String id,
  String domain, {
  Set<int> correct = const {0},
  Level level = Level.beginner,
}) => Question(
  id: id,
  chapterId: 'c',
  domainId: domain,
  level: level,
  concept: 'x',
  prompt: '?',
  choices: const ['a', 'b', 'c', 'd'],
  correct: correct,
  explanation: '',
  whyNot: const {},
  kind: SourceKind.general,
);

const _domains = [
  ExamDomain(id: 'big', nameEn: '', nameFr: '', weight: 70),
  ExamDomain(id: 'small', nameEn: '', nameFr: '', weight: 30),
];

void main() {
  group('isAnswerCorrect', () {
    test('choix unique', () {
      final q = _q('q', 'big', correct: {2});
      expect(isAnswerCorrect(q, {2}), isTrue);
      expect(isAnswerCorrect(q, {1}), isFalse);
      expect(isAnswerCorrect(q, {}), isFalse);
    });

    test('réponses multiples : tout ou rien', () {
      final q = _q('q', 'big', correct: {0, 2});
      expect(isAnswerCorrect(q, {0, 2}), isTrue);
      expect(isAnswerCorrect(q, {0}), isFalse);
      expect(isAnswerCorrect(q, {0, 1, 2}), isFalse);
    });
  });

  test('pickPracticeQuestions filtre par niveau et limite le nombre', () {
    final pool = [
      for (var i = 0; i < 10; i++)
        _q('q$i', 'big', level: i.isEven ? Level.beginner : Level.advanced),
    ];
    final picked = pickPracticeQuestions(
      pool,
      levels: {Level.advanced},
      count: 3,
      random: Random(1),
    );
    expect(picked, hasLength(3));
    expect(picked.every((q) => q.level == Level.advanced), isTrue);
    expect(pickPracticeQuestions(pool), hasLength(10));
  });

  group('buildExam', () {
    test('respecte le poids des domaines', () {
      final pool = [
        for (var i = 0; i < 50; i++) _q('b$i', 'big'),
        for (var i = 0; i < 50; i++) _q('s$i', 'small'),
      ];
      final exam = buildExam(pool, _domains, count: 20, random: Random(3));
      expect(exam, hasLength(20));
      expect(exam.where((q) => q.domainId == 'big'), hasLength(14));
      expect(exam.where((q) => q.domainId == 'small'), hasLength(6));
      expect(
        exam.map((q) => q.id).toSet(),
        hasLength(20),
        reason: 'sans doublon',
      );
    });

    test('redistribue quand un domaine manque de questions', () {
      final pool = [
        for (var i = 0; i < 3; i++) _q('b$i', 'big'),
        for (var i = 0; i < 50; i++) _q('s$i', 'small'),
      ];
      final exam = buildExam(pool, _domains, count: 20, random: Random(3));
      expect(exam, hasLength(20));
      expect(exam.where((q) => q.domainId == 'big'), hasLength(3));
    });

    test('ne dépasse pas la banque disponible', () {
      final pool = [for (var i = 0; i < 5; i++) _q('b$i', 'big')];
      expect(buildExam(pool, _domains, count: 100), hasLength(5));
    });
  });

  test('examDuration applique le temps officiel par question', () {
    const info = ExamInfo(
      questionCount: 100,
      durationMinutes: 120,
      passingScore: 62,
      source: '',
      verifiedOn: '',
    );
    expect(examDuration(info, 100), const Duration(minutes: 120));
    expect(examDuration(info, 20), const Duration(minutes: 24));
  });
}
