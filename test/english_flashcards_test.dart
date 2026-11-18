import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/main.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/flashcards_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

/// Versos identiques dans les deux langues : listes de sigles, de ports ou
/// de noms officiels anglais.
const _sameInBothLanguages = {'m1c2-f10', 'm1c5-f18', 'm3c1-f08', 'm3c1-f09'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  test('Flashcards : chaque carte a sa version anglaise', () {
    final missing = [
      for (final f in library.flashcards)
        if (f.en == null || f.en!.front.isEmpty || f.en!.back.isEmpty) f.id,
    ];
    expect(missing, isEmpty);
    // Le verso est traduit, pas recopié.
    final copied = [
      for (final f in library.flashcards)
        if (f.back.length > 20 &&
            f.en!.back == f.back &&
            !_sameInBothLanguages.contains(f.id))
          f.id,
    ];
    expect(copied, isEmpty);
  });

  test('Flashcards anglaises : orthographe américaine', () {
    final british = RegExp(
      r'\b(organisation|authoris|defence|centre|behaviour|programme|'
      r'prioritis|analys(e|ed|ing)\b|labelling|catalogue|colour)',
      caseSensitive: false,
    );
    for (final f in library.flashcards) {
      for (final t in [f.en!.front, f.en!.back]) {
        expect(british.hasMatch(t), isFalse, reason: '${f.id} : $t');
      }
    }
  });

  testWidgets('Flashcard : recto et verso dans les deux langues', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(CissoAcademyApp(state: state));
    await tester.pumpAndSettle();
    final card = library.flashcards.firstWhere((f) => f.id == 'm1c1-f01');
    final en = card.en!;
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => FlashcardSessionPage(cardIds: [card.id]),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('🇬🇧 ${en.front}'), findsOneWidget);
    expect(find.text('🇫🇷 ${card.front}'), findsOneWidget);

    await tester.tap(find.text('Afficher la réponse'));
    await tester.pumpAndSettle();
    expect(find.text('🇬🇧 ${en.back}'), findsOneWidget);
    expect(find.text('🇫🇷 ${card.back}'), findsOneWidget);
  });
}
