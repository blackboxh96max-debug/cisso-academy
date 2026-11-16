/// Modèle du contenu pédagogique (cours, questions, flashcards, glossaire).
///
/// Tout le contenu est livré dans `assets/content/` au format JSON et chargé
/// localement : aucune connexion n'est nécessaire.
library;

/// Nature d'une information, à afficher systématiquement (cahier des charges §8).
enum SourceKind {
  /// Exigence ou information officielle de la certification (MILE2), vérifiée.
  official,

  /// Connaissance générale en cybersécurité (normes, publications de référence).
  general,

  /// Bonne pratique professionnelle.
  practice,

  /// Exemple pédagogique créé pour l'application (fictif).
  example;

  static SourceKind parse(String? value) => switch (value) {
    'official' => SourceKind.official,
    'general' => SourceKind.general,
    'practice' => SourceKind.practice,
    'example' => SourceKind.example,
    _ => throw FormatException('sourceKind inconnu : $value'),
  };

  String get label => switch (this) {
    SourceKind.official => 'Officiel MILE2',
    SourceKind.general => 'Connaissance générale',
    SourceKind.practice => 'Bonne pratique',
    SourceKind.example => 'Exemple pédagogique',
  };
}

enum Level {
  beginner,
  intermediate,
  advanced;

  static Level parse(String? value) => switch (value) {
    'beginner' => Level.beginner,
    'intermediate' => Level.intermediate,
    'advanced' => Level.advanced,
    _ => throw FormatException('niveau inconnu : $value'),
  };

  String get label => switch (this) {
    Level.beginner => 'Débutant',
    Level.intermediate => 'Intermédiaire',
    Level.advanced => 'Avancé',
  };
}

/// Domaine officiel de l'examen CISSO (blueprint MILE2), avec son poids en %.
class ExamDomain {
  const ExamDomain({
    required this.id,
    required this.nameEn,
    required this.nameFr,
    required this.weight,
  });

  final String id;
  final String nameEn;
  final String nameFr;
  final int weight;

  factory ExamDomain.fromJson(Map<String, dynamic> json) => ExamDomain(
    id: json['id'] as String,
    nameEn: json['nameEn'] as String,
    nameFr: json['nameFr'] as String,
    weight: json['weight'] as int,
  );
}

/// Paramètres officiels de l'examen, utilisés seulement s'ils ont été vérifiés.
class ExamInfo {
  const ExamInfo({
    required this.questionCount,
    required this.durationMinutes,
    required this.passingScore,
    required this.source,
    required this.verifiedOn,
  });

  final int questionCount;
  final int durationMinutes;
  final int passingScore;
  final String source;
  final String verifiedOn;

  /// Temps officiel moyen par question, en secondes.
  double get secondsPerQuestion => durationMinutes * 60 / questionCount;

  factory ExamInfo.fromJson(Map<String, dynamic> json) => ExamInfo(
    questionCount: json['questionCount'] as int,
    durationMinutes: json['durationMinutes'] as int,
    passingScore: json['passingScore'] as int,
    source: json['source'] as String,
    verifiedOn: json['verifiedOn'] as String,
  );
}

class Reference {
  const Reference({required this.title, this.url, required this.kind});

  final String title;
  final String? url;
  final SourceKind kind;

  factory Reference.fromJson(Map<String, dynamic> json) => Reference(
    title: json['title'] as String,
    url: json['url'] as String?,
    kind: SourceKind.parse(json['kind'] as String?),
  );
}

/// Types de blocs d'une leçon.
enum BlockType {
  heading,
  text,
  bullets,
  definition,
  socCase,
  viewpoints,
  table,
  steps,
  pitfalls,
  summary;

  static BlockType parse(String value) => switch (value) {
    'heading' => BlockType.heading,
    'text' => BlockType.text,
    'bullets' => BlockType.bullets,
    'definition' => BlockType.definition,
    'socCase' => BlockType.socCase,
    'viewpoints' => BlockType.viewpoints,
    'table' => BlockType.table,
    'steps' => BlockType.steps,
    'pitfalls' => BlockType.pitfalls,
    'summary' => BlockType.summary,
    _ => throw FormatException('type de bloc inconnu : $value'),
  };
}

class LessonBlock {
  const LessonBlock({
    required this.type,
    this.title,
    this.text,
    this.items = const [],
    this.rows = const [],
    this.kind,
  });

  final BlockType type;
  final String? title;
  final String? text;

  /// Lignes d'une liste, d'étapes, de pièges ou de points de vue ("Rôle : avis").
  final List<String> items;

  /// Tableau : la première ligne est l'en-tête.
  final List<List<String>> rows;
  final SourceKind? kind;

  factory LessonBlock.fromJson(Map<String, dynamic> json) => LessonBlock(
    type: BlockType.parse(json['type'] as String),
    title: json['title'] as String?,
    text: json['text'] as String?,
    items: (json['items'] as List?)?.cast<String>() ?? const [],
    rows:
        (json['rows'] as List?)
            ?.map((r) => (r as List).cast<String>())
            .toList() ??
        const [],
    kind: json['kind'] == null
        ? null
        : SourceKind.parse(json['kind'] as String),
  );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.objectives,
    required this.blocks,
    required this.references,
    required this.minutes,
  });

  final String id;
  final String title;
  final List<String> objectives;
  final List<LessonBlock> blocks;
  final List<Reference> references;
  final int minutes;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    title: json['title'] as String,
    objectives: (json['objectives'] as List).cast<String>(),
    blocks: (json['blocks'] as List)
        .map((b) => LessonBlock.fromJson(b as Map<String, dynamic>))
        .toList(),
    references: (json['references'] as List? ?? const [])
        .map((r) => Reference.fromJson(r as Map<String, dynamic>))
        .toList(),
    minutes: json['minutes'] as int? ?? 20,
  );
}

class Question {
  const Question({
    required this.id,
    required this.chapterId,
    required this.domainId,
    required this.level,
    required this.concept,
    required this.prompt,
    required this.choices,
    required this.correct,
    required this.explanation,
    required this.whyNot,
    required this.kind,
  });

  final String id;
  final String chapterId;
  final String domainId;
  final Level level;

  /// Notion évaluée (sert au suivi des erreurs par notion).
  final String concept;
  final String prompt;
  final List<String> choices;

  /// Index des bonnes réponses (plusieurs = question à réponses multiples).
  final Set<int> correct;
  final String explanation;

  /// Pourquoi chaque mauvais choix est faux : index → explication.
  final Map<int, String> whyNot;
  final SourceKind kind;

  bool get isMultiple => correct.length > 1;

  factory Question.fromJson(Map<String, dynamic> json, String chapterId) {
    final whyNotRaw = json['whyNot'] as Map<String, dynamic>? ?? const {};
    return Question(
      id: json['id'] as String,
      chapterId: chapterId,
      domainId: json['domain'] as String,
      level: Level.parse(json['level'] as String?),
      concept: json['concept'] as String,
      prompt: json['prompt'] as String,
      choices: (json['choices'] as List).cast<String>(),
      correct: (json['correct'] as List).cast<int>().toSet(),
      explanation: json['explanation'] as String,
      whyNot: whyNotRaw.map((k, v) => MapEntry(int.parse(k), v as String)),
      kind: SourceKind.parse(json['kind'] as String? ?? 'general'),
    );
  }
}

class Flashcard {
  const Flashcard({
    required this.id,
    required this.chapterId,
    required this.front,
    required this.back,
    required this.concept,
  });

  final String id;
  final String chapterId;
  final String front;
  final String back;
  final String concept;

  factory Flashcard.fromJson(Map<String, dynamic> json, String chapterId) =>
      Flashcard(
        id: json['id'] as String,
        chapterId: chapterId,
        front: json['front'] as String,
        back: json['back'] as String,
        concept: json['concept'] as String,
      );
}

class GlossaryTerm {
  const GlossaryTerm({
    required this.id,
    required this.termEn,
    required this.termFr,
    this.acronym,
    required this.definition,
    required this.example,
    required this.kind,
  });

  final String id;
  final String termEn;
  final String termFr;
  final String? acronym;
  final String definition;
  final String example;
  final SourceKind kind;

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) => GlossaryTerm(
    id: json['id'] as String,
    termEn: json['en'] as String,
    termFr: json['fr'] as String,
    acronym: json['acronym'] as String?,
    definition: json['definition'] as String,
    example: json['example'] as String,
    kind: SourceKind.parse(json['kind'] as String? ?? 'general'),
  );

  /// Recherche insensible à la casse et aux accents.
  bool matches(String query) {
    final q = normalize(query);
    if (q.isEmpty) return true;
    return [
      termEn,
      termFr,
      acronym ?? '',
      definition,
    ].any((field) => normalize(field).contains(q));
  }
}

/// Minuscules sans accents, pour la recherche.
String normalize(String input) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString().trim();
}

class Chapter {
  const Chapter({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.domainIds,
    required this.available,
    this.lessons = const [],
    this.questions = const [],
    this.flashcards = const [],
    this.revisionSheet = const [],
  });

  final String id;
  final String moduleId;
  final String title;
  final List<String> domainIds;

  /// Faux tant que le contenu du chapitre n'est pas encore rédigé.
  final bool available;
  final List<Lesson> lessons;
  final List<Question> questions;
  final List<Flashcard> flashcards;

  /// Fiche de révision du chapitre (lignes de texte).
  final List<String> revisionSheet;
}

class Module {
  const Module({
    required this.id,
    required this.number,
    required this.title,
    required this.chapters,
  });

  final String id;
  final int number;
  final String title;
  final List<Chapter> chapters;
}

/// Tout le contenu chargé.
class ContentLibrary {
  ContentLibrary({
    required this.modules,
    required this.domains,
    required this.glossary,
    required this.examInfo,
  });

  final List<Module> modules;
  final List<ExamDomain> domains;
  final List<GlossaryTerm> glossary;
  final ExamInfo examInfo;

  Iterable<Chapter> get chapters => modules.expand((m) => m.chapters);

  Iterable<Chapter> get availableChapters => chapters.where((c) => c.available);

  Iterable<Question> get questions => chapters.expand((c) => c.questions);

  Iterable<Flashcard> get flashcards => chapters.expand((c) => c.flashcards);

  Chapter chapter(String id) => chapters.firstWhere((c) => c.id == id);

  Module module(String id) => modules.firstWhere((m) => m.id == id);

  ExamDomain domain(String id) => domains.firstWhere((d) => d.id == id);

  Question question(String id) => questions.firstWhere((q) => q.id == id);
}
