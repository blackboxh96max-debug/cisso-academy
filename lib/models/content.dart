/// Modèle du contenu pédagogique (cours, questions, flashcards, glossaire).
///
/// Tout le contenu est livré dans `assets/content/` au format JSON et chargé
/// localement : aucune connexion n'est nécessaire.
library;

import 'exam_prep.dart';

export 'exam_prep.dart';

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

  String get labelEn => switch (this) {
    SourceKind.official => 'Official MILE2',
    SourceKind.general => 'General knowledge',
    SourceKind.practice => 'Good practice',
    SourceKind.example => 'Teaching example',
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
/// Types de blocs d'une leçon. Chaque type a une couleur pédagogique fixe
/// (voir `lib/ui/notebook/palette.dart`).
enum BlockType {
  heading,
  text,
  bullets,

  /// 📘 Définition (bleu).
  definition,

  /// 🌍 Exemple professionnel / cas SOC (turquoise).
  socCase,

  /// 👥 Points de vue des métiers (violet).
  viewpoints,
  table,

  /// Étapes : affichées comme un schéma en flèches.
  steps,

  /// ⚠️ Pièges d'examen (rose).
  pitfalls,

  /// 💡 À retenir (orange).
  summary,

  /// ✏️ Note du formateur (jaune, manuscrit).
  trainerNote,

  /// 🧠 Astuce de mémorisation (jaune).
  memo,

  /// ⭐ Notion importante, approfondissement (violet).
  important,

  /// ✅ Bonne pratique (vert).
  practice,

  /// 🚨 Risque, erreur, alerte (rouge).
  risk,

  /// 🖼️ Schéma explicatif dessiné par l'application.
  diagram,

  /// 🖼️ Illustration (image vectorielle embarquée).
  illustration,

  /// 📝 Petit test : quelques questions de la banque.
  miniQuiz;

  static BlockType parse(String value) => BlockType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => throw FormatException('type de bloc inconnu : $value'),
  );
}

class LessonBlock {
  const LessonBlock({
    required this.type,
    this.title,
    this.text,
    this.items = const [],
    this.rows = const [],
    this.kind,
    this.diagram,
    this.asset,
    this.alt,
    this.questionIds = const [],
  });

  final BlockType type;
  final String? title;
  final String? text;

  /// Lignes d'une liste, d'étapes, de pièges ou de points de vue ("Rôle : avis").
  final List<String> items;

  /// Tableau : la première ligne est l'en-tête.
  final List<List<String>> rows;
  final SourceKind? kind;

  /// Description d'un schéma (`type` + données), pour [BlockType.diagram].
  final Map<String, dynamic>? diagram;

  /// Chemin d'une illustration embarquée, pour [BlockType.illustration].
  final String? asset;

  /// Description accessible d'un schéma ou d'une illustration.
  final String? alt;

  /// Questions du « petit test », pour [BlockType.miniQuiz].
  final List<String> questionIds;

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
    diagram: json['diagram'] as Map<String, dynamic>?,
    asset: json['asset'] as String?,
    alt: json['alt'] as String?,
    questionIds: (json['questions'] as List?)?.cast<String>() ?? const [],
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
    this.illustration,
    this.illustrationAlt,
  });

  final String id;
  final String title;

  /// Illustration en tête de leçon (chemin d'asset SVG) et sa description.
  final String? illustration;
  final String? illustrationAlt;
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
    illustration: json['illustration'] as String?,
    illustrationAlt: json['illustrationAlt'] as String?,
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
    this.fromTraining = false,
    this.en,
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

  /// Question donnée par l'apprenant depuis sa formation (lots de la
  /// préparation à l'examen), ajoutée au QCM de son chapitre. Elle n'entre
  /// pas dans les examens blancs.
  final bool fromTraining;

  /// Version anglaise, affichée au-dessus du français : l'anglais pour
  /// s'entraîner comme à l'examen, le français pour comprendre.
  final QuestionEn? en;

  bool get isMultiple => correct.length > 1;

  /// La même question avec sa version anglaise.
  Question withEnglish(QuestionEn? english) => Question(
    id: id,
    chapterId: chapterId,
    domainId: domainId,
    level: level,
    concept: concept,
    prompt: prompt,
    choices: choices,
    correct: correct,
    explanation: explanation,
    whyNot: whyNot,
    kind: kind,
    fromTraining: fromTraining,
    en: english,
  );

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

/// Textes anglais d'une question, dans le même ordre que le français.
class QuestionEn {
  const QuestionEn({
    required this.prompt,
    required this.choices,
    required this.explanation,
    this.whyNot = const {},
  });

  final String prompt;
  final List<String> choices;
  final String explanation;
  final Map<int, String> whyNot;

  factory QuestionEn.fromJson(Map<String, dynamic> json) {
    final whyNotRaw = json['whyNot'] as Map<String, dynamic>? ?? const {};
    return QuestionEn(
      prompt: json['prompt'] as String,
      choices: (json['choices'] as List).cast<String>(),
      explanation: json['explanation'] as String,
      whyNot: whyNotRaw.map((k, v) => MapEntry(int.parse(k), v as String)),
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
    this.en,
  });

  final String id;
  final String chapterId;
  final String front;
  final String back;
  final String concept;

  /// Version anglaise, affichée au-dessus du français comme dans les QCM.
  final FlashcardEn? en;

  /// La même carte avec sa version anglaise.
  Flashcard withEnglish(FlashcardEn? english) => Flashcard(
    id: id,
    chapterId: chapterId,
    front: front,
    back: back,
    concept: concept,
    en: english,
  );

  factory Flashcard.fromJson(Map<String, dynamic> json, String chapterId) =>
      Flashcard(
        id: json['id'] as String,
        chapterId: chapterId,
        front: json['front'] as String,
        back: json['back'] as String,
        concept: json['concept'] as String,
      );
}

/// Recto et verso anglais d'une flashcard.
class FlashcardEn {
  const FlashcardEn({required this.front, required this.back});

  final String front;
  final String back;

  factory FlashcardEn.fromJson(Map<String, dynamic> json) =>
      FlashcardEn(front: json['front'] as String, back: json['back'] as String);
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
    this.titleEn,
    required this.domainIds,
    required this.available,
    this.lessons = const [],
    this.questions = const [],
    this.flashcards = const [],
    this.revisionSheet = const [],
    this.revisionSheetEn = const [],
    this.mindMap,
    this.lessonsEn = const {},
  });

  final String id;
  final String moduleId;
  final String title;

  /// Titre anglais, tel qu'on le rencontre dans les supports officiels.
  final String? titleEn;
  final List<String> domainIds;

  /// Faux tant que le contenu du chapitre n'est pas encore rédigé.
  final bool available;
  final List<Lesson> lessons;
  final List<Question> questions;
  final List<Flashcard> flashcards;

  /// Fiche de révision du chapitre (lignes de texte).
  final List<String> revisionSheet;

  /// Fiche de révision anglaise, ligne pour ligne (vide si non traduite).
  final List<String> revisionSheetEn;

  /// Version anglaise de la ligne [i] de la fiche, s'il y en a une.
  String? revisionLineEn(int i) =>
      i < revisionSheetEn.length ? revisionSheetEn[i] : null;

  /// Carte mentale du chapitre (racine = titre du chapitre).
  final MindNode? mindMap;

  /// Version anglaise des leçons, par identifiant de leçon (vide tant que
  /// le chapitre n'est pas traduit). Mêmes blocs, dans le même ordre.
  final Map<String, Lesson> lessonsEn;
}

/// Nœud d'une carte mentale : libellé, terme anglais, détail, sous-nœuds.
class MindNode {
  const MindNode({
    required this.label,
    this.en,
    this.emoji,
    this.detail,
    this.tone,
    this.children = const [],
  });

  factory MindNode.fromJson(Map<String, dynamic> json) => MindNode(
    label: json['label'] as String,
    en: json['en'] as String?,
    emoji: json['emoji'] as String?,
    detail: json['detail'] as String?,
    tone: json['tone'] as String?,
    children: (json['children'] as List? ?? const [])
        .map((c) => MindNode.fromJson(c as Map<String, dynamic>))
        .toList(),
  );

  final String label;

  /// Terme anglais de l'examen, quand il diffère du libellé.
  final String? en;
  final String? emoji;
  final String? detail;

  /// Couleur imposée (nom d'un ton du cahier), sinon couleur de la branche.
  final String? tone;
  final List<MindNode> children;

  /// Nombre total de nœuds, racine comprise.
  int get size => 1 + children.fold(0, (n, c) => n + c.size);

  /// Profondeur maximale (1 pour un nœud sans enfant).
  int get depth => 1 + children.fold(0, (d, c) => c.depth > d ? c.depth : d);
}

class Module {
  const Module({
    required this.id,
    required this.number,
    required this.title,
    this.titleEn,
    required this.chapters,
  });

  final String id;
  final int number;
  final String title;
  final String? titleEn;
  final List<Chapter> chapters;
}

/// Tout le contenu chargé.
class ContentLibrary {
  ContentLibrary({
    required this.modules,
    required this.domains,
    required this.glossary,
    required this.examInfo,
    this.examPrep = ExamPrep.empty,
    this.mile2Outline = CourseOutline.empty,
    this.orsysOutline = CourseOutline.empty,
    this.orsysPlusOutline = CourseOutline.empty,
  });

  final List<Module> modules;

  /// Sommaire officiel MILE2 (11 modules + Prérequis) relié à nos leçons.
  final CourseOutline mile2Outline;

  /// Programme ORSYS en 5 modules, tel quel (sans ajout).
  final CourseOutline orsysOutline;

  /// Programme ORSYS en 5 modules enrichi de tout le livre MILE2.
  final CourseOutline orsysPlusOutline;

  /// Sommaire affiché pour une vue.
  CourseOutline outline(CourseView view) => switch (view) {
    CourseView.mile2 => mile2Outline,
    CourseView.orsys => orsysOutline,
    CourseView.orsysPlus => orsysPlusOutline,
  };
  final List<ExamDomain> domains;
  final List<GlossaryTerm> glossary;
  final ExamInfo examInfo;

  /// Questions de préparation fournies par l'apprenant (hors statistiques).
  final ExamPrep examPrep;

  Iterable<Chapter> get chapters => modules.expand((m) => m.chapters);

  Iterable<Chapter> get availableChapters => chapters.where((c) => c.available);

  Iterable<Question> get questions => chapters.expand((c) => c.questions);

  /// Questions des examens blancs : celles de l'application, sans les
  /// questions de la formation de l'apprenant.
  Iterable<Question> get examQuestions =>
      questions.where((q) => !q.fromTraining);

  Iterable<Flashcard> get flashcards => chapters.expand((c) => c.flashcards);

  Chapter chapter(String id) => chapters.firstWhere((c) => c.id == id);

  Iterable<Lesson> get lessons => chapters.expand((c) => c.lessons);

  /// La version anglaise d'une leçon, ou `null` si elle n'est pas traduite.
  Lesson? englishLesson(String lessonId) {
    for (final c in chapters) {
      final l = c.lessonsEn[lessonId];
      if (l != null) return l;
    }
    return null;
  }

  Lesson lesson(String id) => lessons.firstWhere((l) => l.id == id);

  /// Toutes les leçons dans l'ordre de la vue choisie, chacune une seule
  /// fois (à sa première apparition dans le sommaire), puis celles que le
  /// sommaire ne cite pas.
  List<Lesson> lessonOrder(CourseView view) {
    final all = lessons.toList();
    final outline = this.outline(view);
    if (outline.modules.isEmpty) return all;
    final byId = {for (final l in all) l.id: l};
    final out = <Lesson>[];
    final seen = <String>{};
    for (final m in outline.modules) {
      for (final s in m.sections) {
        for (final id in s.lessons) {
          if (seen.add(id) && byId[id] != null) out.add(byId[id]!);
        }
      }
    }
    for (final l in all) {
      if (seen.add(l.id)) out.add(l);
    }
    return out;
  }

  Module module(String id) => modules.firstWhere((m) => m.id == id);

  ExamDomain domain(String id) => domains.firstWhere((d) => d.id == id);

  Question question(String id) => questions.firstWhere((q) => q.id == id);
}

/// Les deux façons de parcourir la formation.
enum CourseView {
  /// Ordre du support officiel MILE2 v20 : 11 modules + Prérequis.
  mile2,

  /// Programme ORSYS : 5 modules, sans ajout.
  orsys,

  /// Programme ORSYS enrichi de tout le contenu du livre MILE2.
  orsysPlus,
}

/// Niveau de couverture d'une section officielle par nos leçons.
enum Coverage { covered, partial, missing }

class OutlineSection {
  const OutlineSection({
    required this.number,
    required this.titleEn,
    required this.titleFr,
    required this.lessons,
    required this.coverage,
    this.extra = false,
    this.extraLessons = const [],
    this.keywords = const [],
  });

  factory OutlineSection.fromJson(Map<String, dynamic> json) => OutlineSection(
    number: json['number'] as int,
    titleEn: json['titleEn'] as String,
    titleFr: json['titleFr'] as String,
    lessons: (json['lessons'] as List).cast<String>(),
    coverage: Coverage.values.byName(json['coverage'] as String),
    extra: json['extra'] as bool? ?? false,
    extraLessons: (json['extraLessons'] as List? ?? const []).cast<String>(),
    keywords: [
      for (final k in json['keywords'] as List? ?? const [])
        (
          fr: (k as Map<String, dynamic>)['fr'] as String,
          en: k['en'] as String,
        ),
    ],
  );

  final int number;

  /// Titre exact du sommaire officiel (anglais).
  final String titleEn;
  final String titleFr;

  /// Identifiants des leçons qui traitent la section.
  final List<String> lessons;
  final Coverage coverage;

  /// Vue enrichie : thème ajouté depuis le livre MILE2.
  final bool extra;

  /// Vue enrichie : leçons ajoutées depuis le livre MILE2.
  final List<String> extraLessons;

  /// Mots-clés essentiels de la section (cartes mentales), en français et
  /// en anglais.
  final List<({String fr, String en})> keywords;
}

class OutlineModule {
  const OutlineModule({
    required this.id,
    required this.label,
    required this.titleEn,
    required this.titleFr,
    required this.sections,
  });

  factory OutlineModule.fromJson(Map<String, dynamic> json) => OutlineModule(
    id: json['id'] as String,
    label: json['label'] as String,
    titleEn: json['titleEn'] as String,
    titleFr: json['titleFr'] as String,
    sections: (json['sections'] as List)
        .map((s) => OutlineSection.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

  final String id;

  /// « Module 1 » … « Module 11 », « Prérequis ».
  final String label;
  final String titleEn;
  final String titleFr;
  final List<OutlineSection> sections;
}

class CourseOutline {
  const CourseOutline({required this.source, required this.modules});

  factory CourseOutline.fromJson(Map<String, dynamic> json) => CourseOutline(
    source: json['source'] as String,
    modules: (json['modules'] as List)
        .map((m) => OutlineModule.fromJson(m as Map<String, dynamic>))
        .toList(),
  );

  static const empty = CourseOutline(source: '', modules: []);

  /// D'où vient le sommaire.
  final String source;
  final List<OutlineModule> modules;
}
