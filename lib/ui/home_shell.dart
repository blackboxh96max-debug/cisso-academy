import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../app_state.dart';
import 'app_menu.dart';
import 'courses_page.dart';
import 'dashboard_page.dart';
import 'glossary_page.dart';
import 'quiz_hub_page.dart';
import 'revisions_page.dart';

/// Navigation principale : barre du bas sur téléphone, rail latéral sur
/// tablette et ordinateur.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Accueil', Icons.dashboard_outlined, Icons.dashboard),
  _Destination('Cours', Icons.menu_book_outlined, Icons.menu_book),
  _Destination('QCM', Icons.quiz_outlined, Icons.quiz),
  _Destination('Révisions', Icons.style_outlined, Icons.style),
  _Destination('Glossaire', Icons.translate_outlined, Icons.translate),
];

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Rang du module choisi sur l'accueil : la page Cours le déplie et défile
  /// jusqu'à lui.
  final _courseFocus = ValueNotifier<int?>(null);
  final _scaffold = GlobalKey<ScaffoldState>();

  /// Un navigateur par écran principal : modules, chapitres et leçons
  /// s'ouvrent à l'intérieur, et le menu de gauche reste visible.
  final _navigators = List.generate(
    _destinations.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  void _go(int index) => setState(() => _index = index);

  /// Choix dans le menu : un second appui sur l'écran en cours ramène à son
  /// début.
  void _select(int index) {
    if (index == _index) {
      _navigators[index].currentState?.popUntil((r) => r.isFirst);
    } else {
      _go(index);
    }
  }

  void _openModule(int index) {
    _go(1);
    _courseFocus.value = index;
  }

  /// Les actions qui ouvrent une page le font dans l'écran en cours.
  void _run(AppAction a) {
    final nav = _navigators[_index].currentState;
    if (a.page case final page? when nav != null) {
      nav.push(MaterialPageRoute<void>(builder: (_) => page));
    } else {
      a.run(context);
    }
  }

  @override
  void dispose() {
    _courseFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pages = [
      DashboardPage(onNavigate: _go, onOpenModule: _openModule),
      CoursesPage(focus: _courseFocus),
      const QuizHubPage(),
      const RevisionsPage(),
      const GlossaryPage(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = NavigatorPopHandler(
      onPopWithResult: (_) => _navigators[_index].currentState?.maybePop(),
      child: IndexedStack(
        index: _index,
        children: [
          for (final (i, page) in pages.indexed)
            HeroControllerScope.none(
              child: Navigator(
                key: _navigators[i],
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => page,
                ),
              ),
            ),
        ],
      ),
    );
    // Les écrans principaux finissent par la mention de l'auteur.
    final content = Column(
      children: [
        Expanded(child: body),
        const AppFooter(),
      ],
    );

    if (wide) {
      final mode = state.menuMode;
      return Scaffold(
        body: SafeArea(
          child: ShellScope(
            openMenu: null,
            child: Row(
              children: [
                if (mode == MenuMode.hidden)
                  _ShowMenuTab(onTap: () => state.setMenuMode(MenuMode.compact))
                else ...[
                  NavigationRail(
                    key: const Key('side-rail'),
                    // Les entrées défilent si la fenêtre est trop basse.
                    scrollable: true,
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    extended: mode == MenuMode.expanded,
                    minExtendedWidth: 210,
                    labelType: mode == MenuMode.expanded
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    leading: _RailHeader(mode: mode),
                    trailing: Column(
                      crossAxisAlignment: mode == MenuMode.expanded
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        SizedBox(
                          width: mode == MenuMode.expanded ? 180 : 56,
                          child: const Divider(),
                        ),
                        for (final a in AppAction.values)
                          _RailAction(
                            a,
                            extended: mode == MenuMode.expanded,
                            onTap: () => _run(a),
                          ),
                      ],
                    ),
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  _MenuHandle(mode: mode, onMode: state.setMenuMode),
                ],
                Expanded(child: content),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      key: _scaffold,
      drawer: _AppDrawer(
        selected: _index,
        onSelect: _select,
        // Le contexte de l'écran, qui reste valide après fermeture du tiroir.
        onAction: _run,
      ),
      body: SafeArea(
        child: ShellScope(
          openMenu: () => _scaffold.currentState?.openDrawer(),
          child: content,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// En-tête du rail : logo, et nom de l'application quand il est étendu.
class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.mode});

  final MenuMode mode;

  @override
  Widget build(BuildContext context) {
    final logo = Icon(
      Icons.shield_outlined,
      size: 32,
      color: Theme.of(context).colorScheme.primary,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: mode == MenuMode.expanded
          ? SizedBox(
              width: 190,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  logo,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appName,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          : logo,
    );
  }
}

/// Poignée sur le bord droit du menu, en dehors de ses entrées : étendre ou
/// réduire le menu, et le masquer.
class _MenuHandle extends StatelessWidget {
  const _MenuHandle({required this.mode, required this.onMode});

  final MenuMode mode;
  final ValueChanged<MenuMode> onMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = mode == MenuMode.expanded;
    Widget button(String tip, IconData icon, VoidCallback onTap, Key key) =>
        Tooltip(
          message: tip,
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(
              width: 24,
              height: 40,
              child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            ),
          ),
        );
    return Container(
      key: const Key('menu-handle'),
      width: 24,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          left: BorderSide(color: scheme.outlineVariant),
          right: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          button(
            expanded ? 'Réduire le menu' : 'Étendre le menu',
            expanded ? Icons.chevron_left : Icons.chevron_right,
            () => onMode(expanded ? MenuMode.compact : MenuMode.expanded),
            const Key('menu-extend'),
          ),
          button(
            'Masquer le menu',
            Icons.keyboard_double_arrow_left,
            () => onMode(MenuMode.hidden),
            const Key('menu-hide'),
          ),
        ],
      ),
    );
  }
}

/// Languette à gauche quand le menu est masqué : un appui le rouvre.
class _ShowMenuTab extends StatelessWidget {
  const _ShowMenuTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Afficher le menu',
      child: Material(
        color: scheme.surfaceContainerHighest,
        child: InkWell(
          key: const Key('show-menu'),
          onTap: onTap,
          child: SizedBox(
            width: 22,
            child: Center(
              child: Icon(
                Icons.keyboard_double_arrow_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Action générale dans le rail : icône et libellé (court, ou complet quand
/// le menu est étendu).
class _RailAction extends StatelessWidget {
  const _RailAction(this.action, {required this.extended, required this.onTap});

  final AppAction action;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = action == AppAction.reset
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = Icon(action.icon, color: color, size: 22);
    return Tooltip(
      message: action.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: extended
            ? SizedBox(
                width: 194,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          action.label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SizedBox(
                width: 80,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      icon,
                      const SizedBox(height: 2),
                      Text(
                        action.short,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Menu de gauche sur téléphone : écrans, actions générales et mention.
class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.selected,
    required this.onSelect,
    required this.onAction,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<AppAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void close() => Navigator.of(context).pop();
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.shield_outlined,
                      size: 32,
                      color: scheme.primary,
                    ),
                    title: Text(
                      appName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: const Text('Créée par $appAuthor'),
                  ),
                  const Divider(),
                  for (final (i, d) in _destinations.indexed)
                    ListTile(
                      leading: Icon(i == selected ? d.selectedIcon : d.icon),
                      title: Text(d.label),
                      selected: i == selected,
                      onTap: () {
                        close();
                        onSelect(i);
                      },
                    ),
                  const Divider(),
                  for (final a in AppAction.values)
                    ListTile(
                      leading: Icon(
                        a.icon,
                        color: a == AppAction.reset ? scheme.error : null,
                      ),
                      title: Text(
                        a.label,
                        style: a == AppAction.reset
                            ? TextStyle(color: scheme.error)
                            : null,
                      ),
                      onTap: () {
                        close();
                        onAction(a);
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}
