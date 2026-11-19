import 'progress_store.dart';
import 'store_factory_stub.dart'
    if (dart.library.io) 'store_factory_native.dart'
    if (dart.library.js_interop) 'store_factory_web.dart'
    as impl;

/// Ouvre le stockage de progression adapté à la plateforme :
/// SQLite sur Android et ordinateur, `localStorage` dans le navigateur.
Future<ProgressStore> openProgressStore() => impl.openProgressStore();
