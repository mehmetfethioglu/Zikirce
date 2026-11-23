import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/google_drive_sync_service.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';

class _CloudDialogPalette {
  final bool isDark;

  const _CloudDialogPalette(this.isDark);

  factory _CloudDialogPalette.of(BuildContext context) =>
      _CloudDialogPalette(Theme.of(context).brightness == Brightness.dark);

  Color get card => isDark ? const Color(0xFF09090B) : Colors.white;
  Color get subtle =>
      isDark ? const Color(0xFF121216) : const Color(0xFFF8FAFC);
  Color get border =>
      isDark ? const Color(0xFF232329) : const Color(0xFFE2E8F0);
  Color get textPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);
  Color get textMuted =>
      isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
}

String _formatDateTimeShort(DateTime? dt) {
  if (dt == null) return '-';
  final d = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Ayarlar ekranı için kompakt Bulut Yedekleme hızlı işlem & otomatik yedekleme kartı.
class CloudBackupQuickCard extends ConsumerWidget {
  final Future<String?> Function()? onPickFolder;

  const CloudBackupQuickCard({super.key, this.onPickFolder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = _CloudDialogPalette.of(context);
    final syncStatus =
        ref.watch(pdksDashboardProvider.select((s) => s.syncStatus));
    final isCloudBusy =
        ref.watch(pdksDashboardProvider.select((s) => s.isCloudBusy));
    final autoEnabled = ref.watch(
      pdksDashboardProvider
          .select((s) => s.companySettings.autoCloudBackupEnabled),
    );
    final autoMinutes = ref.watch(
      pdksDashboardProvider
          .select((s) => s.companySettings.autoCloudBackupMinutes),
    );
    final profileId = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.cloudProfileId),
    );
    final profileLabel = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.cloudProfileLabel),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.backup_rounded,
                    size: 18,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Bulut Yedekleme & Otomasyon • Kasa: $profileLabel ($profileId)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    key: const ValueKey('quick_switch_auto_cloud_backup'),
                    value: autoEnabled,
                    onChanged: (val) => ref
                        .read(pdksDashboardProvider.notifier)
                        .updateCloudBackupSettings(
                          autoCloudBackupEnabled: val,
                        ),
                  ),
                  Text(
                    autoEnabled
                        ? 'Otomatik ($autoMinutes dk)'
                        : 'Otomatik Kapalı',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pal.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            syncStatus.lastSyncTime != null
                ? 'Son İşlem (${_formatDateTimeShort(syncStatus.lastSyncTime)}): ${syncStatus.message}'
                : syncStatus.message,
            style: TextStyle(fontSize: 11.5, color: pal.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('quick_btn_cloud_backup'),
                onPressed: isCloudBusy
                    ? null
                    : () async {
                        final res = await ref
                            .read(pdksDashboardProvider.notifier)
                            .backupToCloudNow();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(res.message)),
                          );
                        }
                      },
                icon: isCloudBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded, size: 17),
                label: const Text('Buluta Yedekle'),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('quick_btn_cloud_restore'),
                onPressed: isCloudBusy
                    ? null
                    : () => showCloudRestoreDialog(context, ref),
                icon: const Icon(Icons.cloud_download_rounded, size: 17),
                label: const Text('Buluttan Yükle'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('quick_btn_open_cloud_center'),
                onPressed: () => showCloudBackupCenterDialog(
                  context,
                  ref,
                  onPickFolder: onPickFolder,
                ),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Bulut Yedek Merkezi & Profiller'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Buluttan Geri Yükleme (Seçenekli Birleştir / Üzerine Yaz) alt diyalogu.
Future<CloudRestoreSummary?> showCloudRestoreDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialProfileId,
}) async {
  final initSettings = ref.read(pdksDashboardProvider).companySettings;
  final profileCtrl = TextEditingController(
    text: initialProfileId ?? initSettings.cloudProfileId,
  );
  final keyCtrl = TextEditingController();
  CloudRestoreMode selectedMode = CloudRestoreMode.merge;
  bool cloudOnly = false;
  bool confirmedReplace = false;
  bool isRunning = false;
  String? errorMsg;
  CloudRestoreSummary? appliedSummary;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final pal = _CloudDialogPalette.of(ctx);
        final canSubmit = !isRunning &&
            (selectedMode != CloudRestoreMode.replace || confirmedReplace);

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_download_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buluttan Yükle (Geri Yükleme Seçenekleri)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('restore_dialog_profile_field'),
                    controller: profileCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Yüklenecek Yedek Profili (Kasa Kodu)',
                      hintText: 'default veya sube_bursa',
                      prefixIcon: Icon(Icons.folder_special_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Geri Yükleme Yöntemi',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RadioGroup<CloudRestoreMode>(
                    groupValue: selectedMode,
                    onChanged: (val) {
                      if (isRunning || val == null) return;
                      setDialogState(() {
                        selectedMode = val;
                        errorMsg = null;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final mode in CloudRestoreMode.values)
                          RadioListTile<CloudRestoreMode>(
                            key: ValueKey('restore_mode_${mode.name}'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            enabled: !isRunning,
                            value: mode,
                            title: Text(
                              mode.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: pal.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              mode.description,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: pal.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selectedMode == CloudRestoreMode.replace) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dikkat: Tam Geri Yükleme mevcut yerel personelleri, hareketleri, izinleri ve kullanıcıları temizleyerek buluttaki yedek ile birebir değiştirir (denetim izi logları korunur).',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            CheckboxListTile(
                              key: const ValueKey(
                                'restore_replace_confirm_check',
                              ),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: confirmedReplace,
                              onChanged: isRunning
                                  ? null
                                  : (v) => setDialogState(
                                        () => confirmedReplace = v ?? false,
                                      ),
                              title: const Text(
                                'Yerel verilerin üstüne yazılmasını onaylıyorum',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    key: const ValueKey('restore_cloud_only_check'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: cloudOnly,
                    onChanged: isRunning
                        ? null
                        : (v) => setDialogState(() => cloudOnly = v ?? false),
                    title: const Text(
                      'Yalnızca Google Drive bulutundan/klasöründen indir',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    subtitle: Text(
                      'Yerel önbellek yedeğini atlar; yeni cihaz kurulumunda önerilir.',
                      style: TextStyle(fontSize: 11, color: pal.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('restore_workspace_key_field'),
                    controller: keyCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText:
                          'Bulut Şifreleme Parolası veya Cihaz Anahtarı (İsteğe Bağlı)',
                      hintText:
                          'Özel parola belirlediyseniz parolanızı girin; Otomatik modda boş bırakın',
                      prefixIcon: Icon(Icons.key_rounded, size: 18),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isRunning ? null : () => Navigator.of(dialogCtx).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              key: const ValueKey('btn_confirm_cloud_restore'),
              onPressed: canSubmit
                  ? () async {
                      setDialogState(() {
                        isRunning = true;
                        errorMsg = null;
                      });
                      final res = await ref
                          .read(pdksDashboardProvider.notifier)
                          .restoreFromCloudNow(
                            profileId: profileCtrl.text.trim(),
                            mode: selectedMode,
                            cloudOnly: cloudOnly,
                            overrideWorkspaceKey: keyCtrl.text.trim().isEmpty
                                ? null
                                : keyCtrl.text.trim(),
                          );
                      if (!dialogCtx.mounted) return;
                      if (res.summary != null) {
                        appliedSummary = res.summary;
                        Navigator.of(dialogCtx).pop();
                      } else {
                        setDialogState(() {
                          isRunning = false;
                          errorMsg = res.status.message;
                        });
                      }
                    }
                  : null,
              icon: isRunning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_download_rounded, size: 18),
              label: Text(isRunning ? 'Yükleniyor...' : 'Geri Yüklemeyi Başlat'),
            ),
          ],
        );
      },
    ),
  );

  profileCtrl.dispose();
  keyCtrl.dispose();
  return appliedSummary;
}

/// Google OAuth 2.0, Buluta Yedekle, Buluttan Yükle, Otomatik Yedekleme ve Çoklu Profil Merkezi.
Future<void> showCloudBackupCenterDialog(
  BuildContext context,
  WidgetRef ref, {
  Future<String?> Function()? onPickFolder,
}) async {
  final initState = ref.read(pdksDashboardProvider);
  final defaultFolder = initState.companySettings.syncFolderPath.trim().isEmpty
      ? GoogleDriveSyncService.detectDefaultGoogleDrivePath()
      : initState.companySettings.syncFolderPath.trim();
  final gmailCtrl = TextEditingController(
    text: initState.companySettings.syncGmailAccount,
  );
  final folderCtrl = TextEditingController(text: defaultFolder);
  final tokenCtrl = TextEditingController();
  final clientIdCtrl = TextEditingController();
  final clientSecretCtrl = TextEditingController();
  final profileIdCtrl = TextEditingController(
    text: initState.companySettings.cloudProfileId,
  );
  final profileLabelCtrl = TextEditingController(
    text: initState.companySettings.cloudProfileLabel,
  );
  final workspaceKeyCtrl = TextEditingController();
  final passphraseCtrl = TextEditingController();

  bool isConnecting = false;
  bool isScanningProfiles = false;
  bool isPullingInboxes = false;
  int? selectedBridgeBranchId;
  bool obscureWorkspaceKey = true;
  bool obscurePassphrase = true;
  CloudEncryptionKeyMode encryptionMode = CloudEncryptionKeyMode.accountAuto;
  String? statusFeedback;
  bool isFeedbackSuccess = false;
  StateSetter? activeSetDialogState;

  final syncSvc = ref.read(googleDriveSyncServiceProvider);
  final isNativeGoogleAuth = ref.read(googleAuthAdapterProvider).isNativePlatform;
  syncSvc.getSavedOAuthClientId().then((val) {
    if (val.isNotEmpty && clientIdCtrl.text.isEmpty) {
      clientIdCtrl.text = val;
    }
  }).catchError((e) {
    debugPrint('CloudBackupCenterDialog: getSavedOAuthClientId hata: $e');
  });
  syncSvc.getSavedOAuthClientSecret().then((val) {
    if (val.isNotEmpty && clientSecretCtrl.text.isEmpty) {
      clientSecretCtrl.text = val;
    }
  }).catchError((e) {
    debugPrint('CloudBackupCenterDialog: getSavedOAuthClientSecret hata: $e');
  });
  syncSvc.getWorkspaceKey().then((val) {
    if (val.isNotEmpty && workspaceKeyCtrl.text.isEmpty) {
      workspaceKeyCtrl.text = val;
    }
  }).catchError((e) {
    debugPrint('CloudBackupCenterDialog: getWorkspaceKey hata: $e');
  });
  syncSvc.getCloudEncryptionKeyMode().then((mode) {
    encryptionMode = mode;
    if (context.mounted) {
      activeSetDialogState?.call(() {});
    }
  }).catchError((e) {
    debugPrint('CloudBackupCenterDialog: getCloudEncryptionKeyMode hata: $e');
  });

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => Consumer(
      builder: (consumerCtx, dialogRef, _) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          activeSetDialogState = setDialogState;
          final pal = _CloudDialogPalette.of(ctx);
          final liveState = dialogRef.watch(pdksDashboardProvider);
          final syncStatus = liveState.syncStatus;
          final settings = liveState.companySettings;
          final connectedEmail = settings.syncGmailAccount.trim();
          final isTrulySynced = syncStatus.isTrulySynced;
          final isBusy = isConnecting || liveState.isCloudBusy;

          const baseIntervals = <int>[15, 30, 60, 360, 1440];
          final currentMinutes = settings.autoCloudBackupMinutes.clamp(5, 1440);
          final intervalItems = <int>{
            ...baseIntervals,
            currentMinutes,
          }.toList()
            ..sort();

          Future<void> startBrowserOAuthFlow() async {
            setDialogState(() {
              isConnecting = true;
              statusFeedback = isNativeGoogleAuth
                  ? 'Google oturum açma ekranı açıldı. Lütfen hesabınızı seçip Drive erişimini onaylayın...'
                  : 'Edge tarayıcısında Google OAuth 2.0 giriş sayfası açıldı. Lütfen tarayıcıda Google hesabınızla yetkilendirmeyi tamamlayın...';
              isFeedbackSuccess = false;
            });
            final browserResult = await dialogRef
                .read(pdksDashboardProvider.notifier)
                .signInWithGoogleViaBrowser(
                  emailHint: gmailCtrl.text.trim(),
                  customClientId: clientIdCtrl.text.trim(),
                  customClientSecret: clientSecretCtrl.text.trim(),
                  syncFolderPath: folderCtrl.text.trim(),
                );
            if (dialogCtx.mounted) {
              final latestSync = dialogRef.read(pdksDashboardProvider).syncStatus;
              final latestEmail = dialogRef
                  .read(pdksDashboardProvider)
                  .companySettings
                  .syncGmailAccount;
              if (latestEmail.isNotEmpty) {
                gmailCtrl.text = latestEmail;
              }
              setDialogState(() {
                isConnecting = false;
                isFeedbackSuccess =
                    browserResult.success && latestSync.isTrulySynced;
                statusFeedback = browserResult.success
                    ? '✓ ${browserResult.message} • ${latestSync.message}'
                    : '⚠️ ${browserResult.message}';
              });
            }
          }

          Future<void> verifyAndSaveSettings() async {
            final targetEmail = gmailCtrl.text.trim();
            final resolvedEmail = targetEmail.isEmpty
                ? ''
                : (targetEmail.contains('@')
                    ? targetEmail
                    : '$targetEmail@gmail.com');
            if (resolvedEmail.isNotEmpty) {
              gmailCtrl.text = resolvedEmail;
            }
            setDialogState(() {
              isConnecting = true;
              statusFeedback = null;
            });
            final resultStatus = await dialogRef
                .read(pdksDashboardProvider.notifier)
                .saveGmailSyncAccount(
                  gmailAccount: resolvedEmail,
                  syncFolderPath: folderCtrl.text.trim(),
                  accessToken: tokenCtrl.text.trim().isEmpty
                      ? null
                      : tokenCtrl.text.trim(),
                );
            if (dialogCtx.mounted) {
              final updatedEmail = dialogRef
                  .read(pdksDashboardProvider)
                  .companySettings
                  .syncGmailAccount;
              if (updatedEmail.isNotEmpty) {
                gmailCtrl.text = updatedEmail;
              }
              setDialogState(() {
                isConnecting = false;
                if (resultStatus.isTrulySynced) {
                  isFeedbackSuccess = true;
                  statusFeedback =
                      '✓ Doğrulandı ve Eşitlendi: ${resultStatus.message}';
                } else if (resultStatus.stage == DriveSyncStage.error) {
                  isFeedbackSuccess = false;
                  statusFeedback = '❌ Doğrulama Hatası: ${resultStatus.message}';
                } else {
                  isFeedbackSuccess = false;
                  statusFeedback =
                      '⚠️ Tek başına e-posta yazmak Google hesabına giriş yapmaz! '
                      '${resultStatus.message} '
                      'Gerçek bulut eşitlemesi için yukarıdaki "Tarayıcıda Google ile Giriş Yap (OAuth 2.0)" butonunu kullanın veya Google Drive klasör yolunu seçin.';
                }
              });
            }
          }

          Future<void> runBackupNow() async {
            setDialogState(() => statusFeedback = null);
            final res = await dialogRef
                .read(pdksDashboardProvider.notifier)
                .backupToCloudNow();
            if (dialogCtx.mounted) {
              setDialogState(() {
                isFeedbackSuccess = res.stage != DriveSyncStage.error;
                statusFeedback = res.message;
              });
            }
          }

          Future<void> openRestoreFlow({String? targetProfile}) async {
            final summary = await showCloudRestoreDialog(
              dialogCtx,
              dialogRef,
              initialProfileId: targetProfile,
            );
            if (summary != null && dialogCtx.mounted) {
              final refreshedSettings =
                  dialogRef.read(pdksDashboardProvider).companySettings;
              profileIdCtrl.text = refreshedSettings.cloudProfileId;
              profileLabelCtrl.text = refreshedSettings.cloudProfileLabel;
              setDialogState(() {
                isFeedbackSuccess = true;
                statusFeedback =
                    '✓ Geri yüklendi (${summary.mode.label}): ${summary.toTurkishSummary()}';
              });
            }
          }

          final Color statusBorderColor = isTrulySynced
              ? const Color(0xFF10B981)
              : (syncStatus.stage == DriveSyncStage.error
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFF59E0B));

          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.cloud_sync_rounded, color: Color(0xFF10B981)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Google OAuth 2.0 & Drive Veri Eşitleme Merkezi',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. DOĞRULAMA & AKTİF KASA DURUM KARTI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusBorderColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusBorderColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isTrulySynced
                                    ? Icons.verified_rounded
                                    : (syncStatus.stage == DriveSyncStage.error
                                        ? Icons.error_outline_rounded
                                        : Icons.warning_amber_rounded),
                                color: statusBorderColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isTrulySynced
                                      ? (syncStatus.isCloudApiVerified
                                          ? 'Doğrulanmış Google OAuth 2.0 Hesabı: ${connectedEmail.isEmpty ? "Aktif" : connectedEmail}'
                                          : 'Google Drive Masaüstü Klasörü Aktif: ${connectedEmail.isEmpty ? "Yerel Drive" : connectedEmail}')
                                      : (connectedEmail.isNotEmpty
                                          ? 'E-Posta Kayıtlı ($connectedEmail) • OAuth 2.0 / Drive Doğrulanmadı'
                                          : 'Henüz Doğrulanmış Google Bağlantısı Yok'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: pal.textPrimary,
                                  ),
                                ),
                              ),
                              if (connectedEmail.isNotEmpty || isTrulySynced)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: const Color(0xFFEF4444),
                                  ),
                                  onPressed: isBusy
                                      ? null
                                      : () async {
                                          await dialogRef
                                              .read(
                                                pdksDashboardProvider.notifier,
                                              )
                                              .disconnectGmailSyncAccount();
                                          if (dialogCtx.mounted) {
                                            setDialogState(() {
                                              gmailCtrl.clear();
                                              tokenCtrl.clear();
                                              isFeedbackSuccess = false;
                                              statusFeedback =
                                                  'Google hesap bağlantısı ve OAuth anahtarı kaldırıldı.';
                                            });
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.link_off_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'Bağlantıyı Kes',
                                    style: TextStyle(fontSize: 11.5),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aktif Kasa Profili: ${settings.cloudProfileLabel} (${settings.cloudProfileId}) • Son İşlem: ${_formatDateTimeShort(syncStatus.lastSyncTime)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            syncStatus.message,
                            style: TextStyle(
                              fontSize: 12,
                              color: pal.textSecondary,
                            ),
                          ),
                          if (syncStatus.syncedFilePath.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 14,
                                  color: Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Yedek Dosyası: ${syncStatus.syncedFilePath} (${(syncStatus.syncedBytes / 1024).toStringAsFixed(1)} KB)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. HIZLI BULUT YEDEKLEME & GERİ YÜKLEME İŞLEMLERİ
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('btn_cloud_backup_now'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: isBusy ? null : runBackupNow,
                          icon: const Icon(Icons.cloud_upload_rounded, size: 17),
                          label: const Text('Buluta Yedekle'),
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey('btn_cloud_restore_now'),
                          onPressed: isBusy ? null : () => openRestoreFlow(),
                          icon: const Icon(
                            Icons.cloud_download_rounded,
                            size: 17,
                          ),
                          label: const Text('Buluttan Yükle'),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('btn_cloud_two_way_sync'),
                          onPressed: isBusy
                              ? null
                              : () async {
                                  await dialogRef
                                      .read(pdksDashboardProvider.notifier)
                                      .syncWithGoogleDriveNow();
                                  if (dialogCtx.mounted) {
                                    final st = dialogRef
                                        .read(pdksDashboardProvider)
                                        .syncStatus;
                                    setDialogState(() {
                                      isFeedbackSuccess =
                                          st.stage != DriveSyncStage.error;
                                      statusFeedback = st.message;
                                    });
                                  }
                                },
                          icon: const Icon(Icons.sync_rounded, size: 17),
                          label: const Text('Çift Yönlü Eşitle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. OTOMATİK BULUT YEDEKLEME AYARLARI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pal.subtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: pal.border),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Otomatik Bulut Yedekleme',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: pal.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile(
                              key: const ValueKey('switch_auto_cloud_backup'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: settings.autoCloudBackupEnabled,
                              onChanged: (val) => dialogRef
                                  .read(pdksDashboardProvider.notifier)
                                  .updateCloudBackupSettings(
                                    autoCloudBackupEnabled: val,
                                  ),
                              title: const Text(
                                'Periyodik Otomatik Bulut Yedekleme',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Belirlenen aralıkta değişiklik varsa otomatik şifreli yedek alır.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: pal.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            KeyedSubtree(
                              key: const ValueKey(
                                'dropdown_auto_cloud_interval',
                              ),
                              child: DropdownButtonFormField<int>(
                                key: ValueKey<int>(currentMinutes),
                                initialValue: currentMinutes,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Otomatik Yedekleme Aralığı',
                                  prefixIcon:
                                      Icon(Icons.schedule_rounded, size: 18),
                                ),
                                items: [
                                  for (final mins in intervalItems)
                                    DropdownMenuItem<int>(
                                      value: mins,
                                      child: Text(
                                        mins == 60
                                            ? '1 saat (60 dk)'
                                            : (mins == 360
                                                ? '6 saat (360 dk)'
                                                : (mins == 1440
                                                    ? '24 saat (1440 dk)'
                                                    : '$mins dk')),
                                      ),
                                    ),
                                ],
                                onChanged: settings.autoCloudBackupEnabled
                                    ? (val) {
                                        if (val == null) return;
                                        dialogRef
                                            .read(
                                              pdksDashboardProvider.notifier,
                                            )
                                            .updateCloudBackupSettings(
                                              autoCloudBackupMinutes: val,
                                            );
                                      }
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile(
                              key: const ValueKey(
                                'switch_auto_cloud_on_change',
                              ),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: settings.autoCloudBackupOnChange,
                              onChanged: settings.autoCloudBackupEnabled
                                  ? (val) => dialogRef
                                      .read(pdksDashboardProvider.notifier)
                                      .updateCloudBackupSettings(
                                        autoCloudBackupOnChange: val,
                                      )
                                  : null,
                              title: const Text(
                                'Veri değiştikçe anında otomatik yedekle',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Personel, vardiya, hareket veya izin kaydı sonrası buluta anlık gönderir.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: pal.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4. AYNI GMAIL'DE ÇOKLU YEDEK PROFİLİ (KASA SLOTU)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pal.subtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: pal.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aynı Gmail Hesabında Çoklu Yedek Profili (Kasa Slotu)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aynı Google Drive hesabında farklı şube, işletme veya sorumlu kullanıcılar için birbirine karışmayan ayrı şifreli kasalar oluşturabilirsiniz.',
                            style: TextStyle(
                              fontSize: 11,
                              color: pal.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 190,
                                child: TextField(
                                  controller: profileIdCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    labelText: 'Profil Kodu',
                                    hintText: 'default / sube_bursa',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  controller: profileLabelCtrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    labelText: 'Profil / Kasa Adı',
                                    hintText: 'Ana İşletme Kasası',
                                  ),
                                ),
                              ),
                              FilledButton.tonalIcon(
                                key: const ValueKey('btn_save_cloud_profile'),
                                onPressed: () async {
                                  final normId = GoogleDriveSyncService
                                      .normalizeCloudProfileId(
                                    profileIdCtrl.text,
                                  );
                                  profileIdCtrl.text = normId;
                                  await dialogRef
                                      .read(pdksDashboardProvider.notifier)
                                      .updateCloudBackupSettings(
                                        cloudProfileId: normId,
                                        cloudProfileLabel:
                                            profileLabelCtrl.text.trim(),
                                      );
                                  if (dialogCtx.mounted) {
                                    setDialogState(() {
                                      isFeedbackSuccess = true;
                                      statusFeedback =
                                          '✓ Aktif bulut profili "$normId" (${GoogleDriveSyncService.backupFileNameForProfile(normId)}) olarak kaydedildi.';
                                    });
                                  }
                                },
                                icon: const Icon(Icons.save_outlined, size: 16),
                                label: const Text('Profili Kaydet'),
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey('btn_scan_cloud_profiles'),
                                onPressed: isScanningProfiles
                                    ? null
                                    : () async {
                                        setDialogState(
                                          () => isScanningProfiles = true,
                                        );
                                        final list = await dialogRef
                                            .read(
                                              pdksDashboardProvider.notifier,
                                            )
                                            .refreshAvailableCloudBackups();
                                        if (dialogCtx.mounted) {
                                          setDialogState(() {
                                            isScanningProfiles = false;
                                            isFeedbackSuccess = true;
                                            statusFeedback = list.isEmpty
                                                ? 'Tarama tamamlandı: Kayıtlı bulut profili bulunamadı.'
                                                : '✓ ${list.length} adet yedek profili bulundu.';
                                          });
                                        }
                                      },
                                icon: isScanningProfiles
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.manage_search_rounded,
                                        size: 17,
                                      ),
                                label: const Text('Buluttaki Profilleri Tara'),
                              ),
                            ],
                          ),
                          if (liveState.availableCloudBackups.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            for (final pInfo in liveState.availableCloudBackups)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: pal.card,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: pInfo.profileId ==
                                            settings.cloudProfileId
                                        ? const Color(0xFF10B981)
                                        : pal.border,
                                  ),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${pInfo.profileId} • ${pInfo.fileName}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: pal.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${pInfo.source} • ${(pInfo.sizeBytes / 1024).toStringAsFixed(1)} KB • ${_formatDateTimeShort(pInfo.modifiedTime)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: pal.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () async {
                                            profileIdCtrl.text =
                                                pInfo.profileId;
                                            await dialogRef
                                                .read(
                                                  pdksDashboardProvider
                                                      .notifier,
                                                )
                                                .updateCloudBackupSettings(
                                                  cloudProfileId:
                                                      pInfo.profileId,
                                                );
                                          },
                                          child: const Text('Seç'),
                                        ),
                                        FilledButton.tonal(
                                          onPressed: isBusy
                                              ? null
                                              : () => openRestoreFlow(
                                                    targetProfile:
                                                        pInfo.profileId,
                                                  ),
                                          child: const Text('Yükle'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    _BranchInboxSyncSection(
                      pal: pal,
                      branches: liveState.branches,
                      inboxStatuses: liveState.branchInboxStatuses,
                      selectedBranchId: selectedBridgeBranchId,
                      isBusy: isBusy,
                      isPulling: isPullingInboxes,
                      onBranchChanged: (val) =>
                          setDialogState(() => selectedBridgeBranchId = val),
                      onPullInboxes: () async {
                        setDialogState(() => isPullingInboxes = true);
                        try {
                          final res = await dialogRef
                              .read(pdksDashboardProvider.notifier)
                              .pullBranchInboxesNow(force: true);
                          if (!dialogCtx.mounted) return;
                          setDialogState(() {
                            isFeedbackSuccess = res.warnings.isEmpty;
                            if (res.devices.isEmpty && res.warnings.isEmpty) {
                              statusFeedback =
                                  'Google Drive\'da henüz şube cihaz kutusu (hasibu_branch_inbox_*.enc) bulunamadı.';
                            } else if (res.warnings.isNotEmpty) {
                              statusFeedback =
                                  '⚠️ ${res.devices.length} şube kutusu (${res.totalNewLogsInserted} yeni kayıt) • Uyarı: ${res.warnings.join(' | ')}';
                            } else {
                              statusFeedback =
                                  '✓ ${res.devices.length} şube cihaz kutusu eşlendi (${res.totalNewLogsInserted} yeni hareket, ${res.totalLogsRead} toplam kayıt).';
                            }
                          });
                        } finally {
                          if (dialogCtx.mounted) {
                            setDialogState(() => isPullingInboxes = false);
                          }
                        }
                      },
                      onCopyConfigJson: (branch) async {
                        final jsonText = await dialogRef
                            .read(pdksDashboardProvider.notifier)
                            .buildBranchBridgeConfigJson(branch);
                        await Clipboard.setData(ClipboardData(text: jsonText));
                        if (!dialogCtx.mounted) return;
                        setDialogState(() {
                          isFeedbackSuccess = true;
                          statusFeedback =
                              '✓ ${branch.name} şube köprüsü ayar JSON\'u panoya kopyalandı. Şube terazisinde config.json olarak kaydedebilir veya --import-config ile aktarabilirsiniz.';
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // 5. CİHAZLAR ARASI YEDEK ŞİFRELEME & KOLAY EŞLEŞTİRME
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pal.subtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: pal.border),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cihazlar Arası Yedek Şifreleme & Kolay Eşleştirme',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: pal.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Otomatik modda aynı Google hesabındaki telefon ve bilgisayarınız anahtar kopyalamadan yedekleri açar.',
                              style: TextStyle(
                                fontSize: 11,
                                color: pal.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            RadioGroup<CloudEncryptionKeyMode>(
                              groupValue: encryptionMode,
                              onChanged: (mode) async {
                                if (mode == null || isBusy) return;
                                final notifier = dialogRef
                                    .read(pdksDashboardProvider.notifier);
                                if (mode == CloudEncryptionKeyMode.accountAuto) {
                                  await notifier.useAutomaticCloudEncryption();
                                  final resolvedKey =
                                      await notifier.getCloudWorkspaceKey();
                                  if (!dialogCtx.mounted) return;
                                  setDialogState(() {
                                    encryptionMode = mode;
                                    workspaceKeyCtrl.text = resolvedKey;
                                    isFeedbackSuccess = true;
                                    statusFeedback =
                                        '✓ Otomatik Google Hesabı şifrelemesi seçildi. Mevcut cihazlarda aktif etmek için bir kez "Buluta Yedekle" butonuna basın.';
                                  });
                                } else {
                                  setDialogState(() => encryptionMode = mode);
                                }
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RadioListTile<CloudEncryptionKeyMode>(
                                    key: const ValueKey(
                                      'encryption_mode_account_auto',
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    enabled: !isBusy,
                                    value: CloudEncryptionKeyMode.accountAuto,
                                    title: Text(
                                      'Otomatik (Aynı Google Hesabı — Önerilen)',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: pal.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Ek şifre veya anahtar taşımadan aynı Gmail hesabındaki cihazları eşleştirir.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                  ),
                                  RadioListTile<CloudEncryptionKeyMode>(
                                    key: const ValueKey(
                                      'encryption_mode_custom',
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    enabled: !isBusy,
                                    value:
                                        CloudEncryptionKeyMode.customPassphrase,
                                    title: Text(
                                      'Özel Bulut Şifreleme Parolası (Ekstra Güvenlik)',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: pal.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Tüm cihazlarda aynı kısa parolayı girerek uçtan uca şifreleme kullanın.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (encryptionMode ==
                                CloudEncryptionKeyMode.customPassphrase) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 280,
                                    child: TextField(
                                      key: const ValueKey(
                                        'cloud_sync_passphrase_field',
                                      ),
                                      controller: passphraseCtrl,
                                      obscureText: obscurePassphrase,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: 'Ortak Bulut Parolası',
                                        hintText: 'Örn. Sirket2026!',
                                        prefixIcon: const Icon(
                                          Icons.password_rounded,
                                          size: 18,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            obscurePassphrase
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 18,
                                          ),
                                          onPressed: () => setDialogState(
                                            () => obscurePassphrase =
                                                !obscurePassphrase,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    key: const ValueKey(
                                      'btn_save_cloud_passphrase',
                                    ),
                                    onPressed: isBusy
                                        ? null
                                        : () async {
                                            final cleanPass =
                                                passphraseCtrl.text.trim();
                                            if (cleanPass.isEmpty) return;
                                            final notifier = dialogRef.read(
                                              pdksDashboardProvider.notifier,
                                            );
                                            await notifier
                                                .setCloudEncryptionPassphrase(
                                              cleanPass,
                                            );
                                            final derived = await notifier
                                                .getCloudWorkspaceKey();
                                            if (!dialogCtx.mounted) return;
                                            setDialogState(() {
                                              workspaceKeyCtrl.text = derived;
                                              isFeedbackSuccess = true;
                                              statusFeedback =
                                                  '✓ Ortak Bulut Şifreleme Parolası kaydedildi. Buluta yeni parola ile yazmak için "Buluta Yedekle" butonuna basın.';
                                            });
                                          },
                                    icon: const Icon(
                                      Icons.lock_reset_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Parolayı Kaydet'),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  key: const ValueKey('btn_show_pairing_qr'),
                                  onPressed: () async {
                                    var activeKey =
                                        workspaceKeyCtrl.text.trim();
                                    if (activeKey.isEmpty) {
                                      activeKey = await dialogRef
                                          .read(pdksDashboardProvider.notifier)
                                          .getCloudWorkspaceKey();
                                      workspaceKeyCtrl.text = activeKey;
                                    }
                                    if (!dialogCtx.mounted ||
                                        activeKey.isEmpty) {
                                      return;
                                    }
                                    await showDialog<void>(
                                      context: dialogCtx,
                                      builder: (qrCtx) => AlertDialog(
                                        title: const Text(
                                          'Cihaz Eşleştirme QR Kodu',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        content: SizedBox(
                                          width: 240,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 220,
                                                height: 220,
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: CustomPaint(
                                                  size: const Size.square(200),
                                                  painter: QrPainter(
                                                    data: activeKey,
                                                    version: QrVersions.auto,
                                                    gapless: true,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              const Text(
                                                'Eski veya özel anahtarlı yedekleri açmak için diğer cihazda anahtarı kopyalayıp yapıştırabilirsiniz.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontSize: 11.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton.icon(
                                            onPressed: () async {
                                              await Clipboard.setData(
                                                ClipboardData(text: activeKey),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.copy_rounded,
                                              size: 16,
                                            ),
                                            label: const Text('Anahtarı Kopyala'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.of(qrCtx).pop(),
                                            child: const Text('Kapat'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('Cihaz Eşleştirme QR Kodu'),
                                ),
                              ],
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                'Gelişmiş: Ham Çalışma Alanı Anahtarı (Workspace Key)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: pal.textPrimary,
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        controller: workspaceKeyCtrl,
                                        obscureText: obscureWorkspaceKey,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          labelText:
                                              'Aktif Çalışma Alanı Anahtarı',
                                          prefixIcon: const Icon(
                                            Icons.vpn_key_rounded,
                                            size: 18,
                                          ),
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: obscureWorkspaceKey
                                                    ? 'Anahtarı Göster'
                                                    : 'Anahtarı Gizle',
                                                icon: Icon(
                                                  obscureWorkspaceKey
                                                      ? Icons.visibility_outlined
                                                      : Icons
                                                          .visibility_off_outlined,
                                                  size: 18,
                                                ),
                                                onPressed: () => setDialogState(
                                                  () => obscureWorkspaceKey =
                                                      !obscureWorkspaceKey,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Anahtarı Kopyala',
                                                icon: const Icon(
                                                  Icons.copy_rounded,
                                                  size: 17,
                                                ),
                                                onPressed: () async {
                                                  await Clipboard.setData(
                                                    ClipboardData(
                                                      text: workspaceKeyCtrl
                                                          .text
                                                          .trim(),
                                                    ),
                                                  );
                                                  if (dialogCtx.mounted) {
                                                    setDialogState(() {
                                                      isFeedbackSuccess = true;
                                                      statusFeedback =
                                                          '✓ Şifreleme anahtarı panoya kopyalandı.';
                                                    });
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: FilledButton.tonalIcon(
                                          key: const ValueKey(
                                            'btn_save_workspace_key',
                                          ),
                                          onPressed: () async {
                                            final cleanKey =
                                                workspaceKeyCtrl.text.trim();
                                            if (cleanKey.isEmpty) return;
                                            await dialogRef
                                                .read(
                                                  pdksDashboardProvider
                                                      .notifier,
                                                )
                                                .updateCloudWorkspaceKey(
                                                  cleanKey,
                                                );
                                            if (dialogCtx.mounted) {
                                              setDialogState(() {
                                                encryptionMode =
                                                    CloudEncryptionKeyMode
                                                        .customPassphrase;
                                                isFeedbackSuccess = true;
                                                statusFeedback =
                                                    '✓ Çalışma Alanı Şifreleme Anahtarı güncellendi.';
                                              });
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.key_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('Anahtarı Güncelle'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 6. GOOGLE OAUTH 2.0 GİRİŞ BUTONU & BAĞLANTI AYARLARI
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('btn_google_browser_oauth'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                        ),
                        onPressed: isBusy ? null : startBrowserOAuthFlow,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            isConnecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isNativeGoogleAuth
                                        ? Icons.account_circle_outlined
                                        : Icons.open_in_browser_rounded,
                                    size: 20,
                                  ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isConnecting
                                    ? (isNativeGoogleAuth
                                        ? 'Google OAuth 2.0 Onayı Bekleniyor...'
                                        : 'Tarayıcıda Google OAuth 2.0 Onayı Bekleniyor...')
                                    : (isNativeGoogleAuth
                                        ? 'Google ile Giriş Yap (OAuth 2.0)'
                                        : 'Tarayıcıda Google ile Giriş Yap (Gerçek OAuth 2.0)'),
                                textAlign: TextAlign.center,
                                softWrap: true,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      key: const ValueKey('gmail_account_input_field'),
                      controller: gmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Google (Gmail) E-Posta Adresi',
                        hintText: 'ornek.isletme@gmail.com',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: folderCtrl,
                          decoration: const InputDecoration(
                            labelText:
                                'Google Drive Masaüstü Klasörü (Otomatik / Seçimli)',
                            hintText: r"G:\Drive'ım\Hasibu\CloudSync",
                            prefixIcon: Icon(Icons.folder_shared_outlined),
                          ),
                        ),
                        if (Platform.isWindows) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: onPickFolder == null
                                    ? null
                                    : () async {
                                        final picked = await onPickFolder();
                                        if (picked != null) {
                                          setDialogState(
                                            () => folderCtrl.text = picked,
                                          );
                                        }
                                      },
                                icon: const Icon(
                                  Icons.folder_open_rounded,
                                  size: 18,
                                ),
                                label: const Text('Seç'),
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'btn_open_sync_folder_explorer',
                                ),
                                onPressed: () async {
                                  final openedPath = await dialogRef
                                      .read(pdksDashboardProvider.notifier)
                                      .openCloudSyncFolder(
                                        folderCtrl.text.trim(),
                                      );
                                  if (dialogCtx.mounted) {
                                    setDialogState(() {
                                      statusFeedback =
                                          'Yedek klasörü Windows Gezgini\'nde açıldı: $openedPath';
                                    });
                                  }
                                },
                                icon: const Icon(Icons.launch_rounded, size: 16),
                                label: const Text('Klasörü Aç'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    if (!isNativeGoogleAuth) ...[
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (_, constraints) {
                          final clientIdField = TextField(
                            controller: clientIdCtrl,
                            decoration: const InputDecoration(
                              labelText:
                                  'ihasibu Google Cloud OAuth 2.0 Client ID',
                              hintText: '123456-abc.apps.googleusercontent.com',
                              prefixIcon: Icon(Icons.cloud_queue_rounded),
                            ),
                          );
                          final clientSecretField = TextField(
                            controller: clientSecretCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText:
                                  'OAuth 2.0 Client Secret (Masaüstü/Web)',
                              hintText: 'GOCSPX-...',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                          );
                          if (constraints.maxWidth >= 440) {
                            return Row(
                              children: [
                                Expanded(child: clientIdField),
                                const SizedBox(width: 8),
                                Expanded(child: clientSecretField),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              clientIdField,
                              const SizedBox(height: 8),
                              clientSecretField,
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: tokenCtrl,
                      obscureText: false,
                      decoration: const InputDecoration(
                        labelText:
                            'Google OAuth 2.0 Erişim Anahtarı (Bearer ya29...)',
                        hintText:
                            'Doğrudan Google Drive API doğrulaması için ya29.a0...',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        key: const ValueKey('google_quick_connect_button'),
                        onPressed: isBusy ? null : verifyAndSaveSettings,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            isConnecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.fact_check_rounded,
                                    size: 18,
                                  ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isConnecting
                                    ? 'Doğrulanıyor ve Eşitleniyor...'
                                    : 'Anahtarı / Drive Klasörünü Doğrula & Şimdi Eşitle',
                                textAlign: TextAlign.center,
                                softWrap: true,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (statusFeedback != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: (isFeedbackSuccess
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B))
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (isFeedbackSuccess
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B))
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          statusFeedback!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isFeedbackSuccess
                                ? const Color(0xFF10B981)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Kapat'),
              ),
              FilledButton.icon(
                onPressed: isBusy
                    ? null
                    : () async {
                        await verifyAndSaveSettings();
                        if (dialogCtx.mounted &&
                            dialogRef
                                .read(pdksDashboardProvider)
                                .syncStatus
                                .isTrulySynced) {
                          Navigator.of(dialogCtx).pop();
                        }
                      },
                icon: const Icon(Icons.cloud_done_rounded, size: 18),
                label: const Text('Doğrula & Kaydet'),
              ),
            ],
          );
        },
      ),
    ),
  );

  gmailCtrl.dispose();
  folderCtrl.dispose();
  tokenCtrl.dispose();
  clientIdCtrl.dispose();
  clientSecretCtrl.dispose();
  profileIdCtrl.dispose();
  profileLabelCtrl.dispose();
  workspaceKeyCtrl.dispose();
  passphraseCtrl.dispose();
}

class _BranchInboxSyncSection extends StatelessWidget {
  final _CloudDialogPalette pal;
  final List<Branch> branches;
  final List<BranchInboxDeviceStatus> inboxStatuses;
  final int? selectedBranchId;
  final bool isBusy;
  final bool isPulling;
  final ValueChanged<int?> onBranchChanged;
  final Future<void> Function() onPullInboxes;
  final Future<void> Function(Branch branch) onCopyConfigJson;

  const _BranchInboxSyncSection({
    required this.pal,
    required this.branches,
    required this.inboxStatuses,
    required this.selectedBranchId,
    required this.isBusy,
    required this.isPulling,
    required this.onBranchChanged,
    required this.onPullInboxes,
    required this.onCopyConfigJson,
  });

  @override
  Widget build(BuildContext context) {
    Branch? selectedBranch;
    if (branches.isNotEmpty) {
      selectedBranch = branches.firstWhere(
        (b) => b.id == selectedBranchId,
        orElse: () => branches.first,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Şube Yüz Okutma Köprüleri (Otomatik Cihaz Kutuları)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Her şube akıllı terazisi kendi şifreli cihaz kutusuna (hasibu_branch_inbox_*.enc) yazar; merkez verileri çakışmasız otomatik birleştirir.',
            style: TextStyle(fontSize: 11, color: pal.textSecondary),
          ),
          const SizedBox(height: 8),
          if (inboxStatuses.isEmpty)
            Text(
              'Henüz şube cihaz kutusu senkronize edilmedi (her 60 sn\'de bir otomatik taranır).',
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: pal.textSecondary,
              ),
            )
          else
            for (final item in inboxStatuses)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: pal.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hub_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.branchName.isNotEmpty ? item.branchName : item.deviceSlug} • ${item.fileName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: pal.textPrimary,
                            ),
                          ),
                          Text(
                            '${item.logCount} hareket • ${item.source} • ${_formatDateTimeShort(item.modifiedTime)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('btn_pull_branch_inboxes'),
                onPressed: (isBusy || isPulling) ? null : onPullInboxes,
                icon: isPulling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 17),
                label: const Text('Şube Kutularını Şimdi Çek'),
              ),
              if (branches.isNotEmpty && selectedBranch != null) ...[
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey<int>(selectedBranch.id),
                    initialValue: selectedBranch.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Kurulacak Şube',
                    ),
                    items: [
                      for (final b in branches)
                        DropdownMenuItem<int>(
                          value: b.id,
                          child: Text(
                            b.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: onBranchChanged,
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('btn_copy_branch_bridge_config'),
                  onPressed: isBusy
                      ? null
                      : () => onCopyConfigJson(selectedBranch!),
                  icon: const Icon(Icons.copy_all_rounded, size: 17),
                  label: const Text('Şube Köprüsü Ayar JSON Kopyala'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
