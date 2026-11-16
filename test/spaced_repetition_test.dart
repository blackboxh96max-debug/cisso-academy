import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/logic/spaced_repetition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 11, 16, 9);

  test('trois succès donnent 1 jour, 6 jours puis environ 6 × facilité', () {
    var s = CardState.initial('c', t0);
    s = review(s, Grade.good, t0);
    expect(s.intervalDays, 1);
    s = review(s, Grade.good, t0);
    expect(s.intervalDays, 6);
    s = review(s, Grade.good, t0);
    expect(s.intervalDays, (6 * s.ease).round());
    expect(s.due, t0.add(Duration(days: s.intervalDays)));
  });

  test('un échec remet la carte à zéro et compte un oubli', () {
    var s = CardState.initial('c', t0);
    s = review(s, Grade.good, t0);
    s = review(s, Grade.good, t0);
    s = review(s, Grade.again, t0);
    expect(s.repetitions, 0);
    expect(s.intervalDays, 0);
    expect(s.lapses, 1);
    expect(s.due.isBefore(t0.add(const Duration(hours: 1))), isTrue);
  });

  test('la facilité ne descend jamais sous 1,3', () {
    var s = CardState.initial('c', t0);
    for (var i = 0; i < 20; i++) {
      s = review(s, Grade.again, t0);
    }
    expect(s.ease, 1.3);
  });

  test('« facile » augmente la facilité, « difficile » la diminue', () {
    final s = CardState.initial('c', t0);
    expect(review(s, Grade.easy, t0).ease, greaterThan(2.5));
    expect(review(s, Grade.hard, t0).ease, lessThan(2.5));
    expect(review(s, Grade.good, t0).ease, 2.5);
  });

  test(
    'dueCards : échues d\'abord (plus d\'oublis en tête), puis nouvelles',
    () {
      final states = {
        'a': CardState(
          cardId: 'a',
          ease: 2.5,
          intervalDays: 1,
          repetitions: 1,
          lapses: 0,
          due: t0.subtract(const Duration(days: 1)),
        ),
        'b': CardState(
          cardId: 'b',
          ease: 2.5,
          intervalDays: 1,
          repetitions: 1,
          lapses: 3,
          due: t0.subtract(const Duration(hours: 1)),
        ),
        'c': CardState(
          cardId: 'c',
          ease: 2.5,
          intervalDays: 6,
          repetitions: 2,
          lapses: 0,
          due: t0.add(const Duration(days: 2)),
        ),
      };
      expect(dueCards(['a', 'b', 'c', 'new'], states, t0), ['b', 'a', 'new']);
    },
  );

  test('une carte est maîtrisée à partir de 21 jours d\'intervalle', () {
    final s = CardState(
      cardId: 'x',
      ease: 2.5,
      intervalDays: 21,
      repetitions: 4,
      lapses: 0,
      due: t0,
    );
    expect(s.mastered, isTrue);
  });
}
