import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../app_state.dart';
import '../models/content.dart';
import 'about_page.dart';
import 'notebook/palette.dart';
import 'widgets.dart';

/// Les actions générales de l'application : réglages, examen, à propos,
/// réinitialisation. Elles sont proposées dans le menu ⋮ de l'accueil, dans
/// le menu de gauche (tiroir sur téléphone, rail sur grand écran).
enum AppAction {
  settings('Réglages', Icons.settings_outlined),
  exam('À propos de l\'examen', Icons.info_outline),
  about('À propos de l\'application', Icons.shield_outlined),
  reset('Réinitialiser ma progression', Icons.restart_alt);

  const AppAction(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Libellé court, pour le rail latéral.
  String get short => switch (this) {
    AppAction.settings => 'Réglages',
    AppAction.exam => 'Examen',
    AppAction.about => 'À propos',
    AppAction.reset => 'Réinitialiser',
  };

  void run(BuildContext context) => switch (this) {
    AppAction.settings => showSettings(context),
    AppAction.exam => showExamInfo(context),
    AppAction.about => openAbout(context),
    AppAction.reset => confirmReset(context),
  };
}

/// Menu ⋮ de l'accueil.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<AppAction>(
    tooltip: 'Menu',
    onSelected: (a) => a.run(context),
    itemBuilder: (_) => [
      for (final a in AppAction.values)
        PopupMenuItem(value: a, child: Text(a.label)),
    ],
  );
}

/// Mention affichée en bas des écrans principaux, comme dans les
/// applications éditées : auteur, version, nature non officielle.
const appFooterText =
    '© 2026 $appAuthor · $appAuthorTitle · v$appVersion · '
    'Application non officielle';

/// Pied de page des écrans principaux ; un appui ouvre « À propos ».
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    return Material(
      color: paper.background,
      child: InkWell(
        onTap: () => openAbout(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            appFooterText,
            key: const Key('app-footer'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, height: 1.3, color: paper.inkSoft),
          ),
        ),
      ),
    );
  }
}

/// Donne aux écrans principaux l'accès au menu de gauche (tiroir).
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.openMenu, required super.child});

  /// Ouvre le tiroir, ou `null` quand le menu est déjà affiché (rail).
  final VoidCallback? openMenu;

  @override
  bool updateShouldNotify(ShellScope old) => old.openMenu != openMenu;
}

/// Bouton ☰ des écrans principaux sur téléphone.
class ShellMenuButton extends StatelessWidget {
  const ShellMenuButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  /// Le bouton, s'il y a un tiroir à ouvrir ; sinon `null` (l'AppBar garde
  /// son comportement habituel, par exemple le bouton retour).
  static Widget? maybe(BuildContext context) {
    final open = context
        .dependOnInheritedWidgetOfExactType<ShellScope>()
        ?.openMenu;
    return open == null ? null : ShellMenuButton(onPressed: open);
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Ouvrir le menu',
    icon: const Icon(Icons.menu),
    onPressed: onPressed,
  );
}

/// Réglages de l'application.
void showSettings(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final state = AppScope.of(ctx);
      final systemReduced = MediaQuery.disableAnimationsOf(ctx);
      return AlertDialog(
        title: const Text('Réglages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Animations'),
              subtitle: Text(
                systemReduced
                    ? 'Désactivées par le réglage « réduire les animations » de votre appareil.'
                    : 'Apparition des schémas, retournement des flashcards, effets de réussite.',
              ),
              value: state.animationsSetting,
              onChanged: (v) => state.setAnimations(v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      );
    },
  );
}

/// Efface la progression, après confirmation.
Future<void> confirmReset(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Réinitialiser la progression ?'),
      content: const Text(
        'Toutes vos réponses, séries, flashcards et leçons lues seront '
        'effacées de cet appareil. Cette action est définitive.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Effacer'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await AppScope.read(context).resetProgress();
  }
}

/// Paramètres de l'examen CISSO.
void showExamInfo(BuildContext context) {
  final info = AppScope.read(context).library.examInfo;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('L\'examen CISSO'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SourceBadge(SourceKind.official),
          const SizedBox(height: 12),
          Text(
            '${info.questionCount} questions à choix multiples, '
            '${info.durationMinutes} minutes, seuil de réussite '
            '${info.passingScore}/100.',
          ),
          const SizedBox(height: 8),
          Text(
            'Source : ${info.source}, vérifiée le ${info.verifiedOn}. '
            'Vérifiez toujours ces paramètres sur le site de MILE2 avant '
            'de vous inscrire.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Les questions de l\'application sont originales : '
            'elles ne reproduisent pas les questions de l\'examen.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}
