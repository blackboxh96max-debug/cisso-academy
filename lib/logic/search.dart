import '../models/content.dart';
import 'terms.dart';

/// Ce que trouve la recherche globale.
enum SearchKind {
  term('Glossaire', '🔤'),
  chapter('Chapitre', '📘'),
  lesson('Leçon', '📖'),
  section('Dans une leçon', '📌'),
  flashcard('Flashcard', '🃏'),
  mindNode('Carte mentale', '🧠');

  const SearchKind(this.label, this.emoji);
  final String label;
  final String emoji;
}

class SearchResult {
  const SearchResult({
    required this.kind,
    required this.title,
    this.en,
    required this.subtitle,
    this.chapterId,
    this.lessonId,
    this.termId,
    this.flashcardId,
    this.score = 0,
  });

  final SearchKind kind;
  final String title;

  /// Équivalent anglais, quand il existe.
  final String? en;
  final String subtitle;
  final String? chapterId;
  final String? lessonId;
  final String? termId;
  final String? flashcardId;
  final int score;

  SearchResult _withScore(int s) => SearchResult(
    kind: kind,
    title: title,
    en: en,
    subtitle: subtitle,
    chapterId: chapterId,
    lessonId: lessonId,
    termId: termId,
    flashcardId: flashcardId,
    score: s,
  );
}

class _Entry {
  _Entry(this.result, List<String?> names, List<String?> body)
    : names = [
        for (final n in names)
          if (n != null && n.trim().isNotEmpty) fold(n),
      ],
      body = fold(body.whereType<String>().join(' '));

  final SearchResult result;

  /// Titres (français, anglais, sigle), pondérés fortement.
  final List<String> names;

  /// Texte complémentaire (définition, verso, détail), pondéré faiblement.
  final String body;

  /// Bonus selon le type : un terme du glossaire passe avant une mention.
  int get kindBonus => switch (result.kind) {
    SearchKind.term => 12,
    SearchKind.chapter => 10,
    SearchKind.lesson => 8,
    SearchKind.section => 4,
    SearchKind.flashcard => 3,
    SearchKind.mindNode => 2,
  };
}

/// Recherche dans tout le contenu, en français comme en anglais, sans tenir
/// compte des accents ni des majuscules.
class SearchIndex {
  SearchIndex(ContentLibrary library) {
    final terms = TermIndex(library.glossary);
    // Le glossaire cumule les chapitres : un même terme peut y figurer deux
    // fois. On n'en garde qu'un résultat.
    final seenTerms = <String>{};
    for (final t in library.glossary) {
      if (!seenTerms.add(fold(t.termEn).trim())) continue;
      _entries.add(
        _Entry(
          SearchResult(
            kind: SearchKind.term,
            title: t.acronym == null ? t.termFr : '${t.acronym} · ${t.termFr}',
            en: t.termEn,
            subtitle: t.definition,
            termId: t.id,
          ),
          [t.termFr, t.termEn, t.acronym],
          [t.definition, t.example],
        ),
      );
    }
    for (final m in library.modules) {
      for (final c in m.chapters) {
        _entries.add(
          _Entry(
            SearchResult(
              kind: SearchKind.chapter,
              title: c.title,
              en: c.titleEn,
              subtitle: c.available
                  ? 'Module ${m.number} · ${m.title}'
                  : 'Module ${m.number} · bientôt disponible',
              chapterId: c.id,
            ),
            [c.title, c.titleEn],
            [m.title, m.titleEn],
          ),
        );
        for (final l in c.lessons) {
          _entries.add(
            _Entry(
              SearchResult(
                kind: SearchKind.lesson,
                title: l.title,
                subtitle: c.title,
                chapterId: c.id,
                lessonId: l.id,
              ),
              [l.title],
              l.objectives,
            ),
          );
          for (final b in l.blocks) {
            final name = switch (b.type) {
              BlockType.heading => b.text,
              BlockType.definition ||
              BlockType.important ||
              BlockType.practice ||
              BlockType.risk ||
              BlockType.socCase ||
              BlockType.diagram => b.title,
              _ => null,
            };
            if (name == null || name.trim().isEmpty) continue;
            _entries.add(
              _Entry(
                SearchResult(
                  kind: SearchKind.section,
                  title: name,
                  en: terms.englishFor(name),
                  subtitle: '${l.title} · ${c.title}',
                  chapterId: c.id,
                  lessonId: l.id,
                ),
                [name, terms.englishFor(name)],
                [b.text, ...b.items],
              ),
            );
          }
        }
        for (final f in c.flashcards) {
          _entries.add(
            _Entry(
              SearchResult(
                kind: SearchKind.flashcard,
                title: f.front,
                en: terms.englishFor(f.front) ?? terms.englishFor(f.concept),
                subtitle: f.back,
                chapterId: c.id,
                flashcardId: f.id,
              ),
              [f.front, terms.englishFor(f.front)],
              [f.back, f.concept],
            ),
          );
        }
        void walk(MindNode n, int depth) {
          if (depth > 0) {
            final en = n.en ?? terms.englishFor(n.label);
            _entries.add(
              _Entry(
                SearchResult(
                  kind: SearchKind.mindNode,
                  title: n.label,
                  en: en,
                  subtitle: n.detail ?? c.title,
                  chapterId: c.id,
                ),
                [n.label, en],
                [n.detail],
              ),
            );
          }
          for (final k in n.children) {
            walk(k, depth + 1);
          }
        }

        if (c.mindMap != null) walk(c.mindMap!, 0);
      }
    }
  }

  final _entries = <_Entry>[];

  /// Résultats triés du plus pertinent au moins pertinent.
  List<SearchResult> query(String query, {int limit = 80}) {
    final words = fold(query)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    final phrase = words.join(' ');
    final hits = <SearchResult>[];
    for (final e in _entries) {
      var score = 0;
      var allFound = true;
      for (final w in words) {
        var best = 0;
        for (final n in e.names) {
          if (n == w) {
            best = 100;
          } else if (n.startsWith(w)) {
            best = best < 60 ? 60 : best;
          } else if (RegExp('(^|[^a-z0-9])${RegExp.escape(w)}').hasMatch(n)) {
            best = best < 45 ? 45 : best;
          } else if (n.contains(w)) {
            best = best < 30 ? 30 : best;
          }
        }
        if (best == 0 && e.body.contains(w)) best = 8;
        if (best == 0) {
          allFound = false;
          break;
        }
        score += best;
      }
      if (!allFound) continue;
      if (words.length > 1 && e.names.any((n) => n.contains(phrase))) {
        score += 50;
      }
      hits.add(e.result._withScore(score + e.kindBonus));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }
}
