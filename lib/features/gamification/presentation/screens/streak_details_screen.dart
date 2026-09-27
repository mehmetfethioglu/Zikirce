import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/gamification_providers.dart';
import '../widgets/gold_diamond_exchange_sheet.dart';

class StreakDetailsScreen extends ConsumerWidget {
  const StreakDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(userStreakStreamProvider);
    final unrepairedGapsAsync = ref.watch(unrepairedGapDaysProvider);
    final hasRepairableAsync = ref.watch(hasRepairableStreakProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text('Zinciri Kırma (Streak)', style: AppTypography.headingSmall(color: Colors.white)),
      ),
      body: streakAsync.when(
        data: (streak) {
          final currentStreak = streak?.currentStreak ?? 0;
          final bestStreak = streak?.bestStreak ?? 0;
          final shields = streak?.freezeCount ?? 0;
          final unrepairedGaps = unrepairedGapsAsync.valueOrNull ?? const [];
          final hasRepairable = hasRepairableAsync.valueOrNull ?? false;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Fire Hero Center Card
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.fireGradient,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.4),
                            blurRadius: 32,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🔥', style: TextStyle(fontSize: 54)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$currentStreak Günlük Seri',
                      style: AppTypography.headingLarge(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Her gün en az 1 zikir veya sayfa okuyarak serinizi koruyun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8A9BAE), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Stats Row (Best Streak, Shields)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.military_tech_rounded, color: AppColors.gold400, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            '$bestStreak Gün',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text('En İyi Rekor', style: TextStyle(color: Color(0xFF8A9BAE), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.shield_rounded, color: AppColors.emerald400, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            '$shields Kalkan',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text('Seri Koruyucu', style: TextStyle(color: Color(0xFF8A9BAE), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (unrepairedGaps.isNotEmpty || (hasRepairable && bestStreak > currentStreak)) ...[
                const SizedBox(height: 20),
                _StreakRecoveryCard(
                  currentStreak: currentStreak,
                  bestStreak: bestStreak,
                  shields: shields,
                  unrepairedGaps: unrepairedGaps,
                  hasRepairable: hasRepairable,
                ),
              ],
              const SizedBox(height: 28),
              // 30 Days Heatmap Calendar Simulation
              Text(
                'Son 30 Günlük Devamlılık',
                style: AppTypography.headingSmall(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: 28,
                  itemBuilder: (context, index) {
                    final isActive = index >= (28 - currentStreak.clamp(0, 28));

                    return Container(
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.emerald500 : AppColors.darkBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? AppColors.emerald400 : AppColors.darkBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.white24,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Automatic Shield Protection Explanation Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emerald900.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emerald600.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_rounded, color: AppColors.emerald400, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Otomatik Kalkan Koruması Aktif',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shields > 0
                                ? 'Zikir yapamadığınız her gün için 1 kalkanınız otomatik harcanarak seriniz kesintisiz korunur.'
                                : 'Kalkanınız kalmadı! Serinizi garantiye almak için elmaslarınızla kalkan edinebilirsiniz.',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Buy Shield Button (Opens Treasury / Exchange Sheet)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_moderator_rounded),
                label: const Text('Kalkan Satın Al (5 💎 = 1 🛡️)', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  GoldDiamondExchangeSheet.show(context);
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold500)),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}

class _StreakRecoveryCard extends ConsumerStatefulWidget {
  final int currentStreak;
  final int bestStreak;
  final int shields;
  final List<StreakGapDay> unrepairedGaps;
  final bool hasRepairable;

  const _StreakRecoveryCard({
    required this.currentStreak,
    required this.bestStreak,
    required this.shields,
    required this.unrepairedGaps,
    required this.hasRepairable,
  });

  @override
  ConsumerState<_StreakRecoveryCard> createState() => _StreakRecoveryCardState();
}

class _StreakRecoveryCardState extends ConsumerState<_StreakRecoveryCard> {
  bool _isLoading = false;

  Future<void> _handleRepair({int? count}) async {
    setState(() => _isLoading = true);
    try {
      final result = count != null && count > 1
          ? await ref
              .read(gamificationNotifierProvider)
              .repairGapDaysFlexible(countToRepair: count)
          : await ref.read(gamificationNotifierProvider).repairNextGapDay();

      if (mounted) {
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
            backgroundColor:
                result.success ? AppColors.emerald600 : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasExplicitGaps = widget.unrepairedGaps.isNotEmpty;
    final gapCount = widget.unrepairedGaps.length;

    final powerAsync = ref.watch(streakRecoveryPowerProvider);
    final power = powerAsync.valueOrNull;

    final totalGaps = power?.totalUnrepairedDays ?? (hasExplicitGaps ? gapCount : 1);
    final affordableDays = power?.totalAffordableDays ?? widget.shields;
    final canAffordSome = affordableDays > 0;
    final canAffordAll = power?.canAffordAll ?? (affordableDays >= totalGaps && totalGaps > 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3D2005).withValues(alpha: 0.9),
            AppColors.darkCard,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.healing_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kırılan Serini Kurtar!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasExplicitGaps
                          ? '$gapCount eksik gün bulundu (Rekor: ${widget.bestStreak} Gün)'
                          : 'Önceki rekorunuz: ${widget.bestStreak} Gün',
                      style: TextStyle(
                        color: Colors.amber.shade200,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasExplicitGaps
                ? (canAffordAll
                    ? 'Tüm $gapCount eksik günü mevcut kaynaklarınızla kurtararak serinizi ${widget.bestStreak} günlük rekorunuza bağlayabilirsiniz.'
                    : (canAffordSome
                        ? '$gapCount eksik gününüz var. Mevcut kaynaklarınızla $affordableDays günü kurtarabilir; kalan ${gapCount - affordableDays} günü daha sonra biriktirince tamamlayabilirsiniz.'
                        : 'Geçmişte boş kalan $gapCount gününüz var. Kalkan veya elmas edinerek zincirinizi eski rekorunuza (${widget.bestStreak} gün) bağlayabilirsiniz.'))
                : 'Geçmiş seriniz kesintiye uğramış görünüyor. 1 kalkan kullanarak serinizi rekorunuza (${widget.bestStreak} gün) eşitleyin!',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.35),
          ),
          if (power != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Kurtarma Gücü: $affordableDays Gün (${power.availableShields} 🛡️, ${power.availableDiamonds} 💎, ${power.availableGold} 🪙)',
                style: TextStyle(fontSize: 11, color: Colors.amber.shade200, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (hasExplicitGaps) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.unrepairedGaps.take(6).map((g) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    g.dateStr,
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade200, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          if (canAffordSome) ...[
            if (affordableDays > 1) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_fix_high_rounded, size: 20),
                      label: Text(
                        _isLoading
                            ? 'Onarılıyor...'
                            : (canAffordAll
                                ? 'Tümünü Kurtar ($totalGaps Gün)'
                                : 'Kurtar ($affordableDays Gün)'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        textAlign: TextAlign.center,
                      ),
                      onPressed: _isLoading ? null : () => _handleRepair(count: affordableDays),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade200,
                        side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.shield_outlined, size: 16),
                      label: const Text(
                        '1 Gün',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: _isLoading ? null : () => _handleRepair(count: 1),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_fix_high_rounded, size: 20),
                  label: Text(
                    _isLoading ? 'Onarılıyor...' : '1 Kalkan Kullan ve Kurtar',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _isLoading ? null : () => _handleRepair(count: 1),
                ),
              ),
            ],
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.diamond_rounded, size: 20),
                label: const Text(
                  'Kalkan Satın Al ve Kurtar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => GoldDiamondExchangeSheet.show(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
