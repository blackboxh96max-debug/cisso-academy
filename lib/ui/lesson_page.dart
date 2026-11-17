import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../logic/quiz_engine.dart';
import '../models/content.dart';
import 'notebook/diagrams.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/note_box.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import '../logic/terms.dart';
import '../logic/search.dart';
import '../logic/study_groups.dart';
import 'assistant_page.dart';
import 'bilingual.dart';
import 'course_view_bar.dart';
import 'find_highlight.dart';
import 'outline_view.dart';
import 'search_page.dart';
import 'term_links.dart';

/// Leçon présentée comme une page de cahier manuscrit.
///
/// Sur grand écran, un sommaire et les objectifs s'affichent dans une colonne
/// à gauche de la page.
class LessonPage extends StatefulWidget {
  const LessonPage({
    super.key,
    required this.lesson,
    this.find,
    this.focusBlock,
  });

  final Lesson lesson;

  /// Texte à chercher dès l'ouverture (venu de la recherche globale).
  final String? find;

  /// Bloc à montrer dès l'ouverture.
  final int? focusBlock;

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  late bool _finding = (widget.find ?? '').trim().isNotEmpty;
  late final _findController = TextEditingController(text: widget.find ?? '');
  final _findFocus = FocusNode();
  late final _blockKeys = [for (final _ in widget.lesson.blocks) GlobalKey()];

  /// Position dans la liste des blocs trouvés (-1 : aucun encore montré).
  int _current = -1;

  Lesson get lesson => widget.lesson;

  List<String> get _words =>
      _finding ? findWords(_findController.text) : const [];

  /// Blocs de la leçon qui contiennent tous les mots cherchés.
  List<int> get _hits {
    final words = _words;
    if (words.isEmpty) return const [];
    return [
      for (final (i, b) in lesson.blocks.indexed)
        if (containsAllWords(
          blockSearchText(b).whereType<String>().join(' '),
          words,
        ))
          i,
    ];
  }

  @override
  void initState() {
    super.initState();
    if (widget.focusBlock != null || _finding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final hits = _hits;
        final target = widget.focusBlock ?? (hits.isEmpty ? null : hits.first);
        if (target == null) return;
        final i = hits.indexWhere((h) => h >= target);
        setState(() => _current = i);
        _reveal(i >= 0 ? hits[i] : target);
      });
    }
  }

  @override
  void dispose() {
    _findController.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  void _reveal(int block) {
    final target = _blockKeys[block].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _go(int delta) {
    final hits = _hits;
    if (hits.isEmpty) return;
    final next = _current < 0
        ? (delta > 0 ? 0 : hits.length - 1)
        : (_current + delta) % hits.length;
    setState(() => _current = next);
    _reveal(hits[next]);
  }

  void _toggleFind() {
    setState(() {
      _finding = !_finding;
      _current = -1;
    });
    if (_finding) _findFocus.requestFocus();
  }

  PreferredSizeWidget _findBar(BuildContext context) {
    final hits = _hits;
    final typed = _findController.text.trim().isNotEmpty;
    final status = !typed
        ? ''
        : hits.isEmpty
        ? 'Aucun passage'
        : _current < 0
        ? '${hits.length} passage${hits.length > 1 ? 's' : ''}'
        : '${_current + 1}/${hits.length}';
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('lesson-find'),
                controller: _findController,
                focusNode: _findFocus,
                autofocus: (widget.find ?? '').isEmpty,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Chercher dans cette leçon',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _current = -1),
                onSubmitted: (_) {
                  _go(1);
                  _findFocus.requestFocus();
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(status, key: const Key('lesson-find-status')),
            IconButton(
              tooltip: 'Passage précédent',
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: hits.isEmpty ? null : () => _go(-1),
            ),
            IconButton(
              tooltip: 'Passage suivant',
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: hits.isEmpty ? null : () => _go(1),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final read = state.readLessons.contains(lesson.id);
    final chapter = state.library.chapters.firstWhere(
      (c) => c.lessons.any((l) => l.id == lesson.id),
    );
    final module = state.library.module(chapter.moduleId);
    final (moduleTone, moduleEmoji) = moduleStyle(module.number);
    // Numérotation dans la vue choisie : rang de la leçon dans son module
    // (livre MILE2 ou ORSYS), le même ordre que « leçon suivante ».
    final place = lessonPlace(state.library, currentView(state), lesson.id);
    final (
      placeTone,
      placeEmoji,
    ) = place.groupIndex != null && currentView(state) == CourseView.mile2
        ? (
            outlineTone(place.groupIndex!),
            place.label == 'Prérequis' ? '🧰' : '📘',
          )
        : (moduleTone, moduleEmoji);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1100;
    final paper = Paper.of(context);
    final plan = _termPlan(
      state.terms,
      lesson,
      termHomes(state.library, state.terms),
    );
    // Leçons de toute la formation, dans l'ordre de la vue choisie (livre
    // MILE2 ou 5 modules) : on enchaîne sans repasser par le menu.
    final course = state.lessonOrder;
    final position = course.indexWhere((l) => l.id == lesson.id);
    final previous = position > 0 ? course[position - 1] : null;
    final next = position >= 0 && position < course.length - 1
        ? course[position + 1]
        : null;

    final page = NotebookPaper(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          width < 600 ? 22 : 64,
          20,
          width < 600 ? 16 : 36,
          40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Sticker(text: '$placeEmoji ${place.label}', tone: placeTone),
                Sticker(
                  text: 'Leçon ${place.number}/${place.total}',
                  tone: Tone.yellow,
                ),
                Sticker(
                  text: 'Chapitre ${chapterNumber(state.library, chapter)}',
                  tone: Tone.blue,
                ),
                Sticker(text: '⏱ ${lesson.minutes} min', tone: Tone.green),
              ],
            ),
            if (place.section != null) ...[
              const SizedBox(height: 6),
              Text(
                '📍 ${place.section}',
                style: Hand.sansText(
                  context,
                  size: 13,
                ).copyWith(color: paper.inkSoft, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            _LessonHeader(lesson: lesson, tone: moduleTone),
            if (!wide) _Objectives(lesson: lesson),
            for (final (i, block) in lesson.blocks.indexed)
              KeyedSubtree(
                key: _blockKeys[i],
                child: NotebookBlock(block, seed: i + 3),
              ),
            if (lesson.references.isNotEmpty) _References(lesson.references),
            const SizedBox(height: 28),
            Center(
              child: read
                  ? const Sticker(text: '✔ Leçon terminée', tone: Tone.green)
                  : FilledButton.icon(
                      onPressed: () async {
                        await AppScope.read(context).markLessonRead(lesson.id);
                        if (!context.mounted) return;
                        if (next != null) {
                          openLessonInPlace(context, next);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: Text(
                        next != null
                            ? 'J\'ai terminé : leçon suivante'
                            : 'J\'ai terminé cette leçon',
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            LessonNavigation(previous: previous, next: next),
          ],
        ),
      ),
    );

    final shadowedPage = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: page,
    );

    return Scaffold(
      backgroundColor: paper.background,
      appBar: AppBar(
        title: Text(
          '${place.label} · ${place.title}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Leçon précédente',
            icon: const Icon(Icons.chevron_left),
            onPressed: previous == null
                ? null
                : () => openLessonInPlace(context, previous),
          ),
          IconButton(
            tooltip: 'Leçon suivante',
            icon: const Icon(Icons.chevron_right),
            onPressed: next == null
                ? null
                : () => openLessonInPlace(context, next),
          ),
          IconButton(
            tooltip: _finding
                ? 'Fermer la recherche dans la leçon'
                : 'Chercher dans la leçon',
            icon: Icon(_finding ? Icons.search_off : Icons.find_in_page),
            onPressed: _toggleFind,
          ),
          const AssistantAction(),
          const SearchAction(),
        ],
        bottom: _finding ? _findBar(context) : null,
      ),
      body: FindHighlight(
        words: _words,
        child: TermPlan(
          plan: plan,
          child: TermLinks(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: width < 600 ? 0 : 20,
                vertical: width < 600 ? 0 : 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1240 : 880),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 300,
                              child: _SidePanel(lesson: lesson),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: shadowedPage),
                          ],
                        )
                      : shadowedPage,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Remplace la leçon affichée par une autre, sans empiler les pages : le
/// bouton retour ramène toujours à l'écran d'où l'on est venu.
void openLessonInPlace(BuildContext context, Lesson lesson) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => LessonPage(lesson: lesson)),
  );
}

/// Boutons « précédente » et « suivante » en bas de la leçon, avec le titre
/// de la leçon visée.
class LessonNavigation extends StatelessWidget {
  const LessonNavigation({super.key, this.previous, this.next});

  final Lesson? previous;
  final Lesson? next;

  @override
  Widget build(BuildContext context) {
    Widget card(Lesson l, {required bool forward}) => Card(
      child: InkWell(
        onTap: () => openLessonInPlace(context, l),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (!forward) const Icon(Icons.arrow_back),
              if (!forward) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: forward
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      forward ? 'Leçon suivante' : 'Leçon précédente',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      l.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: forward ? TextAlign.end : TextAlign.start,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (forward) const SizedBox(width: 8),
              if (forward) const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final items = [
          if (previous != null) card(previous!, forward: false),
          if (next != null) card(next!, forward: true),
        ];
        if (items.isEmpty) return const SizedBox.shrink();
        if (constraints.maxWidth < 520 || items.length == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items,
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: items[0]),
            const SizedBox(width: 12),
            Expanded(child: items[1]),
          ],
        );
      },
    );
  }
}

/// Repère, dans l'ordre de lecture, les termes du glossaire de la leçon :
/// - l'équivalent anglais est ajouté à la première apparition du terme dans
///   la leçon ;
/// - le terme est cliquable à sa première apparition dans chaque partie (entre
///   deux titres), sauf s'il est défini dans cette leçon même.
Map<Object, List<TermMatch>> _termPlan(
  TermIndex terms,
  Lesson lesson,
  Map<String, TermHome> homes,
) {
  final translated = <String>{};
  final linked = <String>{};
  final plan = <Object, List<TermMatch>>{};
  List<TermMatch> pick(String text) => [
    for (final m in terms.findLinks(text))
      if (m.copyWith(
            translate: m.translate && translated.add(m.term.id),
            link:
                homes[m.term.id]?.lesson.id != lesson.id &&
                linked.add(m.term.id),
          )
          case final k when k.translate || k.link)
        k,
  ];
  for (final b in lesson.blocks) {
    switch (b.type) {
      case BlockType.heading:
        linked.clear();
      case BlockType.text ||
          BlockType.definition ||
          BlockType.important ||
          BlockType.socCase ||
          BlockType.trainerNote ||
          BlockType.risk ||
          BlockType.practice:
        if (b.text != null) plan[b] = pick(b.text!);
        for (final (i, item) in b.items.indexed) {
          plan[(b, i)] = pick(item);
        }
      default:
        break;
    }
  }
  return plan;
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({required this.lesson, required this.tone});

  final Lesson lesson;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final title = HandUnderline(
      color: toneColors(Tone.orange, Theme.of(context).brightness).ink,
      child: Text(
        lesson.title,
        style: Hand.chapterTitle(
          context,
          color: toneColors(tone, Theme.of(context).brightness).ink,
        ),
      ),
    );
    if (lesson.illustration == null) return title;
    final art = Semantics(
      label: lesson.illustrationAlt,
      image: true,
      child: SvgPicture.asset(
        lesson.illustration!,
        height: 150,
        excludeFromSemantics: true,
      ),
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 560
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                art,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: art),
                const SizedBox(height: 8),
                title,
              ],
            ),
    );
  }
}

class _Objectives extends StatelessWidget {
  const _Objectives({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return NoteBox(
      tone: Tone.blue,
      emoji: '🎯',
      label: 'Objectifs de la leçon',
      seed: 2,
      child: HandBullets(lesson.objectives, bullet: '☐'),
    );
  }
}

/// Colonne latérale (grand écran) : objectifs et sommaire.
class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final headings = lesson.blocks
        .where((b) => b.type == BlockType.heading)
        .map((b) => b.text ?? '')
        .toList();
    final paper = Paper.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Objectives(lesson: lesson),
        const SizedBox(height: 12),
        NoteBox(
          tone: Tone.yellow,
          emoji: '🗂️',
          label: 'Sommaire',
          sticky: true,
          seed: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, h) in headings.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${i + 1}. $h',
                    style: TextStyle(
                      fontFamily: Hand.body,
                      fontSize: 18,
                      color: paper.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _References extends StatelessWidget {
  const _References(this.references);

  final List<Reference> references;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📚 Ressources',
            style: Hand.subtitle(context, Tone.blue).copyWith(fontSize: 26),
          ),
          const SizedBox(height: 6),
          for (final r in references)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: r.title,
                      style: Hand.sansText(context, size: 14),
                    ),
                    if (r.url != null)
                      TextSpan(
                        text: '\n${r.url} (en ligne)',
                        style: Hand.sansText(
                          context,
                          size: 12.5,
                        ).copyWith(color: paper.inkSoft),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un bloc de leçon dans le style cahier.
class NotebookBlock extends StatelessWidget {
  const NotebookBlock(this.block, {super.key, this.seed = 7});

  final LessonBlock block;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final source = block.kind == null
        ? null
        : Sticker(text: block.kind!.label, tone: _sourceTone(block.kind!));
    final body = Hand.bodyText(context);
    final english = block.type == BlockType.definition && block.title != null
        ? AppScope.of(context).terms.englishFor(block.title!)
        : null;

    switch (block.type) {
      case BlockType.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 30),
          child: HandUnderline(
            color: toneColors(Tone.yellow, brightness).ink,
            seed: seed,
            child: FindText(
              block.text ?? '',
              style: Hand.subtitle(context, Tone.blue),
            ),
          ),
        );
      case BlockType.text:
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BilingualText(block.text ?? '', planKey: block, style: body),
              if (source != null) ...[const SizedBox(height: 6), source],
            ],
          ),
        );
      case BlockType.bullets:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: HandBullets(block.items),
        );
      case BlockType.definition:
        return NoteBox(
          tone: Tone.blue,
          label: 'Définition',
          title: block.title,
          trailing: source,
          seed: seed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (english != null) ...[
                EnTag(english),
                const SizedBox(height: 6),
              ],
              BilingualText(
                block.text ?? '',
                planKey: block,
                style: Hand.definition(context),
              ),
            ],
          ),
        );
      case BlockType.socCase:
        return NoteBox(
          tone: Tone.turquoise,
          label: 'Exemple professionnel',
          title: block.title,
          trailing: source,
          seed: seed,
          child: BilingualText(
            block.text ?? '',
            planKey: block,
            style: body.copyWith(fontSize: 19),
          ),
        );
      case BlockType.viewpoints:
        return NoteBox(
          tone: Tone.violet,
          emoji: '👥',
          label: block.title ?? 'Points de vue',
          seed: seed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final item in block.items) _Viewpoint(item)],
          ),
        );
      case BlockType.table:
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: HandBox(
            padding: const EdgeInsets.all(10),
            seed: seed,
            child: _HandTable(rows: block.rows),
          ),
        );
      case BlockType.steps:
        return NoteBox(
          tone: Tone.blue,
          emoji: '🖼️',
          label: 'Schéma explicatif',
          title: block.title,
          seed: seed,
          child: _StepsDiagram(block.items),
        );
      case BlockType.pitfalls:
        return NoteBox(
          tone: Tone.pink,
          label: 'Attention à l\'examen',
          seed: seed,
          child: HandBullets(block.items, bullet: '✗'),
        );
      case BlockType.summary:
        return NoteBox(
          tone: Tone.orange,
          label: block.title ?? 'À retenir',
          seed: seed,
          child: HandBullets(block.items, bullet: '★'),
        );
      case BlockType.trainerNote:
        return NoteBox(
          tone: Tone.yellow,
          emoji: '✏️',
          label: block.title ?? 'Note du formateur',
          sticky: true,
          seed: seed,
          child: BilingualText(
            block.text ?? '',
            planKey: block,
            style: Hand.noteText(context),
            selectable: false,
          ),
        );
      case BlockType.memo:
        return NoteBox(
          tone: Tone.yellow,
          label: block.title ?? 'Mémorisation',
          sticky: true,
          seed: seed,
          child: FindText(
            block.text ?? '',
            style: Hand.noteText(context).copyWith(fontSize: 19),
          ),
        );
      case BlockType.important:
        return NoteBox(
          tone: Tone.violet,
          label: block.title ?? 'Important',
          trailing: source,
          seed: seed,
          child: BilingualText(block.text ?? '', planKey: block, style: body),
        );
      case BlockType.practice:
        return NoteBox(
          tone: Tone.green,
          label: block.title ?? 'Bonne pratique',
          trailing: source,
          seed: seed,
          child: block.items.isNotEmpty
              ? HandBullets(
                  block.items,
                  bullet: '✓',
                  itemSpan: (i, item, style) => bilingualSpan(
                    context,
                    item,
                    TermPlan.matchesFor(context, (block, i)),
                    style,
                  ),
                )
              : BilingualText(block.text ?? '', planKey: block, style: body),
        );
      case BlockType.risk:
        return NoteBox(
          tone: Tone.red,
          label: block.title ?? 'Risque',
          seed: seed,
          child: block.items.isNotEmpty
              ? HandBullets(
                  block.items,
                  bullet: '!',
                  itemSpan: (i, item, style) => bilingualSpan(
                    context,
                    item,
                    TermPlan.matchesFor(context, (block, i)),
                    style,
                  ),
                )
              : BilingualText(block.text ?? '', planKey: block, style: body),
        );
      case BlockType.diagram:
        return NoteBox(
          tone: Tone.blue,
          emoji: '🖼️',
          label: 'Schéma explicatif',
          title: block.title,
          seed: seed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              DiagramView(data: block.diagram!, alt: block.alt ?? ''),
              if (block.text != null) ...[
                const SizedBox(height: 10),
                FindText(
                  block.text!,
                  style: Hand.noteText(context).copyWith(fontSize: 16),
                ),
              ],
            ],
          ),
        );
      case BlockType.illustration:
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            children: [
              Semantics(
                label: block.alt,
                image: true,
                child: SvgPicture.asset(
                  block.asset!,
                  height: 200,
                  excludeFromSemantics: true,
                ),
              ),
              if (block.text != null)
                FindText(
                  block.text!,
                  textAlign: TextAlign.center,
                  style: Hand.noteText(context).copyWith(fontSize: 16),
                ),
            ],
          ),
        );
      case BlockType.miniQuiz:
        return NoteBox(
          tone: Tone.pink,
          emoji: '📝',
          label: block.title ?? 'Petit test',
          seed: seed,
          child: _MiniQuiz(block.questionIds),
        );
    }
  }
}

Tone _sourceTone(SourceKind kind) => switch (kind) {
  SourceKind.official => Tone.violet,
  SourceKind.general => Tone.blue,
  SourceKind.practice => Tone.green,
  SourceKind.example => Tone.turquoise,
};

class _Viewpoint extends StatelessWidget {
  const _Viewpoint(this.item);

  final String item;

  @override
  Widget build(BuildContext context) {
    final i = item.indexOf(':');
    final body = Hand.bodyText(context).copyWith(fontSize: 19);
    if (i < 0) return FindText(item, style: body);
    final emoji = switch (item.substring(0, i).trim().toLowerCase()) {
      final r when r.contains('rssi') => '🧭',
      final r when r.contains('soc') => '🖥️',
      final r when r.contains('audit') => '🔎',
      final r when r.contains('risk') || r.contains('risque') => '⚖️',
      _ => '💬',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$emoji  '),
            TextSpan(
              text: item.substring(0, i).trim(),
              style: body.copyWith(
                fontWeight: FontWeight.w700,
                color: toneColors(
                  Tone.violet,
                  Theme.of(context).brightness,
                ).ink,
              ),
            ),
            TextSpan(
              children: highlightSpans(
                ' : ${item.substring(i + 1).trim()}',
                FindHighlight.of(context),
                highlightStyle(context),
              ),
            ),
          ],
          style: body,
        ),
      ),
    );
  }
}

/// Étapes numérotées reliées par des flèches manuscrites.
class _StepsDiagram extends StatelessWidget {
  const _StepsDiagram(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const tones = [
      Tone.blue,
      Tone.violet,
      Tone.turquoise,
      Tone.green,
      Tone.orange,
      Tone.pink,
    ];
    return Column(
      children: [
        for (final (i, step) in items.indexed) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: toneColors(tones[i % tones.length], brightness).fill,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: toneColors(tones[i % tones.length], brightness).ink,
                    width: 2,
                  ),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontFamily: Hand.title,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: toneColors(tones[i % tones.length], brightness).ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: FindText(
                    step.replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                    style: Hand.bodyText(context).copyWith(fontSize: 19),
                  ),
                ),
              ),
            ],
          ),
          if (i < items.length - 1)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  '↓',
                  style: TextStyle(
                    fontSize: 20,
                    color: Paper.of(context).inkSoft,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Tableau du cahier : police sans-serif pour la lisibilité.
class _HandTable extends StatelessWidget {
  const _HandTable({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final paper = Paper.of(context);
    final head = toneColors(Tone.blue, Theme.of(context).brightness);
    final header = rows.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = header.length * 170.0;
        final table = Table(
          border: TableBorder.symmetric(
            inside: BorderSide(color: paper.rule, width: 1.2),
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: head.fill,
                borderRadius: BorderRadius.circular(8),
              ),
              children: [
                for (final h in header)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: FindText(
                      h,
                      style: TextStyle(
                        fontFamily: Hand.title,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: head.ink,
                      ),
                    ),
                  ),
              ],
            ),
            for (final r in rows.skip(1))
              TableRow(
                children: [
                  for (final (i, cell) in r.indexed)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: FindText(
                        cell,
                        style: i == 0
                            ? Hand.sansText(
                                context,
                                size: 14,
                              ).copyWith(fontWeight: FontWeight.w700)
                            : Hand.sansText(context, size: 14),
                      ),
                    ),
                ],
              ),
          ],
        );
        if (constraints.maxWidth >= minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: table),
        );
      },
    );
  }
}

/// Petit test de fin de leçon : correction immédiate, sans effet sur les
/// statistiques (c'est une autoévaluation).
class _MiniQuiz extends StatefulWidget {
  const _MiniQuiz(this.questionIds);

  final List<String> questionIds;

  @override
  State<_MiniQuiz> createState() => _MiniQuizState();
}

class _MiniQuizState extends State<_MiniQuiz> {
  final Map<String, Set<int>> _chosen = {};
  final Set<String> _checked = {};

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    final brightness = Theme.of(context).brightness;
    final body = Hand.bodyText(context).copyWith(fontSize: 19);
    final animate = animationsOn(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (n, id) in widget.questionIds.indexed) ...[
          Builder(
            builder: (context) {
              final q = library.question(id);
              final chosen = _chosen[id] ?? <int>{};
              final checked = _checked.contains(id);
              final ok = isAnswerCorrect(q, chosen);
              return Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${n + 1}. ${q.prompt}',
                      style: body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (q.isMultiple)
                      Text(
                        '(${q.correct.length} réponses)',
                        style: Hand.sansText(context, size: 12.5),
                      ),
                    const SizedBox(height: 6),
                    for (final (i, choice) in q.choices.indexed)
                      _MiniChoice(
                        text: choice,
                        selected: chosen.contains(i),
                        result: !checked
                            ? null
                            : q.correct.contains(i)
                            ? true
                            : chosen.contains(i)
                            ? false
                            : null,
                        onTap: checked
                            ? null
                            : () => setState(() {
                                final set = _chosen.putIfAbsent(
                                  id,
                                  () => <int>{},
                                );
                                if (q.isMultiple) {
                                  set.contains(i) ? set.remove(i) : set.add(i);
                                } else {
                                  set
                                    ..clear()
                                    ..add(i);
                                }
                              }),
                      ),
                    if (!checked)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: chosen.isEmpty
                              ? null
                              : () => setState(() => _checked.add(id)),
                          child: const Text('Vérifier'),
                        ),
                      )
                    else
                      AnimatedSize(
                        duration: animate
                            ? const Duration(milliseconds: 300)
                            : Duration.zero,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${ok ? '🎉 Bravo ! ' : '🤔 Pas tout à fait. '}${q.explanation}',
                            style: Hand.noteText(context).copyWith(
                              fontSize: 17,
                              color: ok
                                  ? toneColors(Tone.green, brightness).ink
                                  : toneColors(Tone.red, brightness).ink,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _MiniChoice extends StatelessWidget {
  const _MiniChoice({
    required this.text,
    required this.selected,
    required this.result,
    required this.onTap,
  });

  final String text;
  final bool selected;

  /// null : pas encore corrigé (ou choix neutre), true : bonne réponse, false : erreur.
  final bool? result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = Paper.of(context);
    final color = switch (result) {
      true => toneColors(Tone.green, brightness).ink,
      false => toneColors(Tone.red, brightness).ink,
      null => selected ? toneColors(Tone.blue, brightness).ink : paper.inkSoft,
    };
    final mark = switch (result) {
      true => '✔',
      false => '✘',
      null => selected ? '●' : '○',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Text(mark, style: TextStyle(fontSize: 18, color: color)),
            ),
            Expanded(
              child: Text(
                text,
                style: Hand.bodyText(
                  context,
                ).copyWith(fontSize: 18, color: result == null ? null : color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
