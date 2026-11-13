import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../domain/irfan_models.dart';

/// SM-2 Aralıklı Hafıza Tekrarı (Spaced Repetition) durum ve aksiyon bandı.
class IrfanSm2ReviewBanner extends StatelessWidget {
  final int dueSm2Count;
  final int totalSm2PoolCount;
  final bool isFreeUsedToday;
  final VoidCallback onStartReview;

  const IrfanSm2ReviewBanner({
    super.key,
    required this.dueSm2Count,
    required this.totalSm2PoolCount,
    this.isFreeUsedToday = false,
    required this.onStartReview,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isTr = l10n.isTurkish;
    final hasDue = dueSm2Count > 0;
    const Color amberAccent = Color(0xFFD4A574);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasDue
              ? amberAccent.withValues(alpha: 0.65)
              : colors.borderStroke,
          width: hasDue ? 1.3 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: hasDue
                  ? amberAccent.withValues(alpha: 0.16)
                  : colors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              hasDue ? Icons.psychology_alt_rounded : Icons.verified_rounded,
              color: hasDue ? amberAccent : colors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.irfanSm2Title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                    if (hasDue) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: amberAccent.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$dueSm2Count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasDue
                      ? (isTr
                          ? (isFreeUsedToday
                              ? 'Vakti gelen $dueSm2Count soru var • Bugünkü ücretsiz hak kullanıldı (ekstra tur ${IrfanEconomyConfig.extraDailyOrSm2DiamondCost} 💎).'
                              : 'Hafızada kalıcılık vakti gelen $dueSm2Count soru seni bekliyor (günde 1 kez ücretsiz).')
                          : (isFreeUsedToday
                              ? '$dueSm2Count due questions • Free daily round used (extra round ${IrfanEconomyConfig.extraDailyOrSm2DiamondCost} 💎).'
                              : '$dueSm2Count questions due for spaced review (1 free daily round).'))
                      : (totalSm2PoolCount > 0
                          ? (isTr
                              ? (isFreeUsedToday
                                  ? 'Hafıza halkan güncel ($totalSm2PoolCount soru). Bugünkü ekstra tekrar ${IrfanEconomyConfig.extraDailyOrSm2DiamondCost} 💎.'
                                  : 'Hafıza halkan güncel ($totalSm2PoolCount soru takipte). Bugünkü 1 ücretsiz tekrarın hazır.')
                              : (isFreeUsedToday
                                  ? 'Memory vault up to date ($totalSm2PoolCount). Extra round today costs ${IrfanEconomyConfig.extraDailyOrSm2DiamondCost} 💎.'
                                  : 'Memory vault up to date ($totalSm2PoolCount). 1 free review ready today.'))
                          : (isTr
                              ? 'Soruları çözdükçe SM-2 akıllı tekrar takvimin otomatik oluşur.'
                              : 'Solve quizzes to build your automatic SM-2 review schedule.')),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: colors.secondaryTextAlt,
                  ),
                ),
              ],
            ),
          ),
          if (hasDue || totalSm2PoolCount > 0) ...[
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                HapticService.selectionClick();
                onStartReview();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: hasDue ? colors.accent : colors.accentLight,
                foregroundColor: hasDue ? Colors.white : colors.accentText,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isFreeUsedToday
                    ? (isTr
                        ? 'Tekrarla • ${IrfanEconomyConfig.extraDailyOrSm2DiamondCost} 💎'
                        : 'Review • ${IrfanEconomyConfig.extraDailyOrSm2DiamondCost} 💎')
                    : (isTr ? 'Tekrarla' : 'Review'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
