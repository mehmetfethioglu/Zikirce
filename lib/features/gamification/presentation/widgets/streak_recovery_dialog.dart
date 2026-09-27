import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/sound_pool_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/gamification_providers.dart';
import 'gold_diamond_exchange_sheet.dart';

class StreakRecoveryDialog extends ConsumerStatefulWidget {
  final int bestStreak;
  final int currentStreak;
  final int availableShields;
  final int remainingGaps;

  const StreakRecoveryDialog({
    super.key,
    required this.bestStreak,
    required this.currentStreak,
    required this.availableShields,
    this.remainingGaps = 1,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int bestStreak,
    required int currentStreak,
    required int availableShields,
    int remainingGaps = 1,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'StreakRecovery',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => StreakRecoveryDialog(
        bestStreak: bestStreak,
        currentStreak: currentStreak,
        availableShields: availableShields,
        remainingGaps: remainingGaps,
      ),
      transitionBuilder: (context, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  @override
  ConsumerState<StreakRecoveryDialog> createState() =>
      _StreakRecoveryDialogState();
}

class _StreakRecoveryDialogState extends ConsumerState<StreakRecoveryDialog> {
  bool _isProcessing = false;

  Future<void> _handleRepair({int? count}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    HapticService.selectionClick();
    final result = count != null && count > 1
        ? await ref
            .read(gamificationNotifierProvider)
            .repairGapDaysFlexible(countToRepair: count)
        : await ref.read(gamificationNotifierProvider).repairNextGapDay();

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.of(context).pop(true);

      if (result.success) {
        HapticService.targetReached();
        SoundPoolService.playChirp(type: 'bulbul');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(result.isFullyRestored ? '🎉' : '🛡️',
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.message,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final powerAsync = ref.watch(streakRecoveryPowerProvider);
    final power = powerAsync.valueOrNull;

    final totalGaps = power?.totalUnrepairedDays ?? widget.remainingGaps;
    final affordableDays =
        power?.totalAffordableDays ?? widget.availableShields;
    final canAffordSome = affordableDays > 0;
    final canAffordAll =
        power?.canAffordAll ?? (affordableDays >= totalGaps && totalGaps > 0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D2E) : Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF059669).withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon with Glow
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF059669).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFF059669).withValues(alpha: 0.4),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.shield_moon_rounded,
                    color: Color(0xFF10B981),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              const Text(
                '🛡️ Serinizi Kurtarma Fırsatı!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                totalGaps > 1
                    ? (canAffordAll
                        ? 'Rekor seriniz ${widget.bestStreak} gündü. $totalGaps eksik günün tümünü mevcut kaynaklarınızla kurtararak zincirinizi yeniden birleştirebilirsiniz!'
                        : (canAffordSome
                            ? 'Rekor seriniz ${widget.bestStreak} gündü ($totalGaps eksik gün). Mevcut kaynaklarınızla $affordableDays günü hemen kurtarabilir; kalan ${totalGaps - affordableDays} günü daha sonra biriktirince tamamlayabilirsiniz.'
                            : 'Rekor seriniz ${widget.bestStreak} gündü ($totalGaps eksik gün). Elmas veya altınlarınızla kalkan edinerek serinizi kurtarabilirsiniz.'))
                    : 'Rekor seriniz ${widget.bestStreak} gündü. Kaçırılan eksik günü kurtararak zincirinizi yeniden bağlayabilirsiniz!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.secondaryTextAlt,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Status Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              'Rekor: ${widget.bestStreak}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                        Container(
                            height: 16, width: 1, color: colors.borderStroke),
                        Row(
                          children: [
                            const Text('🛡️', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              'Eksik: $totalGaps Gün',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (power != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Kurtarma Gücü: $affordableDays Gün (${power.availableShields} 🛡️, ${power.availableDiamonds} 💎, ${power.availableGold} 🪙)',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: colors.secondaryTextAlt,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              if (canAffordSome) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.secondaryTextAlt,
                          side: BorderSide(color: colors.borderStroke),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Daha Sonra'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : () => _handleRepair(count: affordableDays),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                canAffordAll
                                    ? 'Tümünü Kurtar ($totalGaps Gün)'
                                    : (affordableDays > 1
                                        ? 'Kurtar ($affordableDays Gün)'
                                        : 'Kurtar (1 🛡️)'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ],
                ),
                if (affordableDays > 1) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _handleRepair(count: 1),
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: const Text(
                      'Yalnızca 1 Günü Kurtar (1 🛡️)',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.secondaryTextAlt,
                          side: BorderSide(color: colors.borderStroke),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Kapat'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                          GoldDiamondExchangeSheet.show(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.diamond_rounded, size: 16),
                        label: const Text(
                          'Kalkan Satın Al',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
