import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/audio_download_service.dart';
import '../../../../core/services/audio_sync_service.dart';
import '../../../../core/services/battery_optimization_service.dart';
import '../../../../core/services/google_drive_backup_service.dart';
import '../../../../core/services/google_oauth_sheet.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/sound_pool_service.dart';
import '../../../../core/services/cloud_sync_engine.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../gamification/models/user_rank.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../providers/settings_provider.dart';
import '../../../hatim/providers/hatim_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import 'widgets_preview_screen.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../dashboard/presentation/widgets/whats_new_bottom_sheet.dart';
import '../../../namaz_vakitleri/presentation/widgets/prayer_notification_settings_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _userNameController;
  late TextEditingController _feedbackEmailController;
  late TextEditingController _feedbackMessageController;

  bool _isGoogleSignedIn = false;
  String _googleUserEmail = '';
  String _googleUserName = '';
  String _lastBackupTime = 'Yükleniyor...';
  bool _isAutoBackupEnabled = false;
  bool _isProcessingBackup = false;

  bool _isFeedbackExpanded = false;
  String? _selectedFeedbackType;
  bool _isSendingFeedback = false;

  Widget _buildAvatarImage(String imagePath) {
    if (imagePath.startsWith('/') || imagePath.contains(':\\') || (!imagePath.startsWith('assets/') && File(imagePath).existsSync())) {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        cacheWidth: 160,
        cacheHeight: 160,
        errorBuilder: (_, __, ___) => const Center(child: Text('👤', style: TextStyle(fontSize: 28))),
      );
    } else {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        cacheWidth: 160,
        cacheHeight: 160,
        errorBuilder: (_, __, ___) => const Center(child: Text('👤', style: TextStyle(fontSize: 28))),
      );
    }
  }

  String _getSoundDisplayName(String soundKey, AppLocalizations l10n) {
    if (soundKey.contains('Bülbül') || soundKey.contains('Nightingale') || soundKey.contains('bulbul')) {
      return l10n.settingsSoundNightingale;
    } else if (soundKey.contains('Kumru') || soundKey.contains('Dove') || soundKey.contains('kumru')) {
      return l10n.settingsSoundDove;
    } else if (soundKey.contains('Sessiz') || soundKey.contains('Silent')) {
      return l10n.isTurkish ? 'Sessiz' : 'Silent';
    } else {
      return l10n.settingsSoundDefaultClick;
    }
  }

  String _soundDisplayToRaw(String display) {
    if (display.contains('Bülbül') || display.contains('Nightingale')) {
      return 'Bülbül Sesi';
    } else if (display.contains('Kumru') || display.contains('Dove')) {
      return 'Kumru Sesi';
    } else if (display.contains('Sessiz') || display.contains('Silent')) {
      return 'Sessiz';
    } else {
      return 'Varsayılan (Tıklama Sesi)';
    }
  }


  final List<String> _builtInAvatars = [
    'assets/images/avatar_male_1.png',
    'assets/images/avatar_male_2.png',
    'assets/images/avatar_male_3.png',
    'assets/images/avatar_female_1.png',
    'assets/images/avatar_female_2.png',
    'assets/images/avatar_female_3.png',
  ];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(userSettingsProvider);
    _userNameController = TextEditingController(text: settings.userDisplayName);
    _feedbackEmailController = TextEditingController();
    _feedbackMessageController = TextEditingController();
    _loadGoogleDriveStatus();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _feedbackEmailController.dispose();
    _feedbackMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadGoogleDriveStatus() async {
    try {
      final service = ref.read(googleDriveBackupServiceProvider);
      final signedIn = await service.isSignedIn();
      final email = await service.getUserEmail() ?? '';
      final name = await service.getUserName() ?? '';
      final lastTime = await service.getLastBackupTimeFormatted();
      final autoBackup = await service.isAutoBackupEnabled();

      if (mounted) {
        setState(() {
          _isGoogleSignedIn = signedIn;
          _googleUserEmail = email;
          _googleUserName = name;
          _lastBackupTime = lastTime;
          _isAutoBackupEnabled = autoBackup;
        });
      }
    } catch (e, stack) {
      debugPrint('[SettingsScreen] _loadGoogleDriveStatus error: $e\n$stack');
      if (mounted) {
        setState(() {
          _isGoogleSignedIn = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final activeSession = ref.read(activeSessionProvider);
    final success = await GoogleOAuthSheet.startOAuth(context, sessionId: activeSession.id);
    if (success) {
      final sp = await SharedPreferences.getInstance();
      final isDefault = activeSession.id == UserSession.defaultSessionId;
      final email = sp.getString('GoogleDrive_UserEmail_${activeSession.id}') ??
          (isDefault ? sp.getString('GoogleDrive_UserEmail') : null);
      if (email != null && email.isNotEmpty) {
        final updated = activeSession.copyWith(isCloud: true, email: email);
        await ref.read(sessionProvider.notifier).updateSession(updated);
      }
      await _loadGoogleDriveStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.translate('Settings_GoogleDriveConnected'))),
        );
      }
    }
  }

  Future<void> _handleGoogleSignOut() async {
    final service = ref.read(googleDriveBackupServiceProvider);
    await service.signOut();
    final activeSession = ref.read(activeSessionProvider);
    final updated = activeSession.copyWith(isCloud: false, email: null);
    await ref.read(sessionProvider.notifier).updateSession(updated);
    await _loadGoogleDriveStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.translate('Settings_GoogleDriveSignedOut'))),
      );
    }
  }

  Future<void> _syncNow() async {
    final isTr = context.l10n.isTurkish;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final driveService = ref.read(googleDriveBackupServiceProvider);
    final isSignedIn = await driveService.isSignedIn();
    if (!isSignedIn) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            isTr
                ? '⚠️ Google Drive hesabınız bağlı değil. Lütfen önce yukarıdaki bölümden Google ile giriş yapın.'
                : '⚠️ Google Drive is not connected. Please sign in with Google first.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() => _isProcessingBackup = true);
    try {
      final success = await CloudSyncEngine.instance.pullAndMerge(ref, force: true);
      if (mounted) {
        ref.invalidate(databaseProvider);
        ref.invalidate(hatimStatsProvider);
        ref.invalidate(hatimListStreamProvider);
        ref.invalidate(activeMukabeleHatimProvider);
        await _loadGoogleDriveStatus();
        await ref.read(userSettingsProvider.notifier).reloadSettings();
        ref.invalidate(dailyGoalsStatusProvider);
        ref.invalidate(userProfileStreamProvider);
        ref.invalidate(userStreakStreamProvider);
        ref.invalidate(diamondCountProvider);
        ref.invalidate(goldCountProvider);
        ref.read(badgeRefreshTriggerProvider.notifier).state++;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (isTr ? '✅ Cihazlar arası senkronizasyon başarıyla tamamlandı!' : '✅ Cross-device sync completed successfully!')
                  : (isTr ? 'Buluttaki verileriniz güncel (yeni bir değişiklik yok).' : 'Cloud data is already up to date.'),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Senkronizasyon hatası: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Future<void> _backupToCloud() async {
    setState(() => _isProcessingBackup = true);
    final service = ref.read(googleDriveBackupServiceProvider);
    try {
      await service.backupToCloud();
      await _loadGoogleDriveStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.translate('Settings_CloudBackupSuccess'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Future<void> _restoreFromCloud() async {
    final service = ref.read(googleDriveBackupServiceProvider);
    setState(() => _isProcessingBackup = true);

    try {
      final backups = await service.listCloudBackups();
      setState(() => _isProcessingBackup = false);

      if (!mounted) return;

      if (backups.isEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(context.l10n.settingsRestoreFromCloud, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(context.l10n.isTurkish
                ? 'Google Drive bulutundaki varsayılan yedek dosyası indirilip geri yüklenecektir.'
                : 'The default backup file on Google Drive cloud will be downloaded and restored.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.l10n.commonCancel)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF236B56),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.l10n.settingsRestoreFromCloud),
              ),
            ],
          ),
        );

        if (confirm != true) return;
        setState(() => _isProcessingBackup = true);
        final count = await service.restoreFromCloud();
        ref.invalidate(databaseProvider);
        await _loadGoogleDriveStatus();
        await ref.read(userSettingsProvider.notifier).reloadSettings();
        ref.invalidate(dailyGoalsStatusProvider);
        ref.invalidate(userProfileStreamProvider);
        ref.invalidate(userStreakStreamProvider);
        ref.read(badgeRefreshTriggerProvider.notifier).state++;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.isTurkish ? '✅ $count zikir ve ayarlarınız başarıyla geri yüklendi!' : '✅ $count dhikr and settings successfully restored!')),
          );
        }
        return;
      }

      final selectedBackup = await showModalBottomSheet<CloudBackupInfo>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          final colors = ctx.colors;
          final l10n = context.l10n;
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.bottomSheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderStroke,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('☁️', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      l10n.translate('Settings_SelectCloudBackup'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.translate('Settings_SelectCloudBackupDesc'),
                  style: TextStyle(fontSize: 12, color: colors.secondaryTextAlt),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: backups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final item = backups[index];
                      final dateStr = '${item.modifiedTime.day.toString().padLeft(2, '0')}.${item.modifiedTime.month.toString().padLeft(2, '0')}.${item.modifiedTime.year} ${item.modifiedTime.hour.toString().padLeft(2, '0')}:${item.modifiedTime.minute.toString().padLeft(2, '0')}';
                      return InkWell(
                        onTap: () => Navigator.of(ctx).pop(item),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: index == 0 ? colors.accent : colors.borderStroke,
                              width: index == 0 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? colors.accent.withValues(alpha: 0.15)
                                      : colors.pageBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(item.isLocal ? '💾' : (index == 0 ? '⭐' : '☁️'), style: const TextStyle(fontSize: 18)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.displayName,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primaryText,
                                          ),
                                        ),
                                        if (index == 0) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(context.l10n.translate('Settings_Newest'), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '📅 $dateStr • 📱 ${item.deviceName}',
                                      style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt),
                                    ),
                                    if (item.streakCount != null || item.zikirCount != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '🔥 Seri: ${item.streakCount ?? 0} • 📿 Zikir: ${item.zikirCount ?? 0}',
                                        style: TextStyle(fontSize: 11, color: colors.accent, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(Icons.download_rounded, color: colors.accent, size: 22),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

      if (selectedBackup == null) return;

      setState(() => _isProcessingBackup = true);
      final count = await service.restoreFromCloud(
        fileId: selectedBackup.fileId,
        revisionId: selectedBackup.revisionId,
      );
      ref.invalidate(databaseProvider);
      await _loadGoogleDriveStatus();
      await ref.read(userSettingsProvider.notifier).reloadSettings();
      ref.invalidate(dailyGoalsStatusProvider);
      ref.invalidate(userProfileStreamProvider);
      ref.invalidate(userStreakStreamProvider);
      ref.read(badgeRefreshTriggerProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $count zikir ve tüm verileriniz (${selectedBackup.displayName}) başarıyla geri yüklendi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Geri yükleme hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Future<void> _restoreFromLocalFile() async {
    setState(() => _isProcessingBackup = true);
    final service = ref.read(googleDriveBackupServiceProvider);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _isProcessingBackup = false);
        return;
      }

      final filePath = result.files.single.path!;
      final count = await service.restoreFromLocalFilePath(filePath);
      await _loadGoogleDriveStatus();
      await ref.read(userSettingsProvider.notifier).reloadSettings();
      ref.invalidate(dailyGoalsStatusProvider);
      ref.invalidate(userProfileStreamProvider);
      ref.invalidate(userStreakStreamProvider);
      ref.read(badgeRefreshTriggerProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.isTurkish ? '✅ $count zikir ve ayarlarınız yerel yedekten başarıyla geri yüklendi!' : '✅ $count dhikr and settings successfully restored from local backup!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yerel yedek yükleme hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Future<void> _exportLocalBackup() async {
    setState(() => _isProcessingBackup = true);
    final service = ref.read(googleDriveBackupServiceProvider);
    try {
      await service.shareLocalBackupFile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dışa aktarma hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  void _showAvatarSelectionSheet(BuildContext context, AppThemeColors colors) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.bottomSheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: colors.borderStroke, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.translate('Settings_PickAvatar'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.primaryText),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: _builtInAvatars.map((av) {
                    return GestureDetector(
                      onTap: () {
                        ref.read(userSettingsProvider.notifier).setUserProfileImage(av);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.accent, width: 2),
                        ),
                        child: ClipOval(
                          child: Image.asset(av, fit: BoxFit.cover, cacheWidth: 160, cacheHeight: 160),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: Text(l10n.translate('Settings_PickFromDevice'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                        );
                        if (result != null && result.files.single.path != null) {
                          final sourceFile = File(result.files.single.path!);
                          final docDir = await getApplicationDocumentsDirectory();
                          final ext = p.extension(sourceFile.path);
                          final targetPath = p.join(docDir.path, 'profile_custom_${DateTime.now().millisecondsSinceEpoch}$ext');
                          await sourceFile.copy(targetPath);
                          await ref.read(userSettingsProvider.notifier).setUserProfileImage(targetPath);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.isTurkish ? '✅ Profil fotoğrafı başarıyla güncellendi!' : '✅ Profile photo updated successfully!')),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Fotoğraf seçme hatası: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTime(BuildContext context, String initialTime, Function(String) onSelected) async {
    final parts = initialTime.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = int.tryParse(parts.last) ?? 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );

    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onSelected(formatted);
    }
  }

  void _showFiqhLibraryModal(BuildContext context, AppThemeColors colors) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.bottomSheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: colors.borderStroke, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('📚', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Text(l10n.settingsFiqhLibrary, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.primaryText)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.isTurkish
                      ? 'Namaz, zikir, oruç ve Kur\'an tilaveti ile ilgili temel İslam fıkhı kuralları ve Diyanet fetvaları kitaplığına doğrudan erişebilirsiniz.'
                      : 'Access fundamental Islamic fiqh rules and fatwas on prayer, dhikr, fasting, and Quran recitation.',
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: colors.secondaryTextAlt),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.commonClose, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBatteryOptimizationModal(BuildContext context, AppThemeColors colors) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          decoration: BoxDecoration(
            color: colors.bottomSheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: colors.borderStroke, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                ),
                child: const Center(child: Text('🔋', style: TextStyle(fontSize: 26))),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.translate('Settings_BatteryGuideTitle'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.primaryText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.translate('Settings_BatteryGuideDesc'),
                style: TextStyle(fontSize: 11.5, color: colors.secondaryTextAlt, height: 1.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // 1. Adım: Otomatik Başlatma
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Text('🚀', style: TextStyle(fontSize: 15)),
                  label: Text(l10n.translate('Settings_BatteryStep1'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final ok = await BatteryOptimizationService.openAutoStart();
                    if (!ok && ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(l10n.isTurkish ? 'Ayarlar açılamadı, lütfen Güvenlik uygulamasından Otomatik Başlatma\'yı açın.' : 'Settings could not be opened, please enable Auto-Start in Security app.')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // 2. Adım: Kısıtlama Yok
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Text('🔋', style: TextStyle(fontSize: 15)),
                  label: Text(l10n.translate('Settings_BatteryStep2'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final ok = await BatteryOptimizationService.openBatterySaverNoRestrictions();
                    if (!ok && ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(l10n.isTurkish ? 'Ayarlar açılamadı, lütfen Pil Tasarrufu\'nu Kısıtlama Yok olarak ayarlayın.' : 'Settings could not be opened, please set Battery Saver to No Restrictions.')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // 3. Adım: Alarmlar ve Hatırlatıcılar İzni (Android 14 / Xiaomi 14 İçin Kritik)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Text('⏰', style: TextStyle(fontSize: 15)),
                  label: Text(l10n.isTurkish ? '3. Adım: Alarmlar ve Hatırlatıcılar İzni' : 'Step 3: Alarms & Reminders Permission', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await BatteryOptimizationService.openExactAlarmSettings();
                  },
                ),
              ),
              const SizedBox(height: 10),

              // 4. Adım: Xiaomi HyperOS / MIUI Gelişmiş İzinler (Kayan Bildirim & Kilit Ekranı)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Text('📱', style: TextStyle(fontSize: 15)),
                  label: Text(l10n.isTurkish ? '4. Adım: HyperOS / MIUI İzinleri' : 'Step 4: HyperOS / MIUI Permissions', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await BatteryOptimizationService.openAppPermissions();
                  },
                ),
              ),
              const SizedBox(height: 10),

              // 5. Adım: Bildirim İzinleri
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primaryText,
                    side: BorderSide(color: colors.borderStroke),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Text('🔔', style: TextStyle(fontSize: 14)),
                  label: Text(l10n.translate('Settings_BatteryStep3'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await BatteryOptimizationService.openNotificationSettings();
                  },
                ),
              ),
              const SizedBox(height: 14),

              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.commonClose, style: TextStyle(color: colors.secondaryTextAlt, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final settings = ref.watch(userSettingsProvider);
    final settingsNotifier = ref.read(userSettingsProvider.notifier);

    final activeThemeKey = ref.watch(themeNotifierProvider);
    final activeFontFamily = ref.watch(quranFontFamilyProvider);
    final activeFontSize = ref.watch(quranFontSizeProvider);
    final activeLineHeight = ref.watch(quranLineHeightProvider);
    final highlightDivineWords = ref.watch(highlightDivineWordsProvider);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            Text(
              l10n.settingsSubtitle,
              style: TextStyle(
                fontSize: 11,
                color: colors.secondaryTextAlt,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          // ==========================================
          // 1. PROFİL & ÇOKLU OTURUM YÖNETİMİ
          // ==========================================
          _buildCategoryHeader(l10n.settingsProfileSection, colors.primaryText),
          _buildContainerCard(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Multi-Account Switcher & Management Tile
                InkWell(
                  onTap: () => context.push('/sessions'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.people_alt_rounded, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Çoklu Oturum ve Hesaplar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Aktif: ${ref.watch(activeSessionProvider).displayName} (${ref.watch(sessionListProvider).length} Profil Kayıtlı)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.secondaryTextAlt,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: colors.accent, size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Avatar + User Display Name Entry Row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showAvatarSelectionSheet(context, colors),
                      child: Stack(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.accent, width: 2),
                            ),
                            child: ClipOval(
                              child: _buildAvatarImage(settings.userProfileImage),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: colors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(Icons.edit, size: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.translate('Settings_ProfileName').toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colors.secondaryTextAlt)),
                          const SizedBox(height: 4),
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.cardBackgroundAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.borderStroke),
                            ),
                            child: TextField(
                              controller: _userNameController,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.primaryText),
                              decoration: InputDecoration(
                                hintText: l10n.settingsProfileNamePlaceholder,
                                hintStyle: TextStyle(fontSize: 13, color: colors.secondaryTextAlt),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: InputBorder.none,
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.check_rounded, size: 18, color: colors.accent),
                                  onPressed: () {
                                    settingsNotifier.setUserDisplayName(_userNameController.text);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l10n.commonSuccess)),
                                    );
                                  },
                                ),
                              ),
                              onSubmitted: (val) => settingsNotifier.setUserDisplayName(val),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Google Cloud Sync Section: Conditional Display
                Text(l10n.settingsGoogleCloudAccount, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primaryText)),
                const SizedBox(height: 8),

                if (!_isGoogleSignedIn) ...[
                  // Case A: Signed Out - Display Sign In Prompt Card Button
                  Text(
                    l10n.settingsGoogleCloudDesc,
                    style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _handleGoogleSignIn,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.cardBackgroundAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.accent, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Text('🔑', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.settingsLinkGoogleAccount,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: colors.primaryText,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_rounded, size: 18, color: colors.accent),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Case B: Signed In - Display Account Details, Status, Backup and Restore Buttons
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981), // Green connected dot
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_googleUserName.isNotEmpty)
                              Text(
                                _googleUserName,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText),
                              ),
                            Text(
                              _googleUserEmail,
                              style: TextStyle(fontSize: 11.5, color: colors.secondaryTextAlt),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: _handleGoogleSignOut,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Last backup date box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.cardBackgroundAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${l10n.settingsLastCloudBackup} $_lastBackupTime',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Auto Cloud Backup Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.settingsAutoCloudBackup, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText)),
                            const SizedBox(height: 2),
                            Text(l10n.settingsAutoCloudBackupDesc, style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isAutoBackupEnabled,
                        activeTrackColor: colors.accent,
                        onChanged: (val) async {
                          setState(() => _isAutoBackupEnabled = val);
                          final service = ref.read(googleDriveBackupServiceProvider);
                          await service.setAutoBackupEnabled(val);
                          if (val) {
                            final db = ref.read(databaseProvider);
                            GoogleDriveBackupService.triggerAutoBackupBackground(db, force: true);
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) _loadGoogleDriveStatus();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Multi-device sync action card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.cardBackgroundAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x5910B981)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🔄', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.isTurkish ? 'Çoklu Cihaz Senkronizasyonu' : 'Multi-Device Synchronization',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.isTurkish
                              ? 'Tablet, telefon ve bilgisayarınız arasında Kur\'an, hatim ve zikir verileriniz sıfır kayıpla otomatik eşitlenir.'
                              : 'Your Quran, hatim, and dhikr counts are automatically synced between your devices without any loss.',
                          style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: _isProcessingBackup
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(
                              l10n.isTurkish ? 'Cihazları Şimdi Eşitle' : 'Sync Devices Now',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _isProcessingBackup ? null : _syncNow,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pill Action Buttons (Buluta Yedekle & Buluttan Geri Yükle)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            backgroundColor: const Color(0xFFE8F5E9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: _isProcessingBackup
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                              : const Text('☁️', style: TextStyle(fontSize: 14)),
                          label: Text(l10n.settingsBackupToCloud, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          onPressed: _isProcessingBackup ? null : _backupToCloud,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            backgroundColor: const Color(0xFFE0F2FE),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: _isProcessingBackup
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)))
                              : const Text('☁️', style: TextStyle(fontSize: 14)),
                          label: Text(l10n.settingsRestoreFromCloud, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          onPressed: _isProcessingBackup ? null : _restoreFromCloud,
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 24),

                // Local Backup & Restore (.json / .zikirback / zip)
                Text('${l10n.settingsLocalDataSection} (.json / .zikirback)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primaryText)),
                const SizedBox(height: 8),

                // Auto Local Backup Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.settingsAutoLocalBackup, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText)),
                          const SizedBox(height: 2),
                          Text(l10n.settingsAutoLocalBackupDesc, style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt)),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.isAutoLocalBackupEnabled,
                      activeTrackColor: colors.accent,
                      onChanged: (val) => settingsNotifier.toggleAutoLocalBackup(val),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primaryText,
                          side: BorderSide(color: colors.borderStroke),
                          backgroundColor: colors.cardBackgroundAlt,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 15),
                        label: Text(l10n.settingsBackupToFile, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _exportLocalBackup,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.accent,
                          side: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
                          backgroundColor: colors.cardBackgroundAlt,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: Text(l10n.settingsRestoreFromFile, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _isProcessingBackup ? null : _restoreFromLocalFile,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ==========================================
          // 2. GÜNLÜK HEDEFLER
          // ==========================================
          _buildCategoryHeader(l10n.settingsDailyGoalsSection, colors.primaryText),
          _buildContainerCard(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.translate('Onboarding_Slide5Desc'), style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt)),
                const SizedBox(height: 14),

                // 0. 5 Vakit Farz Namaz (Zorunlu)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n.isTurkish ? '5 Vakit Farz Namaz' : '5 Daily Prayers',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primaryText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  l10n.isTurkish ? 'Zorunlu' : 'Mandatory',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.isTurkish
                                ? 'Altın gün için 5 vakit farz namazın kılınması esastır.'
                                : 'Completing 5 daily prayers is essential for Golden Day.',
                            style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: true,
                      activeTrackColor: colors.accent,
                      onChanged: null,
                    ),
                  ],
                ),
                const Divider(height: 20),

                // 1. Zikir Hedefi
                _buildGoalRow(
                  title: l10n.settingsZikirGoal,
                  count: settings.dailyZikirGoal,
                  isEnabled: settings.isDailyZikirGoalEnabled,
                  onToggle: (val) => settingsNotifier.toggleDailyZikirGoal(val),
                  onMinus: () => settingsNotifier.setDailyZikirGoal((settings.dailyZikirGoal - 10).clamp(10, 10000)),
                  onPlus: () => settingsNotifier.setDailyZikirGoal(settings.dailyZikirGoal + 10),
                  colors: colors,
                ),
                const Divider(height: 20),

                // 2. Günlük Kur'an Hedefi (Sayfa)
                _buildGoalRow(
                  title: l10n.settingsQuranGoal,
                  count: settings.dailyQuranGoal,
                  isEnabled: settings.isDailyQuranGoalEnabled,
                  onToggle: (val) => settingsNotifier.toggleDailyQuranGoal(val),
                  onMinus: () => settingsNotifier.setDailyQuranGoal((settings.dailyQuranGoal - 1).clamp(1, 100)),
                  onPlus: () => settingsNotifier.setDailyQuranGoal(settings.dailyQuranGoal + 1),
                  colors: colors,
                ),
                const Divider(height: 20),

                // 3. Hafızlık Tekrar Hedefi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.settingsHafizlikGoal, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.primaryText)),
                    Switch(
                      value: settings.isHafizlikRepeatGoalEnabled,
                      activeTrackColor: colors.accent,
                      onChanged: (val) => settingsNotifier.toggleHafizlikRepeatGoal(val),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // 4. Kaza Namazı Hedefi (Vakit)
                _buildGoalRow(
                  title: l10n.settingsKazaGoal,
                  count: settings.dailyKazaGoal,
                  isEnabled: settings.isDailyKazaGoalEnabled,
                  onToggle: (val) => settingsNotifier.toggleDailyKazaGoal(val),
                  onMinus: () => settingsNotifier.setDailyKazaGoal((settings.dailyKazaGoal - 1).clamp(1, 50)),
                  onPlus: () => settingsNotifier.setDailyKazaGoal(settings.dailyKazaGoal + 1),
                  colors: colors,
                ),
                const Divider(height: 20),

                // 5. Zaruri Hal (Özel Gün) Modu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n.isTurkish ? 'Zaruri Hal (Özel Gün) Modu' : 'Special Days / Excused Mode',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primaryText,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('🌸', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.isTurkish
                                ? 'Zaruri hallerde namaz ve Kur\'an hedefleri muaf sayılarak Altın Gün serisi korunur.'
                                : 'In excused situations, prayer and Quran goals are excused to protect Golden Day streak.',
                            style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.isExcusedModeEnabled,
                      activeTrackColor: colors.accent,
                      onChanged: (val) => settingsNotifier.toggleExcusedMode(val),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ==========================================
          // 4. EKRAN & KİLİT
          // ==========================================
          _buildCategoryHeader(l10n.translate('Settings_ScreenSection'), colors.primaryText),
          _buildContainerCard(
            colors: colors,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.translate('Settings_KeepScreenAwake'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                      const SizedBox(height: 3),
                      Text(
                        l10n.translate('Settings_KeepScreenAwakeDesc'),
                        style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt, height: 1.25),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: settings.isKeepScreenAwakeEnabled,
                  activeTrackColor: colors.accent,
                  onChanged: (val) => settingsNotifier.toggleKeepScreenAwake(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ==========================================
          // 5. DİL SEÇİMİ (LANGUAGE)
          // ==========================================
          _buildCategoryHeader(l10n.settingsLanguageTitle, colors.primaryText),
          Row(
            children: [
              Expanded(
                child: _buildSelectionCard(
                  title: 'Türkçe',
                  flag: '🇹🇷',
                  isSelected: l10n.isTurkish,
                  colors: colors,
                  onTap: () => settingsNotifier.setSelectedLanguage('tr'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSelectionCard(
                  title: 'English',
                  flag: '🇬🇧',
                  isSelected: l10n.isEnglish,
                  colors: colors,
                  onTap: () => settingsNotifier.setSelectedLanguage('en'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ==========================================
          // 6. GÖRÜNÜM & TEMA
          // ==========================================
          _buildCategoryHeader(l10n.settingsAppearanceSection, colors.primaryText),
          _buildContainerCard(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.settingsThemeSelection, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                Text(l10n.settingsThemeDesc, style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt)),
                const SizedBox(height: 14),

                // Row 1: Sistem, Açık, Koyu
                Row(
                  children: [
                    Expanded(
                      child: _buildThemeOptionCard(
                        title: l10n.settingsThemeSystem,
                        icon: '⚙️',
                        isSelected: activeThemeKey == AppThemeKeys.system,
                        colors: colors,
                        onTap: () => ref.read(themeNotifierProvider.notifier).setTheme(AppThemeKeys.system),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeOptionCard(
                        title: l10n.settingsThemeLight,
                        icon: '☀️',
                        isSelected: activeThemeKey == AppThemeKeys.greenLight || activeThemeKey == AppThemeKeys.creamLight,
                        colors: colors,
                        onTap: () {
                          final sub = ref.read(themeNotifierProvider.notifier).lightSubTheme;
                          ref.read(themeNotifierProvider.notifier).setTheme(sub);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeOptionCard(
                        title: l10n.settingsThemeDark,
                        icon: '🌙',
                        isSelected: activeThemeKey == AppThemeKeys.dark,
                        colors: colors,
                        onTap: () => ref.read(themeNotifierProvider.notifier).setTheme(AppThemeKeys.dark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 2: OLED / Siyah, Yüksek Kontrast
                Row(
                  children: [
                    Expanded(
                      child: _buildThemeOptionCard(
                        title: l10n.settingsThemeBlack,
                        icon: '⬛',
                        isSelected: activeThemeKey == AppThemeKeys.oledBlack,
                        colors: colors,
                        onTap: () => ref.read(themeNotifierProvider.notifier).setTheme(AppThemeKeys.oledBlack),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeOptionCard(
                        title: l10n.settingsThemeHighContrast,
                        icon: '⚡',
                        isSelected: activeThemeKey == AppThemeKeys.highContrast,
                        colors: colors,
                        onTap: () => ref.read(themeNotifierProvider.notifier).setTheme(AppThemeKeys.highContrast),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Açık Tema Stili (Visible when Açık or Sistem selected)
                if (activeThemeKey == AppThemeKeys.system || activeThemeKey == AppThemeKeys.greenLight || activeThemeKey == AppThemeKeys.creamLight) ...[
                  _buildDropdownRow(
                    title: l10n.settingsLightThemeStyle,
                    subtitle: l10n.settingsLightThemeStyleDesc,
                    value: ref.watch(lightSubThemeProvider) == AppThemeKeys.creamLight
                        ? l10n.settingsStyleClassicCream
                        : l10n.settingsStyleGreenMint,
                    items: [l10n.settingsStyleGreenMint, l10n.settingsStyleClassicCream],
                    colors: colors,
                    onChanged: (val) {
                      if (val == l10n.settingsStyleClassicCream || val == 'Açık Krem') {
                        ref.read(themeNotifierProvider.notifier).setLightSubTheme(AppThemeKeys.creamLight);
                      } else {
                        ref.read(themeNotifierProvider.notifier).setLightSubTheme(AppThemeKeys.greenLight);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // Sayaç Kuşu Seçimi
                () {
                  final unlockedBirdsAsync = ref.watch(unlockedBirdsProvider);
                  final selectedBirdItem = ref.watch(selectedBirdItemProvider);
                  final defaultBirdName = l10n.isTurkish ? 'Yeni Başlayan' : 'Novice Bird';
                  final unlockedBirds = unlockedBirdsAsync.valueOrNull ?? [
                    BirdSelectionItem(name: defaultBirdName, fileName: 'assets/animations/yeni_bird.json', badge: '🐣')
                  ];
                  final birdDisplayNames = unlockedBirds.map((b) => b.displayName).toList();
                  final currentValue = birdDisplayNames.contains(selectedBirdItem.displayName)
                      ? selectedBirdItem.displayName
                      : (birdDisplayNames.isNotEmpty ? birdDisplayNames.first : '🐣 $defaultBirdName');

                  return _buildDropdownRow(
                    title: l10n.settingsBirdSelection,
                    subtitle: l10n.settingsBirdSelectionDesc,
                    value: currentValue,
                    items: birdDisplayNames.isNotEmpty ? birdDisplayNames : [currentValue],
                    colors: colors,
                    onChanged: (val) {
                      if (val != null) {
                        final chosen = unlockedBirds.firstWhere(
                          (b) => b.displayName == val,
                          orElse: () => unlockedBirds.first,
                        );
                        ref.read(selectedBirdItemProvider.notifier).selectBird(chosen);
                        settingsNotifier.setSelectedBirdAvatar(val);
                      }
                    },
                  );
                }(),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ==========================================
          // MASAÜSTÜ & WINDOWS GİRİŞ TERCİHLERİ
          // ==========================================
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
            _buildCategoryHeader(l10n.isTurkish ? 'Masaüstü Giriş Tercihleri' : 'Desktop Input Preferences', colors.primaryText),
            _buildContainerCard(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fare Tekerleği
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.isTurkish ? '🖱️ Fare Tekerleği ile Zikir' : '🖱️ Mouse Wheel Dhikr', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                            const SizedBox(height: 2),
                            Text(l10n.isTurkish ? 'Tekerleği aşağı veya yukarı çevirerek zikri artırın' : 'Increment dhikr by scrolling mouse wheel up/down', style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt)),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.desktopMouseWheelEnabled,
                        activeTrackColor: colors.accent,
                        onChanged: (_) => settingsNotifier.toggleDesktopMouseWheel(),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Boş Alana Tıklama
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.isTurkish ? '👆 Boş Alana Tıklayarak Zikir' : '👆 Full Window Click Dhikr', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                            const SizedBox(height: 2),
                            Text(l10n.isTurkish ? 'Pencerenin herhangi bir boş alanına tıklayarak zikir çekin' : 'Click anywhere on the window to count dhikr', style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt)),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.desktopFullScreenClickEnabled,
                        activeTrackColor: colors.accent,
                        onChanged: (_) => settingsNotifier.toggleDesktopFullScreenClick(),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Space Tuşu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.isTurkish ? '␣ Boşluk (Space) Tuşu ile Zikir' : '␣ Spacebar Key Dhikr', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                            const SizedBox(height: 2),
                            Text(l10n.isTurkish ? 'Klavyede Boşluk (Space) tuşuna basarak zikir çekin' : 'Press Space key to increment counter', style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt)),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.desktopSpaceKeyEnabled,
                        activeTrackColor: colors.accent,
                        onChanged: (_) => settingsNotifier.toggleDesktopSpaceKey(),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Enter Tuşu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.isTurkish ? '↵ Enter Tuşu ile Zikir' : '↵ Enter Key Dhikr', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                            const SizedBox(height: 2),
                            Text(l10n.isTurkish ? 'Klavyede Enter tuşuna basarak zikir çekin' : 'Press Enter key to increment counter', style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt)),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.desktopEnterKeyEnabled,
                        activeTrackColor: colors.accent,
                        onChanged: (_) => settingsNotifier.toggleDesktopEnterKey(),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Yön Tuşları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.isTurkish ? '⇅ Yön Tuşları (Yukarı/Aşağı Ok)' : '⇅ Arrow Keys (Up/Down)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                            const SizedBox(height: 2),
                            Text(l10n.isTurkish ? 'Yukarı veya aşağı ok tuşuna basarak zikir çekin' : 'Press arrow up/down keys to increment counter', style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt)),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.desktopArrowKeysEnabled,
                        activeTrackColor: colors.accent,
                        onChanged: (_) => settingsNotifier.toggleDesktopArrowKeys(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ==========================================
          // 7. BİLDİRİMLER & HATIRLATICILAR
          // ==========================================
          _buildCategoryHeader(l10n.settingsNotificationsSection, colors.primaryText),
          _buildContainerCard(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zikir Hatırlatıcısı
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.settingsDhikrReminder, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                          const SizedBox(height: 2),
                          Text(l10n.settingsDhikrReminderDesc, style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt)),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.isZikirReminderEnabled,
                      activeTrackColor: colors.accent,
                      onChanged: (val) => settingsNotifier.toggleZikirReminder(val),
                    ),
                  ],
                ),
                if (settings.isZikirReminderEnabled) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primaryText,
                        side: BorderSide(color: colors.borderStroke),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      onPressed: () => _pickTime(context, settings.zikirReminderTime, (t) => settingsNotifier.setZikirReminderTime(t)),
                      child: Text(settings.zikirReminderTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
                const Divider(height: 20),

                // Kur'an Okuma Hatırlatıcısı
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.settingsQuranReminder, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                          const SizedBox(height: 2),
                          Text(l10n.settingsQuranReminderDesc, style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt)),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.isQuranReminderEnabled,
                      activeTrackColor: colors.accent,
                      onChanged: (val) => settingsNotifier.toggleQuranReminder(val),
                    ),
                  ],
                ),
                if (settings.isQuranReminderEnabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primaryText,
                          side: BorderSide(color: colors.borderStroke),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                        onPressed: () => _pickTime(context, settings.quranReminderTime, (t) => settingsNotifier.setQuranReminderTime(t)),
                        child: Text(settings.quranReminderTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () async {
                          await LocalNotificationService.showTestNotification(sound: settings.selectedReminderSound);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('🔔 ${l10n.settingsSendTestNotification} (${_getSoundDisplayName(settings.selectedReminderSound, l10n)})')),
                            );
                          }
                        },
                        child: Text(l10n.settingsSendTestNotification, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 20),

                // Namaz Vakitleri Bildirimleri (Entegre Bottom Sheet)
                InkWell(
                  onTap: () {
                    HapticService.selectionClick();
                    PrayerNotificationSettingsSheet.show(context);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.cardBackgroundAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: settings.isNamazReminderEnabled
                            ? colors.accent.withValues(alpha: 0.35)
                            : colors.borderStroke,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: settings.isNamazReminderEnabled
                                ? colors.accent.withValues(alpha: 0.15)
                                : colors.pageBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            settings.isNamazReminderEnabled ? '🕌' : '🔕',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.settingsPrayerNotifications,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                settings.isNamazReminderEnabled
                                    ? (l10n.isTurkish
                                        ? 'Açık (${settings.prayerNotifications.values.where((v) => v).length} vakit aktif)'
                                        : 'On (${settings.prayerNotifications.values.where((v) => v).length} prayers active)')
                                    : (l10n.isTurkish ? 'Kapalı' : 'Off'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: settings.isNamazReminderEnabled
                                      ? colors.accent
                                      : colors.secondaryTextAlt,
                                  fontWeight: settings.isNamazReminderEnabled
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.pageBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.borderStroke),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.isTurkish ? 'Ayarla' : 'Configure',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded,
                                  size: 16, color: colors.secondaryTextAlt),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Xiaomi / Pil Optimizasyonu
                InkWell(
                  onTap: () => _showBatteryOptimizationModal(context, colors),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.cardBackgroundAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderStroke),
                    ),
                    child: Row(
                      children: [
                        const Text('📱', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.settingsBatteryOptimization, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primaryText)),
                              Text(l10n.translate('Settings_BatteryOptimizationDesc'), style: TextStyle(fontSize: 9.5, color: colors.secondaryTextAlt)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: colors.secondaryTextAlt),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ==========================================
          // 8. SES SEÇENEKLERİ
          // ==========================================
          _buildCategoryHeader(l10n.settingsSoundSettingsSection, colors.primaryText),
          _buildContainerCard(
            colors: colors,
            child: Column(
              children: [
                _buildDropdownRow(
                  title: l10n.settingsDhikrSound,
                  subtitle: l10n.translate('Settings_DhikrSoundDesc'),
                  value: _getSoundDisplayName(settings.selectedDhikrSound, l10n),
                  items: [
                    l10n.settingsSoundNightingale,
                    l10n.settingsSoundDove,
                    l10n.settingsSoundDefaultClick,
                    l10n.isTurkish ? 'Sessiz' : 'Silent',
                  ],
                  colors: colors,
                  onChanged: (val) {
                    if (val != null) {
                      final rawName = _soundDisplayToRaw(val);
                      settingsNotifier.setSelectedDhikrSound(rawName);
                      SoundPoolService.playSoundByName(rawName);
                    }
                  },
                ),
                const Divider(height: 20),
                _buildDropdownRow(
                  title: l10n.settingsPrayerSound,
                  subtitle: l10n.translate('Settings_PrayerSoundDesc'),
                  value: _getSoundDisplayName(settings.selectedPrayerSound, l10n),
                  items: [
                    l10n.settingsSoundDove,
                    l10n.settingsSoundNightingale,
                    l10n.settingsSoundDefaultClick,
                    l10n.isTurkish ? 'Sessiz' : 'Silent',
                  ],
                  colors: colors,
                  onChanged: (val) {
                    if (val != null) {
                      final rawName = _soundDisplayToRaw(val);
                      settingsNotifier.setSelectedPrayerSound(rawName);
                      SoundPoolService.playSoundByName(rawName);
                    }
                  },
                ),
                const Divider(height: 20),
                _buildDropdownRow(
                  title: l10n.settingsReminderSound,
                  subtitle: l10n.translate('Settings_ReminderSoundDesc'),
                  value: _getSoundDisplayName(settings.selectedReminderSound, l10n),
                  items: [
                    l10n.settingsSoundNightingale,
                    l10n.settingsSoundDove,
                    l10n.settingsSoundDefaultClick,
                  ],
                  colors: colors,
                  onChanged: (val) {
                    if (val != null) {
                      final rawName = _soundDisplayToRaw(val);
                      settingsNotifier.setSelectedReminderSound(rawName);
                      SoundPoolService.playSoundByName(rawName);
                    }
                  },
                ),
                const Divider(height: 20),
                _buildDropdownRow(
                  title: l10n.settingsCongratulationSound,
                  subtitle: l10n.translate('Settings_CongratulationSoundDesc'),
                  value: _getSoundDisplayName(settings.selectedCongratulationSound, l10n),
                  items: [
                    l10n.settingsSoundNightingale,
                    l10n.settingsSoundDove,
                    l10n.settingsSoundDefaultClick,
                  ],
                  colors: colors,
                  onChanged: (val) {
                    if (val != null) {
                      final rawName = _soundDisplayToRaw(val);
                      settingsNotifier.setSelectedCongratulationSound(rawName);
                      SoundPoolService.playSoundByName(rawName);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ==========================================
          // 9. KUR'AN-I KERİM AYARLARI
          // ==========================================
          _buildCategoryHeader(l10n.settingsKuranSection, colors.primaryText),
          _buildContainerCard(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdownRow(
                  title: l10n.translate('Settings_QuranTheme'),
                  subtitle: l10n.translate('Settings_QuranThemeDesc'),
                  value: settings.selectedQuranTheme,
                  items: [
                    l10n.translate('Settings_ThemeClassicYellow'),
                    l10n.translate('Settings_ThemeWhite'),
                    l10n.translate('Settings_ThemeNight'),
                    l10n.translate('Settings_ThemeSepia'),
                  ],
                  colors: colors,
                  onChanged: (val) => val != null ? settingsNotifier.setSelectedQuranTheme(val) : null,
                ),
                const SizedBox(height: 14),

                _buildDropdownRow(
                  title: l10n.translate('Settings_EzberTheme'),
                  subtitle: l10n.translate('Settings_EzberThemeDesc'),
                  value: settings.selectedEzberTheme,
                  items: [
                    l10n.translate('Settings_ThemeWhite'),
                    l10n.translate('Settings_ThemeClassicYellow'),
                    l10n.translate('Settings_ThemeNight'),
                  ],
                  colors: colors,
                  onChanged: (val) => val != null ? settingsNotifier.setSelectedEzberTheme(val) : null,
                ),
                const Divider(height: 24),

                // Görünüm Önizleme Kartı (Preview Card)
                Text(l10n.translate('Settings_Preview'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F4EC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2DDD2)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: activeFontFamily,
                      fontSize: activeFontSize.clamp(16.0, 72.0),
                      fontWeight: settings.isBoldArabic ? FontWeight.bold : FontWeight.normal,
                      color: const Color(0xFF1B1917),
                      height: activeLineHeight,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Yazı Tipi Seçimi (3 Font Cards)
                Text(l10n.translate('Settings_FontFamily'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildFontCard(
                        title: 'Amasya Abay',
                        fontCode: 'AmasyaAbay',
                        isSelected: activeFontFamily == 'AmasyaAbay',
                        colors: colors,
                        onTap: () => ref.read(quranFontFamilyProvider.notifier).setFont('AmasyaAbay'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFontCard(
                        title: 'mushaf',
                        fontCode: 'mushaf',
                        isSelected: activeFontFamily == 'mushaf',
                        colors: colors,
                        onTap: () => ref.read(quranFontFamilyProvider.notifier).setFont('mushaf'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFontCard(
                        title: 'mushaf_bold',
                        fontCode: 'mushaf_bold',
                        isSelected: activeFontFamily == 'mushaf_bold',
                        colors: colors,
                        onTap: () => ref.read(quranFontFamilyProvider.notifier).setFont('mushaf_bold'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tipografi Ayarları (Yazı Boyutu)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.translate('Settings_FontSize'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText)),
                    Text('${activeFontSize.toInt()} pt', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.accent)),
                  ],
                ),
                Slider(
                  value: activeFontSize.clamp(16.0, 72.0),
                  min: 16,
                  max: 72,
                  activeColor: colors.accent,
                  onChanged: (val) => ref.read(quranFontSizeProvider.notifier).setFontSize(val),
                ),
                const SizedBox(height: 8),

                // Satır Aralığı (Satır Yüksekliği)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.translate('Settings_LineSpacing'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText)),
                    Text('${activeLineHeight.toStringAsFixed(1)}x', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.accent)),
                  ],
                ),
                Slider(
                  value: activeLineHeight.clamp(1.4, 3.2),
                  min: 1.4,
                  max: 3.2,
                  divisions: 18,
                  activeColor: colors.accent,
                  onChanged: (val) => ref.read(quranLineHeightProvider.notifier).setLineHeight(val),
                ),
                const SizedBox(height: 8),

                // Kalın Arapça Metin
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.translate('Settings_BoldArabic'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.primaryText)),
                    Switch(
                      value: settings.isBoldArabic,
                      activeTrackColor: colors.accent,
                      onChanged: (val) => settingsNotifier.toggleBoldArabic(val),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Lafzatullâh ve Rab Lafızlarını Renklendir
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('Settings_DivineWords'),
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.primaryText),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.translate('Settings_DivineWordsDesc'),
                            style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: highlightDivineWords,
                      activeTrackColor: colors.accent,
                      onChanged: (val) => ref.read(highlightDivineWordsProvider.notifier).setEnabled(val),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Ezber Maskeleme Modu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.translate('Settings_MaskingMode'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.primaryText)),
                    Switch(
                      value: settings.isMaskingMode,
                      activeTrackColor: colors.accent,
                      onChanged: (val) => settingsNotifier.toggleMaskingMode(val),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Bulanıklaştırma Modu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.translate('Settings_BlurMode'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.primaryText)),
                    Switch(
                      value: settings.isBlurMode,
                      activeTrackColor: colors.accent,
                      onChanged: (val) => settingsNotifier.toggleBlurMode(val),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Dinlemeye Besmele ile Başla
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isTurkish ? 'Dinlemeye Besmele ile Başla' : 'Start Recitation with Bismillah',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.primaryText),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.isTurkish
                                ? 'Mukabele ve kelime takipli dinlemede tilavete başlarken Besmele-i Şerif okur'
                                : 'Recites Bismillah before beginning recitation in mukabele and talim modes',
                            style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: settings.isPlayBesmeleOnStartEnabled,
                      activeTrackColor: colors.accent,
                      onChanged: (val) => settingsNotifier.togglePlayBesmeleOnStart(val),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Hafızlık / Ezber ve Kıraat Sesleri İndir
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('Settings_AudioDownload'),
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.isTurkish
                                ? 'Diyanet İşleri Başkanlığı resmi kıraatleri (Osman Şahin & Mehmet Çevik) ile kelime senkronize sesler.'
                                : 'Official Diyanet recitations with synchronized word-by-word timestamps.',
                            style: TextStyle(fontSize: 10.5, color: colors.secondaryTextAlt),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Depolama ve İlerleme Kartı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.cardBackgroundAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.borderStroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                settings.downloadedAudioCount >= 6236
                                    ? Icons.check_circle_rounded
                                    : (settings.downloadedAudioCount > 0
                                        ? Icons.folder_zip_rounded
                                        : Icons.cloud_download_outlined),
                                size: 16,
                                color: settings.downloadedAudioCount >= 6236
                                    ? Colors.green
                                    : colors.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                settings.downloadedAudioCount >= 6236
                                    ? (l10n.isTurkish ? 'Tüm Kur\'an İndirildi' : 'All Quran Downloaded')
                                    : '${settings.downloadedAudioCount} / ${settings.totalAudioCount} ${l10n.isTurkish ? 'Ayet' : 'Verses'}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                ),
                              ),
                            ],
                          ),
                          if (settings.audioStorageSizeMb > 0)
                            Text(
                              '${settings.audioStorageSizeMb.toStringAsFixed(1)} MB',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.secondaryTextAlt),
                            ),
                        ],
                      ),
                      if (settings.isAudioDownloading) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: settings.audioDownloadProgress > 0 ? settings.audioDownloadProgress : null,
                            backgroundColor: colors.borderStroke,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              settings.audioDownloadStatus,
                              style: TextStyle(fontSize: 10.5, color: colors.primaryText, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '%${(settings.audioDownloadProgress * 100).toInt()}',
                              style: TextStyle(fontSize: 10.5, color: colors.accent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Aksiyon Butonları
                if (settings.isAudioDownloading) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: Text(
                        l10n.isTurkish ? 'İndirmeyi Durdur / İptal Et' : 'Cancel Download',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => settingsNotifier.cancelAudioDownload(),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            icon: Icon(
                              settings.downloadedAudioCount >= 6236
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.download_rounded,
                              size: 16,
                            ),
                            label: Text(
                              settings.downloadedAudioCount >= 6236
                                  ? (l10n.isTurkish ? 'Tekrar Kontrol Et' : 'Verify Audio')
                                  : (settings.downloadedAudioCount > 0
                                      ? (l10n.isTurkish ? 'Kalanı Tamamla' : 'Complete All')
                                      : (l10n.isTurkish ? 'Tümünü İndir' : 'Download All')),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => settingsNotifier.startAudioDownload(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.primaryText,
                              side: BorderSide(color: colors.borderStroke),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.menu_book_rounded, size: 16),
                            label: Text(
                              l10n.isTurkish ? 'Cüz Yönetimi' : 'Juz Manager',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _showJuzManagementBottomSheet(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (settings.downloadedAudioCount > 0) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 14),
                        label: Text(
                          l10n.isTurkish ? 'Tüm Ses Dosyalarını Sil' : 'Delete All Audio',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _confirmDeleteAllAudios(),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ==========================================
          // 10. DESTEK & BİLGİ
          // ==========================================
          _buildCategoryHeader(l10n.settingsAboutSection, colors.primaryText),
          _buildContainerCard(
            colors: colors,
            child: Column(
              children: [
                // 1. Geri Bildirim Gönder (Expandable)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isFeedbackExpanded = !_isFeedbackExpanded;
                      if (_isFeedbackExpanded &&
                          _feedbackEmailController.text.isEmpty &&
                          _googleUserEmail.isNotEmpty) {
                        _feedbackEmailController.text = _googleUserEmail;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text('✉️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.settingsFeedbackTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText,
                            ),
                          ),
                        ),
                        Icon(
                          _isFeedbackExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: colors.secondaryTextAlt,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isFeedbackExpanded) ...[
                  const SizedBox(height: 8),
                  // Geri Bildirim Türü (Feedback Type Picker)
                  Builder(
                    builder: (context) {
                      final feedbackTypes = l10n.isTurkish
                          ? const ['Geliştirme Önerisi', 'Hata Bildirimi', 'Soru/Diğer']
                          : const ['Improvement Suggestion', 'Bug Report', 'Question/Other'];
                      final currentType = (_selectedFeedbackType != null && feedbackTypes.contains(_selectedFeedbackType))
                          ? _selectedFeedbackType!
                          : feedbackTypes.first;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.cardBackgroundAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.borderStroke),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentType,
                            isExpanded: true,
                            dropdownColor: colors.cardBackgroundAlt,
                            style: TextStyle(fontSize: 12.5, color: colors.primaryText, fontWeight: FontWeight.w500),
                            icon: Icon(Icons.arrow_drop_down, color: colors.secondaryTextAlt),
                            items: feedbackTypes.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedFeedbackType = val);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _feedbackEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: 12.5, color: colors.primaryText),
                    decoration: InputDecoration(
                      hintText: l10n.settingsFeedbackEmailPlaceholder,
                      hintStyle: TextStyle(fontSize: 12.5, color: colors.secondaryTextAlt),
                      filled: true,
                      fillColor: colors.cardBackgroundAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.borderStroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.borderStroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _feedbackMessageController,
                    maxLines: 4,
                    minLines: 3,
                    style: TextStyle(fontSize: 12.5, color: colors.primaryText),
                    decoration: InputDecoration(
                      hintText: l10n.settingsFeedbackMessagePlaceholder,
                      hintStyle: TextStyle(fontSize: 12.5, color: colors.secondaryTextAlt),
                      filled: true,
                      fillColor: colors.cardBackgroundAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.borderStroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.borderStroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        elevation: 0,
                      ),
                      onPressed: _isSendingFeedback ? null : () => _sendFeedback(l10n),
                      child: _isSendingFeedback
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              l10n.settingsSendFeedbackBtn,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Divider(height: 16, color: colors.borderStroke),

                // 1.5. Ana Ekran Widget'ları
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WidgetsPreviewScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text('📱', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.isTurkish ? 'Ana Ekran Widget\'ları' : 'Home Screen Widgets',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText),
                              ),
                              Text(
                                l10n.isTurkish ? '9 farklı widget\'ı inceleyin ve ekleyin' : 'Explore and add 9 custom widgets',
                                style: TextStyle(fontSize: 10, color: colors.secondaryTextAlt),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
                Divider(height: 16, color: colors.borderStroke),

                // 2. Fıkıh Kitaplığı
                InkWell(
                  onTap: () => _showFiqhLibraryModal(context, colors),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text('📚', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(l10n.settingsFiqhLibrary, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
                Divider(height: 16, color: colors.borderStroke),

                // 3. Kullanım Kılavuzu & Tanıtım
                InkWell(
                  onTap: () {
                    context.push('/onboarding?fromSettings=true');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text('📖', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.translate('Settings_GuideBtn'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                              Text(
                                l10n.isTurkish ? 'Zikirce\'nin tüm özelliklerini animasyonlu keşfedin' : 'Explore all Zikirce features interactively',
                                style: TextStyle(fontSize: 10, color: colors.secondaryTextAlt),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
                Divider(height: 16, color: colors.borderStroke),

                // 4. Sürüm Notları / Yenilikler
                InkWell(
                  onTap: () {
                    HapticService.selectionClick();
                    WhatsNewBottomSheet.showHistory(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text('🚀', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.translate('Settings_ChangelogTileTitle'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                              Text(
                                l10n.translate('Settings_ChangelogTileSubtitle'),
                                style: TextStyle(fontSize: 10, color: colors.secondaryTextAlt),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
                Divider(height: 16, color: colors.borderStroke),

                // 5. Gizlilik Politikası
                InkWell(
                  onTap: () {
                    context.push('/privacy');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text('📄', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(l10n.settingsPrivacyPolicy, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText)),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Alt Bilgiler
          Center(
            child: Column(
              children: [
                Text(
                  l10n.translate('Settings_Version'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.secondaryTextAlt),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.translate('Settings_AllRightsReserved'),
                  style: TextStyle(fontSize: 9.5, color: colors.secondaryTextAlt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _sendFeedback(AppLocalizations l10n) async {
    final message = _feedbackMessageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isTurkish ? 'Lütfen bir mesaj yazın.' : 'Please write a message.',
          ),
        ),
      );
      return;
    }

    final feedbackTypes = l10n.isTurkish
        ? const ['Geliştirme Önerisi', 'Hata Bildirimi', 'Soru/Diğer']
        : const ['Improvement Suggestion', 'Bug Report', 'Question/Other'];

    final selectedType = (_selectedFeedbackType != null && feedbackTypes.contains(_selectedFeedbackType))
        ? _selectedFeedbackType!
        : feedbackTypes.first;

    final userEmail = _feedbackEmailController.text.trim();

    final subject = l10n.isTurkish
        ? 'Zikirce Geri Bildirim: $selectedType'
        : 'Zikirce Feedback: $selectedType';

    final body = l10n.isTurkish
        ? 'Gönderen E-posta: ${userEmail.isEmpty ? 'Belirtilmedi' : userEmail}\n\nMesaj:\n$message'
        : 'Sender Email: ${userEmail.isEmpty ? 'Not specified' : userEmail}\n\nMessage:\n$message';

    setState(() => _isSendingFeedback = true);

    try {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: 'theakar@windowslive.com',
        query: _encodeQueryParameters(<String, String>{
          'subject': subject,
          'body': body,
        }),
      );

      final launched = await launchUrl(
        emailLaunchUri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.isTurkish ? 'E-posta istemcisi açılıyor...' : 'Opening email client...',
            ),
          ),
        );
        _feedbackMessageController.clear();
        setState(() => _isFeedbackExpanded = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.isTurkish ? 'E-posta uygulaması açılamadı.' : 'Could not open email app.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isTurkish ? 'Geri bildirim gönderilemedi.' : 'Could not send feedback.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingFeedback = false);
      }
    }
  }

  Widget _buildCategoryHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildContainerCard({required AppThemeColors colors, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGoalRow({
    required String title,
    required int count,
    required bool isEnabled,
    required Function(bool) onToggle,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required AppThemeColors colors,
    bool hideSwitch = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.primaryText),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: colors.cardBackgroundAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.borderStroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onMinus,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.remove, size: 14, color: colors.primaryText),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primaryText),
                ),
              ),
              InkWell(
                onTap: onPlus,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.add, size: 14, color: colors.primaryText),
                ),
              ),
            ],
          ),
        ),
        if (!hideSwitch) ...[
          const SizedBox(width: 8),
          Switch(
            value: isEnabled,
            activeTrackColor: colors.accent,
            onChanged: onToggle,
          ),
        ],
      ],
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String flag,
    required bool isSelected,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? colors.cardBackground : colors.cardBackgroundAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? colors.accent : colors.borderStroke, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: colors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_rounded, size: 14, color: colors.accent),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOptionCard({
    required String title,
    required String icon,
    required bool isSelected,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.cardBackground : colors.cardBackgroundAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? colors.accent : colors.borderStroke, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: colors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.check, size: 11, color: colors.accent),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontCard({
    required String title,
    required String fontCode,
    required bool isSelected,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.cardBackground : colors.cardBackgroundAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? colors.accent : colors.borderStroke, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text('Aa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.primaryText)),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: colors.primaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownRow({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required AppThemeColors colors,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primaryText)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: colors.secondaryTextAlt)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: colors.cardBackgroundAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.borderStroke),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: items.contains(value) ? value : items.first,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: colors.primaryText),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.primaryText),
                  dropdownColor: colors.cardBackground,
                  items: items.map((it) {
                    return DropdownMenuItem<String>(
                      value: it,
                      child: Text(it),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showJuzManagementBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _JuzAudioManagementSheet(),
    );
  }

  Future<void> _confirmDeleteAllAudios() async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.isTurkish ? 'Tüm Sesleri Sil' : 'Delete All Audio',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.isTurkish
              ? 'İndirilmiş olan tüm Kur\'an ses dosyaları cihazınızdan silinecektir. Depolama alanı boşaltılacaktır. Devam etmek istiyor musunuz?'
              : 'All downloaded Quran audio files will be removed from your device storage. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(userSettingsProvider.notifier).deleteAllAudios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.isTurkish ? 'Tüm ses dosyaları başarıyla silindi.' : 'All audio files deleted.'),
          ),
        );
      }
    }
  }
}

class _JuzAudioManagementSheet extends ConsumerStatefulWidget {
  const _JuzAudioManagementSheet();

  @override
  ConsumerState<_JuzAudioManagementSheet> createState() => _JuzAudioManagementSheetState();
}

class _JuzAudioManagementSheetState extends ConsumerState<_JuzAudioManagementSheet> {
  final Map<int, ({int downloaded, int total})> _juzStatusMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    for (int j = 1; j <= 30; j++) {
      final status = await AudioDownloadService.getJuzDownloadStatus(j);
      _juzStatusMap[j] = status;
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSingleJuz(int j) async {
    final status = await AudioDownloadService.getJuzDownloadStatus(j);
    if (mounted) {
      setState(() {
        _juzStatusMap[j] = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final settings = ref.watch(userSettingsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderStroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isTurkish ? 'Cüz Bazlı Ses Yönetimi' : 'Juz Audio Manager',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.isTurkish
                          ? 'Dilediğiniz cüzü tek tek indirin veya yer açmak için silin.'
                          : 'Download or remove audio files per Juz.',
                      style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: colors.secondaryTextAlt,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Juz List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: 30,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final juz = index + 1;
                      final (startPage, endPage) = AudioSyncService.getJuzPageRange(juz);
                      final status = _juzStatusMap[juz] ?? (downloaded: 0, total: 0);
                      final isComplete = status.total > 0 && status.downloaded >= status.total;
                      final hasSome = status.downloaded > 0;
                      final isCurrentDownloading = settings.isAudioDownloading &&
                          settings.audioDownloadStatus.contains('$juz. Cüz');

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.cardBackgroundAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isComplete ? Colors.green.withAlpha(90) : colors.borderStroke,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Juz badge
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isComplete
                                    ? Colors.green.withAlpha(35)
                                    : colors.accent.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '$juz',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isComplete ? Colors.green : colors.accent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '$juz. Cüz',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: colors.primaryText,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '(Sayfa $startPage - $endPage)',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: colors.secondaryTextAlt,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isComplete
                                        ? (l10n.isTurkish
                                            ? '✅ Tamamı İndirildi (${status.total} Ayet)'
                                            : '✅ Downloaded (${status.total} Verses)')
                                        : (hasSome
                                            ? '${status.downloaded} / ${status.total} ${l10n.isTurkish ? 'Ayet İndirildi' : 'Verses'}'
                                            : (l10n.isTurkish ? 'İndirilmedi (${status.total} Ayet)' : 'Not downloaded')),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isComplete ? Colors.green : colors.secondaryTextAlt,
                                      fontWeight: isComplete ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Actions
                            if (isCurrentDownloading)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            else ...[
                              if (hasSome)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  color: Colors.redAccent,
                                  tooltip: l10n.isTurkish ? 'Cüzü Sil' : 'Delete Juz',
                                  onPressed: settings.isAudioDownloading
                                      ? null
                                      : () async {
                                          await ref
                                              .read(userSettingsProvider.notifier)
                                              .deleteJuzAudios(juz);
                                          await _refreshSingleJuz(juz);
                                        },
                                ),
                              IconButton(
                                icon: Icon(
                                  isComplete
                                      ? Icons.check_circle_rounded
                                      : (hasSome
                                          ? Icons.downloading_rounded
                                          : Icons.download_rounded),
                                  size: 22,
                                ),
                                color: isComplete ? Colors.green : colors.accent,
                                tooltip: isComplete
                                    ? (l10n.isTurkish ? 'Tekrar İndir' : 'Re-download')
                                    : (l10n.isTurkish ? 'Cüzü İndir' : 'Download Juz'),
                                onPressed: settings.isAudioDownloading
                                    ? null
                                    : () async {
                                        await ref
                                            .read(userSettingsProvider.notifier)
                                            .downloadJuz(juz);
                                        await _refreshSingleJuz(juz);
                                      },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
}
