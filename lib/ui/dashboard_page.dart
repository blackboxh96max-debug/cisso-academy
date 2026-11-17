import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../data/progress_store.dart';
import '../logic/badges.dart';
import '../logic/stats.dart';
import '../logic/study_groups.dart';
import '../models/content.dart';
import 'chapter_page.dart';
import 'course_view_bar.dart';
import 'lesson_page.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/page_kit.dart';
import 'notebook/note_box.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'quiz_hub_page.dart';
import 'theme.dart';
import 'widgets.dart';
import 'search_page.dart';

/// Tableau de bord visuel : accueil illustré, progression, modules,
/// graphiques, badges, objectif du jour et accès rapides.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onNavigate, this.onOpenModule});

  /// Change d'onglet (0 accueil, 1 cours, 2 QCM, 3 flashcards, 4 glossaire).
  final ValueChanged<int> onNavigate;

  /// Ouvre la page Cours sur un module (son rang dans la vue choisie).
  final ValueChanged<int>? onOpenModule;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final stats = state.stats;
    final width = MediaQuery.sizeOf(context).width;
    final twoColumns = width >= 1000;

    final welcome = _WelcomeCard(
      stats: stats,
      onOpen: () => _openRecommendation(context, stats.recommendation),
    );
    final modules = _ModuleCards(
      stats: stats,
      onOpen: (n) => onOpenModule == null ? onNavigate(1) : onOpenModule!(n),
    );
    final daily = _DailyGoal(stats: stats);
    final quick = _QuickAccess(onNavigate: onNavigate);
    final scores = _ScoreChart(sessions: stats.sessions);
    final radar = _DomainRadar(stats: stats);
    final pie = _AnswersPie(stats: stats);
    final mastery = _ChapterMastery(stats: stats);
    final badges = _Badges(achievements: computeAchievements(stats));
    final errors = _WeakSpots(stats: stats);
    final history = _History(stats: stats);

    final Widget body;
    if (twoColumns) {
      body = Column(
        children: [
          welcome,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [modules, scores, radar, mastery, history],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(children: [daily, quick, pie, badges, errors]),
              ),
            ],
          ),
        ],
      );
    } else {
      body = Column(
        children: [
          welcome,
          daily,
          quick,
          modules,
          scores,
          radar,
          pie,
          mastery,
          badges,
          errors,
          history,
        ],
      );
    }

    return Scaffold(
      backgroundColor: Paper.of(context).background,
      appBar: AppBar(
        title: const Text('CISSO Academy'),
        actions: [
          const SearchAction(),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (v) {
              if (v == 'settings') _settings(context);
              if (v == 'reset') _confirmReset(context);
              if (v == 'about') _about(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings', child: Text('Réglages')),
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
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          width < 600 ? 12 : 24,
          4,
          width < 600 ? 12 : 24,
          32,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: body,
          ),
        ),
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

  void _settings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final state = AppScope.of(ctx);
        final systemReduced = MediaQuery.disableAnimationsOf(ctx);
        return AlertDialog(
          title: const Text('Réglages'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Animations'),
                subtitle: Text(
                  systemReduced
                      ? 'Désactivées par le réglage « réduire les animations » de votre appareil.'
                      : 'Apparition des schémas, retournement des flashcards, effets de réussite.',
                ),
                value: state.animationsSetting,
                onChanged: (v) => state.setAnimations(v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
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

/// Carte de section du tableau de bord : titre manuscrit, encadré dessiné.
typedef _Panel = NotePanel;

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.stats, required this.onOpen});

  final ProgressStats stats;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final r = stats.recommendation;
    const onGradient = Colors.white;
    final ring = _ProgressRing(value: stats.overallProgress);
    final art = Semantics(
      label: 'Illustration : un cahier ouvert, un crayon et un bouclier de sécurité.',
      image: true,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: SvgPicture.asset(
          'assets/illustrations/welcome.svg',
          height: 110,
          excludeFromSemantics: true,
        ),
      ),
    );
    final recommendation = InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: HandBox(
        fill: const Color(0xFFFFF3B0),
        stroke: toneBright(Tone.yellow),
        strokeWidth: 2.4,
        seed: 21,
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prochaine révision recommandée',
                    style: Hand.boxLabel(context, Tone.orange),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.title,
                    style: TextStyle(
                      fontFamily: Hand.title,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: paper.ink,
                      height: 1.1,
                    ),
                  ),
                  Text(r.detail, style: Hand.sansText(context, size: 14)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: paper.ink),
          ],
        ),
      ),
    );
    return HandBox(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFDB2777)],
      ),
      stroke: const Color(0xFF4C1D95),
      strokeWidth: 2.4,
      seed: 17,
      child: LayoutBuilder(
        builder: (context, c) {
          final greeting = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour et bonne révision !',
                style: const TextStyle(
                  fontFamily: Hand.title,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: onGradient,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                encouragement(stats),
                style: Hand.bodyText(context)
                    .copyWith(fontSize: 19, color: onGradient),
              ),
              const SizedBox(height: 4),
              Text(
                '✨ ${quoteOfTheDay(AppScope.of(context).now())}',
                style: Hand.noteText(context).copyWith(
                  fontSize: 16,
                  color: onGradient.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 10),
              recommendation,
            ],
          );
          if (c.maxWidth >= 720) {
            return Row(
              children: [
                art,
                const SizedBox(width: 16),
                Expanded(child: greeting),
                const SizedBox(width: 20),
                ring,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(height: 110, child: art),
                  ring,
                ],
              ),
              const SizedBox(height: 8),
              greeting,
            ],
          );
        },
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    Widget ring(double v) => SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 11,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              color: const Color(0xFFFDE047),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(v * 100).round()} %',
                style: const TextStyle(
                  fontFamily: Hand.title,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              Text(
                'Progression globale',
                textAlign: TextAlign.center,
                style: Hand.sansText(
                  context,
                  size: 10.5,
                ).copyWith(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
    if (!animationsOn(context)) return ring(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => ring(v),
    );
  }
}

class _ModuleCards extends StatefulWidget {
  const _ModuleCards({required this.stats, required this.onOpen});

  final ProgressStats stats;

  /// Ouvre le cours sur un module (son rang dans la vue choisie).
  final ValueChanged<int> onOpen;

  @override
  State<_ModuleCards> createState() => _ModuleCardsState();
}

class _ModuleCardsState extends State<_ModuleCards> {
  /// Liste des modules dépliée (repliée au départ).
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final view = currentView(state);
    final groups = studyGroups(state.library, view);
    final brightness = Theme.of(context).brightness;
    final stats = widget.stats;

    double progressOf(StudyGroup g) {
      if (g.moduleNumber != null) {
        return stats.moduleProgress(state.library.modules[g.index].id);
      }
      if (g.lessonIds.isEmpty) return 0;
      return g.lessonIds.where(state.readLessons.contains).length /
          g.lessonIds.length;
    }

    String detailOf(StudyGroup g, double progress) {
      final pct = '${(progress * 100).round()} %';
      if (g.moduleNumber != null) {
        final available = g.chapters.where((ch) => ch.available).length;
        return '$pct · $available/${g.chapters.length} chapitre(s) disponible(s)';
      }
      final read = g.lessonIds.where(state.readLessons.contains).length;
      return '$pct · $read/${g.lessonIds.length} leçon(s) lue(s)';
    }

    final toggle = IconButton(
      tooltip: _open
          ? 'Replier la liste des modules'
          : 'Déplier la liste des modules',
      onPressed: () => setState(() => _open = !_open),
      icon: ExpandChevron(open: _open, onDark: false),
    );

    return _Panel(
      tone: Tone.violet,
      title: 'Mes ${groups.length} modules',
      emoji: '🗂️',
      seed: 23,
      trailing: toggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CourseViewSelector(),
          const SizedBox(height: 8),
          if (!_open)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _open = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Vue ${courseViewLabel(view)} : '
                  '${groups.map((g) => g.label.replaceFirst('Module ', 'M')).join(' · ')}'
                  '  ▸ Déplier',
                  style: Hand.sansText(context, size: 13.5).copyWith(
                    color: Paper.of(context).inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final perRow = c.maxWidth >= 640
                    ? 3
                    : (c.maxWidth >= 380 ? 2 : 1);
                final w = (c.maxWidth - 10 * (perRow - 1)) / perRow;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final g in groups)
                      SizedBox(
                        width: w,
                        child: Builder(
                          builder: (context) {
                            final (tone, emoji) = groupStyle(g);
                            final colors = toneColors(tone, brightness);
                            final progress = progressOf(g);
                            return InkWell(
                              onTap: () => widget.onOpen(g.index),
                              borderRadius: BorderRadius.circular(14),
                              child: HandBox(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colors.ink,
                                    Color.lerp(
                                      toneBright(tone),
                                      Colors.white,
                                      0.1,
                                    )!,
                                  ],
                                ),
                                stroke: colors.ink,
                                strokeWidth: 2.2,
                                seed: 30 + g.index,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            g.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                              fontFamily: Hand.title,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      g.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Hand.sansText(context, size: 13)
                                          .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 8,
                                        color: const Color(0xFFFDE047),
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      detailOf(g, progress),
                                      style: Hand.sansText(
                                        context,
                                        size: 11.5,
                                      ).copyWith(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DailyGoal extends StatelessWidget {
  const _DailyGoal({required this.stats});

  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final done = min(stats.answersToday, dailyAnswerGoal);
    final reached = stats.answersToday >= dailyAnswerGoal;
    final orange = toneColors(Tone.orange, Theme.of(context).brightness);
    return NoteBox(
      tone: Tone.yellow,
      emoji: '📅',
      label: 'Objectif du jour',
      sticky: true,
      seed: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reached
                ? '🎉 Objectif atteint : ${stats.answersToday} réponses aujourd\'hui !'
                : '$done / $dailyAnswerGoal réponses aujourd\'hui',
            style: Hand.noteText(context).copyWith(fontSize: 20),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: done / dailyAnswerGoal,
              minHeight: 10,
              color: orange.ink,
              backgroundColor: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stats.streakDays == 0
                ? 'Répondez à une question pour démarrer une série de jours.'
                : '🔥 ${stats.streakDays} jour(s) de révision d\'affilée',
            style: Hand.sansText(context, size: 13),
          ),
        ],
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    Widget button(String emoji, String label, Tone tone, VoidCallback onTap) {
      final c = toneColors(tone, brightness);
      return ActionChip(
        avatar: Text(emoji),
        label: Text(label),
        backgroundColor: c.fill,
        side: BorderSide(color: c.ink.withValues(alpha: 0.5)),
        labelStyle: TextStyle(
          fontFamily: Hand.sans,
          fontWeight: FontWeight.w700,
          color: c.ink,
        ),
        onPressed: onTap,
      );
    }

    return _Panel(
      tone: Tone.pink,
      title: 'Accès rapide',
      emoji: '⚡',
      seed: 25,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          button('📘', 'Cours', Tone.blue, () => onNavigate(1)),
          button('📝', 'QCM et examen blanc', Tone.pink, () => onNavigate(2)),
          button('🃏', 'Révisions', Tone.violet, () => onNavigate(3)),
          button('🔤', 'Glossaire', Tone.turquoise, () => onNavigate(4)),
        ],
      ),
    );
  }
}

/// Courbe des scores des séries terminées (interactive : toucher un point).
class _ScoreChart extends StatelessWidget {
  const _ScoreChart({required this.sessions});

  final List<SessionRecord> sessions;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final brightness = Theme.of(context).brightness;
    final recent = sessions.length > 15
        ? sessions.sublist(sessions.length - 15)
        : sessions;
    final Widget child;
    if (recent.length < 2) {
      child = _Empty(
        recent.isEmpty
            ? 'Terminez deux séries de QCM pour voir votre courbe de progression.'
            : 'Encore une série et votre courbe apparaîtra (dernier score : ${recent.first.score}/100).',
      );
    } else {
      final blue = toneColors(Tone.blue, brightness);
      child = SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            minX: 0,
            maxX: (recent.length - 1).toDouble(),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (v) => FlLine(
                color: v == masteryThreshold * 100
                    ? toneColors(Tone.green, brightness).ink
                    : paper.rule,
                strokeWidth: v == masteryThreshold * 100 ? 1.6 : 1,
                dashArray: v == masteryThreshold * 100 ? [6, 4] : null,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 22,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt() + 1}',
                    style: Hand.sansText(context, size: 11),
                  ),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: Hand.sansText(context, size: 11),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => paper.card,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${recent[s.x.toInt()].mode.label}\n${s.y.toInt()}/100 · ${formatDate(recent[s.x.toInt()].finishedAt)}',
                      TextStyle(
                        fontFamily: Hand.sans,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: paper.ink,
                      ),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final (i, s) in recent.indexed)
                    FlSpot(i.toDouble(), s.score.toDouble()),
                ],
                isCurved: true,
                preventCurveOverShooting: true,
                color: blue.ink,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: blue.fill.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          duration: animationsOn(context)
              ? const Duration(milliseconds: 400)
              : Duration.zero,
        ),
      );
    }
    return _Panel(
      tone: Tone.blue,
      title: 'Évolution de mes scores',
      emoji: '📈',
      seed: 27,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          if (recent.length >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Pointillés verts : seuil de maîtrise (${(masteryThreshold * 100).round()}/100). Touchez un point pour le détail.',
                style: Hand.sansText(context, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Radar des compétences par domaine officiel (réussite en %).
class _DomainRadar extends StatelessWidget {
  const _DomainRadar({required this.stats});

  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    final paper = Paper.of(context);
    final brightness = Theme.of(context).brightness;
    final violet = toneColors(Tone.violet, brightness);
    final domains = library.domains;
    final withData = stats.domainAccuracy.length;
    double rate(String id) {
      final v = stats.domainAccuracy[id];
      return v == null || v.$2 == 0 ? 0 : v.$1 / v.$2 * 100;
    }

    return _Panel(
      tone: Tone.violet,
      title: 'Radar des compétences',
      emoji: '🕸️',
      seed: 29,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (withData == 0)
            const _Empty(
              'Répondez à des questions : chaque domaine officiel de l\'examen apparaîtra sur le radar.',
            ),
          SizedBox(
            height: 260,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                tickCount: 4,
                ticksTextStyle: const TextStyle(
                  fontSize: 0,
                  color: Colors.transparent,
                ),
                radarBorderData: BorderSide(color: paper.inkSoft, width: 1.2),
                gridBorderData: BorderSide(color: paper.rule, width: 1),
                tickBorderData: BorderSide(color: paper.rule, width: 1),
                titlePositionPercentageOffset: 0.12,
                titleTextStyle: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: paper.ink,
                ),
                getTitle: (i, _) => RadarChartTitle(text: 'D${i + 1}'),
                dataSets: [
                  RadarDataSet(
                    fillColor: violet.ink.withValues(alpha: 0.25),
                    borderColor: violet.ink,
                    borderWidth: 2.5,
                    entryRadius: 3,
                    dataEntries: [
                      for (final d in domains) RadarEntry(value: rate(d.id)),
                    ],
                  ),
                  // Jeu invisible fixant l'échelle de 0 à 100 %.
                  RadarDataSet(
                    fillColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    entryRadius: 0,
                    dataEntries: [
                      for (final _ in domains) const RadarEntry(value: 100),
                    ],
                  ),
                ],
              ),
              duration: animationsOn(context)
                  ? const Duration(milliseconds: 400)
                  : Duration.zero,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              for (final (i, d) in domains.indexed)
                Text(
                  'D${i + 1} ${d.nameFr}'
                  '${stats.domainAccuracy.containsKey(d.id) ? ' · ${rate(d.id).round()} %' : ''}',
                  style: Hand.sansText(context, size: 12).copyWith(
                    fontWeight: stats.domainAccuracy.containsKey(d.id)
                        ? FontWeight.w800
                        : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Camembert des dernières réponses justes ou fausses.
class _AnswersPie extends StatelessWidget {
  const _AnswersPie({required this.stats});

  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ok = stats.domainAccuracy.values.fold<int>(0, (s, v) => s + v.$1);
    final seen = stats.domainAccuracy.values.fold<int>(0, (s, v) => s + v.$2);
    final ko = seen - ok;
    final green = toneColors(Tone.green, brightness);
    final red = toneColors(Tone.red, brightness);
    final paper = Paper.of(context);
    return _Panel(
      tone: Tone.green,
      title: 'Justes ou fausses ?',
      emoji: '🥧',
      seed: 31,
      child: seen == 0
          ? const _Empty('Aucune réponse pour l\'instant.')
          : Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 30,
                      sectionsSpace: 3,
                      sections: [
                        PieChartSectionData(
                          value: ok.toDouble(),
                          color: green.ink,
                          radius: 32,
                          title: ok == 0 ? '' : '$ok',
                          titleStyle: const TextStyle(
                            fontFamily: Hand.title,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: ko.toDouble(),
                          color: red.ink,
                          radius: 32,
                          title: ko == 0 ? '' : '$ko',
                          titleStyle: const TextStyle(
                            fontFamily: Hand.title,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(ok / seen * 100).round()} % de réussite',
                        style: TextStyle(
                          fontFamily: Hand.title,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: paper.ink,
                        ),
                      ),
                      Text(
                        '✔ $ok juste(s)   ✘ $ko à revoir',
                        style: Hand.sansText(context, size: 13),
                      ),
                      Text(
                        'Dernière réponse à chaque question vue.',
                        style: Hand.sansText(context, size: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Barres de maîtrise par chapitre disponible, avec statut.
class _ChapterMastery extends StatelessWidget {
  const _ChapterMastery({required this.stats});

  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = Paper.of(context);
    return _Panel(
      tone: Tone.turquoise,
      title: 'Maîtrise des chapitres',
      emoji: '📊',
      seed: 33,
      trailing: Text(
        'seuil ${(masteryThreshold * 100).round()} %',
        style: Hand.sansText(context, size: 12),
      ),
      child: Column(
        children: [
          for (final c in stats.availableChapters)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChapterPage(chapterId: c.chapter.id),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.chapter.title,
                            style: Hand.bodyText(context)
                                .copyWith(fontSize: 18, height: 1.2),
                          ),
                        ),
                        Sticker(
                          text: c.status.label,
                          tone: _statusTone(c.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: c.progress,
                        minHeight: 9,
                        color: toneColors(
                          _statusTone(c.status),
                          brightness,
                        ).ink,
                        backgroundColor: paper.rule,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c.lessonsRead}/${c.lessonCount} leçons · ${c.questionsSeen}/${c.questionCount} questions · '
                      'réussite ${(c.accuracy * 100).round()} %',
                      style: Hand.sansText(context, size: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Tone _statusTone(ChapterStatus s) => switch (s) {
  ChapterStatus.mastered => Tone.green,
  ChapterStatus.toReview => Tone.red,
  ChapterStatus.inProgress => Tone.blue,
  ChapterStatus.notStarted => Tone.yellow,
};

class _Badges extends StatelessWidget {
  const _Badges({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final earned = achievements.where((a) => a.earned).length;
    return _Panel(
      tone: Tone.orange,
      title: 'Mes badges',
      emoji: '🏅',
      seed: 35,
      trailing: Text(
        '$earned/${achievements.length}',
        style: Hand.sansText(
          context,
          size: 13,
        ).copyWith(fontWeight: FontWeight.w800),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final a in achievements)
            Tooltip(
              message: a.rule,
              child: Semantics(
                label:
                    '${a.title} : ${a.earned ? 'obtenu' : 'pas encore obtenu'}. ${a.rule}.',
                excludeSemantics: true,
                child: SizedBox(
                  width: 84,
                  child: Opacity(
                    opacity: a.earned ? 1 : 0.38,
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: a.earned
                                ? toneColors(
                                    Tone.yellow,
                                    Theme.of(context).brightness,
                                  ).fill
                                : paper.rule,
                            border: Border.all(
                              color: paper.inkSoft,
                              width: 1.6,
                            ),
                          ),
                          child: Text(
                            a.earned ? a.emoji : '🔒',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.title,
                          textAlign: TextAlign.center,
                          style: Hand.sansText(context, size: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeakSpots extends StatelessWidget {
  const _WeakSpots({required this.stats});

  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return _Panel(
      tone: Tone.red,
      title: 'Suivi des erreurs',
      emoji: '🎯',
      seed: 37,
      trailing: stats.wrongQuestionIds.isEmpty
          ? null
          : TextButton(
              onPressed: () => startRetry(context),
              child: Text('Reprendre (${stats.wrongQuestionIds.length})'),
            ),
      child: stats.weakConcepts.isEmpty
          ? _Empty(
              stats.totalAnswers == 0
                  ? 'Répondez à quelques questions pour voir apparaître vos notions fragiles.'
                  : 'Aucune erreur en cours : toutes vos dernières réponses sont justes.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in stats.weakConcepts.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.recurrent ? '🚨 ' : '• ',
                          style: const TextStyle(fontSize: 15),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: c.concept,
                                  style: Hand.bodyText(context).copyWith(
                                    fontSize: 18,
                                    height: 1.2,
                                    color: c.recurrent
                                        ? toneColors(Tone.red, brightness).ink
                                        : null,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '\n${c.errors} erreur(s) sur ${c.attempts} réponse(s)'
                                      '${c.recurrent ? ' · lacune récurrente' : ''}',
                                  style: Hand.sansText(context, size: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.stats});

  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.sessions.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return _Panel(
      tone: Tone.blue,
      title: 'Historique',
      emoji: '🕘',
      seed: 39,
      child: Column(
        children: [
          for (final s in stats.sessions.reversed.take(8))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${s.mode.label} · ${s.score}/100',
                style: Hand.sansText(
                  context,
                  size: 14,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${formatDate(s.finishedAt)} · ${s.correctCount}/${s.total} · '
                '${formatDuration(Duration(seconds: s.durationSeconds))}',
                style: Hand.sansText(context, size: 12),
              ),
              trailing: Icon(
                Icons.circle,
                size: 12,
                color: successColor(s.score >= masteryThreshold * 100, scheme),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: Hand.noteText(context)
            .copyWith(fontSize: 16, color: Paper.of(context).inkSoft),
      ),
    );
  }
}
