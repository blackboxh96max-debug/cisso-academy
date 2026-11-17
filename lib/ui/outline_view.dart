import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models/content.dart';
import 'bilingual.dart';
import 'lesson_page.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

const _tones = [
  Tone.blue,
  Tone.violet,
  Tone.turquoise,
  Tone.green,
  Tone.orange,
  Tone.pink,
];

/// Couleur par défaut d'un module de sommaire.
Tone outlineTone(int index) => _tones[index % _tones.length];

/// Un programme (livre MILE2 ou ORSYS) module par module et section par
/// section, avec les leçons qui traitent chaque section. Les sections sans
/// leçon et les ajouts venus du livre MILE2 sont signalés.
class OutlineView extends StatelessWidget {
  const OutlineView({
    super.key,
    required this.outline,
    required this.intro,
    this.sectionWord = 'Section',
    this.toneOf = outlineTone,
    this.trailing,
    this.moduleKeys,
  });

  final CourseOutline outline;

  /// Clés posées sur l'en-tête de chaque module (pour y faire défiler).
  final List<GlobalKey>? moduleKeys;
  final String intro;

  /// « Section » (livre MILE2) ou « Thème » (ORSYS).
  final String sectionWord;
  final Tone Function(int moduleIndex) toneOf;

  /// Contenu ajouté sous chaque module (chapitres d'entraînement).
  final List<Widget> Function(int moduleIndex)? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(intro, style: Hand.bodyText(context)),
        for (final (i, m) in outline.modules.indexed) ...[
          const SizedBox(height: 22),
          _OutlineBanner(
            key: moduleKeys != null && i < moduleKeys!.length
                ? moduleKeys![i]
                : null,
            module: m,
            tone: toneOf(i),
            seed: 60 + i,
            word: sectionWord,
          ),
          for (final s in m.sections)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 12),
              child: _SectionCard(
                section: s,
                tone: toneOf(i),
                word: sectionWord,
              ),
            ),
          ...?trailing?.call(i),
        ],
        const SizedBox(height: 16),
        Text(
          outline.source,
          style: Hand.sansText(
            context,
            size: 12,
          ).copyWith(color: Paper.of(context).inkSoft),
        ),
      ],
    );
  }
}

class _OutlineBanner extends StatelessWidget {
  const _OutlineBanner({
    super.key,
    required this.module,
    required this.tone,
    required this.seed,
    required this.word,
  });

  final OutlineModule module;
  final Tone tone;
  final int seed;
  final String word;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ids = {for (final s in module.sections) ...s.lessons};
    final read = ids.where(state.readLessons.contains).length;
    final progress = ids.isEmpty ? 0.0 : read / ids.length;
    return GradientBanner(
      tone: tone,
      seed: seed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            module.label,
            style: const TextStyle(
              fontFamily: Hand.title,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            module.titleFr,
            style: Hand.sansText(
              context,
              size: 15,
            ).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          EnTag(module.titleEn, onDark: true, size: 12),
          const SizedBox(height: 10),
          HandProgress(value: progress, onDark: true),
          const SizedBox(height: 4),
          Text(
            ids.isEmpty
                ? '${module.sections.length} ${word.toLowerCase()}s · leçons à venir'
                : '${(progress * 100).round()} % · $read/${ids.length} '
                      'leçon(s) lue(s) · ${module.sections.length} '
                      '${word.toLowerCase()}s',
            style: Hand.sansText(
              context,
              size: 12.5,
            ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.tone,
    required this.word,
  });

  final OutlineSection section;
  final Tone tone;
  final String word;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final paper = Paper.of(context);
    final c = toneColors(tone, Theme.of(context).brightness);
    final lessons = [
      for (final id in section.lessons) state.library.lesson(id),
    ];
    final missing = section.coverage == Coverage.missing;
    return HandBox(
      fill: missing ? paper.page : c.fill,
      stroke: missing
          ? paper.inkSoft.withValues(alpha: 0.45)
          : toneBright(tone),
      strokeWidth: missing ? 1.4 : 2,
      seed: section.titleEn.hashCode,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: missing ? paper.rule : c.ink,
                ),
                child: Text(
                  '${section.number}',
                  style: TextStyle(
                    fontFamily: Hand.title,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: missing ? paper.inkSoft : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$word ${section.number} · ${section.titleFr}',
                      style: TextStyle(
                        fontFamily: Hand.body,
                        fontSize: 19,
                        height: 1.2,
                        color: missing ? paper.inkSoft : paper.ink,
                      ),
                    ),
                    EnTag(section.titleEn, size: 12),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              switch (section.coverage) {
                Coverage.covered when section.extra => const Sticker(
                  text: 'Livre MILE2',
                  tone: Tone.violet,
                ),
                Coverage.covered => const SizedBox.shrink(),
                Coverage.partial => const Sticker(
                  text: 'En partie',
                  tone: Tone.yellow,
                ),
                Coverage.missing => const Sticker(
                  text: 'Leçon à venir',
                  tone: Tone.pink,
                ),
              },
            ],
          ),
          if (lessons.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final l in lessons)
              _LessonLink(
                lesson: l,
                read: state.readLessons.contains(l.id),
                added: !section.extra && section.extraLessons.contains(l.id),
              ),
          ],
        ],
      ),
    );
  }
}

class _LessonLink extends StatelessWidget {
  const _LessonLink({
    required this.lesson,
    required this.read,
    this.added = false,
  });

  final Lesson lesson;
  final bool read;

  /// Leçon ajoutée depuis le livre MILE2 (vue ORSYS enrichie).
  final bool added;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => LessonPage(lesson: lesson))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Text(read ? '✔' : '📖', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lesson.title,
                style: Hand.sansText(
                  context,
                  size: 15,
                ).copyWith(color: paper.ink, fontWeight: FontWeight.w600),
              ),
            ),
            if (added) ...[
              const SizedBox(width: 6),
              const Sticker(text: '+ MILE2', tone: Tone.violet),
            ],
            Icon(Icons.chevron_right, color: paper.inkSoft),
          ],
        ),
      ),
    );
  }
}
