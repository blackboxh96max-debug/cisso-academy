import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../logic/study_groups.dart';
import '../models/content.dart';
import 'notebook/palette.dart';
import 'outline_view.dart';

/// Vues proposées : celles dont le sommaire est chargé.
List<CourseView> availableViews(ContentLibrary library) => [
  for (final v in CourseView.values)
    if (library.outline(v).modules.isNotEmpty) v,
];

/// Vue en cours : celle choisie, si elle est disponible.
CourseView currentView(AppState state) {
  final views = availableViews(state.library);
  return views.contains(state.courseView)
      ? state.courseView
      : (views.firstOrNull ?? CourseView.orsysPlus);
}

/// Modules de la vue en cours.
List<StudyGroup> currentGroups(AppState state) =>
    studyGroups(state.library, currentView(state));

/// Couleur et emoji d'un module de la vue : ceux du module ORSYS, ou une
/// couleur par rang pour le livre MILE2.
(Tone, String) groupStyle(StudyGroup g) => g.moduleNumber != null
    ? moduleStyle(g.moduleNumber!)
    : (outlineTone(g.index), g.label == 'Prérequis' ? '🧰' : '📘');

/// Choix de la vue (livre MILE2, ORSYS, ORSYS enrichi). Le choix est le même
/// partout : accueil, cours, révisions, préparation à l'examen.
class CourseViewSelector extends StatelessWidget {
  const CourseViewSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final views = availableViews(state.library);
    if (views.length < 2) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<CourseView>(
        segments: [
          for (final v in views)
            ButtonSegment(value: v, label: Text(courseViewLabel(v))),
        ],
        selected: {currentView(state)},
        showSelectedIcon: false,
        onSelectionChanged: (v) =>
            AppScope.read(context).setCourseView(v.first),
      ),
    );
  }
}

/// Boutons « Tout déplier » et « Tout replier ».
class ExpandAllBar extends StatelessWidget {
  const ExpandAllBar({
    super.key,
    required this.onExpandAll,
    required this.onCollapseAll,
    this.leading,
  });

  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;

  /// Texte affiché à gauche (nombre de modules…).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ?leading,
        TextButton.icon(
          onPressed: onExpandAll,
          icon: const Icon(Icons.unfold_more, size: 20),
          label: const Text('Tout déplier'),
        ),
        TextButton.icon(
          onPressed: onCollapseAll,
          icon: const Icon(Icons.unfold_less, size: 20),
          label: const Text('Tout replier'),
        ),
      ],
    );
  }
}

/// Flèche d'un en-tête repliable, sur fond coloré.
class ExpandChevron extends StatelessWidget {
  const ExpandChevron({super.key, required this.open, this.onDark = true});

  final bool open;
  final bool onDark;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0.5 : 0,
    duration: const Duration(milliseconds: 180),
    child: Icon(
      Icons.expand_more,
      size: 30,
      color: onDark ? Colors.white : Paper.of(context).inkSoft,
      semanticLabel: open ? 'Replier' : 'Déplier',
    ),
  );
}
