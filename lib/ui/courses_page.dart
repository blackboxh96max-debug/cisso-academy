import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import 'chapter_page.dart';
import 'widgets.dart';

/// Programme : 5 modules, chacun rattaché aux domaines officiels MILE2.
class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final library = state.library;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cours')),
      body: ReadingList(
        children: [
          for (final m in library.modules) ...[
            SectionTitle('Module ${m.number} · ${m.title}'),
            LabeledProgress(
              label: 'Progression',
              value: state.stats.moduleProgress(m.id),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final c in m.chapters)
                    ListTile(
                      enabled: c.available,
                      leading: Icon(
                        c.available
                            ? Icons.menu_book_outlined
                            : Icons.hourglass_empty,
                      ),
                      title: Text(c.title),
                      subtitle: Text(
                        c.available
                            ? '${c.lessons.length} leçons · ${c.questions.length} questions · '
                                  '${c.flashcards.length} flashcards'
                            : 'Contenu à venir'
                                  '${c.domainIds.isEmpty ? '' : ' · domaine ${c.domainIds.map((d) => library.domain(d).nameFr).join(', ')}'}',
                      ),
                      trailing: c.available
                          ? const Icon(Icons.chevron_right)
                          : null,
                      iconColor: c.available ? scheme.primary : null,
                      onTap: c.available
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChapterPage(chapterId: c.id),
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
