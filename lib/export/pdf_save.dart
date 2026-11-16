import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

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
