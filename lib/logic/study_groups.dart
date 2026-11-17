import '../models/content.dart';

/// Un module tel que la vue choisie le présente : un module ORSYS (avec ses
/// chapitres d'entraînement) ou un module du livre MILE2 (avec les chapitres
/// de l'application qui traitent ses sections).
///
/// Questions, flashcards, fiches et cartes sont rattachées aux chapitres :
/// dans la vue « Livre MILE2 », un module regroupe donc les chapitres dont au
/// moins une leçon traite l'une de ses sections. Un chapitre peut ainsi
/// apparaître sous plusieurs modules du livre.
class StudyGroup {
  const StudyGroup({
    required this.index,
    required this.label,
    required this.title,
    this.titleEn,
    required this.chapters,
    required this.lessonIds,
    this.moduleNumber,
    this.outline,
  });

  /// Rang dans la vue (0 pour le premier module).
  final int index;

  /// « Module 1 » … « Module 11 », « Prérequis ».
  final String label;
  final String title;
  final String? titleEn;

  /// Chapitres d'entraînement, dans l'ordre de la vue.
  final List<Chapter> chapters;

  /// Leçons du module, dans l'ordre de la vue.
  final List<String> lessonIds;

  /// Numéro du module ORSYS (1 à 5), ou `null` pour un module du livre.
  final int? moduleNumber;

  /// Module du sommaire du livre MILE2 (vue « Livre MILE2 » seulement).
  final OutlineModule? outline;

  /// Chapitres disponibles (avec questions, flashcards et fiche).
  List<Chapter> get availableChapters =>
      chapters.where((c) => c.available).toList();

  /// Libellé complet : « Module 2 · Titre ».
  String get fullTitle => '$label · $title';
}

/// Les modules de la vue [view], dans son ordre.
List<StudyGroup> studyGroups(ContentLibrary library, CourseView view) {
  final outline = library.mile2Outline;
  if (view != CourseView.mile2 || outline.modules.isEmpty) {
    return [
      for (final (i, m) in library.modules.indexed)
        StudyGroup(
          index: i,
          label: 'Module ${m.number}',
          title: m.title,
          titleEn: m.titleEn,
          chapters: m.chapters,
          lessonIds: [
            for (final c in m.chapters)
              for (final l in c.lessons) l.id,
          ],
          moduleNumber: m.number,
        ),
    ];
  }
  final chapterOf = {
    for (final c in library.chapters)
      for (final l in c.lessons) l.id: c,
  };
  return [
    for (final (i, m) in outline.modules.indexed)
      () {
        final lessons = <String>[];
        final chapters = <Chapter>[];
        for (final s in m.sections) {
          for (final id in s.lessons) {
            if (lessons.contains(id)) continue;
            lessons.add(id);
            final c = chapterOf[id];
            if (c != null && !chapters.contains(c)) chapters.add(c);
          }
        }
        return StudyGroup(
          index: i,
          label: m.label,
          title: m.titleFr,
          titleEn: m.titleEn,
          chapters: chapters,
          lessonIds: lessons,
          outline: m,
        );
      }(),
  ];
}

/// Numéro d'un chapitre dans l'application : « 1.2 » (module ORSYS, rang).
String chapterNumber(ContentLibrary library, Chapter chapter) {
  final m = library.module(chapter.moduleId);
  return '${m.number}.${m.chapters.indexOf(chapter) + 1}';
}

/// Nom court d'une vue, pour les titres.
String courseViewLabel(CourseView view) => switch (view) {
  CourseView.mile2 => 'Livre MILE2',
  CourseView.orsys => 'ORSYS',
  CourseView.orsysPlus => 'ORSYS enrichi',
};

/// Où se trouve une leçon ou un chapitre dans la vue [view] : le module (ou
/// les modules du livre) et, pour une leçon du livre, la section.
List<String> placeInView(
  ContentLibrary library,
  CourseView view, {
  String? lessonId,
  String? chapterId,
}) {
  final chapter = chapterId == null ? null : library.chapter(chapterId);
  if (view == CourseView.mile2 && library.mile2Outline.modules.isNotEmpty) {
    final out = <String>[];
    for (final m in library.mile2Outline.modules) {
      if (lessonId != null) {
        for (final s in m.sections) {
          if (s.lessons.contains(lessonId)) {
            out.add(
              'Livre MILE2 · ${m.label} · section ${s.number} · ${s.titleFr}',
            );
          }
        }
      } else if (chapter != null &&
          m.sections.any(
            (s) =>
                s.lessons.any((id) => chapter.lessons.any((l) => l.id == id)),
          )) {
        out.add('Livre MILE2 · ${m.label} · ${m.titleFr}');
      }
    }
    return out.take(3).toList();
  }
  if (chapter == null) return const [];
  final m = library.module(chapter.moduleId);
  return ['Module ${m.number} · ${m.title}'];
}
