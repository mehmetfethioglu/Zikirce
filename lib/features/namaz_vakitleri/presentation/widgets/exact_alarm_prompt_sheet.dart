import 'package:flutter/material.dart';
import '../../../../core/services/battery_optimization_service.dart';
import '../../../../core/theme/app_theme_colors.dart';

class ExactAlarmPromptSheet extends StatelessWidget {
  const ExactAlarmPromptSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExactAlarmPromptSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon Header
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('🕌', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Hassas Vakit ve Widget Bildirimleri',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              'Ezan vakitlerinin gecikmeden çalması ve ana ekran widget\'ının tam vaktinde sıradaki vakte geçmesi için Android "Alarmlar ve Hatırlatıcılar" izninin açık olması gerekmektedir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),

            // Feature Badges
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.borderStroke),
              ),
              child: Column(
                children: [
                  _buildBenefitRow(
                    icon: '⏱️',
                    title: 'Tam Zamanında Ezan Bildirimi',
                    desc: 'Ezan girdiğinde gecikme olmaksızın anında çalar.',
                    colors: colors,
                  ),
                  const Divider(height: 16, thickness: 0.5),
                  _buildBenefitRow(
                    icon: '📱',
                    title: 'Canlı Widget Geri Sayımı',
                    desc: 'Ana ekran widget\'ı donmadan canlı geri sayar.',
                    colors: colors,
                  ),
                  const Divider(height: 16, thickness: 0.5),
                  _buildBenefitRow(
                    icon: '🔔',
                    title: '45 Dk Kala Akıllı Hatırlatıcı',
                    desc: 'Vaktin çıkmasına 45 dk kala stabil bildirim gönderir.',
                    colors: colors,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Primary Button
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await BatteryOptimizationService.openExactAlarmSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'İzni Etkinleştir',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Secondary Button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: colors.secondaryText,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Şimdilik Geç',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow({
    required String icon,
    required String title,
    required String desc,
    required AppThemeColors colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
