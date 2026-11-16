import 'package:material_ui/material_ui.dart';

import 'palette.dart';

/// Rôles typographiques du cahier.
///
/// - Titres : Caveat (manuscrit expressif).
/// - Corps du cours et notes : Patrick Hand (manuscrit très lisible).
/// - Définitions et commentaires du formateur : Kalam.
/// - Interface, tableaux, références : Nunito (sans-serif lisible).
/// - Termes techniques, commandes, IP : JetBrains Mono.
class Hand {
  static const title = 'Caveat';
  static const body = 'PatrickHand';
  static const note = 'Kalam';
  static const sans = 'Nunito';
  static const mono = 'JetBrainsMono';

  static TextStyle chapterTitle(BuildContext context, {Color? color}) =>
      TextStyle(
        fontFamily: title,
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: color ?? toneColors(Tone.blue, Theme.of(context).brightness).ink,
      );

  static TextStyle subtitle(BuildContext context, Tone tone) => TextStyle(
    fontFamily: title,
    fontSize: 30,
    height: 1.1,
    fontWeight: FontWeight.w700,
    color: toneColors(tone, Theme.of(context).brightness).ink,
  );

  static TextStyle boxLabel(BuildContext context, Tone tone) => TextStyle(
    fontFamily: sans,
    fontSize: 12.5,
    letterSpacing: 1.1,
    fontWeight: FontWeight.w800,
    color: toneColors(tone, Theme.of(context).brightness).ink,
  );

  /// Corps du cours : grande taille pour le confort de lecture.
  static TextStyle bodyText(BuildContext context) => TextStyle(
    fontFamily: body,
    fontSize: 20,
    height: 1.45,
    color: Paper.of(context).ink,
  );

  static TextStyle definition(BuildContext context) => TextStyle(
    fontFamily: note,
    fontSize: 18,
    height: 1.5,
    color: Paper.of(context).ink,
  );

  static TextStyle noteText(BuildContext context) => TextStyle(
    fontFamily: note,
    fontSize: 18,
    height: 1.45,
    color: Paper.of(context).ink,
  );

  static TextStyle sansText(BuildContext context, {double size = 15}) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        height: 1.4,
        color: Paper.of(context).ink,
      );

  static TextStyle monoText(BuildContext context) =>
      TextStyle(fontFamily: mono, fontSize: 14, color: Paper.of(context).ink);
}
