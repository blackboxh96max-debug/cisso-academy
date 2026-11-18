import 'package:material_ui/material_ui.dart';

import 'look.dart';

/// Code couleur pédagogique : une couleur = une signification, partout.
enum Tone {
  /// Concepts fondamentaux et définitions.
  blue('Définition', '📘'),

  /// Notions importantes et approfondissement.
  violet('Important', '⭐'),

  /// Bonnes pratiques et recommandations.
  green('Bonne pratique', '✅'),

  /// Astuces, conseils et points à retenir.
  orange('À retenir', '💡'),

  /// Risques, vulnérabilités, erreurs et alertes.
  red('Risque', '🚨'),

  /// Notes manuscrites et mémorisation.
  yellow('Mémorisation', '🧠'),

  /// Exemples et cas pratiques.
  turquoise('Exemple', '🌍'),

  /// Questions à se poser et pièges d'examen.
  pink('Piège d\'examen', '⚠️');

  const Tone(this.meaning, this.classicEmoji);

  final String meaning;

  /// Émoji du cahier d'origine.
  final String classicEmoji;

  /// Émoji de ce type d'encadré dans le thème en cours.
  String get emoji => AppLook.active.toneEmojis[this] ?? classicEmoji;
}

/// Encre (texte, bordures) et fond pastel de chaque couleur.
class ToneColors {
  const ToneColors(this.ink, this.fill);

  final Color ink;
  final Color fill;
}

/// Couleurs d'un ton dans le thème en cours.
ToneColors toneColors(Tone tone, Brightness brightness) =>
    AppLook.active.colors(tone, brightness);

/// Couleur vive et pleine de chaque ton (bandeaux, badges, dégradés).
Color toneBright(Tone tone) => AppLook.active.bright(tone);

/// Dégradé lumineux entre deux tons (cartes motivantes).
LinearGradient toneGradient(Tone a, Tone b) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [toneBright(a), toneBright(b)],
);

/// Couleurs du « papier » et de l'encre.
class Paper {
  const Paper({
    required this.page,
    required this.background,
    required this.ink,
    required this.inkSoft,
    required this.rule,
    required this.margin,
    required this.card,
  });

  /// Page de cahier (crème).
  final Color page;

  /// Fond derrière les pages.
  final Color background;

  /// Encre principale (bleu nuit).
  final Color ink;
  final Color inkSoft;

  /// Lignes horizontales du cahier.
  final Color rule;

  /// Ligne rouge de marge.
  final Color margin;

  /// Fond des fiches et cartes.
  final Color card;

  /// Papier du thème en cours.
  static Paper of(BuildContext context) =>
      AppLook.active.paper(Theme.of(context).brightness);
}

/// Couleur et emoji propres à chaque module (cartes, flashcards).
(Tone, String) moduleStyle(int number) => (
  switch (number) {
    1 => Tone.blue,
    2 => Tone.violet,
    3 => Tone.turquoise,
    4 => Tone.green,
    _ => Tone.orange,
  },
  AppLook.active.moduleEmoji(number),
);
