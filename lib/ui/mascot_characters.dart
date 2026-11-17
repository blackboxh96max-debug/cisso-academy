import 'dart:math';

import 'package:material_ui/material_ui.dart';

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

/// Position du corps à un instant donné (calculée par le widget animé).
class MascotPose {
  const MascotPose({
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

  /// 0 (yeux ouverts) → 1 (fermés).
  final double blink;

  /// Angle du salut (radians, autour de 0).
  final double wave;

  /// Inclinaison de la tête à la frappe.
  final double nod;

  /// Phase des bulles de réflexion (0 → 1, en boucle).
  final double think;

  /// 0 → 1 : présentation de la réponse.
  final double show;

  bool get dark => brightness == Brightness.dark;

  @override
  bool operator ==(Object other) =>
      other is MascotPose &&
      other.mood == mood &&
      other.brightness == brightness &&
      other.breath == breath &&
      other.blink == blink &&
      other.wave == wave &&
      other.nod == nod &&
      other.think == think &&
      other.show == show;

  @override
  int get hashCode =>
      Object.hash(mood, brightness, breath, blink, wave, nod, think, show);
}

/// Outils de dessin partagés : trait, remplissage, yeux, bouche, bras.
class MascotKit {
  MascotKit(this.pose)
    : ink = pose.dark ? const Color(0xFFE6E9F5) : const Color(0xFF26324A);

  final MascotPose pose;
  final Color ink;

  Paint get line => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint fill(Color c) => Paint()..color = c;

  /// Remplit puis entoure un chemin.
  void shape(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, fill(color));
    canvas.drawPath(path, line);
  }

  void oval(Canvas canvas, Offset c, double w, double h, Color color) => shape(
    canvas,
    Path()..addOval(Rect.fromCenter(center: c, width: w, height: h)),
    color,
  );

  void rrect(Canvas canvas, Rect r, double radius, Color color) => shape(
    canvas,
    Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))),
    color,
  );

  /// Où regardent les yeux selon l'humeur.
  Offset get look => switch (pose.mood) {
    MascotMood.thinking => const Offset(2.2, -2.6),
    MascotMood.listening => const Offset(0, 2.2),
    _ => Offset.zero,
  };

  /// Yeux en points (avec reflet), rieurs, fermés ou perplexes.
  void dotEyes(
    Canvas canvas,
    List<Offset> centers, {
    Color? color,
    double size = 1,
    bool whites = false,
  }) {
    final c = color ?? ink;
    final stroke = Paint()
      ..color = c
      ..strokeWidth = 2.6 * size
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final o in centers) {
      if (whites) {
        canvas.drawOval(
          Rect.fromCenter(center: o, width: 11 * size, height: 12 * size),
          fill(Colors.white),
        );
      }
      final p = o + look * size;
      if (pose.mood == MascotMood.answering) {
        canvas.drawArc(
          Rect.fromCenter(
            center: o + Offset(0, 2 * size),
            width: 8 * size,
            height: 7 * size,
          ),
          pi,
          pi,
          false,
          stroke,
        );
        continue;
      }
      final h = 7.5 * size * (1 - pose.blink);
      if (h < 1.2) {
        canvas.drawLine(
          p - Offset(3.5 * size, 0),
          p + Offset(3.5 * size, 0),
          stroke,
        );
        continue;
      }
      canvas.drawOval(
        Rect.fromCenter(center: p, width: 6 * size, height: h),
        fill(c),
      );
      canvas.drawCircle(
        p + Offset(1.2 * size, -1.6 * size),
        1.2 * size,
        fill(Colors.white.withValues(alpha: 0.9)),
      );
    }
    if (pose.mood == MascotMood.puzzled && centers.length == 2) {
      final r = centers[1];
      canvas.drawLine(
        r + Offset(-5 * size, -8 * size),
        r + Offset(4 * size, -10 * size),
        stroke,
      );
    }
  }

  /// Bouche selon l'humeur.
  void mouth(Canvas canvas, Offset c, {Color? color, double size = 1}) {
    final col = color ?? ink;
    final m = Paint()
      ..color = col
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (pose.mood) {
      case MascotMood.thinking:
        canvas.drawCircle(c + Offset(2 * size, 1), 2 * size, m);
      case MascotMood.puzzled:
        canvas.drawLine(c + Offset(-5 * size, 2), c + Offset(5 * size, 0), m);
      case MascotMood.answering:
        final p = Path()
          ..moveTo(c.dx - 7 * size, c.dy)
          ..quadraticBezierTo(c.dx, c.dy + 8 * size, c.dx + 7 * size, c.dy)
          ..close();
        canvas.drawPath(p, fill(col));
      case MascotMood.idle || MascotMood.listening:
        canvas.drawArc(
          Rect.fromCenter(center: c, width: 12 * size, height: 7 * size),
          0.2,
          pi - 0.4,
          false,
          m,
        );
    }
  }

  /// Joues roses.
  void cheeks(Canvas canvas, List<Offset> at, {double r = 3}) {
    for (final o in at) {
      canvas.drawCircle(
        o,
        r,
        fill(const Color(0xFFFF8FB1).withValues(alpha: 0.55)),
      );
    }
  }
}

/// Un personnage : son nom, sa personnalité, ses répliques et son dessin
/// dans un repère de 100 × 120 (pieds en bas, tête en haut).
abstract class MascotCharacter {
  const MascotCharacter();

  String get id;
  String get name;

  /// « le petit robot au cadenas »…
  String get species;

  /// Une phrase de personnalité, affichée dans la liste.
  String get personality;

  /// Ce que dit le personnage selon son humeur.
  String line(MascotMood mood);

  /// Épaules (gauche, droite) : point de rotation des bras.
  Offset get leftShoulder => const Offset(28, 74);
  Offset get rightShoulder => const Offset(72, 74);

  /// Pivot de la tête quand elle penche.
  Offset get neck => const Offset(50, 62);

  Color sleeve(MascotKit k);
  Color hand(MascotKit k);

  /// Ce qui est derrière le corps (queue…).
  void paintBack(Canvas canvas, MascotKit k) {}

  /// Corps et pieds.
  void paintBody(Canvas canvas, MascotKit k);

  /// Tête et visage (penchés selon l'humeur).
  void paintHead(Canvas canvas, MascotKit k);

  /// Objet tenu dans la main droite, dans le repère du bras (main en
  /// (1.5, 22)).
  void paintRightHandItem(Canvas canvas, MascotKit k) {}
}

/// Tous les personnages proposés, Cybi en premier.
const mascotCharacters = <MascotCharacter>[
  _Cybi(),
  _Max(),
  _Ada(),
  _Brik(),
  _Kee(),
  _Trace(),
];

/// Le personnage d'identifiant [id], ou Cybi.
MascotCharacter mascotById(String? id) => mascotCharacters.firstWhere(
  (c) => c.id == id,
  orElse: () => mascotCharacters.first,
);

// ---------------------------------------------------------------------------

class _Cybi extends MascotCharacter {
  const _Cybi();

  @override
  String get id => 'cybi';
  @override
  String get name => 'Cybi';
  @override
  String get species => 'le petit robot au cadenas';
  @override
  String get personality =>
      'Enthousiaste et serviable, il protège ses réponses sous clé.';

  @override
  String line(MascotMood mood) => switch (mood) {
    MascotMood.idle => 'Pose-moi ta question, je t\'attends !',
    MascotMood.listening => 'Je t\'écoute…',
    MascotMood.thinking => 'Je cherche dans le cours…',
    MascotMood.answering => 'Voilà ce que j\'ai trouvé !',
    MascotMood.puzzled => 'Hmm, essaie avec d\'autres mots ?',
  };

  Color _shell(MascotKit k) =>
      k.pose.dark ? const Color(0xFF3A3360) : const Color(0xFFEDE7FF);

  @override
  Color sleeve(MascotKit k) => _shell(k);
  @override
  Color hand(MascotKit k) => _shell(k);

  @override
  void paintBody(Canvas canvas, MascotKit k) {
    final violet = toneColors(Tone.violet, k.pose.brightness);
    for (final x in [38.0, 62.0]) {
      k.rrect(
        canvas,
        Rect.fromCenter(center: Offset(x, 110), width: 16, height: 8),
        4,
        violet.ink,
      );
    }
    final body = Path()
      ..moveTo(28, 66)
      ..quadraticBezierTo(50, 60, 72, 66)
      ..lineTo(72, 92)
      ..quadraticBezierTo(72, 106, 50, 108)
      ..quadraticBezierTo(28, 106, 28, 92)
      ..close();
    k.shape(canvas, body, violet.fill);
    _padlock(canvas, k, const Offset(50, 90));
  }

  @override
  void paintHead(Canvas canvas, MascotKit k) {
    final violet = toneColors(Tone.violet, k.pose.brightness);
    const glow = Color(0xFF5BE3F0);
    const gold = Color(0xFFF7C948);
    canvas.drawLine(const Offset(50, 24), const Offset(50, 13), k.line);
    final bright = switch (k.pose.mood) {
      MascotMood.thinking => 0.5 + 0.5 * sin(k.pose.think * 2 * pi),
      MascotMood.listening => 0.8,
      MascotMood.answering => 1.0,
      _ => 0.35 + 0.4 * k.pose.breath,
    };
    canvas.drawCircle(
      const Offset(50, 10),
      7,
      k.fill(glow.withValues(alpha: 0.25 * bright)),
    );
    k.oval(
      canvas,
      const Offset(50, 10),
      8.4,
      8.4,
      Color.lerp(gold, glow, bright)!,
    );
    for (final x in [17.0, 83.0]) {
      k.rrect(
        canvas,
        Rect.fromCenter(center: Offset(x, 44), width: 7, height: 14),
        3,
        violet.ink,
      );
    }
    k.rrect(canvas, const Rect.fromLTWH(20, 24, 60, 40), 14, _shell(k));
    final screen = k.pose.dark
        ? const Color(0xFF0E1A33)
        : const Color(0xFF1D2B4F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 30, 46, 28),
        const Radius.circular(10),
      ),
      k.fill(screen),
    );
    _screenEyes(canvas, k, glow);
    k.mouth(canvas, const Offset(50, 50), color: glow);
    k.cheeks(canvas, const [Offset(32, 51), Offset(68, 51)]);
  }

  void _screenEyes(Canvas canvas, MascotKit k, Color glow) {
    final eye = Paint()
      ..color = glow
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final x in [40.0, 60.0]) {
      final c = Offset(x, 43) + k.look;
      if (k.pose.mood == MascotMood.answering) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, 45), width: 9, height: 8),
          pi,
          pi,
          false,
          eye,
        );
        continue;
      }
      final h = 8 * (1 - k.pose.blink);
      if (h < 1.2) {
        canvas.drawLine(c - const Offset(4, 0), c + const Offset(4, 0), eye);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 7, height: h),
            const Radius.circular(3.5),
          ),
          k.fill(glow),
        );
      }
    }
    if (k.pose.mood == MascotMood.puzzled) {
      canvas.drawLine(const Offset(55, 35), const Offset(64, 33), eye);
    }
  }
}

void _padlock(Canvas canvas, MascotKit k, Offset c) {
  final shackle = Path()
    ..moveTo(c.dx - 6, c.dy - 6)
    ..lineTo(c.dx - 6, c.dy - 11)
    ..arcToPoint(Offset(c.dx + 6, c.dy - 11), radius: const Radius.circular(6))
    ..lineTo(c.dx + 6, c.dy - 6);
  canvas.drawPath(shackle, k.line..strokeWidth = 2.4);
  k.rrect(
    canvas,
    Rect.fromLTWH(c.dx - 10, c.dy - 7, 20, 15),
    3,
    const Color(0xFFF7C948),
  );
  canvas.drawCircle(c + const Offset(0, -1), 1.8, k.fill(k.ink));
  canvas.drawLine(c, c + const Offset(0, 4), k.line..strokeWidth = 2);
}

// ---------------------------------------------------------------------------

class _Max extends MascotCharacter {
  const _Max();

  @override
  String get id => 'max';
  @override
  String get name => 'Max';
  @override
  String get species => 'le hacker éthique au chapeau blanc';
  @override
  String get personality =>
      'Il teste les défenses avec autorisation, pour les rendre plus solides.';

  @override
  String line(MascotMood mood) => switch (mood) {
    MascotMood.idle => 'Chapeau blanc, mission autorisée. Ta question ?',
    MascotMood.listening => 'Je prends note du périmètre…',
    MascotMood.thinking => 'Je teste toutes les pistes…',
    MascotMood.answering => 'Accès obtenu : voici la réponse !',
    MascotMood.puzzled => 'Rien trouvé. On change de vecteur ?',
  };

  static const _skin = Color(0xFFF1C6A3);
  static const _hat = Color(0xFFFAFAF7);
  Color _hoodie(MascotKit k) =>
      k.pose.dark ? const Color(0xFF55657E) : const Color(0xFF3E4A5C);

  @override
  Color sleeve(MascotKit k) => _hoodie(k);
  @override
  Color hand(MascotKit k) => _skin;

  @override
  void paintBody(Canvas canvas, MascotKit k) {
    for (final x in [40.0, 60.0]) {
      k.rrect(
        canvas,
        Rect.fromCenter(center: Offset(x, 110), width: 15, height: 8),
        4,
        const Color(0xFF26324A),
      );
    }
    k.oval(canvas, const Offset(50, 66), 34, 12, _hoodie(k));
    k.rrect(canvas, const Rect.fromLTWH(30, 64, 40, 44), 14, _hoodie(k));
    // « </> » sur le sweat.
    final code = Paint()
      ..color = const Color(0xFF59E39A)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(43, 82)
        ..lineTo(39, 87)
        ..lineTo(43, 92),
      code,
    );
    canvas.drawPath(
      Path()
        ..moveTo(57, 82)
        ..lineTo(61, 87)
        ..lineTo(57, 92),
      code,
    );
    canvas.drawLine(const Offset(52, 81), const Offset(48, 93), code);
  }

  @override
  void paintHead(Canvas canvas, MascotKit k) {
    k.oval(canvas, const Offset(50, 46), 44, 40, _skin);
    // Cheveux sur les côtés.
    for (final s in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(50 + s * 22, 36)
          ..quadraticBezierTo(50 + s * 23, 46, 50 + s * 20, 50)
          ..lineTo(50 + s * 17, 38)
          ..close(),
        k.fill(const Color(0xFF5A3B2A)),
      );
    }
    k.dotEyes(canvas, const [Offset(41, 46), Offset(59, 46)]);
    k.mouth(canvas, const Offset(50, 56), size: 0.85);
    k.cheeks(canvas, const [Offset(35, 53), Offset(65, 53)], r: 2.6);
    // Chapeau blanc (fédora) avec ruban noir.
    k.oval(canvas, const Offset(50, 31), 66, 11, _hat);
    k.shape(
      canvas,
      Path()
        ..moveTo(32, 31)
        ..quadraticBezierTo(31, 12, 42, 11)
        ..quadraticBezierTo(50, 15, 58, 11)
        ..quadraticBezierTo(69, 12, 68, 31)
        ..close(),
      _hat,
    );
    canvas.drawRect(
      const Rect.fromLTWH(32.5, 24, 35, 5),
      k.fill(const Color(0xFF26324A)),
    );
  }
}

// ---------------------------------------------------------------------------

class _Brik extends MascotCharacter {
  const _Brik();

  @override
  String get id => 'brik';
  @override
  String get name => 'Brik';
  @override
  String get species => 'le pare-feu en briques';
  @override
  String get personality =>
      'Strict mais juste : refus par défaut, sauf pour les bonnes questions.';

  @override
  String line(MascotMood mood) => switch (mood) {
    MascotMood.idle => 'Règle n° 1 : ta question est autorisée !',
    MascotMood.listening => 'J\'inspecte le paquet…',
    MascotMood.thinking => 'Je filtre le cours…',
    MascotMood.answering => 'ALLOW : la réponse passe !',
    MascotMood.puzzled => 'DENY… aucune règle ne correspond. Reformule ?',
  };

  static const _brick = Color(0xFFD9573B);
  static const _mortar = Color(0xFFF3E3C8);
  static const _flame = Color(0xFFFFB13B);

  @override
  Color sleeve(MascotKit k) => _brick;
  @override
  Color hand(MascotKit k) => _mortar;

  @override
  Offset get leftShoulder => const Offset(26, 66);
  @override
  Offset get rightShoulder => const Offset(74, 66);
  @override
  Offset get neck => const Offset(50, 90);

  @override
  void paintBody(Canvas canvas, MascotKit k) {
    final legs = k.line..strokeWidth = 3.4;
    canvas.drawLine(const Offset(42, 100), const Offset(41, 108), legs);
    canvas.drawLine(const Offset(58, 100), const Offset(59, 108), legs);
    for (final x in [39.0, 61.0]) {
      k.rrect(
        canvas,
        Rect.fromCenter(center: Offset(x, 110), width: 14, height: 7),
        3.5,
        const Color(0xFF7A3A2A),
      );
    }
  }

  @override
  void paintHead(Canvas canvas, MascotKit k) {
    // Petite flamme qui danse au-dessus du mur.
    final f = 1 + 0.15 * k.pose.breath + 0.2 * sin(k.pose.think * 2 * pi);
    k.shape(
      canvas,
      Path()
        ..moveTo(42, 28)
        ..quadraticBezierTo(40, 18, 47, 12)
        ..quadraticBezierTo(47, 18, 50, 20)
        ..quadraticBezierTo(52, 10 - 4 * (f - 1), 57, 6 - 6 * (f - 1))
        ..quadraticBezierTo(62, 18, 58, 28)
        ..close(),
      _flame,
    );
    // Mur.
    const wall = Rect.fromLTWH(24, 26, 52, 76);
    k.rrect(canvas, wall, 6, _mortar);
    final rows = 6;
    final rowH = wall.height / rows;
    for (var r = 0; r < rows; r++) {
      final y = wall.top + r * rowH;
      final offset = r.isOdd ? -8.0 : 0.0;
      for (var x = wall.left + offset; x < wall.right; x += 17) {
        final left = max(x + 1.5, wall.left + 2);
        final right = min(x + 15.5, wall.right - 2);
        if (right - left < 3) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left, y + 1.6, right, y + rowH - 1.6),
            const Radius.circular(2),
          ),
          k.fill(_brick),
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(wall, const Radius.circular(6)),
      k.line,
    );
    // Visage sur un panneau clair.
    k.rrect(canvas, const Rect.fromLTWH(31, 36, 38, 30), 9, _mortar);
    k.dotEyes(canvas, const [Offset(42, 47), Offset(58, 47)]);
    k.mouth(canvas, const Offset(50, 57), size: 0.9);
    k.cheeks(canvas, const [Offset(36, 55), Offset(64, 55)], r: 2.6);
  }
}

// ---------------------------------------------------------------------------

class _Kee extends MascotCharacter {
  const _Kee();

  @override
  String get id => 'kee';
  @override
  String get name => 'Kee';
  @override
  String get species => 'la clé de chiffrement';
  @override
  String get personality =>
      'Discrète et précise, elle ne s\'ouvre qu\'aux bonnes questions.';

  @override
  String line(MascotMood mood) => switch (mood) {
    MascotMood.idle => 'Clé prête. Que veux-tu déchiffrer ?',
    MascotMood.listening => 'Je reçois le message chiffré…',
    MascotMood.thinking => 'Déchiffrement en cours…',
    MascotMood.answering => 'Déchiffré : voici la réponse !',
    MascotMood.puzzled => 'Mauvaise clé… essaie d\'autres mots ?',
  };

  static const _gold = Color(0xFFF2C14E);
  static const _goldDark = Color(0xFFC9962A);

  @override
  Color sleeve(MascotKit k) => _goldDark;
  @override
  Color hand(MascotKit k) => _gold;

  @override
  Offset get leftShoulder => const Offset(40, 76);
  @override
  Offset get rightShoulder => const Offset(60, 76);

  @override
  void paintBody(Canvas canvas, MascotKit k) {
    for (final x in [42.0, 58.0]) {
      k.rrect(
        canvas,
        Rect.fromCenter(center: Offset(x, 110), width: 13, height: 7),
        3.5,
        _goldDark,
      );
    }
    // Tige et dents de la clé.
    k.shape(
      canvas,
      Path()
        ..moveTo(43, 64)
        ..lineTo(57, 64)
        ..lineTo(57, 84)
        ..lineTo(66, 84)
        ..lineTo(66, 90)
        ..lineTo(60, 90)
        ..lineTo(60, 95)
        ..lineTo(66, 95)
        ..lineTo(66, 101)
        ..lineTo(57, 101)
        ..lineTo(57, 106)
        ..lineTo(43, 106)
        ..close(),
      _gold,
    );
  }

  @override
  void paintHead(Canvas canvas, MascotKit k) {
    // Anneau de la clé, avec son trou.
    k.oval(canvas, const Offset(50, 42), 56, 46, _gold);
    k.oval(
      canvas,
      const Offset(50, 24.5),
      9,
      7,
      k.pose.dark ? const Color(0xFF1F2433) : const Color(0xFFF3EDE0),
    );
    // Motif binaire discret.
    final tp = TextPainter(
      text: const TextSpan(
        text: '1010',
        style: TextStyle(
          fontSize: 6,
          color: _goldDark,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(44, 58));
    k.dotEyes(canvas, const [Offset(41, 41), Offset(59, 41)]);
    k.mouth(canvas, const Offset(50, 51), size: 0.85);
    k.cheeks(canvas, const [Offset(34, 49), Offset(66, 49)], r: 2.6);
  }
}

// ---------------------------------------------------------------------------

class _Ada extends MascotCharacter {
  const _Ada();

  @override
  String get id => 'ada';
  @override
  String get name => 'Ada';
  @override
  String get species => 'l\'analyste SOC au casque';
  @override
  String get personality =>
      'Vive et méthodique, elle connaît les sigles par cœur, en français comme en anglais.';

  @override
  String line(MascotMood mood) => switch (mood) {
    MascotMood.idle => 'Salut ! Prête quand tu l\'es.',
    MascotMood.listening => 'Je note…',
    MascotMood.thinking => 'Je croise mes sources…',
    MascotMood.answering => 'Et voilà, c\'est dans le cours !',
    MascotMood.puzzled => 'Hmm, pas trouvé. Un autre mot-clé ?',
  };

  static const _skin = Color(0xFFE0A982);
  static const _hair = Color(0xFF3B2A2F);
  Color _hoodie(MascotKit k) =>
      k.pose.dark ? const Color(0xFF8B6AE8) : const Color(0xFF7C5CE0);

  @override
  Color sleeve(MascotKit k) => _hoodie(k);
  @override
  Color hand(MascotKit k) => _skin;

  @override
  void paintBody(Canvas canvas, MascotKit k) {
    for (final x in [40.0, 60.0]) {
      k.rrect(
        canvas,
        Rect.fromCenter(center: Offset(x, 110), width: 15, height: 8),
        4,
        const Color(0xFF2E3B55),
      );
    }
    // Capuche derrière le cou.
    k.oval(canvas, const Offset(50, 66), 34, 12, _hoodie(k));
    k.rrect(canvas, const Rect.fromLTWH(30, 64, 40, 44), 14, _hoodie(k));
    _padlock(canvas, k, const Offset(50, 88));
  }

  @override
  void paintHead(Canvas canvas, MascotKit k) {
    // Chignon et cheveux.
    k.oval(canvas, const Offset(50, 16), 16, 15, _hair);
    k.oval(canvas, const Offset(50, 42), 54, 48, _hair);
    k.oval(canvas, const Offset(50, 47), 42, 38, _skin);
    // Frange.
    k.shape(
      canvas,
      Path()
        ..moveTo(28, 40)
        ..quadraticBezierTo(34, 22, 52, 23)
        ..quadraticBezierTo(70, 22, 72, 40)
        ..quadraticBezierTo(60, 31, 50, 34)
        ..quadraticBezierTo(38, 30, 28, 40)
        ..close(),
      _hair,
    );
    k.dotEyes(canvas, const [Offset(41, 46), Offset(59, 46)]);
    k.mouth(canvas, const Offset(50, 56), size: 0.85);
    k.cheeks(canvas, const [Offset(35, 53), Offset(65, 53)], r: 2.6);
    // Casque et micro.
    final band = k.line..strokeWidth = 3.4;
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(50, 44), width: 58, height: 50),
      pi + 0.15,
      pi - 0.3,
      false,
      band,
    );
    for (final x in [22.0, 78.0]) {
      k.rrect(
        canvas,
        Rect.fromCenter(center: Offset(x, 46), width: 9, height: 15),
        4,
        _hoodie(k),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(78, 52)
        ..quadraticBezierTo(76, 61, 62, 60),
      k.line..strokeWidth = 2,
    );
    k.oval(canvas, const Offset(61, 60), 5, 5, const Color(0xFF2E3B55));
  }
}

// ---------------------------------------------------------------------------

class _Trace extends MascotCharacter {
  const _Trace();

  @override
  String get id => 'trace';
  @override
  String get name => 'Trace';
  @override
  String get species => 'l\'enquêteur forensique';
  @override
  String get personality =>
      'Patient et minutieux, il remonte chaque trace jusqu\'à la preuve.';

  @override
  String line(MascotMood mood) => switch (mood) {
    MascotMood.idle => 'Un incident à élucider ?',
    MascotMood.listening => 'Je relève les indices…',
    MascotMood.thinking => 'J\'analyse les traces…',
    MascotMood.answering => 'Preuve trouvée : la voici !',
    MascotMood.puzzled => 'Aucune trace… essaie un autre indice ?',
  };

  static const _white = Color(0xFFFFF7EC);
  static const _coat = Color(0xFFD9B77E);
  static const _brown = Color(0xFF7A5230);

  @override
  Color sleeve(MascotKit k) => _coat;
  @override
  Color hand(MascotKit k) => _brown;

  @override
  void paintBody(Canvas canvas, MascotKit k) {
    for (final x in [40.0, 60.0]) {
      k.rrect(
        canvas,
        Rect.fromCenter(center: Offset(x, 110), width: 15, height: 8),
        4,
        _brown,
      );
    }
    k.rrect(canvas, const Rect.fromLTWH(31, 64, 38, 44), 15, _coat);
    // Col, ceinture et boutons de l'imperméable.
    k.shape(
      canvas,
      Path()
        ..moveTo(40, 64)
        ..lineTo(50, 76)
        ..lineTo(60, 64)
        ..close(),
      _white,
    );
    canvas.drawLine(
      const Offset(32, 92),
      const Offset(68, 92),
      k.line..strokeWidth = 3,
    );
    for (final y in [82.0, 99.0]) {
      canvas.drawCircle(Offset(50, y), 1.8, k.fill(_brown));
    }
  }

  static const _skin = Color(0xFFB87A55);

  @override
  void paintHead(Canvas canvas, MascotKit k) {
    k.oval(canvas, const Offset(50, 46), 44, 40, _skin);
    k.dotEyes(canvas, const [Offset(41, 46), Offset(59, 46)]);
    k.mouth(canvas, const Offset(50, 57), size: 0.85);
    k.cheeks(canvas, const [Offset(35, 53), Offset(65, 53)], r: 2.6);
    // Moustache d'enquêteur.
    canvas.drawPath(
      Path()
        ..moveTo(43, 53)
        ..quadraticBezierTo(50, 50, 57, 53)
        ..quadraticBezierTo(50, 54.5, 43, 53)
        ..close(),
      k.fill(const Color(0xFF3B2A2F)),
    );
    // Casquette à double visière, à carreaux.
    final cap = Path()
      ..moveTo(28, 36)
      ..quadraticBezierTo(30, 14, 50, 14)
      ..quadraticBezierTo(70, 14, 72, 36)
      ..close();
    k.shape(canvas, cap, _brown);
    canvas.save();
    canvas.clipPath(cap);
    final check = Paint()
      ..color = _coat.withValues(alpha: 0.6)
      ..strokeWidth = 1.4;
    for (var x = 26.0; x < 76; x += 7) {
      canvas.drawLine(Offset(x, 12), Offset(x, 38), check);
    }
    for (var y = 16.0; y < 38; y += 7) {
      canvas.drawLine(Offset(26, y), Offset(74, y), check);
    }
    canvas.restore();
    canvas.drawPath(cap, k.line);
    k.shape(
      canvas,
      Path()
        ..moveTo(24, 36)
        ..quadraticBezierTo(50, 31, 76, 36)
        ..quadraticBezierTo(50, 40, 24, 36)
        ..close(),
      _brown,
    );
  }

  @override
  void paintRightHandItem(Canvas canvas, MascotKit k) {
    // Loupe.
    canvas.drawLine(
      const Offset(1.5, 25),
      const Offset(1.5, 31),
      k.line..strokeWidth = 3.4,
    );
    canvas.drawCircle(
      const Offset(1.5, 37),
      6.5,
      k.fill(const Color(0xFFBFE6F5).withValues(alpha: 0.75)),
    );
    canvas.drawCircle(const Offset(1.5, 37), 6.5, k.line..strokeWidth = 2.4);
  }
}
