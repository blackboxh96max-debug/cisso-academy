import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import 'lesson_page.dart';
import 'quiz_hub_page.dart';
import 'revision_sheet_page.dart';
import 'widgets.dart';

class ChapterPage extends StatelessWidget {
  const ChapterPage({super.key, required this.chapterId});

  final String chapterId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final chapter = state.library.chapter(chapterId);
    final stats = state.stats.chapters.firstWhere(
      (c) => c.chapter.id == chapterId,
    );
    final module = state.library.module(chapter.moduleId);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(chapter.title)),
      body: ReadingList(
        children: [
          Text(
            'Module ${module.number} · ${module.title}',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Domaine officiel : ${chapter.domainIds.map((d) {
              final dom = state.library.domain(d);
              return '${dom.nameFr} (${dom.weight} % de l\'examen)';
            }).join(', ')}',
          ),
          const SizedBox(height: 12),
          LabeledProgress(
            label: 'Progression du chapitre',
            value: stats.progress,
          ),
          Text('Statut : ${stats.status.label}'),
          const SectionTitle('Leçons'),
          Card(
            child: Column(
              children: [
                for (final (i, lesson) in chapter.lessons.indexed)
                  ListTile(
                    leading: CircleAvatar(
                      child: state.readLessons.contains(lesson.id)
                          ? const Icon(Icons.check)
                          : Text('${i + 1}'),
                    ),
                    title: Text(lesson.title),
                    subtitle: Text('Environ ${lesson.minutes} min'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LessonPage(lesson: lesson),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle('S\'entraîner et réviser'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => startPractice(context, chapterId: chapterId),
                icon: const Icon(Icons.quiz_outlined),
                label: Text('QCM du chapitre (${chapter.questions.length})'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RevisionSheetPage(chapter: chapter),
                  ),
                ),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Fiche de révision'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
