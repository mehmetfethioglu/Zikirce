import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cloud_sync_engine.dart';
import '../theme/app_colors.dart';

/// Ekran başlığında veya profil alanında sessiz bulut senkronizasyonu
/// durumunu gösteren mikro gösterge bileşeni.
class CloudSyncAppBarBadge extends ConsumerWidget {
  const CloudSyncAppBarBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(cloudSyncProvider.select((s) => s.status));

    if (syncStatus == CloudSyncStatus.idle) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: (syncStatus == CloudSyncStatus.checking || syncStatus == CloudSyncStatus.syncing)
            ? Container(
                key: const ValueKey('badge_syncing'),
                width: 22,
                height: 22,
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: AppColors.gold500.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold400),
                ),
              )
            : syncStatus == CloudSyncStatus.success
                ? Container(
                    key: const ValueKey('badge_success'),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF22C55E),
                      size: 15,
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}
