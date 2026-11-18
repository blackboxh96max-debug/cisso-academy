import 'package:material_ui/material_ui.dart';

import 'palette.dart';

/// Style de tableau des leçons.
enum TableLook {
  /// Lignes de séparation intérieures, en-tête manuscrit (cahier).
  hand,

  /// Grille complète et fine, en-tête sobre (classique).
  grid,

  /// Lignes alternées sans grille (moderne, lecture).
  zebra,

  /// Cadre lumineux et en-tête inversé (terminal).
  neon,
}

/// Thème de l'application : polices, papier, couleurs, émojis, tracé des
/// dessins et style des tableaux. Tout est inclus dans l'application.
///
/// Le thème actif est [AppLook.active] : les fonctions de couleurs
/// ([toneColors], [Paper.of]…) et les styles de texte ([Hand]) le lisent.
/// Il est fixé par l'application à chaque construction du thème Material.
@immutable
class AppLook {
  const AppLook({
    required this.id,
    required this.name,
    required this.description,
    required this.preview,
    required this.titleFont,
    required this.bodyFont,
    required this.noteFont,
    required this.sansFont,
    required this.seed,
    required this.paperLight,
    required this.paperDark,
    required this.inks,
    required this.toneEmojis,
    required this.moduleEmojis,
    required this.heroGradient,
    this.titleScale = 1,
    this.bodyScale = 1,
    this.titleWeight = FontWeight.w700,
    this.wobble = 1,
    this.radius = 16,
    this.ruled = true,
    this.tilt = true,
    this.shadow = true,
    this.table = TableLook.hand,
    this.darkOnly = false,
  });

  final String id;
  final String name;
  final String description;

  /// Petit symbole affiché dans le choix du thème.
  final String preview;

  /// Polices : titres, corps du cours, définitions et notes, interface.
  final String titleFont;
  final String bodyFont;
  final String noteFont;
  final String sansFont;

  /// Les tailles du cahier sont pensées pour Caveat et Patrick Hand, très
  /// étroites : les autres polices sont ramenées à une taille équivalente.
  final double titleScale;
  final double bodyScale;
  final FontWeight titleWeight;

  /// Couleur de base du thème Material (boutons, champs, sélections).
  final Color seed;
  final Paper paperLight;
  final Paper paperDark;

  /// Encres des huit couleurs pédagogiques : (clair, sombre).
  final Map<Tone, (Color, Color)> inks;

  /// Émoji de chaque type d'encadré, puis de chaque module (1 à 5 et plus).
  final Map<Tone, String> toneEmojis;
  final List<String> moduleEmojis;

  /// Dégradé des grandes cartes (accueil, centre des cartes mentales).
  final List<Color> heroGradient;

  /// Irrégularité du tracé : 1 = main levée, 0 = règle et compas.
  final double wobble;

  /// Arrondi des encadrés.
  final double radius;

  /// Lignes et marge du cahier sur les pages de cours.
  final bool ruled;

  /// Post-it légèrement penchés.
  final bool tilt;

  /// Ombre portée sous les encadrés.
  final bool shadow;
  final TableLook table;

  /// Thème toujours sombre (le réglage clair/sombre est ignoré).
  final bool darkOnly;

  /// Thème en cours d'affichage.
  static AppLook active = cahier;

  /// Les thèmes proposés, dans l'ordre du choix.
  static const all = [cahier, classique, moderne, terminal, lecture];

  static AppLook byId(String? id) =>
      all.firstWhere((l) => l.id == id, orElse: () => cahier);

  Paper paper(Brightness b) =>
      darkOnly || b == Brightness.dark ? paperDark : paperLight;

  ToneColors colors(Tone tone, Brightness b) {
    final (ink, darkInk) = inks[tone]!;
    if (darkOnly || b == Brightness.dark) {
      return ToneColors(darkInk, darkInk.withValues(alpha: 0.12));
    }
    final fill = id == cahier.id
        ? _cahierFills[tone]!
        : Color.alphaBlend(ink.withValues(alpha: 0.10), paperLight.card);
    return ToneColors(ink, fill);
  }

  /// Couleur vive et pleine (bandeaux, badges, dégradés).
  Color bright(Tone tone) => id == cahier.id
      ? _cahierBright[tone]!
      : darkOnly
      ? inks[tone]!.$2
      : Color.lerp(inks[tone]!.$1, Colors.white, 0.12)!;

  String moduleEmoji(int number) =>
      moduleEmojis[(number - 1).clamp(0, moduleEmojis.length - 1)];

  // ---------------------------------------------------------------- Thèmes

  /// Le cahier d'étudiant d'origine : écriture manuscrite, pastels, traits à
  /// main levée.
  static const cahier = AppLook(
    id: 'cahier',
    heroGradient: [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFDB2777)],
    name: 'Cahier d\'étudiant',
    description: 'Écriture manuscrite, couleurs pastel, schémas et encadrés tracés à main levée.',
    preview: '✏️',
    titleFont: 'Caveat',
    bodyFont: 'PatrickHand',
    noteFont: 'Kalam',
    sansFont: 'Nunito',
    seed: Color(0xFF2F64C8),
    paperLight: Paper(
      page: Color(0xFFFFFBF2),
      background: Color(0xFFF4EEE1),
      ink: Color(0xFF26324A),
      inkSoft: Color(0xFF5E6A80),
      rule: Color(0xFFD9E6F5),
      margin: Color(0xFFF2A7A7),
      card: Color(0xFFFFFFFF),
    ),
    paperDark: Paper(
      page: Color(0xFF22252D),
      background: Color(0xFF181A20),
      ink: Color(0xFFE9E4D8),
      inkSoft: Color(0xFFADB3C0),
      rule: Color(0xFF30353F),
      margin: Color(0xFF6B3A3F),
      card: Color(0xFF2A2E37),
    ),
    inks: {
      Tone.blue: (Color(0xFF1F5FE0), Color(0xFF8DB4FF)),
      Tone.violet: (Color(0xFF7A3BE6), Color(0xFFC3A6FF)),
      Tone.green: (Color(0xFF14935A), Color(0xFF86D9A6)),
      Tone.orange: (Color(0xFFE5670A), Color(0xFFFFB878)),
      Tone.red: (Color(0xFFE0322B), Color(0xFFFF9B93)),
      Tone.yellow: (Color(0xFF9A6F00), Color(0xFFF2D35B)),
      Tone.turquoise: (Color(0xFF07928F), Color(0xFF6ED8D2)),
      Tone.pink: (Color(0xFFE0287A), Color(0xFFFF97C4)),
    },
    toneEmojis: {
      Tone.blue: '📘',
      Tone.violet: '⭐',
      Tone.green: '✅',
      Tone.orange: '💡',
      Tone.red: '🚨',
      Tone.yellow: '🧠',
      Tone.turquoise: '🌍',
      Tone.pink: '⚠️',
    },
    moduleEmojis: ['🛡️', '🔐', '🌐', '💻', '🚑'],
  );

  /// Manuel imprimé : police à empattements, couleurs sobres, traits nets,
  /// tableaux en grille.
  static const classique = AppLook(
    id: 'classique',
    heroGradient: [Color(0xFF1F3A68), Color(0xFF2E4D7F), Color(0xFF4B2E5A)],
    name: 'Classique',
    description: 'Comme un manuel imprimé : police à empattements, couleurs sobres, traits nets et tableaux en grille.',
    preview: '📖',
    titleFont: 'Lora',
    bodyFont: 'Lora',
    noteFont: 'Lora',
    sansFont: 'Nunito',
    titleScale: 0.74,
    bodyScale: 0.86,
    titleWeight: FontWeight.w600,
    seed: Color(0xFF1F3A68),
    wobble: 0,
    radius: 4,
    ruled: false,
    tilt: false,
    shadow: false,
    table: TableLook.grid,
    paperLight: Paper(
      page: Color(0xFFFFFFFF),
      background: Color(0xFFF2F2EF),
      ink: Color(0xFF1E2430),
      inkSoft: Color(0xFF5A6070),
      rule: Color(0xFFD5D8DE),
      margin: Color(0xFFD5D8DE),
      card: Color(0xFFFFFFFF),
    ),
    paperDark: Paper(
      page: Color(0xFF1F2126),
      background: Color(0xFF16181C),
      ink: Color(0xFFE6E6E2),
      inkSoft: Color(0xFFA8ACB4),
      rule: Color(0xFF34373E),
      margin: Color(0xFF34373E),
      card: Color(0xFF262930),
    ),
    inks: {
      Tone.blue: (Color(0xFF1F3A68), Color(0xFF9DB6E0)),
      Tone.violet: (Color(0xFF4B2E7A), Color(0xFFBBA6DE)),
      Tone.green: (Color(0xFF2D5A3A), Color(0xFF98C8A5)),
      Tone.orange: (Color(0xFF8A4B12), Color(0xFFE0B184)),
      Tone.red: (Color(0xFF8E1F24), Color(0xFFE59A9C)),
      Tone.yellow: (Color(0xFF6E5A12), Color(0xFFD9C27A)),
      Tone.turquoise: (Color(0xFF1D5C63), Color(0xFF8FC6CB)),
      Tone.pink: (Color(0xFF7A2850), Color(0xFFDDA0BE)),
    },
    toneEmojis: {
      Tone.blue: '📖',
      Tone.violet: '📌',
      Tone.green: '✔️',
      Tone.orange: '📝',
      Tone.red: '⛔',
      Tone.yellow: '🔖',
      Tone.turquoise: '🔎',
      Tone.pink: '❗',
    },
    moduleEmojis: ['📕', '📗', '📘', '📙', '📓'],
  );

  /// Application moderne : sans-serif arrondie, couleurs franches, cartes
  /// arrondies, tableaux à lignes alternées.
  static const moderne = AppLook(
    id: 'moderne',
    heroGradient: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF0EA5E9)],
    name: 'Moderne',
    description: 'Police arrondie, couleurs vives et franches, cartes très arrondies, tableaux à lignes alternées.',
    preview: '✨',
    titleFont: 'Nunito',
    bodyFont: 'Nunito',
    noteFont: 'Nunito',
    sansFont: 'Nunito',
    titleScale: 0.72,
    bodyScale: 0.84,
    titleWeight: FontWeight.w800,
    seed: Color(0xFF5B5BD6),
    wobble: 0,
    radius: 22,
    ruled: false,
    tilt: false,
    table: TableLook.zebra,
    paperLight: Paper(
      page: Color(0xFFFFFFFF),
      background: Color(0xFFF3F5FA),
      ink: Color(0xFF1B1F2E),
      inkSoft: Color(0xFF5B6275),
      rule: Color(0xFFE4E7EF),
      margin: Color(0xFFE4E7EF),
      card: Color(0xFFFFFFFF),
    ),
    paperDark: Paper(
      page: Color(0xFF1C1F2A),
      background: Color(0xFF13151D),
      ink: Color(0xFFEDEFF5),
      inkSoft: Color(0xFFA3A9BA),
      rule: Color(0xFF2C3040),
      margin: Color(0xFF2C3040),
      card: Color(0xFF232736),
    ),
    inks: {
      Tone.blue: (Color(0xFF2563EB), Color(0xFF93B4FF)),
      Tone.violet: (Color(0xFF6D28D9), Color(0xFFC4A8FF)),
      Tone.green: (Color(0xFF059669), Color(0xFF6EE7B7)),
      Tone.orange: (Color(0xFFEA580C), Color(0xFFFDBA74)),
      Tone.red: (Color(0xFFDC2626), Color(0xFFFCA5A5)),
      Tone.yellow: (Color(0xFFB45309), Color(0xFFFCD34D)),
      Tone.turquoise: (Color(0xFF0891B2), Color(0xFF67E8F9)),
      Tone.pink: (Color(0xFFDB2777), Color(0xFFF9A8D4)),
    },
    toneEmojis: {
      Tone.blue: '🔷',
      Tone.violet: '🌟',
      Tone.green: '👍',
      Tone.orange: '🎯',
      Tone.red: '🔥',
      Tone.yellow: '🧩',
      Tone.turquoise: '🚀',
      Tone.pink: '🪤',
    },
    moduleEmojis: ['🛡️', '🗝️', '📡', '🖥️', '🩺'],
  );

  /// Console de sécurité : fond sombre, police à chasse fixe, couleurs
  /// néon, cadres nets.
  static const terminal = AppLook(
    id: 'terminal',
    heroGradient: [Color(0xFF052E1C), Color(0xFF0B3D3A), Color(0xFF1E1B4B)],
    name: 'Terminal cyber',
    description: 'Ambiance console de SOC : fond sombre, police de terminal, couleurs néon et cadres lumineux.',
    preview: '💻',
    titleFont: 'JetBrainsMono',
    bodyFont: 'Nunito',
    noteFont: 'JetBrainsMono',
    sansFont: 'Nunito',
    titleScale: 0.62,
    bodyScale: 0.84,
    titleWeight: FontWeight.w700,
    seed: Color(0xFF00C853),
    wobble: 0,
    radius: 3,
    tilt: false,
    shadow: false,
    table: TableLook.neon,
    darkOnly: true,
    paperLight: Paper(
      page: Color(0xFF0E141B),
      background: Color(0xFF080C11),
      ink: Color(0xFFD7F5E3),
      inkSoft: Color(0xFF7FA595),
      rule: Color(0xFF15212B),
      margin: Color(0xFF0F3B2A),
      card: Color(0xFF111A22),
    ),
    paperDark: Paper(
      page: Color(0xFF0E141B),
      background: Color(0xFF080C11),
      ink: Color(0xFFD7F5E3),
      inkSoft: Color(0xFF7FA595),
      rule: Color(0xFF15212B),
      margin: Color(0xFF0F3B2A),
      card: Color(0xFF111A22),
    ),
    inks: {
      Tone.blue: (Color(0xFF38BDF8), Color(0xFF38BDF8)),
      Tone.violet: (Color(0xFFC084FC), Color(0xFFC084FC)),
      Tone.green: (Color(0xFF39FF88), Color(0xFF39FF88)),
      Tone.orange: (Color(0xFFFFB020), Color(0xFFFFB020)),
      Tone.red: (Color(0xFFFF4D6D), Color(0xFFFF4D6D)),
      Tone.yellow: (Color(0xFFF5E663), Color(0xFFF5E663)),
      Tone.turquoise: (Color(0xFF2DFCE0), Color(0xFF2DFCE0)),
      Tone.pink: (Color(0xFFFF5CCB), Color(0xFFFF5CCB)),
    },
    toneEmojis: {
      Tone.blue: '💾',
      Tone.violet: '⚡',
      Tone.green: '🟢',
      Tone.orange: '🔑',
      Tone.red: '☠️',
      Tone.yellow: '🧬',
      Tone.turquoise: '🖥️',
      Tone.pink: '🎯',
    },
    moduleEmojis: ['🛡️', '🔐', '📡', '🖥️', '🚨'],
  );

  /// Confort de lecture : police très lisible (Atkinson Hyperlegible),
  /// fond sépia, contrastes renforcés.
  static const lecture = AppLook(
    id: 'lecture',
    heroGradient: [Color(0xFF7A4E1D), Color(0xFF8E5B2A), Color(0xFF5C3A1A)],
    name: 'Lecture confort',
    description: 'Police conçue pour la lisibilité, fond sépia reposant, contrastes renforcés, traits nets.',
    preview: '👓',
    titleFont: 'AtkinsonHyperlegible',
    bodyFont: 'AtkinsonHyperlegible',
    noteFont: 'AtkinsonHyperlegible',
    sansFont: 'AtkinsonHyperlegible',
    titleScale: 0.72,
    bodyScale: 0.9,
    seed: Color(0xFF7A4E1D),
    wobble: 0,
    radius: 10,
    ruled: false,
    tilt: false,
    shadow: false,
    table: TableLook.zebra,
    paperLight: Paper(
      page: Color(0xFFFBF3E4),
      background: Color(0xFFEFE4CF),
      ink: Color(0xFF2B2118),
      inkSoft: Color(0xFF5C4D3D),
      rule: Color(0xFFE2D3B8),
      margin: Color(0xFFE2D3B8),
      card: Color(0xFFFFF9EE),
    ),
    paperDark: Paper(
      page: Color(0xFF26211B),
      background: Color(0xFF1B1713),
      ink: Color(0xFFF1E6D2),
      inkSoft: Color(0xFFC2B39B),
      rule: Color(0xFF3A3229),
      margin: Color(0xFF3A3229),
      card: Color(0xFF2E2820),
    ),
    inks: {
      Tone.blue: (Color(0xFF1D4E89), Color(0xFF9CC2F0)),
      Tone.violet: (Color(0xFF5B2A86), Color(0xFFCDB0EA)),
      Tone.green: (Color(0xFF256D3A), Color(0xFF9FD8AE)),
      Tone.orange: (Color(0xFF9A4A00), Color(0xFFF2B77A)),
      Tone.red: (Color(0xFFA11D1D), Color(0xFFF2A0A0)),
      Tone.yellow: (Color(0xFF6B5400), Color(0xFFE8CF6A)),
      Tone.turquoise: (Color(0xFF00636B), Color(0xFF86D4D9)),
      Tone.pink: (Color(0xFF8F1F5C), Color(0xFFF0A2C9)),
    },
    toneEmojis: {
      Tone.blue: '📘',
      Tone.violet: '⭐',
      Tone.green: '✅',
      Tone.orange: '💡',
      Tone.red: '🚨',
      Tone.yellow: '🧠',
      Tone.turquoise: '🌍',
      Tone.pink: '⚠️',
    },
    moduleEmojis: ['🛡️', '🔐', '🌐', '💻', '🚑'],
  );
}

const _cahierFills = {
  Tone.blue: Color(0xFFDCE9FF),
  Tone.violet: Color(0xFFEDE1FF),
  Tone.green: Color(0xFFD5F7E3),
  Tone.orange: Color(0xFFFFE7CC),
  Tone.red: Color(0xFFFFDEDB),
  Tone.yellow: Color(0xFFFFF0A8),
  Tone.turquoise: Color(0xFFCDF5F1),
  Tone.pink: Color(0xFFFFDCEC),
};

const _cahierBright = {
  Tone.blue: Color(0xFF3B82F6),
  Tone.violet: Color(0xFF8B5CF6),
  Tone.green: Color(0xFF10B981),
  Tone.orange: Color(0xFFF97316),
  Tone.red: Color(0xFFEF4444),
  Tone.yellow: Color(0xFFF5B800),
  Tone.turquoise: Color(0xFF06B6D4),
  Tone.pink: Color(0xFFEC4899),
};
