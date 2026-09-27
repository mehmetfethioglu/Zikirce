import 'dart:math' as math;
import 'package:flutter/material.dart';

class NurParticle {
  final double angle; // In radians
  final double baseRadius;
  final double speed;
  final double size;
  final double phase;
  final bool isEmerald;

  const NurParticle({
    required this.angle,
    required this.baseRadius,
    required this.speed,
    required this.size,
    required this.phase,
    required this.isEmerald,
  });
}

class NurParticlesPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final List<NurParticle> particles;
  final Color primaryGlowColor;
  final Color secondaryGlowColor;

  static final Paint _haloPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static final Paint _particlePaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static final Paint _starPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  NurParticlesPainter({
    required this.progress,
    required this.particles,
    this.primaryGlowColor = const Color(0xFFEAB308), // Gold
    this.secondaryGlowColor = const Color(0xFF10B981), // Emerald
  });

  /// Factory helper to generate deterministic particles without GC thrashing
  static List<NurParticle> generateParticles({int count = 48}) {
    final rand = math.Random(42);
    return List.generate(count, (index) {
      final angle = rand.nextDouble() * 2 * math.pi;
      final baseRadius = 50.0 + rand.nextDouble() * 160.0;
      final speed = 0.6 + rand.nextDouble() * 0.8;
      final size = 2.5 + rand.nextDouble() * 4.5;
      final phase = rand.nextDouble() * math.pi;
      final isEmerald = rand.nextBool();
      return NurParticle(
        angle: angle,
        baseRadius: baseRadius,
        speed: speed,
        size: size,
        phase: phase,
        isEmerald: isEmerald,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.55;

    // 1. Fade Curve: Quick smooth fade-in (0.0 -> 0.2), graceful ease-out fade (0.6 -> 1.0)
    final double masterAlpha;
    if (progress < 0.2) {
      masterAlpha = progress / 0.2;
    } else if (progress < 0.65) {
      masterAlpha = 1.0;
    } else {
      masterAlpha = (1.0 - progress) / 0.35;
    }

    if (masterAlpha <= 0.001) return;

    // 2. Central Expanding Sacred Aura (Radial Glow)
    final currentGlowRadius = maxRadius * (0.4 + (progress * 0.6));
    _haloPaint.shader = RadialGradient(
      colors: [
        primaryGlowColor.withValues(alpha: 0.32 * masterAlpha),
        secondaryGlowColor.withValues(alpha: 0.16 * masterAlpha),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: currentGlowRadius));

    canvas.drawCircle(center, currentGlowRadius, _haloPaint);

    // 3. Subtle Outer Sacred Geometric Light Ring
    final ringRadius = maxRadius * (0.35 + (progress * 0.5));
    _haloPaint.shader = null;
    _haloPaint.style = PaintingStyle.stroke;
    _haloPaint.strokeWidth = 1.5;
    _haloPaint.color = primaryGlowColor.withValues(alpha: 0.22 * masterAlpha * (1.0 - progress));
    canvas.drawCircle(center, ringRadius, _haloPaint);
    _haloPaint.style = PaintingStyle.fill;

    // 4. Render Floating Particles
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      // Animate particle distance radiating outward
      final currentDistance = p.baseRadius * (0.5 + progress * 0.9 * p.speed);
      final currentAngle = p.angle + (progress * 0.4 * (i.isEven ? 1 : -1));

      final x = center.dx + currentDistance * math.cos(currentAngle);
      final y = center.dy + currentDistance * math.sin(currentAngle);

      // Particle twinkle phase
      final twinkle = (math.sin(progress * math.pi * 3 + p.phase) + 1.0) / 2.0;
      final particleAlpha = (masterAlpha * (0.35 + 0.65 * twinkle)).clamp(0.0, 1.0);

      final color = p.isEmerald ? secondaryGlowColor : primaryGlowColor;
      _particlePaint.color = color.withValues(alpha: particleAlpha);

      // Draw subtle star sparkle for some particles, circles for others
      if (i % 4 == 0) {
        _drawSparkle(canvas, Offset(x, y), p.size * (0.8 + 0.4 * twinkle), _particlePaint);
      } else {
        canvas.drawCircle(Offset(x, y), p.size * (0.7 + 0.3 * twinkle), _particlePaint);
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset pos, double sparkleSize, Paint paint) {
    _starPaint.color = paint.color;
    final path = Path();
    final half = sparkleSize;
    final quart = sparkleSize * 0.28;

    path.moveTo(pos.dx, pos.dy - half);
    path.quadraticBezierTo(pos.dx, pos.dy - quart, pos.dx + half, pos.dy);
    path.quadraticBezierTo(pos.dx + quart, pos.dy, pos.dx, pos.dy + half);
    path.quadraticBezierTo(pos.dx, pos.dy + quart, pos.dx - half, pos.dy);
    path.quadraticBezierTo(pos.dx - quart, pos.dy, pos.dx, pos.dy - half);
    path.close();

    canvas.drawPath(path, _starPaint);
  }

  @override
  bool shouldRepaint(covariant NurParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
