import 'dart:io';

import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/data/sqlite_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

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

  test('réglages : lecture, écriture et remplacement', () async {
    for (final store in [
      MemoryProgressStore(),
      SqliteProgressStore.open(':memory:'),
    ]) {
      expect(await store.setting('animations'), isNull);
      await store.setSetting('animations', '0');
      await store.setSetting('animations', '1');
      expect(await store.setting('animations'), '1');
    }
  });

  test(
    'migration : une base en version 1 passe en version 2 sans perte',
    () async {
      final dir = await Directory.systemTemp.createTemp('cisso_mig');
      final path = '${dir.path}/v1.db';
      try {
        final old = sqlite3.open(path);
        old.execute('''
        CREATE TABLE lessons_read (lesson_id TEXT PRIMARY KEY, read_at INTEGER NOT NULL);
        INSERT INTO lessons_read VALUES ('m1c1-l1', 0);
        PRAGMA user_version = 1;
      ''');
        old.close();

        final store = SqliteProgressStore.open(path);
        expect(await store.readLessons(), {'m1c1-l1'});
        await store.setSetting('animations', '0');
        expect(await store.setting('animations'), '0');
        await store.close();

        final check = sqlite3.open(path);
        expect(
          check.select('PRAGMA user_version').first.values.first,
          SqliteProgressStore.schemaVersion,
        );
        check.close();
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
