import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/content/content_loader.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/main.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/regulations_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  test('les 15 fiches demandées sont présentes', () {
    final regs = library.regulations;
    expect(regs.sheets.map((s) => s.id), [
      'iso27017',
      'iso27018',
      'iso27701',
      'iec62443',
      'dma',
      'dsa',
      'dga',
      'rgpd',
      'nis2',
      'dora',
      'csa',
      'cra',
      'ii901',
      'igi1300',
      'igi2102',
    ]);
    expect(regs.verifiedOn, isNotEmpty);
  });

  test('chaque fiche est bilingue, courte et pointe vers une source '
      'officielle', () {
    for (final s in library.regulations.sheets) {
      expect(s.essentials.length, inInclusiveRange(3, 6), reason: s.id);
      expect(s.links, isNotEmpty, reason: s.id);
      for (final l in s.links) {
        expect(
          regulationHosts.contains(Uri.parse(l.url).host),
          isTrue,
          reason: l.url,
        );
      }
      for (final b in [s.title, s.definition, s.remember, ...s.essentials]) {
        expect(b.en, isNot(b.fr), reason: '${s.id} : ${b.fr}');
      }
    }
  });

  test('les fiches déjà traitées dans les leçons y renvoient', () {
    final regs = library.regulations;
    expect(regs.sheet('nis2')!.lessons, contains('m5c5-l3'));
    expect(regs.sheet('rgpd')!.lessons, contains('m5c3-l2'));
    expect(regs.sheet('csa')!.lessons, contains('m5c5-l1'));
    expect(regs.sheet('cra')!.lessons, contains('m5c5-l2'));
  });

  test('un lien hors des sites officiels est refusé', () {
    final bad = Regulations.fromJson({
      'intro': {'fr': 'a', 'en': 'b'},
      'notice': {'fr': 'a', 'en': 'b'},
      'verifiedOn': '2026-11-20',
      'groups': [
        {
          'id': 'g',
          'emoji': 'x',
          'title': {'fr': 'a', 'en': 'b'},
          'items': [
            {
              'id': 'x',
              'name': 'X',
              for (final k in [
                'title',
                'nature',
                'reference',
                'status',
                'definition',
                'remember',
              ])
                k: {'fr': 'a', 'en': 'b'},
              'essentials': [
                for (var i = 0; i < 3; i++) {'fr': 'a', 'en': 'b'},
              ],
              'links': [
                {
                  'label': {'fr': 'a', 'en': 'b'},
                  'url': 'https://example.com/',
                },
              ],
            },
          ],
        },
      ],
    });
    expect(
      () => validateRegulations(bad, const {}),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('la page s\'ouvre depuis Cours, déplie une fiche et passe '
      'en anglais', (tester) async {
    tester.view.physicalSize = const Size(400, 860) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(CissoAcademyApp(state: state));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    openRegulations(context, sheetId: 'iec62443');
    await tester.pumpAndSettle();

    expect(find.text('Textes et normes'), findsOneWidget);
    expect(find.text('IEC 62443'), findsOneWidget);
    expect(find.textContaining('Zones et conduits'), findsOneWidget);

    await tester.tap(find.byKey(const Key('regulations-language')));
    await tester.pumpAndSettle();
    expect(state.lessonsInEnglish, isTrue);
    expect(find.text('Laws and standards'), findsOneWidget);
    expect(find.textContaining('Zones and conduits'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('regulations-filter')), 'DORA');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet-dora')), findsOneWidget);
    expect(find.text('IEC 62443'), findsNothing);
  });

  testWidgets('la dernière fiche s\'ouvre et s\'affiche directement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(CissoAcademyApp(state: state));
    await tester.pumpAndSettle();
    openRegulations(
      tester.element(find.byType(Scaffold).first),
      sheetId: 'igi2102',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('II 2100'), findsWidgets);
  });
}
