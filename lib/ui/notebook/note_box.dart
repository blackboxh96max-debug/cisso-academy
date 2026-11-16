import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'hand_drawn.dart';
import 'palette.dart';
import 'typography.dart';

/// Encadré pédagogique coloré : étiquette (emoji + titre en capitales),
/// contour tracé à la main, fond pastel de la couleur [tone].
///
/// Les encadrés jaunes ([sticky]) ressemblent à un post-it légèrement penché.
class NoteBox extends StatelessWidget {
  const NoteBox({
    super.key,
    required this.tone,
    required this.label,
    required this.child,
    this.emoji,
    this.title,
    this.trailing,
    this.sticky = false,
    this.seed = 7,
  });

  final Tone tone;
  final String label;
  final String? emoji;
  final String? title;
  final Widget child;
  final Widget? trailing;
  final bool sticky;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone, Theme.of(context).brightness);
    Widget box = HandBox(
      fill: c.fill,
      stroke: c.ink.withValues(alpha: 0.85),
      seed: seed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji ?? tone.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: Hand.boxLabel(context, tone),
                ),
              ),
              ?trailing,
            ],
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                title!,
                style: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: c.ink,
                ),
              ),
            ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    if (sticky) {
      box = Transform.rotate(
        angle: (seed.isEven ? -1 : 1) * 0.6 * pi / 180,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            box,
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 70,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(padding: const EdgeInsets.only(top: 18), child: box);
  }
}

/// Liste à puces manuscrite.
class HandBullets extends StatelessWidget {
  const HandBullets(this.items, {super.key, this.style, this.bullet = '•'});

  final List<String> items;
  final TextStyle? style;
  final String bullet;

  @override
  Widget build(BuildContext context) {
    final s = style ?? Hand.bodyText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 22, child: Text(bullet, style: s)),
                Expanded(child: Text(item, style: s)),
              ],
            ),
          ),
      ],
    );
  }
}
