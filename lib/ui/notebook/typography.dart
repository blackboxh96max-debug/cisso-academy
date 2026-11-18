import 'package:material_ui/material_ui.dart';

import 'look.dart';
import 'palette.dart';

/// Rôles typographiques du cahier.
///
/// - Titres : Caveat (manuscrit expressif).
/// - Corps du cours et notes : Patrick Hand (manuscrit très lisible).
/// - Définitions et commentaires du formateur : Kalam.
/// - Interface, tableaux, références : Nunito (sans-serif lisible).
/// - Termes techniques, commandes, IP : JetBrains Mono.
///
/// Les autres thèmes ([AppLook]) remplacent ces polices ; les tailles
/// indiquées pour le cahier passent par [tsize] (titres) et [bsize] (corps
/// et notes) pour rester équivalentes.
class Hand {
  static String get title => AppLook.active.titleFont;
  static String get body => AppLook.active.bodyFont;
  static String get note => AppLook.active.noteFont;
  static String get sans => AppLook.active.sansFont;
  static const mono = 'JetBrainsMono';

  /// Taille d'un titre, donnée pour la police manuscrite du cahier.
  static double tsize(double size) => size * AppLook.active.titleScale;

  /// Taille d'un texte de cours ou de note, donnée pour le cahier.
  static double bsize(double size) => size * AppLook.active.bodyScale;

  /// Graisse des titres.
  static FontWeight get titleWeight => AppLook.active.titleWeight;

  static TextStyle chapterTitle(BuildContext context, {Color? color}) =>
      TextStyle(
        fontFamily: title,
        fontSize: Hand.tsize(40),
        height: 1.05,
        fontWeight: Hand.titleWeight,
        color: color ?? toneColors(Tone.blue, Theme.of(context).brightness).ink,
      );

  static TextStyle subtitle(BuildContext context, Tone tone) => TextStyle(
    fontFamily: title,
    fontSize: Hand.tsize(30),
    height: 1.1,
    fontWeight: Hand.titleWeight,
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
    fontSize: Hand.bsize(20),
    height: 1.45,
    color: Paper.of(context).ink,
  );

  static TextStyle definition(BuildContext context) => TextStyle(
    fontFamily: note,
    fontSize: Hand.bsize(18),
    height: 1.5,
    color: Paper.of(context).ink,
  );

  static TextStyle noteText(BuildContext context) => TextStyle(
    fontFamily: note,
    fontSize: Hand.bsize(18),
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
