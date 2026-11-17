import 'package:material_ui/material_ui.dart';

import '../logic/search.dart';

/// Mots cherchés dans la leçon ouverte, à surligner dans tous ses textes.
class FindHighlight extends InheritedWidget {
  const FindHighlight({super.key, required this.words, required super.child});

  /// Mots tels que tapés ; vide quand rien n'est cherché.
  final List<String> words;

  static List<String> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FindHighlight>()?.words ??
      const [];

  @override
  bool updateShouldNotify(FindHighlight old) =>
      old.words.join(' ') != words.join(' ');
}

/// Découpe une recherche en mots.
List<String> findWords(String query) =>
    query.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Vrai si le texte contient tous les mots (en début de mot), sans tenir
/// compte des accents.
bool containsAllWords(String text, List<String> words) {
  if (words.isEmpty) return false;
  return words.every((w) => findAll(text, w).isNotEmpty);
}

/// Fond des passages trouvés : un surligneur jaune, lisible en sombre aussi.
TextStyle highlightStyle(BuildContext context) => TextStyle(
  backgroundColor: Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF8A6D00)
      : const Color(0xFFFFE066),
);

/// Le texte [text] découpé pour surligner chacun des [words].
List<InlineSpan> highlightSpans(
  String text,
  List<String> words,
  TextStyle mark,
) {
  if (words.isEmpty || text.isEmpty) return [TextSpan(text: text)];
  final ranges = <(int, int)>[for (final w in words) ...findAll(text, w)]
    ..sort((a, b) => a.$1.compareTo(b.$1));
  if (ranges.isEmpty) return [TextSpan(text: text)];
  final spans = <InlineSpan>[];
  var pos = 0;
  for (final (start, end) in ranges) {
    if (end <= pos) continue;
    final s = start < pos ? pos : start;
    if (s > pos) spans.add(TextSpan(text: text.substring(pos, s)));
    spans.add(TextSpan(text: text.substring(s, end), style: mark));
    pos = end;
  }
  if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
  return spans;
}

/// Un texte simple qui surligne les mots cherchés dans la leçon.
class FindText extends StatelessWidget {
  const FindText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final words = FindHighlight.of(context);
    if (words.isEmpty) return Text(text, style: style, textAlign: textAlign);
    return Text.rich(
      TextSpan(
        style: style,
        children: highlightSpans(text, words, highlightStyle(context)),
      ),
      textAlign: textAlign,
    );
  }
}
