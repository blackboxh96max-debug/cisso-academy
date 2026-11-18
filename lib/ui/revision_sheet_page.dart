import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models/content.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/note_box.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'bilingual.dart';

/// Fiche de révision d'un chapitre, consultable hors ligne et copiable.
class RevisionSheetPage extends StatelessWidget {
  const RevisionSheetPage({super.key, required this.chapter});

  final Chapter chapter;

  String get plainText => chapter.revisionSheet
      .map((l) => l.startsWith('# ') ? l.substring(2).toUpperCase() : '• $l')
      .join('\n');

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final brightness = Theme.of(context).brightness;
    final titles = chapter.revisionSheet
        .where((l) => l.startsWith('# '))
        .map((l) => l.substring(2));
    final points = chapter.revisionSheet
        .where((l) => !l.startsWith('# '))
        .toList();
    final terms = AppScope.of(context).terms;
    final seen = <String>{};
    final matches = [for (final p in points) terms.findIn(p, skip: seen)];

    return NotebookPage(
      title: 'Fiche de révision',
      maxWidth: 820,
      actions: [
        IconButton(
          tooltip: 'Copier la fiche',
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: plainText));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Fiche copiée')));
            }
          },
        ),
      ],
      children: [
        GradientBanner(
          tone: Tone.orange,
          toTone: Tone.pink,
          seed: 71,
          child: Row(
            children: [
              const Text('📝', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titles.isEmpty ? chapter.title : titles.first,
                      style: TextStyle(
                        fontFamily: Hand.title,
                        fontSize: Hand.tsize(32),
                        height: 1.05,
                        fontWeight: Hand.titleWeight,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${points.length} points clés à savoir par cœur',
                      style: Hand.sansText(context, size: 14).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NotebookPaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, line) in points.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: toneBright(
                            rainbowTones[i % rainbowTones.length],
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontFamily: Hand.sans,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SelectableText.rich(
                          bilingualSpan(
                            context,
                            line,
                            matches[i],
                            Hand.bodyText(context).copyWith(
                              fontSize: Hand.bsize(19),
                              color: i.isEven
                                  ? paper.ink
                                  : toneColors(
                                      rainbowTones[i % rainbowTones.length],
                                      brightness,
                                    ).ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        NoteBox(
          tone: Tone.yellow,
          label: 'Astuce',
          emoji: '💡',
          sticky: true,
          child: Text(
            'Lisez la fiche à voix haute, cachez-la, puis récitez chaque point. '
            'Ceux qui vous échappent sont à revoir dans le cours.',
            style: Hand.noteText(context),
          ),
        ),
      ],
    );
  }
}

/// Feuille de cahier lignée dans un encadré dessiné.
class NotebookPaperCard extends StatelessWidget {
  const NotebookPaperCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HandBox(
      fill: Paper.of(context).page,
      stroke: toneBright(Tone.orange),
      strokeWidth: 2.4,
      seed: 72,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: NotebookPaper(
          child: LayoutBuilder(
            builder: (context, c) => Padding(
              padding: EdgeInsets.fromLTRB(
                c.maxWidth < 600 ? 22 : 58,
                22,
                18,
                10,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
