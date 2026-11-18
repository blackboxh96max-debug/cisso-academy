import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/look.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Choix du thème de l'application, avec un aperçu de chacun (écriture,
/// couleurs, émojis, encadré et tableau), et du mode clair ou sombre.
Future<void> showLookPicker(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.85,
    maxChildSize: 0.95,
    builder: (_, scroll) => _LookList(scroll: scroll),
  ),
);

class _LookList extends StatelessWidget {
  const _LookList({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final current = AppLook.byId(state.lookId);
    final brightness = Theme.of(context).brightness;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          'Thème de l\'application',
          style: Hand.subtitle(context, Tone.blue),
        ),
        Text(
          'Écriture, couleurs, émojis, dessins et tableaux : choisis le style '
          'qui te donne envie de lire. Ta progression ne change pas.',
          style: Hand.sansText(context, size: 14),
        ),
        const SizedBox(height: 12),
        Text(
          'Clair ou sombre',
          style: Hand.sansText(
            context,
            size: 14,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        SegmentedButton<ThemeMode>(
          key: const Key('brightness-mode'),
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('Appareil'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Clair'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Sombre'),
            ),
          ],
          selected: {state.brightnessMode},
          showSelectedIcon: false,
          onSelectionChanged: current.darkOnly
              ? null
              : (s) => state.setBrightnessMode(s.first),
        ),
        if (current.darkOnly)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Le thème « ${current.name} » est toujours sombre.',
              style: Hand.sansText(
                context,
                size: 12.5,
              ).copyWith(color: Paper.of(context).inkSoft),
            ),
          ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 640 ? 2 : 1;
            final width = (c.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final look in AppLook.all)
                  SizedBox(
                    width: width,
                    child: _LookTile(
                      look: look,
                      selected: look == current,
                      brightness: brightness,
                      onTap: () => state.setLook(look.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LookTile extends StatelessWidget {
  const _LookTile({
    required this.look,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  final AppLook look;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final accent = toneBright(Tone.blue);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Thème ${look.name}',
      child: InkWell(
        key: Key('look-${look.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: HandBox(
          fill: selected
              ? toneColors(Tone.blue, Theme.of(context).brightness).fill
              : paper.card,
          stroke: selected ? accent : paper.rule,
          strokeWidth: selected ? 2.6 : 1.4,
          seed: look.id.hashCode,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(look.preview, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      look.name,
                      style: Hand.sansText(
                        context,
                        size: 16,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: accent)
                  else if (look.darkOnly)
                    Icon(
                      Icons.dark_mode_outlined,
                      size: 18,
                      color: paper.inkSoft,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                look.description,
                style: Hand.sansText(
                  context,
                  size: 12.5,
                ).copyWith(color: paper.inkSoft),
              ),
              const SizedBox(height: 8),
              LookPreview(look: look, brightness: brightness),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aperçu d'un thème, dessiné avec ses propres polices et couleurs (sans
/// changer le thème en cours) : titre, encadré, texte, tableau et émojis.
class LookPreview extends StatelessWidget {
  const LookPreview({super.key, required this.look, required this.brightness});

  final AppLook look;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final b = look.darkOnly ? Brightness.dark : brightness;
    final paper = look.paper(b);
    final blue = look.colors(Tone.blue, b);
    final green = look.colors(Tone.green, b);
    final pillText = b == Brightness.dark
        ? const Color(0xFF15171C)
        : Colors.white;
    final body = TextStyle(
      fontFamily: look.bodyFont,
      fontSize: 17 * look.bodyScale,
      height: 1.35,
      color: paper.ink,
    );
    final radius = BorderRadius.circular(look.radius * 0.6);
    final cell = TextStyle(
      fontFamily: look.sansFont,
      fontSize: 12,
      color: paper.ink,
    );
    final headCell = switch (look.table) {
      TableLook.hand => TextStyle(
        fontFamily: look.titleFont,
        fontSize: 18 * look.titleScale,
        fontWeight: look.titleWeight,
        color: blue.ink,
      ),
      TableLook.zebra => cell.copyWith(
        fontWeight: FontWeight.w800,
        color: pillText,
      ),
      TableLook.neon => TextStyle(
        fontFamily: Hand.mono,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: blue.ink,
      ),
      TableLook.grid => cell.copyWith(fontWeight: FontWeight.w800),
    };
    final headFill = switch (look.table) {
      TableLook.hand => blue.fill,
      TableLook.grid => paper.ink.withValues(alpha: 0.07),
      TableLook.zebra => blue.ink,
      TableLook.neon => blue.ink.withValues(alpha: 0.18),
    };
    final border = switch (look.table) {
      TableLook.hand => TableBorder.symmetric(
        inside: BorderSide(color: paper.rule, width: 1.2),
      ),
      TableLook.grid => TableBorder.all(
        color: paper.ink.withValues(alpha: 0.35),
        width: 0.8,
      ),
      TableLook.zebra => TableBorder(
        horizontalInside: BorderSide(color: paper.rule, width: 0.8),
      ),
      TableLook.neon => TableBorder.all(
        color: blue.ink.withValues(alpha: 0.6),
        borderRadius: radius,
      ),
    };
    Widget pad(String t, TextStyle s) => Padding(
      padding: const EdgeInsets.all(5),
      child: Text(t, style: s),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: paper.page,
        borderRadius: radius,
        border: Border.all(color: paper.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Journalisation et SIEM',
            style: TextStyle(
              fontFamily: look.titleFont,
              fontSize: 30 * look.titleScale,
              fontWeight: look.titleWeight,
              height: 1.1,
              color: look.colors(Tone.violet, b).ink,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            decoration: BoxDecoration(
              color: green.fill,
              borderRadius: radius,
              border: Border.all(
                color: b == Brightness.dark
                    ? green.ink
                    : look.bright(Tone.green),
                width: look.wobble == 0 ? 1.4 : 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 2, 10, 2),
                  decoration: BoxDecoration(
                    color: green.ink,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${look.toneEmojis[Tone.green]}  BONNE PRATIQUE',
                    style: TextStyle(
                      fontFamily: look.sansFont,
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                      color: pillText,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Horodater et protéger chaque journal.', style: body),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Table(
            border: border,
            children: [
              TableRow(
                decoration: BoxDecoration(color: headFill),
                children: [pad('Sigle', headCell), pad('Rôle', headCell)],
              ),
              TableRow(
                children: [pad('SIEM', cell), pad('Corréler et alerter', cell)],
              ),
              TableRow(
                decoration: look.table == TableLook.zebra
                    ? BoxDecoration(color: blue.ink.withValues(alpha: 0.07))
                    : null,
                children: [
                  pad('SOAR', cell),
                  pad('Automatiser la réponse', cell),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [for (final t in Tone.values) look.toneEmojis[t]].join('  '),
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
