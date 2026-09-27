import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/gamification_providers.dart';
import 'streak_details_screen.dart';

class BadgesGalleryScreen extends ConsumerWidget {
  const BadgesGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(userStreakStreamProvider);
    final unlockedBadgesAsync = ref.watch(unlockedBadgesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text('Rozetler & Rütbe', style: AppTypography.headingSmall(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent),
            tooltip: 'Seri (Streak) Detayları',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StreakDetailsScreen()),
              );
            },
          ),
        ],
      ),
      body: streakAsync.when(
        data: (streak) {
          final currentXp = streak?.xp ?? 0;
          final rank = streak?.rank ?? 'Mübtedi';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Rank Hero Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold500.withOpacity(0.2),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                      child: const Center(
                        child: Icon(Icons.shield_rounded, color: AppColors.gold400, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Makam: $rank',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currentXp Toplam XP Kazanıldı',
                            style: const TextStyle(color: Colors.black87, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Kazanılabilir Rozetler (${allBadgesCatalog.length})',
                style: AppTypography.headingSmall(color: Colors.white),
              ),
              const SizedBox(height: 12),
              // Badges Grid
              unlockedBadgesAsync.when(
                data: (unlockedList) {
                  final unlockedIds = unlockedList.map((u) => u.badgeId).toSet();

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: allBadgesCatalog.length,
                    itemBuilder: (context, index) {
                      final badge = allBadgesCatalog[index];
                      final isUnlocked = unlockedIds.contains(badge.id) || currentXp >= badge.requiredXp;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isUnlocked ? AppColors.darkCard : AppColors.darkBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isUnlocked ? AppColors.gold500.withOpacity(0.5) : AppColors.darkBorder,
                            width: isUnlocked ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              badge.icon,
                              style: TextStyle(
                                fontSize: 36,
                                color: isUnlocked ? null : Colors.white24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              badge.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isUnlocked ? Colors.white : Colors.white38,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              badge.description,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUnlocked ? const Color(0xFF8A9BAE) : Colors.white24,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold500)),
                error: (e, _) => Center(child: Text('Hata: $e')),
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
