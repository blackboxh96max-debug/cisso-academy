import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'data/progress_store.dart';
import 'logic/assistant.dart';
import 'logic/stats.dart';
import 'models/content.dart';
import 'logic/search.dart';
import 'logic/terms.dart';

/// État partagé de l'application : contenu, stockage et statistiques.
class AppState extends ChangeNotifier {
  AppState({
    required this.library,
    required this.store,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  final ContentLibrary library;

  /// Correspondances français ↔ anglais du glossaire.
  late final TermIndex terms = TermIndex(library.glossary);

  /// Index de la recherche globale.
  late final SearchIndex search = SearchIndex(library);

  /// Assistant de questions, hors ligne.
  late final Assistant assistant = Assistant(library);
  final ProgressStore store;

  /// Horloge injectable (tests).
  final DateTime Function() now;

  ProgressStats? _stats;
  Map<String, CardState> _cards = const {};
  Set<String> _readLessons = const {};

  bool _animations = true;
  CourseView _view = CourseView.mile2;

  /// Vue du programme : livre MILE2, ORSYS ou ORSYS enrichi.
  CourseView get courseView => _view;

  Future<void> setCourseView(CourseView view) async {
    _view = view;
    await store.setSetting('courseView', view.name);
    notifyListeners();
  }

  /// Leçons dans l'ordre de la vue choisie (navigation précédente/suivante).
  List<Lesson> get lessonOrder => library.lessonOrder(_view);

  ProgressStats get stats => _stats!;

  /// Réglage utilisateur : animations activées.
  bool get animationsSetting => _animations;

  Future<void> setAnimations(bool enabled) async {
    _animations = enabled;
    await store.setSetting('animations', enabled ? '1' : '0');
    notifyListeners();
  }

  /// Recherches récentes, la plus récente d'abord (gardées sur l'appareil).
  List<String> get searchHistory => List.unmodifiable(_searches);
  List<String> _searches = [];
  static const searchHistoryMax = 20;

  /// Questions posées à l'assistant, dans l'ordre (la conversation).
  List<String> get assistantHistory => List.unmodifiable(_questions);
  List<String> _questions = [];
  static const assistantHistoryMax = 30;

  static String _key(String s) => normalize(s.trim());

  /// Ajoute une recherche en tête de l'historique (sans doublon).
  Future<void> addSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    _searches = [
      q,
      for (final s in _searches)
        if (_key(s) != _key(q)) s,
    ].take(searchHistoryMax).toList();
    await _saveList('history.search', _searches);
  }

  Future<void> removeSearch(String query) async {
    _searches = [
      for (final s in _searches)
        if (_key(s) != _key(query)) s,
    ];
    await _saveList('history.search', _searches);
  }

  Future<void> clearSearches() async {
    _searches = [];
    await _saveList('history.search', _searches);
  }

  /// Ajoute une question à la conversation de l'assistant.
  Future<void> addQuestion(String question) async {
    final q = question.trim();
    if (q.isEmpty) return;
    _questions = [..._questions, q];
    if (_questions.length > assistantHistoryMax) {
      _questions = _questions.sublist(_questions.length - assistantHistoryMax);
    }
    await _saveList('history.assistant', _questions);
  }

  /// Retire une question (toutes ses occurrences) de la conversation.
  Future<void> removeQuestion(String question) async {
    _questions = [
      for (final q in _questions)
        if (_key(q) != _key(question)) q,
    ];
    await _saveList('history.assistant', _questions);
  }

  Future<void> clearQuestions() async {
    _questions = [];
    await _saveList('history.assistant', _questions);
  }

  Future<void> _saveList(String key, List<String> values) async {
    await store.setSetting(key, jsonEncode(values));
    notifyListeners();
  }

  Future<List<String>> _loadList(String key) async {
    final raw = await store.setting(key);
    if (raw == null) return [];
    try {
      return [
        for (final v in jsonDecode(raw) as List)
          if (v is String) v,
      ];
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  /// Mascotte choisie pour l'assistant (identifiant du personnage).
  String get mascotId => _mascot;
  String _mascot = 'cybi';

  Future<void> setMascot(String id) async {
    _mascot = id;
    await store.setSetting('mascot', id);
    notifyListeners();
  }

  Map<String, CardState> get cards => _cards;
  Set<String> get readLessons => _readLessons;

  /// Relit l'historique local et recalcule les statistiques.
  Future<void> refresh() async {
    _animations = (await store.setting('animations')) != '0';
    // « app » : ancien nom de la vue en 5 modules, devenue « ORSYS enrichi ».
    _view = switch (await store.setting('courseView')) {
      'orsys' => CourseView.orsys,
      'orsysPlus' || 'app' => CourseView.orsysPlus,
      _ => CourseView.mile2,
    };
    _mascot = await store.setting('mascot') ?? 'cybi';
    _searches = await _loadList('history.search');
    _questions = await _loadList('history.assistant');
    final answers = await store.answers();
    final sessions = await store.sessions();
    _cards = await store.cards();
    _readLessons = await store.readLessons();
    _stats = ProgressStats.compute(
      library: library,
      answers: answers,
      sessions: sessions,
      cards: _cards,
      readLessons: _readLessons,
      now: now(),
    );
    notifyListeners();
  }

  Future<void> markLessonRead(String lessonId) async {
    if (_readLessons.contains(lessonId)) return;
    await store.markLessonRead(lessonId, now());
    await refresh();
  }

  /// Enregistre une série terminée et ses réponses.
  Future<void> saveSession(
    SessionRecord session,
    List<AnswerRecord> answers,
  ) async {
    final id = await store.addSession(session);
    await store.addAnswers([
      for (final a in answers)
        AnswerRecord(
          questionId: a.questionId,
          chapterId: a.chapterId,
          domainId: a.domainId,
          concept: a.concept,
          chosen: a.chosen,
          correct: a.correct,
          mode: a.mode,
          answeredAt: a.answeredAt,
          sessionId: id,
        ),
    ]);
    await refresh();
  }

  Future<void> saveCard(CardState state) async {
    await store.saveCard(state);
    await refresh();
  }

  Future<void> resetProgress() async {
    await store.clear();
    await refresh();
  }
}

/// Vrai si les animations doivent être jouées : réglage de l'application
/// et préférence « réduire les animations » du système.
bool animationsOn(BuildContext context) =>
    AppScope.of(context).animationsSetting &&
    !MediaQuery.disableAnimationsOf(context);

/// Donne accès à [AppState] dans l'arbre de widgets.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Accès sans abonnement aux changements (dans les callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
