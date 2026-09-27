import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isProcessing = false;

  Future<void> _exportBackup(AppDatabase db) async {
    setState(() => _isProcessing = true);
    final path = await BackupService.createBackupFile(db);
    setState(() => _isProcessing = false);

    if (mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yedekleme dosyası hazırlandı ve paylaşıldı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text('Yedekleme & Geri Yükleme', style: AppTypography.headingSmall(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.security_rounded, color: AppColors.gold400, size: 28),
                    SizedBox(width: 12),
                    Text('Güvenli Yerel Yedekleme', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tüm zikirleriniz, serileriniz (streak), kaza namazlarınız ve hatim ilerlemeleriniz SHA-256 doğrulama ile şifrelenerek yedeklenir.',
                  style: TextStyle(color: Color(0xFF8A9BAE), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold500,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Icon(Icons.file_download_outlined),
                    label: const Text('Yedek Dosyası Oluştur (.zikirback)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isProcessing ? null : () => _exportBackup(db),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.gold400),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.file_upload_outlined),
                    label: const Text('Yedekten Geri Yükle (.zikirback / .json)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            setState(() => _isProcessing = true);
                            final messenger = ScaffoldMessenger.of(context);
                            final res = await BackupService.pickAndRestoreBackup(db);
                            if (!mounted) return;
                            setState(() => _isProcessing = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.success ? Colors.green : Colors.red,
                              ),
                            );
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
