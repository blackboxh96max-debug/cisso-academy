import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../logic/terms.dart';
import '../models/content.dart';

// Documents PDF hors ligne : fiches de révision, flashcards, cartes mentales.
// Les polices sont celles de l'application (embarquées), rien n'est téléchargé.

class _Fonts {
  _Fonts(this.body, this.hand, this.handBold, this.symbols);
  final pw.Font body;
  final pw.Font hand;
  final pw.Font handBold;
  final pw.Font symbols;
}

_Fonts? _cache;

Future<_Fonts> _fonts() async {
  if (_cache != null) return _cache!;
  Future<pw.Font> load(String path) async =>
      pw.Font.ttf(await rootBundle.load(path));
  return _cache = _Fonts(
    await load('assets/fonts/Nunito.ttf'),
    await load('assets/fonts/Kalam-Regular.ttf'),
    await load('assets/fonts/Kalam-Bold.ttf'),
    await load('assets/fonts/JetBrainsMono.ttf'),
  );
}

/// Retire les emoji, que les polices du PDF ne savent pas dessiner.
String stripEmoji(String input, {bool trim = true}) {
  final out = StringBuffer();
  for (final r in input.runes) {
    final isEmoji =
        (r >= 0x1F000 && r <= 0x1FAFF) ||
        (r >= 0x2600 && r <= 0x27BF) ||
        (r >= 0x2B00 && r <= 0x2BFF) ||
        (r >= 0x1F1E6 && r <= 0x1F1FF) ||
        r == 0xFE0F ||
        r == 0x200D ||
        r == 0x20E3;
    // On garde les quelques symboles utiles du bloc 2600–27BF.
    const keep = {0x2713, 0x2717, 0x2605, 0x2192};
    if (!isEmoji || keep.contains(r)) out.writeCharCode(r);
  }
  final text = out.toString().replaceAll(RegExp(r'\s{2,}'), ' ');
  return trim ? text.trim() : text;
}

/// Nom de fichier sans accents ni espaces.
String pdfFileName(String title) {
  final slug = fold(stripEmoji(title))
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'cisso-${slug.isEmpty ? 'document' : slug}.pdf';
}

// Couleurs du cahier.
const _ink = PdfColor.fromInt(0xFF26324A);
const _soft = PdfColor.fromInt(0xFF6B7280);
const _blue = PdfColor.fromInt(0xFF1D4ED8);
const _paper = PdfColor.fromInt(0xFFFFFBF2);
const _rule = PdfColor.fromInt(0xFFDCE6F2);
const _rainbow = [
  PdfColor.fromInt(0xFF3B82F6),
  PdfColor.fromInt(0xFF8B5CF6),
  PdfColor.fromInt(0xFFEC4899),
  PdfColor.fromInt(0xFFF97316),
  PdfColor.fromInt(0xFF22C55E),
  PdfColor.fromInt(0xFF06B6D4),
];

PdfColor _toneColor(String? tone, PdfColor fallback) => switch (tone) {
  'blue' => _rainbow[0],
  'violet' => _rainbow[1],
  'pink' => _rainbow[2],
  'orange' => _rainbow[3],
  'green' => _rainbow[4],
  'turquoise' => _rainbow[5],
  'red' => const PdfColor.fromInt(0xFFEF4444),
  'yellow' => const PdfColor.fromInt(0xFFCA8A04),
  _ => fallback,
};

pw.ThemeData _theme(_Fonts f) =>
    pw.ThemeData.withFont(
      base: f.body,
      bold: f.handBold,
      fontFallback: [f.symbols],
    ).copyWith(
      defaultTextStyle: pw.TextStyle(font: f.body, fontSize: 11, color: _ink),
    );

pw.Widget _footer(pw.Context ctx, _Fonts f) => pw.Container(
  alignment: pw.Alignment.centerRight,
  margin: const pw.EdgeInsets.only(top: 8),
  child: pw.Text(
    'CISSO MILE2 Academy  ·  page ${ctx.pageNumber}/${ctx.pagesCount}',
    style: pw.TextStyle(font: f.body, fontSize: 8, color: _soft),
  ),
);

pw.Widget _titleBlock(_Fonts f, String title, String? en, String? subtitle) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          stripEmoji(title),
          style: pw.TextStyle(font: f.handBold, fontSize: 24, color: _ink),
        ),
        if (en != null)
          pw.Text(
            'EN  $en',
            style: pw.TextStyle(font: f.body, fontSize: 11, color: _blue),
          ),
        if (subtitle != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              stripEmoji(subtitle),
              style: pw.TextStyle(font: f.body, fontSize: 10, color: _soft),
            ),
          ),
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 6, bottom: 12),
          height: 3,
          width: 120,
          color: _rainbow[3],
        ),
      ],
    );

/// Texte avec l'équivalent anglais des termes clés entre parenthèses.
pw.Widget _bilingual(String text, List<TermMatch> matches, pw.TextStyle style) {
  if (matches.isEmpty) return pw.Text(stripEmoji(text), style: style);
  final spans = <pw.InlineSpan>[];
  var pos = 0;
  for (final m in matches) {
    spans.add(pw.TextSpan(text: text.substring(pos, m.end)));
    spans.add(
      pw.TextSpan(
        text: ' (${m.term.termEn})',
        style: style.copyWith(
          color: _blue,
          fontSize: (style.fontSize ?? 11) * 0.9,
        ),
      ),
    );
    pos = m.end;
  }
  spans.add(pw.TextSpan(text: text.substring(pos)));
  return pw.RichText(
    text: pw.TextSpan(
      style: style,
      children: [
        for (final s in spans)
          s is pw.TextSpan && s.text != null
              ? pw.TextSpan(
                  text: stripEmoji(s.text!, trim: false),
                  style: s.style,
                )
              : s,
      ],
    ),
  );
}

pw.PageTheme _a4(_Fonts f) => pw.PageTheme(
  pageFormat: PdfPageFormat.a4,
  margin: const pw.EdgeInsets.fromLTRB(40, 36, 36, 30),
  theme: _theme(f),
  buildBackground: (ctx) =>
      pw.FullPage(ignoreMargins: true, child: pw.Container(color: _paper)),
);

/// Fiches de révision d'un ou plusieurs chapitres.
Future<Uint8List> revisionSheetsPdf({
  required String title,
  String? subtitle,
  required List<Chapter> chapters,
  required TermIndex terms,
}) async {
  final f = await _fonts();
  final doc = pw.Document(title: stripEmoji(title), author: 'CISSO Academy');
  doc.addPage(
    pw.MultiPage(
      pageTheme: _a4(f),
      footer: (ctx) => _footer(ctx, f),
      build: (ctx) => [
        _titleBlock(f, title, null, subtitle),
        for (final c in chapters.where((c) => c.revisionSheet.isNotEmpty)) ...[
          pw.Header(
            level: 1,
            decoration: const pw.BoxDecoration(),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  c.title,
                  style: pw.TextStyle(
                    font: f.handBold,
                    fontSize: 17,
                    color: _rainbow[3],
                  ),
                ),
                if (c.titleEn != null)
                  pw.Text(
                    'EN  ${c.titleEn}',
                    style: pw.TextStyle(
                      font: f.body,
                      fontSize: 9.5,
                      color: _blue,
                    ),
                  ),
              ],
            ),
          ),
          ...() {
            final points = c.revisionSheet
                .where((l) => !l.startsWith('# '))
                .toList();
            final seen = <String>{};
            return [
              for (final (i, p) in points.indexed)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 18,
                        height: 18,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: _rainbow[i % _rainbow.length],
                        ),
                        child: pw.Text(
                          '${i + 1}',
                          style: pw.TextStyle(
                            font: f.handBold,
                            fontSize: 9,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: _bilingual(
                          p,
                          terms.findIn(p, skip: seen),
                          pw.TextStyle(
                            font: f.body,
                            fontSize: 10.5,
                            lineSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ];
          }(),
          pw.SizedBox(height: 10),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Flashcards à imprimer : recto (avec l'anglais) et verso côte à côte.
Future<Uint8List> flashcardsPdf({
  required String title,
  String? subtitle,
  required List<Chapter> chapters,
  required TermIndex terms,
}) async {
  final f = await _fonts();
  final doc = pw.Document(title: stripEmoji(title), author: 'CISSO Academy');
  doc.addPage(
    pw.MultiPage(
      pageTheme: _a4(f),
      footer: (ctx) => _footer(ctx, f),
      build: (ctx) => [
        _titleBlock(
          f,
          title,
          null,
          subtitle ?? 'Pliez la feuille au milieu : question à gauche, réponse à droite.',
        ),
        for (final (ci, c)
            in chapters.where((c) => c.flashcards.isNotEmpty).indexed) ...[
          pw.Header(
            level: 1,
            decoration: const pw.BoxDecoration(),
            child: pw.Text(
              c.title,
              style: pw.TextStyle(
                font: f.handBold,
                fontSize: 16,
                color: _rainbow[ci % _rainbow.length],
              ),
            ),
          ),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1.4),
            },
            border: pw.TableBorder.all(color: _rule, width: 1),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: _rainbow[ci % _rainbow.length],
                ),
                children: [
                  for (final h in ['Question (recto)', 'Réponse (verso)'])
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(
                          font: f.handBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                ],
              ),
              for (final card in c.flashcards)
                pw.TableRow(
                  verticalAlignment: pw.TableCellVerticalAlignment.middle,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            stripEmoji(card.front),
                            style: pw.TextStyle(font: f.handBold, fontSize: 12),
                          ),
                          if ((terms.englishFor(card.front) ??
                                  terms.englishFor(card.concept)) !=
                              null)
                            pw.Text(
                              'EN  ${terms.englishFor(card.front) ?? terms.englishFor(card.concept)}',
                              style: pw.TextStyle(
                                font: f.body,
                                fontSize: 9,
                                color: _blue,
                              ),
                            ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                        stripEmoji(card.back),
                        style: pw.TextStyle(font: f.body, fontSize: 10),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Carte mentale : l'image de la carte (si fournie), puis son plan détaillé.
Future<Uint8List> mindMapPdf({
  required String title,
  required MindNode root,
  Uint8List? image,
  double? imageWidth,
  double? imageHeight,
}) async {
  final f = await _fonts();
  final doc = pw.Document(title: stripEmoji(title), author: 'CISSO Academy');
  if (image != null && imageWidth != null && imageHeight != null) {
    // Une page à la taille de la carte, pour garder tous les détails.
    const maxSide = 2400.0;
    final scale = imageWidth > maxSide || imageHeight > maxSide
        ? maxSide / (imageWidth > imageHeight ? imageWidth : imageHeight)
        : 1.0;
    final w = imageWidth * scale;
    final h = imageHeight * scale;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(w + 40, h + 80),
        margin: const pw.EdgeInsets.all(20),
        theme: _theme(f),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              stripEmoji(title),
              style: pw.TextStyle(font: f.handBold, fontSize: 26),
            ),
            pw.SizedBox(height: 8),
            pw.Image(pw.MemoryImage(image), width: w, height: h),
          ],
        ),
      ),
    );
  }

  // Plan aplati : une ligne par nœud, pour que les pages se coupent bien.
  final rows = <pw.Widget>[];
  void node(MindNode n, int depth, PdfColor color) {
    final label = stripEmoji(n.label.replaceAll('\n', ' · '));
    rows.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          left: depth <= 1 ? 0 : 14.0 * (depth - 1),
          top: depth == 1 ? 10 : 3,
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4, right: 6),
              width: depth == 1 ? 9 : 6,
              height: depth == 1 ? 9 : 6,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: color,
              ),
            ),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: label,
                      style: depth == 1
                          ? pw.TextStyle(
                              font: f.handBold,
                              fontSize: 15,
                              color: color,
                            )
                          : depth == 2
                          ? pw.TextStyle(font: f.handBold, fontSize: 11.5)
                          : pw.TextStyle(font: f.body, fontSize: 10.5),
                    ),
                    if (n.en != null)
                      pw.TextSpan(
                        text: '   EN ${n.en}',
                        style: pw.TextStyle(
                          font: f.body,
                          fontSize: 9,
                          color: _blue,
                        ),
                      ),
                    if (n.detail != null)
                      pw.TextSpan(
                        text: '\n${stripEmoji(n.detail!)}',
                        style: pw.TextStyle(
                          font: f.body,
                          fontSize: 9.5,
                          color: _soft,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    for (final c in n.children) {
      node(c, depth + 1, _toneColor(c.tone, color));
    }
  }

  for (final (i, b) in root.children.indexed) {
    node(b, 1, _toneColor(b.tone, _rainbow[i % _rainbow.length]));
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: _a4(f),
      footer: (ctx) => _footer(ctx, f),
      build: (ctx) => [
        _titleBlock(f, title, root.en, 'Plan détaillé de la carte mentale'),
        ...rows,
      ],
    ),
  );
  return doc.save();
}

/// Fiche de préparation à l'examen (questions de la formation de
/// l'apprenant) : énoncés, choix, bonne réponse et explication en anglais et
/// en français, tableaux à retenir, récapitulatif et mots-clés.
Future<Uint8List> examPrepPdf({
  required String title,
  String? subtitle,
  PrepLot? lot,
  required List<PrepQuestion> questions,
}) async {
  final f = await _fonts();
  final doc = pw.Document(title: stripEmoji(title), author: 'CISSO Academy');
  const green = PdfColor.fromInt(0xFF15803D);
  final small = pw.TextStyle(font: f.body, fontSize: 10, color: _ink);
  final en = pw.TextStyle(font: f.body, fontSize: 10.5, color: _blue);

  pw.Widget bi(Bi t, {double size = 10.5, bool bold = false}) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'EN  ${stripEmoji(t.en)}',
        style: pw.TextStyle(
          font: bold ? f.handBold : f.body,
          fontSize: size,
          color: _blue,
        ),
      ),
      pw.Text(
        'FR  ${stripEmoji(t.fr)}',
        style: pw.TextStyle(font: f.hand, fontSize: size, color: _ink),
      ),
    ],
  );

  pw.Widget question(PrepQuestion q) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: _rainbow[0], width: 1),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Question ${q.number}',
          style: pw.TextStyle(font: f.handBold, fontSize: 13, color: _ink),
        ),
        bi(q.prompt, size: 11, bold: true),
        pw.SizedBox(height: 4),
        for (final (i, c) in q.choices.indexed)
          pw.Text(
            '${PrepQuestion.letter(i)}. ${stripEmoji(c.en)}  ·  ${stripEmoji(c.fr)}',
            style: small.copyWith(
              color: i == q.correct ? green : _ink,
              font: i == q.correct ? f.handBold : f.body,
            ),
          ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Bonne réponse : ${q.correctLetter}',
          style: pw.TextStyle(font: f.handBold, fontSize: 11, color: green),
        ),
        if (q.formula != null)
          pw.Text(
            'Formula / Formule : ${q.formula}',
            style: pw.TextStyle(font: f.symbols, fontSize: 9.5, color: _ink),
          ),
        pw.Text(
          'Explication',
          style: pw.TextStyle(font: f.handBold, fontSize: 10.5, color: _ink),
        ),
        bi(q.explanation, size: 10),
      ],
    ),
  );

  pw.Widget table(
    String heading,
    List<String> header,
    List<List<String>> rows,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 6),
      pw.Text(
        stripEmoji(heading),
        style: pw.TextStyle(font: f.handBold, fontSize: 13, color: _ink),
      ),
      pw.SizedBox(height: 4),
      pw.TableHelper.fromTextArray(
        headers: header,
        data: [
          for (final r in rows) [for (final c in r) stripEmoji(c)],
        ],
        headerStyle: pw.TextStyle(font: f.handBold, fontSize: 10),
        cellStyle: small,
        headerDecoration: const pw.BoxDecoration(color: _rule),
        cellAlignment: pw.Alignment.centerLeft,
        border: pw.TableBorder.all(color: _rule, width: 0.6),
      ),
      pw.SizedBox(height: 8),
    ],
  );

  final List<(Bi?, List<PrepQuestion>)> parts =
      lot?.parts.map((p) => (p.title, p.questions)).toList() ??
      [(null, questions)];

  doc.addPage(
    pw.MultiPage(
      pageTheme: _a4(f),
      footer: (ctx) => _footer(ctx, f),
      build: (ctx) => [
        _titleBlock(f, title, lot?.title.en, subtitle),
        pw.Text(
          lot?.source ?? 'Questions de la formation de l\'apprenant',
          style: pw.TextStyle(font: f.body, fontSize: 9, color: _soft),
        ),
        pw.SizedBox(height: 8),
        for (final (partTitle, qs) in parts) ...[
          if (partTitle != null) ...[
            pw.Text(
              stripEmoji(partTitle.fr),
              style: pw.TextStyle(font: f.handBold, fontSize: 16, color: _ink),
            ),
            pw.Text('EN  ${partTitle.en}', style: en),
            pw.SizedBox(height: 6),
          ],
          for (final q in qs) question(q),
        ],
        if (lot != null)
          for (final t in lot.tables)
            table(
              '${t.title.fr} (${t.title.en})',
              ['English', 'Français'],
              [
                for (final r in t.rows) [r.$1, r.$2],
              ],
            ),
        table(
          'Les bonnes réponses à mémoriser',
          ['N°', 'English', 'Français'],
          [
            for (final q in questions)
              [
                '${q.number}',
                '${q.correctLetter}. ${q.choices[q.correct].en}',
                q.choices[q.correct].fr,
              ],
          ],
        ),
        if (lot != null && lot.keywords.isNotEmpty)
          table(
            'Mots-clés à retenir',
            ['Terme', 'English', 'Français'],
            [
              for (final k in lot.keywords) [k.term, k.en, k.fr],
            ],
          ),
        if (lot?.advice case final advice?)
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 6),
            padding: const pw.EdgeInsets.all(8),
            color: const PdfColor.fromInt(0xFFFEF3C7),
            child: pw.Text(
              'Conseil : ${stripEmoji(advice)}',
              style: pw.TextStyle(font: f.hand, fontSize: 11, color: _ink),
            ),
          ),
      ],
    ),
  );
  return doc.save();
}
