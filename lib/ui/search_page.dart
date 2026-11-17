import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../data/progress_store.dart';
import '../logic/search.dart';
import '../models/content.dart';
import 'bilingual.dart';
import 'find_highlight.dart';
import 'chapter_page.dart';
import 'exam_prep_page.dart';
import 'quiz_page.dart';
import 'revision_sheet_page.dart';
import 'lesson_page.dart';
import 'mind_map_page.dart';
import 'history_list.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/note_box.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Recherche globale : glossaire, chapitres, leçons, flashcards et cartes
/// mentales, en français comme en anglais.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

/// Termes souvent rencontrés en anglais dans les supports officiels.
const _suggestions = [
  'risk appetite',
  'separation of duties',
  'SIEM',
  'PKI',
  'zero-day',
  'IPsec',
  'least privilege',
  'CVSS',
];

class _SearchPageState extends State<SearchPage> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  SearchKind? _filter;
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.read(context);
  }

  @override
  void dispose() {
    // En quittant la recherche, on garde la dernière recherche faite.
    _remember();
    _controller.dispose();
    super.dispose();
  }

  /// Ajoute la recherche en cours à l'historique si elle donne des résultats.
  void _remember() {
    final app = _app;
    final q = _controller.text.trim();
    if (app == null || q.length < 2) return;
    if (app.search.query(q).isEmpty) return;
    app.addSearch(q);
  }

  void _search(String q) => setState(() {
    _controller.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final paper = Paper.of(context);
    final all = state.search.query(_controller.text);
    final results = _filter == null
        ? all
        : all.where((r) => r.kind == _filter).toList();
    final counts = <SearchKind, int>{};
    for (final r in all) {
      counts[r.kind] = (counts[r.kind] ?? 0) + 1;
    }
    final narrow = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: paper.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _remember(),
          style: Hand.sansText(context, size: 17),
          decoration: InputDecoration(
            hintText: 'Terme, sigle, chapitre… en français ou en anglais',
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close),
                    onPressed: () => _search(''),
                  ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              narrow ? 12 : 24,
              8,
              narrow ? 12 : 24,
              40,
            ),
            children: [
              if (_controller.text.trim().isEmpty) ...[
                if (state.searchHistory.isNotEmpty) ...[
                  HistoryList(
                    title: 'Recherches récentes',
                    entries: state.searchHistory,
                    onPick: _search,
                    onRemove: state.removeSearch,
                    onClear: state.clearSearches,
                  ),
                  const SizedBox(height: 16),
                ],
                NoteBox(
                  tone: Tone.yellow,
                  emoji: '🔎',
                  label: 'Retrouver un terme',
                  sticky: true,
                  child: Text(
                    'Tapez un mot vu dans le support officiel, même en anglais : '
                    'la recherche parcourt le glossaire, les titres des chapitres '
                    'et des leçons, les flashcards et les cartes mentales. Les '
                    'accents et les majuscules sont ignorés.',
                    style: Hand.noteText(context),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Exemples :', style: Hand.sansText(context, size: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _suggestions)
                      ActionChip(label: Text(s), onPressed: () => _search(s)),
                  ],
                ),
              ] else ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text('Tout (${all.length})'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    for (final k in SearchKind.values)
                      if ((counts[k] ?? 0) > 0)
                        ChoiceChip(
                          label: Text('${k.emoji} ${k.label} (${counts[k]})'),
                          selected: _filter == k,
                          onSelected: (_) => setState(() => _filter = k),
                        ),
                  ],
                ),
                const SizedBox(height: 10),
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Text(
                      'Aucun résultat pour « ${_controller.text.trim()} ».\n'
                      'Essayez un mot plus court, le sigle, ou l\'autre langue.',
                      textAlign: TextAlign.center,
                      style: Hand.bodyText(context),
                    ),
                  ),
                for (final r in results)
                  _ResultTile(
                    result: r,
                    query: _controller.text,
                    onOpen: _remember,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.result,
    required this.query,
    required this.onOpen,
  });

  final SearchResult result;
  final String query;

  /// Appelé à l'ouverture d'un résultat (pour l'historique).
  final VoidCallback onOpen;

  Tone get _tone => switch (result.kind) {
    SearchKind.term => Tone.turquoise,
    SearchKind.chapter => Tone.blue,
    SearchKind.lesson => Tone.violet,
    SearchKind.section => Tone.orange,
    SearchKind.flashcard => Tone.pink,
    SearchKind.mindNode => Tone.green,
    SearchKind.sheet => Tone.yellow,
    SearchKind.question => Tone.red,
    SearchKind.prep => Tone.violet,
  };

  void _open(BuildContext context) {
    onOpen();
    final library = AppScope.read(context).library;
    final chapter = result.chapterId == null
        ? null
        : library.chapter(result.chapterId!);
    switch (result.kind) {
      case SearchKind.term:
        _showTerm(
          context,
          library.glossary.firstWhere((t) => t.id == result.termId),
        );
      case SearchKind.chapter:
        if (chapter!.available) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChapterPage(chapterId: chapter.id),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ce chapitre arrive dans une prochaine mise à jour.',
              ),
            ),
          );
        }
      case SearchKind.lesson || SearchKind.section:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonPage(
              lesson: chapter!.lessons.firstWhere(
                (l) => l.id == result.lessonId,
              ),
              find: result.kind == SearchKind.section ? query.trim() : null,
              focusBlock: result.blockIndex,
            ),
          ),
        );
      case SearchKind.flashcard:
        _showCard(
          context,
          chapter!.flashcards.firstWhere((f) => f.id == result.flashcardId),
        );
      case SearchKind.mindNode:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MindMapPage(
              title: chapter!.title,
              root: chapterMindMap(chapter),
            ),
          ),
        );
      case SearchKind.sheet:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RevisionSheetPage(chapter: chapter!),
          ),
        );
      case SearchKind.question:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuizPage(
              config: QuizConfig(
                mode: SessionMode.practice,
                title: chapter!.title,
                questions: [
                  chapter.questions.firstWhere(
                    (q) => q.id == result.questionId,
                  ),
                ],
                chapterId: chapter.id,
              ),
            ),
          ),
        );
      case SearchKind.prep:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrepQuizPage(
              title: 'Préparation examen',
              questions: [
                library.examPrep.questions.firstWhere(
                  (q) => q.id == result.questionId,
                ),
              ],
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = toneColors(_tone, Theme.of(context).brightness);
    final paper = Paper.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(context),
        child: HandBox(
          fill: paper.page,
          stroke: toneBright(_tone),
          strokeWidth: 1.8,
          seed: result.title.hashCode,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.kind.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: TextStyle(
                        fontFamily: Hand.body,
                        fontSize: 20,
                        height: 1.15,
                        color: paper.ink,
                      ),
                    ),
                    if (result.en != null) ...[
                      const SizedBox(height: 2),
                      EnTag(result.en!, size: 13),
                    ],
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: highlightSpans(
                          result.subtitle,
                          result.subtitle.startsWith('«')
                              ? findWords(query)
                              : const [],
                          highlightStyle(context),
                        ),
                      ),
                      maxLines: result.subtitle.startsWith('«') ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Hand.sansText(
                        context,
                        size: 13,
                      ).copyWith(color: paper.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Sticker(text: result.kind.label, tone: _tone),
              Icon(Icons.chevron_right, color: c.ink),
            ],
          ),
        ),
      ),
    );
  }
}

void _showTerm(BuildContext context, GlossaryTerm t) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.acronym == null ? t.termFr : '${t.acronym} · ${t.termFr}',
              style: Hand.subtitle(context, Tone.blue),
            ),
            const SizedBox(height: 4),
            EnTag(t.termEn, size: 15),
            const SizedBox(height: 12),
            SelectableText(t.definition, style: Hand.bodyText(context)),
            const SizedBox(height: 10),
            Text('Exemple : ${t.example}', style: Hand.noteText(context)),
          ],
        ),
      ),
    ),
  );
}

void _showCard(BuildContext context, Flashcard f) {
  final terms = AppScope.read(context).terms;
  final en = terms.englishFor(f.front) ?? terms.englishFor(f.concept);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.front, style: Hand.subtitle(context, Tone.pink)),
            if (en != null) ...[const SizedBox(height: 4), EnTag(en)],
            const SizedBox(height: 12),
            SelectableText(f.back, style: Hand.bodyText(context)),
          ],
        ),
      ),
    ),
  );
}

/// Bouton loupe présent dans la barre de chaque page.
class SearchAction extends StatelessWidget {
  const SearchAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Rechercher',
    icon: const Icon(Icons.search),
    onPressed: () =>
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SearchPage())),
  );
}
