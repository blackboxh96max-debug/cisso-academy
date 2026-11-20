import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../logic/stats.dart';
import '../models/content.dart';
import 'chapter_page.dart';
import 'outline_view.dart';
import 'mind_map_page.dart';
import 'regulations_page.dart';
import 'risk_workshop_page.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'bilingual.dart';
import 'course_view_bar.dart';
import '../logic/study_groups.dart';

/// Programme : au choix, le livre MILE2 (11 modules + Prérequis), le
/// programme ORSYS en 5 modules tel quel, ou ce même programme enrichi de
/// tout le livre MILE2. Les leçons et la progression sont les mêmes partout.
class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key, this.focus});

  /// Rang du module choisi ailleurs, par exemple sur l'accueil, dans la vue
  /// en cours : la page déplie ce module et défile jusqu'à lui.
  final ValueNotifier<int?>? focus;

  @override
  State<CoursesPage> createState() => _CoursesPageState();

  static int _count(CourseOutline o) =>
      o.modules.fold(0, (n, m) => n + m.sections.length);

  static String _mile2Intro(CourseOutline outline) {
    final sections = outline.modules.expand((m) => m.sections);
    final missing = sections.where((s) => s.coverage == Coverage.missing);
    return 'Même découpage et même ordre que le sommaire du livre MILE2 v20 : '
        '${outline.modules.length - 1} modules et le module Prérequis, '
        '${sections.length} sections. '
        '${missing.isEmpty ? 'Toutes les sections ont une leçon.' : '${missing.length} section(s) attendent encore leur leçon.'}';
  }

  static List<Widget> _chapters(BuildContext context, StudyGroup g) {
    final state = AppScope.of(context);
    final library = state.library;
    final (tone, _) = groupStyle(g);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 14, left: 12),
        child: Text(
          g.moduleNumber != null
              ? '🎯 S\'entraîner : chapitres du module ${g.moduleNumber}'
              : '🎯 S\'entraîner : chapitres liés à ce module',
          style: Hand.sansText(
            context,
            size: 15,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      for (final c in g.chapters)
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 12),
          child: _ChapterCard(
            chapter: c,
            number: chapterNumber(library, c),
            tone: g.moduleNumber != null
                ? tone
                : moduleStyle(library.module(c.moduleId).number).$1,
            stats: state.stats.chapters
                .where((s) => s.chapter.id == c.id)
                .firstOrNull,
          ),
        ),
    ];
  }
}

class _CoursesPageState extends State<CoursesPage> {
  final _keys = List.generate(16, (_) => GlobalKey());

  /// Modules dépliés, par vue (tout est replié au départ).
  final _expanded = <CourseView?, Set<int>>{};

  Set<int> _open(CourseView? view) => _expanded.putIfAbsent(view, () => {});

  @override
  void initState() {
    super.initState();
    widget.focus?.addListener(_onFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFocus());
  }

  @override
  void didUpdateWidget(CoursesPage old) {
    super.didUpdateWidget(old);
    if (old.focus != widget.focus) {
      old.focus?.removeListener(_onFocus);
      widget.focus?.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focus?.removeListener(_onFocus);
    super.dispose();
  }

  CourseView? _view(BuildContext context) {
    final views = availableViews(AppScope.read(context).library);
    return views.isEmpty ? null : currentView(AppScope.read(context));
  }

  void _onFocus() {
    final index = widget.focus?.value;
    if (index == null || !mounted) return;
    // Le module choisi est déplié, puis amené en haut de l'écran.
    setState(() => _open(_view(context)).add(index));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = index < _keys.length ? _keys[index].currentContext : null;
      if (target == null) return;
      widget.focus?.value = null;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _toggle(CourseView? view, int i) => setState(() {
    final open = _open(view);
    if (!open.remove(i)) open.add(i);
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final library = state.library;
    final view = availableViews(library).isEmpty ? null : currentView(state);
    final groups = studyGroups(library, view ?? CourseView.orsysPlus);
    final open = _open(view);
    return NotebookPage(
      title: 'Cours',
      children: [
        const CourseViewSelector(key: Key('course-view')),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: GradientButton(
            emoji: '🧠',
            label: 'Carte mentale de toute la formation',
            from: Tone.violet,
            to: Tone.pink,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MindMapPage(
                  title: 'Toute la formation',
                  root: courseMindMap(library, view: view),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GradientButton(
                key: const Key('open-regulations'),
                emoji: '📜',
                label: 'Textes et normes',
                expand: true,
                from: Tone.orange,
                to: Tone.pink,
                onPressed: library.regulations.sheets.isEmpty
                    ? null
                    : () => openRegulations(context),
              ),
            ),
            if (library.riskWorkshop.scenarios.isNotEmpty) ...[
              const SizedBox(width: 10),
              Expanded(
                child: GradientButton(
                  key: const Key('open-risk-workshop'),
                  emoji: '🎯',
                  label: 'Atelier risques',
                  expand: true,
                  from: Tone.red,
                  to: Tone.orange,
                  onPressed: () => openRiskWorkshop(context),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ExpandAllBar(
          onExpandAll: () => setState(
            () => open.addAll([for (var i = 0; i < groups.length; i++) i]),
          ),
          onCollapseAll: () => setState(open.clear),
        ),
        switch (view) {
          CourseView.mile2 => OutlineView(
            outline: library.mile2Outline,
            moduleKeys: _keys,
            expanded: open,
            onToggle: (i) => _toggle(view, i),
            intro: CoursesPage._mile2Intro(library.mile2Outline),
            trailing: (i) => i < groups.length && groups[i].chapters.isNotEmpty
                ? CoursesPage._chapters(context, groups[i])
                : const [],
          ),
          CourseView.orsys => OutlineView(
            outline: library.orsysOutline,
            moduleKeys: _keys,
            expanded: open,
            onToggle: (i) => _toggle(view, i),
            sectionWord: 'Thème',
            toneOf: (i) => moduleStyle(i + 1).$1,
            intro:
                'Le programme ORSYS tel quel : ses '
                '${library.orsysOutline.modules.length} modules et ses '
                '${CoursesPage._count(library.orsysOutline)} thèmes, dans le même ordre, '
                'avec les leçons qui les traitent. Rien n\'est ajouté.',
          ),
          CourseView.orsysPlus => OutlineView(
            outline: library.orsysPlusOutline,
            moduleKeys: _keys,
            expanded: open,
            onToggle: (i) => _toggle(view, i),
            sectionWord: 'Thème',
            toneOf: (i) => moduleStyle(i + 1).$1,
            intro:
                'Les 5 modules ORSYS, enrichis de tout le contenu du livre '
                'MILE2 : les thèmes et leçons ajoutés portent l\'étiquette '
                '« Livre MILE2 » ou « + MILE2 ». Sous chaque module, ses '
                'chapitres d\'entraînement (questions, flashcards, fiche) ; '
                'un chapitre est validé à 80 %.',
            trailing: (i) => i < groups.length
                ? CoursesPage._chapters(context, groups[i])
                : const [],
          ),
          null => _ChapterList(
            groups: groups,
            moduleKeys: _keys,
            expanded: open,
            onToggle: (i) => _toggle(view, i),
          ),
        },
      ],
    );
  }
}

/// Repli sans sommaire : les modules et leurs chapitres.
class _ChapterList extends StatelessWidget {
  const _ChapterList({
    required this.groups,
    required this.moduleKeys,
    required this.expanded,
    required this.onToggle,
  });

  final List<StudyGroup> groups;
  final List<GlobalKey> moduleKeys;
  final Set<int> expanded;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups) ...[
          const SizedBox(height: 22),
          InkWell(
            key: g.index < moduleKeys.length ? moduleKeys[g.index] : null,
            borderRadius: BorderRadius.circular(18),
            onTap: () => onToggle(g.index),
            child: _ModuleBanner(
              module: state.library.modules[g.index],
              progress: state.stats.moduleProgress(
                state.library.modules[g.index].id,
              ),
              open: expanded.contains(g.index),
            ),
          ),
          if (expanded.contains(g.index)) ...CoursesPage._chapters(context, g),
        ],
      ],
    );
  }
}

class _ModuleBanner extends StatelessWidget {
  const _ModuleBanner({
    required this.module,
    required this.progress,
    required this.open,
  });

  final Module module;
  final double progress;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final (tone, emoji) = moduleStyle(module.number);
    final available = module.chapters.where((c) => c.available).length;
    return GradientBanner(
      tone: tone,
      seed: 40 + module.number,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Module ${module.number}',
                      style: TextStyle(
                        fontFamily: Hand.title,
                        fontSize: Hand.tsize(30),
                        height: 1,
                        fontWeight: Hand.titleWeight,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      module.title,
                      style: Hand.sansText(context, size: 15).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (module.titleEn != null)
                      EnTag(module.titleEn!, onDark: true, size: 12),
                  ],
                ),
              ),
              ExpandChevron(open: open),
            ],
          ),
          const SizedBox(height: 10),
          HandProgress(value: progress, onDark: true),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${(progress * 100).round()} % · $available/${module.chapters.length} '
                'chapitre(s) disponible(s)',
                style: Hand.sansText(
                  context,
                  size: 12.5,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.22),
                shape: StadiumBorder(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MindMapPage(
                        title: 'Module ${module.number}',
                        root: moduleMindMap(module),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Text(
                      '🧠 Carte du module',
                      style: TextStyle(
                        fontFamily: Hand.sans,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.number,
    required this.tone,
    required this.stats,
  });

  final Chapter chapter;
  final String number;
  final Tone tone;
  final ChapterStats? stats;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final paper = Paper.of(context);
    final c = toneColors(tone, Theme.of(context).brightness);
    final open = chapter.available;
    final domains = chapter.domainIds
        .map((d) => state.library.domain(d).nameFr)
        .join(', ');

    final badge = Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: open
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.ink, toneBright(tone)],
              )
            : null,
        color: open ? null : paper.rule,
      ),
      child: Text(
        number,
        style: TextStyle(
          fontFamily: Hand.title,
          fontSize: Hand.tsize(22),
          fontWeight: Hand.titleWeight,
          color: open ? Colors.white : paper.inkSoft,
        ),
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chapter.title,
          style: TextStyle(
            fontFamily: Hand.body,
            fontSize: Hand.bsize(21),
            height: 1.2,
            color: open ? paper.ink : paper.inkSoft,
          ),
        ),
        if (chapter.titleEn != null) ...[
          const SizedBox(height: 2),
          EnTag(chapter.titleEn!, size: 12),
        ],
        const SizedBox(height: 6),
        if (open) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Sticker(
                text: '📖 ${chapter.lessons.length} leçons',
                tone: Tone.blue,
              ),
              Sticker(
                text: '❓ ${chapter.questions.length} questions',
                tone: Tone.violet,
              ),
              Sticker(
                text: '🃏 ${chapter.flashcards.length} flashcards',
                tone: Tone.turquoise,
              ),
              if (stats != null) statusSticker(stats!.status),
            ],
          ),
          const SizedBox(height: 8),
          HandProgress(value: stats?.progress ?? 0, tone: tone, height: 8),
        ] else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Sticker(text: '🔒 Bientôt disponible', tone: Tone.yellow),
              if (domains.isNotEmpty)
                Text(
                  'Domaine : $domains',
                  style: Hand.sansText(
                    context,
                    size: 12.5,
                  ).copyWith(color: paper.inkSoft),
                ),
            ],
          ),
      ],
    );

    final card = HandBox(
      fill: open ? c.fill : paper.page,
      stroke: open ? toneBright(tone) : paper.inkSoft.withValues(alpha: 0.45),
      strokeWidth: open ? 2.2 : 1.4,
      shadow: open,
      seed: number.hashCode,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Row(
        children: [
          badge,
          const SizedBox(width: 12),
          Expanded(child: body),
          if (open)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.arrow_forward_rounded, color: c.ink),
            ),
        ],
      ),
    );

    if (!open) return Semantics(label: 'Chapitre à venir', child: card);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChapterPage(chapterId: chapter.id)),
      ),
      child: card,
    );
  }
}
