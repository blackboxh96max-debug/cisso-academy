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

/// Place d'une leçon dans la vue choisie : son module (celui où elle
/// apparaît pour la première fois, comme pour « leçon suivante ») et son
/// rang parmi les leçons de ce module.
class LessonPlace {
  const LessonPlace({
    required this.label,
    required this.title,
    required this.number,
    required this.total,
    this.groupIndex,
    this.section,
  });

  /// « Module 3 », « Prérequis ».
  final String label;
  final String title;

  /// Rang de la leçon dans le module (à partir de 1) et nombre de leçons.
  final int number;
  final int total;

  /// Rang du module dans la vue.
  final int? groupIndex;

  /// Section du livre ou thème ORSYS : « Section 2 · … », « Thème 1 · … ».
  final String? section;
}

/// Pour chaque vue, la place de chaque leçon (calculée une fois).
final _places = Expando<Map<CourseView, Map<String, LessonPlace>>>();

LessonPlace lessonPlace(
  ContentLibrary library,
  CourseView view,
  String lessonId,
) {
  final byView = _places[library] ??= {};
  final places = byView[view] ??= _computePlaces(library, view);
  return places[lessonId] ?? _chapterPlace(library, lessonId);
}

Map<String, LessonPlace> _computePlaces(
  ContentLibrary library,
  CourseView view,
) {
  final outline = library.outline(view);
  final out = <String, LessonPlace>{};
  if (outline.modules.isEmpty) return out;
  final known = {for (final l in library.lessons) l.id};
  final seen = <String>{};
  final word = view == CourseView.mile2 ? 'Section' : 'Thème';
  for (final (i, m) in outline.modules.indexed) {
    // Leçons dont c'est la première apparition, dans l'ordre du module.
    final own = <(String, OutlineSection)>[];
    for (final s in m.sections) {
      for (final id in s.lessons) {
        if (known.contains(id) && seen.add(id)) own.add((id, s));
      }
    }
    for (final (k, (id, s)) in own.indexed) {
      out[id] = LessonPlace(
        label: m.label,
        title: m.titleFr,
        number: k + 1,
        total: own.length,
        groupIndex: i,
        section: '$word ${s.number} · ${s.titleFr}',
      );
    }
  }
  // Leçons que le sommaire ne cite pas : elles viennent à la fin, comme
  // dans « leçon suivante ».
  final rest = [
    for (final l in library.lessons)
      if (!seen.contains(l.id)) l.id,
  ];
  for (final (k, id) in rest.indexed) {
    out[id] = LessonPlace(
      label: 'Compléments',
      title: 'Leçons hors de ce programme',
      number: k + 1,
      total: rest.length,
    );
  }
  return out;
}

/// Repli : la leçon dans son chapitre.
LessonPlace _chapterPlace(ContentLibrary library, String lessonId) {
  final chapter = library.chapters.firstWhere(
    (c) => c.lessons.any((l) => l.id == lessonId),
  );
  final m = library.module(chapter.moduleId);
  return LessonPlace(
    label: 'Module ${m.number}',
    title: m.title,
    number: chapter.lessons.indexWhere((l) => l.id == lessonId) + 1,
    total: chapter.lessons.length,
  );
}
