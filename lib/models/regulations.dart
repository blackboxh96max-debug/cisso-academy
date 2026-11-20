/// Fiches « Textes et normes » : définition courte, l'essentiel à savoir et
/// liens officiels pour une norme ou un règlement. Ce ne sont pas des leçons :
/// quand une leçon traite le sujet, la fiche y renvoie.
library;

import 'exam_prep.dart' show Bi;

/// Un lien externe officiel.
class RegulationLink {
  const RegulationLink({required this.label, required this.url});

  final Bi label;
  final String url;

  factory RegulationLink.fromJson(Map<String, dynamic> json) => RegulationLink(
    label: Bi.fromJson(json['label'] as Map<String, dynamic>),
    url: json['url'] as String,
  );
}

/// Une fiche : une norme, un règlement, une directive ou une instruction.
class RegulationSheet {
  const RegulationSheet({
    required this.id,
    required this.name,
    required this.title,
    required this.nature,
    required this.reference,
    required this.status,
    required this.definition,
    required this.essentials,
    required this.remember,
    required this.lessons,
    required this.links,
  });

  final String id;

  /// Nom court, identique dans les deux langues (« ISO/IEC 27017 », « DORA »).
  final String name;
  final Bi title;
  final Bi nature;
  final Bi reference;

  /// Dates et état (publication, application, transposition).
  final Bi status;
  final Bi definition;
  final List<Bi> essentials;

  /// La phrase à retenir.
  final Bi remember;

  /// Leçons de la formation qui approfondissent le sujet.
  final List<String> lessons;
  final List<RegulationLink> links;

  factory RegulationSheet.fromJson(Map<String, dynamic> json) {
    Bi bi(String key) => Bi.fromJson(json[key] as Map<String, dynamic>);
    return RegulationSheet(
      id: json['id'] as String,
      name: json['name'] as String,
      title: bi('title'),
      nature: bi('nature'),
      reference: bi('reference'),
      status: bi('status'),
      definition: bi('definition'),
      essentials: [
        for (final e in json['essentials'] as List)
          Bi.fromJson(e as Map<String, dynamic>),
      ],
      remember: bi('remember'),
      lessons: [for (final l in json['lessons'] as List? ?? const []) '$l'],
      links: [
        for (final l in json['links'] as List)
          RegulationLink.fromJson(l as Map<String, dynamic>),
      ],
    );
  }
}

class RegulationGroup {
  const RegulationGroup({
    required this.id,
    required this.emoji,
    required this.title,
    required this.items,
  });

  final String id;
  final String emoji;
  final Bi title;
  final List<RegulationSheet> items;

  factory RegulationGroup.fromJson(Map<String, dynamic> json) =>
      RegulationGroup(
        id: json['id'] as String,
        emoji: json['emoji'] as String,
        title: Bi.fromJson(json['title'] as Map<String, dynamic>),
        items: [
          for (final i in json['items'] as List)
            RegulationSheet.fromJson(i as Map<String, dynamic>),
        ],
      );
}

/// Toutes les fiches, par famille.
class Regulations {
  const Regulations({
    required this.intro,
    required this.notice,
    required this.verifiedOn,
    required this.groups,
  });

  final Bi intro;
  final Bi notice;
  final String verifiedOn;
  final List<RegulationGroup> groups;

  static const empty = Regulations(
    intro: Bi('', ''),
    notice: Bi('', ''),
    verifiedOn: '',
    groups: [],
  );

  Iterable<RegulationSheet> get sheets => groups.expand((g) => g.items);

  RegulationSheet? sheet(String id) {
    for (final s in sheets) {
      if (s.id == id) return s;
    }
    return null;
  }

  factory Regulations.fromJson(Map<String, dynamic> json) => Regulations(
    intro: Bi.fromJson(json['intro'] as Map<String, dynamic>),
    notice: Bi.fromJson(json['notice'] as Map<String, dynamic>),
    verifiedOn: json['verifiedOn'] as String,
    groups: [
      for (final g in json['groups'] as List)
        RegulationGroup.fromJson(g as Map<String, dynamic>),
    ],
  );
}
