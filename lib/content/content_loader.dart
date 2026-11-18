import 'dart:convert';

import '../models/content.dart';

/// Lit un fichier texte du contenu (assets en production, disque en test).
typedef TextReader = Future<String> Function(String path);

/// Charge et valide le contenu pédagogique.
///
/// Structure : `catalog.json` décrit les domaines, l'examen, les modules et
/// les chapitres ; chaque chapitre disponible pointe vers son propre fichier.
class ContentLoader {
  ContentLoader(this.read, {this.root = 'assets/content'});

  final TextReader read;
  final String root;

  Future<ContentLibrary> load() async {
    final catalog =
        jsonDecode(await read('$root/catalog.json')) as Map<String, dynamic>;
    Future<CourseOutline> outline(String key) async => catalog[key] == null
        ? CourseOutline.empty
        : CourseOutline.fromJson(
            jsonDecode(await read('$root/${catalog[key]}'))
                as Map<String, dynamic>,
          );

    final domains = (catalog['domains'] as List)
        .map((d) => ExamDomain.fromJson(d as Map<String, dynamic>))
        .toList();

    final examPrep = catalog['examPrep'] == null
        ? ExamPrep.empty
        : ExamPrep.fromJson(
            jsonDecode(await read('$root/${catalog['examPrep']}'))
                as Map<String, dynamic>,
          );

    final modules = <Module>[];
    for (final m in catalog['modules'] as List) {
      final moduleJson = m as Map<String, dynamic>;
      final moduleId = moduleJson['id'] as String;
      final chapters = <Chapter>[];
      for (final c in moduleJson['chapters'] as List) {
        final chapter = await _loadChapter(c as Map<String, dynamic>, moduleId);
        // Les questions de la formation de l'apprenant complètent le QCM de
        // leur chapitre.
        if (chapter.available) {
          chapter.questions.addAll(
            examPrep
                .forChapter(chapter.id)
                .map(
                  (q) => trainingQuestion(q, chapter, examPrep.lot(q.lotId)),
                ),
          );
        }
        chapters.add(chapter);
      }
      modules.add(
        Module(
          id: moduleId,
          number: moduleJson['number'] as int,
          title: moduleJson['title'] as String,
          titleEn: moduleJson['titleEn'] as String?,
          chapters: chapters,
        ),
      );
    }

    final glossaryJson =
        jsonDecode(await read('$root/glossary.json')) as List<dynamic>;
    final glossary =
        glossaryJson
            .map((g) => GlossaryTerm.fromJson(g as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => normalize(a.termFr).compareTo(normalize(b.termFr)));

    final library = ContentLibrary(
      modules: modules,
      domains: domains,
      glossary: glossary,
      examInfo: ExamInfo.fromJson(catalog['exam'] as Map<String, dynamic>),
      examPrep: examPrep,
      mile2Outline: await outline('mile2Outline'),
      orsysOutline: await outline('orsysOutline'),
      orsysPlusOutline: await outline('orsysPlusOutline'),
    );
    validate(library);
    return library;
  }

  Future<Chapter> _loadChapter(
    Map<String, dynamic> json,
    String moduleId,
  ) async {
    final id = json['id'] as String;
    final file = json['file'] as String?;
    final domainIds = (json['domains'] as List).cast<String>();
    if (file == null) {
      return Chapter(
        id: id,
        moduleId: moduleId,
        title: json['title'] as String,
        titleEn: json['titleEn'] as String?,
        domainIds: domainIds,
        available: false,
      );
    }
    final data = jsonDecode(await read('$root/$file')) as Map<String, dynamic>;
    final fileEn = json['fileEn'] as String?;
    final english = fileEn == null
        ? const <Lesson>[]
        : ((jsonDecode(await read('$root/$fileEn'))
                      as Map<String, dynamic>)['lessons']
                  as List)
              .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
              .toList();
    return Chapter(
      id: id,
      moduleId: moduleId,
      title: json['title'] as String,
      titleEn: json['titleEn'] as String?,
      domainIds: domainIds,
      available: true,
      lessons: (data['lessons'] as List)
          .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
          .toList(),
      questions: (data['questions'] as List)
          .map((q) => Question.fromJson(q as Map<String, dynamic>, id))
          .toList(),
      flashcards: (data['flashcards'] as List)
          .map((f) => Flashcard.fromJson(f as Map<String, dynamic>, id))
          .toList(),
      revisionSheet: (data['revisionSheet'] as List? ?? const [])
          .cast<String>(),
      mindMap: data['mindMap'] == null
          ? null
          : MindNode.fromJson(data['mindMap'] as Map<String, dynamic>),
      lessonsEn: {for (final l in english) l.id: l},
    );
  }

  /// Vérifie la cohérence du contenu ; lève [FormatException] sinon.
  static void validate(ContentLibrary library) {
    for (final c in library.chapters) {
      if (c.lessonsEn.isNotEmpty) validateEnglish(c);
    }
    final domainIds = library.domains.map((d) => d.id).toSet();
    final lessonIds = library.lessons.map((l) => l.id).toSet();
    for (final view in CourseView.values) {
      for (final m in library.outline(view).modules) {
        for (final s in m.sections) {
          final where = 'Sommaire ${view.name} ${m.label} section ${s.number}';
          for (final id in s.lessons) {
            if (!lessonIds.contains(id)) {
              throw FormatException('$where : leçon inconnue $id');
            }
          }
          if (!s.lessons.toSet().containsAll(s.extraLessons)) {
            throw FormatException('$where : leçon ajoutée hors liste');
          }
          if ((s.coverage == Coverage.missing) != s.lessons.isEmpty &&
              s.coverage != Coverage.partial) {
            throw FormatException(
              '$where : couverture « ${s.coverage.name} » incohérente avec '
              'ses leçons',
            );
          }
        }
      }
    }
    final seen = <String>{};

    void unique(String id) {
      if (!seen.add(id)) throw FormatException('Identifiant en double : $id');
    }

    for (final chapter in library.chapters) {
      unique(chapter.id);
      for (final d in chapter.domainIds) {
        if (!domainIds.contains(d)) {
          throw FormatException('Domaine inconnu $d (chapitre ${chapter.id})');
        }
      }
      for (final lesson in chapter.lessons) {
        unique(lesson.id);
        if (lesson.illustration != null &&
            (lesson.illustrationAlt ?? '').trim().isEmpty) {
          throw FormatException('${lesson.id} : illustration sans description');
        }
        for (final block in lesson.blocks) {
          _validateBlock(lesson.id, block, library);
        }
      }
      for (final q in chapter.questions) {
        unique(q.id);
        if (!domainIds.contains(q.domainId)) {
          throw FormatException(
            'Domaine inconnu ${q.domainId} (question ${q.id})',
          );
        }
        if (q.choices.length < 2) {
          throw FormatException('Question ${q.id} : au moins 2 choix');
        }
        if (q.correct.isEmpty ||
            q.correct.any((i) => i < 0 || i >= q.choices.length)) {
          throw FormatException(
            'Question ${q.id} : bonne(s) réponse(s) invalide(s)',
          );
        }
        for (var i = 0; i < q.choices.length; i++) {
          // Une question de la formation a une explication d'ensemble.
          if (q.fromTraining) break;
          if (!q.correct.contains(i) && !q.whyNot.containsKey(i)) {
            throw FormatException(
              'Question ${q.id} : explication manquante pour le choix $i',
            );
          }
        }
      }
      for (final f in chapter.flashcards) {
        unique(f.id);
      }
      if (chapter.mindMap case final map?) {
        _validateMindNode(chapter.id, map);
      }
    }
    for (final g in library.glossary) {
      unique(g.id);
    }
    _validateExamPrep(library);
    final total = library.domains.fold<int>(0, (s, d) => s + d.weight);
    if (total != 100) {
      throw FormatException(
        'Les poids des domaines totalisent $total, pas 100',
      );
    }
  }

  /// Lots de préparation : identifiants uniques, chapitre existant, bonne
  /// réponse dans la liste, textes anglais et français non vides.
  static void _validateExamPrep(ContentLibrary library) {
    final chapterIds = library.chapters.map((c) => c.id).toSet();
    final seen = <String>{};
    bool blank(Bi t) => t.en.trim().isEmpty || t.fr.trim().isEmpty;
    for (final lot in library.examPrep.lots) {
      if (!seen.add(lot.id)) {
        throw FormatException('Lot de préparation en double : ${lot.id}');
      }
      for (final q in lot.questions) {
        if (!seen.add(q.id)) {
          throw FormatException('Question de préparation en double : ${q.id}');
        }
        if (!chapterIds.contains(q.chapterId)) {
          throw FormatException('${q.id} : chapitre inconnu ${q.chapterId}');
        }
        if (q.choices.length < 2 ||
            q.correct < 0 ||
            q.correct >= q.choices.length) {
          throw FormatException('${q.id} : choix ou bonne réponse invalides');
        }
        if (blank(q.prompt) || blank(q.explanation) || q.choices.any(blank)) {
          throw FormatException('${q.id} : texte anglais ou français manquant');
        }
      }
    }
  }

  /// Couleurs utilisables dans une carte mentale.
  static const mindTones = {
    'blue',
    'violet',
    'green',
    'orange',
    'red',
    'yellow',
    'turquoise',
    'pink',
  };

  static void _validateMindNode(String chapterId, MindNode node) {
    if (node.label.trim().isEmpty) {
      throw FormatException('$chapterId : nœud de carte mentale sans libellé');
    }
    if (node.tone != null && !mindTones.contains(node.tone)) {
      throw FormatException(
        '$chapterId : couleur inconnue dans la carte mentale (${node.tone})',
      );
    }
    for (final c in node.children) {
      _validateMindNode(chapterId, c);
    }
  }

  /// Types de schémas que l'application sait dessiner.
  static const diagramTypes = {'flow', 'cycle', 'matrix', 'bars', 'quadrant'};

  static void _validateBlock(
    String lessonId,
    LessonBlock block,
    ContentLibrary library,
  ) {
    switch (block.type) {
      case BlockType.diagram:
        final type = block.diagram?['type'];
        if (!diagramTypes.contains(type)) {
          throw FormatException('$lessonId : schéma de type inconnu ($type)');
        }
        if ((block.alt ?? '').trim().isEmpty) {
          throw FormatException(
            '$lessonId : schéma sans description accessible',
          );
        }
      case BlockType.illustration:
        if (block.asset == null || (block.alt ?? '').trim().isEmpty) {
          throw FormatException('$lessonId : illustration incomplète');
        }
      case BlockType.miniQuiz:
        final ids = library.questions.map((q) => q.id).toSet();
        if (block.questionIds.isEmpty) {
          throw FormatException('$lessonId : petit test vide');
        }
        for (final id in block.questionIds) {
          if (!ids.contains(id)) {
            throw FormatException('$lessonId : question inconnue $id');
          }
        }
      default:
        break;
    }
  }
}

/// Vérifie que la version anglaise d'un chapitre reprend chaque leçon bloc
/// pour bloc : mêmes types, mêmes listes, mêmes schémas ; seuls les textes
/// changent. Lève [FormatException] sinon.
void validateEnglish(Chapter chapter) {
  final fr = {for (final l in chapter.lessons) l.id};
  if (!fr.containsAll(chapter.lessonsEn.keys) ||
      !chapter.lessonsEn.keys.toSet().containsAll(fr)) {
    throw FormatException('${chapter.id} : leçons anglaises incomplètes');
  }
  for (final l in chapter.lessons) {
    final en = chapter.lessonsEn[l.id]!;
    final where = '${chapter.id} ${l.id} (anglais)';
    if (en.blocks.length != l.blocks.length ||
        en.objectives.length != l.objectives.length ||
        en.references.length != l.references.length ||
        en.illustration != l.illustration ||
        en.minutes != l.minutes) {
      throw FormatException('$where : structure différente');
    }
    for (final (i, a) in l.blocks.indexed) {
      final b = en.blocks[i];
      final same =
          a.type == b.type &&
          a.kind == b.kind &&
          a.asset == b.asset &&
          (a.title == null) == (b.title == null) &&
          (a.text == null) == (b.text == null) &&
          a.items.length == b.items.length &&
          a.rows.length == b.rows.length &&
          [for (final r in a.rows) r.length].join(',') ==
              [for (final r in b.rows) r.length].join(',') &&
          a.questionIds.join(',') == b.questionIds.join(',') &&
          jsonEncode(diagramSkeleton(a.diagram)) ==
              jsonEncode(diagramSkeleton(b.diagram));
      if (!same) throw FormatException('$where : bloc $i différent');
    }
  }
}

/// Un schéma sans ses textes traduisibles (libellés, détails, axes).
Object? diagramSkeleton(Object? node) => switch (node) {
  Map() => {
    for (final MapEntry(:key, :value) in node.entries)
      key: _diagramTexts.contains(key) ? '' : diagramSkeleton(value),
  },
  List() => [for (final v in node) diagramSkeleton(v)],
  _ => node,
};

const _diagramTexts = {
  'label',
  'detail',
  'center',
  'title',
  'text',
  'xLabel',
  'yLabel',
  'unit',
};

/// Une question de la formation de l'apprenant, au format des QCM de
/// chapitre : le français d'abord, l'anglais de l'examen en dessous.
Question trainingQuestion(PrepQuestion q, Chapter chapter, PrepLot? lot) {
  String both(Bi b) => b.en.trim() == b.fr.trim() ? b.fr : '${b.fr}\n${b.en}';
  return Question(
    id: q.id,
    chapterId: chapter.id,
    domainId: chapter.domainIds.first,
    level: Level.intermediate,
    concept: lot == null
        ? 'Question de ta formation'
        : 'Question de ta formation · ${lot.title.fr}',
    prompt: both(q.prompt),
    choices: [for (final c in q.choices) both(c)],
    correct: {q.correct},
    explanation: [
      q.explanation.fr,
      if (q.formula != null) q.formula!,
      if (q.explanation.en.trim() != q.explanation.fr.trim()) q.explanation.en,
    ].join('\n\n'),
    whyNot: const {},
    kind: SourceKind.general,
    fromTraining: true,
  );
}
