import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
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

  void _go(int index) => setState(() => _index = index);

  void _openModule(int index) {
    _go(1);
    _courseFocus.value = index;
  }

  @override
  void dispose() {
    _courseFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(onNavigate: _go, onOpenModule: _openModule),
      CoursesPage(focus: _courseFocus),
      const QuizHubPage(),
      const RevisionsPage(),
      const GlossaryPage(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = IndexedStack(index: _index, children: pages);
    // Les écrans principaux finissent par la mention de l'auteur.
    final content = Column(
      children: [
        Expanded(child: body),
        const AppFooter(),
      ],
    );

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: ShellScope(
            openMenu: null,
            child: Row(
              children: [
                _ScrollableRail(
                  child: NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _go,
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    trailing: Column(
                      children: [
                        const SizedBox(height: 8),
                        const SizedBox(width: 56, child: Divider()),
                        for (final a in AppAction.values) _RailAction(a),
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
                const VerticalDivider(width: 1),
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
        onSelect: _go,
        // Le contexte de l'écran, qui reste valide après fermeture du tiroir.
        onAction: (a) => a.run(context),
      ),
      body: SafeArea(
        child: ShellScope(
          openMenu: () => _scaffold.currentState?.openDrawer(),
          child: content,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
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

/// Le rail défile si la fenêtre est trop basse pour tout afficher.
class _ScrollableRail extends StatelessWidget {
  const _ScrollableRail({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight),
        child: IntrinsicHeight(child: child),
      ),
    ),
  );
}

/// Action générale dans le rail : icône et libellé court.
class _RailAction extends StatelessWidget {
  const _RailAction(this.action);

  final AppAction action;

  @override
  Widget build(BuildContext context) {
    final color = action == AppAction.reset
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: action.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => action.run(context),
        child: SizedBox(
          width: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(action.icon, color: color, size: 22),
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
