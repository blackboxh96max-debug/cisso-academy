import 'dart:io';

import 'package:cisso_academy/content/content_loader.dart';
import 'package:cisso_academy/models/content.dart';

/// Charge le vrai contenu depuis le disque (les tests tournent à la racine).
Future<ContentLibrary> loadRealContent() =>
    ContentLoader((path) => File(path).readAsString()).load();
