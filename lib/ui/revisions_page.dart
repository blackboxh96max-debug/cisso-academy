import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../export/pdf_export.dart';
import '../export/pdf_save.dart';
import '../models/content.dart';
import 'bilingual.dart';
import 'flashcards_page.dart';
import 'mind_map_page.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/note_box.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'revision_sheet_page.dart';

/// Les trois supports de révision.
enum RevisionTab {
  flashcards('🃏', 'Flashcards'),
  sheets('📋', 'Fiches'),
  maps('🧠', 'Cartes mentales');

  const RevisionTab(this.emoji, this.label);
  final String emoji;
  final String label;
}

/// Menu « Révisions » : flashcards, fiches et cartes mentales, par module et
/// par chapitre, avec export PDF.
class RevisionsPage extends StatefulWidget {
  const RevisionsPage({super.key});

  @override
  State<RevisionsPage> createState() => _RevisionsPageState();
}

class _RevisionsPageState extends State<RevisionsPage> {
  RevisionTab _tab = RevisionTab.flashcards;

  /// Module affiché, ou `null` pour tous.
  String? _moduleId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final library = state.library;
    final modules = library.modules
        .where((m) => _moduleId == null || m.id == _moduleId)
        .toList();
    final locked = library.chapters.where((c) => !c.available).length;

    return NotebookPage(
      title: 'Révisions',
      children: [
        Text(
          'Révisez avec les flashcards, les fiches et les cartes mentales, '
          'chapitre par chapitre ou module entier. Chaque support se '
          'télécharge en PDF pour l\'imprimer ou le lire hors de l\'application.',
          style: Hand.bodyText(context),
        ),
        const SizedBox(height: 14),
        SegmentedButton<RevisionTab>(
          showSelectedIcon: false,
          segments: [
            for (final t in RevisionTab.values)
              ButtonSegment(value: t, label: Text('${t.emoji} ${t.label}')),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Tous les modules'),
              selected: _moduleId == null,
              onSelected: (_) => setState(() => _moduleId = null),
            ),
            for (final m in library.modules)
              ChoiceChip(
                label: Text('${moduleStyle(m.number).$2} Module ${m.number}'),
                selected: _moduleId == m.id,
                onSelected: (_) => setState(() => _moduleId = m.id),
              ),
          ],
        ),
        if (_tab == RevisionTab.flashcards) ...[
          const SizedBox(height: 16),
          Center(
            child: GradientButton(
              emoji: '🔁',
              label: 'Répétition espacée : cartes du jour',
              from: Tone.turquoise,
              to: Tone.violet,
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FlashcardsPage())),
            ),
          ),
        ],
        if (_tab == RevisionTab.maps && _moduleId == null)
          _Row(
            tone: Tone.pink,
            emoji: '🎓',
            title: 'Toute la formation',
            subtitle:
                '${library.modules.length} modules, '
                '${library.domains.length} domaines de l\'examen',
            onOpen: () =>
                _openMap(context, 'Toute la formation', courseMindMap(library)),
            onPdf: () => _openMap(
              context,
              'Toute la formation',
              courseMindMap(library),
              export: true,
            ),
            onHtml: () => _openMap(
              context,
              'Toute la formation',
              courseMindMap(library),
              html: true,
            ),
          ),
        for (final m in modules) ..._moduleSection(context, m),
        if (locked > 0) ...[
          const SizedBox(height: 18),
          NoteBox(
            tone: Tone.yellow,
            emoji: '🔒',
            label: 'À venir',
            sticky: true,
            child: Text(
              '$locked chapitre(s) arrivent dans les prochaines mises à jour, '
              'avec leurs flashcards, fiches et cartes.',
              style: Hand.noteText(context),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _moduleSection(BuildContext context, Module m) {
    final state = AppScope.of(context);
    final (tone, emoji) = moduleStyle(m.number);
    final chapters = m.chapters.where((c) => c.available).toList();
    final title = 'Module ${m.number} · ${m.title}';
    VoidCallback? moduleOpen;
    VoidCallback? modulePdf;
    VoidCallback? moduleHtml;
    String detail;
    switch (_tab) {
      case RevisionTab.flashcards:
        final ids = [
          for (final c in chapters) ...c.flashcards.map((f) => f.id),
        ];
        detail = '${ids.length} flashcards';
        if (ids.isNotEmpty) {
          moduleOpen = () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FlashcardSessionPage(cardIds: ids),
            ),
          );
          modulePdf = () => exportPdf(
            context,
            title: 'Flashcards module ${m.number}',
            build: () => flashcardsPdf(
              title: 'Flashcards · Module ${m.number}',
              chapters: chapters,
              terms: state.terms,
            ),
          );
        }
      case RevisionTab.sheets:
        detail = '${chapters.length} fiche(s)';
        if (chapters.isNotEmpty) {
          modulePdf = () => exportPdf(
            context,
            title: 'Fiches module ${m.number}',
            build: () => revisionSheetsPdf(
              title: 'Fiches de révision · Module ${m.number}',
              subtitle: m.title,
              chapters: chapters,
              terms: state.terms,
            ),
          );
        }
      case RevisionTab.maps:
        detail = 'Carte du module';
        moduleOpen = () =>
            _openMap(context, 'Module ${m.number}', moduleMindMap(m));
        modulePdf = () => _openMap(
          context,
          'Module ${m.number}',
          moduleMindMap(m),
          export: true,
        );
        moduleHtml = () => _openMap(
          context,
          'Module ${m.number}',
          moduleMindMap(m),
          html: true,
        );
    }
    return [
      const SizedBox(height: 22),
      GradientBanner(
        tone: tone,
        seed: 70 + m.number,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$emoji  $title',
              style: const TextStyle(
                fontFamily: Hand.title,
                fontSize: 24,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (m.titleEn != null) EnTag(m.titleEn!, onDark: true, size: 12),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  detail,
                  style: Hand.sansText(
                    context,
                    size: 13,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                if (moduleOpen != null)
                  _WhiteButton(
                    icon: Icons.play_arrow_rounded,
                    label: _tab == RevisionTab.flashcards
                        ? 'Réviser le module'
                        : 'Ouvrir',
                    onPressed: moduleOpen,
                  ),
                if (modulePdf != null)
                  _WhiteButton(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF du module',
                    onPressed: modulePdf,
                  ),
                if (moduleHtml != null)
                  _WhiteButton(
                    icon: Icons.web_outlined,
                    label: 'HTML du module',
                    onPressed: moduleHtml,
                  ),
              ],
            ),
          ],
        ),
      ),
      if (chapters.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 12),
          child: Text(
            'Chapitres bientôt disponibles.',
            style: Hand.sansText(context, size: 14),
          ),
        ),
      for (final (i, c) in m.chapters.indexed)
        if (c.available)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _chapterRow(context, c, '${m.number}.${i + 1}', tone),
          ),
    ];
  }

  Widget _chapterRow(
    BuildContext context,
    Chapter c,
    String number,
    Tone tone,
  ) {
    final state = AppScope.of(context);
    return switch (_tab) {
      RevisionTab.flashcards => _Row(
        tone: tone,
        emoji: '🃏',
        title: '$number  ${c.title}',
        en: c.titleEn,
        subtitle:
            '${c.flashcards.length} flashcards · '
            '${c.flashcards.where((f) => state.cards[f.id]?.mastered ?? false).length} maîtrisée(s)',
        openLabel: 'Réviser',
        onOpen: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FlashcardSessionPage(
              cardIds: c.flashcards.map((f) => f.id).toList(),
            ),
          ),
        ),
        onPdf: () => exportPdf(
          context,
          title: 'Flashcards ${c.title}',
          build: () => flashcardsPdf(
            title: 'Flashcards · ${c.title}',
            chapters: [c],
            terms: state.terms,
          ),
        ),
      ),
      RevisionTab.sheets => _Row(
        tone: tone,
        emoji: '📋',
        title: '$number  ${c.title}',
        en: c.titleEn,
        subtitle:
            '${c.revisionSheet.where((l) => !l.startsWith('# ')).length} points à retenir',
        onOpen: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RevisionSheetPage(chapter: c)),
        ),
        onPdf: () => exportPdf(
          context,
          title: 'Fiche ${c.title}',
          build: () => revisionSheetsPdf(
            title: 'Fiche de révision',
            subtitle: 'Chapitre $number',
            chapters: [c],
            terms: state.terms,
          ),
        ),
      ),
      RevisionTab.maps => _Row(
        tone: tone,
        emoji: '🧠',
        title: '$number  ${c.title}',
        en: c.titleEn,
        subtitle: '${chapterMindMap(c).size - 1} idées reliées',
        onOpen: () => _openMap(context, c.title, chapterMindMap(c)),
        onPdf: () =>
            _openMap(context, c.title, chapterMindMap(c), export: true),
        onHtml: () => _openMap(context, c.title, chapterMindMap(c), html: true),
      ),
    };
  }

  void _openMap(
    BuildContext context,
    String title,
    MindNode root, {
    bool export = false,
    bool html = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MindMapPage(
          title: title,
          root: root,
          exportOnOpen: export,
          htmlOnOpen: html,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.tone,
    required this.emoji,
    required this.title,
    this.en,
    required this.subtitle,
    required this.onOpen,
    required this.onPdf,
    this.onHtml,
    this.openLabel = 'Ouvrir',
  });

  final Tone tone;
  final String emoji;
  final String title;
  final String? en;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onPdf;

  /// Page HTML interactive (cartes mentales seulement).
  final VoidCallback? onHtml;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone, Theme.of(context).brightness);
    final paper = Paper.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 560;
    final buttons = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        FilledButton.tonalIcon(
          onPressed: onOpen,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text(openLabel),
        ),
        OutlinedButton.icon(
          onPressed: onPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('PDF'),
        ),
        if (onHtml != null)
          OutlinedButton.icon(
            onPressed: onHtml,
            icon: const Icon(Icons.web_outlined, size: 18),
            label: const Text('HTML'),
          ),
      ],
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: Hand.body,
            fontSize: 20,
            height: 1.15,
            color: paper.ink,
          ),
        ),
        if (en != null) EnTag(en!, size: 12),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Hand.sansText(context, size: 13).copyWith(color: c.ink),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: HandBox(
        fill: c.fill,
        stroke: toneBright(tone),
        strokeWidth: 2,
        seed: title.hashCode,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(child: text),
                    ],
                  ),
                  const SizedBox(height: 8),
                  buttons,
                ],
              )
            : Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(child: text),
                  const SizedBox(width: 8),
                  buttons,
                ],
              ),
      ),
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.22),
    shape: StadiumBorder(
      side: BorderSide(color: Colors.white.withValues(alpha: 0.75)),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontFamily: Hand.sans,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
