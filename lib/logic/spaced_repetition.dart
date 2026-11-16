import 'dart:math';

import '../data/progress_store.dart';

/// Évaluation d'une carte par l'apprenant.
enum Grade {
  again(0, 'À revoir'),
  hard(3, 'Difficile'),
  good(4, 'Correct'),
  easy(5, 'Facile');

  const Grade(this.quality, this.label);

  /// Qualité de la réponse au sens de SM-2 (0 à 5).
  final int quality;
  final String label;
}

/// Algorithme SM-2 (répétition espacée, P. Wozniak, SuperMemo 2).
///
/// - Échec (`again`) : la carte revient le jour même, le compteur repart à 0.
/// - Succès : intervalles 1 jour, 6 jours, puis intervalle × facilité.
/// - La facilité ne descend jamais sous 1,3.
CardState review(CardState state, Grade grade, DateTime now) {
  final q = grade.quality;
  var ease = state.ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
  ease = max(1.3, ease);

  if (q < 3) {
    return CardState(
      cardId: state.cardId,
      ease: ease,
      intervalDays: 0,
      repetitions: 0,
      lapses: state.lapses + 1,
      due: now.add(const Duration(minutes: 10)),
    );
  }

  final repetitions = state.repetitions + 1;
  final int interval;
  if (repetitions == 1) {
    interval = 1;
  } else if (repetitions == 2) {
    interval = 6;
  } else {
    interval = (state.intervalDays * ease).round();
  }
  return CardState(
    cardId: state.cardId,
    ease: ease,
    intervalDays: interval,
    repetitions: repetitions,
    lapses: state.lapses,
    due: now.add(Duration(days: interval)),
  );
}

/// Cartes à réviser maintenant : nouvelles ou échues, les plus en retard
/// et les plus souvent ratées d'abord.
List<String> dueCards(
  Iterable<String> cardIds,
  Map<String, CardState> states,
  DateTime now,
) {
  final due = cardIds
      .where((id) => states[id] == null || !states[id]!.due.isAfter(now))
      .toList();
  due.sort((a, b) {
    final sa = states[a], sb = states[b];
    if (sa == null && sb == null) return 0;
    if (sa == null) return 1; // les cartes déjà vues et échues passent avant
    if (sb == null) return -1;
    final byLapses = sb.lapses.compareTo(sa.lapses);
    return byLapses != 0 ? byLapses : sa.due.compareTo(sb.due);
  });
  return due;
}
