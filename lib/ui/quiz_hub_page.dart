import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../data/progress_store.dart';
import '../logic/quiz_engine.dart';
import '../models/content.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('QCM et examens')),
      body: ReadingList(
        children: [
          const SectionTitle('Entraînement par chapitre'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                  FilledButton.icon(
                    onPressed: _chapterId == null
                        ? null
                        : () => startPractice(
                            context,
                            chapterId: _chapterId!,
                            levels: _levels,
                            count: _count,
                            timed: _timed,
                          ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Commencer'),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Reprise des erreurs'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.replay),
              title: Text(
                state.stats.wrongQuestionIds.isEmpty
                    ? 'Aucune erreur en cours'
                    : '${state.stats.wrongQuestionIds.length} question(s) à reprendre',
              ),
              subtitle: const Text(
                'Les questions dont votre dernière réponse était fausse.',
              ),
              trailing: const Icon(Icons.chevron_right),
              enabled: state.stats.wrongQuestionIds.isNotEmpty,
              onTap: () => startRetry(context),
            ),
          ),
          const SectionTitle('Examen blanc'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                    onSelectionChanged: (s) =>
                        setState(() => _examSize = s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Durée : ${formatDuration(examDuration(info, _examSize))}',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: available == 0
                        ? null
                        : () => startExam(context, _examSize),
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('Démarrer l\'examen blanc'),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Tentatives d\'examen blanc'),
          ..._examHistory(context, state),
        ],
      ),
    );
  }

  List<Widget> _examHistory(BuildContext context, AppState state) {
    final exams = state.stats.sessions
        .where((s) => s.mode == SessionMode.exam)
        .toList()
        .reversed
        .toList();
    if (exams.isEmpty) {
      return [const Text('Aucune tentative pour l\'instant.')];
    }
    final pass = state.library.examInfo.passingScore;
    return [
      Card(
        child: Column(
          children: [
            for (final e in exams)
              ListTile(
                title: Text(
                  '${e.score}/100 · ${e.score >= pass ? 'réussi' : 'non atteint'}',
                ),
                subtitle: Text(
                  '${formatDate(e.finishedAt)} · ${e.total} questions · '
                  '${formatDuration(Duration(seconds: e.durationSeconds))}',
                ),
              ),
          ],
        ),
      ),
    ];
  }
}
