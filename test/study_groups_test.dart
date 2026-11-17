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
}
