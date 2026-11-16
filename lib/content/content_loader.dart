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

    final domains = (catalog['domains'] as List)
        .map((d) => ExamDomain.fromJson(d as Map<String, dynamic>))
        .toList();

    final modules = <Module>[];
    for (final m in catalog['modules'] as List) {
      final moduleJson = m as Map<String, dynamic>;
      final moduleId = moduleJson['id'] as String;
      final chapters = <Chapter>[];
      for (final c in moduleJson['chapters'] as List) {
        chapters.add(await _loadChapter(c as Map<String, dynamic>, moduleId));
      }
      modules.add(
        Module(
          id: moduleId,
          number: moduleJson['number'] as int,
          title: moduleJson['title'] as String,
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
        domainIds: domainIds,
        available: false,
      );
    }
    final data = jsonDecode(await read('$root/$file')) as Map<String, dynamic>;
    return Chapter(
      id: id,
      moduleId: moduleId,
      title: json['title'] as String,
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
    );
  }

  /// Vérifie la cohérence du contenu ; lève [FormatException] sinon.
  static void validate(ContentLibrary library) {
    final domainIds = library.domains.map((d) => d.id).toSet();
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
    }
    for (final g in library.glossary) {
      unique(g.id);
    }
    final total = library.domains.fold<int>(0, (s, d) => s + d.weight);
    if (total != 100) {
      throw FormatException(
        'Les poids des domaines totalisent $total, pas 100',
      );
    }
  }
}
