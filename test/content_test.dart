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
        'm2c1',
        'm2c2',
        'm2c3',
        'm3c1',
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
}
