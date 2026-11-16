import 'package:material_ui/material_ui.dart';

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

  const Tone(this.meaning, this.emoji);

  final String meaning;
  final String emoji;
}

/// Encre (texte, bordures) et fond pastel de chaque couleur.
class ToneColors {
  const ToneColors(this.ink, this.fill);

  final Color ink;
  final Color fill;
}

ToneColors toneColors(Tone tone, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final (Color ink, Color fill, Color darkInk) = switch (tone) {
    Tone.blue => (
      const Color(0xFF2F64C8),
      const Color(0xFFE7F0FF),
      const Color(0xFF8DB4FF),
    ),
    Tone.violet => (
      const Color(0xFF7446C9),
      const Color(0xFFF1EAFF),
      const Color(0xFFC3A6FF),
    ),
    Tone.green => (
      const Color(0xFF237F4C),
      const Color(0xFFE4F5EA),
      const Color(0xFF86D9A6),
    ),
    Tone.orange => (
      const Color(0xFFC0620F),
      const Color(0xFFFFEEDC),
      const Color(0xFFFFB878),
    ),
    Tone.red => (
      const Color(0xFFC23A33),
      const Color(0xFFFDE7E5),
      const Color(0xFFFF9B93),
    ),
    Tone.yellow => (
      const Color(0xFF8A6A00),
      const Color(0xFFFFF4BF),
      const Color(0xFFF2D35B),
    ),
    Tone.turquoise => (
      const Color(0xFF0E7C7B),
      const Color(0xFFDDF4F2),
      const Color(0xFF6ED8D2),
    ),
    Tone.pink => (
      const Color(0xFFB8336F),
      const Color(0xFFFDE5F0),
      const Color(0xFFFF97C4),
    ),
  };
  if (dark) {
    return ToneColors(darkInk, darkInk.withValues(alpha: 0.12));
  }
  return ToneColors(ink, fill);
}

/// Couleurs du « papier » et de l'encre.
class Paper {
  const Paper._({
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

  static const light = Paper._(
    page: Color(0xFFFFFBF2),
    background: Color(0xFFF4EEE1),
    ink: Color(0xFF26324A),
    inkSoft: Color(0xFF5E6A80),
    rule: Color(0xFFD9E6F5),
    margin: Color(0xFFF2A7A7),
    card: Color(0xFFFFFFFF),
  );

  static const dark = Paper._(
    page: Color(0xFF22252D),
    background: Color(0xFF181A20),
    ink: Color(0xFFE9E4D8),
    inkSoft: Color(0xFFADB3C0),
    rule: Color(0xFF30353F),
    margin: Color(0xFF6B3A3F),
    card: Color(0xFF2A2E37),
  );

  static Paper of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Couleur et emoji propres à chaque module (cartes, flashcards).
(Tone, String) moduleStyle(int number) => switch (number) {
  1 => (Tone.blue, '🛡️'),
  2 => (Tone.violet, '🔐'),
  3 => (Tone.turquoise, '🌐'),
  4 => (Tone.green, '💻'),
  _ => (Tone.orange, '🚑'),
};
