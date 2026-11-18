import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../app_state.dart';
import 'about_page.dart';
import 'assistant_page.dart';
import 'mascot.dart';
import 'look_picker.dart';
import 'mascot_picker.dart';
import 'notebook/look.dart';
import 'notebook/palette.dart';
import 'search_page.dart';

/// Les actions générales de l'application : réglages, à propos (application et
/// examen),
/// réinitialisation. Elles sont proposées dans le menu ⋮ de l'accueil, dans
/// le menu de gauche (tiroir sur téléphone, rail sur grand écran).
enum AppAction {
  search('Recherche', Icons.search),
  assistant('Chatbot', Icons.forum_outlined),
  settings('Réglages', Icons.settings_outlined),
  about('À propos', Icons.shield_outlined),
  reset('Réinitialiser ma progression', Icons.restart_alt);

  const AppAction(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Libellé court, pour le rail latéral.
  String get short => switch (this) {
    AppAction.search => 'Recherche',
    AppAction.assistant => 'Chatbot',
    AppAction.settings => 'Réglages',
    AppAction.about => 'À propos',
    AppAction.reset => 'Réinitialiser',
  };

  /// Vrai pour les actions qui ouvrent une page (et non une fenêtre).
  bool get opensPage =>
      this == AppAction.search ||
      this == AppAction.assistant ||
      this == AppAction.about;

  /// La page ouverte par l'action, s'il y en a une.
  Widget? get page => switch (this) {
    AppAction.search => const SearchPage(),
    AppAction.assistant => const AssistantPage(),
    AppAction.about => const AboutPage(),
    _ => null,
  };

  void run(BuildContext context) => switch (this) {
    AppAction.search || AppAction.assistant => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page!)),
    AppAction.settings => showSettings(context),
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
    // Dans une page ouverte depuis un écran principal, l'AppBar garde son
    // bouton retour.
    final first = ModalRoute.of(context)?.isFirst ?? true;
    return open == null || !first ? null : ShellMenuButton(onPressed: open);
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
            ListTile(
              key: const Key('settings-look'),
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    AppLook.byId(state.lookId).preview,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              title: const Text('Thème de l\'application'),
              subtitle: Text(
                '${AppLook.byId(state.lookId).name} · écriture, couleurs, '
                'émojis, dessins, tableaux',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLookPicker(ctx),
            ),
            ListTile(
              key: const Key('settings-mascot'),
              contentPadding: EdgeInsets.zero,
              leading: const SizedBox(
                width: 40,
                child: Mascot(mood: MascotMood.idle, size: 40),
              ),
              title: const Text('Mascotte du chatbot'),
              subtitle: Text(
                '${mascotById(state.mascotId).name}, '
                '${mascotById(state.mascotId).species}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showMascotPicker(ctx),
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
