import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class BirdRewardDialog extends StatelessWidget {
  final String birdName;
  final String lottieAsset;
  final String title;
  final String description;
  final int xpGained;

  const BirdRewardDialog({
    super.key,
    required this.birdName,
    required this.lottieAsset,
    required this.title,
    required this.description,
    this.xpGained = 50,
  });

  static void show(
    BuildContext context, {
    required String birdName,
    required String lottieAsset,
    required String title,
    required String description,
    int xpGained = 50,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BirdRewardDialog(
        birdName: birdName,
        lottieAsset: lottieAsset,
        title: title,
        description: description,
        xpGained: xpGained,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.gold500.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold500.withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lottie Bird Animation
            SizedBox(
              height: 180,
              width: 180,
              child: Lottie.asset(
                lottieAsset,
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
            const SizedBox(height: 16),
            // Bird Name Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                birdName,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headingSmall(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(color: const Color(0xFFC5D1DE)),
            ),
            const SizedBox(height: 16),
            // XP Reward Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.darkBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: AppColors.gold400, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '+$xpGained XP Kazanıldı',
                    style: const TextStyle(
                      color: AppColors.gold400,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold500,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Mübarek Olsun',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
