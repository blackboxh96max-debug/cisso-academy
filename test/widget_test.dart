import 'dart:math';

import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/main.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/chapter_page.dart';
import 'package:cisso_academy/ui/courses_page.dart';
import 'package:cisso_academy/ui/mind_map_page.dart';
import 'package:cisso_academy/ui/quiz_page.dart';
import 'package:cisso_academy/ui/quiz_result_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  Future<AppState> pumpApp(
    WidgetTester tester, {
    Size size = const Size(400, 860),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(CissoAcademyApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('le tableau de bord recommande la première leçon', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Prochaine révision recommandée'), findsOneWidget);
    expect(find.textContaining('Les briques du risque'), findsOneWidget);
    expect(find.text('Progression globale'), findsOneWidget);
  });

  testWidgets('navigation vers chaque onglet', (tester) async {
    await pumpApp(tester);
    for (final label in ['Cours', 'QCM', 'Flashcards', 'Glossaire']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Rechercher (français, anglais ou acronyme)'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'SLE');
    await tester.pumpAndSettle();
    expect(find.text('Espérance de perte unitaire'), findsOneWidget);
  });

  testWidgets('rail latéral sur grand écran', (tester) async {
    await pumpApp(tester, size: const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('lire une leçon la marque comme lue', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.text('Prochaine révision recommandée'));
    await tester.pumpAndSettle();
    expect(find.text('OBJECTIFS DE LA LEÇON'), findsOneWidget);
    final button = find.text('J\'ai terminé cette leçon');
    await tester.scrollUntilVisible(
      button,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(state.readLessons, contains('m1c1-l1'));
  });

  testWidgets('entraînement : correction immédiate puis résultat enregistré', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    final qs = library.chapter('m1c1').questions;
    final single = qs.firstWhere((q) => !q.isMultiple);
    final multiple = qs.firstWhere((q) => q.isMultiple);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      MaterialPageRoute(
        builder: (_) => QuizPage(
          random: Random(1),
          config: QuizConfig(
            mode: SessionMode.practice,
            title: 'Test',
            questions: [single, multiple],
            chapterId: 'm1c1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Question 1 : on choisit une mauvaise réponse.
    final wrong = List.generate(
      4,
      (i) => i,
    ).firstWhere((i) => !single.correct.contains(i));
    await tester.tap(find.text(single.choices[wrong]));
    await tester.pump();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Réponse incorrecte'), findsOneWidget);
    expect(find.text('Pourquoi pas les autres'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Suivante'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Suivante'));
    await tester.pumpAndSettle();

    // Question 2 : toutes les bonnes réponses.
    for (final c in multiple.correct) {
      await tester.tap(find.text(multiple.choices[c]));
      await tester.pump();
    }
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Bonne réponse'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Voir le résultat'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Voir le résultat'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizResultPage), findsOneWidget);
    expect(find.text('50/100'), findsOneWidget);
    expect(state.stats.sessions, hasLength(1));
    expect(state.stats.wrongQuestionIds, [single.id]);
  });

  testWidgets('examen blanc : pas de correction avant la fin', (tester) async {
    final state = await pumpApp(tester);
    final q = library.chapter('m1c1').questions.first;
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      MaterialPageRoute(
        builder: (_) => QuizPage(
          config: QuizConfig(
            mode: SessionMode.exam,
            title: 'Examen blanc',
            questions: [q],
            timeLimit: const Duration(minutes: 2),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Valider'), findsNothing);
    expect(find.textContaining('⏱'), findsOneWidget);
    await tester.tap(find.text(q.choices[q.correct.first]));
    await tester.pump();
    expect(find.text('Bonne réponse'), findsNothing);
    await tester.tap(find.text('Voir le résultat'));
    await tester.pumpAndSettle();
    expect(find.text('100/100'), findsOneWidget);
    expect(state.stats.sessions.single.mode, SessionMode.exam);
  });

  testWidgets('flashcards : une révision est enregistrée', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Flashcards'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Réviser'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Afficher la réponse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Correct'));
    await tester.pumpAndSettle();
    expect(state.cards, hasLength(1));
    expect(state.cards.values.single.intervalDays, 1);
  });

  testWidgets('leçon cahier : schémas, encadrés colorés et petit test', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1280, 900));
    await tester.tap(find.text('Prochaine révision recommandée'));
    await tester.pumpAndSettle();
    expect(find.text('SCHÉMA EXPLICATIF'), findsWidgets);
    expect(find.text('DÉFINITION'), findsWidgets);
    expect(find.text('NOTE DU FORMATEUR'), findsOneWidget);
    expect(
      find.text('🗂️'),
      findsOneWidget,
      reason: 'sommaire latéral sur grand écran',
    );
    expect(
      find.bySemanticsLabel(RegExp('Matrice cinq par cinq')),
      findsOneWidget,
    );

    // Petit test : choisir une réponse puis vérifier, sans toucher aux stats.
    final q = library.question('m1c1-q01');
    final choice = find.text(q.choices[q.correct.first]);
    await tester.scrollUntilVisible(
      choice,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vérifier').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bravo'), findsOneWidget);
  });

  testWidgets(
    'réglages : les animations se désactivent et le choix est conservé',
    (tester) async {
      final state = await pumpApp(tester);
      expect(state.animationsSetting, isTrue);
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réglages'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(state.animationsSetting, isFalse);
      expect(
        await tester.runAsync(() => state.store.setting('animations')),
        '0',
      );
    },
  );

  testWidgets('cours, chapitre et fiche suivent le style cahier', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Cours'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Module 1'), findsOneWidget);
    expect(find.text('📖 3 leçons'), findsWidgets);
    final list = find
        .descendant(
          of: find.byType(CoursesPage),
          matching: find.byType(Scrollable),
        )
        .first;
    // Descendre jusqu'aux chapitres à venir, quel que soit leur nombre.
    final locked = find.text('🔒 Bientôt disponible');
    for (var i = 0; i < 20 && locked.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -800));
      await tester.pumpAndSettle();
    }
    expect(locked, findsWidgets);
    for (var i = 0; i < 25; i++) {
      await tester.drag(list, const Offset(0, 2000));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Gestion, analyse et traitement des risques'));
    await tester.pumpAndSettle();
    expect(find.text('Leçons'), findsOneWidget);
    expect(find.text('📖 À lire'), findsNWidgets(3));

    final sheet = find.text('Fiche de révision');
    await tester.scrollUntilVisible(
      sheet,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ChapterPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(sheet);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('points clés à savoir par cœur'),
      findsOneWidget,
    );
  });

  testWidgets('carte mentale : branches dépliables et vue liste', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1280, 900));
    final chapter = library.chapter('m1c1');
    await tester.pumpWidget(
      MaterialApp(
        home: MindMapPage(
          title: 'Carte mentale',
          root: chapterMindMap(chapter),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gestion des risques'), findsOneWidget);
    expect(find.text('📖 Définitions du risque'), findsOneWidget);
    // Les idées de 2e niveau sont visibles, leurs détails repliés.
    expect(find.text('ALE = SLE × ARO'), findsOneWidget);
    expect(find.text('Ex. : 30 000 € × 0,25 = 7 500 € par an'), findsNothing);
    await tester.tap(find.text('ALE = SLE × ARO'));
    await tester.pumpAndSettle();
    expect(find.text('Ex. : 30 000 € × 0,25 = 7 500 € par an'), findsOneWidget);
    // Replier une branche entière.
    await tester.tap(find.text('🔍 Appréciation des risques'));
    await tester.pumpAndSettle();
    expect(find.text('ALE = SLE × ARO'), findsNothing);
    // Vue liste : tout le contenu, branche par branche.
    await tester.tap(find.byTooltip('Voir la liste'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Définitions du risque'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cartes du module et de la formation', (tester) async {
    await pumpApp(tester, size: const Size(1280, 900));
    final m1 = library.module('m1');
    for (final root in [moduleMindMap(m1), courseMindMap(library)]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MindMapPage(title: 'Carte', root: root),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    final course = courseMindMap(library);
    expect(course.children.length, library.modules.length + 1);
    expect(
      course.children.last.children.length,
      library.domains.length,
      reason: 'une feuille par domaine officiel',
    );
    expect(moduleMindMap(m1).children.length, m1.chapters.length);
  });
}
