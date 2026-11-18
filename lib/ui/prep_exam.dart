part of 'exam_prep_page.dart';

/// Tailles proposées pour l'examen blanc de fin de formation, selon le
/// nombre de questions disponibles (« toutes » si moins de 100).
List<int> prepExamSizes(int available, int official) {
  final sizes = [
    for (final s in const [20, 50]) ?(s < available ? s : null),
    available < official ? available : official,
  ];
  return available == 0 ? const [] : sizes.toSet().toList();
}

/// Tire [count] questions au hasard parmi celles de la formation.
List<PrepQuestion> drawPrepExam(
  List<PrepQuestion> all,
  int count, [
  Random? random,
]) => (List.of(all)..shuffle(random)).take(count).toList();

/// Encadré de l'examen blanc sur la page de préparation : taille, durée,
/// seuil et départ.
class _PrepExamBox extends StatefulWidget {
  const _PrepExamBox({required this.questions});

  final List<PrepQuestion> questions;

  @override
  State<_PrepExamBox> createState() => _PrepExamBoxState();
}

class _PrepExamBoxState extends State<_PrepExamBox> {
  int? _size;

  @override
  Widget build(BuildContext context) {
    final info = AppScope.of(context).library.examInfo;
    final sizes = prepExamSizes(widget.questions.length, info.questionCount);
    if (sizes.isEmpty) return const SizedBox.shrink();
    final size = sizes.contains(_size) ? _size! : sizes.last;
    final duration = examDuration(info, size);
    return NoteBox(
      key: const Key('prep-exam'),
      tone: Tone.violet,
      emoji: '🏁',
      label: 'Examen blanc de fin de formation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comme le jour de l\'examen : des questions de toutes tes séances '
            'tirées au hasard, chronométrées au rythme de l\'examen réel '
            '(${info.questionCount} questions en ${info.durationMinutes} min), '
            'sans correction avant la fin. Seuil de réussite : '
            '${info.passingScore} %.',
            style: Hand.noteText(context),
          ),
          if (widget.questions.length < info.questionCount)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Pour l\'instant ${widget.questions.length} question(s) : '
                'l\'examen complet de ${info.questionCount} questions sera '
                'possible quand tes séances en compteront assez.',
                style: Hand.sansText(
                  context,
                  size: 13,
                ).copyWith(color: Paper.of(context).inkSoft),
              ),
            ),
          const SizedBox(height: 10),
          if (sizes.length > 1)
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final s in sizes)
                  ButtonSegment(value: s, label: Text('$s questions')),
              ],
              selected: {size},
              onSelectionChanged: (s) => setState(() => _size = s.first),
            ),
          const SizedBox(height: 6),
          Text(
            '$size questions · ${formatDuration(duration)}',
            style: Hand.sansText(
              context,
              size: 14,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Center(
            child: GradientButton(
              emoji: '⏱️',
              label: 'Démarrer l\'examen blanc',
              from: Tone.violet,
              to: Tone.blue,
              onPressed: () {
                // Tirage fait une seule fois, avant d'ouvrir la page.
                final drawn = drawPrepExam(widget.questions, size);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PrepExamPage(
                      questions: drawn,
                      timeLimit: duration,
                      passingScore: info.passingScore,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Examen blanc chronométré sur les questions de la formation : on répond à
/// son rythme (retour possible), la correction n'arrive qu'à la fin, avec le
/// score, le seuil, le détail par chapitre et toutes les explications.
///
/// Comme les séances, il reste hors des statistiques de l'application.
class PrepExamPage extends StatefulWidget {
  const PrepExamPage({
    super.key,
    required this.questions,
    required this.timeLimit,
    required this.passingScore,
  });

  final List<PrepQuestion> questions;
  final Duration timeLimit;
  final int passingScore;

  @override
  State<PrepExamPage> createState() => _PrepExamPageState();
}

class _PrepExamPageState extends State<PrepExamPage> {
  late final List<int?> _answers = List.filled(widget.questions.length, null);
  late final DateTime _startedAt;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  int _index = 0;
  bool _done = false;
  bool _timeUp = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = DateTime.now().difference(_startedAt));
      if (_elapsed >= widget.timeLimit) _finish(timeUp: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish({bool timeUp = false}) {
    _timer?.cancel();
    setState(() {
      _done = true;
      _timeUp = timeUp;
    });
  }

  Future<void> _confirmFinish() async {
    final missing = _answers.where((a) => a == null).length;
    if (missing > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Terminer l\'examen ?'),
          content: Text(
            '$missing question(s) sans réponse : elles compteront comme '
            'fausses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Continuer'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Terminer'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _finish();
  }

  @override
  Widget build(BuildContext context) =>
      _done ? _result(context) : _question(context);

  Widget _question(BuildContext context) {
    final q = widget.questions[_index];
    final remaining = widget.timeLimit - _elapsed;
    final last = _index == widget.questions.length - 1;
    final answered = _answers.where((a) => a != null).length;
    return NotebookPage(
      key: const ValueKey('prep-exam-questions'),
      title: 'Examen blanc',
      showSearch: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: Text(
              '⏱ ${formatDuration(remaining.isNegative ? Duration.zero : remaining)}',
              key: const Key('prep-exam-timer'),
              style: Hand.sansText(context, size: 16).copyWith(
                fontWeight: FontWeight.w800,
                color: remaining.inSeconds < 60
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
        ),
      ],
      children: [
        HandProgress(
          value: answered / widget.questions.length,
          tone: Tone.violet,
        ),
        const SizedBox(height: 6),
        Text(
          'Question ${_index + 1}/${widget.questions.length} · '
          '$answered répondue(s)',
          style: Hand.sansText(context, size: 13),
        ),
        const SizedBox(height: 12),
        _BiText(q.prompt, size: 22, bold: true),
        const SizedBox(height: 12),
        for (final (i, c) in q.choices.indexed) _choice(context, i, c),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_index > 0)
              OutlinedButton.icon(
                onPressed: () => setState(() => _index--),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Précédente'),
              ),
            if (!last)
              FilledButton.icon(
                onPressed: () => setState(() => _index++),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Suivante'),
              ),
            GradientButton(
              emoji: '🏁',
              label: 'Terminer l\'examen',
              from: Tone.violet,
              to: Tone.pink,
              onPressed: _confirmFinish,
            ),
          ],
        ),
      ],
    );
  }

  Widget _choice(BuildContext context, int i, Bi c) {
    final selected = _answers[_index] == i;
    final paper = Paper.of(context);
    final colors = toneColors(Tone.blue, Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Réponse ${PrepQuestion.letter(i)} : ${c.en}. ${c.fr}',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _answers[_index] = i),
          child: HandBox(
            fill: selected ? colors.fill : paper.page,
            stroke: selected
                ? toneBright(Tone.blue)
                : paper.ink.withValues(alpha: 0.3),
            strokeWidth: selected ? 2.6 : 1.8,
            seed: _index * 10 + i,
            shadow: false,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${PrepQuestion.letter(i)}.',
                  style: TextStyle(
                    fontFamily: Hand.title,
                    fontSize: Hand.tsize(26),
                    fontWeight: Hand.titleWeight,
                    color: selected ? colors.ink : paper.ink,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _BiText(c, size: 18)),
                if (selected)
                  Icon(Icons.radio_button_checked, color: colors.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _result(BuildContext context) {
    final library = AppScope.of(context).library;
    final qs = widget.questions;
    final good = [
      for (final (i, q) in qs.indexed)
        if (_answers[i] == q.correct) i,
    ].length;
    final pct = (good * 100 / qs.length).round();
    final passed = pct >= widget.passingScore;
    // Résultat par chapitre, dans l'ordre de la formation.
    final byChapter = <String, (int, int)>{};
    for (final (i, q) in qs.indexed) {
      final (g, t) = byChapter[q.chapterId] ?? (0, 0);
      byChapter[q.chapterId] = (g + (_answers[i] == q.correct ? 1 : 0), t + 1);
    }
    final order = [for (final c in library.chapters) c.id];
    final chapters = byChapter.keys.toList()
      ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    final used = _elapsed > widget.timeLimit ? widget.timeLimit : _elapsed;
    // Nouvelle page : le résultat s'affiche depuis le haut.
    return NotebookPage(
      key: const ValueKey('prep-exam-result'),
      title: 'Résultat de l\'examen blanc',
      showSearch: false,
      children: [
        const SizedBox(height: 8),
        GradientBanner(
          tone: passed ? Tone.green : Tone.orange,
          toTone: Tone.violet,
          child: Column(
            children: [
              Text(
                passed ? '✅ Réussi' : '📚 À retravailler',
                style: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: Hand.tsize(34),
                  fontWeight: Hand.titleWeight,
                  color: Colors.white,
                ),
              ),
              Text(
                '$good / ${qs.length} · $pct %',
                key: const Key('prep-exam-score'),
                style: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: Hand.tsize(48),
                  fontWeight: Hand.titleWeight,
                  color: Colors.white,
                ),
              ),
              Text(
                'Seuil de réussite : ${widget.passingScore} % · temps : '
                '${formatDuration(used)}'
                '${_timeUp ? ' (temps écoulé)' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Hand.sans,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Par chapitre', style: Hand.subtitle(context, Tone.violet)),
        const SizedBox(height: 6),
        for (final id in chapters)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    library.chapter(id).title,
                    style: Hand.sansText(context, size: 14),
                  ),
                ),
                Text(
                  '${byChapter[id]!.$1} / ${byChapter[id]!.$2}',
                  style: Hand.sansText(context, size: 14).copyWith(
                    fontWeight: FontWeight.w800,
                    color: successColor(
                      byChapter[id]!.$1 * 100 >=
                          byChapter[id]!.$2 * widget.passingScore,
                      Theme.of(context).colorScheme,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('Correction', style: Hand.subtitle(context, Tone.violet)),
        for (final (i, q) in qs.indexed) ...[
          const SizedBox(height: 14),
          Text(
            '${i + 1}. ${_answers[i] == q.correct ? '✅' : '❌'} '
            'Ta réponse : ${_answers[i] == null ? '—' : PrepQuestion.letter(_answers[i]!)}'
            ' · bonne réponse : ${q.correctLetter}',
            style: Hand.sansText(
              context,
              size: 14,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          _BiText(q.prompt, size: 18, bold: true),
          _explanationBox(context, q),
        ],
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: const Text('Terminer'),
          ),
        ),
      ],
    );
  }
}
