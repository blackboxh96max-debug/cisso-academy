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
      const Color(0xFF1F5FE0),
      const Color(0xFFDCE9FF),
      const Color(0xFF8DB4FF),
    ),
    Tone.violet => (
      const Color(0xFF7A3BE6),
      const Color(0xFFEDE1FF),
      const Color(0xFFC3A6FF),
    ),
    Tone.green => (
      const Color(0xFF14935A),
      const Color(0xFFD5F7E3),
      const Color(0xFF86D9A6),
    ),
    Tone.orange => (
      const Color(0xFFE5670A),
      const Color(0xFFFFE7CC),
      const Color(0xFFFFB878),
    ),
    Tone.red => (
      const Color(0xFFE0322B),
      const Color(0xFFFFDEDB),
      const Color(0xFFFF9B93),
    ),
    Tone.yellow => (
      const Color(0xFF9A6F00),
      const Color(0xFFFFF0A8),
      const Color(0xFFF2D35B),
    ),
    Tone.turquoise => (
      const Color(0xFF07928F),
      const Color(0xFFCDF5F1),
      const Color(0xFF6ED8D2),
    ),
    Tone.pink => (
      const Color(0xFFE0287A),
      const Color(0xFFFFDCEC),
      const Color(0xFFFF97C4),
    ),
  };
  if (dark) {
    return ToneColors(darkInk, darkInk.withValues(alpha: 0.12));
  }
  return ToneColors(ink, fill);
}

/// Couleur vive et pleine de chaque ton (bandeaux, badges, dégradés).
Color toneBright(Tone tone) => switch (tone) {
  Tone.blue => const Color(0xFF3B82F6),
  Tone.violet => const Color(0xFF8B5CF6),
  Tone.green => const Color(0xFF10B981),
  Tone.orange => const Color(0xFFF97316),
  Tone.red => const Color(0xFFEF4444),
  Tone.yellow => const Color(0xFFF5B800),
  Tone.turquoise => const Color(0xFF06B6D4),
  Tone.pink => const Color(0xFFEC4899),
};

/// Dégradé lumineux entre deux tons (cartes motivantes).
LinearGradient toneGradient(Tone a, Tone b) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [toneBright(a), toneBright(b)],
);

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
