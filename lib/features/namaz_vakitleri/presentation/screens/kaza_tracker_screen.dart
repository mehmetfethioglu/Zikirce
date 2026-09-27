import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/prayer_providers.dart';
import '../../../../core/database/app_database.dart';

class KazaTrackerScreen extends ConsumerWidget {
  const KazaTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kazaListAsync = ref.watch(kazaPrayersStreamProvider);
    final kazaNotifier = ref.read(kazaNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text('Kaza Namazı Defteri', style: AppTypography.headingSmall(color: Colors.white)),
      ),
      body: kazaListAsync.when(
        data: (list) {
          final totalRemaining = list.fold<int>(0, (sum, k) => sum + k.totalCount);
          final totalCompleted = list.fold<int>(0, (sum, k) => sum + k.completedCount);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.emeraldGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.gold500.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Kalan Kaza', style: TextStyle(color: Color(0xFFD4EBE4), fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                          '$totalRemaining',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 44, color: Colors.white24),
                    Column(
                      children: [
                        const Text('Kılınan Kaza', style: TextStyle(color: Color(0xFFD4EBE4), fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                          '$totalCompleted',
                          style: const TextStyle(
                            color: AppColors.gold300,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // List of 7 Kaza Prayers
              ...list.map((kaza) => _buildKazaCard(context, kaza, kazaNotifier)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold500)),
        error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildKazaCard(BuildContext context, KazaPrayer kaza, KazaNotifier notifier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                kaza.prayerType,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Text(
                  'Kalan: ${kaza.totalCount}',
                  style: const TextStyle(color: AppColors.gold400, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Increment buttons
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: AppColors.darkBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => notifier.adjustKaza(kaza.prayerType, 1),
                child: const Text('+1 Ekle'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: AppColors.darkBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => notifier.adjustKaza(kaza.prayerType, 5),
                child: const Text('+5 Ekle'),
              ),
              const Spacer(),
              // Kaza Kıldım Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold500,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Kıldım (-1)', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: kaza.totalCount > 0
                    ? () => notifier.performKaza(kaza.prayerType)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
