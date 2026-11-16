import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../data/progress_store.dart';
import '../logic/stats.dart';
import 'quiz_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// Résultat d'une série : score, analyse des erreurs, recommandations.
class QuizResultPage extends StatelessWidget {
  const QuizResultPage({
    super.key,
    required this.config,
    required this.session,
    required this.answers,
    this.timeUp = false,
  });

  final QuizConfig config;
  final SessionRecord session;
  final List<AnswerRecord> answers;
  final bool timeUp;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final library = state.library;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isExam = config.mode == SessionMode.exam;
    final threshold = isExam
        ? library.examInfo.passingScore
        : (masteryThreshold * 100).round();
    final passed = session.score >= threshold;

    // Erreurs par notion et par domaine.
    final conceptErrors = <String, int>{};
    final domainTotals = <String, (int, int)>{};
    for (final a in answers) {
      if (!a.correct) {
        conceptErrors[a.concept] = (conceptErrors[a.concept] ?? 0) + 1;
      }
      final (ok, n) = domainTotals[a.domainId] ?? (0, 0);
      domainTotals[a.domainId] = (ok + (a.correct ? 1 : 0), n + 1);
    }
    final sortedConcepts = conceptErrors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final byId = {for (final a in answers) a.questionId: a};

    return Scaffold(
      appBar: AppBar(title: Text('Résultat · ${config.title}')),
      body: ReadingList(
        children: [
          if (timeUp)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Temps écoulé : la série a été clôturée automatiquement.',
                style: TextStyle(color: scheme.error),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('${session.score}/100', style: text.displaySmall),
                  const SizedBox(height: 4),
                  Text(
                    '${session.correctCount} bonne(s) réponse(s) sur ${session.total} · '
                    '${formatDuration(Duration(seconds: session.durationSeconds))}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    passed
                        ? (isExam
                              ? 'Seuil de réussite atteint ($threshold/100).'
                              : 'Objectif atteint (≥ $threshold %).')
                        : (isExam
                              ? 'Seuil de réussite non atteint ($threshold/100).'
                              : 'Objectif non atteint : il faut $threshold % pour valider.'),
                    style: text.titleSmall?.copyWith(
                      color: successColor(passed, scheme),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (config.feedbackAfterEach &&
              answers.length < config.questions.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${config.questions.length - answers.length} question(s) non validée(s) '
                'ne sont pas comptées.',
                style: text.bodySmall,
              ),
            ),
          if (domainTotals.length > 1) ...[
            const SectionTitle('Par domaine officiel'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final e in domainTotals.entries)
                      LabeledProgress(
                        label: library.domain(e.key).nameFr,
                        value: e.value.$1 / e.value.$2,
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SectionTitle('Analyse des erreurs'),
          if (sortedConcepts.isEmpty)
            const Text('Aucune erreur sur cette série.')
          else
            Card(
              child: Column(
                children: [
                  for (final e in sortedConcepts)
                    ListTile(
                      leading: Icon(Icons.error_outline, color: scheme.error),
                      title: Text(e.key),
                      subtitle: Text('${e.value} erreur(s)'),
                    ),
                ],
              ),
            ),
          const SectionTitle('Recommandations'),
          ..._recommendations(
            sortedConcepts.map((e) => e.key).toList(),
            passed,
            isExam,
          ).map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('•  $r'),
            ),
          ),
          const SectionTitle('Correction détaillée'),
          for (final (i, q) in config.questions.indexed)
            if (byId.containsKey(q.id))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  leading: Icon(
                    byId[q.id]!.correct ? Icons.check_circle : Icons.cancel,
                    color: successColor(byId[q.id]!.correct, scheme),
                  ),
                  title: Text(
                    '${i + 1}. ${q.prompt}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  initiallyExpanded: !byId[q.id]!.correct && isExam,
                  children: [
                    Text(q.prompt),
                    const SizedBox(height: 8),
                    QuestionCorrection(question: q, chosen: byId[q.id]!.chosen),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  List<String> _recommendations(List<String> weak, bool passed, bool isExam) {
    if (weak.isEmpty) {
      return [
        isExam
            ? 'Excellent : refaites un examen blanc plus long pour confirmer.'
            : 'Chapitre solide : passez au suivant ou tentez un examen blanc.',
        'Gardez le rythme des flashcards pour ancrer les notions.',
      ];
    }
    return [
      'Relisez la partie du cours sur : ${weak.take(3).join(', ')}.',
      'Révisez les flashcards liées à ces notions.',
      'Utilisez « Reprise des erreurs » d\'ici 24 à 48 heures.',
      if (!passed)
        'Refaites une série sur ce chapitre avant de passer au suivant.',
    ];
  }
}
