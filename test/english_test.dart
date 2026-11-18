import 'dart:convert';

import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/content/content_loader.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/logic/terms.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/lesson_page.dart';
import 'package:cisso_academy/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;
  late TermIndex terms;

  setUpAll(() async {
    library = await loadRealContent();
    terms = TermIndex(library.glossary);
  });

  /// Tous les textes d'une leçon, dans l'ordre (titres, listes, cellules…).
  List<String> textsOf(Lesson l) => [
    l.title,
    ...l.objectives,
    for (final b in l.blocks) ...[
      ?b.text,
      ...b.items,
      for (final r in b.rows) ...r,
    ],
  ];

  test('modules 1 à 3 : chaque leçon a sa version anglaise', () {
    for (final c in library.chapters.where(
      (c) => const {'m1', 'm2', 'm3'}.contains(c.moduleId),
    )) {
      expect(
        c.lessonsEn.keys.toSet(),
        c.lessons.map((l) => l.id).toSet(),
        reason: c.id,
      );
      for (final l in c.lessons) {
        final en = library.englishLesson(l.id)!;
        expect(en.blocks, hasLength(l.blocks.length));
        expect(en.title, isNot(l.title));
        // Les textes sont traduits, pas recopiés : seuls restent identiques
        // les noms propres, sigles et références (ISO/IEC 27005…).
        final fr = textsOf(l);
        final tr = textsOf(en);
        final same = [
          for (final (i, t) in fr.indexed)
            if (t.length > 40 && t == tr[i]) t,
        ];
        expect(same, isEmpty, reason: '${l.id} : textes non traduits');
      }
    }
  });

  test('version anglaise : orthographe américaine, celle du glossaire', () {
    final british = RegExp(
      r'\b(organisation|authoris|defence|centre|behaviour|programme|'
      r'prioritis|analys(e|ed|ing)\b|labelling|catalogue|colour)',
      caseSensitive: false,
    );
    for (final c in library.chapters) {
      for (final l in c.lessonsEn.values) {
        for (final t in textsOf(l)) {
          expect(british.hasMatch(t), isFalse, reason: '${l.id} : $t');
        }
      }
    }
  });

  test('une leçon anglaise dont un bloc diffère est refusée', () async {
    final files = <String, String>{};
    Future<String> read(String path) async {
      if (path.endsWith('en/m1c1_risques.json')) {
        final data = jsonDecode(await loadFile(path)) as Map<String, dynamic>;
        final blocks =
            ((data['lessons'] as List).first as Map)['blocks'] as List;
        blocks.removeLast();
        return jsonEncode(data);
      }
      return files[path] ??= await loadFile(path);
    }

    expect(ContentLoader(read).load(), throwsFormatException);
  });

  test('texte anglais : le français suit le mot-clé', () {
    final matches = terms.findLinks(
      'The threat exploits a vulnerability of the asset.',
      english: true,
    );
    final byWord = {for (final m in matches) m.term.id: m};
    final threat = matches.firstWhere((m) => m.translation == 'menace');
    expect(threat.translate, isTrue);
    expect(byWord.values.map((m) => m.translation), contains('actif'));
    // Le français déjà écrit dans le texte n'est pas répété.
    final again = terms.findLinks(
      'The threat (menace) is real.',
      english: true,
    );
    expect(again.where((m) => m.translate), isEmpty);
    // Le rappel de l'anglais entre parenthèses n'est pas répété.
    final mantrap = terms.findLinks(
      'A mantrap stops tailgating.',
      english: true,
    );
    expect(
      mantrap.firstWhere((m) => m.term.termEn == 'Mantrap').translation,
      'sas',
    );
    // Un mot courant au sens large n'est pas traduit par son sens RACI.
    final vague = terms.findLinks(
      "Data remains the customer's responsibility.",
      english: true,
    );
    expect(vague.where((m) => m.translate), isEmpty);
    // En français, rien ne change : l'anglais suit le terme.
    final fr = terms.findLinks('La menace exploite une vulnérabilité.');
    expect(fr.firstWhere((m) => m.translate).translation, 'Threat');
  });

  test('titre de définition : le français vient de la leçon', () {
    expect(terms.frenchFor('Authentication'), 'Authentification');
    expect(terms.frenchFor('Asset (actif)'), isNull);
    // « Accountability » : traçabilité en IAM, responsabilité finale en
    // gouvernance ; chaque leçon garde le sens de sa définition.
    final iam = library.englishLesson('m1c4-l1')!;
    final plan = termPlan(terms, iam, termHomes(library, terms), english: true);
    final labels = {
      for (final ms in plan.values)
        for (final m in ms)
          if (m.translate) m.term.termEn: m.translation,
    };
    expect(labels['Accountability'], 'traçabilité');
  });

  testWidgets('leçon : passer en anglais puis revenir au français', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = MemoryProgressStore();
    final state = AppState(library: library, store: store);
    await tester.runAsync(state.refresh);
    final lesson = library.lessons.firstWhere((l) => l.id == 'm1c1-l1');
    final en = library.englishLesson(lesson.id)!;
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: LessonPage(lesson: lesson),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(lesson.title), findsOneWidget);

    await tester.tap(find.byKey(const Key('lesson-language')));
    await tester.pumpAndSettle();
    expect(find.text(en.title), findsOneWidget);
    expect(find.text(lesson.title), findsNothing);
    expect(await tester.runAsync(() => store.setting('lessonLanguage')), 'en');
    // Le premier mot-clé du texte est suivi du français.
    expect(find.textContaining('(risque)', findRichText: true), findsWidgets);
    // Les étiquettes des blocs passent en anglais.
    expect(find.textContaining('Definition', findRichText: true), findsWidgets);

    await tester.tap(find.byKey(const Key('lesson-language')));
    await tester.pumpAndSettle();
    expect(find.text(lesson.title), findsOneWidget);
    expect(state.lessonsInEnglish, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leçon pas encore traduite : affichée en français, signalée', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.runAsync(() => state.setLessonsInEnglish(true));
    final lesson = library.lessons.firstWhere(
      (l) => library.englishLesson(l.id) == null,
    );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: LessonPage(lesson: lesson),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(lesson.title), findsOneWidget);
    expect(find.byKey(const Key('lesson-english-pending')), findsOneWidget);
    // Le bouton reste là pour revenir au français.
    expect(find.byKey(const Key('lesson-language')), findsOneWidget);
    // Fin des apparitions échelonnées des schémas.
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
