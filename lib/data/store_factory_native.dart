import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'progress_store.dart';
import 'sqlite_store.dart';

/// Base `cisso_academy.db` dans le dossier de données privé de l'application.
Future<ProgressStore> openProgressStore() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return SqliteProgressStore.open(p.join(dir.path, 'cisso_academy.db'));
}
