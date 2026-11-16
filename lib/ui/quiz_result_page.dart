import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../data/progress_store.dart';
import '../logic/stats.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/note_box.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'quiz_page.dart';
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

    final brightness = Theme.of(context).brightness;
    final white = Hand.sansText(
      context,
      size: 14,
    ).copyWith(color: Colors.white, fontWeight: FontWeight.w700);

    return NotebookPage(
      title: 'Résultat · ${config.title}',
      children: [
        if (timeUp)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Sticker(
              text: '⏰ Temps écoulé : la série a été clôturée automatiquement.',
              tone: Tone.red,
            ),
          ),
        GradientBanner(
          tone: passed ? Tone.green : Tone.orange,
          toTone: passed ? Tone.turquoise : Tone.pink,
          seed: 111,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            children: [
              Text(passed ? '🏆' : '💪', style: const TextStyle(fontSize: 44)),
              Text(
                '${session.score}/100',
                style: const TextStyle(
                  fontFamily: Hand.title,
                  fontSize: 64,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${session.correctCount} bonne(s) réponse(s) sur ${session.total} · '
                '${formatDuration(Duration(seconds: session.durationSeconds))}',
                style: white,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                passed
                    ? (isExam
                          ? 'Seuil de réussite atteint ($threshold/100), bravo !'
                          : 'Objectif atteint (≥ $threshold %), bravo !')
                    : (isExam
                          ? 'Seuil de réussite non atteint ($threshold/100) : on s\'y remet !'
                          : 'Objectif non atteint : il faut $threshold % pour valider. On s\'y remet !'),
                style: white.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (config.feedbackAfterEach &&
            answers.length < config.questions.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${config.questions.length - answers.length} question(s) non validée(s) '
              'ne sont pas comptées.',
              style: Hand.sansText(context, size: 13),
            ),
          ),
        if (domainTotals.length > 1)
          NotePanel(
            title: 'Par domaine officiel',
            emoji: '🧭',
            tone: Tone.blue,
            seed: 112,
            child: Column(
              children: [
                for (final (i, e) in domainTotals.entries.indexed)
                  LabeledProgress(
                    label: library.domain(e.key).nameFr,
                    value: e.value.$1 / e.value.$2,
                    tone: rainbowTones[i % rainbowTones.length],
                  ),
              ],
            ),
          ),
        NotePanel(
          title: 'Analyse des erreurs',
          emoji: '🔍',
          tone: Tone.red,
          seed: 113,
          child: sortedConcepts.isEmpty
              ? Text(
                  'Aucune erreur sur cette série. 🎉',
                  style: Hand.bodyText(context),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in sortedConcepts)
                      Sticker(
                        text: '${e.key} · ${e.value} erreur(s)',
                        tone: Tone.red,
                      ),
                  ],
                ),
        ),
        NotePanel(
          title: 'Recommandations',
          emoji: '🌱',
          tone: Tone.green,
          seed: 114,
          child: HandBullets(
            _recommendations(
              sortedConcepts.map((e) => e.key).toList(),
              passed,
              isExam,
            ),
            style: Hand.bodyText(context).copyWith(fontSize: 18),
            bullet: '✓',
          ),
        ),
        NotePanel(
          title: 'Correction détaillée',
          emoji: '📝',
          tone: Tone.violet,
          seed: 115,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                for (final (i, q) in config.questions.indexed)
                  if (byId.containsKey(q.id))
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      leading: Icon(
                        byId[q.id]!.correct ? Icons.check_circle : Icons.cancel,
                        color: toneBright(
                          byId[q.id]!.correct ? Tone.green : Tone.red,
                        ),
                      ),
                      title: Text(
                        '${i + 1}. ${q.prompt}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Hand.sansText(context, size: 15).copyWith(
                          color: toneColors(
                            byId[q.id]!.correct ? Tone.green : Tone.red,
                            brightness,
                          ).ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      initiallyExpanded: !byId[q.id]!.correct && isExam,
                      children: [
                        Text(q.prompt, style: Hand.bodyText(context)),
                        const SizedBox(height: 8),
                        QuestionCorrection(
                          question: q,
                          chosen: byId[q.id]!.chosen,
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GradientButton(
            emoji: '✅',
            label: 'Terminer',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
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
