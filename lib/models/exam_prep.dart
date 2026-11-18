/// Préparation à l'examen : lots de questions fournis par l'apprenant depuis
/// sa formation, en anglais et en français. Ils restent séparés des
/// questions originales de l'application (statistiques, examens blancs).
library;

/// Texte bilingue.
class Bi {
  const Bi(this.en, this.fr);

  final String en;
  final String fr;

  factory Bi.fromJson(Map<String, dynamic> json) =>
      Bi(json['en'] as String, json['fr'] as String);
}

class PrepQuestion {
  const PrepQuestion({
    required this.id,
    required this.number,
    required this.chapterId,
    required this.prompt,
    required this.choices,
    required this.correct,
    required this.explanation,
    this.formula,
    required this.lotId,
  });

  final String id;

  /// Numéro dans le lot (1, 2, …), comme sur la fiche de l'apprenant.
  final int number;
  final String chapterId;
  final Bi prompt;
  final List<Bi> choices;
  final int correct;
  final Bi explanation;
  final String? formula;
  final String lotId;

  /// Lettre de la bonne réponse (A, B, C…).
  String get correctLetter => letter(correct);

  static String letter(int i) => String.fromCharCode(65 + i);
}

class PrepPart {
  const PrepPart({required this.title, required this.questions});

  final Bi title;
  final List<PrepQuestion> questions;
}

class PrepTable {
  const PrepTable({required this.title, required this.rows});

  final Bi title;

  /// Lignes [anglais, français].
  final List<(String, String)> rows;
}

class PrepKeyword {
  const PrepKeyword({required this.term, required this.en, required this.fr});

  final String term;
  final String en;
  final String fr;
}

/// Un lot du jour : questions, tableaux à retenir, mots-clés, conseil.
class PrepLot {
  const PrepLot({
    required this.id,
    required this.date,
    required this.title,
    required this.source,
    required this.parts,
    required this.tables,
    required this.keywords,
    this.advice,
  });

  final String id;
  final DateTime date;
  final Bi title;
  final String source;
  final List<PrepPart> parts;
  final List<PrepTable> tables;
  final List<PrepKeyword> keywords;
  final String? advice;

  List<PrepQuestion> get questions => parts.expand((p) => p.questions).toList();

  factory PrepLot.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    var n = 0;
    return PrepLot(
      id: id,
      date: DateTime.parse(json['date'] as String),
      title: Bi.fromJson(json['title'] as Map<String, dynamic>),
      source: json['source'] as String,
      parts: [
        for (final p in json['parts'] as List)
          PrepPart(
            title: Bi.fromJson(
              (p as Map<String, dynamic>)['title'] as Map<String, dynamic>,
            ),
            questions: [
              for (final q in p['questions'] as List)
                _question(q as Map<String, dynamic>, ++n, id),
            ],
          ),
      ],
      tables: [
        for (final t in json['tables'] as List? ?? const [])
          PrepTable(
            title: Bi.fromJson(
              (t as Map<String, dynamic>)['title'] as Map<String, dynamic>,
            ),
            rows: [
              for (final r in t['rows'] as List)
                ((r as List)[0] as String, r[1] as String),
            ],
          ),
      ],
      keywords: [
        for (final k in json['keywords'] as List? ?? const [])
          PrepKeyword(
            term: (k as Map<String, dynamic>)['term'] as String,
            en: k['en'] as String,
            fr: k['fr'] as String,
          ),
      ],
      advice: json['advice'] as String?,
    );
  }

  static PrepQuestion _question(Map<String, dynamic> q, int n, String lotId) =>
      PrepQuestion(
        id: q['id'] as String,
        number: n,
        chapterId: q['chapterId'] as String,
        prompt: Bi.fromJson(q['prompt'] as Map<String, dynamic>),
        choices: [
          for (final c in q['choices'] as List)
            Bi.fromJson(c as Map<String, dynamic>),
        ],
        correct: q['correct'] as int,
        explanation: Bi.fromJson(q['explanation'] as Map<String, dynamic>),
        formula: q['formula'] as String?,
        lotId: lotId,
      );
}

/// Tous les lots, du plus ancien au plus récent.
class ExamPrep {
  const ExamPrep(this.lots);

  static const empty = ExamPrep([]);

  final List<PrepLot> lots;

  List<PrepQuestion> get questions => lots.expand((l) => l.questions).toList();

  PrepLot? lot(String id) {
    for (final l in lots) {
      if (l.id == id) return l;
    }
    return null;
  }

  List<PrepQuestion> forChapter(String chapterId) =>
      questions.where((q) => q.chapterId == chapterId).toList();

  factory ExamPrep.fromJson(Map<String, dynamic> json) => ExamPrep(
    [
      for (final l in json['lots'] as List)
        PrepLot.fromJson(l as Map<String, dynamic>),
    ]..sort((a, b) => a.date.compareTo(b.date)),
  );
}
