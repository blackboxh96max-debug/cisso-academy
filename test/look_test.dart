import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/main.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/lesson_page.dart';
import 'package:cisso_academy/ui/notebook/look.dart';
import 'package:cisso_academy/ui/notebook/palette.dart';
import 'package:cisso_academy/ui/notebook/typography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());
  tearDown(() => AppLook.active = AppLook.cahier);

  Future<AppState> pumpApp(
    WidgetTester tester, {
    Size size = const Size(400, 860),
    MemoryProgressStore? store,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(
      library: library,
      store: store ?? MemoryProgressStore(),
    );
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(CissoAcademyApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  test('chaque thème est complet et ses identifiants sont uniques', () {
    expect(AppLook.all.map((l) => l.id).toSet().length, AppLook.all.length);
    expect(AppLook.all.length, greaterThanOrEqualTo(5));
    for (final l in AppLook.all) {
      expect(l.inks.keys.toSet(), Tone.values.toSet(), reason: l.id);
      expect(l.toneEmojis.keys.toSet(), Tone.values.toSet(), reason: l.id);
      expect(l.moduleEmojis.length, 5, reason: l.id);
    }
    // Les polices, émojis et tableaux diffèrent vraiment d'un thème à l'autre.
    expect(AppLook.all.map((l) => l.titleFont).toSet().length, 5);
    expect(AppLook.all.map((l) => l.table).toSet(), TableLook.values.toSet());
    expect(
      AppLook.all.map((l) => l.toneEmojis[Tone.red]).toSet().length,
      greaterThanOrEqualTo(4),
    );
    expect(AppLook.byId('inconnu'), AppLook.cahier);
  });

  test('le thème actif change polices, couleurs, émojis et tracé', () {
    AppLook.active = AppLook.classique;
    expect(Hand.title, 'Lora');
    expect(Hand.tsize(40), closeTo(40 * 0.74, 0.01));
    expect(Tone.red.emoji, '⛔');
    expect(moduleStyle(1).$2, '📕');
    expect(
      toneColors(Tone.blue, Brightness.light).ink,
      AppLook.classique.inks[Tone.blue]!.$1,
    );
    AppLook.active = AppLook.terminal;
    // Thème toujours sombre : encre néon même en mode clair.
    expect(
      toneColors(Tone.green, Brightness.light).ink,
      const Color(0xFF39FF88),
    );
    AppLook.active = AppLook.cahier;
    expect(Hand.title, 'Caveat');
    expect(Tone.red.emoji, Tone.red.classicEmoji);
  });

  testWidgets('réglages : choisir un thème, gardé au redémarrage', (
    tester,
  ) async {
    final store = MemoryProgressStore();
    final state = await pumpApp(tester, store: store);
    await tester.tap(find.byTooltip('Ouvrir le menu').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-look')));
    await tester.pumpAndSettle();
    for (final l in AppLook.all) {
      expect(
        find.byKey(Key('look-${l.id}'), skipOffstage: false),
        findsOneWidget,
      );
    }
    // Le nom du thème, en haut de sa carte.
    final classic = find.descendant(
      of: find.byKey(const Key('look-classique')),
      matching: find.text('Classique'),
    );
    await tester.ensureVisible(classic);
    await tester.pumpAndSettle();
    await tester.tap(classic);
    await tester.pumpAndSettle();
    expect(state.lookId, 'classique');
    expect(AppLook.active, AppLook.classique);
    // Le choix clair / sombre.
    final dark = find.text('Sombre');
    await tester.scrollUntilVisible(
      dark,
      -300,
      scrollable: find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(dark);
    await tester.pumpAndSettle();
    expect(state.brightnessMode, ThemeMode.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme!.textTheme.bodyMedium!.fontFamily, 'Nunito');
    expect(app.theme!.appBarTheme.titleTextStyle!.fontFamily, 'Lora');
    expect(tester.takeException(), isNull);

    final again = AppState(library: library, store: store);
    await tester.runAsync(again.refresh);
    expect(again.lookId, 'classique');
    expect(again.brightnessMode, ThemeMode.dark);
  });

  // Chaque thème affiche l'accueil et une leçon avec tableau, sur téléphone
  // et grand écran, sans débordement.
  for (final look in AppLook.all) {
    for (final size in const [Size(400, 860), Size(1280, 800)]) {
      testWidgets('thème ${look.id} ${size.width.toInt()} px : accueil et '
          'leçon avec tableau', (tester) async {
        final store = MemoryProgressStore();
        await store.setSetting('look', look.id);
        final lesson = library.availableChapters
            .expand((c) => c.lessons)
            .firstWhere((l) => l.blocks.any((b) => b.type == BlockType.table));
        await pumpApp(tester, size: size, store: store);
        expect(AppLook.active, look);
        expect(tester.takeException(), isNull);
        final nav = tester.state<NavigatorState>(find.byType(Navigator).at(1));
        nav.push(
          MaterialPageRoute<void>(builder: (_) => LessonPage(lesson: lesson)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LessonPage), findsOneWidget);
        final title = tester.widget<Text>(
          find.text(lesson.title).hitTestable().first,
        );
        expect(title.style?.fontFamily, look.titleFont);
        final table = find.byType(Table, skipOffstage: false);
        await tester.scrollUntilVisible(
          table.first,
          400,
          scrollable: find
              .descendant(
                of: find.byType(LessonPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
