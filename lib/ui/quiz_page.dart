import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../data/progress_store.dart';
import '../logic/quiz_engine.dart';
import '../models/content.dart';
import 'bilingual.dart';
import 'quiz_result_page.dart';
import 'theme.dart';
import 'widgets.dart';

class QuizConfig {
  const QuizConfig({
    required this.mode,
    required this.title,
    required this.questions,
    this.chapterId,
    this.timeLimit,
  });

  final SessionMode mode;
  final String title;
  final List<Question> questions;
  final String? chapterId;

  /// Null : pas de chronomètre.
  final Duration? timeLimit;

  /// En examen, la correction n'est affichée qu'à la fin.
  bool get feedbackAfterEach => mode != SessionMode.exam;
}

/// Déroulé d'une série de questions.
class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.config, this.random});

  final QuizConfig config;

  /// Aléa injectable (tests) pour l'ordre des choix.
  final Random? random;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final List<List<int>> _order;
  late final List<Set<int>> _selected;
  late final List<bool> _validated;
  late final DateTime _startedAt;
  int _index = 0;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _finishing = false;

  QuizConfig get config => widget.config;
  List<Question> get questions => config.questions;

  @override
  void initState() {
    super.initState();
    final rng = widget.random ?? Random();
    // Ordre des choix mélangé pour éviter d'apprendre une position.
    _order = [
      for (final q in questions)
        List<int>.generate(q.choices.length, (i) => i)..shuffle(rng),
    ];
    _selected = [for (final _ in questions) <int>{}];
    _validated = [for (final _ in questions) false];
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = DateTime.now().difference(_startedAt));
      final limit = config.timeLimit;
      if (limit != null && _elapsed >= limit) _finish(timeUp: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle(int choice) {
    if (_validated[_index]) return;
    final q = questions[_index];
    setState(() {
      final sel = _selected[_index];
      if (q.isMultiple) {
        sel.contains(choice) ? sel.remove(choice) : sel.add(choice);
      } else {
        sel
          ..clear()
          ..add(choice);
      }
    });
  }

  Future<void> _finish({bool timeUp = false}) async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();
    final state = AppScope.read(context);
    final now = DateTime.now();
    final answers = <AnswerRecord>[];
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      // En entraînement, seules les questions validées comptent ; en examen,
      // une question sans réponse compte comme fausse.
      if (config.feedbackAfterEach && !_validated[i]) continue;
      answers.add(
        AnswerRecord(
          questionId: q.id,
          chapterId: q.chapterId,
          domainId: q.domainId,
          concept: q.concept,
          chosen: Set.of(_selected[i]),
          correct: isAnswerCorrect(q, _selected[i]),
          mode: config.mode,
          answeredAt: now,
        ),
      );
    }
    final session = SessionRecord(
      mode: config.mode,
      chapterId: config.chapterId,
      correctCount: answers.where((a) => a.correct).length,
      total: answers.length,
      durationSeconds: now.difference(_startedAt).inSeconds,
      finishedAt: now,
    );
    if (answers.isNotEmpty) await state.saveSession(session, answers);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultPage(
          config: config,
          session: session,
          answers: answers,
          timeUp: timeUp,
        ),
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    final answered =
        _validated.where((v) => v).length +
        (config.feedbackAfterEach
            ? 0
            : _selected.where((s) => s.isNotEmpty).length);
    if (answered == 0) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter la série ?'),
        content: const Text(
          'Vous pouvez terminer maintenant pour enregistrer vos réponses, '
          'ou quitter sans rien enregistrer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter sans enregistrer'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              _finish();
            },
            child: const Text('Terminer et enregistrer'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[_index];
    final validated = _validated[_index];
    final selected = _selected[_index];
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final limit = config.timeLimit;
    final remaining = limit == null ? null : limit - _elapsed;
    final isLast = _index == questions.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave() && mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(config.title),
          actions: [
            if (remaining != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '⏱ ${formatDuration(remaining.isNegative ? Duration.zero : remaining)}',
                    style: text.titleMedium?.copyWith(
                      color: remaining.inSeconds < 60 ? scheme.error : null,
                    ),
                  ),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_index + 1) / questions.length,
            ),
          ),
        ),
        body: ReadingList(
          children: [
            Row(
              children: [
                Text(
                  'Question ${_index + 1}/${questions.length}',
                  style: text.labelLarge,
                ),
                const Spacer(),
                Text(q.level.label, style: text.labelMedium),
              ],
            ),
            const SizedBox(height: 12),
            BiLines(en: q.en?.prompt, fr: q.prompt, style: text.titleMedium),
            if (q.isMultiple) ...[
              const SizedBox(height: 6),
              Text(
                'Plusieurs réponses attendues (${q.correct.length}).',
                style: text.bodySmall?.copyWith(color: scheme.primary),
              ),
            ],
            const SizedBox(height: 16),
            for (final (pos, choice) in _order[_index].indexed)
              _ChoiceTile(
                letter: String.fromCharCode(65 + pos),
                text: q.choices[choice],
                english: q.en?.choices[choice],
                multiple: q.isMultiple,
                selected: selected.contains(choice),
                state: !validated
                    ? _ChoiceState.neutral
                    : q.correct.contains(choice)
                    ? _ChoiceState.correct
                    : selected.contains(choice)
                    ? _ChoiceState.wrong
                    : _ChoiceState.neutral,
                onTap: () => _toggle(choice),
              ),
            if (validated)
              _Feedback(question: q, chosen: selected, order: _order[_index]),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!config.feedbackAfterEach && _index > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _index--),
                    child: const Text('Précédente'),
                  ),
                const Spacer(),
                if (config.feedbackAfterEach && !validated)
                  FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => setState(() => _validated[_index] = true),
                    child: const Text('Valider'),
                  )
                else if (!isLast)
                  FilledButton(
                    onPressed: () => setState(() => _index++),
                    child: const Text('Suivante'),
                  )
                else
                  FilledButton(
                    onPressed: _finish,
                    child: const Text('Voir le résultat'),
                  ),
              ],
            ),
            if (!config.feedbackAfterEach) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Terminer l\'examen '
                    '(${_selected.where((s) => s.isNotEmpty).length}/${questions.length} répondues)',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ChoiceState { neutral, correct, wrong }

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.letter,
    required this.text,
    this.english,
    required this.multiple,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String text;
  final String? english;
  final bool multiple;
  final bool selected;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (state) {
      _ChoiceState.correct => successColor(true, scheme),
      _ChoiceState.wrong => scheme.error,
      _ChoiceState.neutral => selected ? scheme.primary : scheme.outlineVariant,
    };
    final icon = switch (state) {
      _ChoiceState.correct => Icons.check_circle,
      _ChoiceState.wrong => Icons.cancel,
      _ChoiceState.neutral =>
        multiple
            ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
            : (selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: color,
            width: selected || state != _ChoiceState.neutral ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Text(
                  '$letter. ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: BiLines(en: english, fr: text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Correction détaillée : bonne réponse, pourquoi, pourquoi pas les autres.
class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.question,
    required this.chosen,
    required this.order,
  });

  final Question question;
  final Set<int> chosen;
  final List<int> order;

  @override
  Widget build(BuildContext context) {
    return QuestionCorrection(question: question, chosen: chosen, order: order);
  }
}

/// Bloc de correction réutilisé dans l'écran de résultat.
class QuestionCorrection extends StatelessWidget {
  const QuestionCorrection({
    super.key,
    required this.question,
    required this.chosen,
    this.order,
  });

  final Question question;
  final Set<int> chosen;

  /// Ordre d'affichage des choix (pour les lettres) ; ordre d'origine sinon.
  final List<int>? order;

  String _letter(int choice) {
    final pos = (order ?? List.generate(question.choices.length, (i) => i))
        .indexOf(choice);
    return String.fromCharCode(65 + pos);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ok = isAnswerCorrect(question, chosen);
    final en = question.en;
    final correctList = question.correct.toList()
      ..sort((a, b) => _letter(a).compareTo(_letter(b)));
    final wrongList = [
      for (var i = 0; i < question.choices.length; i++)
        if (!question.correct.contains(i)) i,
    ]..sort((a, b) => _letter(a).compareTo(_letter(b)));

    return Card(
      color: (ok ? successColor(true, scheme) : scheme.error).withValues(
        alpha: 0.08,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Petit effet de réussite (désactivable dans les réglages).
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: ok && animationsOn(context) ? 0.3 : 1,
                    end: 1,
                  ),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Icon(
                    ok ? Icons.check_circle : Icons.cancel,
                    color: successColor(ok, scheme),
                    size: ok ? 30 : 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok
                        ? 'Bonne réponse'
                        : chosen.isEmpty
                        ? 'Sans réponse'
                        : 'Réponse incorrecte',
                    style: text.titleSmall,
                  ),
                ),
                if (question.fromTraining)
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Text('🎯'),
                    label: Text('Ta formation'),
                  )
                else
                  SourceBadge(question.kind),
              ],
            ),
            const SizedBox(height: 8),
            BiLines(
              en: en == null
                  ? null
                  : 'Right answer: ${correctList.map((c) => '${_letter(c)}. ${en.choices[c]}').join(' ; ')}',
              fr: 'Bonne réponse : ${correctList.map((c) => '${_letter(c)}. ${question.choices[c]}').join(' ; ')}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Pourquoi', style: text.labelLarge),
            BiLines(en: en?.explanation, fr: question.explanation),
            if (question.whyNot.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Pourquoi pas les autres', style: text.labelLarge),
            ],
            for (final i in wrongList.where(question.whyNot.containsKey))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: BiLines(
                  en: en?.whyNot[i] == null
                      ? null
                      : '${_letter(i)}. ${en!.whyNot[i]}',
                  fr: '${_letter(i)}. ${question.whyNot[i] ?? ''}',
                  style: chosen.contains(i)
                      ? TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        )
                      : null,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Notion : ${question.concept}',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
