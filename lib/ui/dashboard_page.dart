import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../logic/stats.dart';
import '../models/content.dart';
import 'chapter_page.dart';
import 'lesson_page.dart';
import 'quiz_hub_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// Tableau de bord : progression, scores, lacunes, prochaine révision.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onNavigate});

  /// Change d'onglet (0 accueil, 1 cours, 2 QCM, 3 flashcards, 4 glossaire).
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final stats = state.stats;
    final library = state.library;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final avg = stats.averageScore;
    final mastered = stats.availableChapters
        .where((c) => c.status == ChapterStatus.mastered)
        .toList();
    final toReview = stats.availableChapters
        .where((c) => c.status == ChapterStatus.toReview)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CISSO Academy'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') _confirmReset(context);
              if (v == 'about') _about(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'about',
                child: Text('À propos de l\'examen'),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Text('Réinitialiser ma progression'),
              ),
            ],
          ),
        ],
      ),
      body: ReadingList(
        children: [
          _RecommendationCard(
            recommendation: stats.recommendation,
            onOpen: () => _openRecommendation(context, stats.recommendation),
          ),
          const SectionTitle('Vue d\'ensemble'),
          TileGrid(
            children: [
              StatTile(
                label: 'Progression globale',
                value: '${(stats.overallProgress * 100).round()} %',
                caption:
                    '${library.availableChapters.length}/${library.chapters.length} chapitres disponibles',
              ),
              StatTile(
                label: 'Score moyen',
                value: avg == null ? '–' : '$avg/100',
                caption: '${stats.sessions.length} série(s) terminée(s)',
              ),
              StatTile(
                label: 'Questions traitées',
                value: '${stats.distinctQuestions}/${library.questions.length}',
                caption: '${stats.totalAnswers} réponse(s) au total',
              ),
              StatTile(
                label: 'Flashcards',
                value:
                    '${stats.masteredCardCount}/${library.flashcards.length}',
                caption: 'maîtrisées · ${stats.dueCardCount} à revoir',
              ),
            ],
          ),
          const SectionTitle('Progression par module'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final m in library.modules)
                    LabeledProgress(
                      label: 'Module ${m.number} · ${m.title}',
                      value: stats.moduleProgress(m.id),
                    ),
                ],
              ),
            ),
          ),
          const SectionTitle('Chapitres'),
          Card(
            child: Column(
              children: [
                for (final c in stats.availableChapters)
                  ListTile(
                    title: Text(c.chapter.title),
                    subtitle: Text(
                      '${c.lessonsRead}/${c.lessonCount} leçons · '
                      '${c.questionsSeen}/${c.questionCount} questions · '
                      'réussite ${(c.accuracy * 100).round()} %',
                    ),
                    trailing: _StatusChip(c.status),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChapterPage(chapterId: c.chapter.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (mastered.isNotEmpty || toReview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Maîtrisés : ${mastered.length} · À revoir : ${toReview.length} '
              '(seuil de validation : ${(masteryThreshold * 100).round()} %)',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          SectionTitle(
            'Suivi des erreurs',
            trailing: stats.wrongQuestionIds.isEmpty
                ? null
                : TextButton(
                    onPressed: () => startRetry(context),
                    child: Text('Reprendre (${stats.wrongQuestionIds.length})'),
                  ),
          ),
          if (stats.weakConcepts.isEmpty)
            Text(
              stats.totalAnswers == 0
                  ? 'Répondez à quelques questions pour voir apparaître vos notions fragiles.'
                  : 'Aucune erreur en cours : toutes vos dernières réponses sont justes.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final c in stats.weakConcepts.take(6))
                    ListTile(
                      leading: Icon(
                        c.recurrent ? Icons.priority_high : Icons.error_outline,
                        color: c.recurrent
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(c.concept),
                      subtitle: Text(
                        '${c.errors} erreur(s) sur ${c.attempts} réponse(s)'
                        '${c.recurrent ? ' · lacune récurrente' : ''}',
                      ),
                    ),
                ],
              ),
            ),
          const SectionTitle('Réussite par domaine officiel'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final d in library.domains)
                    if (stats.domainAccuracy.containsKey(d.id))
                      LabeledProgress(
                        label: '${d.nameFr} (poids ${d.weight} %)',
                        value:
                            stats.domainAccuracy[d.id]!.$1 /
                            stats.domainAccuracy[d.id]!.$2,
                      ),
                  if (stats.domainAccuracy.isEmpty)
                    Text(
                      'Aucune donnée pour l\'instant.',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (stats.sessions.isNotEmpty) ...[
            const SectionTitle('Historique'),
            Card(
              child: Column(
                children: [
                  for (final s in stats.sessions.reversed.take(8))
                    ListTile(
                      dense: true,
                      title: Text('${s.mode.label} · ${s.score}/100'),
                      subtitle: Text(
                        '${formatDate(s.finishedAt)} · ${s.correctCount}/${s.total} · '
                        '${formatDuration(Duration(seconds: s.durationSeconds))}',
                      ),
                      trailing: Icon(
                        Icons.circle,
                        size: 12,
                        color: successColor(
                          s.score >= masteryThreshold * 100,
                          scheme,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openRecommendation(BuildContext context, Recommendation r) {
    final state = AppScope.read(context);
    switch (r.kind) {
      case RecommendationKind.flashcards:
        onNavigate(3);
      case RecommendationKind.retryErrors:
        startRetry(context);
      case RecommendationKind.lesson:
        final lesson = state.library.chapters
            .expand((c) => c.lessons)
            .firstWhere((l) => l.id == r.targetId);
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => LessonPage(lesson: lesson)));
      case RecommendationKind.practice:
        startPractice(context, chapterId: r.targetId!);
      case RecommendationKind.exam:
        onNavigate(2);
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser la progression ?'),
        content: const Text(
          'Toutes vos réponses, séries, flashcards et leçons lues seront '
          'effacées de cet appareil. Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await AppScope.read(context).resetProgress();
    }
  }

  void _about(BuildContext context) {
    final info = AppScope.read(context).library.examInfo;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('L\'examen CISSO'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SourceBadge(SourceKind.official),
            const SizedBox(height: 12),
            Text(
              '${info.questionCount} questions à choix multiples, '
              '${info.durationMinutes} minutes, seuil de réussite '
              '${info.passingScore}/100.',
            ),
            const SizedBox(height: 8),
            Text(
              'Source : ${info.source}, vérifiée le ${info.verifiedOn}. '
              'Vérifiez toujours ces paramètres sur le site de MILE2 avant '
              'de vous inscrire.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Les questions de l\'application sont originales : '
              'elles ne reproduisent pas les questions de l\'examen.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.onOpen,
  });

  final Recommendation recommendation;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prochaine révision recommandée',
                      style: text.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recommendation.title,
                      style: text.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recommendation.detail,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final ChapterStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      ChapterStatus.mastered => successColor(true, scheme),
      ChapterStatus.toReview => scheme.error,
      ChapterStatus.inProgress => scheme.primary,
      ChapterStatus.notStarted => scheme.outline,
    };
    return Text(
      status.label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
    );
  }
}
