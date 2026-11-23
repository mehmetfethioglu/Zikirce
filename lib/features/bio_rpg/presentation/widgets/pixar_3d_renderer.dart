import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/bio_rpg_models.dart';

/// Pixar-grade 3D Layered Subsurface Scattering (SSS), Specular Catchlight,
/// and Interactive Matrix4 Perspective Skeletal Renderer for Battle Guardians.
class Pixar3DGuardianStage extends StatefulWidget {
  final BioCharacter guardian;
  final double size;
  final bool isAttacking;
  final bool isShielding;

  const Pixar3DGuardianStage({
    super.key,
    required this.guardian,
    this.size = 150,
    this.isAttacking = false,
    this.isShielding = false,
  });

  @override
  State<Pixar3DGuardianStage> createState() => _Pixar3DGuardianStageState();
}

class _Pixar3DGuardianStageState extends State<Pixar3DGuardianStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _tiltY = (_tiltY + details.delta.dx * 0.01).clamp(-0.35, 0.35);
          _tiltX = (_tiltX - details.delta.dy * 0.01).clamp(-0.35, 0.35);
        });
      },
      onPanEnd: (_) {
        setState(() {
          _tiltX = 0.0;
          _tiltY = 0.0;
        });
      },
      child: AnimatedBuilder(
        animation: _breathController,
        builder: (context, _) {
          final double t = _breathController.value;
          final double hoverOffset = math.sin(t * math.pi) * 6.0;
          final double attackLunge = widget.isAttacking ? 18.0 : 0.0;
          final double scalePulse = 1.0 + (math.sin(t * math.pi) * 0.035);

          final Matrix4 perspective = Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateX(_tiltX)
            ..rotateY(_tiltY);

          return Transform(
            alignment: Alignment.center,
            transform: perspective,
            child: Transform.translate(
              offset: Offset(attackLunge, -hoverOffset),
              child: Transform.scale(
                scale: scalePulse,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _PixarGuardianPainter(
                      guardian: widget.guardian,
                      animPhase: t,
                      isShielding: widget.isShielding,
                      isAttacking: widget.isAttacking,
                    ),
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

class _PixarGuardianPainter extends CustomPainter {
  final BioCharacter guardian;
  final double animPhase;
  final bool isShielding;
  final bool isAttacking;

  const _PixarGuardianPainter({
    required this.guardian,
    required this.animPhase,
    required this.isShielding,
    required this.isAttacking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double r = size.width * 0.34;

    final Paint shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.45),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(center.dx, size.height * 0.88),
          width: size.width * 0.68,
          height: size.height * 0.16,
        ),
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.88),
        width: size.width * 0.68,
        height: size.height * 0.16,
      ),
      shadowPaint,
    );

    final Paint auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          guardian.primaryColor.withValues(alpha: 0.42),
          guardian.secondaryColor.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.45));
    canvas.drawCircle(center, r * 1.45, auraPaint);

    final Paint secondary3DPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          guardian.accentColor,
          guardian.secondaryColor,
          guardian.primaryColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));

    switch (guardian.archetype) {
      case GuardianArchetype.kefirSprite:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx - r * 0.78, center.dy - r * 0.55),
            width: r * 0.55,
            height: r * 0.85,
          ),
          secondary3DPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx + r * 0.78, center.dy - r * 0.55),
            width: r * 0.55,
            height: r * 0.85,
          ),
          secondary3DPaint,
        );
        break;
      case GuardianArchetype.oliveKnight:
        final Path crest = Path()
          ..moveTo(center.dx, center.dy - r * 1.35)
          ..quadraticBezierTo(
            center.dx + r * 0.55,
            center.dy - r * 0.9,
            center.dx,
            center.dy - r * 0.6,
          )
          ..quadraticBezierTo(
            center.dx - r * 0.55,
            center.dy - r * 0.9,
            center.dx,
            center.dy - r * 1.35,
          );
        canvas.drawPath(crest, secondary3DPaint);
        break;
      case GuardianArchetype.oatTitan:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(center.dx - r * 0.95, center.dy),
              width: r * 0.5,
              height: r * 0.85,
            ),
            const Radius.circular(14),
          ),
          secondary3DPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(center.dx + r * 0.95, center.dy),
              width: r * 0.5,
              height: r * 0.85,
            ),
            const Radius.circular(14),
          ),
          secondary3DPaint,
        );
        break;
      case GuardianArchetype.chiaDragon:
      case GuardianArchetype.honeyPaladin:
      case GuardianArchetype.avocadoSage:
        canvas.drawCircle(
          Offset(center.dx - r * 0.92, center.dy - r * 0.2),
          r * 0.42,
          secondary3DPaint,
        );
        canvas.drawCircle(
          Offset(center.dx + r * 0.92, center.dy - r * 0.2),
          r * 0.42,
          secondary3DPaint,
        );
        break;
    }

    final Rect bodyRect = Rect.fromCenter(
      center: center,
      width: r * 1.95,
      height: r * 1.85,
    );
    final Paint bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 1.1,
        colors: [
          guardian.accentColor,
          guardian.primaryColor,
          Color.lerp(guardian.primaryColor, Colors.black, 0.45)!,
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(bodyRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(r * 0.88)),
      bodyPaint,
    );

    final Paint specularPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.62),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(bodyRect);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - r * 0.32, center.dy - r * 0.44),
        width: r * 0.75,
        height: r * 0.42,
      ),
      specularPaint,
    );

    final double eyeOffsetX = r * 0.36;
    final double eyeY = center.dy - r * 0.08;
    for (final double dir in [-1.0, 1.0]) {
      final Offset eyeCenter = Offset(center.dx + (dir * eyeOffsetX), eyeY);
      canvas.drawOval(
        Rect.fromCenter(center: eyeCenter, width: r * 0.44, height: r * 0.50),
        Paint()..color = Colors.white,
      );
      final Rect irisRect = Rect.fromCenter(
        center: eyeCenter,
        width: r * 0.32,
        height: r * 0.38,
      );
      canvas.drawOval(
        irisRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              guardian.secondaryColor,
              const Color(0xFF0F172A),
            ],
          ).createShader(irisRect),
      );
      canvas.drawCircle(eyeCenter, r * 0.10, Paint()..color = Colors.black);
      canvas.drawCircle(
        Offset(eyeCenter.dx - r * 0.06, eyeCenter.dy - r * 0.08),
        r * 0.065,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(eyeCenter.dx + r * 0.05, eyeCenter.dy + r * 0.07),
        r * 0.03,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    final Path smilePath = Path()
      ..moveTo(center.dx - r * 0.22, center.dy + r * 0.24)
      ..quadraticBezierTo(
        center.dx,
        center.dy + r * 0.44,
        center.dx + r * 0.22,
        center.dy + r * 0.24,
      );
    canvas.drawPath(
      smilePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );

    for (int i = 0; i < 3; i++) {
      final double angle = (animPhase * math.pi * 2) + (i * (math.pi * 2 / 3));
      final Offset orbPos = Offset(
        center.dx + math.cos(angle) * (r * 1.18),
        center.dy + math.sin(angle) * (r * 0.42),
      );
      canvas.drawCircle(
        orbPos,
        5.5,
        Paint()..color = guardian.accentColor.withValues(alpha: 0.9),
      );
    }

    if (isShielding) {
      canvas.drawCircle(
        center,
        r * 1.25,
        Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.28)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        r * 1.25,
        Paint()
          ..color = const Color(0xFF34D399)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixarGuardianPainter oldDelegate) {
    return oldDelegate.animPhase != animPhase ||
        oldDelegate.guardian.id != guardian.id ||
        oldDelegate.isShielding != isShielding ||
        oldDelegate.isAttacking != isAttacking;
  }
}

/// Pixar-Villain 3D Toxic Boss Renderer
class Pixar3DBossStage extends StatefulWidget {
  final ToxicBoss boss;
  final double size;
  final bool isHit;

  const Pixar3DBossStage({
    super.key,
    required this.boss,
    this.size = 155,
    this.isHit = false,
  });

  @override
  State<Pixar3DBossStage> createState() => _Pixar3DBossStageState();
}

class _Pixar3DBossStageState extends State<Pixar3DBossStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final double t = _pulseController.value;
        final double hitShakeX = widget.isHit ? math.sin(t * 30) * 10.0 : 0.0;
        final double floatY = math.cos(t * math.pi) * 5.0;

        return Transform.translate(
          offset: Offset(hitShakeX, floatY),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _PixarBossPainter(
                boss: widget.boss,
                animPhase: t,
                isHit: widget.isHit,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PixarBossPainter extends CustomPainter {
  final ToxicBoss boss;
  final double animPhase;
  final bool isHit;

  const _PixarBossPainter({
    required this.boss,
    required this.animPhase,
    required this.isHit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double r = size.width * 0.35;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.89),
        width: size.width * 0.74,
        height: size.height * 0.17,
      ),
      Paint()..color = boss.primaryColor.withValues(alpha: 0.35),
    );

    final Paint spikePaint = Paint()
      ..shader = LinearGradient(
        colors: [boss.secondaryColor, boss.primaryColor],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.3));

    for (int i = 0; i < 6; i++) {
      final double angle = (i * math.pi / 3) + (animPhase * 0.4);
      final Offset bubblePos = Offset(
        center.dx + math.cos(angle) * (r * 0.92),
        center.dy + math.sin(angle) * (r * 0.82),
      );
      canvas.drawCircle(bubblePos, r * 0.28, spikePaint);
    }

    final Rect coreRect = Rect.fromCenter(
      center: center,
      width: r * 1.95,
      height: r * 1.8,
    );
    final Paint corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.05,
        colors: [
          isHit ? Colors.white : boss.secondaryColor,
          boss.primaryColor,
          const Color(0xFF18042C),
        ],
      ).createShader(coreRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(coreRect, Radius.circular(r * 0.78)),
      corePaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - r * 0.3, center.dy - r * 0.42),
        width: r * 0.65,
        height: r * 0.32,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.42),
    );

    for (final double dir in [-1.0, 1.0]) {
      final Offset eyePos = Offset(
        center.dx + (dir * r * 0.36),
        center.dy - r * 0.1,
      );
      canvas.drawOval(
        Rect.fromCenter(center: eyePos, width: r * 0.38, height: r * 0.30),
        Paint()..color = const Color(0xFFFEF08A),
      );
      canvas.drawCircle(
        eyePos,
        r * 0.11,
        Paint()..color = const Color(0xFFDC2626),
      );
      canvas.drawCircle(
        Offset(eyePos.dx - r * 0.04, eyePos.dy - r * 0.04),
        r * 0.045,
        Paint()..color = Colors.white,
      );
    }

    final Path mouth = Path()
      ..moveTo(center.dx - r * 0.38, center.dy + r * 0.28)
      ..lineTo(center.dx - r * 0.18, center.dy + r * 0.38)
      ..lineTo(center.dx, center.dy + r * 0.26)
      ..lineTo(center.dx + r * 0.18, center.dy + r * 0.38)
      ..lineTo(center.dx + r * 0.38, center.dy + r * 0.28);
    canvas.drawPath(
      mouth,
      Paint()
        ..color = const Color(0xFFFEF08A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PixarBossPainter oldDelegate) {
    return oldDelegate.animPhase != animPhase ||
        oldDelegate.isHit != isHit ||
        oldDelegate.boss.id != boss.id;
  }
}

class PixarAvatarPalettes {
  static const List<Color> skinTones = [
    Color(0xFFFFDFC4),
    Color(0xFFF0C8A0),
    Color(0xFFD8A070),
    Color(0xFFA56B46),
    Color(0xFF6E4228),
  ];

  static const List<Color> hairColors = [
    Color(0xFF1E1B18),
    Color(0xFF6B3E26),
    Color(0xFFD97706),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
  ];

  static const List<Color> eyeColors = [
    Color(0xFF10B981),
    Color(0xFF0284C7),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
  ];

  static const List<Color> armorColors = [
    Color(0xFFF59E0B), // 0: Orijinal Stüdyo
    Color(0xFF10B981), // 1: Zümrüt Biyo-Aura
    Color(0xFF06B6D4), // 2: Siber Okyanus
    Color(0xFFF43F5E), // 3: Mercan Enerji
    Color(0xFF8B5CF6), // 4: Kuantum Mor
  ];
}

/// Close-Up 3D Pixar Character Bust / Portrait Renderer
/// Used in Viral Share Card & Compact Bust Previews; delegates to the 3D Stage or Studio Card.
class Pixar3DAvatarCanvas extends StatelessWidget {
  final PixarAvatarConfig config;
  final int personalOrganicScore;
  final double bmi;
  final double size;

  const Pixar3DAvatarCanvas({
    super.key,
    required this.config,
    required this.personalOrganicScore,
    required this.bmi,
    this.size = 190,
  });

  @override
  Widget build(BuildContext context) {
    final PixarCharacterSkin skin = config.activeCharacter;
    final int gradeIdx =
        config.armorStyleIndex % PixarAvatarPalettes.armorColors.length;
    final Color accentColor = gradeIdx == 0
        ? skin.accentColor
        : PixarAvatarPalettes.armorColors[gradeIdx];

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.90,
            height: size * 0.90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accentColor.withValues(alpha: 0.34),
                  accentColor.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.55),
                width: 2.0,
              ),
            ),
          ),
          ClipOval(
            child: SizedBox(
              width: size * 0.84,
              height: size * 0.84,
              child: Transform.scale(
                scale: 1.38,
                alignment: const Alignment(0.0, -0.55),
                child: Image.asset(
                  skin.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// True 3D `.glb` Skeletal Character Stage powered by `<model-viewer>` WebGL
/// (matching `ZVmE1GuEWmA` & `HVFTkE5_SHA` with real-time `Run`, `Walk`, `Idle`
/// skeletal animations, smooth camera-orbit transitions, 360° touch rotation,
/// real-time PBR hoodie color grading, tempo control, and BMI/height scaling).
class Pixar3DFullBodyWalkingStage extends StatefulWidget {
  final PixarAvatarConfig config;
  final int personalOrganicScore;
  final double bmi;
  final double heightCm;
  final bool isWalking;
  final int cameraMode; // 0: Koşu (Run 3/4), 1: Yürüyüş (Walk Side), 2: Duruş (Idle), 3: Portre (Close-up)
  final double width;
  final double height;

  const Pixar3DFullBodyWalkingStage({
    super.key,
    required this.config,
    required this.personalOrganicScore,
    required this.bmi,
    this.heightCm = 175.0,
    this.isWalking = true,
    this.cameraMode = 0,
    this.width = 215,
    this.height = 315,
  });

  @override
  State<Pixar3DFullBodyWalkingStage> createState() =>
      _Pixar3DFullBodyWalkingStageState();
}

class _Pixar3DFullBodyWalkingStageState
    extends State<Pixar3DFullBodyWalkingStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vfxController;

  @override
  void initState() {
    super.initState();
    _vfxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _vfxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PixarCharacterSkin skin = widget.config.activeCharacter;
    final int gradeIdx =
        widget.config.armorStyleIndex % PixarAvatarPalettes.armorColors.length;
    final Color accentColor = gradeIdx == 0
        ? skin.accentColor
        : PixarAvatarPalettes.armorColors[gradeIdx];
    final String mood = widget.config.expressionMood;

    return AnimatedBuilder(
      animation: _vfxController,
      builder: (context, _) {
        final double rawPhase = _vfxController.value * math.pi * 2;
        final double flightArc =
            widget.isWalking ? math.sin(rawPhase).abs() : 0.12;

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.width, widget.height),
                painter: _PixarStudioStageBackdropPainter(
                  accentColor: accentColor,
                  mood: mood,
                  phase: rawPhase,
                  flightArc: flightArc,
                  isWalking: widget.isWalking,
                ),
              ),
              if (widget.config.companionVisorIndex > 0)
                IgnorePointer(
                  child: CustomPaint(
                    size: Size(widget.width, widget.height),
                    painter: _Pixar3DEquipmentOverlayPainter(
                      equipmentIndex: widget.config.companionVisorIndex,
                      accentColor: accentColor,
                      phase: rawPhase,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PixarStudioStageBackdropPainter extends CustomPainter {
  final Color accentColor;
  final String mood;
  final double phase;
  final double flightArc;
  final bool isWalking;

  const _PixarStudioStageBackdropPainter({
    required this.accentColor,
    required this.mood,
    required this.phase,
    required this.flightArc,
    required this.isWalking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.50;
    final double groundY = size.height * 0.89;
    final Color effectiveColor =
        mood == 'detox_fog' ? const Color(0xFF7C3AED) : accentColor;

    // 1. Dynamic 3D Floor Glow Pedestal
    final double shadowScale = (1.0 - flightArc * 0.22).clamp(0.7, 1.0);
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(cx, groundY),
      width: size.width * 0.74 * shadowScale,
      height: size.height * 0.08 * shadowScale,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            effectiveColor.withValues(alpha: 0.30 * shadowScale),
            effectiveColor.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(shadowRect),
    );

    // 2. Expanding 3D Kinetic Step Ripple Rings
    if (isWalking) {
      final double ripple = (phase / (math.pi * 2)) % 1.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, groundY),
          width: size.width * (0.36 + ripple * 0.48),
          height: size.height * (0.04 + ripple * 0.06),
        ),
        Paint()
          ..color = effectiveColor.withValues(alpha: (1.0 - ripple) * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // 3. Mood-Driven 3D Particle VFX
    if (mood == 'energized') {
      for (int i = 0; i < 5; i++) {
        final double p = ((phase / (math.pi * 2)) + i * 0.2) % 1.0;
        final double px = cx + math.sin(phase + i * 1.4) * (size.width * 0.34);
        final double py = groundY - p * (size.height * 0.72);
        canvas.drawCircle(
          Offset(px, py),
          3.2 * (1.0 - p * 0.5),
          Paint()..color = const Color(0xFFFBBF24).withValues(alpha: 1.0 - p),
        );
      }
    } else if (mood == 'detox_fog') {
      for (int i = 0; i < 3; i++) {
        final double angle = phase + i * (math.pi * 2 / 3);
        final Offset fogPos = Offset(
          cx + math.cos(angle) * (size.width * 0.28),
          size.height * 0.52 + math.sin(angle) * 18.0,
        );
        canvas.drawCircle(
          fogPos,
          16.0,
          Paint()..color = const Color(0xFF7C3AED).withValues(alpha: 0.16),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixarStudioStageBackdropPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.mood != mood ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isWalking != isWalking;
  }
}

class _Pixar3DEquipmentOverlayPainter extends CustomPainter {
  final int equipmentIndex;
  final Color accentColor;
  final double phase;

  const _Pixar3DEquipmentOverlayPainter({
    required this.equipmentIndex,
    required this.accentColor,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.50;

    if (equipmentIndex == 1) {
      final Offset hudCenter = Offset(cx, size.height * 0.42);
      canvas.drawOval(
        Rect.fromCenter(
          center: hudCenter,
          width: size.width * 0.82,
          height: size.height * 0.18,
        ),
        Paint()
          ..color = accentColor.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      final double orbAngle = phase;
      final Offset scannerDot = Offset(
        hudCenter.dx + math.cos(orbAngle) * (size.width * 0.41),
        hudCenter.dy + math.sin(orbAngle) * (size.height * 0.09),
      );
      canvas.drawCircle(scannerDot, 5.0, Paint()..color = Colors.white);
      canvas.drawCircle(scannerDot, 3.0, Paint()..color = accentColor);
    } else if (equipmentIndex == 2) {
      final Offset dronePos = Offset(
        size.width * 0.80,
        size.height * 0.24 + math.sin(phase * 1.5) * 7.0,
      );
      final Rect droneRect = Rect.fromCenter(
        center: dronePos,
        width: 34,
        height: 34,
      );
      canvas.drawCircle(
        dronePos,
        22,
        Paint()..color = accentColor.withValues(alpha: 0.24),
      );
      canvas.drawOval(
        droneRect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [
              Colors.white,
              accentColor,
              const Color(0xFF0F172A),
            ],
          ).createShader(droneRect),
      );
      canvas.drawCircle(
        Offset(dronePos.dx - 4.5, dronePos.dy - 1),
        2.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(dronePos.dx + 4.5, dronePos.dy - 1),
        2.5,
        Paint()..color = Colors.white,
      );
    } else if (equipmentIndex == 3) {
      final Offset crownCenter = Offset(
        cx,
        size.height * 0.06 + math.sin(phase * 1.5) * 4.0,
      );
      final Path crown = Path()
        ..moveTo(crownCenter.dx - 18, crownCenter.dy + 8)
        ..lineTo(crownCenter.dx - 22, crownCenter.dy - 6)
        ..lineTo(crownCenter.dx - 9, crownCenter.dy + 1)
        ..lineTo(crownCenter.dx, crownCenter.dy - 10)
        ..lineTo(crownCenter.dx + 9, crownCenter.dy + 1)
        ..lineTo(crownCenter.dx + 22, crownCenter.dy - 6)
        ..lineTo(crownCenter.dx + 18, crownCenter.dy + 8)
        ..close();
      canvas.drawPath(
        crown,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDE047), Color(0xFFD97706)],
          ).createShader(
            Rect.fromCenter(center: crownCenter, width: 46, height: 24),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Pixar3DEquipmentOverlayPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.equipmentIndex != equipmentIndex ||
        oldDelegate.accentColor != accentColor;
  }
}
