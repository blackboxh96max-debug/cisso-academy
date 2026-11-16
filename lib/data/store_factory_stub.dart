import 'progress_store.dart';

/// Aperçu web (non visé par le cahier des charges) : progression en mémoire.
Future<ProgressStore> openProgressStore() async => MemoryProgressStore();
