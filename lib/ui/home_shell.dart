import 'package:material_ui/material_ui.dart';

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

  /// Module choisi sur l'accueil : la page Cours défile jusqu'à lui.
  final _courseFocus = ValueNotifier<int?>(null);

  void _go(int index) => setState(() => _index = index);

  void _openModule(int number) {
    _go(1);
    _courseFocus.value = number;
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

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
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
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(child: body),
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
