import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../data/progress_store.dart';
import '../logic/spaced_repetition.dart';
import '../models/content.dart';
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
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: ReadingList(
        children: [
          TileGrid(
            children: [
              StatTile(label: 'À réviser', value: '$seenDue'),
              StatTile(label: 'Nouvelles', value: '$fresh'),
              StatTile(
                label: 'Maîtrisées',
                value: '$mastered/${allIds.length}',
              ),
              StatTile(label: 'Total', value: '${allIds.length}'),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: due.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          FlashcardSessionPage(cardIds: due.take(20).toList()),
                    ),
                  ),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              due.isEmpty
                  ? 'Rien à réviser pour l\'instant'
                  : 'Réviser ${due.length > 20 ? 20 : due.length} carte(s)',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Les cartes ratées reviennent dans la même session, puis à intervalles '
            'croissants (1 jour, 6 jours, puis plus). Une carte est maîtrisée '
            'quand son intervalle atteint 21 jours.',
            style: text.bodySmall,
          ),
          const SectionTitle('Par chapitre'),
          for (final ch in library.availableChapters)
            Card(
              child: ListTile(
                title: Text(ch.title),
                subtitle: Text(
                  '${ch.flashcards.where((f) => state.cards[f.id]?.mastered ?? false).length}'
                  '/${ch.flashcards.length} maîtrisées',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FlashcardSessionPage(
                      cardIds: ch.flashcards.map((f) => f.id).toList(),
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

  Future<void> _grade(Flashcard card, Grade grade) async {
    final state = AppScope.read(context);
    final now = state.now();
    final current = state.cards[card.id] ?? CardState.initial(card.id, now);
    await state.saveCard(review(current, grade, now));
    setState(() {
      _queue.removeAt(0);
      if (grade == Grade.again) {
        _queue.add(card.id); // revient en fin de session
      }
      _flipped = false;
      _done++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Révision terminée')),
        body: ReadingList(
          children: [
            Text('$_done carte(s) révisée(s).', style: text.titleLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
          ],
        ),
      );
    }
    final card = state.library.flashcards.firstWhere(
      (f) => f.id == _queue.first,
    );
    return Scaffold(
      appBar: AppBar(title: Text('Flashcards · ${_queue.length} restante(s)')),
      body: ReadingList(
        children: [
          GestureDetector(
            onTap: () => setState(() => _flipped = !_flipped),
            child: Card(
              color: _flipped ? scheme.secondaryContainer : null,
              child: SizedBox(
                height: 260,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _flipped ? 'Réponse' : 'Question',
                          style: text.labelMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _flipped ? card.back : card.front,
                          style: _flipped
                              ? text.titleMedium
                              : text.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Notion : ${card.concept}',
            textAlign: TextAlign.center,
            style: text.bodySmall,
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
    );
  }
}
