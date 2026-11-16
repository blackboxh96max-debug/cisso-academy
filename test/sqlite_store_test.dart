import 'dart:io';

import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/data/sqlite_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t = DateTime(2026, 11, 16, 10, 30);

  Future<void> fill(ProgressStore store) async {
    final id = await store.addSession(
      SessionRecord(
        mode: SessionMode.exam,
        chapterId: null,
        correctCount: 7,
        total: 10,
        durationSeconds: 600,
        finishedAt: t,
      ),
    );
    await store.addAnswers([
      AnswerRecord(
        questionId: 'q1',
        chapterId: 'c',
        domainId: 'd',
        concept: 'ALE',
        chosen: {2, 0},
        correct: true,
        mode: SessionMode.exam,
        answeredAt: t,
        sessionId: id,
      ),
      AnswerRecord(
        questionId: 'q2',
        chapterId: 'c',
        domainId: 'd',
        concept: 'SLE',
        chosen: {},
        correct: false,
        mode: SessionMode.exam,
        answeredAt: t,
        sessionId: id,
      ),
    ]);
    await store.saveCard(
      CardState(
        cardId: 'f1',
        ease: 2.36,
        intervalDays: 6,
        repetitions: 2,
        lapses: 1,
        due: t,
      ),
    );
    await store.saveCard(
      CardState(
        cardId: 'f1',
        ease: 2.5,
        intervalDays: 15,
        repetitions: 3,
        lapses: 1,
        due: t,
      ),
    );
    await store.markLessonRead('l1', t);
    await store.markLessonRead('l1', t);
  }

  Future<void> check(ProgressStore store) async {
    final sessions = await store.sessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.score, 70);
    expect(sessions.single.mode, SessionMode.exam);
    expect(sessions.single.finishedAt, t);

    final answers = await store.answers();
    expect(answers, hasLength(2));
    expect(answers.first.chosen, {0, 2});
    expect(answers.first.sessionId, sessions.single.id);
    expect(answers.last.chosen, isEmpty);
    expect(answers.last.correct, isFalse);

    final cards = await store.cards();
    expect(cards.keys, ['f1']);
    expect(cards['f1']!.intervalDays, 15, reason: 'mise à jour, pas doublon');

    expect(await store.readLessons(), {'l1'});
  }

  test('MemoryProgressStore : aller-retour', () async {
    final store = MemoryProgressStore();
    await fill(store);
    await check(store);
  });

  test(
    'SqliteProgressStore : aller-retour, persistance et effacement',
    () async {
      final dir = await Directory.systemTemp.createTemp('cisso_db');
      final path = '${dir.path}/test.db';
      try {
        var store = SqliteProgressStore.open(path);
        await fill(store);
        await check(store);
        await store.close();

        // Réouverture : les données ont bien été écrites sur disque.
        store = SqliteProgressStore.open(path);
        await check(store);

        await store.clear();
        expect(await store.answers(), isEmpty);
        expect(await store.sessions(), isEmpty);
        expect(await store.cards(), isEmpty);
        expect(await store.readLessons(), isEmpty);
        await store.close();
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
