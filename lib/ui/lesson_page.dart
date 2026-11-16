import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models/content.dart';
import 'widgets.dart';

/// Lecture d'une leçon. Elle est marquée comme lue quand l'apprenant
/// atteint la fin ou appuie sur « J'ai terminé ».
class LessonPage extends StatelessWidget {
  const LessonPage({super.key, required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final read = state.readLessons.contains(lesson.id);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: ReadingList(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Objectifs', style: text.titleSmall),
                  const SizedBox(height: 8),
                  for (final o in lesson.objectives) _Bullet(o),
                ],
              ),
            ),
          ),
          for (final block in lesson.blocks) LessonBlockView(block),
          if (lesson.references.isNotEmpty) ...[
            const SectionTitle('Ressources'),
            for (final r in lesson.references)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(r.title),
                    if (r.url != null)
                      SelectableText(
                        '${r.url} (en ligne)',
                        style: text.bodySmall,
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          Center(
            child: read
                ? const Chip(
                    avatar: Icon(Icons.check),
                    label: Text('Leçon lue'),
                  )
                : FilledButton.icon(
                    onPressed: () async {
                      await AppScope.read(context).markLessonRead(lesson.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('J\'ai terminé cette leçon'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Affiche un bloc de leçon selon son type.
class LessonBlockView extends StatelessWidget {
  const LessonBlockView(this.block, {super.key});

  final LessonBlock block;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final badge = block.kind == null ? null : SourceBadge(block.kind!);

    Widget boxed(Widget child, {Color? color, IconData? icon, String? title}) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Card(
          color: color,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null || badge != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20),
                          const SizedBox(width: 8),
                        ],
                        if (title != null)
                          Expanded(child: Text(title, style: text.titleSmall))
                        else
                          const Spacer(),
                        ?badge,
                      ],
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
      );
    }

    switch (block.type) {
      case BlockType.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 4),
          child: Text(block.text ?? '', style: text.titleLarge),
        );
      case BlockType.text:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(block.text ?? '', style: text.bodyLarge),
              if (badge != null) ...[const SizedBox(height: 6), badge],
            ],
          ),
        );
      case BlockType.bullets:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(children: [for (final i in block.items) _Bullet(i)]),
        );
      case BlockType.definition:
        return boxed(
          SelectableText(block.text ?? ''),
          title: block.title,
          icon: Icons.bookmark_outline,
        );
      case BlockType.socCase:
        return boxed(
          SelectableText(block.text ?? ''),
          title: block.title ?? 'Cas SOC',
          icon: Icons.security,
          color: scheme.secondaryContainer.withValues(alpha: 0.5),
        );
      case BlockType.viewpoints:
        return boxed(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final item in block.items) _Viewpoint(item)],
          ),
          title: block.title ?? 'Points de vue',
          icon: Icons.groups_outlined,
        );
      case BlockType.table:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _LessonTable(rows: block.rows),
        );
      case BlockType.steps:
        return boxed(
          Column(
            children: [
              for (final (i, step) in block.items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        child: Text('${i + 1}', style: text.labelSmall),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(step)),
                    ],
                  ),
                ),
            ],
          ),
          title: block.title,
          icon: Icons.account_tree_outlined,
        );
      case BlockType.pitfalls:
        return boxed(
          Column(children: [for (final i in block.items) _Bullet(i)]),
          title: block.title ?? 'Pièges à éviter',
          icon: Icons.warning_amber_outlined,
          color: scheme.errorContainer.withValues(alpha: 0.4),
        );
      case BlockType.summary:
        return boxed(
          Column(children: [for (final i in block.items) _Bullet(i)]),
          title: block.title ?? 'À retenir',
          icon: Icons.lightbulb_outline,
          color: scheme.primaryContainer.withValues(alpha: 0.5),
        );
    }
  }
}

class _Viewpoint extends StatelessWidget {
  const _Viewpoint(this.item);

  final String item;

  @override
  Widget build(BuildContext context) {
    final i = item.indexOf(':');
    if (i < 0) return _Bullet(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: item.substring(0, i).trim(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: ' : ${item.substring(i + 1).trim()}'),
          ],
        ),
      ),
    );
  }
}

/// Tableau pédagogique : défilement horizontal sur petit écran.
class _LessonTable extends StatelessWidget {
  const _LessonTable({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final header = rows.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = header.length * 180.0;
        final table = Table(
          border: TableBorder.all(color: scheme.outlineVariant),
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            TableRow(
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
              children: [
                for (final h in header)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      h,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            for (final r in rows.skip(1))
              TableRow(
                children: [
                  for (final cell in r)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(cell),
                    ),
                ],
              ),
          ],
        );
        if (constraints.maxWidth >= minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: table),
        );
      },
    );
  }
}
