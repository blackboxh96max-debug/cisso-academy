import '../models/content.dart';

/// Une occurrence d'un terme du glossaire dans un texte français.
class TermMatch {
  const TermMatch(
    this.term,
    this.start,
    this.end, {
    this.translate = true,
    this.link = false,
    this.french = false,
    this.label,
  });

  final GlossaryTerm term;

  /// Position du terme dans le texte d'origine (fin exclue).
  final int start;
  final int end;

  /// Afficher l'équivalent anglais après le terme.
  final bool translate;

  /// Rendre le terme cliquable (info-bulle et lien vers sa définition).
  final bool link;

  /// Texte anglais : la traduction ajoutée est le terme français.
  final bool french;

  /// Traduction propre à la leçon (celle de sa définition), à la place de
  /// celle du glossaire.
  final String? label;

  /// La traduction à ajouter entre parenthèses après le terme.
  /// En français, la majuscule initiale d'un nom commun tombe au fil du
  /// texte (« Vulnérabilité » → « vulnérabilité ») ; un sigle la garde.
  String get translation {
    if (label != null) return label!;
    if (!french) return term.termEn;
    final fr = term.termFr;
    final common =
        fr.length > 1 &&
        fr[1] == fr[1].toLowerCase() &&
        fr[1] != fr[1].toUpperCase();
    return common ? fr[0].toLowerCase() + fr.substring(1) : fr;
  }

  TermMatch copyWith({bool? translate, bool? link, String? label}) => TermMatch(
    term,
    start,
    end,
    translate: translate ?? this.translate,
    link: link ?? this.link,
    french: french,
    label: label ?? this.label,
  );
}

/// Comment un terme a été reconnu dans le texte.
enum _KeyKind { french, english, acronym }

/// Minuscules sans accents, caractère pour caractère (même longueur que
/// l'entrée), pour retrouver les positions dans le texte d'origine.
String fold(String input) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ’';
  const to = "aaaaaaceeeeiiiinooooouuuuyyoa'";
  final buffer = StringBuffer();
  for (final unit in input.toLowerCase().split('')) {
    final i = from.indexOf(unit);
    buffer.write(i >= 0 ? to[i] : unit);
  }
  return buffer.toString();
}

bool _isWordChar(String ch) => RegExp(r'[a-z0-9]').hasMatch(ch);

/// Les sigles d'un terme, séparés par « / » entre espaces : « CISO / RSSI »
/// → CISO et RSSI ; « CI/CD » reste un seul sigle.
List<String> acronymsOf(GlossaryTerm t) => [
  for (final a in (t.acronym ?? '').split(' / '))
    if (a.trim().isNotEmpty) a.trim(),
];

/// Index des termes du glossaire, pour afficher l'anglais à côté du français.
class TermIndex {
  TermIndex(List<GlossaryTerm> glossary) {
    // Un sigle partagé par deux termes (MAC : contrôle d'accès obligatoire
    // ou code d'authentification de message) est ambigu : il n'est ni
    // cherché seul ni rendu cliquable ; le nom complet, lui, l'est.
    final owners = <String, Set<String>>{};
    for (final t in glossary) {
      for (final a in acronymsOf(t)) {
        (owners[fold(a)] ??= {}).add(t.id);
      }
    }
    final ambiguous = {
      for (final MapEntry(:key, :value) in owners.entries)
        if (value.length > 1) key,
    };
    _ambiguous.addAll(ambiguous);
    for (final t in glossary) {
      _byKey.putIfAbsent(fold(t.termFr).trim(), () => t);
      _byKey.putIfAbsent(fold(t.termEn).trim(), () => t);
      if (t.acronym case final a? when !ambiguous.contains(fold(a).trim())) {
        _byKey.putIfAbsent(fold(a).trim(), () => t);
      }
      for (final a in acronymsOf(t)) {
        if (!ambiguous.contains(fold(a))) _byKey.putIfAbsent(fold(a), () => t);
      }
      final fr = fold(t.termFr).trim();
      // Un terme identique dans les deux langues n'a pas besoin de traduction.
      if (fr.length >= 4 && fr != fold(t.termEn).trim()) {
        _annotable.add((fr, t));
      }
      final en = fold(t.termEn).trim();
      final keys = <(String, _KeyKind, String?)>[
        if (fr.length >= 3) (fr, _KeyKind.french, null),
        if (en.length >= 4 && en != fr) (en, _KeyKind.english, null),
        for (final a in acronymsOf(t))
          if (a.length >= 2 && !ambiguous.contains(fold(a)))
            (fold(a), _KeyKind.acronym, a),
      ];
      for (final (key, kind, exact) in keys) {
        if (_linkKeys.add(key)) _linkable.add((key, t, kind, exact));
      }
    }
    _linkable.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    // Les termes longs d'abord : « gestion des risques » avant « risque ».
    _annotable.sort((a, b) => b.$1.length.compareTo(a.$1.length));
  }

  final _byKey = <String, GlossaryTerm>{};
  final _ambiguous = <String>{};

  /// Vrai si [acronym] désigne plusieurs termes du glossaire.
  bool isAmbiguous(String acronym) => _ambiguous.contains(fold(acronym));
  final _annotable = <(String, GlossaryTerm)>[];
  final _linkKeys = <String>{};
  final _linkable = <(String, GlossaryTerm, _KeyKind, String?)>[];

  /// Le terme dont le nom (français, anglais ou sigle) est exactement [label].
  /// Ce qui est entre parenthèses est ignoré : « SIEM (Security…) » → SIEM.
  GlossaryTerm? lookup(String label) {
    final full = fold(label).trim();
    final hit = _byKey[full];
    if (hit != null) return hit;
    final i = full.indexOf('(');
    if (i > 0) return _byKey[full.substring(0, i).trim()];
    return null;
  }

  /// Le terme anglais à afficher sous [label], ou `null` s'il est inconnu ou
  /// déjà présent dans le libellé.
  String? englishFor(String label) {
    final t = lookup(label);
    if (t == null) return null;
    final folded = fold(label);
    if (folded.contains(fold(t.termEn))) return null;
    return t.termEn;
  }

  /// Le terme français à afficher sous [label] (titre anglais), ou `null`
  /// s'il est inconnu ou déjà présent dans le libellé.
  /// Un titre qui donne déjà le français entre parenthèses (« Asset
  /// (actif) ») n'en reçoit pas d'autre.
  String? frenchFor(String label) {
    if (label.contains('(')) return null;
    final t = lookup(label);
    if (t == null) return null;
    final folded = fold(label);
    if (folded.contains(fold(t.termFr)) ||
        fold(t.termFr).trim() == fold(t.termEn).trim()) {
      return null;
    }
    return t.termFr;
  }

  /// Termes du glossaire présents dans [text], sans chevauchement.
  /// [skip] contient les identifiants déjà annotés (première occurrence
  /// seulement) ; il est complété au passage.
  List<TermMatch> findIn(String text, {Set<String>? skip}) {
    final folded = fold(text);
    final taken = List<bool>.filled(folded.length, false);
    final out = <TermMatch>[];
    for (final (key, term) in _annotable) {
      if (skip != null && skip.contains(term.id)) continue;
      // Déjà écrit en anglais dans le texte : rien à ajouter.
      if (folded.contains(fold(term.termEn))) continue;
      var from = 0;
      while (true) {
        final i = folded.indexOf(key, from);
        if (i < 0) break;
        final end = i + key.length;
        final before = i == 0 || !_isWordChar(folded[i - 1]);
        // On accepte un pluriel en « s » ou « x ».
        var stop = end;
        if (stop < folded.length &&
            (folded[stop] == 's' || folded[stop] == 'x')) {
          stop++;
        }
        final after = stop >= folded.length || !_isWordChar(folded[stop]);
        final free = !taken.sublist(i, stop).contains(true);
        if (before && after && free) {
          for (var k = i; k < stop; k++) {
            taken[k] = true;
          }
          out.add(TermMatch(term, i, stop));
          skip?.add(term.id);
          break;
        }
        from = i + 1;
      }
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  /// Les termes à rendre cliquables dans [text] : la première occurrence de
  /// chaque terme du glossaire, par son nom français, anglais ou son sigle
  /// (sigle en majuscules seulement), sans chevauchement. `translate` dit si
  /// l'équivalent anglais peut être ajouté (nom français, différent de
  /// l'anglais, qui n'est pas déjà écrit dans le texte).
  ///
  /// Pour un texte anglais ([english]), c'est l'inverse : le français est
  /// ajouté après le nom anglais d'un terme, s'il n'est pas déjà écrit.
  List<TermMatch> findLinks(String text, {bool english = false}) {
    final folded = fold(text);
    final taken = List<bool>.filled(folded.length, false);
    final out = <TermMatch>[];
    final found = <String>{};
    for (final (key, term, kind, exact) in _linkable) {
      if (found.contains(term.id)) continue;
      var from = 0;
      while (true) {
        final i = folded.indexOf(key, from);
        if (i < 0) break;
        from = i + 1;
        final end = i + key.length;
        // Un sigle s'écrit en majuscules : « IAM », pas « iam ».
        if (kind == _KeyKind.acronym && text.substring(i, end) != exact) {
          continue;
        }
        var stop = end;
        if (kind != _KeyKind.acronym &&
            stop < folded.length &&
            (folded[stop] == 's' || folded[stop] == 'x')) {
          stop++;
        }
        final before = i == 0 || !_isWordChar(folded[i - 1]);
        final after = stop >= folded.length || !_isWordChar(folded[stop]);
        if (!before || !after || taken.sublist(i, stop).contains(true)) {
          continue;
        }
        for (var k = i; k < stop; k++) {
          taken[k] = true;
        }
        final fr = fold(term.termFr).trim();
        final en = fold(term.termEn).trim();
        out.add(
          TermMatch(
            term,
            i,
            stop,
            link: true,
            french: english,
            translate: english
                ? kind == _KeyKind.english &&
                      !_vagueInEnglish.contains(en) &&
                      fr.length >= 3 &&
                      fr != en &&
                      !folded.contains(fr)
                : kind == _KeyKind.french &&
                      fr.length >= 4 &&
                      fr != en &&
                      !folded.contains(en),
          ),
        );
        found.add(term.id);
        break;
      }
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }
}

/// Mots anglais trop vagues pour recevoir le français sans contexte :
/// « standard » désigne une norme interne dans la pyramide documentaire,
/// mais aussi n'importe quelle norme (« ISO standard »).
const _vagueInEnglish = {'standard'};

/// Les noms qu'un titre de définition peut donner à un terme :
/// « SLE, Single Loss Expectancy (perte unitaire) » → « SLE »,
/// « Single Loss Expectancy », « perte unitaire »… ; « MAC et HMAC » → les
/// deux.
List<String> definitionNames(String title) {
  final parts = <String>[title];
  final open = title.indexOf('(');
  if (open > 0) {
    final close = title.lastIndexOf(')');
    parts.add(title.substring(0, open));
    if (close > open) parts.add(title.substring(open + 1, close));
  }
  final out = <String>[];
  for (final p in parts) {
    out.add(p.trim());
    for (final piece in p.split(RegExp(r',| ou | et '))) {
      final t = piece.trim();
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }
  }
  return out;
}

/// Où un terme est défini dans le cours : la leçon et le numéro du bloc
/// « Définition ».
typedef TermHome = ({Lesson lesson, int block});

final _homes = Expando<Map<String, TermHome>>();

/// Pour chaque terme du glossaire défini dans une leçon, la première
/// définition dans l'ordre du cours (calculé une fois).
Map<String, TermHome> termHomes(ContentLibrary library, TermIndex index) =>
    _homes[library] ??= () {
      final out = <String, TermHome>{};
      for (final lesson in library.lessons) {
        for (final (i, b) in lesson.blocks.indexed) {
          if (b.type != BlockType.definition || b.title == null) continue;
          for (final name in definitionNames(b.title!)) {
            final t = index.lookup(name);
            if (t != null) {
              out.putIfAbsent(t.id, () => (lesson: lesson, block: i));
            }
          }
        }
      }
      return out;
    }();
