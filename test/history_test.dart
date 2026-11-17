import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/assistant_page.dart';
import 'package:cisso_academy/ui/search_page.dart';
import 'package:cisso_academy/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  /// Un « redémarrage » : nouvel état relu depuis le même stockage.
  Future<AppState> open(ProgressStore store) async {
    final state = AppState(library: library, store: store);
    await state.refresh();
    return state;
  }

  test('recherches : plus récente d\'abord, sans doublon, gardées', () async {
    final store = MemoryProgressStore();
    var state = await open(store);
    await state.addSearch('pare-feu');
    await state.addSearch('SIEM');
    await state.addSearch('  Pare-Feu ');
    await state.addSearch('x'); // trop court
    expect(state.searchHistory, ['Pare-Feu', 'SIEM']);

    state = await open(store);
    expect(state.searchHistory, ['Pare-Feu', 'SIEM']);
    await state.removeSearch('siem');
    expect(state.searchHistory, ['Pare-Feu']);
    for (var i = 0; i < 30; i++) {
      await state.addSearch('terme $i');
    }
    expect(state.searchHistory, hasLength(AppState.searchHistoryMax));
    expect(state.searchHistory.first, 'terme 29');
    await state.clearSearches();
    expect((await open(store)).searchHistory, isEmpty);
  });

  test(
    'assistant : conversation gardée, limitée, historique illisible ignoré',
    () async {
      final store = MemoryProgressStore();
      var state = await open(store);
      for (var i = 0; i < 35; i++) {
        await state.addQuestion('question $i');
      }
      state = await open(store);
      expect(state.assistantHistory, hasLength(AppState.assistantHistoryMax));
      expect(state.assistantHistory.last, 'question 34');
      await state.removeQuestion('QUESTION 34');
      expect(state.assistantHistory.last, 'question 33');

      await store.setSetting('history.assistant', '{pas du json');
      await store.setSetting('history.search', '{"a": 1}');
      state = await open(store);
      expect(state.assistantHistory, isEmpty);
      expect(state.searchHistory, isEmpty);
    },
  );

  Future<void> pump(WidgetTester tester, AppState state, Widget home) async {
    tester.view.physicalSize = const Size(800, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('recherche : récentes affichées, relancées, supprimées', (
    tester,
  ) async {
    final store = MemoryProgressStore();
    var state = AppState(library: library, store: store);
    await tester.runAsync(state.refresh);
    await pump(tester, state, const SearchPage());
    expect(find.text('Recherches récentes'), findsNothing);

    await tester.enterText(find.byType(TextField), 'pare-feu');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SIEM');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(state.searchHistory, ['SIEM', 'pare-feu']);

    // Redémarrage : l'historique est relu depuis le stockage.
    state = AppState(library: library, store: store);
    await tester.runAsync(state.refresh);
    await pump(tester, state, const SizedBox());
    await pump(tester, state, const SearchPage());
    expect(find.text('Recherches récentes'), findsOneWidget);
    expect(find.text('pare-feu'), findsOneWidget);

    // Un appui relance la recherche.
    await tester.tap(find.text('pare-feu'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'pare-feu'), findsOneWidget);
    expect(find.text('Recherches récentes'), findsNothing);

    // Retour au champ vide : la croix supprime une entrée.
    await tester.tap(find.byTooltip('Effacer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Supprimer « SIEM »'));
    await tester.pumpAndSettle();
    expect(state.searchHistory, ['pare-feu']);

    // « Tout effacer » demande confirmation.
    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Effacer'));
    await tester.pumpAndSettle();
    expect(state.searchHistory, isEmpty);
    expect(find.text('Recherches récentes'), findsNothing);
  });

  testWidgets('assistant : la conversation précédente est reprise', (
    tester,
  ) async {
    final store = MemoryProgressStore();
    var state = AppState(library: library, store: store);
    await tester.runAsync(state.refresh);
    await pump(tester, state, const AssistantPage());
    await tester.enterText(find.byType(TextField), 'Qu\'est-ce qu\'un SIEM ?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(state.assistantHistory, ['Qu\'est-ce qu\'un SIEM ?']);

    // Redémarrage : la question et sa réponse reviennent.
    state = AppState(library: library, store: store);
    await tester.runAsync(state.refresh);
    await pump(tester, state, const SizedBox());
    await pump(tester, state, const AssistantPage());
    // La page s'ouvre en bas de la conversation : on remonte.
    await tester.scrollUntilVisible(
      find.text('Questions récentes'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Conversation précédente'), findsOneWidget);
    expect(find.text('Questions récentes'), findsOneWidget);
    expect(find.text('Qu\'est-ce qu\'un SIEM ?'), findsNWidgets(2));

    // Supprimer la question la retire de l'historique et de l'écran.
    await tester.tap(find.byTooltip('Supprimer « Qu\'est-ce qu\'un SIEM ? »'));
    await tester.pumpAndSettle();
    expect(state.assistantHistory, isEmpty);
    expect(find.text('Qu\'est-ce qu\'un SIEM ?'), findsNothing);
    expect(find.text('Conversation précédente'), findsNothing);
  });
}
