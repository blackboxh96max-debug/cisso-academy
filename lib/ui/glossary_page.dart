import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'widgets.dart';

/// Glossaire bilingue anglais/français, avec recherche hors ligne.
class GlossaryPage extends StatefulWidget {
  const GlossaryPage({super.key, this.initialQuery});

  /// Recherche déjà saisie à l'ouverture (venue d'un mot-clé d'une leçon).
  final String? initialQuery;

  @override
  State<GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends State<GlossaryPage> {
  late String _query = widget.initialQuery ?? '';
  late final _field = TextEditingController(text: _query);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terms = AppScope.of(context).library.glossary
        .where((t) => t.matches(_query))
        .toList();
    final paper = Paper.of(context);
    final brightness = Theme.of(context).brightness;
    return NotebookPage(
      title: 'Glossaire',
      maxWidth: 820,
      children: [
        GradientBanner(
          tone: Tone.turquoise,
          toTone: Tone.blue,
          seed: 81,
          child: Row(
            children: [
              const Text('🔤', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Le vocabulaire de l\'examen, en français et en anglais',
                  style: Hand.sansText(
                    context,
                    size: 15,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        HandBox(
          fill: paper.card,
          stroke: toneBright(Tone.turquoise),
          strokeWidth: 2.2,
          seed: 82,
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
          child: TextField(
            controller: _field,
            style: Hand.sansText(context, size: 16),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Rechercher (français, anglais ou acronyme)',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Sticker(
            text: '📚 ${terms.length} terme(s)',
            tone: Tone.turquoise,
          ),
        ),
        const SizedBox(height: 6),
        for (final (i, t) in terms.indexed)
          Builder(
            builder: (context) {
              final tone = rainbowTones[i % rainbowTones.length];
              final c = toneColors(tone, brightness);
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: HandBox(
                  fill: paper.card,
                  stroke: toneBright(tone),
                  strokeWidth: 2,
                  seed: 90 + i,
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      iconColor: c.ink,
                      collapsedIconColor: c.ink,
                      title: Text(
                        t.termFr,
                        style: TextStyle(
                          fontFamily: Hand.body,
                          fontSize: 21,
                          color: c.ink,
                        ),
                      ),
                      subtitle: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '🇬🇧 ${t.termEn}',
                            style: Hand.sansText(context, size: 13),
                          ),
                          if (t.acronym != null)
                            Sticker(text: t.acronym!, tone: tone),
                        ],
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          t.definition,
                          style: Hand.definition(context),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          decoration: BoxDecoration(
                            color: toneColors(Tone.turquoise, brightness).fill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: toneBright(Tone.turquoise),
                                width: 4,
                              ),
                            ),
                          ),
                          child: Text(
                            '💡 Exemple : ${t.example}',
                            style: Hand.noteText(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SourceBadge(t.kind),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
