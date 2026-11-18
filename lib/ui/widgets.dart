import 'package:material_ui/material_ui.dart';

import '../models/content.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'theme.dart';

/// Étiquette qui indique la nature d'une information (officiel, général…).
class SourceBadge extends StatelessWidget {
  const SourceBadge(this.kind, {super.key});

  final SourceKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = sourceColor(kind, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        kind.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// Contenu centré à largeur de lecture, défilant.
class ReadingList extends StatelessWidget {
  const ReadingList({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readingWidth),
        child: ListView(
          padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: children,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(Tone.blue, Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: HandUnderline(
                color: toneBright(Tone.blue),
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: Hand.title,
                    fontSize: Hand.tsize(26),
                    fontWeight: Hand.titleWeight,
                    color: c.ink,
                  ),
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Indicateur chiffré, au style cahier.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.tone = Tone.blue,
  });

  final String label;
  final String value;
  final String? caption;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final stat = HandStat(label: label, value: value, tone: tone);
    if (caption == null) return stat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stat,
        Text(caption!, style: Hand.sansText(context, size: 12)),
      ],
    );
  }
}

/// Barre de progression avec libellé et pourcentage.
class LabeledProgress extends StatelessWidget {
  const LabeledProgress({
    super.key,
    required this.label,
    required this.value,
    this.tone = Tone.blue,
  });

  final String label;
  final double value;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone, Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: Hand.sansText(context, size: 14)),
              ),
              Text(
                '${(value * 100).round()} %',
                style: Hand.sansText(
                  context,
                  size: 14,
                ).copyWith(color: c.ink, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          HandProgress(value: value, tone: tone),
        ],
      ),
    );
  }
}

/// Grille responsive de tuiles (2 colonnes sur téléphone, 4 au-delà).
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 4 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String formatDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
