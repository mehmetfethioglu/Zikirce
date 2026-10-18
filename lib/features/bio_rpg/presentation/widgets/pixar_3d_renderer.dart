import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/bio_rpg_models.dart';

/// Pixar-grade 3D Layered Subsurface Scattering (SSS), Specular Catchlight,
/// and Interactive Matrix4 Perspective Skeletal Renderer (Option A - Zero Muda).
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

    // 1. 3D Ground Ambient Occlusion Shadow
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

    // 2. Volumetric Back Rim Aura
    final Paint auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          guardian.primaryColor.withValues(alpha: 0.42),
          guardian.secondaryColor.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.45));
    canvas.drawCircle(center, r * 1.45, auraPaint);

    // 3. Archetype-specific 3D Ears / Crest / Wings behind torso
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
        // Floating 3D Water/Probiotic Droplet Crown & Ears
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
        // Golden Leaf Paladin Crest & Shoulder Pauldrons
        final Path crest = Path()
          ..moveTo(center.dx, center.dy - r * 1.35)
          ..quadraticBezierTo(center.dx + r * 0.55, center.dy - r * 0.9, center.dx, center.dy - r * 0.6)
          ..quadraticBezierTo(center.dx - r * 0.55, center.dy - r * 0.9, center.dx, center.dy - r * 1.35);
        canvas.drawPath(crest, secondary3DPaint);
        break;
      case GuardianArchetype.oatTitan:
        // Heavy 3D Golem Shoulder Plates
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(center.dx - r * 0.95, center.dy), width: r * 0.5, height: r * 0.85),
            const Radius.circular(14),
          ),
          secondary3DPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(center.dx + r * 0.95, center.dy), width: r * 0.5, height: r * 0.85),
            const Radius.circular(14),
          ),
          secondary3DPaint,
        );
        break;
      case GuardianArchetype.chiaDragon:
      case GuardianArchetype.honeyPaladin:
      case GuardianArchetype.avocadoSage:
        // Floating Energy Wings
        canvas.drawCircle(Offset(center.dx - r * 0.92, center.dy - r * 0.2), r * 0.42, secondary3DPaint);
        canvas.drawCircle(Offset(center.dx + r * 0.92, center.dy - r * 0.2), r * 0.42, secondary3DPaint);
        break;
    }

    // 4. Core Pixar 3D Subsurface-Scattered (SSS) Body Sphere/Capsule
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

    // 5. Specular Top-Left Studio Softbox Highlight (Pixar Vinyl Toy Sheen)
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

    // 6. Expressive Pixar 3D Eyes with Dual Catchlights
    final double eyeOffsetX = r * 0.36;
    final double eyeY = center.dy - r * 0.08;
    for (final double dir in [-1.0, 1.0]) {
      final Offset eyeCenter = Offset(center.dx + (dir * eyeOffsetX), eyeY);
      // Sclera shadow
      canvas.drawOval(
        Rect.fromCenter(center: eyeCenter, width: r * 0.44, height: r * 0.50),
        Paint()..color = Colors.white,
      );
      // Iris 3D gradient
      final Rect irisRect = Rect.fromCenter(center: eyeCenter, width: r * 0.32, height: r * 0.38);
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
      // Pupil
      canvas.drawCircle(eyeCenter, r * 0.10, Paint()..color = Colors.black);
      // Primary Pixar Specular Catchlight
      canvas.drawCircle(
        Offset(eyeCenter.dx - r * 0.06, eyeCenter.dy - r * 0.08),
        r * 0.065,
        Paint()..color = Colors.white,
      );
      // Secondary Rim Catchlight
      canvas.drawCircle(
        Offset(eyeCenter.dx + r * 0.05, eyeCenter.dy + r * 0.07),
        r * 0.03,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    // 7. Happy Confident Pixar Smile / Expression
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

    // 8. Orbiting Bio-Elemental Particles or Shield Bubble
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

/// Pixar-Villain 3D Toxic Boss Renderer (Emülgo-Slime, Glüten Golem, MSG Phantom, etc.)
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

    // 1. Toxic Puddle Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.89),
        width: size.width * 0.74,
        height: size.height * 0.17,
      ),
      Paint()..color = boss.primaryColor.withValues(alpha: 0.35),
    );

    // 2. Spiky / Bubbling Chemical Silhouettes
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

    // 3. 3D Subsurface Boss Core
    final Rect coreRect = Rect.fromCenter(center: center, width: r * 1.95, height: r * 1.8);
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

    // 4. Glossy Slime / Crystal Specular Highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - r * 0.3, center.dy - r * 0.42),
        width: r * 0.65,
        height: r * 0.32,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.42),
    );

    // 5. Angry Glowing 3D Villain Eyes
    for (final double dir in [-1.0, 1.0]) {
      final Offset eyePos = Offset(center.dx + (dir * r * 0.36), center.dy - r * 0.1);
      canvas.drawOval(
        Rect.fromCenter(center: eyePos, width: r * 0.38, height: r * 0.30),
        Paint()..color = const Color(0xFFFEF08A),
      );
      canvas.drawCircle(eyePos, r * 0.11, Paint()..color = const Color(0xFFDC2626));
      canvas.drawCircle(
        Offset(eyePos.dx - r * 0.04, eyePos.dy - r * 0.04),
        r * 0.045,
        Paint()..color = Colors.white,
      );
    }

    // 6. Jagged Monster Grin
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

/// Apple Animoji-style 3D Pixar Avatar Renderer synchronized with Height/Weight BMI
/// and Living Personal OrganicScore!
class Pixar3DAvatarCanvas extends StatefulWidget {
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
  State<Pixar3DAvatarCanvas> createState() => _Pixar3DAvatarCanvasState();
}

class _Pixar3DAvatarCanvasState extends State<Pixar3DAvatarCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idleController;
  double _rotY = 0.0;
  double _rotX = 0.0;

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
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
  ];

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color skin = skinTones[widget.config.skinToneIndex % skinTones.length];
    final Color hair = hairColors[widget.config.hairColorIndex % hairColors.length];
    final Color eyes = eyeColors[widget.config.eyeColorIndex % eyeColors.length];
    final Color armor = armorColors[widget.config.armorStyleIndex % armorColors.length];

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _rotY = (_rotY + details.delta.dx * 0.012).clamp(-0.4, 0.4);
          _rotX = (_rotX - details.delta.dy * 0.012).clamp(-0.3, 0.3);
        });
      },
      onPanEnd: (_) {
        setState(() {
          _rotX = 0.0;
          _rotY = 0.0;
        });
      },
      child: AnimatedBuilder(
        animation: _idleController,
        builder: (context, _) {
          final double t = _idleController.value;
          final Matrix4 transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0018)
            ..rotateX(_rotX)
            ..rotateY(_rotY);

          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _PixarAvatarPainter(
                  skinColor: skin,
                  hairColor: hair,
                  eyeColor: eyes,
                  armorColor: armor,
                  hairStyleIndex: widget.config.hairStyleIndex,
                  visorIndex: widget.config.companionVisorIndex,
                  mood: widget.config.expressionMood,
                  personalScore: widget.personalOrganicScore,
                  bmi: widget.bmi,
                  animPhase: t,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PixarAvatarPainter extends CustomPainter {
  final Color skinColor;
  final Color hairColor;
  final Color eyeColor;
  final Color armorColor;
  final int hairStyleIndex;
  final int visorIndex;
  final String mood;
  final int personalScore;
  final double bmi;
  final double animPhase;

  const _PixarAvatarPainter({
    required this.skinColor,
    required this.hairColor,
    required this.eyeColor,
    required this.armorColor,
    required this.hairStyleIndex,
    required this.visorIndex,
    required this.mood,
    required this.personalScore,
    required this.bmi,
    required this.animPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double r = size.width * 0.32;
    final bool isDetoxFog = mood == 'detox_fog' || personalScore < 55;

    // 1. Dynamic Bio-Aura Ring based on Personal OrganicScore
    final Color auraColor = isDetoxFog
        ? const Color(0xFF7C3AED)
        : (personalScore >= 80 ? const Color(0xFF10B981) : const Color(0xFF06B6D4));

    canvas.drawCircle(
      center,
      r * 1.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            auraColor.withValues(alpha: 0.38),
            auraColor.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.42)),
    );

    // 2. 3D Bio-Armor Torso / Shoulders (scaled slightly by BMI factor)
    final double bmiWidthFactor = (bmi / 22.0).clamp(0.88, 1.18);
    final Rect torsoRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + r * 0.92),
      width: r * 1.65 * bmiWidthFactor,
      height: r * 0.95,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(r * 0.42)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            armorColor,
            Color.lerp(armorColor, Colors.black, 0.45)!,
          ],
        ).createShader(torsoRect),
    );

    // Glowing Chest Core Reactor
    canvas.drawCircle(
      Offset(center.dx, center.dy + r * 0.85),
      r * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + r * 0.85),
      r * 0.15,
      Paint()..color = auraColor,
    );

    // 3. 3D Subsurface-Scattered Head (Animoji Style)
    final Offset headCenter = Offset(center.dx, center.dy - r * 0.1 + math.sin(animPhase * math.pi) * 3.0);
    final Rect headRect = Rect.fromCenter(
      center: headCenter,
      width: r * 1.58,
      height: r * 1.66,
    );

    // Ears
    for (final double dir in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headCenter.dx + dir * r * 0.80, headCenter.dy + r * 0.05),
          width: r * 0.28,
          height: r * 0.38,
        ),
        Paint()..color = Color.lerp(skinColor, Colors.black, 0.12)!,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, Radius.circular(r * 0.72)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.28, -0.35),
          radius: 1.05,
          colors: [
            Color.lerp(skinColor, Colors.white, 0.22)!,
            skinColor,
            Color.lerp(skinColor, const Color(0xFF7C2D12), 0.28)!,
          ],
        ).createShader(headRect),
    );

    // Pixar Cheek Subsurface Blush
    for (final double dir in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headCenter.dx + dir * r * 0.42, headCenter.dy + r * 0.22),
          width: r * 0.32,
          height: r * 0.18,
        ),
        Paint()..color = const Color(0xFFF43F5E).withValues(alpha: 0.22),
      );
    }

    // 4. Expressive Pixar Eyes
    for (final double dir in [-1.0, 1.0]) {
      final Offset eyePos = Offset(headCenter.dx + dir * r * 0.32, headCenter.dy - r * 0.02);
      canvas.drawOval(
        Rect.fromCenter(center: eyePos, width: r * 0.36, height: r * 0.38),
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(eyePos, r * 0.14, Paint()..color = eyeColor);
      canvas.drawCircle(eyePos, r * 0.07, Paint()..color = Colors.black);
      canvas.drawCircle(
        Offset(eyePos.dx - r * 0.04, eyePos.dy - r * 0.05),
        r * 0.045,
        Paint()..color = Colors.white,
      );
    }

    // 5. Optional Holo-Visor (Cyber-Organic Glasses)
    if (visorIndex > 0) {
      final Rect visorRect = Rect.fromCenter(
        center: Offset(headCenter.dx, headCenter.dy - r * 0.02),
        width: r * 1.38,
        height: r * 0.44,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(visorRect, const Radius.circular(12)),
        Paint()..color = auraColor.withValues(alpha: 0.35),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(visorRect, const Radius.circular(12)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // 6. 3D Stylized Hair Geometry
    final Paint hairPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(hairColor, Colors.white, 0.18)!,
          hairColor,
          Color.lerp(hairColor, Colors.black, 0.35)!,
        ],
      ).createShader(headRect);

    if (hairStyleIndex % 3 == 0) {
      // Spiky Pixar Hero Crest
      final Path hairPath = Path()
        ..moveTo(headCenter.dx - r * 0.78, headCenter.dy - r * 0.32)
        ..quadraticBezierTo(headCenter.dx - r * 0.3, headCenter.dy - r * 1.15, headCenter.dx + r * 0.1, headCenter.dy - r * 0.92)
        ..quadraticBezierTo(headCenter.dx + r * 0.5, headCenter.dy - r * 1.18, headCenter.dx + r * 0.78, headCenter.dy - r * 0.32)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - r * 0.65, headCenter.dx - r * 0.78, headCenter.dy - r * 0.32);
      canvas.drawPath(hairPath, hairPaint);
    } else if (hairStyleIndex % 3 == 1) {
      // Rounded Fluffy Wave
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headCenter.dx, headCenter.dy - r * 0.68),
          width: r * 1.62,
          height: r * 0.68,
        ),
        hairPaint,
      );
    } else {
      // Twin Bio-Bun / Cyber Crown
      canvas.drawCircle(Offset(headCenter.dx - r * 0.58, headCenter.dy - r * 0.72), r * 0.32, hairPaint);
      canvas.drawCircle(Offset(headCenter.dx + r * 0.58, headCenter.dy - r * 0.72), r * 0.32, hairPaint);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(headCenter.dx, headCenter.dy - r * 0.64),
          width: r * 1.4,
          height: r * 0.45,
        ),
        hairPaint,
      );
    }

    // 7. Dynamic Mouth Expression (Heroic Smile vs Detox Fog Worry)
    final Path mouthPath = Path();
    if (isDetoxFog) {
      mouthPath
        ..moveTo(headCenter.dx - r * 0.20, headCenter.dy + r * 0.42)
        ..quadraticBezierTo(
          headCenter.dx,
          headCenter.dy + r * 0.30,
          headCenter.dx + r * 0.20,
          headCenter.dy + r * 0.42,
        );
    } else {
      mouthPath
        ..moveTo(headCenter.dx - r * 0.24, headCenter.dy + r * 0.34)
        ..quadraticBezierTo(
          headCenter.dx,
          headCenter.dy + r * 0.54,
          headCenter.dx + r * 0.24,
          headCenter.dy + r * 0.34,
        );
    }
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PixarAvatarPainter oldDelegate) {
    return oldDelegate.animPhase != animPhase ||
        oldDelegate.skinColor != skinColor ||
        oldDelegate.hairColor != hairColor ||
        oldDelegate.eyeColor != eyeColor ||
        oldDelegate.armorColor != armorColor ||
        oldDelegate.hairStyleIndex != hairStyleIndex ||
        oldDelegate.visorIndex != visorIndex ||
        oldDelegate.mood != mood ||
        oldDelegate.personalScore != personalScore;
  }
}
