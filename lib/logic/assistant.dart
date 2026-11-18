import 'dart:math';

import '../models/content.dart';
import 'search.dart' show blockSearchText;
import 'terms.dart';

/// Assistant de questions hors ligne : il cherche dans le contenu de
/// l'application (leçons, glossaire, fiches, flashcards, explications des
/// QCM) les passages qui répondent le mieux à une question posée en français
/// ou en anglais. Aucun service en ligne, aucune IA : un classement BM25 avec
/// tolérance aux accents, aux pluriels, aux fautes de frappe légères et aux
/// équivalences français ↔ anglais du glossaire.
enum PassageKind {
  lesson('Leçon', '📖'),
  term('Glossaire', '🔤'),
  flashcard('Flashcard', '🃏'),
  sheet('Fiche de révision', '📝'),
  question('Explication de QCM', '❓'),
  prep('Préparation examen', '🎯');

  const PassageKind(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// Un morceau du contenu que l'assistant peut citer.
class Passage {
  Passage({
    required this.kind,
    required this.title,
    this.en,
    required this.text,
    this.chapterId,
    this.lessonId,
    this.blockIndex,
    this.termId,
    this.flashcardId,
    this.questionId,
  });

  final PassageKind kind;

  /// Intertitre, terme, recto de flashcard…
  final String title;
  final String? en;

  /// Texte complet du passage.
  final String text;
  final String? chapterId;
  final String? lessonId;

  /// Bloc de la leçon où commence le passage.
  final int? blockIndex;
  final String? termId;
  final String? flashcardId;
  final String? questionId;

  late final List<String> _titleTokens = tokenize(title, keepStop: true);
  late final List<String> _bodyTokens = tokenize(text, keepStop: true);

  /// Fréquence de chaque mot ; le titre compte double.
  late final Map<String, int> _tf = () {
    final m = <String, int>{};
    for (final t in _titleTokens) {
      m[t] = (m[t] ?? 0) + 2;
    }
    for (final t in _bodyTokens) {
      m[t] = (m[t] ?? 0) + 1;
    }
    return m;
  }();
}

/// Un passage trouvé, avec les phrases qui répondent le mieux.
class AssistantHit {
  const AssistantHit({
    required this.passage,
    required this.score,
    required this.excerpt,
    this.coverage = 1,
  });

  final Passage passage;
  final double score;

  /// Part des notions de la question que le passage contient (0 à 1).
  final double coverage;

  /// Une ou deux phrases du passage, les plus proches de la question.
  final String excerpt;
}

/// Réponse de l'assistant à une question.
class AssistantAnswer {
  const AssistantAnswer({
    required this.question,
    required this.english,
    required this.terms,
    required this.hits,
  });

  final String question;

  /// Question posée en anglais.
  final bool english;

  /// Termes du glossaire reconnus dans la question.
  final List<GlossaryTerm> terms;

  /// Passages du plus pertinent au moins pertinent (le premier est la
  /// réponse principale).
  final List<AssistantHit> hits;

  bool get isEmpty => hits.isEmpty && terms.isEmpty;

  /// Réponse jugée peu sûre (aucun mot important ne se retrouve bien).
  bool get uncertain =>
      terms.isEmpty &&
      (hits.isEmpty || hits.first.score < 4 || hits.first.coverage < 0.6);
}

// ---------------------------------------------------------------------------
// Découpage du texte.
// ---------------------------------------------------------------------------

/// Mots vides français et anglais, y compris les mots de question.
const _stop = {
  // français
  'a', 'au', 'aux', 'avec', 'ce', 'ces', 'cet', 'cette', 'c', 'd', 'dans',
  'de', 'des', 'du', 'elle', 'en', 'est', 'et', 'etre', 'il', 'ils', 'je',
  'j', 'l', 'la', 'le', 'les', 'leur', 'lui', 'ma', 'mais', 'me', 'mes', 'moi',
  'mon', 'ne', 'nos', 'notre', 'nous', 'on', 'ou', 'par', 'pas', 'pour',
  'qu', 'que', 'quel', 'quelle', 'quelles', 'quels', 'qui', 'quoi', 'sa',
  'se', 'ses', 'son', 'sont', 'sur', 'ta', 'te', 'tes', 'toi', 'ton', 'tu',
  'un', 'une', 'vos', 'votre', 'vous', 'y', 's', 'n', 'm', 't', 'comment',
  'pourquoi', 'quand', 'combien', 'dont', 'faut', 'fait', 'faire', 'peut',
  'peux', 'doit', 'dois', 'sert', 'servent', 'ca', 'cela', 'ceci', 'est-ce',
  'qu-est', 'veut', 'dire', 'signifie', 'explique', 'expliquer',
  'moyen', 'definition', 'definir', 'donne', 'donner', 'trouve', 'trouver',
  'chapitre', 'lecon', 'cours', 'parle', 'parler', 'aussi', 'plus', 'tres',
  'bien', 'entre', 'avoir', 'a-t-il', 'svp', 'stp', 'merci', 'bonjour',
  // anglais
  'an', 'and', 'are', 'as', 'at', 'be', 'by', 'can', 'do', 'does', 'for',
  'from', 'how', 'i', 'in', 'is', 'it', 'its', 'of', 'or',
  'should', 'the', 'this', 'that', 'to', 'what', 'when', 'where', 'which',
  'who', 'why', 'with', 'you', 'your', 'mean', 'means', 'explain', 'define',
  'please', 'tell', 'about', 'between', 'there', 'their', 'was', 'were',
  'will', 'would', 'my', 'we', 'our', 'has', 'have', 'used', 'use',
};

/// Mots qui signalent une question en anglais.
const _englishCues = {
  'what',
  'how',
  'why',
  'which',
  'when',
  'where',
  'who',
  'is',
  'are',
  'the',
  'does',
  'do',
  'difference',
  'between',
  'explain',
  'define',
  'of',
  'and',
  'should',
  'can',
  'an',
};

/// Mots qui signalent une question en français.
const _frenchCues = {
  'quel',
  'quelle',
  'quels',
  'quelles',
  'comment',
  'pourquoi',
  'est',
  'les',
  'des',
  'une',
  'un',
  'le',
  'la',
  'du',
  'entre',
  'qu',
  'que',
  'difference',
  'quoi',
  'et',
  'de',
};

/// Mots normalisés (minuscules, sans accents), sans mots vides sauf
/// [keepStop], ramenés à une racine simple.
List<String> tokenize(String text, {bool keepStop = false}) {
  final out = <String>[];
  for (final raw in fold(text).split(RegExp(r"[^a-z0-9]+"))) {
    if (raw.isEmpty) continue;
    if (!keepStop && _stop.contains(raw)) continue;
    out.add(stem(raw));
  }
  return out;
}

/// Racine simple : pluriels et féminins français, pluriels anglais.
String stem(String w) {
  if (RegExp(r'^[0-9]+$').hasMatch(w) || w.length <= 3) return w;
  var s = w;
  if (s.endsWith('ies') && s.length > 4) {
    s = '${s.substring(0, s.length - 3)}y';
  } else if (s.endsWith('aux') && s.length > 4) {
    s = '${s.substring(0, s.length - 3)}al';
  } else if ((s.endsWith('s') || s.endsWith('x')) && !s.endsWith('ss')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.length > 4 && s.endsWith('e')) s = s.substring(0, s.length - 1);
  return s;
}

int _distance(String a, String b) {
  if ((a.length - b.length).abs() > 1) return 2;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = min(
        min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Équivalences utiles absentes du glossaire (mots courants).
const _extraSynonyms = [
  ['chiffrement', 'encryption', 'cryptage'],
  ['dechiffrement', 'decryption'],
  ['sauvegarde', 'backup'],
  ['mot de passe', 'password'],
  ['pare-feu', 'firewall'],
  ['menace', 'threat'],
  ['vulnerabilite', 'vulnerability', 'faille'],
  ['risque', 'risk'],
  ['attaque', 'attack'],
  ['loi', 'law', 'reglement', 'regulation'],
  ['reseau', 'network'],
  ['donnee', 'data'],
  ['incident', 'incident'],
  ['delai', 'deadline', 'heure', 'hour', 'jour', 'day'],
  ['amende', 'fine', 'sanction', 'penalty'],
  ['difference', 'compare', 'versus', 'vs'],
  ['calcul', 'calculer', 'formule', 'formula', 'calculate'],
  ['rgpd', 'gdpr'],
  ['violation', 'breach', 'fuite'],
  ['notification', 'notifier', 'notify', 'signalement'],
  ['symetrique', 'symmetric'],
  ['asymetrique', 'asymmetric'],
  ['certificat', 'certificate'],
  ['publique', 'public'],
  ['privee', 'private'],
  ['preuve', 'evidence'],
  ['audit', 'audit'],
  ['journal', 'log', 'journalisation', 'logging'],
  ['sensibilisation', 'awareness'],
  ['ingenierie sociale', 'social engineering', 'hameconnage', 'phishing'],
  ['rancongiciel', 'ransomware'],
  ['norme', 'standard'],
  ['exigence', 'requirement'],
  ['cle', 'key'],
  ['signature', 'signature'],
  ['hachage', 'hash', 'empreinte'],
  ['politique', 'policy'],
  ['continuite', 'continuity'],
  ['reprise', 'recovery'],
  ['malveillant', 'malware', 'maliciel'],
  ['authentification', 'authentication'],
  ['autorisation', 'authorization'],
  ['controle', 'control'],
  ['acces', 'access'],
  ['gestion', 'management'],
  ['securite', 'security'],
  ['physique', 'physical'],
  ['logiciel', 'software'],
  ['developpement', 'development'],
  ['nuage', 'cloud'],
];

// ---------------------------------------------------------------------------
// Moteur.
// ---------------------------------------------------------------------------

class Assistant {
  Assistant(this.library) {
    _build();
  }

  final ContentLibrary library;
  final passages = <Passage>[];

  final _df = <String, int>{};
  late final double _avgLen;
  final _vocab = <String>{};

  /// Nom du glossaire (forme normalisée) → termes.
  final _termNames = <String, List<GlossaryTerm>>{};

  /// Mot normalisé → mots équivalents (autre langue).
  final _synonyms = <String, Set<String>>{};

  void _build() {
    final seenTerms = <String>{};
    for (final t in library.glossary) {
      for (final name in [t.termFr, t.termEn, ...acronymsOf(t)]) {
        final key = tokenize(name, keepStop: true).join(' ');
        if (key.isEmpty) continue;
        (_termNames[key] ??= []).add(t);
      }
      if (!seenTerms.add(fold(t.termEn).trim())) continue;
      passages.add(
        Passage(
          kind: PassageKind.term,
          title: t.acronym == null ? t.termFr : '${t.acronym} · ${t.termFr}',
          en: t.termEn,
          text: '${t.definition} ${t.example}'.trim(),
          termId: t.id,
        ),
      );
    }
    for (final group in _extraSynonyms) {
      final keys = [for (final w in group) tokenize(w).join(' ')];
      for (final k in keys) {
        (_synonyms[k] ??= {}).addAll(keys.where((o) => o != k));
      }
    }

    for (final c in library.chapters) {
      for (final l in c.lessons) {
        String? heading;
        var start = 0;
        final buffer = <String>[];
        void close() {
          final text = buffer.join(' ').trim();
          if (text.isEmpty) return;
          passages.add(
            Passage(
              kind: PassageKind.lesson,
              title: heading ?? l.title,
              text: text,
              chapterId: c.id,
              lessonId: l.id,
              blockIndex: start,
            ),
          );
        }

        for (final (i, b) in l.blocks.indexed) {
          if (b.type == BlockType.heading) {
            close();
            heading = b.text;
            start = i;
            buffer.clear();
            continue;
          }
          // Une partie longue est coupée pour que chaque passage reste précis.
          if (buffer.join(' ').length > 1400) {
            close();
            start = i;
            buffer.clear();
          }
          // Un tableau se lit ligne par ligne : « NIS 2 · 24 h · 72 h. »
          final parts = b.type == BlockType.table
              ? [b.title, b.text, for (final r in b.rows) r.join(' · ')]
              : blockSearchText(b);
          for (final s in parts) {
            if (s == null || s.trim().isEmpty) continue;
            buffer.add(RegExp(r'[.!?:;]$').hasMatch(s.trim()) ? s : '$s.');
          }
        }
        close();
      }
      for (final f in c.flashcards) {
        passages.add(
          Passage(
            kind: PassageKind.flashcard,
            title: f.front,
            text: f.back,
            chapterId: c.id,
            flashcardId: f.id,
          ),
        );
      }
      for (final line in c.revisionSheet) {
        if (line.startsWith('# ') || line.trim().isEmpty) continue;
        passages.add(
          Passage(
            kind: PassageKind.sheet,
            title: 'Fiche · ${c.title}',
            text: line.replaceFirst(RegExp(r'^[-*•]\s*'), ''),
            chapterId: c.id,
          ),
        );
      }
      for (final q in c.questions.where((q) => !q.fromTraining)) {
        final right = [for (final i in q.correct) q.choices[i]].join(' ; ');
        passages.add(
          Passage(
            kind: PassageKind.question,
            title: q.prompt,
            text: 'Réponse : $right. ${q.explanation}',
            chapterId: c.id,
            questionId: q.id,
          ),
        );
      }
    }
    for (final q in library.examPrep.questions) {
      passages.add(
        Passage(
          kind: PassageKind.prep,
          title: q.prompt.fr,
          en: q.prompt.en,
          text:
              'Réponse : ${q.choices[q.correct].fr}. ${q.explanation.fr} '
              '${q.prompt.en} ${q.choices[q.correct].en}. ${q.explanation.en}',
          chapterId: q.chapterId,
          questionId: q.id,
        ),
      );
    }

    var total = 0;
    for (final p in passages) {
      final all = {...p._titleTokens, ...p._bodyTokens};
      for (final t in all) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
      _vocab.addAll(all);
      total += p._titleTokens.length + p._bodyTokens.length;
    }
    _avgLen = passages.isEmpty ? 1 : total / passages.length;
  }

  double _idf(String t) {
    final n = passages.length;
    final df = _df[t] ?? 0;
    return log(1 + (n - df + 0.5) / (df + 0.5));
  }

  /// Termes du glossaire nommés dans la question (les plus longs d'abord,
  /// sans chevauchement).
  List<GlossaryTerm> recognizedTerms(String question) {
    final words = tokenize(question, keepStop: true);
    final taken = List<bool>.filled(words.length, false);
    final found = <GlossaryTerm>[];
    for (var len = min(6, words.length); len >= 1; len--) {
      for (var i = 0; i + len <= words.length; i++) {
        if (taken.sublist(i, i + len).contains(true)) continue;
        final key = words.sublist(i, i + len).join(' ');
        if (len == 1 && (_stop.contains(key) || key.length < 2)) continue;
        final terms = _termNames[key];
        if (terms == null) continue;
        for (var k = i; k < i + len; k++) {
          taken[k] = true;
        }
        if (!found.any((t) => t.termEn == terms.first.termEn)) {
          found.add(terms.first);
        }
      }
    }
    return found;
  }

  /// Les notions de la question : pour chaque mot (ou terme du glossaire),
  /// les mots de l'index qui l'expriment, avec leur poids.
  List<Map<String, double>> _concepts(
    String question,
    List<GlossaryTerm> terms,
  ) {
    final concepts = <Map<String, double>>[];
    void add(Map<String, double> c, String t, double w) {
      if (_stop.contains(t)) return;
      if (_vocab.contains(t)) {
        c[t] = max(c[t] ?? 0, w);
        return;
      }
      // Mot inconnu : faute de frappe légère ou forme voisine.
      if (t.length >= 5) {
        final head = t.substring(0, 5);
        for (final v in _vocab) {
          if (v.length < 5) continue;
          final near =
              (v.startsWith(head) && (v.length - t.length).abs() <= 3) ||
              _distance(v, t) <= 1;
          if (near) c[v] = max(c[v] ?? 0, w * 0.6);
        }
      }
    }

    // Mots déjà couverts par un terme du glossaire reconnu.
    final covered = <String>{};
    for (final term in terms) {
      final c = <String, double>{};
      final names = [term.termFr, term.termEn, ...acronymsOf(term)];
      final own = tokenize(question).toSet();
      for (final name in names) {
        for (final t in tokenize(name)) {
          add(c, t, own.contains(t) ? 1.2 : 0.7);
          if (own.contains(t)) covered.add(t);
        }
      }
      if (c.isNotEmpty) concepts.add(c);
    }
    for (final t in tokenize(question)) {
      if (covered.contains(t)) continue;
      final c = <String, double>{};
      add(c, t, 1);
      for (final s in _synonyms[t] ?? const <String>{}) {
        for (final p in s.split(' ')) {
          add(c, p, 0.7);
        }
      }
      // Un mot introuvable compte quand même : la réponse ne le couvre pas.
      concepts.add(c);
    }
    return concepts;
  }

  double _score(Passage p, Map<String, double> q) {
    const k1 = 1.2, b = 0.75;
    final len = p._titleTokens.length + p._bodyTokens.length;
    var s = 0.0;
    for (final MapEntry(key: t, value: w) in q.entries) {
      final tf = p._tf[t] ?? 0;
      if (tf == 0) continue;
      s +=
          w *
          _idf(t) *
          (tf * (k1 + 1)) /
          (tf + k1 * (1 - b + b * len / _avgLen));
    }
    return s;
  }

  /// Part des notions de la question présentes dans le passage.
  double _coverage(Passage p, List<Map<String, double>> concepts) {
    if (concepts.isEmpty) return 0;
    final found = concepts
        .where((c) => c.keys.any((t) => p._tf.containsKey(t)))
        .length;
    return found / concepts.length;
  }

  /// Les phrases du passage qui répondent le mieux (au plus [count]).
  String _excerpt(Passage p, Map<String, double> q, {int count = 2}) {
    final sentences = p.text
        .split(RegExp(r'(?<=[.!?;])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.length <= count) return p.text.trim();
    final scored = [
      for (final (i, s) in sentences.indexed)
        (
          i,
          tokenize(s)
              .toSet()
              .fold<double>(0, (a, t) => a + (q[t] ?? 0) * _idf(t)),
        ),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final picked = scored.take(count).map((e) => e.$1).toSet();
    // Une phrase courte est souvent un titre (« Les délais de NIS 2. ») :
    // on y joint les phrases qui suivent, où se trouve le contenu.
    for (final i in picked.toList()) {
      if (sentences[i].length < 60) {
        for (var k = i + 1; k < sentences.length && k <= i + 3; k++) {
          picked.add(k);
        }
      }
    }
    final keep = picked.toList()..sort();
    final out = StringBuffer();
    var last = -1;
    for (final i in keep) {
      if (last >= 0 && i != last + 1) out.write(' … ');
      if (last >= 0 && i == last + 1) out.write(' ');
      out.write(sentences[i]);
      last = i;
    }
    return out.toString();
  }

  /// La question est en anglais (plus d'indices anglais que français).
  static bool isEnglish(String question) {
    final words = fold(question).split(RegExp(r"[^a-z]+"));
    final en = words.where(_englishCues.contains).length;
    final fr = words.where(_frenchCues.contains).length;
    return en > fr;
  }

  /// Répond à [question] : passages classés, un seul par partie de leçon.
  AssistantAnswer ask(String question, {int limit = 6}) {
    final terms = recognizedTerms(question);
    final concepts = _concepts(question, terms);
    final q = <String, double>{};
    for (final c in concepts) {
      for (final MapEntry(key: t, value: w) in c.entries) {
        q[t] = max(q[t] ?? 0, w);
      }
    }
    final english = isEnglish(question);
    if (q.isEmpty) {
      return AssistantAnswer(
        question: question,
        english: english,
        terms: terms,
        hits: const [],
      );
    }
    final scored = <(Passage, double, double)>[];
    for (final p in passages) {
      var s = _score(p, q);
      if (s <= 0) continue;
      // Un passage qui couvre toute la question passe devant celui qui ne
      // répète qu'un mot.
      final cov = _coverage(p, concepts);
      s *= pow(cov, 1.5);
      // Les leçons passent devant à score égal : c'est là qu'on apprend.
      s *= switch (p.kind) {
        PassageKind.lesson => 1.15,
        PassageKind.term => 1.1,
        PassageKind.sheet => 1.0,
        PassageKind.flashcard => 0.95,
        PassageKind.question => 0.8,
        PassageKind.prep => 0.8,
      };
      scored.add((p, s, cov));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final hits = <AssistantHit>[];
    final seen = <String>{};
    for (final (p, s, cov) in scored) {
      final key = p.kind == PassageKind.lesson
          ? '${p.lessonId}#${p.blockIndex}'
          : '${p.kind.name}:${p.title}:${p.text.hashCode}';
      if (!seen.add(key)) continue;
      // Les définitions des termes nommés sont déjà affichées à part.
      if (p.kind == PassageKind.term &&
          terms.any((t) => t.id == p.termId || p.en == t.termEn)) {
        continue;
      }
      hits.add(
        AssistantHit(
          passage: p,
          score: s,
          coverage: cov,
          excerpt: _excerpt(p, q),
        ),
      );
      if (hits.length >= limit) break;
    }
    return AssistantAnswer(
      question: question,
      english: english,
      terms: terms.take(3).toList(),
      hits: hits,
    );
  }
}
