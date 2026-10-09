import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/models/badge_models.dart';
import '../../../gamification/models/user_rank.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../gamification/presentation/widgets/gold_diamond_exchange_sheet.dart';
import '../../../kuran/presentation/screens/mushaf_screen.dart';

class BadgeDetailModal extends ConsumerWidget {
  final Badge badge;

  const BadgeDetailModal({super.key, required this.badge});

  static Future<void> show(BuildContext context, Badge badge) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BadgeDetailModal(badge: badge),
    );
  }

  void _readInQuran(BuildContext context) {
    int targetPage = 1;
    SureItem? targetSurah;
    String? streakKey;

    switch (badge.id) {
      case 'waqiah_40':
        targetPage = 534;
        targetSurah = SurahDataProvider.getSurahById(56);
        streakKey = 'Streak_Waqiah';
        break;
      case 'mulk_40':
        targetPage = 562;
        targetSurah = SurahDataProvider.getSurahById(67);
        streakKey = 'Streak_Mulk';
        break;
      case 'naba_40':
        targetPage = 582;
        targetSurah = SurahDataProvider.getSurahById(78);
        streakKey = 'Streak_Naba';
        break;
      case 'sleep_protection':
        targetPage = 604;
        targetSurah = SurahDataProvider.getSurahById(112);
        streakKey = 'Streak_Sleep';
        break;
      case 'surah_yasin':
        targetPage = 440;
        targetSurah = SurahDataProvider.getSurahById(36);
        streakKey = 'Streak_Yasin';
        break;
      default:
        if (badge.id.startsWith('quran_juz_')) {
          final juzNum = int.tryParse(badge.id.replaceAll('quran_juz_', ''));
          if (juzNum != null && juzNum >= 1 && juzNum <= 30) {
            targetPage = juzNum == 1 ? 1 : ((juzNum - 1) * 20) + 2;
          }
        } else {
          targetPage = 1;
        }
        break;
    }

    Navigator.of(context).pop();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => MushafScreen(
          initialPage: targetPage,
          targetSurah: targetSurah,
          streakKey: streakKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isZikir = badge.category == 'Zikir';
    final isSpecialQuran = badge.id == 'waqiah_40' ||
        badge.id == 'mulk_40' ||
        badge.id == 'naba_40' ||
        badge.id == 'sleep_protection' ||
        badge.id == 'surah_yasin' ||
        badge.category == 'Kur\'an' ||
        badge.category == 'Kuran';

    final diamondAsync = ref.watch(diamondCountProvider);
    final diamonds = diamondAsync.valueOrNull ?? 0;

    final String unlockStatusText = badge.isUnlocked
        ? (l10n.isTurkish ? '🔓 Kazanıldı!' : '🔓 Unlocked!')
        : (l10n.isTurkish ? '🔒 Henüz Kilitli' : '🔒 Locked');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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
          const SizedBox(height: 18),

          // Icon / Animation Container
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badge.glowColor.withValues(alpha: 0.14),
              border: Border.all(color: badge.glowColor, width: 2),
            ),
            alignment: Alignment.center,
            child: isZikir && badge.iconPath.endsWith('.json')
                ? Lottie.asset(
                    badge.iconPath,
                    width: 52,
                    height: 52,
                    repeat: true,
                  )
                : Text(
                    badge.emoji,
                    style: const TextStyle(fontSize: 40),
                  ),
          ),
          const SizedBox(height: 14),

          // Badge Name
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Criteria Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: badge.glowColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badge.criteria,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: badge.glowColor,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            badge.description,
            style: TextStyle(
              fontSize: 13,
              color: colors.secondaryTextAlt,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Streak Progress (if applicable)
          if (badge.hasStreakProgress) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: colors.cardBackgroundAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(badge.targetReadCount > 0 ? '📖 ' : '🔥 ',
                      style: const TextStyle(fontSize: 13)),
                  Text(
                    l10n.isTurkish ? 'İlerleme: ${badge.progressText}' : 'Progress: ${badge.progressText}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: badge.glowColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Unlock Status
          Text(
            unlockStatusText,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: badge.isUnlocked ? const Color(0xFF10B981) : colors.secondaryTextAlt,
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          if (isZikir && badge.isUnlocked) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Text('🕊️', style: TextStyle(fontSize: 16)),
                label: Text(l10n.isTurkish ? 'Bu Kuşu Sayaçta Kullan' : 'Use this Bird in Counter', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                onPressed: () async {
                  final allRanks = UserRank.getAllRanks();
                  final rankLevelStr = badge.id.replaceAll('rank_', '');
                  final levelVal = int.tryParse(rankLevelStr);
                  if (levelVal != null) {
                    final rank = allRanks.firstWhere((r) => r.level.value == levelVal, orElse: () => allRanks.first);
                    await ref.read(selectedBirdItemProvider.notifier).selectBird(
                      BirdSelectionItem(name: rank.name, fileName: rank.birdAnimationFile, badge: rank.badge),
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.isTurkish ? '🕊️ "${rank.name}" kuşu başarıyla sayaç kuşu yapıldı!' : '🕊️ "${rank.name}" bird selected as counter bird!')),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
          ] else if (isZikir && !badge.isUnlocked && badge.unlockCost > 0) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Text('💎', style: TextStyle(fontSize: 15)),
                label: Text(l10n.isTurkish ? '${badge.unlockCost} Elmas ile Kilidi Aç' : 'Unlock with ${badge.unlockCost} Diamonds', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                onPressed: () async {
                  final success = await ref.read(gamificationNotifierProvider).unlockBadgeWithDiamonds(badge);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.isTurkish ? '🎉 Tebrikler! "${badge.name}" rozetinin kilidi açıldı ve kuşu yüklendi!' : '🎉 Congratulations! "${badge.name}" badge unlocked!')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.isTurkish ? 'Yetersiz Elmas! Gerekli: ${badge.unlockCost} 💎' : 'Not enough diamonds! Required: ${badge.unlockCost} 💎'),
                          action: SnackBarAction(
                            label: l10n.translate('Exchange_ConvertBtn'),
                            textColor: const Color(0xFF38BDF8),
                            onPressed: () => GoldDiamondExchangeSheet.show(context),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            if (diamonds < badge.unlockCost) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Text('🪙', style: TextStyle(fontSize: 15)),
                  label: Text(
                    l10n.translate('Exchange_ConvertToUnlockBadge'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    GoldDiamondExchangeSheet.show(context);
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],

          if (isSpecialQuran) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: badge.glowColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text(l10n.isTurkish ? 'Kur\'an\'da Okumaya Devam Et' : 'Continue Reading in Quran', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                onPressed: () => _readInQuran(context),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Close Button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.commonClose,
                style: TextStyle(
                  color: colors.secondaryTextAlt,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
