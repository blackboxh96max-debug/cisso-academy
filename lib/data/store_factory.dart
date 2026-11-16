import 'progress_store.dart';
import 'store_factory_stub.dart'
    if (dart.library.io) 'store_factory_native.dart'
    as impl;

/// Ouvre le stockage de progression adapté à la plateforme :
/// SQLite sur Android et ordinateur, mémoire sur l'aperçu web.
Future<ProgressStore> openProgressStore() => impl.openProgressStore();
