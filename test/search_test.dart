import 'package:cisso_academy/logic/search.dart';
import 'package:cisso_academy/logic/terms.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;
  late SearchIndex search;
  late TermIndex terms;

  setUpAll(() async {
    library = await loadRealContent();
    search = SearchIndex(library);
    terms = TermIndex(library.glossary);
  });

  test('un terme anglais de l\'ebook retrouve le terme français', () {
    final hits = search.query('separation of duties');
    expect(hits.first.kind, SearchKind.term);
    expect(hits.first.title, contains('Séparation des tâches'));
    expect(hits.first.en, 'Separation of duties');
  });

  test('la recherche ignore accents et majuscules', () {
    final a = search.query('separation des taches').first;
    final b = search.query('SÉPARATION DES TÂCHES').first;
    expect(a.title, b.title);
  });

  test('un sigle donne le terme du glossaire en premier', () {
    final hits = search.query('siem');
    expect(hits.first.kind, SearchKind.term);
    expect(hits.first.termId, 'siem');
    expect(hits.map((h) => h.kind).toSet(), contains(SearchKind.flashcard));
  });

  test('les titres de chapitres se trouvent en français et en anglais', () {
    expect(
      search.query('vulnerability management').map((h) => h.chapterId),
      contains('m2c3'),
    );
    final fr = search.query('certificats et PKI');
    expect(fr.first.kind, SearchKind.chapter);
    expect(fr.first.chapterId, 'm2c2');
    // Un chapitre à venir est trouvé lui aussi.
    expect(
      search.query('zero trust').map((h) => h.chapterId),
      contains('m3c3'),
    );
  });

  test('une recherche vide ne renvoie rien', () {
    expect(search.query('   '), isEmpty);
  });

  test('l\'anglais d\'un terme clé est retrouvé pour un libellé français', () {
    expect(terms.englishFor('Séparation des tâches'), 'Separation of duties');
    expect(
      terms.englishFor('Configuration de référence (baseline)'),
      isNull,
      reason: 'déjà écrit en anglais dans le libellé',
    );
    expect(terms.englishFor('Un libellé inconnu'), isNull);
  });

  test('les termes clés d\'un texte sont repérés une seule fois', () {
    final seen = <String>{};
    const text =
        'La séparation des tâches oblige à une collusion. '
        'La séparation des tâches est préventive.';
    final first = terms.findIn(text, skip: seen);
    final ids = first.map((m) => m.term.id).toList();
    expect(ids, contains('separation-of-duties'));
    expect(ids.where((i) => i == 'separation-of-duties'), hasLength(1));
    final m = first.firstWhere((m) => m.term.id == 'separation-of-duties');
    expect(text.substring(m.start, m.end), 'séparation des tâches');
    // Déjà annoté : le texte suivant ne le répète pas.
    expect(
      terms.findIn(text, skip: seen).map((m) => m.term.id),
      isNot(contains('separation-of-duties')),
    );
  });

  test('un terme présent deux fois au glossaire ne sort qu\'une fois', () {
    final hits = search
        .query('separation of duties')
        .where((r) => r.kind == SearchKind.term)
        .toList();
    expect(hits, hasLength(1));
  });
}
