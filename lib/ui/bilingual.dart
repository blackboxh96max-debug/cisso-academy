import 'package:material_ui/material_ui.dart';

import '../logic/terms.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Couleur des termes anglais : un bleu lisible sur le papier clair ou sombre.
Color englishColor(BuildContext context) =>
    toneColors(Tone.blue, Theme.of(context).brightness).ink;

/// Petite étiquette « EN » suivie du terme anglais, sous un titre français.
class EnTag extends StatelessWidget {
  const EnTag(this.english, {super.key, this.onDark = false, this.size = 13});

  final String english;
  final bool onDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : englishColor(context);
    return Semantics(
      label: 'En anglais : $english',
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: color.withValues(alpha: 0.7)),
            ),
            child: Text(
              'EN',
              style: TextStyle(
                fontFamily: Hand.sans,
                fontSize: size - 3,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: color,
              ),
            ),
          ),
          Text(
            english,
            style: TextStyle(
              fontFamily: Hand.sans,
              fontSize: size,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Le texte [text] avec, après chaque terme clé repéré, son équivalent
/// anglais entre parenthèses.
TextSpan bilingualSpan(
  BuildContext context,
  String text,
  List<TermMatch> matches,
  TextStyle style,
) {
  if (matches.isEmpty) return TextSpan(text: text, style: style);
  final en = style.copyWith(
    color: englishColor(context),
    fontStyle: FontStyle.italic,
    fontSize: (style.fontSize ?? 16) * 0.86,
  );
  final spans = <InlineSpan>[];
  var pos = 0;
  for (final m in matches) {
    spans.add(TextSpan(text: text.substring(pos, m.end)));
    spans.add(TextSpan(text: ' (${m.term.termEn})', style: en));
    pos = m.end;
  }
  spans.add(TextSpan(text: text.substring(pos)));
  return TextSpan(style: style, children: spans);
}

/// Plan d'annotation d'une leçon : pour chaque texte, les termes à traduire.
/// Chaque terme n'est traduit qu'à sa première apparition dans la leçon.
class TermPlan extends InheritedWidget {
  const TermPlan({super.key, required this.plan, required super.child});

  /// Clé : le bloc, ou (bloc, numéro d'élément) pour une liste.
  final Map<Object, List<TermMatch>> plan;

  static List<TermMatch> matchesFor(BuildContext context, Object key) =>
      context.dependOnInheritedWidgetOfExactType<TermPlan>()?.plan[key] ??
      const [];

  @override
  bool updateShouldNotify(TermPlan old) => old.plan != plan;
}

/// Texte sélectionnable avec les termes anglais.
class BilingualText extends StatelessWidget {
  const BilingualText(
    this.text, {
    super.key,
    required this.planKey,
    required this.style,
    this.selectable = true,
  });

  final String text;
  final Object planKey;
  final TextStyle style;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final span = bilingualSpan(
      context,
      text,
      TermPlan.matchesFor(context, planKey),
      style,
    );
    return selectable ? SelectableText.rich(span) : Text.rich(span);
  }
}
