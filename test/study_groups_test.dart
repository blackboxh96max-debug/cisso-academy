import 'package:cisso_academy/logic/study_groups.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  test('vues ORSYS : les 5 modules et leurs chapitres', () {
    for (final view in [CourseView.orsys, CourseView.orsysPlus]) {
      final groups = studyGroups(library, view);
      expect(groups.length, library.modules.length);
      for (final (i, g) in groups.indexed) {
        expect(g.index, i);
        expect(g.label, 'Module ${library.modules[i].number}');
        expect(g.chapters, library.modules[i].chapters);
      }
    }
  });

  test('vue du livre MILE2 : ses modules, chacun avec ses chapitres', () {
    final groups = studyGroups(library, CourseView.mile2);
    final outline = library.mile2Outline.modules;
    expect(groups.map((g) => g.label), outline.map((m) => m.label));
    expect(groups.last.label, 'Prérequis');
    // Chaque leçon citée par une section mène à son chapitre.
    for (final (i, g) in groups.indexed) {
      final lessons = {for (final s in outline[i].sections) ...s.lessons};
      expect(g.lessonIds.toSet(), lessons);
      for (final id in lessons) {
        final chapter = library.chapters.firstWhere(
          (c) => c.lessons.any((l) => l.id == id),
        );
        expect(g.chapters, contains(chapter));
      }
      expect(g.chapters.toSet().length, g.chapters.length);
    }
    // Le module 3 du livre (cryptographie) regroupe les deux chapitres
    // de cryptographie.
    expect(groups[2].chapters.map((c) => c.id), ['m2c2', 'm2c4']);
    // Tous les chapitres de l'application sont rangés quelque part.
    final covered = {for (final g in groups) ...g.chapters};
    expect(covered.length, library.chapters.length);
  });

  test('numéro d\'un chapitre dans l\'application', () {
    expect(chapterNumber(library, library.chapter('m2c4')), '2.4');
  });

  for (final view in CourseView.values) {
    test(
      'numérotation des leçons continue dans chaque module (${view.name})',
      () {
        final order = library.lessonOrder(view);
        LessonPlace? previous;
        for (final l in order) {
          final place = lessonPlace(library, view, l.id);
          expect(place.number, inInclusiveRange(1, place.total));
          if (previous != null && previous.label == place.label) {
            // Même module : la leçon suivante porte le numéro suivant.
            expect(place.number, previous.number + 1, reason: l.id);
            expect(place.total, previous.total);
          } else {
            // Nouveau module : on repart de 1, après avoir fini le précédent.
            expect(place.number, 1, reason: l.id);
            if (previous != null) expect(previous.number, previous.total);
          }
          previous = place;
        }
        expect(previous!.number, previous.total);
      },
    );
  }

  test('un module ORSYS numérote toutes ses leçons, pas 1/3 par chapitre', () {
    final first = library.lessonOrder(CourseView.orsysPlus).first;
    final place = lessonPlace(library, CourseView.orsysPlus, first.id);
    expect(place.label, 'Module 1');
    expect(place.total, greaterThan(3));
  });
}
