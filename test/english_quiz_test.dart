import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/main.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/quiz_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

/// Noms officiels américains, déjà en anglais dans le QCM français.
const _officialNames = {
  'Sensitive But Unclassified',
  'FAIR (Factor Analysis of Information Risk)',
  'Cross-site scripting (XSS)',
};

/// Nombre de questions de chaque module. Un module est traduit en entier ou
/// pas du tout : chaque PR de traduction n'ajoute que ses fichiers anglais.
const _moduleQuestions = {'m1': 135, 'm2': 111, 'm3': 111, 'm4': 91, 'm5': 145};

/// Modules dont la traduction des QCM est déjà livrée.
const _minimumTranslated = ['m1', 'm2', 'm3', 'm4', 'm5'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  Iterable<Chapter> translated() => library.chapters.where(
    (c) => c.questions.any((q) => !q.fromTraining && q.en != null),
  );

  test('QCM traduits : chaque question a sa version anglaise', () {
    final count = <String, int>{};
    for (final c in translated()) {
      for (final q in c.questions.where((q) => !q.fromTraining)) {
        final en = q.en;
        expect(en, isNotNull, reason: q.id);
        expect(en!.prompt, isNot(q.prompt), reason: q.id);
        expect(en.explanation, isNot(q.explanation), reason: q.id);
        expect(en.choices, hasLength(q.choices.length), reason: q.id);
        expect(en.whyNot.keys.toSet(), q.whyNot.keys.toSet(), reason: q.id);
        // Les choix sont traduits, pas recopiés ; seuls les sigles et noms
        // propres (RBAC, Kerberos, ISO/IEC 27001…) restent identiques.
        final same = [
          for (final (i, t) in q.choices.indexed)
            if (t.length > 20 &&
                t == en.choices[i] &&
                !_officialNames.contains(t))
              t,
        ];
        expect(same, isEmpty, reason: q.id);
        count.update(c.moduleId, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    // Chaque module commencé est traduit en entier, chapitre par chapitre.
    for (final MapEntry(key: module, value: n) in count.entries) {
      expect(n, _moduleQuestions[module], reason: module);
    }
    expect(count.keys, containsAll(_minimumTranslated));
  });

  test('QCM anglais : orthographe américaine', () {
    final british = RegExp(
      r'\b(organisation|authoris|defence|centre|behaviour|programme|'
      r'prioritis|analys(e|ed|ing)\b|labelling|catalogue|colour)',
      caseSensitive: false,
    );
    for (final c in translated()) {
      for (final q in c.questions) {
        final en = q.en;
        if (en == null) continue;
        for (final t in [
          en.prompt,
          ...en.choices,
          en.explanation,
          ...en.whyNot.values,
        ]) {
          expect(british.hasMatch(t), isFalse, reason: '${q.id} : $t');
        }
      }
    }
  });

  testWidgets(
    'QCM de chapitre : question et correction dans les deux langues',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final state = AppState(library: library, store: MemoryProgressStore());
      await tester.runAsync(state.refresh);
      await tester.pumpWidget(CissoAcademyApp(state: state));
      await tester.pumpAndSettle();
      final q = library
          .chapter('m1c4')
          .questions
          .firstWhere((q) => q.id == 'm1c4-q01');
      final en = q.en!;
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => QuizPage(
                config: QuizConfig(
                  mode: SessionMode.practice,
                  title: 'Test',
                  questions: [q],
                  chapterId: 'm1c4',
                ),
              ),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('🇬🇧 ${en.prompt}'), findsOneWidget);
      expect(find.text('🇫🇷 ${q.prompt}'), findsOneWidget);
      for (final (i, choice) in q.choices.indexed) {
        expect(find.text('🇬🇧 ${en.choices[i]}'), findsOneWidget);
        expect(find.text('🇫🇷 $choice'), findsOneWidget);
      }

      // Une mauvaise réponse : la correction explique dans les deux langues.
      final wrong = q.whyNot.keys.first;
      await tester.tap(find.text('🇬🇧 ${en.choices[wrong]}'));
      await tester.pump();
      final validate = find.text('Valider');
      await tester.scrollUntilVisible(
        validate,
        300,
        scrollable: find
            .descendant(
              of: find.byType(QuizPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(validate);
      await tester.pumpAndSettle();
      expect(find.text('🇬🇧 ${en.explanation}'), findsOneWidget);
      expect(find.text('🇫🇷 ${q.explanation}'), findsOneWidget);
      expect(find.textContaining(en.whyNot[wrong]!), findsOneWidget);
      expect(find.textContaining(q.whyNot[wrong]!), findsOneWidget);
    },
  );
}
