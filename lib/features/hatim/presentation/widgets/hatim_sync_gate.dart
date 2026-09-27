import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/cloud_sync_engine.dart';
import '../../../../core/theme/app_colors.dart';

/// Mukabele ve Hatim ekranlarına girişlerde en güncel bulut yedeğini
/// garantiye alan akıllı ve modern senkronizasyon kapısı.
class HatimSyncGate {
  static Future<void> checkAndProceed({
    required BuildContext context,
    required WidgetRef ref,
    required VoidCallback onProceed,
  }) async {
    final syncState = ref.read(cloudSyncProvider);

    // Eğer arka planda bir eşitleme/denetleme yoksa doğrudan devam et
    if (syncState.status != CloudSyncStatus.checking &&
        syncState.status != CloudSyncStatus.syncing) {
      onProceed();
      return;
    }

    // Eşitleme sürüyorsa modern bir dialog ile en fazla 2.5 saniye bekle
    bool hasProceeded = false;
    Timer? timeoutTimer;

    void proceedOnce(BuildContext? dialogCtx) {
      if (!hasProceeded) {
        hasProceeded = true;
        timeoutTimer?.cancel();
        if (dialogCtx != null && Navigator.of(dialogCtx).canPop()) {
          Navigator.of(dialogCtx).pop();
        } else if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        onProceed();
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        // 2500ms maksimum bekleme emniyeti
        timeoutTimer = Timer(const Duration(milliseconds: 2500), () {
          proceedOnce(dialogCtx);
        });

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) proceedOnce(dialogCtx);
          },
          child: Consumer(
            builder: (ctx, watchRef, _) {
              final status = watchRef.watch(cloudSyncProvider.select((s) => s.status));
              if (status == CloudSyncStatus.idle ||
                  status == CloudSyncStatus.success ||
                  status == CloudSyncStatus.error) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  proceedOnce(dialogCtx);
                });
              }

              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.gold500.withValues(alpha: 0.3), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.gold500.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: AppColors.gold400,
                          strokeWidth: 2.8,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Son Okumanız Kontrol Ediliyor',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Diğer cihazınızda kaldığınız en güncel sayfa taranıyor...',
                        style: TextStyle(
                          color: Color(0xFF8A9BAE),
                          fontSize: 13,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.gold400,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.gold500.withValues(alpha: 0.2)),
                            ),
                          ),
                          onPressed: () => proceedOnce(dialogCtx),
                          child: const Text(
                            'Beklemeden Devam Et',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
