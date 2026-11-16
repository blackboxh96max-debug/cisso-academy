import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../data/progress_store.dart';
import '../logic/quiz_engine.dart';
import '../models/content.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'exam_prep_page.dart';
import 'quiz_page.dart';
import 'widgets.dart';

/// Lance un entraînement sur un chapitre.
void startPractice(
  BuildContext context, {
  required String chapterId,
  Set<Level>? levels,
  int? count,
  bool timed = false,
}) {
  final state = AppScope.read(context);
  final chapter = state.library.chapter(chapterId);
  final questions = pickPracticeQuestions(
    chapter.questions,
    levels: levels,
    count: count,
  );
  if (questions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aucune question ne correspond à ces critères.'),
      ),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QuizPage(
        config: QuizConfig(
          mode: SessionMode.practice,
          title: chapter.title,
          questions: questions,
          chapterId: chapterId,
          timeLimit: timed
              ? examDuration(state.library.examInfo, questions.length)
              : null,
        ),
      ),
    ),
  );
}

/// Reprend les questions dont la dernière réponse était fausse.
void startRetry(BuildContext context) {
  final state = AppScope.read(context);
  final ids = state.stats.wrongQuestionIds;
  if (ids.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aucune erreur à reprendre pour l\'instant.'),
      ),
    );
    return;
  }
  final questions = ids.map(state.library.question).toList()..shuffle();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QuizPage(
        config: QuizConfig(
          mode: SessionMode.retry,
          title: 'Reprise des erreurs',
          questions: questions,
        ),
      ),
    ),
  );
}

/// Lance un examen blanc chronométré, réparti selon le poids des domaines.
void startExam(BuildContext context, int count) {
  final state = AppScope.read(context);
  final questions = buildExam(
    state.library.questions,
    state.library.domains,
    count: count,
  );
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QuizPage(
        config: QuizConfig(
          mode: SessionMode.exam,
          title: 'Examen blanc',
          questions: questions,
          timeLimit: examDuration(state.library.examInfo, questions.length),
        ),
      ),
    ),
  );
}

class QuizHubPage extends StatefulWidget {
  const QuizHubPage({super.key});

  @override
  State<QuizHubPage> createState() => _QuizHubPageState();
}

class _QuizHubPageState extends State<QuizHubPage> {
  String? _chapterId;
  final Set<Level> _levels = {};
  int? _count = 10;
  bool _timed = false;
  int _examSize = 20;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final library = state.library;
    final chapters = library.availableChapters.toList();
    _chapterId ??= chapters.isEmpty ? null : chapters.first.id;
    final info = library.examInfo;
    final available = library.questions.length;
    final examSizes = {
      for (final s in [10, 20, 50, info.questionCount])
        if (s <= available) s,
      if (available < info.questionCount) available,
    }.toList()..sort();
    if (!examSizes.contains(_examSize)) _examSize = examSizes.last;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return NotebookPage(
      title: 'QCM et examens',
      children: [
        if (library.examPrep.lots.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => openExamPrep(context),
            child: GradientBanner(
              tone: Tone.pink,
              toTone: Tone.orange,
              seed: 99,
              child: Row(
                children: [
                  const Text('🎓', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Préparation examen',
                          style: TextStyle(
                            fontFamily: Hand.title,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Les questions de ta formation en anglais et en '
                          'français : ${library.examPrep.lots.length} séance(s), '
                          '${library.examPrep.questions.length} questions',
                          style: const TextStyle(
                            fontFamily: Hand.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
        NotePanel(
          title: 'Entraînement par chapitre',
          emoji: '🎯',
          tone: Tone.violet,
          seed: 101,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _chapterId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Chapitre'),
                items: [
                  for (final c in chapters)
                    DropdownMenuItem(value: c.id, child: Text(c.title)),
                ],
                onChanged: (v) => setState(() => _chapterId = v),
              ),
              const SizedBox(height: 16),
              Text('Niveau', style: text.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final l in Level.values)
                    FilterChip(
                      label: Text(l.label),
                      selected: _levels.contains(l),
                      onSelected: (on) => setState(
                        () => on ? _levels.add(l) : _levels.remove(l),
                      ),
                    ),
                ],
              ),
              Text(
                'Aucun niveau sélectionné = tous les niveaux.',
                style: muted,
              ),
              const SizedBox(height: 16),
              Text('Nombre de questions', style: text.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<int?>(
                segments: const [
                  ButtonSegment(value: 10, label: Text('10')),
                  ButtonSegment(value: 20, label: Text('20')),
                  ButtonSegment(value: null, label: Text('Toutes')),
                ],
                selected: {_count},
                onSelectionChanged: (s) => setState(() => _count = s.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mode chronométré'),
                subtitle: Text(
                  'Même rythme que l\'examen : '
                  '${info.secondsPerQuestion.round()} s par question',
                ),
                value: _timed,
                onChanged: (v) => setState(() => _timed = v),
              ),
              const SizedBox(height: 8),
              GradientButton(
                emoji: '▶️',
                label: 'Commencer',
                from: Tone.violet,
                to: Tone.pink,
                onPressed: _chapterId == null
                    ? null
                    : () => startPractice(
                        context,
                        chapterId: _chapterId!,
                        levels: _levels,
                        count: _count,
                        timed: _timed,
                      ),
              ),
            ],
          ),
        ),
        NotePanel(
          title: 'Reprise des erreurs',
          emoji: '🔁',
          tone: Tone.orange,
          seed: 102,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.stats.wrongQuestionIds.isEmpty
                    ? 'Aucune erreur en cours, bravo !'
                    : '${state.stats.wrongQuestionIds.length} question(s) à reprendre',
                style: Hand.bodyText(context),
              ),
              Text(
                'Les questions dont votre dernière réponse était fausse.',
                style: muted,
              ),
              const SizedBox(height: 10),
              GradientButton(
                emoji: '🔁',
                label: 'Reprendre mes erreurs',
                from: Tone.orange,
                to: Tone.pink,
                onPressed: state.stats.wrongQuestionIds.isEmpty
                    ? null
                    : () => startRetry(context),
              ),
            ],
          ),
        ),
        NotePanel(
          title: 'Examen blanc',
          emoji: '⏱️',
          tone: Tone.pink,
          seed: 103,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Conditions proches de l\'examen'),
                  ),
                  const SourceBadge(SourceKind.official),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Examen réel : ${info.questionCount} questions en '
                '${info.durationMinutes} min, seuil ${info.passingScore}/100 '
                '(${info.source}). Ici, le temps est calculé au prorata et '
                'les questions sont réparties selon le poids des domaines.',
                style: muted,
              ),
              if (available < info.questionCount) ...[
                const SizedBox(height: 6),
                Text(
                  'Banque actuelle : $available questions originales. '
                  'L\'examen complet de ${info.questionCount} questions sera '
                  'possible quand la banque sera assez fournie.',
                  style: muted,
                ),
              ],
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: [
                  for (final s in examSizes)
                    ButtonSegment(value: s, label: Text('$s q.')),
                ],
                selected: {_examSize},
                onSelectionChanged: (s) => setState(() => _examSize = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Durée : ${formatDuration(examDuration(info, _examSize))}',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 12),
              GradientButton(
                emoji: '⏱️',
                label: 'Démarrer l\'examen blanc',
                from: Tone.pink,
                to: Tone.orange,
                onPressed: available == 0
                    ? null
                    : () => startExam(context, _examSize),
              ),
            ],
          ),
        ),
        NotePanel(
          title: 'Tentatives d\'examen blanc',
          emoji: '📈',
          tone: Tone.blue,
          seed: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _examHistory(context, state),
          ),
        ),
      ],
    );
  }

  List<Widget> _examHistory(BuildContext context, AppState state) {
    final exams = state.stats.sessions
        .where((s) => s.mode == SessionMode.exam)
        .toList()
        .reversed
        .toList();
    if (exams.isEmpty) {
      return [
        Text(
          'Aucune tentative pour l\'instant : lancez-vous, c\'est le meilleur entraînement !',
          style: Hand.bodyText(context),
        ),
      ];
    }
    final pass = state.library.examInfo.passingScore;
    return [
      for (final e in exams)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Sticker(
                text: e.score >= pass
                    ? '🏆 ${e.score}/100 · réussi'
                    : '💪 ${e.score}/100 · non atteint',
                tone: e.score >= pass ? Tone.green : Tone.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${formatDate(e.finishedAt)} · ${e.total} questions · '
                  '${formatDuration(Duration(seconds: e.durationSeconds))}',
                  style: Hand.sansText(context, size: 13),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}
