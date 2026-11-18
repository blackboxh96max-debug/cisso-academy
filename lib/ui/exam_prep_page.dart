import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../export/pdf_export.dart';
import '../export/pdf_save.dart';
import '../models/content.dart';
import '../logic/study_groups.dart';
import 'bilingual.dart';
import 'course_view_bar.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/look_table.dart';
import 'notebook/note_box.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Ouvre la préparation à l'examen.
void openExamPrep(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ExamPrepPage()));

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

enum _View { lots, chapters }

/// « Préparation examen » : les questions que l'apprenant ajoute chaque jour
/// depuis sa formation, par séance ou par chapitre, en anglais et en français.
class ExamPrepPage extends StatefulWidget {
  const ExamPrepPage({super.key});

  @override
  State<ExamPrepPage> createState() => _ExamPrepPageState();
}

class _ExamPrepPageState extends State<ExamPrepPage> {
  _View _view = _View.lots;

  /// Modules dépliés dans la vue « Par chapitre » (repliés au départ).
  final _open = <int>{};
  CourseView? _groupView;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    final prep = library.examPrep;
    final all = prep.questions;
    return NotebookPage(
      title: 'Préparation examen',
      children: [
        Text(
          'Les questions de ta formation, en anglais et en français, avec la '
          'bonne réponse et son explication. Entraîne-toi, relis la fiche ou '
          'télécharge-la en PDF.',
          style: Hand.bodyText(context),
        ),
        const SizedBox(height: 10),
        NoteBox(
          tone: Tone.yellow,
          emoji: '📌',
          label: 'Questions de ta formation',
          sticky: true,
          child: Text(
            'Elles sont rangées à part des questions de l\'application : '
            'elles ne comptent ni dans tes statistiques ni dans les examens '
            'blancs. ${prep.lots.length} séance(s), ${all.length} question(s).',
            style: Hand.noteText(context),
          ),
        ),
        const SizedBox(height: 14),
        if (all.isNotEmpty)
          Center(
            child: GradientButton(
              emoji: '🎯',
              label: 'Tout réviser (${all.length} questions)',
              from: Tone.pink,
              to: Tone.orange,
              onPressed: () => _practice(context, 'Toutes les séances', all),
            ),
          ),
        const SizedBox(height: 14),
        SegmentedButton<_View>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _View.lots, label: Text('📅 Par séance')),
            ButtonSegment(
              value: _View.chapters,
              label: Text('📚 Par chapitre'),
            ),
          ],
          selected: {_view},
          onSelectionChanged: (s) => setState(() => _view = s.first),
        ),
        if (prep.lots.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Aucune séance pour l\'instant.',
              style: Hand.sansText(context),
            ),
          ),
        if (_view == _View.lots)
          for (final lot in prep.lots.reversed) _lotRow(context, lot)
        else
          ..._chapterSections(context, library),
      ],
    );
  }

  Widget _lotRow(BuildContext context, PrepLot lot) => _PrepRow(
    tone: Tone.pink,
    emoji: '📅',
    title: '${_date(lot.date)} · ${lot.title.fr}',
    en: lot.title.en,
    subtitle:
        '${lot.questions.length} questions · '
        '${lot.parts.map((p) => p.title.fr).join(', ')}',
    onPractice: () => _practice(context, lot.title.fr, lot.questions),
    onSheet: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrepSheetPage(
          title: lot.title.fr,
          subtitle: 'Séance du ${_date(lot.date)}',
          lot: lot,
          questions: lot.questions,
        ),
      ),
    ),
    onPdf: () => _pdf(
      context,
      title: 'Préparation ${lot.title.fr} ${_date(lot.date)}',
      lot: lot,
      questions: lot.questions,
    ),
  );

  List<Widget> _chapterSections(BuildContext context, ContentLibrary library) {
    final prep = library.examPrep;
    final state = AppScope.of(context);
    final view = currentView(state);
    if (_groupView != view) {
      _groupView = view;
      _open.clear();
    }
    final out = <Widget>[];
    final shown = <int>[];
    for (final g in studyGroups(library, view)) {
      final rows = <Widget>[];
      var count = 0;
      for (final c in g.chapters) {
        final qs = prep.forChapter(c.id);
        if (qs.isEmpty) continue;
        count += qs.length;
        final number = chapterNumber(library, c);
        final (tone, _) = moduleStyle(library.module(c.moduleId).number);
        rows.add(
          _PrepRow(
            tone: tone,
            emoji: '📘',
            title: '$number  ${c.title}',
            en: c.titleEn,
            subtitle: '${qs.length} question(s)',
            onPractice: () => _practice(context, c.title, qs),
            onSheet: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PrepSheetPage(
                  title: c.title,
                  subtitle: 'Chapitre $number',
                  questions: qs,
                ),
              ),
            ),
            onPdf: () => _pdf(
              context,
              title: 'Préparation chapitre $number',
              subtitle: c.title,
              questions: qs,
            ),
          ),
        );
      }
      if (rows.isEmpty) continue;
      shown.add(g.index);
      final (tone, emoji) = groupStyle(g);
      final open = _open.contains(g.index);
      out.add(const SizedBox(height: 18));
      out.add(
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() {
              if (!_open.remove(g.index)) _open.add(g.index);
            }),
            child: GradientBanner(
              tone: tone,
              seed: 90 + g.index,
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$emoji  ${g.fullTitle}',
                          style: TextStyle(
                            fontFamily: Hand.title,
                            fontSize: Hand.tsize(22),
                            fontWeight: Hand.titleWeight,
                            color: Colors.white,
                          ),
                        ),
                        if (g.titleEn != null)
                          EnTag(g.titleEn!, onDark: true, size: 12),
                        Text(
                          '${rows.length} chapitre(s) · $count question(s)',
                          style: Hand.sansText(context, size: 12.5).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ExpandChevron(open: open),
                ],
              ),
            ),
          ),
        ),
      );
      if (open) out.addAll(rows);
    }
    return [
      const SizedBox(height: 12),
      const CourseViewSelector(),
      if (shown.isNotEmpty)
        ExpandAllBar(
          onExpandAll: () => setState(() => _open.addAll(shown)),
          onCollapseAll: () => setState(_open.clear),
        ),
      ...out,
    ];
  }

  void _practice(BuildContext context, String title, List<PrepQuestion> qs) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrepQuizPage(title: title, questions: qs),
        ),
      );

  void _pdf(
    BuildContext context, {
    required String title,
    String? subtitle,
    PrepLot? lot,
    required List<PrepQuestion> questions,
  }) => exportPdf(
    context,
    title: title,
    build: () => examPrepPdf(
      title: title,
      subtitle: subtitle ?? lot?.title.en,
      lot: lot,
      questions: questions,
    ),
  );
}

class _PrepRow extends StatelessWidget {
  const _PrepRow({
    required this.tone,
    required this.emoji,
    required this.title,
    this.en,
    required this.subtitle,
    required this.onPractice,
    required this.onSheet,
    required this.onPdf,
  });

  final Tone tone;
  final String emoji;
  final String title;
  final String? en;
  final String subtitle;
  final VoidCallback onPractice;
  final VoidCallback onSheet;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone, Theme.of(context).brightness);
    final paper = Paper.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: HandBox(
        fill: c.fill,
        stroke: toneBright(tone),
        strokeWidth: 2,
        seed: title.hashCode,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: Hand.body,
                          fontSize: Hand.bsize(20),
                          height: 1.15,
                          color: paper.ink,
                        ),
                      ),
                      if (en != null) EnTag(en!, size: 12),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Hand.sansText(
                          context,
                          size: 13,
                        ).copyWith(color: c.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onPractice,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('S\'entraîner'),
                ),
                OutlinedButton.icon(
                  onPressed: onSheet,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Fiche'),
                ),
                OutlinedButton.icon(
                  onPressed: onPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Énoncé bilingue : anglais (langue de l'examen) puis français.
class _BiText extends StatelessWidget {
  const _BiText(this.text, {this.size = 19, this.bold = false});

  final Bi text;
  final double size;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '🇬🇧 '),
              TextSpan(text: text.en),
            ],
          ),
          style: TextStyle(
            fontFamily: Hand.body,
            fontSize: Hand.bsize(size),
            height: 1.3,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: englishColor(context),
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '🇫🇷 '),
              TextSpan(text: text.fr),
            ],
          ),
          style: TextStyle(
            fontFamily: Hand.note,
            fontSize: Hand.bsize(size - 3),
            height: 1.35,
            color: paper.ink,
          ),
        ),
      ],
    );
  }
}

Widget _explanationBox(BuildContext context, PrepQuestion q) => NoteBox(
  tone: Tone.blue,
  emoji: '💡',
  label: 'Explication',
  seed: q.number,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (q.formula != null) ...[
        Text('Formula / Formule', style: Hand.boxLabel(context, Tone.blue)),
        const SizedBox(height: 2),
        Text(q.formula!, style: Hand.monoText(context)),
        const SizedBox(height: 8),
      ],
      _BiText(q.explanation, size: 18),
    ],
  ),
);

/// Entraînement : une question à la fois, correction immédiate en EN et FR.
class PrepQuizPage extends StatefulWidget {
  const PrepQuizPage({super.key, required this.title, required this.questions});

  final String title;
  final List<PrepQuestion> questions;

  @override
  State<PrepQuizPage> createState() => _PrepQuizPageState();
}

class _PrepQuizPageState extends State<PrepQuizPage> {
  late List<PrepQuestion> _questions = List.of(widget.questions);
  int _index = 0;
  int? _chosen;
  final List<PrepQuestion> _wrong = [];
  int _good = 0;
  bool _done = false;

  void _answer(int i) {
    if (_chosen != null) return;
    final q = _questions[_index];
    setState(() {
      _chosen = i;
      if (i == q.correct) {
        _good++;
      } else {
        _wrong.add(q);
      }
    });
  }

  void _next() => setState(() {
    if (_index + 1 >= _questions.length) {
      _done = true;
    } else {
      _index++;
      _chosen = null;
    }
  });

  void _restart(List<PrepQuestion> qs, {bool shuffle = false}) => setState(() {
    _questions = List.of(qs);
    if (shuffle) _questions.shuffle();
    _index = 0;
    _chosen = null;
    _wrong.clear();
    _good = 0;
    _done = false;
  });

  @override
  Widget build(BuildContext context) {
    if (_done) return _result(context);
    final q = _questions[_index];
    final chapter = AppScope.of(context).library.chapter(q.chapterId);
    return NotebookPage(
      title: widget.title,
      showSearch: false,
      actions: [
        IconButton(
          tooltip: 'Mélanger les questions',
          icon: const Icon(Icons.shuffle),
          onPressed: () => _restart(widget.questions, shuffle: true),
        ),
      ],
      children: [
        HandProgress(
          value: (_index + (_chosen == null ? 0 : 1)) / _questions.length,
          tone: Tone.pink,
        ),
        const SizedBox(height: 6),
        Text(
          'Question ${_index + 1}/${_questions.length} · ${chapter.title}',
          style: Hand.sansText(context, size: 13),
        ),
        const SizedBox(height: 12),
        _BiText(q.prompt, size: 22, bold: true),
        const SizedBox(height: 12),
        for (final (i, c) in q.choices.indexed) _choice(context, q, i, c),
        if (_chosen != null) ...[
          const SizedBox(height: 12),
          Text(
            _chosen == q.correct
                ? '✅ Correct ! Bonne réponse : ${q.correctLetter}'
                : '❌ Bonne réponse : ${q.correctLetter}',
            style: Hand.subtitle(
              context,
              _chosen == q.correct ? Tone.green : Tone.red,
            ),
          ),
          const SizedBox(height: 8),
          _explanationBox(context, q),
          const SizedBox(height: 16),
          Center(
            child: GradientButton(
              emoji: _index + 1 >= _questions.length ? '🏁' : '➡️',
              label: _index + 1 >= _questions.length
                  ? 'Voir le résultat'
                  : 'Question suivante',
              from: Tone.violet,
              to: Tone.pink,
              onPressed: _next,
            ),
          ),
        ],
      ],
    );
  }

  Widget _choice(BuildContext context, PrepQuestion q, int i, Bi c) {
    final answered = _chosen != null;
    final tone = !answered
        ? Tone.blue
        : i == q.correct
        ? Tone.green
        : i == _chosen
        ? Tone.red
        : null;
    final colors = tone == null
        ? null
        : toneColors(tone, Theme.of(context).brightness);
    final paper = Paper.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        button: !answered,
        label: 'Réponse ${PrepQuestion.letter(i)} : ${c.en}. ${c.fr}',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: answered ? null : () => _answer(i),
          child: HandBox(
            fill: colors?.fill ?? paper.page,
            stroke: tone == null
                ? paper.ink.withValues(alpha: 0.3)
                : toneBright(tone),
            strokeWidth: answered && tone != null && tone != Tone.blue
                ? 2.6
                : 1.8,
            seed: q.number * 10 + i,
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
                    color: colors?.ink ?? paper.ink,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _BiText(c, size: 18)),
                if (answered && i == q.correct) const Text('✅'),
                if (answered && i == _chosen && i != q.correct) const Text('❌'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _result(BuildContext context) {
    final total = _questions.length;
    final pct = total == 0 ? 0 : (_good * 100 / total).round();
    return NotebookPage(
      title: widget.title,
      showSearch: false,
      children: [
        const SizedBox(height: 8),
        GradientBanner(
          tone: pct >= 70 ? Tone.green : Tone.orange,
          toTone: Tone.violet,
          child: Column(
            children: [
              Text(
                '$_good / $total',
                style: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: Hand.tsize(54),
                  fontWeight: Hand.titleWeight,
                  color: Colors.white,
                ),
              ),
              Text(
                '$pct % de bonnes réponses',
                style: TextStyle(
                  fontFamily: Hand.sans,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_wrong.isNotEmpty)
              GradientButton(
                emoji: '🔁',
                label: 'Reprendre mes ${_wrong.length} erreur(s)',
                from: Tone.orange,
                to: Tone.pink,
                onPressed: () => _restart(List.of(_wrong)),
              ),
            OutlinedButton.icon(
              onPressed: () => _restart(widget.questions),
              icon: const Icon(Icons.replay),
              label: const Text('Recommencer'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PrepSheetPage(
                    title: widget.title,
                    questions: widget.questions,
                  ),
                ),
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Voir la fiche'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Fiche bilingue : questions, bonnes réponses, explications, tableaux,
/// récapitulatif et mots-clés.
class PrepSheetPage extends StatelessWidget {
  const PrepSheetPage({
    super.key,
    required this.title,
    this.subtitle,
    this.lot,
    required this.questions,
  });

  final String title;
  final String? subtitle;
  final PrepLot? lot;
  final List<PrepQuestion> questions;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final List<(Bi?, List<PrepQuestion>)> parts =
        lot?.parts.map((p) => (p.title, p.questions)).toList() ??
        [(null, questions)];
    return NotebookPage(
      title: 'Fiche de préparation',
      showSearch: false,
      actions: [
        IconButton(
          tooltip: 'Télécharger en PDF',
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: () => exportPdf(
            context,
            title: 'Préparation $title',
            build: () => examPrepPdf(
              title: title,
              subtitle: subtitle,
              lot: lot,
              questions: questions,
            ),
          ),
        ),
      ],
      children: [
        HandUnderline(
          color: toneBright(Tone.pink),
          seed: 5,
          child: Text(title, style: Hand.chapterTitle(context)),
        ),
        if (lot != null) EnTag(lot!.title.en),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle!, style: Hand.sansText(context, size: 14)),
          ),
        for (final (partTitle, qs) in parts) ...[
          if (partTitle != null) ...[
            const SizedBox(height: 20),
            Text(partTitle.fr, style: Hand.subtitle(context, Tone.violet)),
            EnTag(partTitle.en),
          ],
          for (final q in qs) _questionCard(context, q),
        ],
        if (lot != null)
          for (final t in lot!.tables)
            NotePanel(
              title: t.title.fr,
              emoji: '📋',
              tone: Tone.turquoise,
              seed: t.title.fr.hashCode,
              child: _table(
                context,
                ['English', 'Français'],
                [
                  for (final r in t.rows) [r.$1, r.$2],
                ],
              ),
            ),
        NotePanel(
          title: 'Les bonnes réponses à mémoriser',
          emoji: '🏁',
          tone: Tone.green,
          seed: 77,
          child: _table(
            context,
            ['N°', 'English', 'Français'],
            [
              for (final q in questions)
                [
                  '${q.number}',
                  '${q.correctLetter}. ${q.choices[q.correct].en}',
                  q.choices[q.correct].fr,
                ],
            ],
          ),
        ),
        if (lot != null && lot!.keywords.isNotEmpty)
          NotePanel(
            title: 'Mots-clés à retenir',
            emoji: '🔑',
            tone: Tone.orange,
            seed: 78,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in lot!.keywords)
                  HandBox(
                    fill: toneColors(
                      Tone.yellow,
                      Theme.of(context).brightness,
                    ).fill,
                    stroke: toneBright(Tone.yellow),
                    seed: k.term.hashCode,
                    shadow: false,
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${k.term}  ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: '${k.en} = ${k.fr}'),
                        ],
                      ),
                      style: TextStyle(
                        fontFamily: Hand.sans,
                        fontSize: 14,
                        color: paper.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (lot?.advice case final advice?) ...[
          const SizedBox(height: 16),
          NoteBox(
            tone: Tone.yellow,
            emoji: '🧠',
            label: 'Conseil',
            sticky: true,
            child: Text(advice, style: Hand.noteText(context)),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          lot?.source ?? 'Questions de la formation de l\'apprenant',
          style: Hand.sansText(context, size: 12),
        ),
      ],
    );
  }

  Widget _questionCard(BuildContext context, PrepQuestion q) {
    final good = q.choices[q.correct];
    final green = toneColors(Tone.green, Theme.of(context).brightness);
    return NotePanel(
      title: 'Question ${q.number}',
      emoji: '❓',
      tone: Tone.blue,
      seed: q.number + 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BiText(q.prompt, size: 20, bold: true),
          const SizedBox(height: 8),
          for (final (i, c) in q.choices.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${PrepQuestion.letter(i)}. ${c.en}  ·  ${c.fr}',
                style: Hand.sansText(context, size: 14).copyWith(
                  fontWeight: i == q.correct ? FontWeight.w800 : null,
                  color: i == q.correct ? green.ink : null,
                ),
              ),
            ),
          const SizedBox(height: 10),
          NoteBox(
            tone: Tone.green,
            emoji: '✅',
            label: 'Bonne réponse : ${q.correctLetter}',
            seed: q.number + 300,
            child: _BiText(good, size: 18),
          ),
          const SizedBox(height: 10),
          _explanationBox(context, q),
        ],
      ),
    );
  }

  Widget _table(
    BuildContext context,
    List<String> header,
    List<List<String>> rows,
  ) {
    final look = LookTable(context);
    final style = Hand.sansText(context, size: 14);
    return Table(
      columnWidths: header.length == 3
          ? const {0: FixedColumnWidth(36)}
          : const {},
      border: look.border,
      children: [
        TableRow(
          decoration: look.headerDecoration,
          children: [
            for (final h in header)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  h,
                  style: look.headerStyle.copyWith(fontSize: Hand.tsize(19)),
                ),
              ),
          ],
        ),
        for (final (k, r) in rows.indexed)
          TableRow(
            decoration: look.row(k),
            children: [
              for (final (i, cell) in r.indexed)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    cell,
                    style: header[i] == 'English'
                        ? style.copyWith(color: englishColor(context))
                        : style,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
