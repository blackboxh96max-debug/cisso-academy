import 'package:material_ui/material_ui.dart';

import 'notebook/hand_drawn.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Historique récent (recherches ou questions) : un appui relance l'entrée,
/// la croix la supprime, « Tout effacer » vide l'historique.
class HistoryList extends StatelessWidget {
  const HistoryList({
    super.key,
    required this.title,
    required this.entries,
    required this.onPick,
    required this.onRemove,
    required this.onClear,
    this.icon = Icons.history,
    this.tone = Tone.blue,
  });

  final String title;
  final List<String> entries;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final paper = Paper.of(context);
    final c = toneColors(tone, Theme.of(context).brightness);
    return HandBox(
      fill: paper.card,
      stroke: toneBright(tone),
      strokeWidth: 1.8,
      seed: 733,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: c.ink),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Hand.sansText(
                    context,
                    size: 15,
                  ).copyWith(fontWeight: FontWeight.w800, color: c.ink),
                ),
              ),
              TextButton(
                onPressed: () => _confirmClear(context),
                child: const Text('Tout effacer'),
              ),
            ],
          ),
          for (final e in entries)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 8),
              visualDensity: VisualDensity.compact,
              leading: Icon(Icons.north_west, size: 18, color: paper.inkSoft),
              minLeadingWidth: 20,
              title: Text(
                e,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Hand.sansText(context, size: 15.5),
              ),
              onTap: () => onPick(e),
              trailing: IconButton(
                tooltip: 'Supprimer « $e »',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => onRemove(e),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Effacer l\'historique ?'),
        content: Text(
          '$title : ${entries.length} entrée(s) seront supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (ok ?? false) onClear();
  }
}
