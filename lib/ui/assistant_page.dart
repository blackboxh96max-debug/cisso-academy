import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../logic/assistant.dart';
import '../logic/study_groups.dart';
import '../models/content.dart';
import 'bilingual.dart';
import 'chapter_page.dart';
import 'course_view_bar.dart';
import 'lesson_page.dart';
import 'mascot.dart';
import 'mascot_picker.dart';
import 'history_list.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Ouvre l'assistant de questions.
void openAssistant(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AssistantPage()));

/// Bouton de la barre : ouvre l'assistant.
class AssistantAction extends StatelessWidget {
  const AssistantAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Assistant : poser une question',
    icon: const Icon(Icons.forum_outlined),
    onPressed: () => openAssistant(context),
  );
}

const _suggestions = [
  'Qu\'est-ce que l\'ALE ?',
  'Différence entre IDS et IPS',
  'Délais de notification NIS 2',
  'What is a SIEM?',
  'Qui décide dans le RGPD : le DPO ou le responsable de traitement ?',
  'Règle de sauvegarde 3-2-1',
];

/// Assistant de questions, de type conversation : on écrit une question en
/// français ou en anglais ; il répond avec les passages du cours qui
/// conviennent le mieux et indique où les étudier. Tout se passe sur
/// l'appareil, sans connexion ni compte.
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key, this.initialQuestion});

  /// Question posée dès l'ouverture (tests, démonstration).
  final String? initialQuestion;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _answers = <AssistantAnswer>[];

  /// Nombre de réponses reprises de la conversation précédente.
  int _restored = 0;
  bool _loaded = false;

  /// Humeur de la mascotte, et nombre de frappes (elle hoche la tête).
  MascotMood _mood = MascotMood.idle;
  int _keys = 0;

  /// Question en cours de recherche (la mascotte réfléchit).
  String? _pending;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTyping);
    final q = widget.initialQuestion;
    if (q != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(q));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    // La conversation précédente est reprise : les réponses sont recalculées
    // sur l'appareil à partir des questions gardées.
    final app = AppScope.read(context);
    _answers.addAll(app.assistantHistory.map(app.assistant.ask));
    _restored = _answers.length;
    if (_restored > 0) _scrollToEnd(animate: false);
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  void _remove(String question) {
    final key = normalize(question.trim());
    setState(() {
      for (var i = _answers.length - 1; i >= 0; i--) {
        if (normalize(_answers[i].question.trim()) == key) {
          _answers.removeAt(i);
          if (i < _restored) _restored--;
        }
      }
    });
    AppScope.read(context).removeQuestion(question);
  }

  void _clear() {
    setState(() {
      _answers.clear();
      _restored = 0;
    });
    AppScope.read(context).clearQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onTyping);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTyping() {
    if (_pending != null) return;
    final typing = _controller.text.trim().isNotEmpty;
    final mood = typing
        ? MascotMood.listening
        : (_mood == MascotMood.listening ? MascotMood.idle : _mood);
    setState(() {
      if (typing) _keys++;
      _mood = mood;
    });
  }

  void _ask(String question) {
    final q = question.trim();
    if (q.isEmpty || _pending != null) return;
    final app = AppScope.read(context);
    final answer = app.assistant.ask(q);
    void show() {
      if (!mounted) return;
      final found =
          !(answer.isEmpty || (answer.uncertain && answer.terms.isEmpty));
      setState(() {
        _pending = null;
        _answers.add(answer);
        _mood = found ? MascotMood.answering : MascotMood.puzzled;
      });
      _scrollToEnd();
      // Puis elle se remet à attendre la question suivante.
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 2600), () {
        if (!mounted || _pending != null) return;
        setState(
          () => _mood = _controller.text.trim().isEmpty
              ? MascotMood.idle
              : MascotMood.listening,
        );
      });
    }

    app.addQuestion(q);
    _timer?.cancel();
    _controller.clear();
    if (!animationsOn(context)) {
      show();
      return;
    }
    // La recherche est immédiate ; un court instant de réflexion laisse voir
    // la mascotte chercher.
    setState(() {
      _pending = q;
      _mood = MascotMood.thinking;
    });
    _scrollToEnd();
    _timer = Timer(const Duration(milliseconds: 700), show);
  }

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final side = narrow ? 12.0 : 24.0;
    // Questions récentes, sans doublon, la plus récente d'abord.
    final seen = <String>{};
    final recent = [
      for (final q in AppScope.of(context).assistantHistory.reversed)
        if (seen.add(normalize(q.trim()))) q,
    ].take(6).toList();
    return Scaffold(
      backgroundColor: paper.background,
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          IconButton(
            tooltip: 'Changer de mascotte',
            icon: const Icon(Icons.face_retouching_natural),
            onPressed: () => showMascotPicker(context),
          ),
          if (_answers.isNotEmpty)
            IconButton(
              tooltip: 'Effacer la conversation et l\'historique',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clear,
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(side, 8, side, 16),
                  children: [
                    _Welcome(onPick: _ask, compact: _answers.isNotEmpty),
                    if (recent.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      HistoryList(
                        title: 'Questions récentes',
                        entries: recent,
                        tone: Tone.violet,
                        onPick: _ask,
                        onRemove: _remove,
                        onClear: _clear,
                      ),
                      const SizedBox(height: 8),
                    ],
                    for (final (i, a) in _answers.indexed) ...[
                      if (i == 0 && _restored > 0)
                        const _Divider('Conversation précédente'),
                      if (i == _restored && _restored > 0)
                        const _Divider('Nouvelles questions'),
                      _UserBubble(text: a.question),
                      _AnswerCard(answer: a, onAsk: _ask),
                    ],
                    if (_pending != null) _UserBubble(text: _pending!),
                  ],
                ),
              ),
              _MascotBar(
                mood: _mood,
                typing: _keys,
                big: _answers.isEmpty && _pending == null,
                side: side,
              ),
              _InputBar(controller: _controller, onSend: _ask, side: side),
            ],
          ),
        ),
      ),
    );
  }
}

/// Séparateur de la conversation : « Conversation précédente », « Nouvelles questions ».
class _Divider extends StatelessWidget {
  const _Divider(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final soft = Paper.of(context).inkSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: soft.withValues(alpha: 0.4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: Hand.sansText(
                context,
                size: 13,
              ).copyWith(color: soft, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Divider(color: soft.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick, required this.compact});

  final ValueChanged<String> onPick;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final c = toneColors(Tone.violet, Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: HandBox(
        fill: c.fill,
        stroke: toneBright(Tone.violet),
        strokeWidth: 2,
        seed: 501,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🤖 Pose ta question',
              style: TextStyle(
                fontFamily: Hand.title,
                fontSize: Hand.tsize(26),
                fontWeight: Hand.titleWeight,
                color: c.ink,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                'En français ou en anglais. Je cherche dans tout le cours '
                '(leçons, glossaire, fiches, flashcards, explications des QCM) '
                'et je t\'indique le module, le chapitre et la leçon où '
                'l\'étudier. Tout reste sur l\'appareil : pas d\'internet, pas '
                'd\'IA en ligne. Je cite le cours tel qu\'il est écrit, je '
                'n\'invente rien.',
                style: Hand.sansText(context, size: 14.5),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s),
                    labelStyle: Hand.sansText(
                      context,
                      size: 13,
                    ).copyWith(color: paper.ink),
                    onPressed: () => onPick(s),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(Tone.blue, Theme.of(context).brightness);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 14, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: Hand.sansText(
            context,
            size: 15,
          ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer, required this.onAsk});

  final AssistantAnswer answer;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final hits = answer.hits;
    final main = hits.isEmpty ? null : hits.first;
    // Où l'étudier : la meilleure leçon, si la réponse principale n'en est
    // pas une.
    final lesson = hits
        .where((h) => h.passage.kind == PassageKind.lesson)
        .firstOrNull;
    // Voir aussi : seulement les passages proches de la réponse principale.
    final others = hits
        .skip(1)
        .where((h) => h != lesson)
        .where((h) => h.coverage >= 0.5 && h.score >= main!.score * 0.4)
        .take(3)
        .toList();
    final children = <Widget>[];

    if (answer.english) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '🇬🇧 Question in English: the course is written in French; '
            'English terms are shown next to the French ones.',
            style: Hand.sansText(
              context,
              size: 13,
            ).copyWith(color: englishColor(context)),
          ),
        ),
      );
    }

    if (answer.isEmpty || (answer.uncertain && answer.terms.isEmpty)) {
      children.add(
        Text(
          answer.isEmpty
              ? 'Je n\'ai rien trouvé dans le cours pour cette question. '
                    'Essaie avec un mot-clé ou un sigle (par exemple « RPO », '
                    '« pare-feu », « NIS 2 »).'
              : 'Je n\'ai pas trouvé de réponse sûre. Voici les passages les '
                    'plus proches ; reformule avec un mot-clé si ce n\'est pas '
                    'ce que tu cherches.',
          style: Hand.sansText(context, size: 14.5),
        ),
      );
    }

    for (final t in answer.terms) {
      children.add(_TermCard(term: t));
    }

    if (main != null) {
      children.add(
        _HitCard(
          hit: main,
          label: answer.terms.isEmpty ? 'Réponse du cours' : 'Dans le cours',
          big: true,
        ),
      );
    }
    if (lesson != null && lesson != main) {
      children.add(_HitCard(hit: lesson, label: 'Où l\'étudier'));
    }
    if (others.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Text(
            'Voir aussi',
            style: Hand.sansText(
              context,
              size: 13,
            ).copyWith(color: paper.inkSoft, fontWeight: FontWeight.w800),
          ),
        ),
      );
      for (final h in others) {
        children.add(_HitCard(hit: h, compact: true));
      }
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, right: 24),
        child: HandBox(
          fill: paper.page,
          stroke: toneBright(Tone.violet),
          strokeWidth: 2,
          seed: answer.question.hashCode,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({required this.term});

  final GlossaryTerm term;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final c = toneColors(Tone.blue, Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.ink.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Sticker(text: '🔤 Définition', tone: Tone.blue),
                Text(
                  term.acronym == null
                      ? term.termFr
                      : '${term.acronym} · ${term.termFr}',
                  style: TextStyle(
                    fontFamily: Hand.body,
                    fontSize: Hand.bsize(20),
                    height: 1.15,
                    color: c.ink,
                  ),
                ),
              ],
            ),
            EnTag(term.termEn, size: 12.5),
            const SizedBox(height: 4),
            Text(
              term.definition,
              style: Hand.sansText(
                context,
                size: 15,
              ).copyWith(color: paper.ink),
            ),
            if (term.example.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Exemple : ${term.example}',
                  style: Hand.sansText(
                    context,
                    size: 13.5,
                  ).copyWith(color: paper.inkSoft),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HitCard extends StatelessWidget {
  const _HitCard({
    required this.hit,
    this.label,
    this.big = false,
    this.compact = false,
  });

  final AssistantHit hit;
  final String? label;
  final bool big;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final library = state.library;
    final paper = Paper.of(context);
    final p = hit.passage;
    final chapter = p.chapterId == null
        ? null
        : library.chapters.where((c) => c.id == p.chapterId).firstOrNull;
    final lesson = p.lessonId == null ? null : library.lesson(p.lessonId!);
    final view = currentView(state);
    final places = chapter == null
        ? const <String>[]
        : placeInView(
            library,
            view,
            lessonId: p.lessonId,
            chapterId: chapter.id,
          );
    final tone = chapter == null
        ? Tone.blue
        : moduleStyle(library.module(chapter.moduleId).number).$1;
    final c = toneColors(tone, Theme.of(context).brightness);

    VoidCallback? open;
    String? openLabel;
    if (lesson != null) {
      openLabel = 'Ouvrir la leçon';
      open = () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonPage(lesson: lesson, focusBlock: p.blockIndex),
        ),
      );
    } else if (chapter != null) {
      openLabel = 'Ouvrir le chapitre';
      open = () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChapterPage(chapterId: chapter.id)),
      );
    }

    final location = <String>[
      if (chapter != null)
        'Chapitre ${chapterNumber(library, chapter)} · ${chapter.title}',
      ...places,
      if (lesson != null) 'Leçon : ${lesson.title}',
    ];

    if (compact) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.kind.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Hand.sansText(
                        context,
                        size: 14,
                      ).copyWith(color: paper.ink, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        p.kind.label,
                        if (chapter != null)
                          'chapitre ${chapterNumber(library, chapter)}',
                      ].join(' · '),
                      style: Hand.sansText(
                        context,
                        size: 12,
                      ).copyWith(color: paper.inkSoft),
                    ),
                  ],
                ),
              ),
              if (open != null) Icon(Icons.chevron_right, color: paper.inkSoft),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: big ? c.fill : paper.page,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.ink.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: Hand.sansText(
                      context,
                      size: 13,
                    ).copyWith(color: c.ink, fontWeight: FontWeight.w800),
                  ),
                Sticker(text: '${p.kind.emoji} ${p.kind.label}', tone: tone),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              p.title,
              style: TextStyle(
                fontFamily: Hand.body,
                fontSize: Hand.bsize(big ? 20 : 18),
                height: 1.15,
                color: paper.ink,
              ),
            ),
            if (p.en != null) EnTag(p.en!, size: 12),
            const SizedBox(height: 4),
            Text(
              hit.excerpt,
              style: Hand.sansText(
                context,
                size: big ? 15 : 14,
              ).copyWith(color: paper.ink),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final l in location)
                Text(
                  '📍 $l',
                  style: Hand.sansText(
                    context,
                    size: 12.5,
                  ).copyWith(color: paper.inkSoft, fontWeight: FontWeight.w600),
                ),
            ],
            if (open != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: FilledButton.tonalIcon(
                    onPressed: open,
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: Text(openLabel!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La mascotte au-dessus du champ de saisie, avec sa bulle.
class _MascotBar extends StatelessWidget {
  const _MascotBar({
    required this.mood,
    required this.typing,
    required this.big,
    required this.side,
  });

  final MascotMood mood;
  final int typing;
  final bool big;
  final double side;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final c = toneColors(Tone.violet, Theme.of(context).brightness);
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 4, side, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: GestureDetector(
              onTap: () => showMascotPicker(context),
              child: Mascot(
                key: const Key('assistant-mascot'),
                mood: mood,
                typing: typing,
                size: big ? 96 : 60,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Padding(
              padding: EdgeInsets.only(bottom: big ? 40 : 22),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(mood),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: paper.card,
                    border: Border.all(
                      color: toneBright(Tone.violet),
                      width: 1.6,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                      bottomLeft: Radius.circular(3),
                    ),
                  ),
                  child: Text(
                    mascotById(AppScope.of(context).mascotId).line(mood),
                    style: Hand.sansText(
                      context,
                      size: 14,
                    ).copyWith(color: c.ink, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.side,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final double side;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    return Material(
      color: paper.page,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(side, 8, side - 4, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('assistant-input'),
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: onSend,
                  decoration: const InputDecoration(
                    hintText: 'Ta question, en français ou en anglais…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Envoyer',
                icon: const Icon(Icons.send),
                onPressed: () => onSend(controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
