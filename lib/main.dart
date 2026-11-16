import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'content/content_loader.dart';
import 'data/store_factory.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final library = await ContentLoader(rootBundle.loadString).load();
  final store = await openProgressStore();
  final state = AppState(library: library, store: store);
  await state.refresh();
  runApp(CissoAcademyApp(state: state));
}

class CissoAcademyApp extends StatelessWidget {
  const CissoAcademyApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'CISSO Academy',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeShell(),
      ),
    );
  }
}
