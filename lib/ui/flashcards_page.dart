import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../data/progress_store.dart';
import '../logic/spaced_repetition.dart';
import '../models/content.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/note_box.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'widgets.dart';

/// Flashcards avec répétition espacée (SM-2).
class FlashcardsPage extends StatelessWidget {
  const FlashcardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final library = state.library;
    final now = state.now();
    final allIds = library.flashcards.map((f) => f.id).toList();
    final due = dueCards(allIds, state.cards, now);
    final seenDue = due.where(state.cards.containsKey).length;
    final fresh = due.length - seenDue;
    final mastered = state.cards.values.where((c) => c.mastered).length;
    final brightness = Theme.of(context).brightness;

    return NotebookPage(
      title: 'Flashcards',
      children: [
        TileGrid(
          children: [
            HandStat(
              emoji: '⏰',
              label: 'À réviser',
              value: '$seenDue',
              tone: Tone.orange,
              seed: 11,
            ),
            HandStat(
              emoji: '✨',
              label: 'Nouvelles',
              value: '$fresh',
              tone: Tone.blue,
              seed: 12,
            ),
            HandStat(
              emoji: '🏆',
              label: 'Maîtrisées',
              value: '$mastered/${allIds.length}',
              tone: Tone.green,
              seed: 13,
            ),
            HandStat(
              emoji: '🃏',
              label: 'Total',
              value: '${allIds.length}',
              tone: Tone.violet,
              seed: 14,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: GradientButton(
            emoji: due.isEmpty ? '😌' : '▶️',
            from: Tone.turquoise,
            to: Tone.violet,
            onPressed: due.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          FlashcardSessionPage(cardIds: due.take(20).toList()),
                    ),
                  ),
            label: due.isEmpty
                ? 'Rien à réviser pour l\'instant'
                : 'Réviser ${due.length > 20 ? 20 : due.length} carte(s)',
          ),
        ),
        const SizedBox(height: 18),
        NoteBox(
          tone: Tone.yellow,
          label: 'Comment ça marche',
          emoji: '💡',
          sticky: true,
          child: Text(
            'Les cartes ratées reviennent dans la même session, puis à intervalles '
            'croissants (1 jour, 6 jours, puis plus). Une carte est maîtrisée '
            'quand son intervalle atteint 21 jours.',
            style: Hand.noteText(context),
          ),
        ),
        NotePanel(
          title: 'Par chapitre',
          emoji: '📚',
          tone: Tone.turquoise,
          seed: 15,
          child: Column(
            children: [
              for (final ch in library.availableChapters)
                Builder(
                  builder: (context) {
                    final (tone, emoji) = moduleStyle(
                      library.module(ch.moduleId).number,
                    );
                    final c = toneColors(tone, brightness);
                    final done = ch.flashcards
                        .where((f) => state.cards[f.id]?.mastered ?? false)
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FlashcardSessionPage(
                              cardIds: ch.flashcards.map((f) => f.id).toList(),
                            ),
                          ),
                        ),
                        child: HandBox(
                          fill: c.fill,
                          stroke: toneBright(tone),
                          strokeWidth: 2,
                          seed: ch.id.hashCode,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Row(
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ch.title,
                                      style: TextStyle(
                                        fontFamily: Hand.body,
                                        fontSize: 20,
                                        height: 1.2,
                                        color: c.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    HandProgress(
                                      value: ch.flashcards.isEmpty
                                          ? 0
                                          : done / ch.flashcards.length,
                                      tone: tone,
                                      height: 8,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$done/${ch.flashcards.length} maîtrisées',
                                      style: Hand.sansText(context, size: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_rounded, color: c.ink),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class FlashcardSessionPage extends StatefulWidget {
  const FlashcardSessionPage({super.key, required this.cardIds});

  final List<String> cardIds;

  @override
  State<FlashcardSessionPage> createState() => _FlashcardSessionPageState();
}

class _FlashcardSessionPageState extends State<FlashcardSessionPage> {
  late final List<String> _queue = List.of(widget.cardIds);
  bool _flipped = false;
  int _done = 0;

  /// Affiche brièvement la célébration « carte maîtrisée ».
  bool _celebrate = false;

  Future<void> _grade(Flashcard card, Grade grade) async {
    final state = AppScope.read(context);
    final now = state.now();
    final current = state.cards[card.id] ?? CardState.initial(card.id, now);
    final next = review(current, grade, now);
    await state.saveCard(next);
    if (!mounted) return;
    setState(() {
      _queue.removeAt(0);
      if (grade == Grade.again) {
        _queue.add(card.id); // revient en fin de session
      }
      _flipped = false;
      _done++;
      _celebrate = next.mastered && !current.mastered;
    });
    if (_celebrate) {
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (mounted) setState(() => _celebrate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Révision terminée')),
        body: ReadingList(
          children: [
            Text('🎉 $_done carte(s) révisée(s).', style: text.titleLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
          ],
        ),
      );
    }
    final library = state.library;
    final card = library.flashcards.firstWhere((f) => f.id == _queue.first);
    final chapter = library.chapters.firstWhere((c) => c.id == card.chapterId);
    final (tone, emoji) = moduleStyle(library.module(chapter.moduleId).number);
    final animate = animationsOn(context);

    return Scaffold(
      backgroundColor: Paper.of(context).background,
      appBar: AppBar(title: Text('Flashcards · ${_queue.length} restante(s)')),
      body: Stack(
        children: [
          ReadingList(
            children: [
              Semantics(
                button: true,
                label: _flipped
                    ? 'Carte retournée, réponse affichée'
                    : 'Toucher pour retourner la carte',
                child: GestureDetector(
                  onTap: () => setState(() => _flipped = !_flipped),
                  child: _FlipCard(
                    key: ValueKey(card.id),
                    flipped: _flipped,
                    animate: animate,
                    front: _IndexCard(
                      tone: tone,
                      corner: '$emoji ${chapter.title}',
                      label: 'Question',
                      difficulty: _difficulty(state.cards[card.id]),
                      text: card.front,
                      big: true,
                    ),
                    back: _IndexCard(
                      tone: tone,
                      corner: '$emoji ${card.concept}',
                      label: 'Réponse',
                      difficulty: _difficulty(state.cards[card.id]),
                      text: card.back,
                      big: false,
                      back: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_flipped)
                FilledButton(
                  onPressed: () => setState(() => _flipped = true),
                  child: const Text('Afficher la réponse'),
                )
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in Grade.values)
                      if (g == Grade.good)
                        FilledButton(
                          onPressed: () => _grade(card, g),
                          child: Text(g.label),
                        )
                      else
                        OutlinedButton(
                          onPressed: () => _grade(card, g),
                          child: Text(g.label),
                        ),
                  ],
                ),
            ],
          ),
          if (_celebrate) _MasteredBurst(animate: animate),
        ],
      ),
    );
  }
}

/// Difficulté estimée d'une carte : 0 nouvelle, 1 facile, 2 moyenne, 3 difficile.
int _difficulty(CardState? s) {
  if (s == null) return 0;
  if (s.ease < 2.0 || s.lapses >= 3) return 3;
  if (s.ease < 2.4) return 2;
  return 1;
}

/// Retournement 3D de la carte (instantané si les animations sont coupées).
class _FlipCard extends StatelessWidget {
  const _FlipCard({
    super.key,
    required this.flipped,
    required this.animate,
    required this.front,
    required this.back,
  });

  final bool flipped;
  final bool animate;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: flipped ? 1 : 0),
      duration: animate ? const Duration(milliseconds: 450) : Duration.zero,
      curve: Curves.easeInOut,
      builder: (context, t, _) {
        final angle = t * pi;
        final showBack = t >= 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: back,
                )
              : front,
        );
      },
    );
  }
}

/// Fiche bristol : ligne de couleur du module, lignes du cahier, coin
/// d'information et indicateur de difficulté.
class _IndexCard extends StatelessWidget {
  const _IndexCard({
    required this.tone,
    required this.corner,
    required this.label,
    required this.difficulty,
    required this.text,
    required this.big,
    this.back = false,
  });

  final Tone tone;
  final String corner;
  final String label;
  final int difficulty;
  final String text;
  final bool big;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final c = toneColors(tone, brightness);
    final paper = Paper.of(context);
    const levels = ['Nouvelle', 'Facile', 'Moyenne', 'Difficile'];
    return HandBox(
      fill: back ? c.fill : paper.page,
      stroke: c.ink,
      strokeWidth: 2.4,
      seed: back ? 61 : 60,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 300,
        child: Stack(
          children: [
            if (!back)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: CustomPaint(painter: _CardLines(paper.rule, c.ink)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          corner,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Hand.sansText(
                            context,
                            size: 12,
                          ).copyWith(fontWeight: FontWeight.w700, color: c.ink),
                        ),
                      ),
                      Semantics(
                        label: 'Difficulté : ${levels[difficulty]}',
                        excludeSemantics: true,
                        child: Row(
                          children: [
                            for (var i = 1; i <= 3; i++)
                              Padding(
                                padding: const EdgeInsets.only(left: 3),
                                child: Icon(
                                  difficulty == 0
                                      ? Icons.circle_outlined
                                      : (i <= difficulty
                                            ? Icons.circle
                                            : Icons.circle_outlined),
                                  size: 10,
                                  color: difficulty == 3
                                      ? toneColors(Tone.red, brightness).ink
                                      : c.ink,
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              levels[difficulty],
                              style: Hand.sansText(context, size: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label.toUpperCase(),
                              style: Hand.boxLabel(
                                context,
                                back ? Tone.green : tone,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              text,
                              textAlign: TextAlign.center,
                              style: big
                                  ? TextStyle(
                                      fontFamily: Hand.title,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                      color: paper.ink,
                                      height: 1.1,
                                    )
                                  : Hand.noteText(context)
                                        .copyWith(fontSize: 19),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    back
                        ? 'Comment vous en êtes-vous souvenu ?'
                        : '👆 Touchez la carte pour la retourner',
                    style: Hand.sansText(
                      context,
                      size: 12,
                    ).copyWith(color: paper.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardLines extends CustomPainter {
  _CardLines(this.rule, this.accent);

  final Color rule;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      const Offset(8, 42),
      Offset(size.width - 8, 42),
      Paint()
        ..color = accent.withValues(alpha: 0.7)
        ..strokeWidth = 2,
    );
    final p = Paint()
      ..color = rule
      ..strokeWidth = 1;
    for (var y = 74.0; y < size.height - 30; y += 30) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), p);
    }
  }

  @override
  bool shouldRepaint(_CardLines old) =>
      old.rule != rule || old.accent != accent;
}

/// Célébration discrète quand une carte devient maîtrisée.
class _MasteredBurst extends StatelessWidget {
  const _MasteredBurst({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final green = toneColors(Tone.green, Theme.of(context).brightness);
    final badge = Semantics(
      liveRegion: true,
      label: 'Carte maîtrisée',
      child: HandBox(
        fill: green.fill,
        stroke: green.ink,
        seed: 70,
        child: Text(
          '🏆 Carte maîtrisée !',
          style: TextStyle(
            fontFamily: Hand.title,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: green.ink,
          ),
        ),
      ),
    );
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.2),
        child: animate
            ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: badge,
              )
            : badge,
      ),
    );
  }
}
