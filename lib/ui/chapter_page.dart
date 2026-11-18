import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models/content.dart';
import 'flashcards_page.dart';
import 'lesson_page.dart';
import 'mind_map_page.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'quiz_hub_page.dart';
import 'revision_sheet_page.dart';
import 'bilingual.dart';

class ChapterPage extends StatelessWidget {
  const ChapterPage({super.key, required this.chapterId});

  final String chapterId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final chapter = state.library.chapter(chapterId);
    final stats = state.stats.chapters.firstWhere(
      (c) => c.chapter.id == chapterId,
    );
    final module = state.library.module(chapter.moduleId);
    final (tone, emoji) = moduleStyle(module.number);
    final white = Hand.sansText(
      context,
      size: 13,
    ).copyWith(color: Colors.white, fontWeight: FontWeight.w700);

    return NotebookPage(
      title: 'Chapitre',
      children: [
        GradientBanner(
          tone: tone,
          seed: 51,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$emoji  Module ${module.number} · ${module.title}',
                style: white,
              ),
              const SizedBox(height: 4),
              Text(
                chapter.title,
                style: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: Hand.tsize(36),
                  height: 1.05,
                  fontWeight: Hand.titleWeight,
                  color: Colors.white,
                ),
              ),
              if (chapter.titleEn != null) ...[
                const SizedBox(height: 4),
                EnTag(chapter.titleEn!, onDark: true, size: 14),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in chapter.domainIds)
                    _WhitePill(
                      '🎯 ${state.library.domain(d).nameFr} · '
                      '${state.library.domain(d).weight} % de l\'examen',
                    ),
                  _WhitePill('📊 ${stats.status.label}'),
                ],
              ),
              const SizedBox(height: 12),
              HandProgress(value: stats.progress, onDark: true),
              const SizedBox(height: 4),
              Text(
                'Progression du chapitre : ${(stats.progress * 100).round()} %'
                ' · ${stats.lessonsRead}/${stats.lessonCount} leçon(s) lue(s)',
                style: white,
              ),
            ],
          ),
        ),
        NotePanel(
          title: 'Leçons',
          emoji: '📚',
          tone: Tone.blue,
          seed: 52,
          child: Column(
            children: [
              for (final (i, lesson) in chapter.lessons.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _LessonCard(
                    lesson: lesson,
                    index: i,
                    read: state.readLessons.contains(lesson.id),
                    tone: tone,
                  ),
                ),
            ],
          ),
        ),
        NotePanel(
          title: 'S\'entraîner et réviser',
          emoji: '💪',
          tone: Tone.pink,
          seed: 53,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GradientButton(
                emoji: '📝',
                label: 'QCM du chapitre (${chapter.questions.length})',
                from: Tone.pink,
                to: Tone.violet,
                onPressed: () => startPractice(context, chapterId: chapterId),
              ),
              GradientButton(
                emoji: '🃏',
                label: 'Flashcards (${chapter.flashcards.length})',
                from: Tone.turquoise,
                to: Tone.blue,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FlashcardSessionPage(
                      cardIds: chapter.flashcards.map((f) => f.id).toList(),
                    ),
                  ),
                ),
              ),
              GradientButton(
                emoji: '📄',
                label: 'Fiche de révision',
                from: Tone.orange,
                to: Tone.yellow,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RevisionSheetPage(chapter: chapter),
                  ),
                ),
              ),
              GradientButton(
                emoji: '🧠',
                label: 'Carte mentale',
                from: Tone.violet,
                to: Tone.blue,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MindMapPage(
                      title: 'Carte mentale',
                      root: chapterMindMap(chapter),
                    ),
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

class _WhitePill extends StatelessWidget {
  const _WhitePill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: Hand.sans,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.index,
    required this.read,
    required this.tone,
  });

  final Lesson lesson;
  final int index;
  final bool read;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final c = toneColors(tone, Theme.of(context).brightness);
    final thumb = Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: toneBright(tone), width: 2.4),
      ),
      child: lesson.illustration != null
          ? SvgPicture.asset(lesson.illustration!, excludeFromSemantics: true)
          : Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: Hand.tsize(28),
                  fontWeight: Hand.titleWeight,
                  color: c.ink,
                ),
              ),
            ),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => LessonPage(lesson: lesson))),
      child: HandBox(
        fill: c.fill,
        stroke: toneBright(tone),
        strokeWidth: 2,
        seed: 60 + index,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            thumb,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leçon ${index + 1}',
                    style: Hand.sansText(
                      context,
                      size: 12.5,
                    ).copyWith(color: c.ink, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    lesson.title,
                    style: TextStyle(
                      fontFamily: Hand.body,
                      fontSize: Hand.bsize(21),
                      height: 1.2,
                      color: paper.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Sticker(
                        text: '⏱️ ${lesson.minutes} min',
                        tone: Tone.yellow,
                      ),
                      read
                          ? const Sticker(text: '✅ Lue', tone: Tone.green)
                          : const Sticker(text: '📖 À lire', tone: Tone.orange),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: c.ink),
          ],
        ),
      ),
    );
  }
}
