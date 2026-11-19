import 'dart:js_interop';

import 'json_store.dart';
import 'progress_store.dart';

@JS('localStorage')
external _Storage? get _localStorage;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

const _key = 'cisso_academy_progress_v1';

/// Version navigateur : progression gardée dans le `localStorage`.
/// Si le navigateur le refuse (navigation privée stricte), elle reste en
/// mémoire le temps de la session.
Future<ProgressStore> openProgressStore() async {
  _Storage? storage;
  String? initial;
  try {
    storage = _localStorage;
    initial = storage?.getItem(_key);
  } catch (_) {
    storage = null;
  }
  return JsonProgressStore(
    initial: initial,
    save: (json) {
      try {
        storage?.setItem(_key, json);
      } catch (_) {
        // Quota dépassé ou stockage bloqué : on continue en mémoire.
      }
    },
  );
}
