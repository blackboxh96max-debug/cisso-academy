import 'dart:ui' as ui;

import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/assistant_page.dart';
import 'package:cisso_academy/ui/mascot.dart';
import 'package:cisso_academy/ui/mascot_characters.dart';
import 'package:cisso_academy/ui/notebook/look.dart';
import 'package:cisso_academy/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

final cybi = mascotById('cybi');

void main() {
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  Future<void> pump(WidgetTester tester, {bool reduced = false}) async {
    tester.view.physicalSize = const Size(800, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // Mise en page de référence du test : le thème Cahier.
    AppLook.active = AppLook.cahier;
    addTearDown(() => AppLook.active = AppLook.moderne);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light, AppLook.cahier),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: const AssistantPage(),
        ),
      ),
    );
  }

  MascotMood mood(WidgetTester tester) =>
      tester.widget<Mascot>(find.byKey(const Key('assistant-mascot'))).mood;

  testWidgets('mascotte : attend, écoute, réfléchit, répond, puis attend', (
    tester,
  ) async {
    await pump(tester);
    // Elle apparaît en saluant.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('assistant-mascot')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(mood(tester), MascotMood.idle);
    expect(find.text(cybi.line(MascotMood.idle)), findsOneWidget);

    await tester.enterText(find.byKey(const Key('assistant-input')), 'SIEM');
    await tester.pump();
    expect(mood(tester), MascotMood.listening);
    expect(find.text(cybi.line(MascotMood.listening)), findsOneWidget);

    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pump();
    expect(mood(tester), MascotMood.thinking);
    expect(find.text(cybi.line(MascotMood.thinking)), findsOneWidget);
    // La question s'affiche déjà ; la réponse arrive après la réflexion.
    await tester.pump(const Duration(milliseconds: 400));
    expect(mood(tester), MascotMood.thinking);
    expect(find.text('SIEM', skipOffstage: false), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(mood(tester), MascotMood.answering);
    expect(find.text(cybi.line(MascotMood.answering)), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(mood(tester), MascotMood.idle);
  });

  testWidgets('mascotte : perplexe quand rien n\'est trouvé', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      'zqxwv plorbk',
    );
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 100));
    expect(mood(tester), MascotMood.puzzled);
    await tester.pumpAndSettle();
  });

  testWidgets('animations réduites : réponse immédiate, mascotte immobile', (
    tester,
  ) async {
    await pump(tester, reduced: true);
    // Aucune animation en cours dès l'ouverture.
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.enterText(find.byKey(const Key('assistant-input')), 'SIEM');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pump();
    expect(mood(tester), MascotMood.answering);
    expect(find.text(cybi.line(MascotMood.thinking)), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  test('chaque personnage se dessine dans chaque humeur, clair et sombre', () {
    expect(mascotCharacters.length, greaterThanOrEqualTo(6));
    expect(
      mascotCharacters.map((c) => c.id).toSet(),
      hasLength(mascotCharacters.length),
    );
    for (final c in mascotCharacters) {
      for (final b in Brightness.values) {
        for (final m in MascotMood.values) {
          expect(c.line(m), isNotEmpty);
          final recorder = ui.PictureRecorder();
          MascotPainter(
            c,
            MascotPose(
              mood: m,
              brightness: b,
              breath: 0.5,
              blink: 0.5,
              wave: 0.4,
              nod: 0.1,
              think: 0.3,
              show: 1,
            ),
          ).paint(Canvas(recorder), const Size(96, 115));
          recorder.endRecording().dispose();
        }
      }
    }
    expect(mascotById('inconnu').id, 'cybi');
  });

  testWidgets('choisir une mascotte : liste, aperçu, choix mémorisé', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = MemoryProgressStore();
    var state = AppState(library: library, store: store);
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const AssistantPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(cybi.line(MascotMood.idle)), findsOneWidget);

    await tester.tap(find.byTooltip('Changer de mascotte'));
    await tester.pumpAndSettle();
    expect(find.text('Choisis ta mascotte'), findsOneWidget);
    final last = mascotCharacters.last;
    await tester.scrollUntilVisible(
      find.byKey(Key('mascot-${last.id}')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('mascot-${last.id}')));
    await tester.pumpAndSettle();
    expect(state.mascotId, last.id);
    Navigator.of(tester.element(find.byType(DraggableScrollableSheet))).pop();
    await tester.pumpAndSettle();
    // La bulle prend la voix du personnage choisi.
    expect(find.text(last.line(MascotMood.idle)), findsOneWidget);

    // Le choix est relu au redémarrage.
    state = AppState(library: library, store: store);
    await tester.runAsync(state.refresh);
    expect(state.mascotId, last.id);
  });
}
