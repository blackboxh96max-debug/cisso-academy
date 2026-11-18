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
      // Le menu est affiché (icônes et libellés courts) ou masqué.
      final hidden = state.menuMode == MenuMode.hidden;
      return Scaffold(
        body: SafeArea(
          child: ShellScope(
            openMenu: null,
            child: Row(
              children: [
                if (hidden)
                  _ShowMenuTab(onTap: () => state.setMenuMode(MenuMode.compact))
                else
                  _SideMenu(
                    onHide: () => state.setMenuMode(MenuMode.hidden),
                    rail: NavigationRail(
                      key: const Key('side-rail'),
                      // Les entrées défilent si la fenêtre est trop basse.
                      scrollable: true,
                      selectedIndex: _index,
                      onDestinationSelected: _select,
                      labelType: NavigationRailLabelType.all,
                      leading: const _RailHeader(),
                      trailing: Column(
                        children: [
                          const SizedBox(height: 8),
                          const SizedBox(width: 56, child: Divider()),
                          for (final a in AppAction.values)
                            _RailAction(
                              a,
                              extended: false,
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
                  ),
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

/// En-tête du rail : le logo.
class _RailHeader extends StatelessWidget {
  const _RailHeader();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Icon(
      Icons.shield_outlined,
      size: 32,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

/// Le menu de gauche, avec tout en bas le bouton qui le masque.
class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.rail, required this.onHide});

  final Widget rail;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background =
        NavigationRailTheme.of(context).backgroundColor ?? scheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          Expanded(child: rail),
          Tooltip(
            message: 'Masquer le menu',
            child: InkWell(
              key: const Key('menu-hide'),
              borderRadius: BorderRadius.circular(8),
              onTap: onHide,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.keyboard_double_arrow_left,
                      color: scheme.onSurfaceVariant,
                    ),
                    Text(
                      'Masquer',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
