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

  test('un mot du texte d\'une leçon (ici un tableau) est retrouvé', () {
    final hits = search
        .query('Shor')
        .where((r) => r.kind == SearchKind.section)
        .toList();
    expect(hits, isNotEmpty);
    final hit = hits.firstWhere((r) => r.lessonId == 'm2c2-l3');
    expect(hit.blockIndex, isNotNull);
    expect(hit.subtitle, startsWith('« '));
    expect(hit.subtitle, contains('Shor'));
    final lesson = library
        .chapter('m2c2')
        .lessons
        .firstWhere((l) => l.id == 'm2c2-l3');
    expect(lesson.blocks[hit.blockIndex!].type, BlockType.heading);
  });

  test(
    'chaque paragraphe de chaque leçon est atteignable par la recherche',
    () {
      for (final c in library.chapters) {
        for (final l in c.lessons) {
          for (final b in l.blocks.where((b) => b.type == BlockType.text)) {
            // Un mot rare du paragraphe : le plus long.
            final word = (b.text!.split(
              RegExp(r"[^\wÀ-ÿ'-]+"),
            )..sort((a, b) => b.length.compareTo(a.length))).first;
            final found = search
                .query(word, limit: 100000)
                .any((r) => r.lessonId == l.id);
            expect(found, isTrue, reason: '« $word » dans ${l.id}');
          }
        }
      }
    },
  );

  test('findAll ignore accents et majuscules, et garde les positions', () {
    const text = 'La Sécurité et la securite.';
    final ranges = findAll(text, 'securité');
    expect(ranges, hasLength(2));
    expect(text.substring(ranges[0].$1, ranges[0].$2), 'Sécurité');
    expect(text.substring(ranges[1].$1, ranges[1].$2), 'securite');
    expect(findAll(text, '  '), isEmpty);
    // Seulement en début de mot.
    expect(findAll('anniversaires et RSA', 'rsa'), [(17, 20)]);
  });

  test('l\'extrait cite le passage autour du mot', () {
    final text = '${'mot ' * 40}chiffrement asymétrique ${'fin ' * 40}';
    final e = excerpt(text, fold('asymetrique'))!;
    expect(e, contains('chiffrement asymétrique'));
    expect(e, startsWith('… '));
    expect(e, endsWith(' …'));
    expect(e.length, lessThan(160));
  });

  test('la recherche couvre aussi fiches, QCM et préparation examen', () {
    // Fiche de révision du module 11 : NIS 2 et ses délais.
    final sheet = search
        .query('rapport final')
        .where((r) => r.kind == SearchKind.sheet);
    expect(sheet.map((r) => r.chapterId), contains('m5c5'));
    expect(sheet.first.subtitle, startsWith('«'));
    // Une question du QCM se retrouve par son énoncé.
    final q = library.chapter('m3c4').questions.first;
    final hits = search.query(q.prompt);
    expect(
      hits.where((r) => r.kind == SearchKind.question).map((r) => r.questionId),
      contains(q.id),
    );
    // Les questions de préparation fournies par l'apprenant aussi.
    final prep = library.examPrep.questions.first;
    expect(
      search
          .query(prep.prompt.fr)
          .where((r) => r.kind == SearchKind.prep)
          .map((r) => r.questionId),
      contains(prep.id),
    );
  });

  test('chaque chapitre, y compris les nouveaux, est trouvable', () {
    for (final (term, chapter) in [
      ('NIS 2', 'm5c5'),
      ('post-quantique', 'm2c4'),
      ('téléphonie', 'm3c4'),
      ('TOCTOU', 'm4c3'),
      ('injection d\'instructions', 'm1c5'),
      ('EU-CyCLONe', 'm5c5'),
    ]) {
      final hits = search.query(term, limit: 200);
      expect(hits.map((h) => h.chapterId), contains(chapter), reason: term);
    }
    for (final c in library.chapters) {
      final hits = search.query(c.title);
      expect(
        hits.where((h) => h.kind == SearchKind.chapter).map((h) => h.chapterId),
        contains(c.id),
        reason: c.id,
      );
    }
  });
}
