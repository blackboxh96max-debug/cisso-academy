import 'package:cisso_academy/logic/study_groups.dart';
import 'package:cisso_academy/models/content.dart';
import 'package:cisso_academy/ui/mind_map_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Signature d'un sous-arbre (libellés), pour repérer les branches répétées.
String _sig(MindNode n) => '${n.label}(${n.children.map(_sig).join(',')})';

/// Problèmes de répétition dans une carte : deux enfants de même libellé, ou
/// deux branches sœurs qui ont exactement les mêmes sous-branches.
List<String> _repeats(MindNode n, [String path = '']) {
  final out = <String>[];
  final here = '$path/${n.label.replaceAll('\n', ' ')}';
  final labels = <String>{};
  final subtrees = <String>{};
  for (final c in n.children) {
    if (!labels.add(c.label)) out.add('$here : « ${c.label} » deux fois');
    if (c.children.isNotEmpty) {
      final sub = c.children.map(_sig).join(',');
      if (!subtrees.add(sub)) {
        out.add('$here : « ${c.label} » répète les branches d\'une sœur');
      }
    }
    out.addAll(_repeats(c, here));
  }
  return out;
}

void main() {
  late ContentLibrary library;

  setUpAll(() async => library = await loadRealContent());

  test('chaque section du livre a ses mots-clés, sans doublon', () {
    for (final m in library.mile2Outline.modules) {
      final seen = <String>{};
      for (final s in m.sections) {
        final where = '${m.label} section ${s.number}';
        expect(s.keywords.length, inInclusiveRange(4, 6), reason: where);
        final fr = s.keywords.map((k) => k.fr).toSet();
        expect(fr.length, s.keywords.length, reason: where);
        // Deux sections d'un module n'ont pas les mêmes mots-clés.
        expect(seen.add(fr.join('|')), isTrue, reason: where);
      }
    }
  });

  test('aucune carte mentale ne répète une branche', () {
    final problems = <String>[
      for (final c in library.availableChapters) ..._repeats(chapterMindMap(c)),
      for (final view in CourseView.values) ...[
        for (final g in studyGroups(library, view))
          ..._repeats(groupMindMap(library, g)),
        ..._repeats(courseMindMap(library, view: view)),
      ],
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('carte du module 3 (livre) : une branche propre à chaque section', () {
    final g = studyGroups(
      library,
      CourseView.mile2,
    ).firstWhere((g) => g.outline?.label == 'Module 3');
    final map = groupMindMap(library, g);
    // Neuf sections, puis cadre de décision, réflexes d'examen et sigles.
    expect(map.children, hasLength(12));
    final hashing = map.children[3];
    expect(hashing.label, contains('Hachage'));
    expect(hashing.children.map((c) => c.label), contains('HMAC'));
    expect(
      hashing.children.map((c) => c.label),
      containsAll(['Contrôles appliqués', 'Vérifier ses acquis']),
    );
    expect(map.children.last.label, 'Glossaire des sigles');
    expect(
      map.children.first.children.map((c) => c.label),
      isNot(contains('Le chiffrement symétrique')),
    );
  });

  test('cartes de révision des modules du livre : bien rattachées', () {
    final modules = {
      for (final m in library.mile2Outline.modules)
        if (m.revisionMap.isNotEmpty) m.label: m,
    };
    expect(
      modules.keys,
      containsAll([
        'Module 1',
        'Module 2',
        'Module 3',
        'Module 4',
        'Module 5',
        'Module 8',
      ]),
    );
    for (final m in modules.values) {
      final numbers = {for (final s in m.sections) s.number};
      for (final b in m.revisionMap) {
        final where = '${m.label} « ${b.node.label} »';
        if (b.section != null) {
          expect(numbers, contains(b.section), reason: where);
        }
        expect(b.node.children, isNotEmpty, reason: where);
        expect(b.inline && b.section == null, isFalse, reason: where);
      }
    }
  });

  test('carte du module 4 (livre) : Kerberos sous les authentifications', () {
    final g = studyGroups(
      library,
      CourseView.mile2,
    ).firstWhere((g) => g.outline?.label == 'Module 4');
    final map = groupMindMap(library, g);
    // Cinq sections, puis le glossaire des sigles à la racine.
    expect(map.children, hasLength(6));
    expect(map.children.last.label, 'Glossaire des sigles');
    final auth = map.children[1];
    expect(auth.label, contains("Techniques d'authentification"));
    final labels = auth.children.map((c) => c.label).toList();
    expect(labels, contains('MFA'));
    expect(labels, contains('Authentification unique, annuaires et Kerberos'));
    final kerberos = auth.children.firstWhere(
      (c) => c.label == 'Authentification unique, annuaires et Kerberos',
    );
    expect(kerberos.en, 'Single Sign-On, Directories and Kerberos');
    expect(kerberos.depth, greaterThanOrEqualTo(3));
  });
}
