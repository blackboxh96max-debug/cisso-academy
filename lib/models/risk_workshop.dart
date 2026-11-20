/// Atelier risques : registre de scénarios ISO/IEC 27005 (vraisemblance,
/// gravité, mesure de l'annexe A, risque résiduel) pour la matrice 4 × 4 et
/// les études de cas.
library;

import 'exam_prep.dart' show Bi;

/// Niveau qualitatif d'un score vraisemblance × gravité (1 à 16).
enum RiskLevel {
  low(Bi('Low', 'Faible')),
  moderate(Bi('Moderate', 'Modéré')),
  high(Bi('High', 'Élevé')),
  critical(Bi('Critical', 'Critique'));

  const RiskLevel(this.label);

  final Bi label;

  /// Seuils de la matrice : 1-3 faible, 4-7 modéré, 8-11 élevé, 12-16
  /// critique.
  static RiskLevel of(int score) => score <= 3
      ? low
      : score <= 7
      ? moderate
      : score <= 11
      ? high
      : critical;
}

/// Un niveau d'échelle (vraisemblance ou gravité) et son repère chiffré.
class RiskScale {
  const RiskScale({required this.level, required this.label, this.value = 0});

  final int level;
  final Bi label;

  /// Probabilité annuelle (vraisemblance) ou perte par événement en euros
  /// (gravité).
  final double value;
}

class RiskControl {
  const RiskControl({required this.ref, required this.title});

  /// Référence de l'annexe A d'ISO/IEC 27001:2022 (« A.8.7 »).
  final String ref;
  final Bi title;
}

class RiskScenario {
  const RiskScenario({
    required this.id,
    required this.asset,
    required this.threat,
    required this.vulnerability,
    required this.consequence,
    required this.criteria,
    required this.likelihood,
    required this.impact,
    required this.control,
    required this.action,
    required this.residualLikelihood,
    required this.residualImpact,
    required this.owner,
    required this.explanation,
  });

  final String id;
  final Bi asset;
  final Bi threat;
  final Bi vulnerability;
  final Bi consequence;

  /// Critères touchés : 'C', 'I', 'D'.
  final List<String> criteria;
  final int likelihood;
  final int impact;
  final RiskControl control;
  final Bi action;
  final int residualLikelihood;
  final int residualImpact;
  final Bi owner;

  /// Pourquoi ces notes, et ce que change la mesure.
  final Bi explanation;

  int get score => likelihood * impact;
  int get residualScore => residualLikelihood * residualImpact;
  RiskLevel get level => RiskLevel.of(score);
  RiskLevel get residualLevel => RiskLevel.of(residualScore);

  factory RiskScenario.fromJson(Map<String, dynamic> json) {
    Bi bi(String key) => Bi.fromJson(json[key] as Map<String, dynamic>);
    final control = json['control'] as Map<String, dynamic>;
    return RiskScenario(
      id: json['id'] as String,
      asset: bi('asset'),
      threat: bi('threat'),
      vulnerability: bi('vulnerability'),
      consequence: bi('consequence'),
      criteria: [for (final c in json['criteria'] as List) '$c'],
      likelihood: json['likelihood'] as int,
      impact: json['impact'] as int,
      control: RiskControl(
        ref: control['ref'] as String,
        title: Bi.fromJson(control['title'] as Map<String, dynamic>),
      ),
      action: bi('action'),
      residualLikelihood: json['residualLikelihood'] as int,
      residualImpact: json['residualImpact'] as int,
      owner: bi('owner'),
      explanation: bi('explanation'),
    );
  }
}

class RiskWorkshop {
  const RiskWorkshop({
    required this.intro,
    required this.notice,
    required this.source,
    required this.likelihoodScale,
    required this.impactScale,
    required this.scenarios,
  });

  final Bi intro;
  final Bi notice;
  final Bi source;
  final List<RiskScale> likelihoodScale;
  final List<RiskScale> impactScale;
  final List<RiskScenario> scenarios;

  static const empty = RiskWorkshop(
    intro: Bi('', ''),
    notice: Bi('', ''),
    source: Bi('', ''),
    likelihoodScale: [],
    impactScale: [],
    scenarios: [],
  );

  /// Probabilité annuelle (ARO) d'un niveau de vraisemblance.
  double probability(int level) =>
      likelihoodScale.firstWhere((s) => s.level == level).value;

  /// Perte par événement (SLE) d'un niveau de gravité.
  double loss(int level) =>
      impactScale.firstWhere((s) => s.level == level).value;

  /// Perte annuelle attendue : ALE = ARO × SLE.
  double ale(int likelihood, int impact) =>
      probability(likelihood) * loss(impact);

  double initialAle(RiskScenario s) => ale(s.likelihood, s.impact);
  double residualAle(RiskScenario s) =>
      ale(s.residualLikelihood, s.residualImpact);

  factory RiskWorkshop.fromJson(Map<String, dynamic> json) {
    Bi bi(String key) => Bi.fromJson(json[key] as Map<String, dynamic>);
    List<RiskScale> scale(String key, String value) => [
      for (final s in json[key] as List)
        RiskScale(
          level: (s as Map<String, dynamic>)['level'] as int,
          label: Bi.fromJson(s['label'] as Map<String, dynamic>),
          value: (s[value] as num).toDouble(),
        ),
    ];
    return RiskWorkshop(
      intro: bi('intro'),
      notice: bi('notice'),
      source: bi('source'),
      likelihoodScale: scale('likelihood', 'probability'),
      impactScale: scale('impact', 'loss'),
      scenarios: [
        for (final s in json['scenarios'] as List)
          RiskScenario.fromJson(s as Map<String, dynamic>),
      ],
    );
  }
}

/// Montant en euros avec espaces de milliers : « 156 000 € ».
String euros(double amount) {
  final digits = amount.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(' ');
    b.write(digits[i]);
  }
  return '$b €';
}

/// Quatre réponses possibles pour l'ALE d'un scénario : la bonne et trois
/// erreurs classiques (oublier l'ARO, prendre le niveau pour une
/// probabilité, prendre le résiduel), dans un ordre stable.
List<double> aleChoices(RiskWorkshop w, RiskScenario s) {
  final right = w.initialAle(s);
  final sle = w.loss(s.impact);
  final candidates = <double>[
    right,
    sle,
    s.likelihood * sle,
    w.residualAle(s),
    right * 10,
    right / 10,
  ];
  final out = <double>[];
  for (final c in candidates) {
    if (out.length == 4) break;
    if (!out.any((o) => (o - c).abs() < 0.5)) out.add(c);
  }
  final shift = _seed(s.id) % 4;
  return [for (var i = 0; i < 4; i++) out[(i + shift) % 4]];
}

/// Quatre mesures de l'annexe A : celle du scénario et trois autres du
/// registre, choisies de façon stable.
List<RiskControl> controlChoices(RiskWorkshop w, RiskScenario s) {
  final others = <String, RiskControl>{};
  for (final o in w.scenarios) {
    if (o.control.ref != s.control.ref) others[o.control.ref] = o.control;
  }
  final pool = others.values.toList()..sort((a, b) => a.ref.compareTo(b.ref));
  final start = _seed(s.id) % pool.length;
  final picked = <RiskControl>[
    s.control,
    for (var i = 0; i < 3; i++) pool[(start + i * 7) % pool.length],
  ];
  final shift = (_seed(s.id) ~/ 4) % 4;
  return [for (var i = 0; i < 4; i++) picked[(i + shift) % 4]];
}

/// Graine stable (identique sur toutes les plateformes) tirée de l'identifiant.
int _seed(String id) =>
    int.tryParse(id.replaceAll(RegExp(r'\D'), '')) ??
    id.codeUnits.fold(0, (a, b) => a + b);
