import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../dashboard/presentation/widgets/streak_share_preview_modal.dart';
import '../../../zikir/presentation/widgets/zikir_share_card_widget.dart';

class ShareCardScreen extends ConsumerWidget {
  const ShareCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(userStreakStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text('Paylaşım Kartı', style: AppTypography.headingSmall(color: Colors.white)),
      ),
      body: streakAsync.when(
        data: (streak) {
          final currentStreak = streak?.currentStreak ?? 0;
          final rank = streak?.rank ?? 'Mübtedi';

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                // Luxury Share Card Preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppColors.gold500.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold500.withValues(alpha: 0.2),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold400, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold400.withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Image.asset('assets/images/zikirce_logo.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '“Kalpler ancak Allah’ı anmakla huzur bulur.”',
                        textAlign: TextAlign.center,
                        style: AppTypography.headingSmall(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(Ra’d Sûresi, 28)',
                        style: TextStyle(color: AppColors.gold300, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.gold500.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '$currentStreak Günlük İbadet Serisi • Makam: $rank',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Zikirce — İslâmî Yaşam ve Zikir Asistanı',
                        style: TextStyle(color: Color(0xFFD4EBE4), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Share Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold500,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Görsel Paylaşım Kartını Aç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: () {
                      StreakSharePreviewModal.show(
                        context,
                        currentStreak: currentStreak,
                        bestStreak: streak?.bestStreak ?? 0,
                        totalDays: streak?.totalDays ?? 0,
                        rankName: rank,
                        initialTheme: ZikirShareThemeData.themeForGoalOrTask(goalType: 'streak'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold500)),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}
