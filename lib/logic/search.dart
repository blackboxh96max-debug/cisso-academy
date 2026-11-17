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
    this.blockIndex,
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

  /// Bloc de la leçon où se trouve le passage, pour y aller directement.
  final int? blockIndex;
  final int score;

  SearchResult _withScore(int s, {String? subtitle}) => SearchResult(
    kind: kind,
    title: title,
    en: en,
    subtitle: subtitle ?? this.subtitle,
    chapterId: chapterId,
    lessonId: lessonId,
    termId: termId,
    flashcardId: flashcardId,
    blockIndex: blockIndex,
    score: s,
  );
}

class _Entry {
  _Entry(this.result, List<String?> names, List<String?> body)
    : names = [
        for (final n in names)
          if (n != null && n.trim().isNotEmpty) fold(n),
      ],
      rawBody = body.whereType<String>().join(' '),
      body = fold(body.whereType<String>().join(' '));

  final SearchResult result;

  /// Texte complémentaire tel qu'affiché, pour en citer un extrait.
  final String rawBody;

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
          // Chaque partie de la leçon (d'un intertitre au suivant) est
          // indexée avec tout son texte : paragraphes, listes, encadrés,
          // tableaux. Les encadrés titrés ont aussi leur propre résultat.
          String? sectionTitle;
          var sectionStart = 0;
          final sectionText = <String?>[];
          void closeSection() {
            final title = sectionTitle ?? l.title;
            if (sectionText.whereType<String>().isEmpty) return;
            _entries.add(
              _Entry(
                SearchResult(
                  kind: SearchKind.section,
                  title: title,
                  en: terms.englishFor(title),
                  subtitle: '${l.title} · ${c.title}',
                  chapterId: c.id,
                  lessonId: l.id,
                  blockIndex: sectionStart,
                ),
                sectionTitle == null ? [] : [title, terms.englishFor(title)],
                List.of(sectionText),
              ),
            );
          }

          for (final (i, b) in l.blocks.indexed) {
            if (b.type == BlockType.heading) {
              closeSection();
              sectionTitle = b.text;
              sectionStart = i;
              sectionText.clear();
              continue;
            }
            sectionText.addAll(blockSearchText(b));
            final name = switch (b.type) {
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
                  blockIndex: i,
                ),
                [name, terms.englishFor(name)],
                [b.text, ...b.items],
              ),
            );
          }
          closeSection();
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
      String? bodyHit;
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
        if (best == 0 && e.body.contains(w)) {
          best = 8;
          bodyHit ??= w;
        }
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
      // Trouvé dans le texte : on montre le passage plutôt que le résumé.
      final snippet = bodyHit == null || e.result.kind != SearchKind.section
          ? null
          : excerpt(e.rawBody, bodyHit);
      hits.add(
        e.result._withScore(
          score + e.kindBonus,
          subtitle: snippet == null
              ? null
              : '« $snippet »\n${e.result.subtitle}',
        ),
      );
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }
}

/// Tout le texte lisible d'un bloc de leçon.
List<String?> blockSearchText(LessonBlock b) => [
  b.title,
  b.text,
  ...b.items,
  for (final row in b.rows) ...row,
];

/// Positions (début, fin) de [query] dans [text], en début de mot, sans
/// tenir compte des accents ni des majuscules.
List<(int, int)> findAll(String text, String query) {
  final q = fold(query.trim());
  if (q.isEmpty) return const [];
  final t = fold(text);
  // fold garde une lettre pour une lettre : les positions correspondent.
  if (t.length != text.length) return const [];
  final out = <(int, int)>[];
  var from = 0;
  while (true) {
    final i = t.indexOf(q, from);
    if (i < 0) break;
    // Seulement en début de mot : « rsa » ne surligne pas « anniversaire ».
    final startsWord = i == 0 || !RegExp(r'[a-z0-9]').hasMatch(t[i - 1]);
    if (startsWord) out.add((i, i + q.length));
    from = i + (startsWord ? q.length : 1);
  }
  return out;
}

/// Un extrait d'environ [radius] caractères de chaque côté du mot trouvé.
String? excerpt(String text, String foldedWord, {int radius = 60}) {
  final t = fold(text);
  final i = t.indexOf(foldedWord);
  if (i < 0 || t.length != text.length) return null;
  var start = (i - radius).clamp(0, text.length);
  var end = (i + foldedWord.length + radius).clamp(0, text.length);
  if (start > 0) {
    final space = text.indexOf(' ', start);
    if (space >= 0 && space < i) start = space + 1;
  }
  if (end < text.length) {
    final space = text.lastIndexOf(' ', end);
    if (space > i + foldedWord.length) end = space;
  }
  return '${start > 0 ? '… ' : ''}${text.substring(start, end).trim()}${end < text.length ? ' …' : ''}';
}
