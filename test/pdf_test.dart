import 'dart:convert';

import 'package:cisso_academy/export/pdf_export.dart';
import 'package:cisso_academy/logic/terms.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/mind_map_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentLibrary library;
  late TermIndex terms;

  setUpAll(() async {
    library = await loadRealContent();
    terms = TermIndex(library.glossary);
  });

  bool isPdf(List<int> bytes) => ascii.decode(bytes.sublist(0, 5)) == '%PDF-';

  test('fiches de révision d\'un module en PDF', () async {
    final m1 = library.module('m1');
    final bytes = await revisionSheetsPdf(
      title: 'Fiches · Module 1',
      chapters: m1.chapters.where((c) => c.available).toList(),
      terms: terms,
    );
    expect(isPdf(bytes), isTrue);
    expect(bytes.length, greaterThan(20000));
  });

  test('flashcards de toute la formation en PDF', () async {
    final bytes = await flashcardsPdf(
      title: 'Flashcards',
      chapters: library.availableChapters.toList(),
      terms: terms,
    );
    expect(isPdf(bytes), isTrue);
  });

  test(
    'plan de la carte mentale en PDF, même pour toute la formation',
    () async {
      final root = withEnglish(courseMindMap(library), terms);
      final bytes = await mindMapPdf(title: 'Toute la formation', root: root);
      expect(isPdf(bytes), isTrue);
      final chapterBytes = await mindMapPdf(
        title: 'Chapitre 1',
        root: withEnglish(chapterMindMap(library.chapter('m1c1')), terms),
      );
      expect(isPdf(chapterBytes), isTrue);
    },
  );

  test('les emoji sont retirés et le nom de fichier est propre', () {
    expect(stripEmoji('🧠 Carte mentale ✓'), 'Carte mentale ✓');
    expect(
      pdfFileName('Fiche : Gestion des risques'),
      'cisso-fiche-gestion-des-risques.pdf',
    );
  });
}
