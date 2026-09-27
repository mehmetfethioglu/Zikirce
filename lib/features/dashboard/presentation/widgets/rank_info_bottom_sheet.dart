import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/models/user_rank.dart';
import '../../../gamification/providers/gamification_providers.dart';

class RankInfoBottomSheet extends ConsumerWidget {
  const RankInfoBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RankInfoBottomSheet(),
    );
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalZikirAsync = ref.watch(totalZikirCountProvider);
    final totalZikir = totalZikirAsync.valueOrNull ?? 0;

    final currentRank = ref.watch(currentUserRankProvider);
    final nextRank = UserRank.getNextRank(totalZikir);
    final allRanks = UserRank.getAllRanks();

    final remainingForNext = nextRank != null ? (nextRank.requiredZikir - totalZikir).clamp(0, 999999999) : 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          // ==========================================
          // HEADER (Matching MAUI RankInfoView Header)
          // ==========================================
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title Row
                Row(
                  children: [
                    // Shield / Explore icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.military_tech_rounded, size: 20, color: colors.accent),
                    ),
                    const SizedBox(width: 12),

                    // Title & Current count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('Gamification_SpiritualRanks'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 12, color: colors.secondaryTextAlt),
                              children: [
                                TextSpan(text: '${l10n.translate('Gamification_CurrentDhikr')} '),
                                TextSpan(
                                  text: _formatNumber(totalZikir),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colors.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Close Button
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.close, size: 16, color: colors.secondaryTextAlt),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ==========================================
          // RANK LIST (Matching MAUI AllRanksDisplay)
          // ==========================================
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: allRanks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rank = allRanks[index];
                final isCurrent = rank.level == currentRank.level;
                final isUnlocked = totalZikir >= rank.requiredZikir;

                // Color mappings matching MAUI RankDisplayItem.cs
                final bgGradient = isCurrent
                    ? (isDark
                        ? const [Color(0xFF4A3D30), Color(0xFF3A3025)]
                        : const [Color(0xFFFFF8E1), Color(0xFFFFE8B8)])
                    : null;

                final solidBg = !isCurrent
                    ? (isUnlocked ? colors.cardBackground : colors.cardBackgroundAlt.withValues(alpha: 0.6))
                    : null;

                final borderColor = isCurrent
                    ? const Color(0xFFD4A574)
                    : (isUnlocked ? colors.borderStroke : colors.borderStroke.withValues(alpha: 0.4));

                final borderThickness = isCurrent ? 2.0 : 1.0;

                final badgeBg = isCurrent
                    ? (isDark ? const Color(0xFFD4A574) : const Color(0xFFFFC107))
                    : (isDark ? const Color(0xFF3A3530) : const Color(0xFFF5E6D3));

                final countBg = isCurrent
                    ? const Color(0xFF4ADE80)
                    : (isDark ? const Color(0xFF3A3530) : const Color(0xFFF5E6D3));

                final countTextColor = isCurrent
                    ? Colors.white
                    : (isDark ? const Color(0xFFA89888) : const Color(0xFF8B7355));

                return Opacity(
                  opacity: isUnlocked || isCurrent ? 1.0 : 0.65,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: solidBg,
                      gradient: bgGradient != null
                          ? LinearGradient(
                              colors: bgGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: borderThickness),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD4A574).withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Left: Badge Emoji
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            rank.badge,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Middle: Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    rank.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primaryText,
                                    ),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        l10n.isTurkish ? 'Siz' : 'You',
                                        style: const TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rank.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: colors.secondaryTextAlt,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (rank.privilege.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '🎁 ${rank.privilege}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colors.accent,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Right: Required Zikir Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: countBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            rank.getLocalizedCriteria(l10n),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: countTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ==========================================
          // BOTTOM FIXED BANNER (Matching MAUI HasNextRank)
          // ==========================================
          if (nextRank != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.bottomSheetBg.withValues(alpha: 0.0),
                    colors.bottomSheetBg,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accent, colors.accent.withValues(alpha: 0.85)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🚀', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12.5, color: Colors.white),
                        children: [
                          TextSpan(text: l10n.isTurkish ? 'Sonraki mertebeye ' : 'Remaining for next rank: '),
                          TextSpan(
                            text: _formatNumber(remainingForNext),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          TextSpan(text: l10n.isTurkish ? ' zikir kaldı' : ' dhikr'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
}
