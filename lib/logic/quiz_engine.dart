import 'dart:math';

import '../models/content.dart';

/// Vrai si l'ensemble des choix correspond exactement aux bonnes réponses.
bool isAnswerCorrect(Question question, Set<int> chosen) =>
    chosen.length == question.correct.length &&
    chosen.containsAll(question.correct);

/// Sélection de questions pour un entraînement.
List<Question> pickPracticeQuestions(
  Iterable<Question> pool, {
  Set<Level>? levels,
  int? count,
  Random? random,
}) {
  final list =
      pool
          .where(
            (q) => levels == null || levels.isEmpty || levels.contains(q.level),
          )
          .toList()
        ..shuffle(random ?? Random());
  if (count != null && count < list.length) return list.sublist(0, count);
  return list;
}

/// Construit un examen blanc dont la répartition suit le poids officiel des
/// domaines, dans la limite des questions disponibles.
///
/// Renvoie au plus [count] questions. Les places d'un domaine sans assez de
/// questions sont redistribuées aux autres domaines.
List<Question> buildExam(
  Iterable<Question> pool,
  List<ExamDomain> domains, {
  required int count,
  Random? random,
}) {
  final rng = random ?? Random();
  final byDomain = <String, List<Question>>{};
  for (final q in pool) {
    byDomain.putIfAbsent(q.domainId, () => []).add(q);
  }
  for (final list in byDomain.values) {
    list.shuffle(rng);
  }
  final available = byDomain.values.fold<int>(0, (s, l) => s + l.length);
  final target = min(count, available);

  // Quotas proportionnels aux poids, parmi les domaines qui ont des questions.
  final present = domains.where((d) => byDomain.containsKey(d.id)).toList();
  final weightSum = present.fold<int>(0, (s, d) => s + d.weight);
  final quota = <String, int>{
    for (final d in present)
      d.id: min(
        byDomain[d.id]!.length,
        (target * d.weight / weightSum).floor(),
      ),
  };
  var assigned = quota.values.fold<int>(0, (s, v) => s + v);
  // Complète les places restantes, domaines les plus lourds d'abord.
  final ordered = [...present]..sort((a, b) => b.weight.compareTo(a.weight));
  while (assigned < target) {
    var progressed = false;
    for (final d in ordered) {
      if (assigned >= target) break;
      if (quota[d.id]! < byDomain[d.id]!.length) {
        quota[d.id] = quota[d.id]! + 1;
        assigned++;
        progressed = true;
      }
    }
    if (!progressed) break;
  }

  final exam = <Question>[
    for (final d in present) ...byDomain[d.id]!.take(quota[d.id]!),
  ]..shuffle(rng);
  return exam;
}

/// Durée d'un examen blanc au prorata du temps officiel par question.
Duration examDuration(ExamInfo info, int questionCount) =>
    Duration(seconds: (info.secondsPerQuestion * questionCount).round());
