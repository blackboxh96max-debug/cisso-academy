import 'package:material_ui/material_ui.dart';

import '../../logic/stats.dart';
import 'hand_drawn.dart';
import 'palette.dart';
import 'typography.dart';

/// Page au style cahier : fond papier, contenu centré et défilant.
class NotebookPage extends StatelessWidget {
  const NotebookPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.maxWidth = 920,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: Paper.of(context).background,
      appBar: AppBar(title: Text(title), actions: actions),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              narrow ? 12 : 24,
              4,
              narrow ? 12 : 24,
              40,
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Section encadrée à la main, titre manuscrit souligné de la couleur [tone].
class NotePanel extends StatelessWidget {
  const NotePanel({
    super.key,
    required this.title,
    required this.child,
    this.emoji,
    this.seed = 9,
    this.trailing,
    this.tone = Tone.blue,
  });

  final Tone tone;
  final String title;
  final String? emoji;
  final Widget child;
  final int seed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final c = toneColors(tone, Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: HandBox(
        fill: paper.page,
        stroke: toneBright(tone),
        strokeWidth: 2.4,
        seed: seed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (emoji != null) ...[
                  Text(emoji!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: HandUnderline(
                      color: toneBright(tone),
                      seed: seed,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: Hand.title,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Bandeau en dégradé (module, chapitre, résultat) avec texte blanc.
class GradientBanner extends StatelessWidget {
  const GradientBanner({
    super.key,
    required this.tone,
    required this.child,
    this.toTone,
    this.seed = 41,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 16),
  });

  final Tone tone;
  final Tone? toTone;
  final Widget child;
  final int seed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone, Theme.of(context).brightness);
    return HandBox(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          c.ink,
          toTone == null
              ? Color.lerp(toneBright(tone), Colors.white, 0.1)!
              : toneBright(toTone!),
        ],
      ),
      stroke: c.ink,
      strokeWidth: 2.2,
      seed: seed,
      padding: padding,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    );
  }
}

/// Barre de progression colorée, arrondie.
class HandProgress extends StatelessWidget {
  const HandProgress({
    super.key,
    required this.value,
    this.tone = Tone.blue,
    this.height = 10,
    this.onDark = false,
  });

  final double value;
  final Tone tone;
  final double height;

  /// Sur un fond en dégradé : barre jaune sur fond blanc translucide.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone, Theme.of(context).brightness);
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      value: '${(v * 100).round()} %',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: onDark ? Colors.white.withValues(alpha: 0.3) : c.fill,
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: onDark ? const Color(0xFFFDE047) : null,
                    gradient: onDark
                        ? null
                        : LinearGradient(colors: [c.ink, toneBright(tone)]),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gros bouton en dégradé, texte blanc.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.emoji,
    this.from = Tone.blue,
    this.to = Tone.violet,
    this.expand = false,
  });

  final String label;
  final String? emoji;
  final VoidCallback? onPressed;
  final Tone from;
  final Tone to;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final paper = Paper.of(context);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (emoji != null) ...[
          Text(emoji!, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Hand.sans,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: enabled ? Colors.white : paper.inkSoft,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(colors: [toneBright(from), toneBright(to)])
                : null,
            color: enabled ? null : paper.rule,
            borderRadius: BorderRadius.circular(999),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: toneBright(from).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tuile chiffrée colorée (statistiques des pages QCM et flashcards).
class HandStat extends StatelessWidget {
  const HandStat({
    super.key,
    required this.label,
    required this.value,
    required this.tone,
    this.emoji,
    this.seed = 13,
  });

  final String label;
  final String value;
  final Tone tone;
  final String? emoji;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone, Theme.of(context).brightness);
    return HandBox(
      fill: c.fill,
      stroke: toneBright(tone),
      strokeWidth: 2.2,
      seed: seed,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [?emoji, label].join(' '),
            style: Hand.sansText(
              context,
              size: 13,
            ).copyWith(color: c.ink, fontWeight: FontWeight.w800),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: Hand.title,
              fontSize: 36,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille de statut d'un chapitre, avec la couleur qui lui correspond.
Widget statusSticker(ChapterStatus status) => Sticker(
  text: switch (status) {
    ChapterStatus.notStarted => '🌱 ${status.label}',
    ChapterStatus.inProgress => '🚀 ${status.label}',
    ChapterStatus.toReview => '🔁 ${status.label}',
    ChapterStatus.mastered => '🏆 ${status.label}',
  },
  tone: switch (status) {
    ChapterStatus.notStarted => Tone.blue,
    ChapterStatus.inProgress => Tone.violet,
    ChapterStatus.toReview => Tone.orange,
    ChapterStatus.mastered => Tone.green,
  },
);

/// Tons parcourus en boucle pour colorer des listes (glossaire, fiche).
const rainbowTones = [
  Tone.blue,
  Tone.violet,
  Tone.pink,
  Tone.orange,
  Tone.green,
  Tone.turquoise,
];
