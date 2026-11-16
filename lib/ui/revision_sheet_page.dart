import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/content.dart';
import 'widgets.dart';

/// Fiche de révision d'un chapitre, consultable hors ligne et copiable.
class RevisionSheetPage extends StatelessWidget {
  const RevisionSheetPage({super.key, required this.chapter});

  final Chapter chapter;

  String get plainText => chapter.revisionSheet
      .map((l) => l.startsWith('# ') ? l.substring(2).toUpperCase() : '• $l')
      .join('\n');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche de révision'),
        actions: [
          IconButton(
            tooltip: 'Copier la fiche',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: plainText));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Fiche copiée')));
              }
            },
          ),
        ],
      ),
      body: ReadingList(
        children: [
          for (final line in chapter.revisionSheet)
            if (line.startsWith('# '))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(line.substring(2), style: text.titleLarge),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(
                      child: SelectableText(line, style: text.bodyLarge),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
