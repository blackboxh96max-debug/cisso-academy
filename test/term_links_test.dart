import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/logic/terms.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/glossary_page.dart';
import 'package:cisso_academy/ui/lesson_page.dart';
import 'package:cisso_academy/ui/term_links.dart';
import 'package:cisso_academy/ui/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
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

  test(
    'sigles multiples et sigles avec « / » : RSSI, CI/CD, ISO/IEC 15408',
    () {
      List<String> ids(String text) =>
          terms.findLinks(text).map((m) => m.term.id).toList();
      expect(ids('Le RSSI valide.'), contains('rssi'));
      expect(ids('Le CISO valide.'), contains('rssi'));
      expect(ids('Une chaîne CI/CD sûre.'), contains('ci-cd'));
      expect(ids('Selon ISO/IEC 15408.'), contains('common-criteria'));
      expect(ids('Un produit EAL4.'), contains('evaluation-assurance-level'));
      expect(ids('Empreinte SHA-256.'), contains('sha-2'));
      // « SHA-2 » ne s'accroche pas au début de « SHA-256 » d'un autre terme.
      expect(ids('MITRE ATT&CK et ATT&CK.'), contains('mitre-attack'));
    },
  );

  test('les mots-clés importants du cours ont tous une infobulle', () {
    const keywords = [
      'RSSI',
      'ISO/IEC 27001',
      'ISO/IEC 27005',
      'NIST',
      'NIST SP 800-53',
      'HTTPS',
      'RDP',
      'DHCP',
      'SHA-256',
      'MD5',
      'ATT&CK',
      'PCA',
      'PRA',
      'ML-KEM',
      'SaaS',
      'IaaS',
      'WPA2',
      'SSID',
      'KDC',
      'LDAPS',
      'SMB',
      'FIPS',
      'EUCC',
      'DDoS',
      'ACL',
      'API',
      'Argon2id',
      'TOE',
    ];
    for (final k in keywords) {
      final m = terms.findLinks('Mot : $k.');
      expect(m, isNotEmpty, reason: k);
      expect('Mot : $k.'.substring(m.first.start, m.first.end), k, reason: k);
    }
    // Chaque bloc « Définition » d'une leçon renvoie à un terme du
    // glossaire, sauf quelques titres qui ne sont pas des termes.
    const notTerms = {
      'Utilisateur (user)',
      'Fonctionnalité et assurance',
      'RAID n\'est pas une sauvegarde',
      'Transferts de données personnelles',
    };
    for (final l in library.lessons) {
      for (final b in l.blocks) {
        if (b.type != BlockType.definition || notTerms.contains(b.title)) {
          continue;
        }
        expect(
          definitionNames(b.title!).any((n) => terms.lookup(n) != null),
          isTrue,
          reason: '${l.id} : ${b.title}',
        );
      }
    }
  });

  test('plan d\'une leçon : liens dans chaque bloc, tableaux et listes '
      'compris', () {
    final homes = termHomes(library, terms);
    var cells = 0, items = 0, steps = 0;
    for (final l in library.lessons) {
      final plan = termPlan(terms, l, homes);
      for (final (i, b) in l.blocks.indexed) {
        for (final MapEntry(key: key, value: matches) in plan.entries) {
          final owner = switch (key) {
            (final LessonBlock o, int _, int _) => o,
            (final LessonBlock o, int _) => o,
            final LessonBlock o => o,
            _ => null,
          };
          if (owner != b) continue;
          final links = matches.where((m) => m.link).toList();
          if (b.type == BlockType.table) cells += links.length;
          if (b.type == BlockType.steps) steps += links.length;
          if (b.type == BlockType.summary || b.type == BlockType.pitfalls) {
            items += links.length;
          }
          // Jamais de lien vers la définition qu'on est en train de lire.
          for (final m in links) {
            final h = homes[m.term.id];
            expect(
              h != null && h.lesson.id == l.id && h.block == i,
              isFalse,
              reason: '${l.id} bloc $i : ${m.term.id}',
            );
          }
          // Un terme n'est cliquable qu'une fois par texte.
          expect(links.map((m) => m.term.id).toSet(), hasLength(links.length));
        }
      }
    }
    expect(cells, greaterThan(100));
    expect(items, greaterThan(50));
    expect(steps, greaterThan(3));

    // Un terme défini dans une leçon est cliquable ailleurs dans la même
    // leçon.
    final rssiLesson = library.lessons.firstWhere(
      (l) => homes.values.any((h) => h.lesson.id == l.id),
    );
    final defined = {
      for (final MapEntry(key: id, value: h) in homes.entries)
        if (h.lesson.id == rssiLesson.id) id,
    };
    final plan = termPlan(terms, rssiLesson, homes);
    expect(
      plan.values
          .expand((m) => m)
          .where((m) => m.link && defined.contains(m.term.id)),
      isNotEmpty,
    );
  });

  testWidgets('leçon : un mot-clé d\'un tableau ouvre sa fiche', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    final homes = termHomes(library, terms);
    late Lesson lesson;
    late TermMatch match;
    late String cell;
    search:
    for (final l in library.lessons) {
      final plan = termPlan(terms, l, homes);
      for (final b in l.blocks.where((b) => b.type == BlockType.table)) {
        for (final (r, row) in b.rows.indexed.skip(1)) {
          for (final (c, text) in row.indexed) {
            final m = plan[(b, r, c)]?.where((m) => m.link) ?? const [];
            if (m.isNotEmpty) {
              (lesson, match, cell) = (l, m.first, text);
              break search;
            }
          }
        }
      }
    }
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
    final word = cell.substring(match.start, match.end);
    final rich = find.byWidgetPredicate(
      (w) =>
          w is RichText &&
          w.text.toPlainText(includeSemanticsLabels: false) == cell,
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      rich.first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final render = tester.renderObject<RenderParagraph>(rich.first);
    final at = linkOffset(render.text, word);
    final boxes = render.getBoxesForSelection(
      TextSelection(baseOffset: at, extentOffset: at + word.length),
    );
    await tester.tapAt(render.localToGlobal(boxes.first.toRect().center));
    await tester.pumpAndSettle();
    expect(find.byType(TermCard), findsOneWidget);
    expect(find.text(match.term.definition), findsOneWidget);
  });

  testWidgets('un terme défini dans la leçon ouverte y est montré sur place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    final homes = termHomes(library, terms);
    // Un terme défini assez loin dans sa leçon.
    final entry = homes.entries.firstWhere((e) => e.value.block > 8);
    final term = library.glossary.firstWhere((t) => t.id == entry.key);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: LessonPage(lesson: entry.value.lesson),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(scroll.pixels, 0);
    tester.state<TermLinksState>(find.byType(TermLinks)).open(term);
    await tester.pumpAndSettle();
    // Pas de nouvelle page : la leçon défile jusqu'à la définition.
    expect(find.byType(LessonPage), findsOneWidget);
    expect(scroll.pixels, greaterThan(0));
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
