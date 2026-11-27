import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/hasibu_security_service.dart';
import '../../../../core/services/google_drive_sync_service.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import '../widgets/employee_profile_avatar.dart';
import '../widgets/hasibu_theme_palette.dart';
import 'app_users_management_card.dart';
import 'cloud_backup_center_dialog.dart';
import 'hasibu_release_notes_dialog.dart';
import 'pdks_operational_dialogs.dart';

// ============================================================================
// 1. İŞLETME & ŞUBE VE TERMİNAL AYARLARI
// ============================================================================
class CompanyAndBranchesSettingsView extends ConsumerStatefulWidget {
  const CompanyAndBranchesSettingsView({super.key});

  @override
  ConsumerState<CompanyAndBranchesSettingsView> createState() =>
      _CompanyAndBranchesSettingsViewState();
}

class _CompanyAndBranchesSettingsViewState
    extends ConsumerState<CompanyAndBranchesSettingsView> {
  late final TextEditingController _companyNameCtrl;
  late final TextEditingController _pollMinutesCtrl;
  late final TextEditingController _adminUserCtrl;
  late final TextEditingController _adminPassCtrl;
  late final TextEditingController _empPinCtrl;
  late final TextEditingController _gmailCtrl;
  late final TextEditingController _driveFolderCtrl;
  String? _connectionTestFeedback;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(pdksDashboardProvider).companySettings;
    _companyNameCtrl = TextEditingController(text: settings.companyName);
    _pollMinutesCtrl =
        TextEditingController(text: settings.autoPollMinutes.toString());
    _adminUserCtrl = TextEditingController(text: settings.adminUsername);
    _adminPassCtrl = TextEditingController(
      text: HasibuSecurityService.isPasswordHashed(settings.adminPassword)
          ? ''
          : settings.adminPassword,
    );
    _empPinCtrl = TextEditingController(text: settings.defaultEmployeePin);
    _gmailCtrl = TextEditingController(text: settings.syncGmailAccount);
    _driveFolderCtrl = TextEditingController(text: settings.syncFolderPath);
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _pollMinutesCtrl.dispose();
    _adminUserCtrl.dispose();
    _adminPassCtrl.dispose();
    _empPinCtrl.dispose();
    _gmailCtrl.dispose();
    _driveFolderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(pdksDashboardProvider.select((s) => s.companySettings));
    final syncStatus =
        ref.watch(pdksDashboardProvider.select((s) => s.syncStatus));
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final isBranchScoped =
        ref.watch(pdksDashboardProvider.select((s) => s.isBranchScoped));
    final pal = HasibuPalette.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KART 1: ŞİRKET LOGOSU, KİŞİSEL TEMA & KURUMSAL KİMLİK AYARLARI
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pal.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kurumsal Kimlik, Şirket Logosu, Tema & Güvenlik Ayarları',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                // ŞİRKET LOGOSU KUTUSU
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: pal.subtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pal.border),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CompanyLogoBadge(
                            settings: settings,
                            size: 52,
                            borderRadius: 12,
                            onTap: () async {
                              await showCompanyLogoDialog(context, ref);
                              if (!mounted) return;
                              final updatedName = ref
                                  .read(pdksDashboardProvider)
                                  .companySettings
                                  .companyName;
                              if (_companyNameCtrl.text != updatedName) {
                                _companyNameCtrl.text = updatedName;
                              }
                            },
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Şirket Logosu & Kurumsal Amblem',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: pal.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Giriş (Login) ekranında, üst uygulama barında ve mobil personel portalında görüntülenir.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: pal.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('settings_company_logo_button'),
                        onPressed: () async {
                          await showCompanyLogoDialog(context, ref);
                          if (!mounted) return;
                          final updatedName = ref
                              .read(pdksDashboardProvider)
                              .companySettings
                              .companyName;
                          if (_companyNameCtrl.text != updatedName) {
                            _companyNameCtrl.text = updatedName;
                          }
                        },
                        icon: const Icon(Icons.image_outlined, size: 17),
                        label: const Text('Şirket Logosunu Değiştir / Ekle'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // KULLANICIYA ÖZGÜ TEMA SEÇİCİ (AÇIK / KOYU / SİSTEM)
                const UserThemeSelectorBar(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _companyNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Şirket / İşletme Adı',
                          prefixIcon: Icon(Icons.apartment_rounded),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _pollMinutesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Oto Çekim (Dk)',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: _adminUserCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Yönetici Kullanıcı',
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: TextField(
                        controller: _adminPassCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Yönetici Parolası',
                          hintText: HasibuSecurityService.isPasswordHashed(
                            settings.adminPassword,
                          )
                              ? 'Değiştirmek için yeni parola girin'
                              : null,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: _empPinCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Varsayılan Personel Parolası',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: settings.autoPollEnabled,
                          onChanged: (val) => ref
                              .read(pdksDashboardProvider.notifier)
                              .toggleAutoPoll(val),
                        ),
                        const Text(
                          'Otomatik Terminal Çekimi',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: pal.border),
                const SizedBox(height: 16),
                Text(
                  'Google (Gmail) & Bulut Veri Eşitleme Hesabı',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  syncStatus.stage == DriveSyncStage.syncing
                      ? '↻ Doğrulanıyor / Eşitleniyor (${settings.syncGmailAccount.isEmpty ? "Google Drive" : settings.syncGmailAccount}) • ${syncStatus.message}'
                      : (syncStatus.isTrulySynced
                          ? '✓ Doğrulanmış Google Bulut/Drive Eşitlemesi Aktif (${settings.syncGmailAccount.isEmpty ? "Google Drive" : settings.syncGmailAccount} • ${syncStatus.message})'
                          : (settings.syncGmailAccount.trim().isNotEmpty
                              ? '⚠️ E-posta kayıtlı (${settings.syncGmailAccount}) ancak Google OAuth 2.0 girişi veya Drive klasörü doğrulanmadı • ${syncStatus.message}'
                              : 'Cihazlar arası gerçek bulut eşitleme için "Google OAuth 2.0 & Drive Doğrulama Merkezi" butonunu kullanarak Google hesabınızla giriş yapın.')),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: syncStatus.stage == DriveSyncStage.syncing ||
                            syncStatus.isTrulySynced
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: syncStatus.stage == DriveSyncStage.syncing
                        ? const Color(0xFF0284C7)
                        : (syncStatus.isTrulySynced
                            ? const Color(0xFF10B981)
                            : (settings.syncGmailAccount.trim().isNotEmpty
                                ? const Color(0xFFD97706)
                                : pal.textSecondary)),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _gmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Gmail Adresi (Eşitleme Hesabı)',
                          hintText: 'isletme@gmail.com',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _driveFolderCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Google Drive Klasör Yolu (İsteğe Bağlı)',
                          hintText: r"G:\Drive'ım\Hasibu\CloudSync",
                          prefixIcon: Icon(Icons.folder_shared_outlined),
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await showGmailDriveSyncDialog(context, ref);
                        final updated =
                            ref.read(pdksDashboardProvider).companySettings;
                        if (mounted) {
                          setState(() {
                            _gmailCtrl.text = updated.syncGmailAccount;
                            _driveFolderCtrl.text = updated.syncFolderPath;
                          });
                        }
                      },
                      icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                      label: Text(
                        syncStatus.stage == DriveSyncStage.syncing
                            ? 'Google OAuth / Drive Doğrulanıyor...'
                            : (syncStatus.isTrulySynced
                                ? 'Google OAuth / Drive Doğrulandı (${settings.syncGmailAccount.isEmpty ? "Drive" : settings.syncGmailAccount})'
                                : 'Google OAuth 2.0 & Drive Doğrulama Merkezi'),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final mins =
                            int.tryParse(_pollMinutesCtrl.text.trim()) ?? 5;
                        final rawGmail = _gmailCtrl.text.trim();
                        final cleanGmail =
                            rawGmail.isNotEmpty && !rawGmail.contains('@')
                                ? '$rawGmail@gmail.com'
                                : rawGmail;
                        _gmailCtrl.text = cleanGmail;
                        final typedAdminPass = _adminPassCtrl.text.trim();
                        final shouldUpdateAdminPass =
                            typedAdminPass.isNotEmpty &&
                                !HasibuSecurityService.verifyPassword(
                                  typedAdminPass,
                                  settings.adminPassword,
                                );
                        final nextAdminPass = shouldUpdateAdminPass
                            ? HasibuSecurityService.hashPassword(typedAdminPass)
                            : settings.adminPassword;
                        final nextAdminUpdated = settings.adminPasswordUpdated ||
                            shouldUpdateAdminPass ||
                            !HasibuSecurityService.verifyPassword(
                              CompanySettings.defaultAdminPassword,
                              nextAdminPass,
                            );
                        await ref
                            .read(pdksDashboardProvider.notifier)
                            .updateCompanySettings(
                              settings.copyWith(
                                companyName: _companyNameCtrl.text.trim(),
                                autoPollMinutes: mins.clamp(1, 1440),
                                adminUsername: _adminUserCtrl.text.trim(),
                                adminPassword: nextAdminPass,
                                adminPasswordUpdated: nextAdminUpdated,
                                defaultEmployeePin: _empPinCtrl.text.trim(),
                                syncGmailAccount: cleanGmail,
                                syncFolderPath: _driveFolderCtrl.text.trim(),
                              ),
                            );
                        if (shouldUpdateAdminPass && mounted) {
                          _adminPassCtrl.clear();
                        }
                        final syncRes = await ref
                            .read(pdksDashboardProvider.notifier)
                            .saveGmailSyncAccount(
                              gmailAccount: cleanGmail,
                              syncFolderPath: _driveFolderCtrl.text.trim(),
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                syncRes.isTrulySynced
                                    ? '✓ Ayarlar kaydedildi ve Google Bulut/Drive bağlantısı doğrulandı.'
                                    : 'Ayarlar ve yerel yedek kaydedildi. Bulut eşitlemesi için Google OAuth 2.0 girişi veya Drive klasörü gereklidir.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Ayarları Kaydet'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const CloudBackupQuickCard(
                  onPickFolder: EmployeeProfileAvatar.pickFolderFromDesktop,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Şubeler & Yüz / Parmak İzi Terminalleri',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showBranchDialog(context, null),
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: const Text('Yeni Şube / Cihaz Ekle'),
              ),
            ],
          ),
          if (_connectionTestFeedback != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Text(
                _connectionTestFeedback!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0369A1),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final branch in branches)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pal.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pal.border),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: branch.hasTerminal
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          branch.hasTerminal
                              ? Icons.router_rounded
                              : Icons.storefront_rounded,
                          size: 20,
                          color: branch.hasTerminal
                              ? const Color(0xFF059669)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${branch.name} (${branch.code})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${branch.hasTerminal ? "Aktif Terminal" : "Mobil GPS Geofence Modu"}  •  '
                              'IP: ${branch.terminalIp ?? "-"}:${branch.terminalPort}  •  '
                              'Konum: ${branch.latitude}, ${branch.longitude} (${branch.geofenceRadiusMeters.round()}m)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          setState(() {
                            _connectionTestFeedback =
                                '${branch.name} (${branch.terminalIp}:${branch.terminalPort}) test ediliyor...';
                          });
                          final diag = await ref
                              .read(pdksDashboardProvider.notifier)
                              .testBranchTerminalConnection(branch);
                          if (mounted) {
                            setState(
                              () => _connectionTestFeedback = diag.message,
                            );
                          }
                        },
                        icon: const Icon(Icons.network_check_rounded, size: 16),
                        label: const Text('Bağlantı Testi'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => showTerminalDiagnosticsDialog(
                          context,
                          ref,
                          initialBranch: branch,
                        ),
                        icon: const Icon(Icons.radar_rounded, size: 16),
                        label: const Text('Cihaz Tanılama & Çek'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _showBranchDialog(context, branch),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Düzenle'),
                      ),
                      if (branch.id != 1)
                        IconButton(
                          tooltip: 'Şubeyi Sil',
                          color: const Color(0xFFDC2626),
                          onPressed: () => ref
                              .read(pdksDashboardProvider.notifier)
                              .deleteBranch(branch.id),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (!isBranchScoped) ...[
            const SizedBox(height: 12),
            const AppUsersManagementCard(),
          ],
          const SizedBox(height: 12),
          const HasibuReleaseNotesQuickCard(),
        ],
      ),
    );
  }

  Future<void> _showBranchDialog(BuildContext context, Branch? existing) async {
    final branches = ref.read(pdksDashboardProvider).branches;
    final nextId = existing?.id ??
        (branches.isEmpty
            ? 1
            : branches.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final ipCtrl = TextEditingController(text: existing?.terminalIp ?? '');
    final portCtrl = TextEditingController(
      text: (existing?.terminalPort ?? 4370).toString(),
    );
    final machineCtrl = TextEditingController(
      text: (existing?.machineNo ?? 1).toString(),
    );
    final latCtrl = TextEditingController(
      text: (existing?.latitude ?? 0.0).toString(),
    );
    final lngCtrl = TextEditingController(
      text: (existing?.longitude ?? 0.0).toString(),
    );
    final radiusCtrl = TextEditingController(
      text: (existing?.geofenceRadiusMeters ?? 150).round().toString(),
    );
    final commKeyCtrl = TextEditingController(
      text: (existing?.terminalCommKey ?? 0).toString(),
    );
    bool hasTerminal = existing?.hasTerminal ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Yeni Şube & Cihaz Ekle'
                    : '${existing.name} Ayarlarını Düzenle',
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Şube / Lokasyon Adı (örn. Merkez Şube)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Şube Kısa Kodu (örn. MERKEZ)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Bu Şubede Yüz / Parmak İzi Terminali Var',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Açıksa TCP 4370 üzerinden otomatik veri çekilir',
                        ),
                        value: hasTerminal,
                        onChanged: (v) => setDialogState(() => hasTerminal = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: ipCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cihaz IP Adresi',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: portCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port (4370)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: machineCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Makine No',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: commKeyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Terminal İletişim Şifresi (CommKey)',
                          helperText: 'Varsayılan 0 yerine şifreli CommKey',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'GPS Enlem (Lat)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lngCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'GPS Boylam (Lng)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: radiusCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Yarıçap (m)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final branch = Branch(
                      id: nextId,
                      code: codeCtrl.text.trim().isEmpty
                          ? 'SUBE_$nextId'
                          : codeCtrl.text.trim().toUpperCase(),
                      name: nameCtrl.text.trim(),
                      hasTerminal: hasTerminal,
                      terminalIp: ipCtrl.text.trim(),
                      terminalPort: int.tryParse(portCtrl.text.trim()) ?? 4370,
                      machineNo: int.tryParse(machineCtrl.text.trim()) ?? 1,
                      terminalCommKey:
                          int.tryParse(commKeyCtrl.text.trim()) ?? 0,
                      qrSecret: existing?.qrSecret ?? 'DISABLED',
                      latitude: double.tryParse(latCtrl.text.trim()) ?? 0.0,
                      longitude: double.tryParse(lngCtrl.text.trim()) ?? 0.0,
                      geofenceRadiusMeters:
                          double.tryParse(radiusCtrl.text.trim()) ?? 150.0,
                    );
                    await ref
                        .read(pdksDashboardProvider.notifier)
                        .saveBranch(branch);
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop();
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    codeCtrl.dispose();
    ipCtrl.dispose();
    portCtrl.dispose();
    machineCtrl.dispose();
    commKeyCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    radiusCtrl.dispose();
  }
}
