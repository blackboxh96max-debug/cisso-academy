import '../models/content.dart';

/// Une occurrence d'un terme du glossaire dans un texte français.
class TermMatch {
  const TermMatch(this.term, this.start, this.end);

  final GlossaryTerm term;

  /// Position du terme dans le texte d'origine (fin exclue).
  final int start;
  final int end;
}

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

/// Index des termes du glossaire, pour afficher l'anglais à côté du français.
class TermIndex {
  TermIndex(List<GlossaryTerm> glossary) {
    for (final t in glossary) {
      _byKey.putIfAbsent(fold(t.termFr).trim(), () => t);
      _byKey.putIfAbsent(fold(t.termEn).trim(), () => t);
      if (t.acronym != null) {
        _byKey.putIfAbsent(fold(t.acronym!).trim(), () => t);
      }
      final fr = fold(t.termFr).trim();
      // Un terme identique dans les deux langues n'a pas besoin de traduction.
      if (fr.length >= 4 && fr != fold(t.termEn).trim()) {
        _annotable.add((fr, t));
      }
    }
    // Les termes longs d'abord : « gestion des risques » avant « risque ».
    _annotable.sort((a, b) => b.$1.length.compareTo(a.$1.length));
  }

  final _byKey = <String, GlossaryTerm>{};
  final _annotable = <(String, GlossaryTerm)>[];

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
}
