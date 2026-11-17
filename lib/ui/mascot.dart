import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import 'mascot_characters.dart';
import 'notebook/palette.dart';

export 'mascot_characters.dart'
    show MascotMood, MascotCharacter, mascotCharacters, mascotById;

/// La mascotte de l'assistant (Cybi par défaut, ou le personnage choisi),
/// entièrement dessinée en code (aucune image, aucune dépendance).
///
/// Elle apparaît en saluant, puis s'anime par petites séquences (respiration,
/// clignement) entre deux pauses. Si les animations sont coupées (réglage de
/// l'application ou du système), elle reste immobile dans la pose de son
/// humeur.
class Mascot extends StatefulWidget {
  const Mascot({
    super.key,
    required this.mood,
    this.size = 72,
    this.typing,
    this.character,
  });

  final MascotMood mood;
  final double size;

  /// Personnage à dessiner ; par défaut, celui choisi dans les réglages.
  final MascotCharacter? character;

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
    final character =
        widget.character ?? mascotById(AppScope.of(context).mascotId);
    return Semantics(
      label:
          '${character.name}, ${character.species} : '
          '${character.line(widget.mood)}',
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
                  character,
                  MascotPose(
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
            ),
          );
        },
      ),
    );
  }
}

/// Dessin d'un personnage : ombre, respiration, bras, corps, tête penchée et
/// petits effets (bulles de réflexion, « ? », étincelles).
class MascotPainter extends CustomPainter {
  MascotPainter(this.character, this.pose);

  final MascotCharacter character;
  final MascotPose pose;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / 100, size.height / 120);
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, size.height - 120 * s);
    canvas.scale(s);
    final k = MascotKit(pose);
    final mood = pose.mood;

    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(50, 116),
        width: 52 - pose.breath * 4,
        height: 6,
      ),
      k.fill(k.ink.withValues(alpha: 0.15)),
    );
    canvas.translate(0, -pose.breath * 2.2);

    character.paintBack(canvas, k);

    // Bras : le gauche au repos ; le droit salue, se lève pour montrer la
    // réponse, ou se porte au menton quand le personnage réfléchit.
    _arm(canvas, k, character.leftShoulder, 0.25, left: true);
    final thinking = mood == MascotMood.thinking;
    final raise = mood == MascotMood.answering ? pose.show * 2.0 : 0.0;
    if (!thinking) {
      _arm(canvas, k, character.rightShoulder, -0.25 - raise + pose.wave);
    }

    character.paintBody(canvas, k);

    final tilt =
        switch (mood) {
          MascotMood.listening => 0.10,
          MascotMood.puzzled => -0.16,
          _ => 0.0,
        } +
        pose.nod;
    final n = character.neck;
    canvas.save();
    canvas.translate(n.dx, n.dy);
    canvas.rotate(tilt);
    canvas.translate(-n.dx, -n.dy);
    character.paintHead(canvas, k);
    canvas.restore();
    // Main au menton pendant la réflexion, devant le corps.
    if (thinking) _arm(canvas, k, character.rightShoulder, 2.55);

    if (mood == MascotMood.thinking) {
      for (var j = 0; j < 3; j++) {
        final phase = (pose.think + j / 3) % 1;
        canvas.drawCircle(
          Offset(82 + j * 6.0, 24 - j * 7.0),
          2.2 + j * 1.3,
          k.fill(k.ink.withValues(alpha: 0.25 + 0.6 * sin(phase * pi))),
        );
      }
    }
    if (mood == MascotMood.puzzled) {
      final violet = toneColors(Tone.violet, pose.brightness);
      final tp = TextPainter(
        text: TextSpan(
          text: '?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: violet.ink.withValues(alpha: pose.show.clamp(0.0, 1.0)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(84, 0 + (1 - pose.show) * 6));
    }
    if (mood == MascotMood.answering) {
      final p = k.fill(
        const Color(0xFFF7C948).withValues(alpha: pose.show.clamp(0.0, 1.0)),
      );
      for (final o in const [Offset(92, 30), Offset(97, 42), Offset(86, 20)]) {
        _sparkle(canvas, o, 3.2 * pose.show, p);
      }
    }
    canvas.restore();
  }

  void _arm(
    Canvas canvas,
    MascotKit k,
    Offset shoulder,
    double angle, {
    bool left = false,
  }) {
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);
    k.rrect(
      canvas,
      Rect.fromLTWH(left ? -6 : -3, -4, 9, 24),
      4.5,
      character.sleeve(k),
    );
    final hand = Offset(left ? -1.5 : 1.5, 22);
    k.oval(canvas, hand, 10.4, 10.4, character.hand(k));
    if (!left) character.paintRightHandItem(canvas, k);
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
      old.character != character || old.pose != pose;
}
