import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Telegram anketlerindeki gibi sade, ekranı engellemeyen (IgnorePointer) doğru cevap konfeti katmanı.
class IrfanPollConfettiOverlay extends StatefulWidget {
  final ValueListenable<int> trigger;

  const IrfanPollConfettiOverlay({
    super.key,
    required this.trigger,
  });

  @override
  State<IrfanPollConfettiOverlay> createState() =>
      _IrfanPollConfettiOverlayState();
}

class _IrfanPollConfettiOverlayState extends State<IrfanPollConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _rng = math.Random();
  List<_PollConfettiParticle> _particles = const [];

  static const List<Color> _palette = [
    Color(0xFF10B981),
    Color(0xFFD4A574),
    Color(0xFFF59E0B),
    Color(0xFF14B8A6),
    Color(0xFF38BDF8),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..addStatusListener(_onAnimationStatus);
    widget.trigger.addListener(_handleTrigger);
  }

  @override
  void didUpdateWidget(covariant IrfanPollConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      oldWidget.trigger.removeListener(_handleTrigger);
      widget.trigger.addListener(_handleTrigger);
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {});
    }
  }

  void _handleTrigger() {
    if (!mounted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) == true) return;

    _particles = List<_PollConfettiParticle>.generate(32, (index) {
      return _PollConfettiParticle(
        originDxFactor: (_rng.nextDouble() * 2.0 - 1.0) * 0.12,
        vx: (_rng.nextDouble() * 2.0 - 1.0) * 155.0,
        vy: -115.0 - _rng.nextDouble() * 145.0,
        baseAngle: _rng.nextDouble() * math.pi * 2.0,
        angularSpeed: (_rng.nextDouble() * 2.0 - 1.0) * 6.0,
        flipSpeed: 4.5 + _rng.nextDouble() * 6.0,
        phase: _rng.nextDouble() * math.pi * 2.0,
        scale: 0.85 + _rng.nextDouble() * 0.45,
        shape: index % 3,
        color: _palette[index % _palette.length],
      );
    }, growable: false);

    setState(() {});
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_handleTrigger);
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _PollConfettiPainter(
                  progress: _controller.value,
                  particles: _particles,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PollConfettiParticle {
  final double originDxFactor;
  final double vx;
  final double vy;
  final double baseAngle;
  final double angularSpeed;
  final double flipSpeed;
  final double phase;
  final double scale;
  final int shape;
  final Color color;

  const _PollConfettiParticle({
    required this.originDxFactor,
    required this.vx,
    required this.vy,
    required this.baseAngle,
    required this.angularSpeed,
    required this.flipSpeed,
    required this.phase,
    required this.scale,
    required this.shape,
    required this.color,
  });
}

class _PollConfettiPainter extends CustomPainter {
  final double progress;
  final List<_PollConfettiParticle> particles;

  static final Paint _paint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static const Rect _ribbonRect = Rect.fromLTWH(-3.25, -1.6, 6.5, 3.2);

  _PollConfettiPainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0 || particles.isEmpty) return;

    final p = progress;
    final t = Curves.easeOutCubic.transform(p);
    final double alpha = p < 0.12
        ? (p / 0.12)
        : (p > 0.62 ? ((1.0 - p) / 0.38).clamp(0.0, 1.0) : 1.0);
    if (alpha <= 0.001) return;

    final double originY = size.height * 0.28;

    for (final particle in particles) {
      final double x =
          size.width * (0.5 + particle.originDxFactor) + particle.vx * t;
      final double y = originY + particle.vy * p + 0.5 * 540.0 * p * p;

      final double flipX =
          0.35 + 0.65 * math.cos(p * particle.flipSpeed + particle.phase).abs();

      _paint.color = particle.color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.baseAngle + p * particle.angularSpeed);
      canvas.scale(flipX * particle.scale, particle.scale);

      switch (particle.shape) {
        case 0:
          canvas.drawRRect(
            RRect.fromRectAndRadius(_ribbonRect, const Radius.circular(1.0)),
            _paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, 2.6, _paint);
        default:
          _drawFourPointStar(canvas, 3.6);
      }

      canvas.restore();
    }
  }

  void _drawFourPointStar(Canvas canvas, double r) {
    final inner = r * 0.42;
    final path = Path()
      ..moveTo(0, -r)
      ..lineTo(inner, -inner)
      ..lineTo(r, 0)
      ..lineTo(inner, inner)
      ..lineTo(0, r)
      ..lineTo(-inner, inner)
      ..lineTo(-r, 0)
      ..lineTo(-inner, -inner)
      ..close();
    canvas.drawPath(path, _paint);
  }

  @override
  bool shouldRepaint(covariant _PollConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
  }
}
