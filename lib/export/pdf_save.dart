import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'pdf_export.dart';

/// Enregistre ou partage un PDF.
///
/// Sur Windows, le fichier va dans le dossier Téléchargements et son chemin
/// est renvoyé. Sur Android (et dans la démo web), la feuille de partage du
/// système s'ouvre : « Enregistrer dans Fichiers », Drive, e-mail…
Future<String?> savePdf(Uint8List bytes, String fileName) async {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
  await Printing.sharePdf(bytes: bytes, filename: fileName);
  return null;
}

/// Construit puis enregistre un PDF, en informant l'apprenant.
Future<void> exportPdf(
  BuildContext context, {
  required String title,
  required Future<Uint8List> Function() build,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(
      content: Text('Préparation du PDF…'),
      duration: Duration(seconds: 2),
    ),
  );
  try {
    final bytes = await build();
    final path = await savePdf(bytes, pdfFileName(title));
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'PDF prêt : $title' : 'PDF enregistré : $path',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Le PDF n\'a pas pu être créé ($e).')),
    );
  }
}

/// Enregistre ou partage une page HTML autonome (carte mentale interactive).
///
/// Sur Windows, le fichier va dans le dossier Téléchargements. Sur Android,
/// la feuille de partage propose « Enregistrer dans Fichiers », Drive…
Future<String?> saveHtml(String html, String fileName) async {
  final bytes = Uint8List.fromList(utf8.encode(html));
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/html', name: fileName)],
      fileNameOverrides: [fileName],
    ),
  );
  return null;
}

/// Construit puis enregistre une page HTML, en informant l'apprenant.
Future<void> exportHtml(
  BuildContext context, {
  required String title,
  required String Function() build,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final name = pdfFileName(title).replaceFirst(RegExp(r'\.pdf$'), '.html');
    final path = await saveHtml(build(), name);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? 'Page interactive prête : $title'
              : 'Page interactive enregistrée : $path',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('La page n\'a pas pu être créée ($e).')),
    );
  }
}
