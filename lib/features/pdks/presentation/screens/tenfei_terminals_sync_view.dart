import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pdks_providers.dart';
import '../widgets/hasibu_theme_palette.dart';
import 'cloud_backup_center_dialog.dart';
import 'pdks_operational_dialogs.dart';

/// Yüz Tanıma & Parmak İzi Terminali (TCP 4370) ve Gmail Bulut Eşitleme ekranı.
class TenfeiTerminalsAndSyncView extends ConsumerWidget {
  const TenfeiTerminalsAndSyncView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final autoPoll =
        ref.watch(pdksDashboardProvider.select((s) => s.autoPollEnabled));
    final syncStatus =
        ref.watch(pdksDashboardProvider.select((s) => s.syncStatus));
    final isCloudBusy =
        ref.watch(pdksDashboardProvider.select((s) => s.isCloudBusy));
    final autoCloudEnabled = ref.watch(
      pdksDashboardProvider
          .select((s) => s.companySettings.autoCloudBackupEnabled),
    );
    final autoCloudMinutes = ref.watch(
      pdksDashboardProvider
          .select((s) => s.companySettings.autoCloudBackupMinutes),
    );
    final gmail = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.syncGmailAccount),
    );
    final terminalMsg =
        ref.watch(pdksDashboardProvider.select((s) => s.terminalStatusMessage));
    final pal = HasibuPalette.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sensors_rounded, color: Color(0xFF0284C7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Yüz Tanıma & Parmak İzi Terminali (TCP 4370) ve Gmail Bulut Eşitleme',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: autoPoll,
                    onChanged: (val) => ref
                        .read(pdksDashboardProvider.notifier)
                        .toggleAutoPoll(val),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Ağdaki yüz ve parmak izi terminallerine doğrudan TCP 4370 protokolüyle bağlanarak giriş-çıkış hareketlerini çeker ve tanımladığınız Gmail / Google Drive hesabıyla eşitler.',
                style: TextStyle(
                  color: pal.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pal.border),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terminal: $terminalMsg',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gmail / Drive (${gmail.isEmpty ? "Henüz tanımlanmadı" : gmail}): ${syncStatus.message}',
                          style: TextStyle(
                            fontSize: 12,
                            color: pal.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Otomatik Bulut Yedekleme: ${autoCloudEnabled ? "Aktif (Her $autoCloudMinutes dk)" : "Kapalı"}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('tenfei_tab_pull_all_button'),
                          onPressed: () =>
                              pullTerminalAndShowPopup(context, ref),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Terminalden Şimdi Veri Çek'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              showTerminalDiagnosticsDialog(context, ref),
                          icon: const Icon(
                            Icons.radar_rounded,
                            size: 16,
                          ),
                          label: const Text('Cihaz Bağlantı Kontrolü'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              showGmailDriveSyncDialog(context, ref),
                          icon: const Icon(
                            Icons.alternate_email_rounded,
                            size: 16,
                          ),
                          label: const Text('Gmail Hesabı Tanımla'),
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey('tenfei_btn_cloud_backup'),
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
                          icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                          label: const Text('Buluta Yedekle'),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('tenfei_btn_cloud_restore'),
                          onPressed: isCloudBusy
                              ? null
                              : () => showCloudRestoreDialog(context, ref),
                          icon: const Icon(
                            Icons.cloud_download_rounded,
                            size: 16,
                          ),
                          label: const Text('Buluttan Yükle'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: isCloudBusy
                              ? null
                              : () => ref
                                  .read(pdksDashboardProvider.notifier)
                                  .syncWithGoogleDriveNow(),
                          icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                          label: const Text('Şimdi Eşitle'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Kayıtlı Terminaller & Şube Bağlantıları',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final b in branches)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    const Color(0xFF0284C7).withValues(alpha: 0.14),
                child: Icon(
                  b.hasTerminal
                      ? Icons.face_retouching_natural_rounded
                      : Icons.qr_code_2_rounded,
                  color: const Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              title: Text(
                '${b.name} (${b.code})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: pal.textPrimary,
                ),
              ),
              subtitle: Text(
                b.hasTerminal
                    ? 'Aktif Terminal • IP: ${b.terminalIp}:${b.terminalPort} (Cihaz No: ${b.machineNo})'
                    : 'Mobil GPS Geofence Modu (${b.geofenceRadiusMeters.round()}m) • IP: ${b.terminalIp}:${b.terminalPort}',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
              trailing: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showTerminalDiagnosticsDialog(
                      context,
                      ref,
                      initialBranch: b,
                    ),
                    icon: const Icon(Icons.network_check_rounded, size: 16),
                    label: const Text('Bağlantı Kontrolü'),
                  ),
                  if (b.hasTerminal) ...[
                    OutlinedButton.icon(
                      key: ValueKey('sync_clock_btn_${b.id}'),
                      onPressed: () async {
                        final msg = await ref
                            .read(pdksDashboardProvider.notifier)
                            .syncBranchTerminalClock(b.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      },
                      icon: const Icon(Icons.schedule_send_rounded, size: 16),
                      label: const Text('Saat Eşitle'),
                    ),
                    OutlinedButton.icon(
                      key: ValueKey('sync_staff_btn_${b.id}'),
                      onPressed: () async {
                        final msg = await ref
                            .read(pdksDashboardProvider.notifier)
                            .syncEmployeesToBranchTerminal(b.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      },
                      icon: const Icon(Icons.sync_alt_rounded, size: 16),
                      label: const Text('Kadro Eşitle'),
                    ),
                  ],
                  FilledButton.tonal(
                    onPressed: () => pullTerminalAndShowPopup(
                      context,
                      ref,
                      onlyBranchId: b.id,
                    ),
                    child: const Text('Şimdi Çek'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
