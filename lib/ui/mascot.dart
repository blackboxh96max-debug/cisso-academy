import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import 'notebook/palette.dart';

/// Humeur de la mascotte de l'assistant.
enum MascotMood {
  /// Attend la question : respire, cligne des yeux.
  idle,

  /// L'utilisateur tape : elle écoute, hoche la tête.
  listening,

  /// Recherche en cours : regarde en l'air, bulles de réflexion.
  thinking,

  /// Réponse trouvée : yeux rieurs, bras levé vers la réponse.
  answering,

  /// Rien trouvé : tête penchée, point d'interrogation.
  puzzled,
}

/// « Cybi », la mascotte de l'assistant : un petit robot au cadenas,
/// entièrement dessiné en code (aucune image, aucune dépendance).
///
/// Elle apparaît en saluant, puis s'anime par petites séquences (respiration,
/// clignement) entre deux pauses. Si les animations sont coupées (réglage de
/// l'application ou du système), elle reste immobile dans la pose de son
/// humeur.
class Mascot extends StatefulWidget {
  const Mascot({super.key, required this.mood, this.size = 72, this.typing});

  final MascotMood mood;
  final double size;

  /// Change à chaque frappe : la mascotte hoche la tête.
  final Object? typing;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  // Apparition et salut.
  late final _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  // Une respiration et un clignement, joués de temps en temps.
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  // Hochement de tête à la frappe.
  late final _nod = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  // Bulles de réflexion, tant qu'elle réfléchit.
  late final _think = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  // Présentation de la réponse.
  late final _show = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _next;
  final _random = Random();
  bool _animate = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = animationsOn(context);
    if (!_started) {
      _started = true;
      if (_animate) {
        _enter.forward().whenComplete(_scheduleIdle);
      } else {
        _enter.value = 1;
      }
    }
    _applyMood();
  }

  @override
  void didUpdateWidget(Mascot old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _applyMood();
    if (_animate && old.typing != widget.typing && widget.typing != null) {
      _nod.forward(from: 0);
    }
  }

  void _applyMood() {
    if (!_animate) {
      _think.stop();
      return;
    }
    if (widget.mood == MascotMood.thinking) {
      _think.repeat();
    } else {
      _think.stop();
      _think.value = 0;
    }
    if (widget.mood == MascotMood.answering ||
        widget.mood == MascotMood.puzzled) {
      _show.forward(from: 0);
    }
  }

  /// Prochaine respiration dans 2 à 4 s.
  void _scheduleIdle() {
    _next?.cancel();
    if (!mounted || !_animate) return;
    _next = Timer(Duration(milliseconds: 2000 + _random.nextInt(2000)), () {
      if (!mounted) return;
      _idle.forward(from: 0).whenComplete(_scheduleIdle);
    });
  }

  @override
  void dispose() {
    _next?.cancel();
    _enter.dispose();
    _idle.dispose();
    _nod.dispose();
    _think.dispose();
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Semantics(
      label: 'Cybi, la mascotte de l\'assistant : ${mascotLine(widget.mood)}',
      image: true,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _idle, _nod, _think, _show]),
        builder: (context, _) {
          final e = Curves.elasticOut.transform(
            (_enter.value / 0.55).clamp(0.0, 1.0),
          );
          // Salut : le bras droit oscille pendant la fin de l'apparition.
          final waveT = ((_enter.value - 0.3) / 0.7).clamp(0.0, 1.0);
          final wave = _enter.isAnimating || _enter.value < 1
              ? sin(waveT * pi * 4) * (1 - waveT) * 0.9
              : 0.0;
          final i = _idle.value;
          final breath = sin(i * pi);
          // Clignement au milieu de la respiration.
          final blink = i > 0.45 && i < 0.6 ? sin((i - 0.45) / 0.15 * pi) : 0.0;
          final nod = sin(_nod.value * pi) * 0.12;
          return SizedBox(
            width: widget.size,
            height: widget.size * 1.2,
            child: Transform.scale(
              scale: 0.3 + 0.7 * e,
              alignment: Alignment.bottomCenter,
              child: CustomPaint(
                painter: MascotPainter(
                  mood: widget.mood,
                  breath: breath,
                  blink: blink,
                  wave: wave,
                  nod: nod,
                  think: _think.value,
                  show: Curves.easeOutBack.transform(_show.value),
                  brightness: brightness,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ce que dit la mascotte selon son humeur.
String mascotLine(MascotMood mood) => switch (mood) {
  MascotMood.idle => 'Pose-moi ta question, je t\'attends !',
  MascotMood.listening => 'Je t\'écoute…',
  MascotMood.thinking => 'Je cherche dans le cours…',
  MascotMood.answering => 'Voilà ce que j\'ai trouvé !',
  MascotMood.puzzled => 'Hmm, essaie avec d\'autres mots ?',
};

/// Dessin du robot, dans un repère de 100 × 120.
class MascotPainter extends CustomPainter {
  MascotPainter({
    required this.mood,
    required this.brightness,
    this.breath = 0,
    this.blink = 0,
    this.wave = 0,
    this.nod = 0,
    this.think = 0,
    this.show = 0,
  });

  final MascotMood mood;
  final Brightness brightness;

  /// 0 → 1 → 0 : le corps se soulève légèrement.
  final double breath;

  /// 0 (ouverts) → 1 (fermés).
  final double blink;

  /// Angle du salut (radians, autour de 0).
  final double wave;

  /// Inclinaison de la tête à la frappe.
  final double nod;

  /// Phase des bulles de réflexion (0 → 1, en boucle).
  final double think;

  /// 0 → 1 : bras levé vers la réponse.
  final double show;

  @override
  void paint(Canvas canvas, Size size) {
    final k = min(size.width / 100, size.height / 120);
    canvas.save();
    canvas.translate((size.width - 100 * k) / 2, size.height - 120 * k);
    canvas.scale(k);

    final dark = brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFE6E9F5) : const Color(0xFF26324A);
    final violet = toneColors(Tone.violet, brightness);
    final shell = dark ? const Color(0xFF3A3360) : const Color(0xFFEDE7FF);
    final screen = dark ? const Color(0xFF0E1A33) : const Color(0xFF1D2B4F);
    const glow = Color(0xFF5BE3F0);
    const gold = Color(0xFFF7C948);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint fill(Color c) => Paint()..color = c;

    // Ombre au sol.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(50, 116),
        width: 52 - breath * 4,
        height: 6,
      ),
      fill(ink.withValues(alpha: 0.15)),
    );

    final lift = -breath * 2.2;
    canvas.translate(0, lift);

    // Pieds.
    for (final x in [38.0, 62.0]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 110), width: 16, height: 8),
        const Radius.circular(4),
      );
      canvas.drawRRect(r, fill(violet.ink));
      canvas.drawRRect(r, line);
    }

    // Bras gauche (au repos, ou sur la hanche quand il réfléchit).
    final leftAngle = mood == MascotMood.thinking ? -0.9 : 0.25;
    _arm(
      canvas,
      const Offset(27, 74),
      leftAngle,
      line,
      fill(shell),
      left: true,
    );

    // Bras droit : salut, réponse (levé) ou repos.
    final restRight = mood == MascotMood.thinking ? -2.3 : -0.25;
    final raise = mood == MascotMood.answering ? show * 2.0 : 0.0;
    final rightAngle = restRight - raise + wave;
    _arm(canvas, const Offset(73, 74), rightAngle, line, fill(shell));

    // Corps : un écusson arrondi.
    final body = Path()
      ..moveTo(28, 66)
      ..quadraticBezierTo(50, 60, 72, 66)
      ..lineTo(72, 92)
      ..quadraticBezierTo(72, 106, 50, 108)
      ..quadraticBezierTo(28, 106, 28, 92)
      ..close();
    canvas.drawPath(body, fill(violet.fill));
    canvas.drawPath(body, line);

    // Cadenas sur la poitrine.
    final shackle = Path()
      ..moveTo(44, 84)
      ..lineTo(44, 79)
      ..arcToPoint(const Offset(56, 79), radius: const Radius.circular(6))
      ..lineTo(56, 84);
    canvas.drawPath(shackle, line..strokeWidth = 2.4);
    final lockBody = RRect.fromRectAndRadius(
      const Rect.fromLTWH(40, 83, 20, 15),
      const Radius.circular(3),
    );
    canvas.drawRRect(lockBody, fill(gold));
    canvas.drawRRect(lockBody, line);
    canvas.drawCircle(const Offset(50, 89), 1.8, fill(ink));
    canvas.drawLine(
      const Offset(50, 90),
      const Offset(50, 94),
      line..strokeWidth = 2,
    );
    line.strokeWidth = 2.6;

    // Tête (penchée selon l'humeur et la frappe).
    final tilt =
        switch (mood) {
          MascotMood.listening => 0.10,
          MascotMood.puzzled => -0.16,
          _ => 0.0,
        } +
        nod;
    canvas.save();
    canvas.translate(50, 62);
    canvas.rotate(tilt);
    canvas.translate(-50, -62);

    // Antenne : la boule brille quand il réfléchit ou écoute.
    canvas.drawLine(const Offset(50, 24), const Offset(50, 13), line);
    final bright = switch (mood) {
      MascotMood.thinking => 0.5 + 0.5 * sin(think * 2 * pi),
      MascotMood.listening => 0.8,
      MascotMood.answering => 1.0,
      _ => 0.35 + 0.4 * breath,
    };
    canvas.drawCircle(
      const Offset(50, 10),
      7,
      fill(glow.withValues(alpha: 0.25 * bright)),
    );
    canvas.drawCircle(
      const Offset(50, 10),
      4.2,
      fill(Color.lerp(gold, glow, bright)!),
    );
    canvas.drawCircle(const Offset(50, 10), 4.2, line);

    // Oreilles.
    for (final x in [17.0, 83.0]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 44), width: 7, height: 14),
        const Radius.circular(3),
      );
      canvas.drawRRect(r, fill(violet.ink));
      canvas.drawRRect(r, line);
    }

    final head = RRect.fromRectAndRadius(
      const Rect.fromLTWH(20, 24, 60, 40),
      const Radius.circular(14),
    );
    canvas.drawRRect(head, fill(shell));
    canvas.drawRRect(head, line);
    final face = RRect.fromRectAndRadius(
      const Rect.fromLTWH(27, 30, 46, 28),
      const Radius.circular(10),
    );
    canvas.drawRRect(face, fill(screen));

    _eyes(canvas, glow);
    _mouth(canvas, glow);

    // Joues.
    for (final x in [32.0, 68.0]) {
      canvas.drawCircle(
        Offset(x, 51),
        3,
        fill(const Color(0xFFFF8FB1).withValues(alpha: 0.55)),
      );
    }
    canvas.restore();

    // Bulles de réflexion ou point d'interrogation.
    if (mood == MascotMood.thinking) {
      for (var j = 0; j < 3; j++) {
        final phase = (think + j / 3) % 1;
        final r = 2.2 + j * 1.3;
        canvas.drawCircle(
          Offset(80 + j * 6.0, 26 - j * 7.0),
          r,
          fill(ink.withValues(alpha: 0.25 + 0.6 * sin(phase * pi))),
        );
      }
    }
    if (mood == MascotMood.puzzled) {
      final tp = TextPainter(
        text: TextSpan(
          text: '?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: violet.ink.withValues(alpha: show),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(82, 2 + (1 - show) * 6));
    }
    if (mood == MascotMood.answering) {
      // Petites étincelles autour de la main levée.
      final p = fill(gold.withValues(alpha: show));
      for (final o in const [Offset(90, 30), Offset(96, 42), Offset(84, 22)]) {
        _sparkle(canvas, o, 3.2 * show, p);
      }
    }
    canvas.restore();
  }

  void _eyes(Canvas canvas, Color glow) {
    final eye = Paint()
      ..color = glow
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Où regarde-t-il ?
    final look = switch (mood) {
      MascotMood.thinking => const Offset(2.5, -3),
      MascotMood.listening => const Offset(0, 2.5),
      _ => Offset.zero,
    };
    for (final x in [40.0, 60.0]) {
      final c = Offset(x, 43) + look;
      if (mood == MascotMood.answering) {
        // Yeux rieurs : deux arcs.
        canvas.drawArc(
          Rect.fromCenter(center: c + const Offset(0, 2), width: 9, height: 8),
          pi,
          pi,
          false,
          eye,
        );
        continue;
      }
      final h = 8 * (1 - blink);
      if (h < 1.2) {
        canvas.drawLine(c - const Offset(4, 0), c + const Offset(4, 0), eye);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 7, height: h),
            const Radius.circular(3.5),
          ),
          Paint()..color = glow,
        );
      }
    }
    if (mood == MascotMood.puzzled) {
      canvas.drawLine(const Offset(55, 35), const Offset(64, 33), eye);
    }
  }

  void _mouth(Canvas canvas, Color glow) {
    final m = Paint()
      ..color = glow
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (mood) {
      case MascotMood.thinking:
        canvas.drawCircle(const Offset(52, 52), 2.2, m);
      case MascotMood.puzzled:
        canvas.drawLine(const Offset(45, 53), const Offset(55, 51), m);
      case MascotMood.answering:
        final p = Path()
          ..moveTo(43, 50)
          ..quadraticBezierTo(50, 57, 57, 50)
          ..close();
        canvas.drawPath(p, Paint()..color = glow);
      case MascotMood.idle || MascotMood.listening:
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(50, 49), width: 12, height: 7),
          0.2,
          pi - 0.4,
          false,
          m,
        );
    }
  }

  /// Un bras : segment arrondi qui pivote à l'épaule, avec une main ronde.
  void _arm(
    Canvas canvas,
    Offset shoulder,
    double angle,
    Paint line,
    Paint fill, {
    bool left = false,
  }) {
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);
    final dir = left ? -1.0 : 1.0;
    final arm = RRect.fromRectAndRadius(
      Rect.fromLTWH(left ? -6 : -3, -4, 9, 24),
      const Radius.circular(4.5),
    );
    canvas.drawRRect(arm, fill);
    canvas.drawRRect(arm, line);
    final hand = Offset(dir * 0.5 + (left ? -1.5 : 1.5), 22);
    canvas.drawCircle(hand, 5.2, fill);
    canvas.drawCircle(hand, 5.2, line);
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset c, double r, Paint p) {
    if (r <= 0.1) return;
    final path = Path()
      ..moveTo(c.dx, c.dy - r * 1.6)
      ..lineTo(c.dx + r * 0.4, c.dy - r * 0.4)
      ..lineTo(c.dx + r * 1.6, c.dy)
      ..lineTo(c.dx + r * 0.4, c.dy + r * 0.4)
      ..lineTo(c.dx, c.dy + r * 1.6)
      ..lineTo(c.dx - r * 0.4, c.dy + r * 0.4)
      ..lineTo(c.dx - r * 1.6, c.dy)
      ..lineTo(c.dx - r * 0.4, c.dy - r * 0.4)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(MascotPainter old) =>
      old.mood != mood ||
      old.breath != breath ||
      old.blink != blink ||
      old.wave != wave ||
      old.nod != nod ||
      old.think != think ||
      old.show != show ||
      old.brightness != brightness;
}
