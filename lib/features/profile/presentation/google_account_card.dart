import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/kilerce_backup_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/google_auth_sync_service.dart';
import '../domain/user_profile_service.dart';

class GoogleAccountCard extends StatefulWidget {
  const GoogleAccountCard({super.key});

  @override
  State<GoogleAccountCard> createState() => _GoogleAccountCardState();
}

class _GoogleAccountCardState extends State<GoogleAccountCard> {
  bool _isAdvancedExpanded = false;

  @override
  void initState() {
    super.initState();
    GoogleAuthSyncService.instance.addListener(_onServiceUpdate);
    UserProfileService.instance.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    GoogleAuthSyncService.instance.removeListener(_onServiceUpdate);
    UserProfileService.instance.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _handleGoogleSignIn() async {
    final result = await GoogleAuthSyncService.instance.signIn();

    if (!mounted) return;

    if (result.isCancelled) {
      return;
    }

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.errorMessage ?? 'Giriş yapılamadı.',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Check if cloud backup was found
    if (result.cloudBackup != null && result.cloudBackup!.exists) {
      _showCloudBackupFoundDialog(result.cloudBackup!);
    } else {
      // First time connecting: perform initial backup to Google Drive AppData
      await GoogleAuthSyncService.instance.uploadToCloud();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Google hesabınız başarıyla bağlandı ve verileriniz buluta yedeklendi!',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  void _showCloudBackupFoundDialog(CloudBackupInfo backup) {
    final dateStr = backup.modifiedTime != null
        ? '${backup.modifiedTime!.day}.${backup.modifiedTime!.month}.${backup.modifiedTime!.year} ${backup.modifiedTime!.hour.toString().padLeft(2, '0')}:${backup.modifiedTime!.minute.toString().padLeft(2, '0')}'
        : 'Mevcut';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.cloud_done_rounded, color: AppColors.primaryMint),
            SizedBox(width: 10),
            Text('Bulut Yedeği Bulundu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Google Drive hesabınızda ($dateStr) tarihli bir OrganicScore yedeği tespit edildi.',
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cihazınızdaki profil ve rozetleri buluttaki bu yedekle geri yüklemek ister misiniz?',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // User chooses to keep local data and overwrite cloud
              await GoogleAuthSyncService.instance.uploadToCloud();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.primaryEmerald,
                    content: Text('Cihazdaki güncel profil buluta kaydedildi.'),
                  ),
                );
              }
            },
            child: const Text('Cihaz Verisini Koru'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await GoogleAuthSyncService.instance.restoreFromCloud();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: success ? AppColors.primaryEmerald : AppColors.dangerRed,
                    content: Text(
                      success
                        ? 'Profil ve rozetleriniz Google Drive\'dan başarıyla yüklendi!'
                        : 'Yedek geri yüklenirken bir hata oluştu.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Buluttan Geri Yükle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Google Oturumundan Çıkılsın mı?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text(
          'Google hesabınızın bağlantısı kesilecek. Cihazınızdaki rozetler, puanlar ve tarama geçmişiniz kesinlikle silinmez, yerel olarak korunur.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await GoogleAuthSyncService.instance.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Google oturumu kapatıldı. Verileriniz cihazınızda korundu.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualSync() async {
    final success = await GoogleAuthSyncService.instance.uploadToCloud();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? AppColors.primaryEmerald : AppColors.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          success
              ? 'Tüm rozet ve profil verileri Google Drive ile eşitlendi.'
              : (GoogleAuthSyncService.instance.lastSyncMessage ?? 'Eşitleme sırasında bir hata oluştu.'),
        ),
      ),
    );
  }

  Future<void> _handleOfflineShareBackup() async {
    final backupJson = await KilerceBackupService.exportFullBackupJson();
    await Share.share(
      backupJson,
      subject: 'Kilerce Tam Yedeği (${DateTime.now().toString().substring(0, 10)})',
    );
  }

  Future<void> _showOfflineRestoreDialog() async {
    final controller = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('JSON Yedeğinden Yükle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daha önce kopyaladığınız JSON yedek metnini buraya yapıştırın:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '{"app": "Kilerce", ...}',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () async {
                final jsonStr = controller.text.trim();
                if (jsonStr.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await KilerceBackupService.importFullBackupJson(jsonStr);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: success ? AppColors.primaryEmerald : AppColors.dangerRed,
                        content: Text(
                          success
                              ? 'Kiler, tarif ve profil verileriniz başarıyla geri yüklendi!'
                              : 'Hata: Geçersiz yedekleme dosyası formatı.',
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
              ),
              child: const Text('Geri Yükle'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserProfileService.instance.profile;
    final isSyncing = GoogleAuthSyncService.instance.isSyncing;
    final isGoogleConnected = profile.isGoogleConnected;
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    final String lastBackupText = profile.lastBackupTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(profile.lastBackupTimestamp!)
            .toLocal()
            .toString()
            .substring(0, 16)
        : 'Henüz eşitlenmedi';

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isGoogleConnected ? AppColors.primaryEmerald.withValues(alpha: 0.35) : borderColor,
          width: isGoogleConnected ? 1.5 : 1.0,
        ),
        boxShadow: isGoogleConnected
            ? [
                BoxShadow(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isGoogleConnected) ...[
            // --- Logged Out View ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_sync_rounded,
                    color: AppColors.primaryMint,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Google Hesabı & Bulut Eşitleme',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Verilerini kaybetmeden cihazlar arası senkronize et',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Kazanılan rozetleri, seviyeni ve tarama istatistiklerini Google hesabınla eşitle. Cihaz değiştirsen bile verilerin güvende kalır.',
              style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: isSyncing ? null : _handleGoogleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1F1F1F),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFDADCE0), width: 1),
                  ),
                ),
                child: isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryEmerald),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Custom minimal Google G icon
                          _buildGoogleLogo(),
                          const SizedBox(width: 10),
                          const Text(
                            'Google ile Giriş Yap',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3C4043),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ] else ...[
            // --- Logged In View ---
            Row(
              children: [
                // Google profile avatar or initial
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.15),
                  backgroundImage: profile.googlePhotoUrl != null && profile.googlePhotoUrl!.isNotEmpty
                      ? NetworkImage(profile.googlePhotoUrl!)
                      : null,
                  child: profile.googlePhotoUrl == null || profile.googlePhotoUrl!.isEmpty
                      ? Text(
                          (profile.googleDisplayName?.isNotEmpty == true
                                  ? profile.googleDisplayName![0]
                                  : (profile.googleEmail?.isNotEmpty == true ? profile.googleEmail![0] : 'G'))
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryMint,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.googleDisplayName ?? profile.displayName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Google Bağlı',
                              style: TextStyle(
                                color: AppColors.primaryMint,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.googleEmail ?? '',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (context.isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync_rounded, size: 15, color: AppColors.primaryMint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Son Senkronizasyon: $lastBackupText',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textPrimary.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Actions Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: isSyncing ? null : _handleManualSync,
                    icon: isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 16),
                    label: Text(
                      isSyncing ? 'Eşitleniyor...' : 'Şimdi Eşitle',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: isSyncing ? null : _confirmSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 14),
                    label: const Text('Çıkış', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dangerRed,
                      side: BorderSide(color: AppColors.dangerRed.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // Advanced / Offline Backup Options Accordion
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              initiallyExpanded: _isAdvancedExpanded,
              onExpansionChanged: (v) => setState(() => _isAdvancedExpanded = v),
              title: Text(
                'Gelişmiş Çevrimdışı Yedekleme (JSON)',
                style: TextStyle(
                  fontSize: 11.5,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleOfflineShareBackup,
                        icon: const Icon(Icons.share_rounded, size: 14),
                        label: const Text('Paylaş / İndir', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showOfflineRestoreDialog,
                        icon: const Icon(Icons.file_upload_outlined, size: 14),
                        label: const Text('Metinden Yükle', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4285F4),
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          ),
        ),
      ),
    );
  }
}
