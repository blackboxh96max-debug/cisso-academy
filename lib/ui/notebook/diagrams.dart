import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import 'hand_drawn.dart';
import 'palette.dart';
import 'typography.dart';

Tone _tone(Object? name, [Tone fallback = Tone.blue]) =>
    Tone.values.firstWhere((t) => t.name == name, orElse: () => fallback);

/// Schéma explicatif décrit dans le contenu JSON (`diagram.type`).
///
/// Types : `flow` (chaîne en flèches), `cycle` (processus circulaire),
/// `matrix` (matrice vraisemblance × impact), `bars` (comparaison chiffrée),
/// `quadrant` (grille 2 × 2).
class DiagramView extends StatelessWidget {
  const DiagramView({super.key, required this.data, required this.alt});

  final Map<String, dynamic> data;

  /// Description accessible (lecteurs d'écran).
  final String alt;

  @override
  Widget build(BuildContext context) {
    final Widget diagram = switch (data['type']) {
      'flow' => _FlowDiagram(data),
      'cycle' => _CycleDiagram(data),
      'matrix' => _MatrixDiagram(data),
      'bars' => _BarsDiagram(data),
      'quadrant' => _QuadrantDiagram(data),
      _ => const SizedBox.shrink(),
    };
    return Semantics(
      label: alt,
      image: true,
      child: ExcludeSemantics(child: diagram),
    );
  }
}

/// Nœud de schéma : pastille avec emoji et libellé.
class _Node {
  _Node(Map<String, dynamic> json)
    : emoji = json['emoji'] as String? ?? '',
      label = json['label'] as String,
      detail = json['detail'] as String?,
      tone = _tone(json['tone']);

  final String emoji;
  final String label;
  final String? detail;
  final Tone tone;
}

/// Fait apparaître ses enfants l'un après l'autre (si les animations sont actives).
class _Staggered extends StatefulWidget {
  const _Staggered({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_Staggered> createState() => _StaggeredState();
}

class _StaggeredState extends State<_Staggered> {
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!animationsOn(context)) {
      _visible = true;
    } else if (!_visible) {
      Future.delayed(Duration(milliseconds: 120 + widget.index * 160), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final animate = animationsOn(context);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: animate ? const Duration(milliseconds: 380) : Duration.zero,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.15),
        duration: animate ? const Duration(milliseconds: 380) : Duration.zero,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard(this.node, {this.seed = 1, this.width});

  final _Node node;
  final int seed;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(node.tone, Theme.of(context).brightness);
    return SizedBox(
      width: width,
      child: HandBox(
        fill: c.fill,
        stroke: c.ink,
        seed: seed,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (node.emoji.isNotEmpty)
              Text(node.emoji, style: const TextStyle(fontSize: 26)),
            // Un mot seul trop long est réduit plutôt que coupé en deux.
            _maybeFit(
              node.label,
              Text(
                node.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: Hand.tsize(23),
                  fontWeight: Hand.titleWeight,
                  height: 1.05,
                  color: c.ink,
                ),
              ),
            ),
            if (node.detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  node.detail!,
                  textAlign: TextAlign.center,
                  style: Hand.sansText(context, size: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Flèche manuscrite, horizontale ou verticale.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.vertical, this.seed = 2});

  final bool vertical;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final color = Paper.of(context).inkSoft;
    return SizedBox(
      width: vertical ? 30 : 34,
      height: vertical ? 30 : 34,
      child: CustomPaint(painter: _ArrowPainter(color, vertical, seed)),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.color, this.vertical, this.seed);

  final Color color;
  final bool vertical;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final a = vertical ? Offset(size.width / 2, 3) : Offset(3, size.height / 2);
    final b = vertical
        ? Offset(size.width / 2, size.height - 3)
        : Offset(size.width - 3, size.height / 2);
    drawHandArrow(canvas, a, b, paint, seed: seed);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}

class _FlowDiagram extends StatelessWidget {
  const _FlowDiagram(this.data);

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final nodes = (data['nodes'] as List)
        .map((n) => _Node(n as Map<String, dynamic>))
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= nodes.length * 150;
        final children = <Widget>[];
        for (var i = 0; i < nodes.length; i++) {
          final card = _Staggered(
            index: i,
            child: _NodeCard(
              nodes[i],
              seed: i + 11,
              width: horizontal ? null : 260,
            ),
          );
          children.add(horizontal ? Expanded(child: card) : card);
          if (i < nodes.length - 1) {
            children.add(_Arrow(vertical: !horizontal, seed: i));
          }
        }
        if (horizontal) return Row(children: children);
        return Column(children: children);
      },
    );
  }
}

class _CycleDiagram extends StatelessWidget {
  const _CycleDiagram(this.data);

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final nodes = (data['nodes'] as List)
        .map((n) => _Node(n as Map<String, dynamic>))
        .toList();
    final center = data['center'] as String?;
    final paper = Paper.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Écran étroit : le cercle serait illisible, on déroule le cycle
        // verticalement et on rappelle qu'il recommence.
        if (constraints.maxWidth < 440) {
          return Column(
            children: [
              if (center != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    center.replaceAll('\n', ' '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Hand.title,
                      fontSize: Hand.tsize(24),
                      fontWeight: Hand.titleWeight,
                      color: paper.ink,
                    ),
                  ),
                ),
              _FlowDiagram({'nodes': data['nodes']}),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '↻ puis on recommence au début',
                  style: Hand.noteText(context)
                      .copyWith(fontSize: Hand.bsize(17)),
                ),
              ),
            ],
          );
        }
        final size = min(constraints.maxWidth, 560.0);
        final nodeW = size < 360 ? 110.0 : 140.0;
        final radius = size / 2 - nodeW / 2 - 4;
        return Center(
          child: SizedBox(
            width: size,
            height: size + 40,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CyclePainter(
                      nodes.length,
                      radius,
                      paper.inkSoft,
                      nodeW,
                    ),
                  ),
                ),
                if (center != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 30,
                    height: size,
                    child: Center(
                      child: SizedBox(
                        width: size * 0.32,
                        child: Text(
                          center,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: Hand.title,
                            fontSize: Hand.tsize(26),
                            fontWeight: Hand.titleWeight,
                            color: paper.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                for (var i = 0; i < nodes.length; i++)
                  Builder(
                    builder: (context) {
                      final angle = -pi / 2 + i * 2 * pi / nodes.length;
                      final cx = size / 2 + radius * cos(angle);
                      final cy = size / 2 + radius * sin(angle);
                      return Positioned(
                        left: cx - nodeW / 2,
                        top: cy - 42,
                        width: nodeW,
                        child: _Staggered(
                          index: i,
                          child: _NodeCard(nodes[i], seed: 30 + i),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CyclePainter extends CustomPainter {
  _CyclePainter(this.count, this.radius, this.color, this.nodeW);

  final int count;
  final double radius;
  final Color color;
  final double nodeW;

  /// Les cartes sont posées 42 px au-dessus de leur point d'ancrage et
  /// mesurent environ 150 px de haut : leur centre visuel est donc plus bas.
  static const _dy = 30.0;
  static const _halfH = 74.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.width / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset center(int i) {
      final a = -pi / 2 + i * 2 * pi / count;
      return c + Offset(cos(a), sin(a)) * radius + const Offset(0, _dy);
    }

    // Point de sortie du rectangle d'une carte dans la direction [d].
    Offset edge(Offset p, Offset d) {
      final tx = d.dx.abs() < 1e-6 ? double.infinity : (nodeW / 2) / d.dx.abs();
      final ty = d.dy.abs() < 1e-6 ? double.infinity : _halfH / d.dy.abs();
      return p + d * (min(tx, ty) + 6);
    }

    for (var i = 0; i < count; i++) {
      final a = center(i);
      final b = center((i + 1) % count);
      final d = (b - a) / (b - a).distance;
      final from = edge(a, d);
      final to = edge(b, -d);
      if ((to - from).distance < 18) continue; // cartes trop proches
      // Projection vers l'extérieur pour un léger arrondi « au crayon ».
      final mid = Offset.lerp(from, to, 0.5)!;
      final out = mid - c;
      final bulge = out / out.distance * 10;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(mid.dx + bulge.dx, mid.dy + bulge.dy, to.dx, to.dy);
      canvas.drawPath(path, paint);
      final dir = (to - (mid + bulge));
      final ang = atan2(dir.dy, dir.dx);
      const head = 10.0;
      canvas.drawPath(
        Path()
          ..moveTo(
            to.dx - cos(ang - 0.45) * head,
            to.dy - sin(ang - 0.45) * head,
          )
          ..lineTo(to.dx, to.dy)
          ..lineTo(
            to.dx - cos(ang + 0.45) * head,
            to.dy - sin(ang + 0.45) * head,
          ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CyclePainter old) =>
      old.color != color || old.count != count || old.radius != radius;
}

class _MatrixDiagram extends StatelessWidget {
  const _MatrixDiagram(this.data);

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    const n = 5;
    final points = (data['points'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final brightness = Theme.of(context).brightness;
    final paper = Paper.of(context);
    Color cellColor(int x, int y) {
      final score = x * y; // 1..25
      final tone = score >= 15
          ? Tone.red
          : score >= 8
          ? Tone.orange
          : score >= 4
          ? Tone.yellow
          : Tone.green;
      return toneColors(tone, brightness).fill;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth - 40, 420.0);
        final cell = side / n;
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  '${data['yLabel'] ?? 'Vraisemblance'} →',
                  style: TextStyle(
                    fontFamily: Hand.title,
                    fontSize: Hand.tsize(22),
                    color: paper.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: side,
                    height: side,
                    child: Stack(
                      children: [
                        for (var y = 1; y <= n; y++)
                          for (var x = 1; x <= n; x++)
                            Positioned(
                              left: (x - 1) * cell,
                              top: (n - y) * cell,
                              width: cell,
                              height: cell,
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: cellColor(x, y),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        for (final (i, p) in points.indexed)
                          Positioned(
                            left: ((p['x'] as int) - 1) * cell + 4,
                            top: (n - (p['y'] as int)) * cell + 4,
                            width: cell - 8,
                            height: cell - 8,
                            child: _Staggered(
                              index: i,
                              child: Center(
                                child: Text(
                                  '${p['emoji'] ?? '●'}\n${p['label']}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: Hand.body,
                                    fontSize: Hand.bsize(cell < 64 ? 11 : 13),
                                    height: 1.1,
                                    color: paper.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data['xLabel'] ?? 'Impact'} →',
                    style: TextStyle(
                      fontFamily: Hand.title,
                      fontSize: Hand.tsize(22),
                      color: paper.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BarsDiagram extends StatelessWidget {
  const _BarsDiagram(this.data);

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final bars = (data['bars'] as List).cast<Map<String, dynamic>>();
    final unit = data['unit'] as String? ?? '';
    final brightness = Theme.of(context).brightness;
    final paper = Paper.of(context);
    final maxV = bars
        .map((b) => (b['value'] as num).toDouble())
        .fold<double>(0, max);
    String fmt(num v) {
      final s = v.round().toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
        buf.write(s[i]);
      }
      return '$buf$unit';
    }

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxV * 1.25,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: paper.rule, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => paper.card,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                fmt(rod.toY),
                TextStyle(
                  fontFamily: Hand.sans,
                  fontWeight: FontWeight.w700,
                  color: paper.ink,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, meta) => Text(
                  fmt((bars[v.toInt()]['value'] as num)),
                  style: TextStyle(
                    fontFamily: Hand.title,
                    fontSize: Hand.tsize(20),
                    fontWeight: Hand.titleWeight,
                    color: paper.ink,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 110,
                    child: Text(
                      bars[v.toInt()]['label'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Hand.sansText(context, size: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          barGroups: [
            for (final (i, b) in bars.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (b['value'] as num).toDouble(),
                    width: 38,
                    color: toneColors(
                      _tone(b['tone']),
                      brightness,
                    ).ink.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: animationsOn(context)
            ? const Duration(milliseconds: 600)
            : Duration.zero,
      ),
    );
  }
}

class _QuadrantDiagram extends StatelessWidget {
  const _QuadrantDiagram(this.data);

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final cells = (data['cells'] as List)
        .map((c) => _Node(c as Map<String, dynamic>))
        .toList();
    final paper = Paper.of(context);
    final label = TextStyle(
      fontFamily: Hand.title,
      fontSize: Hand.tsize(22),
      color: paper.ink,
    );
    Widget cell(int i) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: _Staggered(
          index: i,
          child: _NodeCard(cells[i], seed: 50 + i),
        ),
      ),
    );
    return Row(
      children: [
        RotatedBox(
          quarterTurns: 3,
          child: Text('${data['yLabel'] ?? 'Vraisemblance'} →', style: label),
        ),
        Expanded(
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [cell(0), cell(1)],
                ),
              ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [cell(2), cell(3)],
                ),
              ),
              Text('${data['xLabel'] ?? 'Impact'} →', style: label),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _maybeFit(String label, Widget text) =>
    label.contains(' ') ? text : FittedBox(fit: BoxFit.scaleDown, child: text);
