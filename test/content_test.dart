import 'dart:convert';

import 'package:cisso_academy/content/content_loader.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  test('le contenu réel se charge et passe la validation', () {
    expect(library.modules, hasLength(5));
    expect(library.domains, hasLength(11));
    expect(library.domains.fold<int>(0, (s, d) => s + d.weight), 100);
  });

  test('les paramètres d\'examen correspondent au blueprint vérifié', () {
    final exam = library.examInfo;
    expect(exam.questionCount, 100);
    expect(exam.durationMinutes, 120);
    expect(exam.passingScore, 62);
    expect(exam.secondsPerQuestion, 72);
  });

  test('le chapitre pilote est complet', () {
    final ch = library.chapter('m1c1');
    expect(ch.available, isTrue);
    expect(ch.lessons, hasLength(3));
    expect(ch.questions.length, greaterThanOrEqualTo(20));
    expect(ch.flashcards.length, greaterThanOrEqualTo(15));
    expect(ch.revisionSheet, isNotEmpty);
    for (final lesson in ch.lessons) {
      expect(lesson.objectives, isNotEmpty, reason: lesson.id);
      expect(
        lesson.blocks.any((b) => b.type == BlockType.socCase),
        isTrue,
        reason: '${lesson.id} : cas SOC attendu',
      );
      expect(
        lesson.blocks.any((b) => b.type == BlockType.viewpoints),
        isTrue,
        reason: '${lesson.id} : points de vue attendus',
      );
      expect(
        lesson.blocks.any((b) => b.type == BlockType.summary),
        isTrue,
        reason: '${lesson.id} : résumé attendu',
      );
    }
  });

  test('chaque question a 4 choix, une explication et un « pourquoi pas »', () {
    for (final q in library.questions) {
      expect(q.choices, hasLength(4), reason: q.id);
      expect(q.explanation.trim(), isNotEmpty, reason: q.id);
      for (var i = 0; i < q.choices.length; i++) {
        if (!q.correct.contains(i)) {
          expect(q.whyNot[i]?.trim(), isNotEmpty, reason: '${q.id} choix $i');
        }
      }
    }
  });

  test('la banque couvre les trois niveaux et les questions multiples', () {
    final levels = library.questions.map((q) => q.level).toSet();
    expect(levels, containsAll(Level.values));
    expect(library.questions.where((q) => q.isMultiple), isNotEmpty);
  });

  test('aucune URL inventée : seules des URL https connues sont citées', () {
    final urls = library.chapters
        .expand((c) => c.lessons)
        .expand((l) => l.references)
        .map((r) => r.url)
        .whereType<String>();
    for (final url in urls) {
      expect(url, startsWith('https://csrc.nist.gov/'), reason: url);
    }
  });

  test('le glossaire est bilingue et la recherche ignore accents et casse', () {
    expect(library.glossary.length, greaterThanOrEqualTo(30));
    final hits = library.glossary.where((t) => t.matches('VULNERABILITE'));
    expect(hits.map((t) => t.id), contains('vulnerability'));
    expect(
      library.glossary.where((t) => t.matches('ale')).map((t) => t.id),
      contains('ale'),
    );
  });

  test(
    'la validation rejette une question sans bonne réponse valide',
    () async {
      final catalog = {
        'exam': {
          'questionCount': 10,
          'durationMinutes': 10,
          'passingScore': 50,
          'source': 'test',
          'verifiedOn': '2026-01-01',
        },
        'domains': [
          {'id': 'd', 'nameEn': 'D', 'nameFr': 'D', 'weight': 100},
        ],
        'modules': [
          {
            'id': 'm',
            'number': 1,
            'title': 'M',
            'chapters': [
              {
                'id': 'c',
                'title': 'C',
                'domains': ['d'],
                'file': 'c.json',
              },
            ],
          },
        ],
      };
      final chapter = {
        'lessons': [],
        'flashcards': [],
        'questions': [
          {
            'id': 'q',
            'domain': 'd',
            'level': 'beginner',
            'concept': 'x',
            'prompt': '?',
            'choices': ['a', 'b'],
            'correct': [5],
            'explanation': 'e',
            'whyNot': {},
          },
        ],
      };
      final files = {
        'r/catalog.json': jsonEncode(catalog),
        'r/c.json': jsonEncode(chapter),
        'r/glossary.json': '[]',
      };
      final loader = ContentLoader((p) async => files[p]!, root: 'r');
      expect(loader.load(), throwsFormatException);
    },
  );
}
