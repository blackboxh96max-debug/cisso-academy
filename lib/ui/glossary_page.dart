import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import 'widgets.dart';

/// Glossaire bilingue anglais/français, avec recherche hors ligne.
class GlossaryPage extends StatefulWidget {
  const GlossaryPage({super.key});

  @override
  State<GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends State<GlossaryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final terms = AppScope.of(context).library.glossary
        .where((t) => t.matches(_query))
        .toList();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Glossaire')),
      body: ReadingList(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Rechercher (français, anglais ou acronyme)',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Text('${terms.length} terme(s)', style: text.bodySmall),
          const SizedBox(height: 8),
          for (final t in terms)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(t.termFr),
                subtitle: Text([t.termEn, ?t.acronym].join(' · ')),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(t.definition),
                  const SizedBox(height: 8),
                  Text('Exemple', style: text.labelLarge),
                  Text(t.example),
                  const SizedBox(height: 8),
                  SourceBadge(t.kind),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
