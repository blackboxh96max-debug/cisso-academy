import 'dart:convert';

import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/content/content_loader.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/export/pdf_export.dart';
import 'package:cisso_academy/main.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/exam_prep_page.dart';
import 'package:cisso_academy/ui/notebook/hand_drawn.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  test('le lot du 16/11/2026 est fidèle à la fiche de l\'apprenant', () {
    final lot = library.examPrep.lots.firstWhere(
      (l) => l.id == 'prep-2026-11-16',
    );
    expect(lot.questions, hasLength(10));
    expect(lot.parts.map((p) => p.title.en), [
      'Risk Management',
      'Legal Concepts',
      'Compliance',
    ]);
    // Lettres des bonnes réponses, dans l'ordre de la fiche.
    expect(lot.questions.map((q) => q.correctLetter).join(), 'BADCBADCBA');
    for (final q in lot.questions) {
      expect(q.choices, hasLength(4));
    }
    expect(lot.questions[2].choices[3].en, r'$40,000');
    expect(lot.questions[2].formula, contains('100,000 × 40%'));
    expect(lot.keywords.map((k) => k.term), contains('CAN-SPAM'));
  });

  test('le lot du 18/11/2026 (questions 11 et 12) est fidèle', () {
    final lot = library.examPrep.lots.firstWhere(
      (l) => l.id == 'prep-2026-11-18',
    );
    expect(lot.questions, hasLength(5));
    expect(lot.questions.map((q) => q.correctLetter).join(), 'CBACD');
    expect(lot.parts.map((p) => p.title.en).last, 'Cryptography');
    // Empreinte SHA-256 de « Hello » (vérifiée avec sha256sum).
    expect(lot.questions[2].formula, contains('185f8db32271fe25'));
    expect(lot.questions[1].choices.map((c) => c.en), [
      'ITIL',
      'COBIT',
      'PCI-DSS',
      'CSA CCM',
    ]);
    expect(lot.keywords.map((k) => k.term), contains('COBIT'));
  });

  test('les questions de préparation restent hors des statistiques', () {
    final prepIds = library.examPrep.questions.map((q) => q.id).toSet();
    final appIds = library.questions.map((q) => q.id).toSet();
    expect(prepIds.intersection(appIds), isEmpty);
  });

  test('un chapitre inconnu dans un lot est refusé', () async {
    final files = <String, String>{};
    Future<String> read(String path) async {
      if (path.endsWith('exam_prep.json')) {
        final data = jsonDecode(await loadFile(path)) as Map<String, dynamic>;
        ((((data['lots'] as List).first as Map)['parts'] as List).first
                    as Map)['questions']
                .first['chapterId'] =
            'm9c9';
        return jsonEncode(data);
      }
      return files[path] ??= await loadFile(path);
    }

    expect(ContentLoader(read).load(), throwsFormatException);
  });

  test('fiche de préparation en PDF', () async {
    final lot = library.examPrep.lots.first;
    final bytes = await examPrepPdf(
      title: lot.title.fr,
      lot: lot,
      questions: lot.questions,
    );
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(15000));
  });

  testWidgets('préparation examen : entraînement bilingue et fiche', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(CissoAcademyApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('QCM'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Préparation examen'));
    await tester.pumpAndSettle();
    final lotRow = find.textContaining(
      RegExp(r' · Gestion des risques et conformité$'),
    );
    await tester.scrollUntilVisible(lotRow, 200);
    expect(lotRow, findsOne);

    // Le bouton de la séance du 16/11.
    final practice = find.descendant(
      of: find.ancestor(of: lotRow, matching: find.byType(HandBox)).first,
      matching: find.text('S\'entraîner'),
    );
    await tester.ensureVisible(practice);
    await tester.pumpAndSettle();
    await tester.tap(practice);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('What is a vulnerability?', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Qu\'est-ce qu\'une vulnérabilité ?',
        findRichText: true,
      ),
      findsOneWidget,
    );

    // Mauvaise réponse (A) : la bonne (B) est donnée avec l'explication.
    final wrong = find.textContaining(
      'An entity that may damage or abuse an asset.',
      findRichText: true,
    );
    await tester.ensureVisible(wrong);
    await tester.pumpAndSettle();
    await tester.tap(wrong);
    await tester.pumpAndSettle();
    final verdict = find.text('❌ Bonne réponse : B');
    await tester.scrollUntilVisible(verdict, 200);
    expect(verdict, findsOneWidget);
    final why = find.textContaining(
      'A vulnerability is a weakness in a system that a threat can exploit.',
      findRichText: true,
    );
    await tester.scrollUntilVisible(why, 200);
    expect(
      find.textContaining(
        'A vulnerability is a weakness in a system that a threat can exploit.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    final answers = await tester.runAsync(state.store.answers);
    expect(answers, isEmpty, reason: 'hors statistiques de l\'application');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('📚 Par chapitre'), -200);
    await tester.tap(find.text('📚 Par chapitre'));
    await tester.pumpAndSettle();
    // Modules de la vue choisie, repliés au départ.
    final chapterRow = find.textContaining('Gestion, analyse et traitement');
    expect(chapterRow, findsNothing);
    await tester.ensureVisible(find.text('Tout déplier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout déplier'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      chapterRow,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ExamPrepPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(chapterRow, findsOne);
    await tester.ensureVisible(find.text('Fiche').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fiche').first);
    await tester.pumpAndSettle();
    expect(find.text('Question 1'), findsOneWidget);
  });
}
