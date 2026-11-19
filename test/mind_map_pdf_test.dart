import 'dart:convert';

import 'package:cisso_academy/export/mind_map_html.dart';
import 'package:cisso_academy/export/pdf_export.dart';
import 'package:cisso_academy/logic/terms.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/mind_map_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  bool overlap(MindBox a, MindBox b) =>
      a.x < b.x + b.width &&
      b.x < a.x + a.width &&
      a.y < b.y + b.height &&
      b.y < a.y + a.height;

  test('la carte du PDF est une arborescence sans bulles superposées', () {
    for (final root in [
      chapterMindMap(library.chapter('m1c1')),
      moduleMindMap(library.modules.first),
      courseMindMap(library),
    ]) {
      final map = MindMapLayout.of(root);
      final boxes = map.boxes.toList();
      // Toutes les bulles sont présentes et dans le cadre.
      int count(MindNode n) => 1 + n.children.fold(0, (s, c) => s + count(c));
      expect(boxes, hasLength(count(root)));
      for (final b in boxes) {
        expect(b.x, greaterThanOrEqualTo(-0.01), reason: b.label);
        expect(b.y, greaterThanOrEqualTo(-0.01), reason: b.label);
        expect(b.x + b.width, lessThanOrEqualTo(map.width + 0.01));
        expect(b.y + b.height, lessThanOrEqualTo(map.height + 0.01));
      }
      for (var i = 0; i < boxes.length; i++) {
        for (var j = i + 1; j < boxes.length; j++) {
          expect(
            overlap(boxes[i], boxes[j]),
            isFalse,
            reason: '${boxes[i].label} / ${boxes[j].label}',
          );
        }
      }
      // Les branches sont réparties des deux côtés de la racine.
      final first = map.root.children;
      if (first.length > 1) {
        expect(first.where((b) => b.right), isNotEmpty);
        expect(first.where((b) => !b.right), isNotEmpty);
      }
      // Chaque enfant est dans la colonne suivante, du bon côté du parent.
      for (final p in boxes) {
        for (final c in p.children) {
          expect(c.right ? c.x > p.x : c.x < p.x, isTrue, reason: c.label);
        }
      }
    }
  });

  test('le PDF de la carte mentale contient le dessin de la carte', () async {
    final terms = TermIndex(library.glossary);
    final bytes = await mindMapPdf(
      title: 'Carte mentale · chapitre 1',
      root: withEnglish(chapterMindMap(library.chapter('m1c1')), terms),
    );
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    // Le dessin des liaisons produit des courbes de Bézier (opérateur « c »).
    expect(bytes.length, greaterThan(20000));
  });

  test('PDF zoomable : une page par branche, reliées par des liens', () async {
    final root = chapterMindMap(library.chapter('m1c1'));
    final bytes = await mindMapPdf(title: 'Carte', root: root);
    final text = latin1.decode(bytes);
    final pages = RegExp(r'/Type\s*/Page\b').allMatches(text).length;
    // Carte générale + une page par branche + au moins une page de plan.
    expect(pages, greaterThan(root.children.length + 1));
    // Un lien vers chaque branche et un lien de retour sur chaque branche.
    final links = RegExp(r'/Subtype\s*/Link').allMatches(text).length;
    expect(links, 2 * root.children.length);
    for (var i = 0; i < root.children.length; i++) {
      expect(text, contains('branche-$i'));
    }
  });

  test('page HTML : autonome, complète et repliable', () {
    final root = courseMindMap(library);
    final html = mindMapHtml(title: 'Carte <test>', root: root);
    expect(html, startsWith('<!doctype html>'));
    expect(html, contains('Carte &lt;test&gt;'));
    // Hors ligne : aucune ressource extérieure.
    expect(html, isNot(contains('src=')));
    expect(html, isNot(contains('<link')));
    expect(html, isNot(contains('@import')));
    // Une bulle par nœud et un bouton par nœud qui a des enfants.
    var nodes = 0;
    var parents = 0;
    void walk(MindNode n) {
      nodes++;
      if (n.children.isNotEmpty) parents++;
      n.children.forEach(walk);
    }

    walk(root);
    expect('class="bubble"'.allMatches(html).length, nodes);
    expect('class="toggle"'.allMatches(html).length, parents);
    // Chaque libellé est présent, échappé.
    void check(MindNode n) {
      expect(
        html,
        contains(const HtmlEscape().convert(n.label).replaceAll('\n', '<br>')),
      );
      n.children.forEach(check);
    }

    check(root);
    // Arbre : racine au centre, grandes branches à gauche et à droite.
    if (root.children.length > 1) {
      expect(html, contains('<ul class="kids l">'));
      expect(html, contains('<ul class="kids r">'));
      // La branche gauche précède la bulle de la racine dans la page.
      final rootAt = html.indexOf('class="node d0');
      final leftAt = html.indexOf('<ul class="kids l">');
      expect(leftAt, greaterThan(rootAt));
      expect(leftAt, lessThan(html.indexOf('class="bubble"')));
    }
  });
}
