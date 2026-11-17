import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../logic/stats.dart';
import '../models/content.dart';
import 'chapter_page.dart';
import 'mile2_outline_view.dart';
import 'mind_map_page.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'bilingual.dart';

/// Programme : au choix, l'ordre du livre MILE2 (11 modules + Prérequis) ou
/// le parcours de l'application en 5 modules. Les leçons et la progression
/// sont les mêmes dans les deux vues.
class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final library = state.library;
    final view = library.mile2Outline.modules.isEmpty
        ? CourseView.app
        : state.courseView;
    return NotebookPage(
      title: 'Cours',
      children: [
        if (library.mile2Outline.modules.isNotEmpty) ...[
          SegmentedButton<CourseView>(
            key: const Key('course-view'),
            segments: const [
              ButtonSegment(
                value: CourseView.mile2,
                icon: Icon(Icons.menu_book_outlined),
                label: Text('Livre MILE2'),
              ),
              ButtonSegment(
                value: CourseView.app,
                icon: Icon(Icons.view_module_outlined),
                label: Text('5 modules'),
              ),
            ],
            selected: {view},
            showSelectedIcon: false,
            onSelectionChanged: (v) =>
                AppScope.read(context).setCourseView(v.first),
          ),
          const SizedBox(height: 14),
        ],
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
                  root: courseMindMap(library),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (view == CourseView.mile2)
          const Mile2OutlineView()
        else ...[
          Text(
            'Votre programme en ${library.modules.length} modules '
            'thématiques. Un chapitre est validé à 80 %. Le bouton « Livre '
            'MILE2 » montre les mêmes leçons rangées comme dans le livre.',
            style: Hand.bodyText(context),
          ),
          for (final m in library.modules) ...[
            const SizedBox(height: 22),
            _ModuleBanner(
              module: m,
              progress: state.stats.moduleProgress(m.id),
            ),
            for (final (i, c) in m.chapters.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 12),
                child: _ChapterCard(
                  chapter: c,
                  number: '${m.number}.${i + 1}',
                  tone: moduleStyle(m.number).$1,
                  stats: state.stats.chapters
                      .where((s) => s.chapter.id == c.id)
                      .firstOrNull,
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _ModuleBanner extends StatelessWidget {
  const _ModuleBanner({required this.module, required this.progress});

  final Module module;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final (tone, emoji) = moduleStyle(module.number);
    final open = module.chapters.where((c) => c.available).length;
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
                      style: const TextStyle(
                        fontFamily: Hand.title,
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w700,
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
                '${(progress * 100).round()} % · $open/${module.chapters.length} '
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
                  child: const Padding(
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
          fontSize: 22,
          fontWeight: FontWeight.w700,
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
            fontSize: 21,
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
