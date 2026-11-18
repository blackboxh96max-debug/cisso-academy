import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/main.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/revision_sheet_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  test('Fiches : chaque fiche a sa version anglaise, ligne à ligne', () {
    for (final c in library.chapters.where((c) => c.revisionSheet.isNotEmpty)) {
      expect(c.revisionSheetEn.length, c.revisionSheet.length, reason: c.id);
      for (final (i, fr) in c.revisionSheet.indexed) {
        final en = c.revisionSheetEn[i];
        expect(en.trim(), isNotEmpty, reason: '${c.id} ligne $i');
        expect(en.startsWith('# '), fr.startsWith('# '), reason: c.id);
        if (fr.length > 40) {
          expect(en, isNot(fr), reason: '${c.id} ligne $i recopiée');
        }
      }
    }
  });

  test('Fiches anglaises : orthographe américaine', () {
    final british = RegExp(
      r'\b(organisation|authoris|defence|centre|behaviour|programme|'
      r'prioritis|analys(e|ed|ing)\b|labelling|catalogue|colour|licence)',
      caseSensitive: false,
    );
    for (final c in library.chapters) {
      for (final l in c.revisionSheetEn) {
        expect(british.hasMatch(l), isFalse, reason: '${c.id} : $l');
      }
    }
  });

  testWidgets('Fiche : anglais puis français pour chaque point', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(CissoAcademyApp(state: state));
    await tester.pumpAndSettle();
    final chapter = library.chapters.firstWhere((c) => c.id == 'm1c1');
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => RevisionSheetPage(chapter: chapter),
          ),
        );
    await tester.pumpAndSettle();
    expect(
      find.text(chapter.revisionSheetEn.first.substring(2)),
      findsOneWidget,
    );
    expect(
      find.text('🇫🇷 ${chapter.revisionSheet.first.substring(2)}'),
      findsOneWidget,
    );
    expect(find.text('🇬🇧 ${chapter.revisionSheetEn[1]}'), findsOneWidget);
    expect(find.text('🇫🇷 ${chapter.revisionSheet[1]}'), findsOneWidget);
  });
}
