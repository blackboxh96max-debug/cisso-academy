import 'package:material_ui/material_ui.dart';

import '../models/content.dart';

import 'notebook/look.dart';
import 'notebook/palette.dart';

final _themes = <(String, Brightness), ThemeData>{};

/// Thème Material d'un thème de l'application, construit une seule fois.
ThemeData cachedTheme(AppLook look, Brightness brightness) =>
    _themes[(look.id, brightness)] ??= buildTheme(brightness, look);

/// Thème Material du thème de lecture [look] (le moderne par défaut).
ThemeData buildTheme(Brightness brightness, [AppLook look = AppLook.moderne]) {
  if (look.darkOnly) brightness = Brightness.dark;
  final paper = look.paper(brightness);
  final base = ColorScheme.fromSeed(
    seedColor: look.seed,
    brightness: brightness,
  );
  final scheme = base.copyWith(
    surface: paper.background,
    onSurface: paper.ink,
    surfaceContainerLow: paper.card,
    surfaceContainer: paper.page,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: look.sansFont,
    scaffoldBackgroundColor: paper.background,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: paper.background,
      foregroundColor: paper.ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: look.titleFont,
        fontSize: 30 * look.titleScale,
        fontWeight: look.titleWeight,
        color: paper.ink,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paper.page,
      indicatorColor: look.colors(Tone.yellow, brightness).fill,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: paper.page,
      indicatorColor: look.colors(Tone.yellow, brightness).fill,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: paper.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(look.radius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: TextStyle(
          fontFamily: look.sansFont,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: TextStyle(
          fontFamily: look.sansFont,
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
