import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../../zikir/presentation/widgets/zikir_share_preview_modal.dart';
import 'surprise_chest_dialog.dart';

class DailyGoalsSheet extends ConsumerWidget {
  const DailyGoalsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const DailyGoalsSheet(),
    );
  }

  void _openGoalShareCard({
    required BuildContext context,
    required String goalTitle,
    required String category,
    required int currentCount,
    required int targetCount,
    required ZikirShareCardTheme theme,
  }) {
    HapticService.selectionClick();
    ZikirSharePreviewModal.show(
      context: context,
      zikirName: goalTitle,
      category: category,
      currentCount: currentCount,
      targetCount: targetCount,
      totalCount: currentCount,
      initialTheme: theme,
      initialShowCounterStats: false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusAsync = ref.watch(dailyGoalsStatusProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: statusAsync.when(
          data: (status) {
            final isGold = status.isGoldCompleted;
            final isClaimed = status.isChestClaimed;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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
                const SizedBox(height: 16),

                // Title Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isTurkish ? '🌟 Altın Gün Hedefleri' : '🌟 Golden Day Goals',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.isTurkish
                                ? 'Her hedef için manevi paylaşım kartı oluşturabilir, tüm hedeflerle sandığı açabilirsiniz!'
                                : 'Share a spiritual card for any goal and complete all goals to unlock the chest!',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.secondaryTextAlt,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isGold ? const Color(0xFFFEF08A) : colors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isGold ? const Color(0xFFEAB308) : colors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${status.completedGoalsCount}/${status.totalActiveGoals}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isGold ? const Color(0xFF854D0E) : colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Goals List (Ordered 1. Namaz, 2. Zikir, 3. Kur'an, 4. Ezber, 5. Kaza)
                // 1. 5 Vakit Namaz (Zorunlu)
                _buildGoalRow(
                  icon: '🕌',
                  title: l10n.isTurkish ? '5 Vakit Farz Namaz' : '5 Daily Prayers',
                  subtitle: status.isExcusedMode
                      ? (l10n.isTurkish ? 'Zaruri hal nedeniyle muaf tutuldu' : 'Excused due to special day')
                      : (status.isPrayersMet && status.completedPrayersCount < 5
                          ? (l10n.isTurkish
                              ? 'Vakti gelen namazlar kılındı (${status.completedPrayersCount} / 5)'
                              : 'Due prayers completed (${status.completedPrayersCount} / 5)')
                          : '${status.completedPrayersCount} / 5 vakit kılındı'),
                  isDone: status.isExcusedMode || status.isPrayersMet,
                  isMandatory: true,
                  isExcused: status.isExcusedMode,
                  colors: colors,
                  onShareTap: () => _openGoalShareCard(
                    context: context,
                    goalTitle: l10n.isTurkish ? '5 Vakit Namaz & Secde Huzuru' : '5 Daily Prayers & Prostration',
                    category: 'Namaz',
                    currentCount: status.completedPrayersCount,
                    targetCount: 5,
                    theme: ZikirShareCardTheme.turquoiseDome,
                  ),
                ),

                // 2. Zikir Goal (if active)
                if (status.isZikirGoalEnabled)
                  _buildGoalRow(
                    icon: '📿',
                    title: l10n.isTurkish ? 'Günlük Zikir Hedefi' : 'Daily Dhikr Goal',
                    subtitle: '${status.todayZikirCount} / ${status.zikirGoal} zikir',
                    isDone: status.isZikirMet,
                    colors: colors,
                    onShareTap: () => _openGoalShareCard(
                      context: context,
                      goalTitle: l10n.isTurkish ? 'Günlük Zikir & Kalbin Huzuru' : 'Daily Dhikr & Peace of Heart',
                      category: 'Zikir',
                      currentCount: status.todayZikirCount,
                      targetCount: status.zikirGoal,
                      theme: ZikirShareCardTheme.emeraldSufi,
                    ),
                  ),

                // 3. Quran Goal (if active)
                if (status.isKuranGoalEnabled)
                  _buildGoalRow(
                    icon: '📖',
                    title: l10n.isTurkish ? 'Kur\'an-ı Kerim' : 'Holy Quran',
                    subtitle: status.isExcusedMode
                        ? (l10n.isTurkish ? 'Zaruri hal nedeniyle muaf tutuldu' : 'Excused due to special day')
                        : '${status.todayKuranPages} / ${status.kuranGoal} sayfa',
                    isDone: status.isExcusedMode || status.isKuranMet,
                    isExcused: status.isExcusedMode,
                    colors: colors,
                    onShareTap: () => _openGoalShareCard(
                      context: context,
                      goalTitle: l10n.isTurkish ? 'Kur’an-ı Kerim Tilaveti' : 'Holy Quran Recitation',
                      category: 'Kur’an',
                      currentCount: status.todayKuranPages,
                      targetCount: status.kuranGoal,
                      theme: ZikirShareCardTheme.fajrDawn,
                    ),
                  ),

                // 4. Memorization Goal (if active)
                if (status.isEzberGoalEnabled)
                  _buildGoalRow(
                    icon: '🧠',
                    title: l10n.isTurkish ? 'Ezber / Hafızlık' : 'Memorization',
                    subtitle: '${status.todayEzberCount} / ${status.ezberGoal} tekrar',
                    isDone: status.isEzberMet,
                    colors: colors,
                    onShareTap: () => _openGoalShareCard(
                      context: context,
                      goalTitle: l10n.isTurkish ? 'Ezber & Hafızlık Gayreti' : 'Quran Memorization & Hifz',
                      category: 'Ezber',
                      currentCount: status.todayEzberCount,
                      targetCount: status.ezberGoal,
                      theme: ZikirShareCardTheme.royalAmethyst,
                    ),
                  ),

                // 5. Kaza Goal (if active)
                if (status.isKazaGoalEnabled)
                  _buildGoalRow(
                    icon: '⚖️',
                    title: l10n.isTurkish ? 'Kaza Namazı Telafisi' : 'Missed Prayer Make-up',
                    subtitle: '${status.todayKazaCount} / ${status.kazaGoal} kaza',
                    isDone: status.isKazaMet,
                    colors: colors,
                    onShareTap: () => _openGoalShareCard(
                      context: context,
                      goalTitle: l10n.isTurkish ? 'Kaza Telafisi & İstiğfar' : 'Missed Prayer Make-up & Repentance',
                      category: 'Kaza & Tövbe',
                      currentCount: status.todayKazaCount,
                      targetCount: status.kazaGoal,
                      theme: ZikirShareCardTheme.roseAmber,
                    ),
                  ),

                const SizedBox(height: 16),

                // Altın Gün Action Box
                if (isGold)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2A2510), const Color(0xFF1E1B0E)]
                            : [const Color(0xFFFEF08A), const Color(0xFFFDE047)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEAB308), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('🎁', style: TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.isTurkish
                                        ? 'Tebrikler! Altın Gün Tamamlandı 🎉'
                                        : 'Congratulations! Golden Day Complete 🎉',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFFFACC15) : const Color(0xFF854D0E),
                                    ),
                                  ),
                                  Text(
                                    isClaimed
                                        ? (l10n.isTurkish ? 'Bugünkü sandık açıldı.' : 'Today\'s chest claimed.')
                                        : (l10n.isTurkish ? 'Sürpriz sandığınız hazır!' : 'Your surprise chest is ready!'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white70 : const Color(0xFFA16207),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: isClaimed
                                  ? null
                                  : () async {
                                      HapticService.selectionClick();
                                      Navigator.of(context).pop();
                                      final reward = await ref
                                          .read(gamificationNotifierProvider)
                                          .openSurpriseChest(isTurkish: l10n.isTurkish);
                                      ref.invalidate(dailyGoalsStatusProvider);
                                      ref.invalidate(userProfileStreamProvider);
                                      ref.invalidate(diamondCountProvider);
                                      ref.invalidate(goldCountProvider);
                                      ref.invalidate(userStreakStreamProvider);
                                      if (reward != null && context.mounted) {
                                        await SurpriseChestDialog.show(context, reward: reward);
                                        ref.invalidate(dailyGoalsStatusProvider);
                                        ref.invalidate(userProfileStreamProvider);
                                        ref.invalidate(diamondCountProvider);
                                        ref.invalidate(goldCountProvider);
                                        ref.invalidate(userStreakStreamProvider);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEAB308),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                isClaimed
                                    ? (l10n.isTurkish ? 'Açıldı ✅' : 'Claimed ✅')
                                    : (l10n.isTurkish ? 'Aç 🎁' : 'Open 🎁'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openGoalShareCard(
                              context: context,
                              goalTitle: l10n.isTurkish ? 'Altın Gün & İbadette İstikamet' : 'Golden Day & Steadfastness',
                              category: 'Altın Gün',
                              currentCount: status.completedGoalsCount,
                              targetCount: status.totalActiveGoals,
                              theme: ZikirShareCardTheme.midnightGold,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? const Color(0xFFFACC15) : const Color(0xFF854D0E),
                              side: const BorderSide(color: Color(0xFFEAB308)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.share_rounded, size: 16),
                            label: Text(
                              l10n.isTurkish ? 'Altın Gün Kartını Paylaş' : 'Share Golden Day Card',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.borderStroke),
                    ),
                    child: Row(
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.isTurkish
                                ? 'Her hedefin yanındaki paylaş butonundan o hedefe özel ayet/hadis kartını paylaşabilirsiniz.'
                                : 'Tap the share button next to any goal to share its dedicated verse/hadith card.',
                            style: TextStyle(fontSize: 11.5, color: colors.secondaryTextAlt),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildGoalRow({
    required String icon,
    required String title,
    required String subtitle,
    required bool isDone,
    bool isMandatory = false,
    bool isExcused = false,
    required AppThemeColors colors,
    required VoidCallback onShareTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: isDone && !isExcused ? TextDecoration.lineThrough : null,
                          color: isDone ? colors.secondaryTextAlt : colors.primaryText,
                        ),
                      ),
                    ),
                    if (isMandatory) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Zorunlu',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                    if (isExcused) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Muaf 🌸',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE91E63),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.secondaryTextAlt,
                  ),
                ),
              ],
            ),
          ),
          // Per-Goal Share Button (Every goal can open its own Share Card!)
          InkWell(
            onTap: onShareTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                    : colors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDone
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                      : colors.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.share_rounded,
                    size: 13,
                    color: isDone ? const Color(0xFFD97706) : colors.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Paylaş',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isDone ? const Color(0xFFD97706) : colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isDone ? const Color(0xFF10B981) : colors.borderStroke,
            size: 22,
          ),
        ],
      ),
    );
  }
}
