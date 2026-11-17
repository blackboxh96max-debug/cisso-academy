import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../logic/terms.dart';
import '../models/content.dart';
import 'bilingual.dart';
import 'glossary_page.dart';
import 'lesson_page.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Mots-clés cliquables d'une leçon : un appui ouvre une fiche avec la
/// définition courte (français et anglais) et un lien vers la définition
/// complète ; à la souris, la fiche apparaît aussi au survol.
///
/// Les reconnaisseurs d'appui sont gardés ici et libérés avec la page.
class TermLinks extends StatefulWidget {
  const TermLinks({super.key, required this.child});

  final Widget child;

  /// L'état le plus proche, ou `null` (pas de liens hors d'une leçon).
  static TermLinksState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TermLinksScope>()?.state;

  @override
  State<TermLinks> createState() => TermLinksState();
}

class TermLinksState extends State<TermLinks> {
  final _taps = <Object, TapGestureRecognizer>{};
  OverlayEntry? _hover;
  String? _hoverId;
  Timer? _showTimer;
  Timer? _hideTimer;

  /// Le reconnaisseur d'appui d'un terme à un endroit du texte.
  TapGestureRecognizer tapFor(Object key, GlossaryTerm term) =>
      _taps[key] ??= TapGestureRecognizer()
        ..onTap = () {
          _removeHover();
          showTermCard(context, term);
        };

  /// Survol à la souris : la fiche apparaît après un court délai, près du
  /// pointeur.
  void hoverEnter(GlossaryTerm term, Offset position) {
    _hideTimer?.cancel();
    if (_hoverId == term.id && _hover != null) return;
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _removeHover();
      _hoverId = term.id;
      final overlay = Overlay.of(context);
      final box = overlay.context.findRenderObject() as RenderBox?;
      final local = box?.globalToLocal(position) ?? position;
      final size = box?.size ?? MediaQuery.sizeOf(context);
      const width = 340.0;
      final left = (local.dx - 40).clamp(8.0, size.width - width - 8);
      final below = local.dy < size.height * 0.6;
      _hover = OverlayEntry(
        builder: (_) => Positioned(
          left: left < 8 ? 8 : left,
          width: width,
          top: below ? local.dy + 18 : null,
          bottom: below ? null : size.height - local.dy + 18,
          child: MouseRegion(
            onEnter: (_) => _hideTimer?.cancel(),
            onExit: (_) => hoverExit(),
            child: Material(
              type: MaterialType.transparency,
              child: TermCard(
                term: term,
                compact: true,
                onOpen: () {
                  _removeHover();
                  openTermDefinition(context, term);
                },
              ),
            ),
          ),
        ),
      );
      overlay.insert(_hover!);
    });
  }

  void hoverExit() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 250), _removeHover);
  }

  void _removeHover() {
    _showTimer?.cancel();
    _hover?.remove();
    _hover?.dispose();
    _hover = null;
    _hoverId = null;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeHover();
    for (final r in _taps.values) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _TermLinksScope(state: this, child: widget.child);
}

class _TermLinksScope extends InheritedWidget {
  const _TermLinksScope({required this.state, required super.child});

  final TermLinksState state;

  @override
  bool updateShouldNotify(_TermLinksScope old) => old.state != state;
}

/// Style d'un mot-clé cliquable : souligné en pointillés, couleur du lien.
TextStyle termLinkStyle(BuildContext context, TextStyle base) {
  final color = toneColors(Tone.violet, Theme.of(context).brightness).ink;
  return base.copyWith(
    color: color,
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.dotted,
    decorationColor: color,
    decorationThickness: 2,
  );
}

/// Fiche d'un terme en bas de l'écran (après un appui).
Future<void> showTermCard(BuildContext context, GlossaryTerm term) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TermCard(
            term: term,
            onOpen: () {
              Navigator.of(sheet).pop();
              openTermDefinition(context, term);
            },
          ),
        ),
      ),
    );

/// Ouvre la définition complète : la leçon qui définit le terme (au bloc
/// « Définition »), sinon le glossaire filtré sur ce terme.
void openTermDefinition(BuildContext context, GlossaryTerm term) {
  final state = AppScope.read(context);
  final home = termHomes(state.library, state.terms)[term.id];
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => home == null
          ? GlossaryPage(initialQuery: term.termFr)
          : LessonPage(lesson: home.lesson, focusBlock: home.block),
    ),
  );
}

/// Contenu de la fiche : nom français, anglais et sigle, définition courte,
/// exemple et lien vers la définition complète.
class TermCard extends StatelessWidget {
  const TermCard({
    super.key,
    required this.term,
    required this.onOpen,
    this.compact = false,
  });

  final GlossaryTerm term;
  final VoidCallback onOpen;

  /// Version au survol : sans l'exemple.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final home = termHomes(state.library, state.terms)[term.id];
    final paper = Paper.of(context);
    final tone = toneColors(Tone.violet, Theme.of(context).brightness);
    final sameName =
        normalize(term.termFr).trim() == normalize(term.termEn).trim();
    return HandBox(
      fill: paper.card,
      stroke: tone.ink,
      strokeWidth: 2,
      seed: 917,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            term.acronym == null || term.termFr.contains(term.acronym!)
                ? term.termFr
                : '${term.termFr} (${term.acronym})',
            style: Hand.subtitle(
              context,
              Tone.violet,
            ).copyWith(fontSize: compact ? 24 : 28),
          ),
          if (!sameName) EnTag(term.termEn),
          const SizedBox(height: 8),
          Text(
            term.definition,
            style: Hand.sansText(context, size: compact ? 14.5 : 16),
          ),
          if (!compact && term.example.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Exemple : ${term.example}',
              style: Hand.sansText(
                context,
                size: 14.5,
              ).copyWith(color: paper.inkSoft, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onOpen,
              icon: Icon(
                home == null ? Icons.menu_book_outlined : Icons.school_outlined,
                size: 18,
              ),
              label: Text(
                home == null
                    ? 'Voir dans le glossaire'
                    : 'Voir la définition complète',
              ),
            ),
          ),
          if (home != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Leçon « ${home.lesson.title} »',
                textAlign: TextAlign.right,
                style: Hand.sansText(
                  context,
                  size: 12.5,
                ).copyWith(color: paper.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}
