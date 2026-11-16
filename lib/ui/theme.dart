import 'package:material_ui/material_ui.dart';

import '../models/content.dart';

import 'notebook/palette.dart';

const _seed = Color(0xFF2F64C8);

ThemeData buildTheme(Brightness brightness) {
  final paper = brightness == Brightness.dark ? Paper.dark : Paper.light;
  final base = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final scheme = base.copyWith(
    surface: paper.background,
    onSurface: paper.ink,
    surfaceContainerLow: paper.card,
    surfaceContainer: paper.page,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: paper.background,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: paper.background,
      foregroundColor: paper.ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: paper.ink,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paper.page,
      indicatorColor: toneColors(Tone.yellow, brightness).fill,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: paper.page,
      indicatorColor: toneColors(Tone.yellow, brightness).fill,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: paper.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}

/// Couleur associée à la nature d'une information.
Color sourceColor(SourceKind kind, ColorScheme scheme) => switch (kind) {
  SourceKind.official => scheme.primary,
  SourceKind.general => scheme.tertiary,
  SourceKind.practice => scheme.secondary,
  SourceKind.example => scheme.outline,
};

/// Couleur sémantique : vert si réussi, rouge sinon.
Color successColor(bool ok, ColorScheme scheme) => ok
    ? (scheme.brightness == Brightness.dark
          ? const Color(0xFF7BD88F)
          : const Color(0xFF1B7F3B))
    : scheme.error;

/// Largeur maximale du contenu de lecture.
const double readingWidth = 760;
