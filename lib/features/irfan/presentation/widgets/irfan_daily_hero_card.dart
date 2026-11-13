import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../domain/irfan_models.dart';
import 'irfan_seljuk_star_painter.dart';

/// Günün 5 İrfan Sorusu kahraman kartı (özel gün temalı, süresiz ve stressiz).
class IrfanDailyHeroCard extends StatelessWidget {
  final bool isDailyCompleted;
  final int dailyCorrectCount;
  final String? activeThemeLabel;
  final int irfanStreakDays;
  final int totalSolved;
  final VoidCallback onStartDaily;

  const IrfanDailyHeroCard({
    super.key,
    required this.isDailyCompleted,
    required this.dailyCorrectCount,
    required this.activeThemeLabel,
    required this.irfanStreakDays,
    required this.totalSolved,
    required this.onStartDaily,
  });

  static const Color _seljukGold = Color(0xFFD4A574);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isTr = l10n.isTurkish;
    final hasSpecialTheme =
        activeThemeLabel != null && activeThemeLabel!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent,
            Color.lerp(colors.accent, const Color(0xFF0F2E24), 0.42)!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              top: -26,
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size(148, 148),
                    painter: IrfanSeljukStarPainter(
                      color: Colors.white.withValues(alpha: 0.10),
                      accentColor: _seljukGold.withValues(alpha: 0.16),
                      strokeWidth: 1.6,
                      filled: true,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: _HeroTagPill(
                          label: hasSpecialTheme
                              ? '✨ ${activeThemeLabel!}'
                              : (isTr
                                  ? 'GÜNLÜK İRFAN HALKASI'
                                  : 'DAILY WISDOM CIRCLE'),
                          isHighlighted: hasSpecialTheme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HeroStatChip(
                        emoji: '🔥',
                        text: isTr
                            ? '$irfanStreakDays Gün'
                            : '$irfanStreakDays d',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.irfanDailyTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isDailyCompleted
                        ? (isTr
                            ? 'Bugünkü ücretsiz İrfan Halkan tamamlandı ($dailyCorrectCount/5 doğru). Dilersen ${IrfanEconomyConfig.extraDailyOrSm2DiamondCost} Elmas ile ekstra halka açabilirsin.'
                            : 'Today\'s free Wisdom Circle is complete ($dailyCorrectCount/5 correct). Open an extra round anytime for ${IrfanEconomyConfig.extraDailyOrSm2DiamondCost} Diamonds.')
                        : (isTr
                            ? 'Günde 1 kez ücretsiz • ${IrfanEconomyConfig.initialSessionSeconds} sn Akıllı Kum Saati (hikmet okurken durur). İlk tamamlamada +${IrfanEconomyConfig.dailyCompleteGoldBonus} Altın ve +${IrfanEconomyConfig.dailyCompleteDiamondBonus} Elmas kazan.'
                            : 'Free once daily • ${IrfanEconomyConfig.initialSessionSeconds}s Smart Hourglass (pauses while reading). First completion earns +${IrfanEconomyConfig.dailyCompleteGoldBonus} Gold & +${IrfanEconomyConfig.dailyCompleteDiamondBonus} Diamond.'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.42,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _FiveStepPearls(
                        completedCount:
                            isDailyCompleted ? dailyCorrectCount : 0,
                        isDone: isDailyCompleted,
                      ),
                      const Spacer(),
                      Text(
                        isTr ? '$totalSolved Çözüldü' : '$totalSolved Solved',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticService.selectionClick();
                        onStartDaily();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: colors.accent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isDailyCompleted
                                ? Icons.replay_rounded
                                : Icons.auto_awesome_rounded,
                            size: 18,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isDailyCompleted
                                ? (isTr
                                    ? 'Ekstra Halka Aç • ${IrfanEconomyConfig.extraDailyOrSm2DiamondCost} 💎'
                                    : 'Extra Round • ${IrfanEconomyConfig.extraDailyOrSm2DiamondCost} 💎')
                                : (isTr
                                    ? 'Günün 5 Sorusuna Başla'
                                    : 'Start Daily 5 Quiz'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTagPill extends StatelessWidget {
  final String label;
  final bool isHighlighted;

  const _HeroTagPill({
    required this.label,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFFD4A574).withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFFD4A574).withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final String emoji;
  final String text;

  const _HeroStatChip({
    required this.emoji,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiveStepPearls extends StatelessWidget {
  final int completedCount;
  final bool isDone;

  const _FiveStepPearls({
    required this.completedCount,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = isDone && index < completedCount;
        return Container(
          margin: const EdgeInsets.only(right: 6),
          width: 22,
          height: 8,
          decoration: BoxDecoration(
            color: filled
                ? const Color(0xFFD4A574)
                : Colors.white.withValues(alpha: isDone ? 0.28 : 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
