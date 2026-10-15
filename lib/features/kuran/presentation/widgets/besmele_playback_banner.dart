import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/kuran_providers.dart';

class BesmelePlaybackBanner extends ConsumerStatefulWidget {
  const BesmelePlaybackBanner({super.key});

  @override
  ConsumerState<BesmelePlaybackBanner> createState() => _BesmelePlaybackBannerState();
}

class _BesmelePlaybackBannerState extends ConsumerState<BesmelePlaybackBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arabicFont = ref.watch(arabicFontFamilyProvider);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      AppColors.darkCard.withValues(alpha: 0.95),
                      const Color(0xFF1E2B25).withValues(alpha: 0.95),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.96),
                      AppColors.emerald50.withValues(alpha: 0.96),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: (isDark ? AppColors.gold500 : AppColors.gold700)
                  .withValues(alpha: (0.4 * _glowAnimation.value).clamp(0.0, 1.0)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? AppColors.gold500 : AppColors.gold600)
                    .withValues(alpha: (0.12 * _glowAnimation.value).clamp(0.0, 1.0)),
                blurRadius: 16 * _glowAnimation.value,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 16,
                    color: isDark ? AppColors.gold400 : AppColors.gold800,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Besmele-i Şerif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.gold300 : AppColors.gold800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 16,
                    color: isDark ? AppColors.gold400 : AppColors.gold800,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحٖيمِ',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: arabicFont,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.gold400 : const Color(0xFF7A510A),
                  height: 1.6,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
