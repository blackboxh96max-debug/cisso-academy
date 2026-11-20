import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models/content.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/note_box.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Ouvre l'Atelier risques, sur la matrice ou sur les études de cas.
void openRiskWorkshop(BuildContext context, {bool cases = false}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RiskWorkshopPage(startWithCases: cases),
      ),
    );

/// Couleur d'un niveau de risque.
Tone levelTone(RiskLevel level) => switch (level) {
  RiskLevel.low => Tone.green,
  RiskLevel.moderate => Tone.yellow,
  RiskLevel.high => Tone.orange,
  RiskLevel.critical => Tone.red,
};

/// Atelier risques : la matrice 4 × 4 des scénarios (avant et après
/// traitement) et des études de cas corrigées.
class RiskWorkshopPage extends StatefulWidget {
  const RiskWorkshopPage({super.key, this.startWithCases = false});

  final bool startWithCases;

  @override
  State<RiskWorkshopPage> createState() => _RiskWorkshopPageState();
}

class _RiskWorkshopPageState extends State<RiskWorkshopPage> {
  late bool _cases = widget.startWithCases;
  bool _residual = false;

  /// Case de la matrice choisie : (vraisemblance, gravité).
  (int, int)? _cell;
  final Set<String> _open = {};
  int _case = 0;

  /// Points obtenus par cas terminé (sur 4).
  final Map<String, int> _scores = {};

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final w = state.library.riskWorkshop;
    final en = state.lessonsInEnglish;
    String t(Bi b) => en ? b.en : b.fr;
    final white = Hand.sansText(
      context,
      size: 14,
    ).copyWith(color: Colors.white, fontWeight: FontWeight.w600);
    return NotebookPage(
      title: en ? 'Risk workshop' : 'Atelier risques',
      actions: [
        Tooltip(
          message: en ? 'Lire en français' : 'Read in English',
          child: TextButton(
            key: const Key('risk-language'),
            onPressed: () => state.setLessonsInEnglish(!en),
            child: Text(
              en ? 'FR' : 'EN',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
      children: [
        GradientBanner(
          tone: Tone.red,
          toTone: Tone.orange,
          seed: 91,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                en ? '🎯 Risk workshop' : '🎯 Atelier risques',
                style: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: Hand.tsize(34),
                  fontWeight: Hand.titleWeight,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(t(w.intro), style: white),
              const SizedBox(height: 6),
              Text(
                '${w.scenarios.length} ${en ? 'scenarios' : 'scénarios'} · '
                'ISO/IEC 27005 · ${t(w.notice)}',
                style: white.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: SegmentedButton<bool>(
            key: const Key('risk-tabs'),
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.grid_view),
                label: Text(en ? 'Matrix' : 'Matrice'),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.school_outlined),
                label: Text(en ? 'Case studies' : 'Études de cas'),
              ),
            ],
            selected: {_cases},
            onSelectionChanged: (s) => setState(() => _cases = s.first),
          ),
        ),
        const SizedBox(height: 10),
        if (_cases)
          ..._caseStudies(context, w, en)
        else
          ..._matrix(context, w, en),
      ],
    );
  }

  // ---------------------------------------------------------------- matrice

  List<Widget> _matrix(BuildContext context, RiskWorkshop w, bool en) {
    String t(Bi b) => en ? b.en : b.fr;
    int l(RiskScenario s) => _residual ? s.residualLikelihood : s.likelihood;
    int g(RiskScenario s) => _residual ? s.residualImpact : s.impact;
    final shown = [
      for (final s in w.scenarios)
        if (_cell == null || (l(s), g(s)) == _cell) s,
    ];
    final initial = w.scenarios.fold(0.0, (a, s) => a + w.initialAle(s));
    final residual = w.scenarios.fold(0.0, (a, s) => a + w.residualAle(s));
    final levels = {
      for (final lv in RiskLevel.values)
        lv: w.scenarios
            .where((s) => (_residual ? s.residualLevel : s.level) == lv)
            .length,
    };
    return [
      Center(
        child: SegmentedButton<bool>(
          key: const Key('risk-residual'),
          segments: [
            ButtonSegment(
              value: false,
              label: Text(en ? 'Before treatment' : 'Avant traitement'),
            ),
            ButtonSegment(
              value: true,
              label: Text(en ? 'After treatment' : 'Après traitement'),
            ),
          ],
          selected: {_residual},
          onSelectionChanged: (s) => setState(() {
            _residual = s.first;
            _cell = null;
          }),
        ),
      ),
      NotePanel(
        title: en
            ? 'Likelihood × impact (${_residual ? 'residual' : 'initial'})'
            : 'Vraisemblance × gravité (${_residual ? 'résiduel' : 'initial'})',
        emoji: '🗺️',
        tone: Tone.red,
        seed: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeatMap(
              workshop: w,
              english: en,
              residual: _residual,
              selected: _cell,
              onTap: (c) => setState(() => _cell = _cell == c ? null : c),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final lv in RiskLevel.values.reversed)
                  _Chip(
                    text: '${t(lv.label)} : ${levels[lv]}',
                    tone: levelTone(lv),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              en
                  ? 'Score = likelihood × impact: 1-3 low, 4-7 moderate, '
                        '8-11 high, 12-16 critical. Tap a cell to filter.'
                  : 'Score = vraisemblance × gravité : 1-3 faible, 4-7 '
                        'modéré, 8-11 élevé, 12-16 critique. Touche une case '
                        'pour filtrer.',
              style: Hand.sansText(
                context,
                size: 13,
              ).copyWith(color: Paper.of(context).inkSoft),
            ),
          ],
        ),
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          HandStat(
            label: en ? 'Initial ALE' : 'ALE initiale',
            value: euros(initial),
            tone: Tone.red,
            emoji: '💸',
          ),
          HandStat(
            label: en ? 'Residual ALE' : 'ALE résiduelle',
            value: euros(residual),
            tone: Tone.green,
            emoji: '🛡️',
            seed: 14,
          ),
          HandStat(
            label: en ? 'Annual reduction' : 'Réduction annuelle',
            value: euros(initial - residual),
            tone: Tone.blue,
            emoji: '📉',
            seed: 15,
          ),
        ],
      ),
      const SizedBox(height: 6),
      NotePanel(
        title: _cell == null
            ? (en ? 'Risk register' : 'Registre des risques')
            : en
            ? 'Likelihood ${_cell!.$1}, impact ${_cell!.$2}'
            : 'Vraisemblance ${_cell!.$1}, gravité ${_cell!.$2}',
        emoji: '📋',
        tone: Tone.blue,
        seed: 93,
        trailing: _cell == null
            ? null
            : TextButton(
                onPressed: () => setState(() => _cell = null),
                child: Text(en ? 'Show all' : 'Tout afficher'),
              ),
        child: Column(
          children: [
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(en ? 'No scenario here.' : 'Aucun scénario ici.'),
              ),
            for (final s in shown)
              _ScenarioCard(
                key: Key('risk-${s.id}'),
                workshop: w,
                scenario: s,
                english: en,
                open: _open.contains(s.id),
                onToggle: () => setState(() {
                  if (!_open.remove(s.id)) _open.add(s.id);
                }),
                onPractice: () => setState(() {
                  _case = w.scenarios.indexOf(s);
                  _cases = true;
                }),
              ),
          ],
        ),
      ),
      Text(
        t(w.source),
        style: Hand.sansText(
          context,
          size: 12.5,
        ).copyWith(color: Paper.of(context).inkSoft),
      ),
    ];
  }

  // --------------------------------------------------------- études de cas

  List<Widget> _caseStudies(BuildContext context, RiskWorkshop w, bool en) {
    final s = w.scenarios[_case];
    final done = _scores.length;
    final points = _scores.values.fold(0, (a, b) => a + b);
    return [
      Row(
        children: [
          IconButton(
            key: const Key('case-previous'),
            tooltip: en ? 'Previous case' : 'Cas précédent',
            onPressed: _case == 0 ? null : () => setState(() => _case--),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              en
                  ? 'Case ${_case + 1} of ${w.scenarios.length} · '
                        '$done done, $points/${done * 4} points'
                  : 'Cas ${_case + 1} sur ${w.scenarios.length} · '
                        '$done terminés, $points/${done * 4} points',
              textAlign: TextAlign.center,
              style: Hand.sansText(
                context,
                size: 14,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            key: const Key('case-next'),
            tooltip: en ? 'Next case' : 'Cas suivant',
            onPressed: _case == w.scenarios.length - 1
                ? null
                : () => setState(() => _case++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      _CaseStudy(
        key: ValueKey('case-${s.id}'),
        workshop: w,
        scenario: s,
        english: en,
        onFinished: (p) => setState(() => _scores[s.id] = p),
        onNext: _case == w.scenarios.length - 1
            ? null
            : () => setState(() => _case++),
      ),
    ];
  }
}

// ------------------------------------------------------------------ widgets

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.tone});

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.fill,
        border: Border.all(color: c.ink, width: 1.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: Hand.sansText(
          context,
          size: 13,
        ).copyWith(color: c.ink, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Matrice 4 × 4 : vraisemblance de 4 (en haut) à 1, gravité de 1 à 4.
class _HeatMap extends StatelessWidget {
  const _HeatMap({
    required this.workshop,
    required this.english,
    required this.residual,
    required this.selected,
    required this.onTap,
  });

  final RiskWorkshop workshop;
  final bool english;
  final bool residual;
  final (int, int)? selected;
  final ValueChanged<(int, int)> onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = Paper.of(context);
    final small = Hand.sansText(
      context,
      size: 12,
    ).copyWith(color: paper.inkSoft);
    String t(Bi b) => english ? b.en : b.fr;
    int count(int l, int g) => workshop.scenarios
        .where(
          (s) => residual
              ? s.residualLikelihood == l && s.residualImpact == g
              : s.likelihood == l && s.impact == g,
        )
        .length;
    Widget label(String text, {TextAlign align = TextAlign.center}) => Padding(
      padding: const EdgeInsets.all(4),
      child: Text(text, style: small, textAlign: align),
    );
    return Column(
      children: [
        for (final l in [4, 3, 2, 1])
          Row(
            children: [
              SizedBox(
                width: 92,
                child: label(
                  '$l · ${t(workshop.likelihoodScale[l - 1].label)}',
                  align: TextAlign.right,
                ),
              ),
              for (final g in [1, 2, 3, 4])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: Builder(
                      builder: (context) {
                        final n = count(l, g);
                        final c = toneColors(
                          levelTone(RiskLevel.of(l * g)),
                          brightness,
                        );
                        final isSel = selected == (l, g);
                        return InkWell(
                          key: Key('cell-$l-$g'),
                          onTap: () => onTap((l, g)),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: n == 0
                                  ? c.fill.withValues(alpha: 0.45)
                                  : c.fill,
                              border: Border.all(
                                color: c.ink,
                                width: isSel ? 3.2 : 1.2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    n == 0 ? '·' : '$n',
                                    style: TextStyle(
                                      fontFamily: Hand.title,
                                      fontSize: Hand.tsize(24),
                                      fontWeight: FontWeight.w800,
                                      color: c.ink,
                                    ),
                                  ),
                                  Text(
                                    '${l * g}',
                                    style: small.copyWith(
                                      fontSize: 10.5,
                                      color: c.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        Row(
          children: [
            const SizedBox(width: 92),
            for (final g in [1, 2, 3, 4])
              Expanded(
                child: Column(
                  children: [
                    label('$g'),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        t(workshop.impactScale[g - 1].label),
                        style: small,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        label(
          english ? '↑ likelihood    impact →' : '↑ vraisemblance    gravité →',
        ),
      ],
    );
  }
}

/// Fiche d'un scénario du registre.
class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    super.key,
    required this.workshop,
    required this.scenario,
    required this.english,
    required this.open,
    required this.onToggle,
    required this.onPractice,
  });

  final RiskWorkshop workshop;
  final RiskScenario scenario;
  final bool english;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final s = scenario;
    final w = workshop;
    final paper = Paper.of(context);
    String t(Bi b) => english ? b.en : b.fr;
    final body = Hand.sansText(context, size: 14.5);
    final bold = body.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: HandBox(
        fill: paper.page,
        stroke: paper.rule,
        strokeWidth: 1.4,
        seed: s.id.codeUnits.last,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s.id} · ${t(s.threat)}', style: bold),
                        Text(
                          '${t(s.asset)} → ${t(s.consequence)}',
                          style: body.copyWith(color: paper.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _Chip(
                    text: '${s.score} ${t(s.level.label)}',
                    tone: levelTone(s.level),
                  ),
                  const SizedBox(width: 4),
                  Text('→', style: bold),
                  const SizedBox(width: 4),
                  _Chip(
                    text: '${s.residualScore}',
                    tone: levelTone(s.residualLevel),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (open) ...[
              const SizedBox(height: 8),
              _ScenarioFacts(workshop: w, scenario: s, english: english),
              const SizedBox(height: 8),
              _Treatment(workshop: w, scenario: s, english: english),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GradientButton(
                  key: Key('practice-${s.id}'),
                  emoji: '🏋️',
                  label: english
                      ? 'Practice this case'
                      : "S'entraîner sur ce cas",
                  from: Tone.orange,
                  to: Tone.red,
                  onPressed: onPractice,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le contexte d'un scénario : actif, menace, vulnérabilité, critères.
class _ScenarioFacts extends StatelessWidget {
  const _ScenarioFacts({
    required this.workshop,
    required this.scenario,
    required this.english,
  });

  final RiskWorkshop workshop;
  final RiskScenario scenario;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final s = scenario;
    String t(Bi b) => english ? b.en : b.fr;
    final body = Hand.sansText(context, size: 14.5);
    const crit = {
      'C': Bi('Confidentiality', 'Confidentialité'),
      'I': Bi('Integrity', 'Intégrité'),
      'D': Bi('Availability', 'Disponibilité'),
    };
    TableRow row(String k, String v) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10, bottom: 4),
          child: Text(k, style: body.copyWith(fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(v, style: body),
        ),
      ],
    );
    return Table(
      columnWidths: const {0: FixedColumnWidth(150), 1: FlexColumnWidth()},
      children: [
        row(english ? '🗄️ Asset' : '🗄️ Actif', t(s.asset)),
        row(english ? '😈 Threat' : '😈 Menace', t(s.threat)),
        row(
          english ? '🕳️ Vulnerability' : '🕳️ Vulnérabilité',
          t(s.vulnerability),
        ),
        row(english ? '💥 Consequence' : '💥 Conséquence', t(s.consequence)),
        row(
          english ? '🔐 Criteria' : '🔐 Critères',
          s.criteria.map((c) => t(crit[c]!)).join(', '),
        ),
      ],
    );
  }
}

/// La correction complète : notes, ALE, mesure, risque résiduel.
class _Treatment extends StatelessWidget {
  const _Treatment({
    required this.workshop,
    required this.scenario,
    required this.english,
  });

  final RiskWorkshop workshop;
  final RiskScenario scenario;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final s = scenario;
    final w = workshop;
    String t(Bi b) => english ? b.en : b.fr;
    final body = Hand.sansText(context, size: 14.5);
    String pct(int l) => '${(w.probability(l) * 100).round()} %';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteBox(
          tone: levelTone(s.level),
          label: english ? 'Initial risk' : 'Risque initial',
          emoji: '📊',
          seed: 4,
          child: Text(
            english
                ? 'Likelihood ${s.likelihood} × impact ${s.impact} = '
                      '${s.score} (${t(s.level.label)}).\n'
                      'ALE = ARO ${pct(s.likelihood)} × SLE '
                      '${euros(w.loss(s.impact))} = ${euros(w.initialAle(s))}'
                : 'Vraisemblance ${s.likelihood} × gravité ${s.impact} = '
                      '${s.score} (${t(s.level.label)}).\n'
                      'ALE = ARO ${pct(s.likelihood)} × SLE '
                      '${euros(w.loss(s.impact))} = ${euros(w.initialAle(s))}',
            style: body,
          ),
        ),
        const SizedBox(height: 8),
        NoteBox(
          tone: Tone.green,
          label: english ? 'Treatment: reduce' : 'Traitement : réduire',
          emoji: '🛠️',
          seed: 6,
          child: Text(
            '${s.control.ref} ${t(s.control.title)}\n'
            '${t(s.action)}\n'
            '${english ? 'Owner' : 'Responsable'} : ${t(s.owner)}',
            style: body,
          ),
        ),
        const SizedBox(height: 8),
        NoteBox(
          tone: levelTone(s.residualLevel),
          label: english ? 'Residual risk' : 'Risque résiduel',
          emoji: '🛡️',
          seed: 8,
          child: Text(
            '${s.residualLikelihood} × ${s.residualImpact} = '
            '${s.residualScore} (${t(s.residualLevel.label)}) · ALE '
            '${euros(w.residualAle(s))} · '
            '${english ? 'saving' : 'gain'} '
            '${euros(w.initialAle(s) - w.residualAle(s))} '
            '${english ? 'per year' : 'par an'}',
            style: body,
          ),
        ),
        const SizedBox(height: 8),
        NoteBox(
          tone: Tone.orange,
          label: english ? 'Why' : 'Pourquoi',
          emoji: '💡',
          seed: 5,
          child: Text(t(s.explanation), style: body),
        ),
      ],
    );
  }
}

/// Une étude de cas en trois étapes : noter, choisir la mesure, calculer
/// l'ALE ; puis la correction complète.
class _CaseStudy extends StatefulWidget {
  const _CaseStudy({
    super.key,
    required this.workshop,
    required this.scenario,
    required this.english,
    required this.onFinished,
    required this.onNext,
  });

  final RiskWorkshop workshop;
  final RiskScenario scenario;
  final bool english;
  final ValueChanged<int> onFinished;
  final VoidCallback? onNext;

  @override
  State<_CaseStudy> createState() => _CaseStudyState();
}

class _CaseStudyState extends State<_CaseStudy> {
  int? _l, _g;
  bool _rated = false;
  String? _control;
  double? _ale;

  bool get _finished => _ale != null;

  int _score() {
    final s = widget.scenario;
    return (_l == s.likelihood ? 1 : 0) +
        (_g == s.impact ? 1 : 0) +
        (_control == s.control.ref ? 1 : 0) +
        (_ale != null && (_ale! - widget.workshop.initialAle(s)).abs() < 0.5
            ? 1
            : 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scenario;
    final w = widget.workshop;
    final en = widget.english;
    String t(Bi b) => en ? b.en : b.fr;
    final body = Hand.sansText(context, size: 14.5);
    final bold = body.copyWith(fontWeight: FontWeight.w800);
    final brightness = Theme.of(context).brightness;
    final good = toneColors(Tone.green, brightness).ink;
    final bad = toneColors(Tone.red, brightness).ink;

    Widget levelPicker(
      String key,
      List<RiskScale> scale,
      int? value,
      int answer,
      ValueChanged<int> onPick,
      String Function(RiskScale) extra,
    ) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final sc in scale)
          ChoiceChip(
            key: Key('$key-${sc.level}'),
            label: Text('${sc.level} · ${t(sc.label)} (${extra(sc)})'),
            selected: value == sc.level,
            onSelected: _rated ? null : (_) => setState(() => onPick(sc.level)),
            avatar: !_rated
                ? null
                : sc.level == answer
                ? Icon(Icons.check_circle, color: good, size: 18)
                : value == sc.level
                ? Icon(Icons.cancel, color: bad, size: 18)
                : null,
          ),
      ],
    );

    return NotePanel(
      title: '${s.id} · ${t(s.threat)}',
      emoji: '🧩',
      tone: Tone.turquoise,
      seed: 94,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScenarioFacts(workshop: w, scenario: s, english: en),
          const SizedBox(height: 10),
          Text(
            en
                ? '1. Rate the likelihood (annual probability)'
                : '1. Note la vraisemblance (probabilité annuelle)',
            style: bold,
          ),
          const SizedBox(height: 6),
          levelPicker(
            'case-l',
            w.likelihoodScale,
            _l,
            s.likelihood,
            (v) => _l = v,
            (sc) => '${(sc.value * 100).round()} %',
          ),
          const SizedBox(height: 10),
          Text(
            en
                ? '2. Rate the impact (loss per event)'
                : '2. Note la gravité (perte par événement)',
            style: bold,
          ),
          const SizedBox(height: 6),
          levelPicker(
            'case-g',
            w.impactScale,
            _g,
            s.impact,
            (v) => _g = v,
            (sc) => euros(sc.value),
          ),
          const SizedBox(height: 10),
          if (!_rated)
            FilledButton(
              key: const Key('case-rate'),
              onPressed: _l == null || _g == null
                  ? null
                  : () => setState(() => _rated = true),
              child: Text(en ? 'Check' : 'Vérifier'),
            )
          else ...[
            NoteBox(
              tone: levelTone(s.level),
              label: en ? 'Expected rating' : 'Notation attendue',
              emoji: '📊',
              seed: 11,
              child: Text(
                '${s.likelihood} × ${s.impact} = ${s.score} '
                '(${t(s.level.label)}). ${t(s.explanation)}',
                style: body,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              en
                  ? '3. Which ISO/IEC 27001 Annex A control treats this risk best?'
                  : '3. Quelle mesure de l\'annexe A d\'ISO/IEC 27001 traite '
                        'le mieux ce risque ?',
              style: bold,
            ),
            const SizedBox(height: 4),
            for (final c in controlChoices(w, s))
              _Option(
                key: Key('case-control-${c.ref}'),
                text: '${c.ref} ${t(c.title)}',
                selected: _control == c.ref,
                revealed: _control != null,
                right: c.ref == s.control.ref,
                onTap: _control != null
                    ? null
                    : () => setState(() => _control = c.ref),
              ),
            if (_control != null) ...[
              const SizedBox(height: 4),
              Text('🛠️ ${t(s.action)}', style: body),
              const SizedBox(height: 12),
              Text(
                en
                    ? '4. What is the annual loss expectancy (ALE = ARO × SLE)?'
                    : '4. Quelle est la perte annuelle attendue '
                          '(ALE = ARO × SLE) ?',
                style: bold,
              ),
              const SizedBox(height: 4),
              for (final (i, a) in aleChoices(w, s).indexed)
                _Option(
                  key: Key('case-ale-$i'),
                  text: euros(a),
                  selected: _ale == a,
                  revealed: _ale != null,
                  right: (a - w.initialAle(s)).abs() < 0.5,
                  onTap: _ale != null
                      ? null
                      : () {
                          setState(() => _ale = a);
                          widget.onFinished(_score());
                        },
                ),
            ],
            if (_finished) ...[
              const SizedBox(height: 10),
              Text(
                en
                    ? '🏁 ${_score()} / 4 — correction'
                    : '🏁 ${_score()} / 4 — correction',
                style: bold,
              ),
              const SizedBox(height: 6),
              _Treatment(workshop: w, scenario: s, english: en),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('case-retry'),
                    onPressed: () => setState(() {
                      _l = _g = null;
                      _rated = false;
                      _control = null;
                      _ale = null;
                    }),
                    child: Text(en ? 'Try again' : 'Recommencer'),
                  ),
                  if (widget.onNext != null)
                    FilledButton(
                      key: const Key('case-continue'),
                      onPressed: widget.onNext,
                      child: Text(en ? 'Next case' : 'Cas suivant'),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Une réponse à choix : marquée juste ou fausse une fois révélée.
class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.text,
    required this.selected,
    required this.revealed,
    required this.right,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool revealed;
  final bool right;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = Paper.of(context);
    final tone = !revealed
        ? null
        : right
        ? Tone.green
        : selected
        ? Tone.red
        : null;
    final c = tone == null ? null : toneColors(tone, brightness);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: c?.fill ?? paper.page,
            border: Border.all(color: c?.ink ?? paper.rule, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                !revealed
                    ? Icons.radio_button_unchecked
                    : right
                    ? Icons.check_circle
                    : selected
                    ? Icons.cancel
                    : Icons.radio_button_unchecked,
                size: 20,
                color: c?.ink ?? paper.inkSoft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: Hand.sansText(context, size: 14.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
