import 'package:material_ui/material_ui.dart';

import '../models/content.dart';

const _seed = Color(0xFF1F5F8B);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
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
