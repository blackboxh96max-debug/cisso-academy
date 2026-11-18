import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../find_highlight.dart';
import 'hand_drawn.dart';
import 'look.dart';
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
    final brightness = Theme.of(context).brightness;
    final c = toneColors(tone, brightness);
    final dark = brightness == Brightness.dark;
    final pillText = dark ? const Color(0xFF15171C) : Colors.white;
    Widget box = HandBox(
      fill: c.fill,
      stroke: dark ? c.ink : toneBright(tone),
      strokeWidth: 2.4,
      seed: seed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              // Étiquette vive : pastille pleine de la couleur du bloc.
              Container(
                padding: const EdgeInsets.fromLTRB(8, 3, 12, 3),
                decoration: BoxDecoration(
                  color: c.ink,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: toneBright(tone).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      emoji ?? tone.emoji,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: Hand.boxLabel(
                          context,
                          tone,
                        ).copyWith(color: pillText),
                      ),
                    ),
                  ],
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
                  fontSize: Hand.tsize(26),
                  fontWeight: Hand.titleWeight,
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
    if (sticky && AppLook.active.tilt) {
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
  const HandBullets(
    this.items, {
    super.key,
    this.style,
    this.bullet = '•',
    this.itemSpan,
  });

  final List<String> items;
  final TextStyle? style;
  final String bullet;

  /// Construit le texte enrichi d'un élément (termes anglais, par exemple).
  final InlineSpan Function(int index, String item, TextStyle style)? itemSpan;

  @override
  Widget build(BuildContext context) {
    final s = style ?? Hand.bodyText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 22, child: Text(bullet, style: s)),
                Expanded(
                  child: itemSpan == null
                      ? FindText(item, style: s)
                      : Text.rich(itemSpan!(i, item, s)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
