import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'palette.dart';

/// Contour de rectangle arrondi « tracé au stylo » : légères irrégularités,
/// identiques d'un affichage à l'autre (graine fixe).
Path wobblyRect(
  Rect r, {
  double radius = 14,
  double wobble = 1.6,
  int seed = 7,
}) {
  final rng = Random(seed);
  double j() => (rng.nextDouble() - 0.5) * 2 * wobble;
  final path = Path();
  final rad = min(radius, min(r.width, r.height) / 2);
  final pts = <Offset>[];
  void edge(Offset a, Offset b) {
    final len = (b - a).distance;
    final n = max(2, (len / 40).round());
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final p = Offset.lerp(a, b, t)!;
      final normal = Offset(-(b - a).dy, (b - a).dx) / len;
      pts.add(p + normal * j());
    }
  }

  edge(Offset(r.left + rad, r.top), Offset(r.right - rad, r.top));
  pts.add(Offset(r.right - rad * 0.3, r.top + rad * 0.3));
  edge(Offset(r.right, r.top + rad), Offset(r.right, r.bottom - rad));
  pts.add(Offset(r.right - rad * 0.3, r.bottom - rad * 0.3));
  edge(Offset(r.right - rad, r.bottom), Offset(r.left + rad, r.bottom));
  pts.add(Offset(r.left + rad * 0.3, r.bottom - rad * 0.3));
  edge(Offset(r.left, r.bottom - rad), Offset(r.left, r.top + rad));
  pts.add(Offset(r.left + rad * 0.3, r.top + rad * 0.3));

  // Courbe lissée passant par les points (Catmull-Rom → Bézier).
  path.moveTo(pts.first.dx, pts.first.dy);
  for (var i = 0; i < pts.length; i++) {
    final p0 = pts[(i - 1 + pts.length) % pts.length];
    final p1 = pts[i];
    final p2 = pts[(i + 1) % pts.length];
    final p3 = pts[(i + 2) % pts.length];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  path.close();
  return path;
}

/// Trait légèrement ondulé entre deux points (flèches, soulignements).
Path wobblyLine(Offset a, Offset b, {double wobble = 1.2, int seed = 3}) {
  final rng = Random(seed);
  final len = (b - a).distance;
  final n = max(2, (len / 30).round());
  final normal = len == 0 ? Offset.zero : Offset(-(b - a).dy, (b - a).dx) / len;
  final path = Path()..moveTo(a.dx, a.dy);
  for (var i = 1; i <= n; i++) {
    final p = Offset.lerp(a, b, i / n)!;
    final off = i == n
        ? Offset.zero
        : normal * (rng.nextDouble() - 0.5) * 2 * wobble;
    final prev = Offset.lerp(a, b, (i - 0.5) / n)! + off;
    path.quadraticBezierTo(prev.dx, prev.dy, p.dx, p.dy);
  }
  return path;
}

/// Dessine une flèche manuscrite de [a] vers [b].
void drawHandArrow(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint, {
  int seed = 3,
}) {
  canvas.drawPath(wobblyLine(a, b, seed: seed), paint);
  final angle = atan2(b.dy - a.dy, b.dx - a.dx);
  const head = 10.0;
  final p1 = b - Offset(cos(angle - 0.45), sin(angle - 0.45)) * head;
  final p2 = b - Offset(cos(angle + 0.45), sin(angle + 0.45)) * head;
  canvas.drawPath(
    Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(p2.dx, p2.dy),
    paint,
  );
}

/// Encadré dessiné à la main : fond pastel, contour irrégulier, ombre légère.
class HandBox extends StatelessWidget {
  const HandBox({
    super.key,
    required this.child,
    this.fill,
    this.stroke,
    this.gradient,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
    this.seed = 7,
    this.strokeWidth = 1.8,
    this.shadow = true,
    this.radius = 16,
  });

  final Widget child;
  final Color? fill;
  final Color? stroke;

  /// Remplissage en dégradé (prioritaire sur [fill]).
  final Gradient? gradient;
  final EdgeInsets padding;
  final int seed;
  final double strokeWidth;
  final bool shadow;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    return CustomPaint(
      painter: _HandBoxPainter(
        fill: fill ?? paper.card,
        stroke: stroke ?? paper.inkSoft,
        gradient: gradient,
        seed: seed,
        strokeWidth: strokeWidth,
        shadow: shadow,
        radius: radius,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _HandBoxPainter extends CustomPainter {
  _HandBoxPainter({
    required this.fill,
    required this.stroke,
    required this.gradient,
    required this.seed,
    required this.strokeWidth,
    required this.shadow,
    required this.radius,
  });

  final Color fill;
  final Color stroke;
  final Gradient? gradient;
  final int seed;
  final double strokeWidth;
  final bool shadow;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = wobblyRect(rect.deflate(1.5), seed: seed, radius: radius);
    if (shadow) {
      canvas.drawPath(
        path.shift(const Offset(2, 3)),
        Paint()
          ..color = const Color(0x22000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    final fillPaint = Paint()..color = fill;
    if (gradient != null) fillPaint.shader = gradient!.createShader(rect);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HandBoxPainter old) =>
      old.fill != fill ||
      old.stroke != stroke ||
      old.seed != seed ||
      old.gradient != gradient;
}

/// Soulignement manuscrit sous un titre.
class HandUnderline extends StatelessWidget {
  const HandUnderline({
    super.key,
    required this.child,
    required this.color,
    this.seed = 5,
  });

  final Widget child;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _UnderlinePainter(color, seed),
      child: Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter(this.color, this.seed);

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 3;
    final w = min(size.width, 260.0);
    canvas.drawPath(
      wobblyLine(Offset(2, y), Offset(w, y - 2), wobble: 1.8, seed: seed),
      Paint()
        ..color = color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) => old.color != color;
}

/// Page de cahier : papier crème, lignes horizontales et marge rouge.
class NotebookPaper extends StatelessWidget {
  const NotebookPaper({super.key, required this.child, this.lines = true});

  final Widget child;
  final bool lines;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    return CustomPaint(painter: _PaperPainter(paper, lines), child: child);
  }
}

class _PaperPainter extends CustomPainter {
  _PaperPainter(this.paper, this.lines);

  final Paper paper;
  final bool lines;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper.page);
    if (!lines) return;
    final rule = Paint()
      ..color = paper.rule
      ..strokeWidth = 1;
    for (var y = 64.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final marginX = size.width < 600 ? 10.0 : 44.0;
    canvas.drawLine(
      Offset(marginX, 0),
      Offset(marginX, size.height),
      Paint()
        ..color = paper.margin
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.paper != paper || old.lines != lines;
}

/// Petite étiquette arrondie (type gommette).
class Sticker extends StatelessWidget {
  const Sticker({super.key, required this.text, required this.tone});

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.ink.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: c.ink,
        ),
      ),
    );
  }
}

/// Utilitaire pour dessiner du texte dans un CustomPainter.
TextPainter layoutText(
  String text,
  TextStyle style, {
  double maxWidth = double.infinity,
  TextAlign align = TextAlign.center,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: align,
    textDirection: ui.TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
}
