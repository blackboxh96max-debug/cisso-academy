import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../export/pdf_export.dart';
import '../export/pdf_save.dart';
import '../models/content.dart';
import '../logic/study_groups.dart';
import 'bilingual.dart';
import 'course_view_bar.dart';
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

  /// Rang du module affiché dans la vue, ou `null` pour tous.
  int? _group;

  /// Vue pour laquelle [_group] a été choisi.
  CourseView? _groupView;

  /// Modules dépliés (par rang) ; tout est replié au départ.
  final _open = <int>{};

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final library = state.library;
    final view = currentView(state);
    if (_groupView != view) {
      _groupView = view;
      _group = null;
      _open.clear();
    }
    final all = studyGroups(library, view);
    final groups = all
        .where((g) => _group == null || g.index == _group)
        .toList();
    final locked = library.chapters.where((c) => !c.available).length;

    return NotebookPage(
      title: 'Révisions',
      children: [
        Text(
          'Révisez avec les flashcards, les fiches et les cartes mentales, '
          'chapitre par chapitre ou module entier, dans la vue choisie. Chaque '
          'support se télécharge en PDF pour l\'imprimer ou le lire hors de '
          'l\'application.',
          style: Hand.bodyText(context),
        ),
        const SizedBox(height: 14),
        const CourseViewSelector(),
        if (view == CourseView.mile2) ...[
          const SizedBox(height: 8),
          Text(
            'Vue du livre MILE2 : sous chaque module du livre, les chapitres '
            'de l\'application qui traitent ses sections. Un chapitre peut '
            'donc apparaître sous plusieurs modules.',
            style: Hand.sansText(
              context,
              size: 13,
            ).copyWith(color: Paper.of(context).inkSoft),
          ),
        ],
        const SizedBox(height: 12),
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
              selected: _group == null,
              onSelected: (_) => setState(() => _group = null),
            ),
            for (final g in all)
              ChoiceChip(
                label: Text('${groupStyle(g).$2} ${g.label}'),
                selected: _group == g.index,
                onSelected: (_) => setState(() {
                  _group = g.index;
                  _open.add(g.index);
                }),
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
        if (_tab == RevisionTab.maps && _group == null)
          _Row(
            tone: Tone.pink,
            emoji: '🎓',
            title: 'Toute la formation',
            subtitle:
                '${all.length} modules, '
                '${library.domains.length} domaines de l\'examen',
            onOpen: () => _openMap(
              context,
              'Toute la formation',
              courseMindMap(library, view: view),
            ),
            onPdf: () => _openMap(
              context,
              'Toute la formation',
              courseMindMap(library, view: view),
              export: true,
            ),
            onHtml: () => _openMap(
              context,
              'Toute la formation',
              courseMindMap(library, view: view),
              html: true,
            ),
          ),
        const SizedBox(height: 6),
        ExpandAllBar(
          onExpandAll: () =>
              setState(() => _open.addAll(groups.map((g) => g.index))),
          onCollapseAll: () => setState(_open.clear),
        ),
        for (final g in groups) ..._moduleSection(context, g),
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

  List<Widget> _moduleSection(BuildContext context, StudyGroup g) {
    final state = AppScope.of(context);
    final library = state.library;
    final (tone, emoji) = groupStyle(g);
    final chapters = g.availableChapters;
    final title = g.fullTitle;
    final open = _open.contains(g.index);
    VoidCallback? moduleOpen;
    VoidCallback? modulePdf;
    VoidCallback? moduleHtml;
    String detail;
    switch (_tab) {
      case RevisionTab.flashcards:
        final ids = [
          for (final c in chapters) ...c.flashcards.map((f) => f.id),
        ];
        detail = '${ids.length} flashcards · ${chapters.length} chapitre(s)';
        if (ids.isNotEmpty) {
          moduleOpen = () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FlashcardSessionPage(cardIds: ids),
            ),
          );
          modulePdf = () => exportPdf(
            context,
            title: 'Flashcards ${g.label}',
            build: () => flashcardsPdf(
              title: 'Flashcards · ${g.label}',
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
            title: 'Fiches ${g.label}',
            build: () => revisionSheetsPdf(
              title: 'Fiches de révision · ${g.label}',
              subtitle: g.title,
              chapters: chapters,
              terms: state.terms,
            ),
          );
        }
      case RevisionTab.maps:
        detail = g.outline != null
            ? 'Carte du module · ${g.outline!.sections.length} sections'
            : 'Carte du module';
        final root = groupMindMap(library, g);
        moduleOpen = () => _openMap(context, g.label, root);
        modulePdf = () => _openMap(context, g.label, root, export: true);
        moduleHtml = () => _openMap(context, g.label, root, html: true);
    }
    return [
      const SizedBox(height: 22),
      GradientBanner(
        tone: tone,
        seed: 70 + g.index,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: open,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  if (!_open.remove(g.index)) _open.add(g.index);
                }),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$emoji  $title',
                            style: TextStyle(
                              fontFamily: Hand.title,
                              fontSize: Hand.tsize(24),
                              height: 1.1,
                              fontWeight: Hand.titleWeight,
                              color: Colors.white,
                            ),
                          ),
                          if (g.titleEn != null)
                            EnTag(g.titleEn!, onDark: true, size: 12),
                        ],
                      ),
                    ),
                    ExpandChevron(open: open),
                  ],
                ),
              ),
            ),
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
      if (open && chapters.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 12),
          child: Text(
            'Chapitres bientôt disponibles.',
            style: Hand.sansText(context, size: 14),
          ),
        ),
      if (open)
        for (final c in chapters)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _chapterRow(
              context,
              c,
              chapterNumber(library, c),
              moduleStyle(library.module(c.moduleId).number).$1,
            ),
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
            fontSize: Hand.bsize(20),
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
              style: TextStyle(
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
