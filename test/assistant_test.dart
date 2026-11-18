import 'package:cisso_academy/app_state.dart';
import 'package:cisso_academy/data/progress_store.dart';
import 'package:cisso_academy/logic/assistant.dart';
import 'package:cisso_academy/main.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/assistant_page.dart';
import 'package:cisso_academy/ui/lesson_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  late ContentLibrary library;
  late Assistant assistant;

  setUpAll(() async {
    library = await loadRealContent();
    assistant = Assistant(library);
  });

  test('normalisation : accents, majuscules, pluriels', () {
    expect(tokenize('Les Vulnérabilités'), tokenize('vulnerabilite'));
    expect(tokenize('Quelle est la clé ?'), ['cle']);
    expect(stem('policies'), stem('policy'));
  });

  test('langue de la question', () {
    expect(Assistant.isEnglish('What is a SIEM?'), isTrue);
    expect(Assistant.isEnglish('Qu\'est-ce qu\'un SIEM ?'), isFalse);
  });

  test('un sigle donne sa définition et la leçon qui en parle', () {
    final a = assistant.ask('Qu\'est-ce que l\'ALE ?');
    expect(a.terms.map((t) => t.acronym), contains('ALE'));
    expect(a.uncertain, isFalse);
    final lesson = a.hits.firstWhere(
      (h) => h.passage.kind == PassageKind.lesson,
    );
    expect(lesson.passage.chapterId, 'm1c1');
    expect(lesson.excerpt, contains('ALE'));
  });

  test('question en anglais : le passage français est retrouvé', () {
    final a = assistant.ask('What is a SIEM?');
    expect(a.english, isTrue);
    expect(a.hits.first.passage.lessonId, 'm2c1-l2');
  });

  test('comparaison de deux notions', () {
    final a = assistant.ask('Différence entre IDS et IPS');
    expect(a.terms.length, 2);
    expect(
      a.hits.take(2).map((h) => h.passage.chapterId),
      everyElement('m3c2'),
    );
  });

  test('une faute de frappe est tolérée', () {
    final a = assistant.ask('chifrement homomorphe');
    expect(
      a.hits.take(3).any((h) => h.passage.text.contains('homomorphe')),
      isTrue,
    );
  });

  test('question hors sujet : réponse signalée comme incertaine', () {
    expect(assistant.ask('quelle est la meilleure pizza').uncertain, isTrue);
    expect(assistant.ask('???').isEmpty, isTrue);
  });

  test('délais NIS 2 : la leçon et ses délais', () {
    final a = assistant.ask('délais de notification NIS 2');
    final texts = a.hits.take(3).map((h) => h.passage.text).join(' ');
    expect(texts, contains('24 h'));
    expect(texts, contains('72 h'));
  });

  testWidgets('écran : question, réponse, lieu dans le cours, leçon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = AppState(library: library, store: MemoryProgressStore());
    await tester.runAsync(state.refresh);
    await tester.pumpWidget(CissoAcademyApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chatbot : poser une question'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantPage), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      'What is a SIEM?',
    );
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();
    final list = find
        .descendant(
          of: find.byType(AssistantPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(list, const Offset(0, 4000));
    await tester.pumpAndSettle();
    // La question (bulle), sa suggestion d'origine et les questions récentes.
    expect(find.text('What is a SIEM?', skipOffstage: false), findsNWidgets(3));
    // La page s'ouvre dans l'onglet (menu visible) : moins de hauteur, d'où
    // des éléments construits mais hors de l'écran.
    expect(find.text('🔤 Définition', skipOffstage: false), findsOneWidget);
    // Lieu selon la vue choisie (livre MILE2 par défaut).
    expect(
      find.textContaining('📍 Livre MILE2 · Module', skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.textContaining('📍 Chapitre 2.1', skipOffstage: false),
      findsWidgets,
    );

    final open = find.text('Ouvrir la leçon', skipOffstage: false).first;
    await tester.scrollUntilVisible(open, 200, scrollable: list);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(LessonPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
