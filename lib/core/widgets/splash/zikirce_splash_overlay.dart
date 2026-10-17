import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme_colors.dart';
import 'zikirce_vector_logo.dart';

/// Zikirce Otonom Atmosferik ve Vektörel Animasyonlu Splash Katmanı.
/// İşletim sistemi (Native) açılış ekranından birebir aynı boyut ve merkez
/// konumundan zıplamasız devralır; yalnızca logo ve üzerindeki ruhani nur hâlesi,
/// kubbe pencere ışıltıları ve tesbih salınımı animasyonlarını çalıştırarak
/// ana ekrana "Fade + Scale-Out" ile pürüzsüzce erir.
class ZikirceSplashOverlay extends StatefulWidget {
  final Widget child;

  const ZikirceSplashOverlay({
    super.key,
    required this.child,
  });

  @override
  State<ZikirceSplashOverlay> createState() => _ZikirceSplashOverlayState();
}

class _ZikirceSplashOverlayState extends State<ZikirceSplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isDismissed = false;
  bool _didTriggerHaptic = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    );
    _controller.addListener(_onAnimationTick);
    _controller.addStatusListener(_onAnimationStatus);
    _controller.forward();
  }

  void _onAnimationTick() {
    if (!_didTriggerHaptic && _controller.value >= 0.18) {
      _didTriggerHaptic = true;
      HapticService.lightImpact();
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        _isDismissed = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationTick);
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) {
      return widget.child;
    }

    final colors = context.colors;
    final isDark = colors.statusBrightness == Brightness.light;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;

            // Çıkış aşaması (0.76 -> 1.00): Yumuşak Fade + Hafif Scale-Out (1.0 -> 1.06)
            final exitProgress = ((t - 0.76) / 0.24).clamp(0.0, 1.0);
            final exitCurve = Curves.easeInOutCubic.transform(exitProgress);
            final overlayOpacity = (1.0 - exitCurve).clamp(0.0, 1.0);
            final overlayScale = 1.0 + 0.06 * exitCurve;

            // İç animasyon eğrileri (0.00 -> 0.78)
            final introT = (t / 0.78).clamp(0.0, 1.0);
            final haloProgress =
                Curves.easeOutCubic.transform((introT / 0.75).clamp(0.0, 1.0));
            final haloRotation = introT * (math.pi / 6.0);
            final shimmerProgress = Curves.easeInOutSine.transform(introT);

            // Doğal sönümlü sarkaç salınımı (Tesbih)
            final tesbihSwing = 0.082 *
                math.sin(introT * 3.2 * math.pi) *
                math.exp(-introT * 2.5);

            // Native splash merkezinden yumuşak nefes/yerleşme ölçeği
            final logoBreath = 1.0 +
                0.035 *
                    math.sin(Curves.easeOutQuad.transform(introT) * math.pi);

            final goldAccent = isDark
                ? const Color(0xFFDAB562)
                : const Color(0xFFB8893A);

            return IgnorePointer(
              ignoring: exitProgress > 0.05,
              child: Opacity(
                opacity: overlayOpacity,
                child: Transform.scale(
                  scale: overlayScale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.pageBackground,
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.95,
                        colors: [
                          Color.lerp(
                            colors.pageBackground,
                            isDark
                                ? const Color(0xFF163829)
                                : const Color(0xFFDCEBE4),
                            0.55 * haloProgress,
                          )!,
                          colors.pageBackground,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: logoBreath,
                        child: ZikirceVectorLogo(
                          size: 188.0,
                          haloProgress: haloProgress,
                          haloRotation: haloRotation,
                          shimmerProgress: shimmerProgress,
                          tesbihSwingAngle: tesbihSwing,
                          haloColor: goldAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
