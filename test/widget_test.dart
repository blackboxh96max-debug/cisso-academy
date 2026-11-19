import 'dart:io';
import 'dart:math';

import 'package:cisso_academy/app_info.dart';
import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/main.dart';
import 'package:cisso_academy/logic/study_groups.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/app_menu.dart';
import 'package:cisso_academy/ui/flashcards_page.dart';
import 'package:cisso_academy/ui/lesson_page.dart';
import 'package:cisso_academy/ui/chapter_page.dart';
import 'package:cisso_academy/ui/courses_page.dart';
import 'package:cisso_academy/ui/dashboard_page.dart';
import 'package:cisso_academy/ui/mind_map_page.dart';
import 'package:cisso_academy/ui/quiz_page.dart';
import 'package:cisso_academy/ui/quiz_result_page.dart';
import 'package:cisso_academy/ui/search_page.dart';
import 'package:cisso_academy/ui/about_page.dart';
import 'package:cisso_academy/ui/assistant_page.dart';
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

  testWidgets('à propos : auteur, version et mention non officielle', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('À propos'));
    await tester.pumpAndSettle();
    expect(find.text('Créée par $appAuthor'), findsOneWidget);
    expect(find.text(appAuthorTitle), findsOneWidget);
    expect(find.text('Version $appVersion'), findsOneWidget);
    expect(find.text('APPLICATION NON OFFICIELLE'), findsOneWidget);
    expect(
      find.textContaining('ni affiliée à MILE2 ou à ORSYS'),
      findsOneWidget,
    );
    final modulesLine = find.text(
      '${library.modules.length} modules, '
      '${library.chapters.length} chapitres',
    );
    await tester.scrollUntilVisible(
      modulesLine,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text(
        '${library.modules.length} modules, '
        '${library.chapters.length} chapitres',
      ),
      findsOneWidget,
    );
    expect(
      find.text('${library.examQuestions.length} questions de QCM originales'),
      findsOneWidget,
    );
    // Menu de la page : rubrique « L'examen ».
    await tester.scrollUntilVisible(
      find.byKey(const Key('about-menu')),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('L\'examen'));
    await tester.pumpAndSettle();
    final info = library.examInfo;
    expect(find.byKey(const Key('about-exam')), findsOneWidget);
    expect(
      find.text('Seuil de réussite : ${info.passingScore}/100.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('${info.questionCount} questions à choix multiples'),
      findsOneWidget,
    );
    final domainsTable = find.byKey(const Key('about-domains'));
    await tester.scrollUntilVisible(
      domainsTable,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    for (final d in library.domains) {
      expect(
        find.descendant(of: domainsTable, matching: find.text(d.nameFr)),
        findsOneWidget,
      );
    }
    expect(library.domains.fold<int>(0, (n, d) => n + d.weight), 100);
    final source = find.byKey(const Key('about-exam-source'));
    await tester.scrollUntilVisible(
      source,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      tester.widget<Text>(source).data,
      contains('vérifiée le 16/11/2026'),
    );
    // Rubrique « Nouveautés » : la plus récente en premier.
    await tester.scrollUntilVisible(
      find.byKey(const Key('about-menu')),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Nouveautés'));
    await tester.pumpAndSettle();
    expect(
      find.text(newsTitle(appNews.first.$1, appNews.first.$2)),
      findsOneWidget,
    );
    // La dernière entrée des Nouveautés porte la version de l'application,
    // et chaque entrée a une version plus haute que la suivante.
    expect(appNews.first.$1, appVersion);
    List<int> parts(String v) => v.split('.').map(int.parse).toList();
    for (var i = 0; i + 1 < appNews.length; i++) {
      final a = parts(appNews[i].$1), b = parts(appNews[i + 1].$1);
      final cmp = a[0] != b[0]
          ? a[0] - b[0]
          : a[1] != b[1]
          ? a[1] - b[1]
          : a[2] - b[2];
      expect(cmp, greaterThan(0), reason: appNews[i].$1);
    }
    expect(tester.takeException(), isNull);
    // La version affichée est celle du pubspec.
    final pubspec = await tester.runAsync(
      () => File('pubspec.yaml').readAsString(),
    );
    expect(pubspec, contains('version: $appVersion+'));
    expect(pubspec, contains(appAuthor));
  });

  testWidgets('pied de page : auteur et version sur chaque écran principal', (
    tester,
  ) async {
    await pumpApp(tester);
    for (final label in ['Accueil', 'Cours', 'QCM', 'Révisions', 'Glossaire']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(appFooterText), findsOneWidget, reason: label);
    }
    expect(appFooterText, contains('© 2026 Samir ACHAHOD'));
    expect(appFooterText, contains('v$appVersion'));
    expect(appFooterText, contains('non officielle'));
    // Un appui ouvre « À propos ».
    await tester.tap(find.text(appFooterText));
    await tester.pumpAndSettle();
    expect(find.text('Créée par $appAuthor'), findsOneWidget);
  });

  testWidgets('menu de gauche (téléphone) : écrans, réglages, réinitialiser', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    await state.markLessonRead('m1c1-l1');
    await tester.pumpAndSettle();
    expect(state.readLessons, isNotEmpty);
    // Le menu ☰ existe aussi sur les autres écrans principaux.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Glossaire'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ouvrir le menu').hitTestable());
    await tester.pumpAndSettle();
    final drawer = find.byType(Drawer);
    for (final a in AppAction.values) {
      expect(
        find.descendant(of: drawer, matching: find.text(a.label)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: drawer, matching: find.text(appFooterText)),
      findsOneWidget,
    );
    // Aller à un écran depuis le menu.
    await tester.tap(find.descendant(of: drawer, matching: find.text('Cours')));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    // Réinitialiser depuis le menu : confirmation puis effacement.
    await tester.tap(find.byTooltip('Ouvrir le menu').hitTestable());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Réinitialiser ma progression'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réinitialiser ma progression'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Effacer'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(state.readLessons, isEmpty);
    // Réglages depuis le menu.
    await tester.tap(find.byTooltip('Ouvrir le menu').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();
    expect(find.text('Animations'), findsOneWidget);
  });

  testWidgets('rail (grand écran) : actions et pied de page', (tester) async {
    await pumpApp(tester, size: const Size(1280, 800));
    final rail = find.byType(NavigationRail);
    for (final a in AppAction.values) {
      expect(
        find.descendant(of: rail, matching: find.byTooltip(a.label)),
        findsOneWidget,
      );
    }
    expect(find.byTooltip('Ouvrir le menu'), findsNothing);
    expect(find.text(appFooterText), findsOneWidget);
    await tester.tap(
      find.descendant(of: rail, matching: find.byTooltip('À propos')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Créée par $appAuthor'), findsOneWidget);
    // L'examen est une rubrique d'À propos, pas une entrée du menu.
    expect(
      find.descendant(of: rail, matching: find.text('Examen')),
      findsNothing,
    );
    await tester.tap(find.text('L\'examen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-exam')), findsOneWidget);
    // Recherche et assistant s'ouvrent depuis le menu, à côté de lui.
    for (final (a, page) in [
      (AppAction.search, SearchPage),
      (AppAction.assistant, AssistantPage),
    ]) {
      await tester.tap(
        find.descendant(of: rail, matching: find.byTooltip(a.label)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(page), findsOneWidget);
      expect(rail, findsOneWidget);
    }
  });

  testWidgets('navigation vers chaque onglet', (tester) async {
    await pumpApp(tester);
    for (final label in ['Cours', 'QCM', 'Révisions', 'Glossaire']) {
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

  testWidgets('rail : reste visible dans une leçon, se réduit et se masque', (
    tester,
  ) async {
    final state = await pumpApp(tester, size: const Size(1280, 800));
    final rail = find.byKey(const Key('side-rail'));
    // Une leçon s'ouvre à côté du menu, qui reste affiché.
    await tester.tap(find.text('Prochaine révision recommandée'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonPage), findsOneWidget);
    expect(rail, findsOneWidget);
    expect(find.text(appFooterText), findsOneWidget);

    // Pas de bouton pour étendre ou réduire : seulement « Masquer », tout
    // en bas du menu, sous ses entrées.
    expect(find.byTooltip('Étendre le menu'), findsNothing);
    expect(find.byTooltip('Réduire le menu'), findsNothing);
    final hide = find.byKey(const Key('menu-hide'));
    expect(hide, findsOneWidget);
    expect(
      tester.getTopLeft(hide).dy,
      greaterThan(tester.getBottomLeft(rail).dy - 1),
    );
    expect(tester.widget<NavigationRail>(rail).extended, isFalse);

    // Masquer : une languette permet de le rouvrir.
    await tester.tap(find.byTooltip('Masquer le menu'));
    await tester.pumpAndSettle();
    expect(rail, findsNothing);
    expect(state.menuMode, MenuMode.hidden);
    expect(find.byType(LessonPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('show-menu')));
    await tester.pumpAndSettle();
    expect(rail, findsOneWidget);

    // Le retour du système referme la leçon, pas l'application.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LessonPage), findsNothing);
    expect(find.byType(DashboardPage), findsOneWidget);

    // Un appui sur l'onglet en cours ramène à son début.
    await tester.tap(find.text('Prochaine révision recommandée'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: rail, matching: find.text('Accueil')));
    await tester.pumpAndSettle();
    expect(find.byType(LessonPage), findsNothing);
  });

  test('rail : le mode choisi est gardé au redémarrage', () async {
    final store = MemoryProgressStore();
    final first = AppState(library: library, store: store);
    await first.refresh();
    expect(first.menuMode, MenuMode.compact);
    await first.setMenuMode(MenuMode.hidden);
    final second = AppState(library: library, store: store);
    await second.refresh();
    expect(second.menuMode, MenuMode.hidden);
  });

  testWidgets('lire une leçon la marque comme lue', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.text('Prochaine révision recommandée'));
    await tester.pumpAndSettle();
    expect(find.text('OBJECTIFS DE LA LEÇON'), findsOneWidget);
    final button = find.text('J\'ai terminé : leçon suivante');
    await tester.scrollUntilVisible(
      button,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(state.readLessons, contains('m1c1-l1'));
    // On enchaîne directement sur la leçon suivante.
    final second = library.chapter('m1c1').lessons[1].title;
    expect(find.text(second), findsWidgets);
  });

  for (final view in CourseView.values) {
    testWidgets('leçon : précédente et suivante dans l\'ordre ${view.name}', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await state.setCourseView(view);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prochaine révision recommandée'));
      await tester.pumpAndSettle();
      final lessons = library.lessonOrder(view);
      expect(lessons.first.id, 'm1c1-l1');
      // Précédente désactivée sur la toute première leçon.
      final prev = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      expect(prev.onPressed, isNull);
      // On avance jusqu'à la première leçon du chapitre suivant.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Leçon suivante'));
        await tester.pumpAndSettle();
      }
      expect(find.text(lessons[3].title), findsWidgets);
      final chapter = library.chapters.firstWhere(
        (c) => c.lessons.contains(lessons[3]),
      );
      // Le numéro suit la vue : rang de la leçon dans son module.
      final place = lessonPlace(library, view, lessons[3].id);
      expect(find.text('Leçon ${place.number}/${place.total}'), findsOneWidget);
      expect(
        find.text('Chapitre ${chapterNumber(library, chapter)}'),
        findsOneWidget,
      );
      // MILE2 : après le module 1 vient « Lois, éthique » (module 2 du
      // livre) ; ORSYS : le management de la sécurité (chapitre 1.2).
      expect(chapter.id, view == CourseView.mile2 ? 'm5c3' : 'm1c2');
      await tester.tap(find.byTooltip('Leçon précédente'));
      await tester.pumpAndSettle();
      expect(find.text(lessons[2].title), findsWidgets);
      // Les pages ne s'empilent pas : un retour ramène au tableau de bord.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Prochaine révision recommandée'), findsOneWidget);
    });
  }

  for (final view in CourseView.values) {
    testWidgets(
      'accueil : un module ouvre le cours sur ce module (${view.name})',
      (tester) async {
        final state = await pumpApp(tester);
        await state.setCourseView(view);
        await tester.pumpAndSettle();
        // La liste des modules de l'accueil est repliée au départ.
        final toggle = find.byTooltip('Déplier la liste des modules');
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        final card = find.descendant(
          of: find.byType(DashboardPage),
          matching: find.text('Module 4'),
        );
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(CoursesPage), findsOneWidget);
        // Même découpage que l'accueil : le 4e module de la vue choisie.
        final label = library.outline(view).modules[3].label;
        final banner = find.descendant(
          of: find.byType(CoursesPage),
          matching: find.text(label),
        );
        expect(banner, findsOneWidget);
        // L'en-tête du module est à l'écran, en haut de la page.
        final top = tester.getTopLeft(banner).dy;
        final height =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(top, greaterThan(0));
        expect(top, lessThan(height / 2));
        expect(label, 'Module 4');
        // Ce module est déplié, les autres restent repliés.
        final firstSection = view == CourseView.mile2 ? 'Section 1' : 'Thème 1';
        expect(find.textContaining('$firstSection · '), findsWidgets);
      },
    );
  }

  testWidgets('cours : vues « Livre MILE2 », « ORSYS » et « ORSYS enrichi »', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Cours'),
      ),
    );
    await tester.pumpAndSettle();
    // Par défaut, l'ordre du livre, modules repliés.
    expect(find.text('Section 1 · Définitions du risque'), findsNothing);
    expect(find.text('Prérequis'), findsOneWidget);
    // Un module se déplie d'un geste…
    await tester.tap(find.text('Module 1').first);
    await tester.pumpAndSettle();
    expect(find.text('Section 1 · Définitions du risque'), findsOneWidget);
    await tester.tap(find.text('Tout replier'));
    await tester.pumpAndSettle();
    expect(find.text('Section 1 · Définitions du risque'), findsNothing);
    // … ou tous ensemble : sections officielles et leçons reliées.
    await tester.tap(find.text('Tout déplier'));
    await tester.pumpAndSettle();
    expect(find.text('Section 1 · Définitions du risque'), findsOneWidget);
    expect(find.text('Risk Definitions'), findsWidgets);
    final link = find
        .text('Les briques du risque et le processus de gestion')
        .first;
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('OBJECTIFS DE LA LEÇON'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Toutes les sections du livre ont désormais leur leçon, jusqu'au
    // module 11.
    expect(
      find.textContaining('Toutes les sections ont une leçon.'),
      findsOneWidget,
    );
    final list = find
        .descendant(
          of: find.byType(CoursesPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final m11 = find.text(
      'Section 1 · L\'environnement européen de la cybersécurité',
    );
    for (var i = 0; i < 30 && m11.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    expect(m11, findsOneWidget);
    expect(
      find.text('L\'environnement européen de la cybersécurité'),
      findsWidgets,
    );
    expect(find.text('Leçon à venir'), findsNothing);
    // Programme ORSYS tel quel : ses thèmes, sans les ajouts du livre.
    await tester.drag(list, const Offset(0, 40000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ORSYS'));
    await tester.pumpAndSettle();
    expect(state.courseView, CourseView.orsys);
    await tester.tap(find.text('Tout déplier'));
    await tester.pumpAndSettle();
    expect(
      find.text('Thème 1 · Gestion des risques : évaluation et réponses'),
      findsOneWidget,
    );
    expect(find.text('+ MILE2'), findsNothing);
    expect(find.text('Comprendre la sécurité de l\'information'), findsNothing);
    // Version enrichie : les ajouts du livre sont signalés, mémorisée.
    await tester.drag(list, const Offset(0, 40000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ORSYS enrichi'));
    await tester.pumpAndSettle();
    expect(state.courseView, CourseView.orsysPlus);
    await tester.tap(find.text('Tout déplier'));
    await tester.pumpAndSettle();
    expect(await state.store.setting('courseView'), 'orsysPlus');
    final added = find.text('Comprendre la sécurité de l\'information');
    for (var i = 0; i < 10 && added.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(added, findsOneWidget);
    expect(find.text('+ MILE2'), findsWidgets);
  });

  testWidgets('recherche dans le texte puis dans la leçon ouverte', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Rechercher').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Voisin');
    await tester.pumpAndSettle();
    // Le mot n'est que dans le corps d'un encadré : on voit le passage.
    expect(find.textContaining('Mon Voisin', findRichText: true), findsWidgets);
    await tester.tap(find.text('Les cinq briques').first);
    await tester.pumpAndSettle();
    // La leçon s'ouvre avec la recherche déjà remplie et le passage montré.
    expect(find.byKey(const Key('lesson-find')), findsOneWidget);
    final status = tester.widget<Text>(
      find.byKey(const Key('lesson-find-status')),
    );
    expect(status.data, matches(RegExp(r'^1/\d+$')));
    // Nouvelle recherche dans la même leçon.
    await tester.enterText(find.byKey(const Key('lesson-find')), 'risque');
    await tester.pumpAndSettle();
    final count = tester.widget<Text>(
      find.byKey(const Key('lesson-find-status')),
    );
    expect(count.data, matches(RegExp(r'^\d+ passages$')));
    await tester.tap(find.byTooltip('Passage suivant'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('lesson-find-status'))).data,
      matches(RegExp(r'^1/\d+$')),
    );
    // Fermer la recherche enlève la barre.
    await tester.tap(find.byTooltip('Fermer la recherche dans la leçon'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lesson-find')), findsNothing);
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
    await tester.tap(find.text('🇫🇷 ${single.choices[wrong]}'));
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
      await tester.tap(find.text('🇫🇷 ${multiple.choices[c]}'));
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
    await tester.tap(find.text('🇫🇷 ${q.choices[q.correct.first]}'));
    await tester.pump();
    expect(find.text('Bonne réponse'), findsNothing);
    await tester.tap(find.text('Voir le résultat'));
    await tester.pumpAndSettle();
    expect(find.text('100/100'), findsOneWidget);
    expect(state.stats.sessions.single.mode, SessionMode.exam);
  });

  testWidgets('flashcards : une révision est enregistrée', (tester) async {
    final state = await pumpApp(tester, size: const Size(800, 2400));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Révisions'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Répétition espacée : cartes du jour'),
    );
    await tester.tap(find.text('Répétition espacée : cartes du jour'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FlashcardsPage),
        matching: find.textContaining('carte(s)'),
      ),
    );
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
    await tester.tap(find.text('ORSYS enrichi'));
    await tester.pumpAndSettle();
    expect(find.text('Module 1'), findsOneWidget);
    await tester.tap(find.text('Tout déplier'));
    await tester.pumpAndSettle();
    final list = find
        .descendant(
          of: find.byType(CoursesPage),
          matching: find.byType(Scrollable),
        )
        .first;
    // Descendre jusqu'au dernier chapitre : le programme est complet,
    // plus aucun chapitre n'est verrouillé.
    final last = find.text('Sécurité physique et environnementale');
    for (var i = 0; i < 20 && last.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -800));
      await tester.pumpAndSettle();
    }
    expect(last, findsWidgets);
    expect(find.text('🔒 Bientôt disponible'), findsNothing);
    for (var i = 0; i < 25; i++) {
      await tester.drag(list, const Offset(0, 2000));
      await tester.pumpAndSettle();
    }

    final first = find.text('Gestion, analyse et traitement des risques');
    await tester.ensureVisible(first);
    await tester.pumpAndSettle();
    await tester.tap(first);
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

  testWidgets('révisions : trois supports, filtre par module', (tester) async {
    await pumpApp(tester, size: const Size(800, 2400));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Révisions'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Répétition espacée : cartes du jour'), findsOneWidget);
    expect(find.text('Réviser le module'), findsWidgets);
    // Vue du livre MILE2 par défaut : 11 modules et Prérequis, repliés.
    expect(find.widgetWithText(ChoiceChip, '🧰 Prérequis'), findsOneWidget);
    expect(find.text('Réviser'), findsNothing);
    await tester.tap(find.text('Tout déplier'));
    await tester.pumpAndSettle();
    expect(find.text('Réviser'), findsWidgets);
    await tester.tap(find.text('Tout replier'));
    await tester.pumpAndSettle();
    expect(find.text('Réviser'), findsNothing);

    await tester.tap(find.text('📋 Fiches'));
    await tester.pumpAndSettle();
    expect(find.text('PDF du module'), findsWidgets);
    expect(find.text('Réviser le module'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(ChoiceChip),
        matching: find.textContaining('Module 2'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Module 1 ·'), findsNothing);
    expect(find.textContaining('Module 2 ·'), findsOneWidget);
    // Le module choisi est déplié : ses fiches sont à l'écran.
    expect(find.text('Ouvrir'), findsWidgets);

    await tester.tap(find.text('🧠 Cartes mentales'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tous les modules'));
    await tester.pumpAndSettle();
    expect(find.text('Toute la formation'), findsOneWidget);
  });

  testWidgets('recherche : un terme anglais retrouve le glossaire', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Rechercher').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'separation of duties');
    await tester.pumpAndSettle();
    expect(find.text('SoD · Séparation des tâches'), findsWidgets);
    await tester.tap(find.text('SoD · Séparation des tâches').first);
    await tester.pumpAndSettle();
    expect(find.text('Separation of duties'), findsWidgets);
  });
}
