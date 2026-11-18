import 'dart:convert';
import 'dart:io';

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

  test('chaque chapitre disponible respecte le format pédagogique', () {
    final chapters = library.availableChapters.toList();
    expect(
      chapters.map((c) => c.id),
      containsAll([
        'm1c1',
        'm1c2',
        'm1c3',
        'm1c4',
        'm1c5',
        'm2c1',
        'm2c2',
        'm2c3',
        'm2c4',
        'm3c1',
        'm3c2',
        'm3c3',
        'm3c4',
        'm4c1',
        'm4c2',
        'm4c3',
        'm5c1',
        'm5c2',
        'm5c3',
        'm5c4',
        'm5c5',
      ]),
    );
    for (final ch in chapters) {
      expect(ch.lessons.length, greaterThanOrEqualTo(3), reason: ch.id);
      expect(ch.questions.length, greaterThanOrEqualTo(20), reason: ch.id);
      expect(ch.flashcards.length, greaterThanOrEqualTo(15), reason: ch.id);
      expect(ch.revisionSheet, isNotEmpty, reason: ch.id);
      expect(
        ch.questions.every((q) => ch.domainIds.contains(q.domainId)),
        isTrue,
        reason: '${ch.id} : questions rattachées au domaine du chapitre',
      );
      final levels = ch.questions.map((q) => q.level).toSet();
      expect(levels, containsAll(Level.values), reason: ch.id);
    }
    for (final lesson in chapters.expand((c) => c.lessons)) {
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
    for (final q in library.examQuestions) {
      expect(q.choices, hasLength(4), reason: q.id);
      expect(q.explanation.trim(), isNotEmpty, reason: q.id);
      for (var i = 0; i < q.choices.length; i++) {
        if (!q.correct.contains(i)) {
          expect(q.whyNot[i]?.trim(), isNotEmpty, reason: '${q.id} choix $i');
        }
      }
    }
  });

  test('la bonne réponse ne se devine ni à sa place ni à sa longueur', () {
    final single = library.examQuestions.where((q) => !q.isMultiple).toList();
    // Place : chaque lettre porte la bonne réponse dans au moins 15 % des cas
    // (l'ordre stocké est celui du mini-quiz des leçons, qui ne mélange pas).
    final byPosition = List.filled(4, 0);
    for (final q in single) {
      byPosition[q.correct.single]++;
    }
    for (var i = 0; i < 4; i++) {
      expect(
        byPosition[i] / single.length,
        greaterThanOrEqualTo(0.15),
        reason: 'position $i : $byPosition',
      );
    }
    // Longueur : la bonne réponse n'est nettement la plus longue (plus de
    // 30 % de plus que la suivante) que dans moins de 5 % des questions.
    final tooLong = single
        .where((q) {
          final lengths = q.choices.map((c) => c.length).toList();
          final right = lengths[q.correct.single];
          final others = [
            for (var i = 0; i < lengths.length; i++)
              if (i != q.correct.single) lengths[i],
          ];
          return others.every((l) => right > l * 1.3);
        })
        .map((q) => q.id)
        .toList();
    expect(
      tooLong.length / single.length,
      lessThan(0.05),
      reason: tooLong.join(', '),
    );
  });

  test('la banque couvre les trois niveaux et les questions multiples', () {
    final levels = library.questions.map((q) => q.level).toSet();
    expect(levels, containsAll(Level.values));
    expect(library.questions.where((q) => q.isMultiple), isNotEmpty);
  });

  test('aucune URL inventée : seuls des domaines vérifiés sont cités', () {
    final urls = library.chapters
        .expand((c) => c.lessons)
        .expand((l) => l.references)
        .map((r) => r.url)
        .whereType<String>();
    for (final url in urls) {
      expect(
        url.startsWith('https://csrc.nist.gov/') ||
            url.startsWith('https://www.nist.gov/'),
        isTrue,
        reason: url,
      );
    }
  });

  test('le glossaire est bilingue et la recherche ignore accents et casse', () {
    expect(library.glossary.length, greaterThanOrEqualTo(45));
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

  test('la validation rejette un schéma sans description accessible', () async {
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
    Map<String, String> files(Map<String, dynamic> block) => {
      'r/catalog.json': jsonEncode(catalog),
      'r/c.json': jsonEncode({
        'lessons': [
          {
            'id': 'l',
            'title': 'L',
            'minutes': 5,
            'objectives': ['o'],
            'blocks': [block],
          },
        ],
        'flashcards': [],
        'questions': [],
      }),
      'r/glossary.json': '[]',
    };
    final diagram = {
      'type': 'diagram',
      'diagram': {'type': 'flow', 'nodes': []},
    };
    expect(
      ContentLoader((p) async => files(diagram)[p]!, root: 'r').load(),
      throwsFormatException,
      reason: 'alt manquant',
    );
    final ok = {...diagram, 'alt': 'Schéma vide'};
    await ContentLoader((p) async => files(ok)[p]!, root: 'r').load();
    final quiz = {
      'type': 'miniQuiz',
      'questions': ['inconnue'],
    };
    expect(
      ContentLoader((p) async => files(quiz)[p]!, root: 'r').load(),
      throwsFormatException,
      reason: 'question inexistante',
    );
  });

  test('le chapitre modèle utilise les blocs du design cahier', () async {
    final library = await loadRealContent();
    final lessons = library.chapters.firstWhere((c) => c.id == 'm1c1').lessons;
    final types = lessons.expand((l) => l.blocks).map((b) => b.type).toSet();
    expect(
      types,
      containsAll([
        BlockType.diagram,
        BlockType.trainerNote,
        BlockType.memo,
        BlockType.miniQuiz,
        BlockType.practice,
        BlockType.important,
        BlockType.risk,
      ]),
    );
    for (final l in lessons) {
      expect(l.illustration, isNotNull);
      expect(
        File(l.illustration!).existsSync(),
        isTrue,
        reason: l.illustration,
      );
      expect(l.illustrationAlt, isNotEmpty);
    }
  });

  test('chaque leçon disponible suit le format cahier', () async {
    final library = await loadRealContent();
    for (final ch in library.availableChapters) {
      for (final l in ch.lessons) {
        final types = l.blocks.map((b) => b.type).toSet();
        expect(l.illustration, isNotNull, reason: l.id);
        expect(
          File(l.illustration!).existsSync(),
          isTrue,
          reason: l.illustration,
        );
        expect(
          types,
          contains(BlockType.diagram),
          reason: '${l.id} : au moins un schéma',
        );
        expect(
          types,
          contains(BlockType.miniQuiz),
          reason: '${l.id} : petit test',
        );
        expect(
          types.intersection({BlockType.trainerNote, BlockType.memo}),
          isNotEmpty,
          reason: '${l.id} : note du formateur ou mémo',
        );
      }
    }
  });

  test('chaque chapitre disponible a une carte mentale', () async {
    final library = await loadRealContent();
    for (final ch in library.availableChapters) {
      final map = ch.mindMap;
      expect(map, isNotNull, reason: '${ch.id} : carte mentale');
      expect(map!.children.length, greaterThanOrEqualTo(3), reason: ch.id);
      expect(map.depth, greaterThanOrEqualTo(3), reason: ch.id);
    }
    // La carte du chapitre 1 développe l'exemple de l'apprenant :
    // ses 4 branches anglaises sont reprises.
    final c1 = library.chapter('m1c1').mindMap!;
    expect(c1.children.map((b) => b.en), [
      'Risk Definitions',
      'Risk Assessment',
      'Risk Response and Monitoring',
      'Risk Management',
    ]);
    expect(c1.size, greaterThan(28));
  });

  test('la validation rejette une couleur inconnue dans une carte', () async {
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
    Map<String, String> files(String tone) => {
      'r/catalog.json': jsonEncode(catalog),
      'r/c.json': jsonEncode({
        'lessons': [],
        'flashcards': [],
        'questions': [],
        'mindMap': {
          'label': 'C',
          'children': [
            {'label': 'B', 'tone': tone},
          ],
        },
      }),
      'r/glossary.json': '[]',
    };
    expect(
      ContentLoader((p) async => files('fuchsia')[p]!, root: 'r').load(),
      throwsFormatException,
    );
    final ok = await ContentLoader(
      (p) async => files('pink')[p]!,
      root: 'r',
    ).load();
    expect(ok.chapter('c').mindMap!.children.single.label, 'B');
  });

  test(
    'le sommaire officiel MILE2 v20 est complet et relié aux leçons',
    () async {
      final library = await loadRealContent();
      final outline = library.mile2Outline;
      // 11 modules + le module Prérequis, 70 sections, dans l'ordre du livre.
      expect(outline.modules, hasLength(12));
      expect(outline.modules.last.label, 'Prérequis');
      expect(
        [for (final m in outline.modules) m.sections.length],
        [4, 7, 9, 5, 5, 6, 6, 4, 5, 4, 5, 10],
      );
      for (final m in outline.modules) {
        expect([
          for (final s in m.sections) s.number,
        ], List.generate(m.sections.length, (i) => i + 1));
      }
      // Chaque leçon de l'application apparaît dans le sommaire.
      final cited = {
        for (final m in outline.modules)
          for (final s in m.sections) ...s.lessons,
      };
      expect(cited, containsAll(library.lessons.map((l) => l.id)));
      // Les deux ordres contiennent les mêmes leçons, une seule fois.
      for (final view in CourseView.values) {
        final order = library.lessonOrder(view).map((l) => l.id).toList();
        expect(order.toSet(), hasLength(order.length));
        expect(order.toSet(), library.lessons.map((l) => l.id).toSet());
      }
    },
  );

  test('programme ORSYS : 5 modules, tel quel puis enrichi du livre', () async {
    final library = await loadRealContent();
    final strict = library.orsysOutline;
    final plus = library.orsysPlusOutline;
    Set<String> cited(CourseOutline o) => {
      for (final m in o.modules)
        for (final s in m.sections) ...s.lessons,
    };
    // Les 5 modules ORSYS et leurs 18 thèmes, sans ajout.
    expect(strict.modules, hasLength(5));
    expect(
      [for (final m in strict.modules) m.sections.length],
      [4, 4, 4, 3, 3],
    );
    expect(
      strict.modules.expand((m) => m.sections).where((s) => s.extra),
      isEmpty,
    );
    expect(
      strict.modules.expand((m) => m.sections).expand((s) => s.extraLessons),
      isEmpty,
    );
    // Les modèles de sécurité sont au module 2, comme chez ORSYS.
    expect(
      strict.modules[1].sections.first.titleEn,
      'Security Models and Evaluation Criteria',
    );
    // La vue enrichie garde les thèmes ORSYS, dans le même ordre, et
    // contient toutes les leçons de l'application.
    for (final (i, m) in strict.modules.indexed) {
      expect(
        plus.modules[i].sections.take(m.sections.length).map((s) => s.titleEn),
        m.sections.map((s) => s.titleEn),
      );
    }
    expect(cited(plus), containsAll(library.lessons.map((l) => l.id)));
    // Tout ce que la vue enrichie ajoute est signalé comme venant du livre.
    final added = cited(plus).difference(cited(strict));
    final marked = {
      for (final m in plus.modules)
        for (final s in m.sections) ...s.extraLessons,
    };
    expect(marked, containsAll(added));
    expect(added, isNotEmpty);
  });
}
