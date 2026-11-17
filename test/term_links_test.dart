import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/logic/terms.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/glossary_page.dart';
import 'package:cisso_academy/ui/lesson_page.dart';
import 'package:cisso_academy/ui/term_links.dart';
import 'package:cisso_academy/ui/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;
  late TermIndex terms;

  setUpAll(() async {
    library = await loadRealContent();
    terms = TermIndex(library.glossary);
  });

  GlossaryTerm term(String id) =>
      library.glossary.firstWhere((t) => t.id == id);

  test('noms tirés d\'un titre de définition', () {
    expect(
      definitionNames('SLE, Single Loss Expectancy (perte unitaire)'),
      containsAll(['SLE', 'Single Loss Expectancy', 'perte unitaire']),
    );
    expect(definitionNames('MAC et HMAC'), containsAll(['MAC', 'HMAC']));
    expect(
      definitionNames('Dépositaire (data custodian)'),
      containsAll(['Dépositaire', 'data custodian']),
    );
  });

  test('chaque terme renvoie à une définition qui existe', () {
    final homes = termHomes(library, terms);
    // Une bonne partie du glossaire est définie dans une leçon.
    expect(homes.length, greaterThan(80));
    for (final MapEntry(key: id, value: home) in homes.entries) {
      final block = home.lesson.blocks[home.block];
      expect(block.type, BlockType.definition, reason: id);
      expect(
        definitionNames(block.title!).any((n) => terms.lookup(n)?.id == id),
        isTrue,
        reason: '$id → ${block.title}',
      );
    }
  });

  test(
    'mots-clés : français, anglais, sigle en majuscules, sans chevauchement',
    () {
      final asset = term('asset');
      final text = 'Un actif critique et ses actifs secondaires.';
      final m = terms.findLinks(text);
      final first = m.firstWhere((x) => x.term.id == asset.id);
      expect(text.substring(first.start, first.end), 'actif');
      expect(first.link, isTrue);
      expect(first.translate, isTrue);
      // Une seule occurrence par texte.
      expect(m.where((x) => x.term.id == asset.id), hasLength(1));

      final withAcronym = library.glossary.firstWhere(
        (t) => (t.acronym ?? '').length >= 3 && !t.termFr.contains(t.acronym!),
      );
      final a = withAcronym.acronym!;
      expect(
        terms.findLinks('Le $a est surveillé.').map((x) => x.term.id),
        contains(withAcronym.id),
      );
      expect(
        terms
            .findLinks('le ${a.toLowerCase()} est surveillé.')
            .where((x) => x.term.id == withAcronym.id),
        isEmpty,
      );
      for (final t in [text, 'Le $a et la gestion des risques.']) {
        final found = terms.findLinks(t);
        for (var i = 1; i < found.length; i++) {
          expect(found[i].start, greaterThanOrEqualTo(found[i - 1].end));
        }
      }
    },
  );

  testWidgets('leçon : un mot-clé ouvre sa fiche puis sa définition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    final homes = termHomes(library, terms);
    // Une leçon qui cite, dans son premier texte, un terme défini ailleurs.
    late Lesson lesson;
    late TermMatch match;
    late String text;
    search:
    for (final l in library.lessons) {
      for (final b in l.blocks) {
        if (b.type != BlockType.text || b.text == null) continue;
        for (final m in terms.findLinks(b.text!)) {
          final home = homes[m.term.id];
          if (home != null && home.lesson.id != l.id) {
            (lesson, match, text) = (l, m, b.text!);
            break search;
          }
        }
        break;
      }
    }
    final home = homes[match.term.id]!;
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: LessonPage(lesson: lesson),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final word = text.substring(match.start, match.end);
    // Le texte du bloc est sélectionnable : on cherche le mot-clé dans son
    // RenderEditable et on appuie au milieu.
    final editable = find.byWidgetPredicate(
      (w) =>
          w is EditableText &&
          w.controller.text.contains(text.substring(0, 20)),
    );
    expect(editable, findsOneWidget);
    await tester.ensureVisible(editable);
    await tester.pumpAndSettle();
    final render = tester.state<EditableTextState>(editable).renderEditable;
    final at = linkOffset(render.text!, word);
    final boxes = render.getBoxesForSelection(
      TextSelection(baseOffset: at, extentOffset: at + word.length),
    );
    final target = render.localToGlobal(boxes.first.toRect().center);
    // Au survol de la souris, la fiche apparaît puis disparaît.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(target);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TermCard), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TermCard), findsNothing);
    await mouse.removePointer();

    await tester.tapAt(target);
    await tester.pumpAndSettle();
    expect(find.byType(TermCard), findsOneWidget);
    expect(find.text(match.term.definition), findsOneWidget);
    await tester.tap(find.text('Voir la définition complète'));
    await tester.pumpAndSettle();
    final page = tester.widget<LessonPage>(find.byType(LessonPage).last);
    expect(page.lesson.id, home.lesson.id);
    expect(page.focusBlock, home.block);
  });

  testWidgets('glossaire : ouvert sur un terme', (tester) async {
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(home: GlossaryPage(initialQuery: 'Actif')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Actif'), findsOneWidget);
    expect(find.textContaining('terme(s)'), findsOneWidget);
    expect(find.text('📚 ${library.glossary.length} terme(s)'), findsNothing);
  });
}

/// Position, dans le texte affiché, du mot-clé cliquable [word].
int linkOffset(InlineSpan root, String word) {
  var pos = 0;
  int? found;
  root.visitChildren((span) {
    if (span is TextSpan && span.text != null) {
      if (span.recognizer != null && span.text == word) {
        found = pos;
        return false;
      }
      pos += span.text!.length;
    }
    return true;
  });
  return found ?? (throw StateError('mot-clé $word introuvable'));
}
