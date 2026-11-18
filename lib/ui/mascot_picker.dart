import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import 'mascot.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Liste des mascottes, avec un aperçu animé de chacune ; le choix est
/// mémorisé sur l'appareil.
Future<void> showMascotPicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, scroll) => _MascotList(scroll: scroll),
      ),
    );

class _MascotList extends StatelessWidget {
  const _MascotList({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final selected = mascotById(state.mascotId);
    final paper = Paper.of(context);
    final violet = toneColors(Tone.violet, Theme.of(context).brightness);
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text('Choisis ta mascotte', style: Hand.subtitle(context, Tone.violet)),
        Text(
          'Elle t\'accompagne dans l\'assistant : elle écoute, réfléchit et '
          'te montre la réponse.',
          style: Hand.sansText(context, size: 14),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 640 ? 3 : 2;
            final width = (c.maxWidth - 10 * (columns - 1)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in mascotCharacters)
                  SizedBox(
                    width: width,
                    child: _MascotTile(
                      character: m,
                      selected: m == selected,
                      onTap: () => state.setMascot(m.id),
                      paper: paper,
                      accent: violet.ink,
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

class _MascotTile extends StatelessWidget {
  const _MascotTile({
    required this.character,
    required this.selected,
    required this.onTap,
    required this.paper,
    required this.accent,
  });

  final MascotCharacter character;
  final bool selected;
  final VoidCallback onTap;
  final Paper paper;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${character.name}, ${character.species}',
      child: InkWell(
        key: Key('mascot-${character.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: HandBox(
          fill: selected
              ? toneColors(Tone.violet, Theme.of(context).brightness).fill
              : paper.card,
          stroke: selected ? toneBright(Tone.violet) : paper.rule,
          strokeWidth: selected ? 2.6 : 1.6,
          seed: character.id.hashCode,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            children: [
              Stack(
                children: [
                  Center(
                    child: Mascot(
                      mood: selected ? MascotMood.answering : MascotMood.idle,
                      size: 76,
                      character: character,
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(Icons.check_circle, color: accent),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                character.name,
                style: Hand.subtitle(
                  context,
                  Tone.violet,
                ).copyWith(fontSize: Hand.tsize(24)),
              ),
              Text(
                character.species,
                textAlign: TextAlign.center,
                style: Hand.sansText(
                  context,
                  size: 13,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                character.personality,
                textAlign: TextAlign.center,
                style: Hand.sansText(
                  context,
                  size: 12.5,
                ).copyWith(color: paper.inkSoft),
              ),
              const SizedBox(height: 4),
              Text(
                '« ${character.line(MascotMood.idle)} »',
                textAlign: TextAlign.center,
                style: Hand.sansText(
                  context,
                  size: 12.5,
                ).copyWith(color: accent, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
