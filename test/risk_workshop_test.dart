import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/content/content_loader.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/main.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/risk_workshop_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  test('30 scénarios distincts et cohérents avec les échelles', () {
    final w = library.riskWorkshop;
    expect(w.scenarios, hasLength(30));
    expect(w.scenarios.map((s) => s.id).toSet(), hasLength(30));
    expect(
      w.scenarios.map((s) => '${s.asset.fr}|${s.threat.fr}').toSet(),
      hasLength(30),
    );
    expect(
      [for (final s in w.likelihoodScale) s.value],
      [0.02, 0.10, 0.30, 0.65],
    );
    expect(
      [for (final s in w.impactScale) s.value],
      [3000, 12000, 60000, 240000],
    );
    for (final s in w.scenarios) {
      expect(s.residualScore, lessThan(s.score), reason: s.id);
      expect(w.residualAle(s), lessThan(w.initialAle(s)), reason: s.id);
      expect(s.explanation.en, isNot(s.explanation.fr), reason: s.id);
    }
    // Les niveaux couvrent la matrice : du modéré au critique avant
    // traitement, plus rien d'élevé ni de critique après.
    final before = {for (final s in w.scenarios) s.level};
    expect(before, containsAll([RiskLevel.critical, RiskLevel.high]));
    expect(w.scenarios.where((s) => s.residualScore >= 8), isEmpty);
  });

  test('niveaux, ALE et montants', () {
    expect(RiskLevel.of(3), RiskLevel.low);
    expect(RiskLevel.of(4), RiskLevel.moderate);
    expect(RiskLevel.of(8), RiskLevel.high);
    expect(RiskLevel.of(12), RiskLevel.critical);
    final w = library.riskWorkshop;
    expect(w.ale(3, 4), closeTo(72000, 0.01));
    expect(euros(156000), '156 000 €');
    expect(euros(600), '600 €');
  });

  test('chaque cas propose 4 réponses distinctes dont la bonne', () {
    final w = library.riskWorkshop;
    final rightPlaces = <int>{};
    for (final s in w.scenarios) {
      final ales = aleChoices(w, s);
      expect(ales, hasLength(4), reason: s.id);
      expect(ales.toSet(), hasLength(4), reason: s.id);
      expect(
        ales.where((a) => (a - w.initialAle(s)).abs() < 0.5),
        hasLength(1),
        reason: s.id,
      );
      final controls = controlChoices(w, s);
      expect(controls.map((c) => c.ref).toSet(), hasLength(4), reason: s.id);
      expect(controls.where((c) => c.ref == s.control.ref), hasLength(1));
      rightPlaces.add(controls.indexWhere((c) => c.ref == s.control.ref));
    }
    // La bonne mesure n'est pas toujours à la même place.
    expect(rightPlaces.length, greaterThanOrEqualTo(3));
  });

  test('un scénario dont le risque ne baisse pas est refusé', () {
    final bad = RiskWorkshop.fromJson({
      for (final k in ['intro', 'notice', 'source']) k: {'fr': 'a', 'en': 'b'},
      'likelihood': [
        for (var i = 1; i <= 4; i++)
          {
            'level': i,
            'label': {'fr': 'a', 'en': 'b'},
            'probability': 0.1,
          },
      ],
      'impact': [
        for (var i = 1; i <= 4; i++)
          {
            'level': i,
            'label': {'fr': 'a', 'en': 'b'},
            'loss': 1000,
          },
      ],
      'scenarios': [
        {
          'id': 'X',
          for (final k in [
            'asset',
            'threat',
            'vulnerability',
            'consequence',
            'action',
            'owner',
            'explanation',
          ])
            k: {'fr': 'a', 'en': 'b'},
          'criteria': ['C'],
          'likelihood': 2,
          'impact': 2,
          'residualLikelihood': 2,
          'residualImpact': 2,
          'control': {
            'ref': 'A.8.7',
            'title': {'fr': 'a', 'en': 'b'},
          },
        },
      ],
    });
    expect(() => validateRiskWorkshop(bad), throwsA(isA<FormatException>()));
  });

  testWidgets('matrice : avant et après traitement, filtre par case', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(CissoAcademyApp(state: state));
    await tester.pumpAndSettle();
    openRiskWorkshop(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();

    expect(find.text('Atelier risques'), findsOneWidget);
    Future<void> tap(Finder f) async {
      if (f.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          f,
          -300,
          scrollable: find.byType(Scrollable).last,
        );
      }
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    // Case 3 × 4 : R001 (rançongiciel) et R003 (vol de compte).
    await tap(find.byKey(const Key('cell-3-4')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('risk-R003')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('risk-R001')), findsOneWidget);
    expect(find.byKey(const Key('risk-R002')), findsNothing);

    await tap(find.text('Après traitement'));
    await tap(find.byKey(const Key('cell-3-4')));
    await tester.scrollUntilVisible(
      find.text('Aucun scénario ici.'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    await tap(find.byKey(const Key('risk-language')));
    expect(find.text('Risk workshop'), findsOneWidget);
  });

  testWidgets('étude de cas : noter, choisir la mesure, calculer l\'ALE', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(CissoAcademyApp(state: state));
    await tester.pumpAndSettle();
    openRiskWorkshop(tester.element(find.byType(Scaffold).first), cases: true);
    await tester.pumpAndSettle();

    final w = library.riskWorkshop;
    final s = w.scenarios.first;
    Future<void> tap(Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    await tap(Key('case-l-${s.likelihood}'));
    await tap(Key('case-g-${s.impact}'));
    await tap(const Key('case-rate'));
    expect(find.text('NOTATION ATTENDUE'), findsOneWidget);
    await tap(Key('case-control-${s.control.ref}'));
    final right = aleChoices(
      w,
      s,
    ).indexWhere((a) => (a - w.initialAle(s)).abs() < 0.5);
    await tap(Key('case-ale-$right'));
    expect(find.textContaining('4 / 4'), findsOneWidget);
    await tap(const Key('case-continue'));
    await tester.scrollUntilVisible(
      find.textContaining('Cas 2 sur 30'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('1 terminés, 4/4 points'), findsOneWidget);
  });
}
