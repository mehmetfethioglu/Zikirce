import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/company_logo_service.dart';
import '../../data/tenfei_zk_client.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import '../widgets/employee_profile_avatar.dart';
import '../widgets/hasibu_theme_palette.dart';
import 'cloud_backup_center_dialog.dart';

/// Kurumsal logo, Tenfei terminal tanılama/çekim, tarih seçici, İK talep,
/// Gmail Drive eşitleme ve CSV puantaj dışa aktarım dialogları (Katman 5).

Future<void> showCompanyLogoDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final feedback = await showDialog<String>(
    context: context,
    builder: (_) => const _CompanyLogoSettingsDialog(),
  );
  if (feedback != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(feedback),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _CompanyLogoSettingsDialog extends ConsumerStatefulWidget {
  const _CompanyLogoSettingsDialog();

  @override
  ConsumerState<_CompanyLogoSettingsDialog> createState() =>
      _CompanyLogoSettingsDialogState();
}

class _CompanyLogoSettingsDialogState
    extends ConsumerState<_CompanyLogoSettingsDialog> {
  late final TextEditingController _pathCtrl;
  late final TextEditingController _nameCtrl;
  Uint8List? _pickedPreviewBytes;
  String? _validationError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(pdksDashboardProvider).companySettings;
    _pathCtrl = TextEditingController(text: settings.logoPath ?? 'logo:1');
    _nameCtrl = TextEditingController(text: settings.companyName);
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogoFile(CompanySettings settings) async {
    final picked =
        await ref.read(companyLogoPickerGatewayProvider).pickLogoImagePath();
    if (picked == null || !mounted) return;
    final inspected = CompanyLogoService.inspectLogoFile(
      rawInput: picked,
      currentSettings: settings,
    );
    if (!mounted) return;
    setState(() {
      _pathCtrl.text = picked;
      if (inspected.isValid) {
        _pickedPreviewBytes = inspected.previewBytes;
        _validationError = null;
      } else {
        _pickedPreviewBytes = null;
        _validationError = inspected.errorMessage;
      }
    });
  }

  Future<void> _save(CompanySettings settings) async {
    setState(() {
      _isSaving = true;
      _validationError = null;
    });
    final prepared = await CompanyLogoService.prepareLogoForSave(
      rawInput: _pathCtrl.text,
      currentSettings: settings,
    );
    if (!prepared.isValid) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _validationError = prepared.errorMessage;
        });
      }
      return;
    }
    if (prepared.storedPath != null &&
        !prepared.storedPath!.startsWith('logo:')) {
      try {
        PaintingBinding.instance.imageCache.evict(
          FileImage(File(prepared.storedPath!)),
        );
      } catch (e) {
        debugPrint('showCompanyLogoDialog: cache temizlenemedi ($e)');
      }
    }
    final notifier = ref.read(pdksDashboardProvider.notifier);
    await notifier.updateCompanySettings(
      settings.copyWith(
        companyName: _nameCtrl.text.trim().isEmpty
            ? settings.companyName
            : _nameCtrl.text.trim(),
        logoPath: () => prepared.storedPath,
        logoDataBase64: () => prepared.base64Data,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop(
        prepared.warningMessage ?? '✓ İşletme adı ve şirket logosu kaydedildi.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.read(pdksDashboardProvider).companySettings;
    final previewPath = CompanyLogoService.normalizeInputPath(_pathCtrl.text);
    final previewIsPreset = previewPath.startsWith('logo:');
    final previewSettings = settings.copyWith(
      companyName: _nameCtrl.text.trim().isEmpty
          ? settings.companyName
          : _nameCtrl.text.trim(),
      logoPath: () => previewPath.isEmpty ? null : previewPath,
      logoDataBase64: () => (previewIsPreset || previewPath.isEmpty)
          ? null
          : settings.logoDataBase64,
    );
    final pal = HasibuPalette.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.verified_rounded, color: Color(0xFF0284C7)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Şirket Logosu & Kurumsal Kimlik Ayarı',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Row(
                  children: [
                    if (_pickedPreviewBytes != null && !previewIsPreset)
                      Container(
                        width: 58,
                        height: 58,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: pal.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: pal.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _pickedPreviewBytes!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      )
                    else
                      CompanyLogoBadge(
                        settings: previewSettings,
                        size: 58,
                        borderRadius: 14,
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            previewSettings.companyName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Seçtiğiniz logo hem Oturum Açma (Login) ekranında hem de uygulama üst barında gösterilir.',
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
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('company_logo_name_field'),
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Şirket / İşletme Adı',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('company_logo_path_field'),
                      controller: _pathCtrl,
                      onChanged: (_) => setState(() {
                        _pickedPreviewBytes = null;
                        _validationError = null;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Logo Dosya Yolu veya Stil Kodu',
                        hintText: r'C:\Logo\sirket_logo.png veya logo:1',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('company_logo_pick_file_button'),
                    onPressed: _isSaving ? null : () => _pickLogoFile(settings),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Dosya Seç'),
                  ),
                ],
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('company_logo_error_banner'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _validationError!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Hazır Kurumsal Amblem Stilleri:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.auto_awesome_rounded, size: 15),
                    label: const Text('Hasibu Mizan & Defter'),
                    selected: previewPath.isEmpty ||
                        previewPath == 'logo:1' ||
                        previewPath == 'logo:hasibu',
                    onSelected: (_) => setState(() {
                      _pathCtrl.text = 'logo:hasibu';
                      _pickedPreviewBytes = null;
                      _validationError = null;
                    }),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.architecture_rounded, size: 15),
                    label: const Text('Hasibu Monolitik H'),
                    selected: previewPath == 'logo:hasibu_alt',
                    onSelected: (_) => setState(() {
                      _pathCtrl.text = 'logo:hasibu_alt';
                      _pickedPreviewBytes = null;
                      _validationError = null;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Harf Amblemi'),
                    selected: previewPath == 'logo:initials',
                    onSelected: (_) => setState(() {
                      _pathCtrl.text = 'logo:initials';
                      _pickedPreviewBytes = null;
                      _validationError = null;
                    }),
                  ),
                  for (int i = 0; i < CompanyLogoBadge.presets.length; i++)
                    ChoiceChip(
                      avatar: Icon(
                        CompanyLogoBadge.presets[i].icon,
                        size: 15,
                      ),
                      label: Text(CompanyLogoBadge.presets[i].label),
                      selected: previewPath == 'logo:${i + 1}',
                      onSelected: (_) => setState(() {
                        _pathCtrl.text = 'logo:${i + 1}';
                        _pickedPreviewBytes = null;
                        _validationError = null;
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          key: const ValueKey('save_company_logo_button'),
          onPressed: _isSaving ? null : () => _save(settings),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: const Text('Logoyu & Kimliği Kaydet'),
        ),
      ],
    );
  }
}

class _SummaryMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      width: 175,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTerminalDiagnosticsDialog(
  BuildContext context,
  WidgetRef ref, {
  Branch? initialBranch,
}) async {
  final initState = ref.read(pdksDashboardProvider);
  if (initState.branches.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yetkili şube bulunamadı.')),
      );
    }
    return;
  }
  final isSingleBranchScoped = initState.isSingleBranchScoped;
  Branch selectedBranch = initialBranch ??
      initState.branches.firstWhere(
        (b) => b.hasTerminal,
        orElse: () => initState.branches.first,
      );
  final ipCtrl = TextEditingController(
    text: selectedBranch.terminalIp ?? '',
  );
  final portCtrl = TextEditingController(
    text: selectedBranch.terminalPort.toString(),
  );

  bool isTesting = false;
  bool isPulling = false;
  TenfeiConnectionDiagnostics? lastDiag;
  String? pullFeedback;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final pal = HasibuPalette.of(ctx);
        final branches = ref.watch(
          pdksDashboardProvider.select((s) => s.branches),
        );

        Future<void> runDiagnostic() async {
          setDialogState(() {
            isTesting = true;
            pullFeedback = null;
          });
          final ip = ipCtrl.text.trim();
          final port = int.tryParse(portCtrl.text.trim()) ?? 4370;
          final updatedBranch = selectedBranch.copyWith(
            hasTerminal: true,
            terminalIp: ip,
            terminalPort: port,
          );
          await ref.read(pdksDashboardProvider.notifier).saveBranch(updatedBranch);
          selectedBranch = updatedBranch;
          final diag = await ref
              .read(pdksDashboardProvider.notifier)
              .testBranchTerminalConnection(updatedBranch);
          if (dialogCtx.mounted) {
            setDialogState(() {
              isTesting = false;
              lastDiag = diag;
            });
          }
        }

        Future<void> pullNow() async {
          setDialogState(() {
            isPulling = true;
            pullFeedback = null;
          });
          final ip = ipCtrl.text.trim();
          final port = int.tryParse(portCtrl.text.trim()) ?? 4370;
          final updatedBranch = selectedBranch.copyWith(
            hasTerminal: true,
            terminalIp: ip,
            terminalPort: port,
          );
          await ref.read(pdksDashboardProvider.notifier).saveBranch(updatedBranch);
          selectedBranch = updatedBranch;
          final summary = await ref
              .read(pdksDashboardProvider.notifier)
              .pullFromTenfeiTerminals(onlyBranchId: updatedBranch.id);
          final latestState = ref.read(pdksDashboardProvider);
          if (dialogCtx.mounted) {
            setDialogState(() {
              isPulling = false;
              pullFeedback = latestState.terminalStatusMessage;
            });
            if (summary != null) {
              await showTerminalPullResultDialog(dialogCtx, ref, summary);
            }
          }
        }

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.network_check_rounded, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cihaz Bağlantı Kontrolü & Canlı Veri Çekme (TCP 4370)',
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
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aynı yerel ağdaki Tenfei D35 / ZKTeco yüz ve parmak izi terminaline doğrudan TCP 4370 soketi ve CMD_AUTH (1102) el sıkışması ile bağlanarak erişimi ve cihaz hafızasındaki hareket sayısını kontrol edin.',
                    style: TextStyle(fontSize: 12.5, color: pal.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'diag_branch_${selectedBranch.id}_$isSingleBranchScoped',
                    ),
                    isExpanded: true,
                    initialValue: branches.any((b) => b.id == selectedBranch.id)
                        ? selectedBranch.id
                        : (branches.isNotEmpty ? branches.first.id : null),
                    decoration: const InputDecoration(
                      labelText: 'Kontrol Edilecek Şube / Terminal',
                      prefixIcon: Icon(Icons.router_outlined),
                    ),
                    items: [
                      for (final b in branches)
                        DropdownMenuItem<int>(
                          value: b.id,
                          child: Text(
                            (b.terminalIp != null && b.terminalIp!.isNotEmpty)
                                ? '${b.name} (${b.terminalIp}:${b.terminalPort})'
                                : '${b.name} (Terminal IP tanımlı değil)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: isSingleBranchScoped
                        ? null
                        : (val) {
                            if (val == null) return;
                            final found =
                                branches.firstWhere((b) => b.id == val);
                            setDialogState(() {
                              selectedBranch = found;
                              ipCtrl.text = found.terminalIp ?? '';
                              portCtrl.text = found.terminalPort.toString();
                              lastDiag = null;
                              pullFeedback = null;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: ipCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Terminal IP Adresi',
                            hintText: '192.168.1.100',
                            prefixIcon: Icon(Icons.lan_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'TCP Port',
                            hintText: '4370',
                            prefixIcon: Icon(Icons.settings_ethernet_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('run_terminal_diag_button'),
                        onPressed: isTesting ? null : runDiagnostic,
                        icon: isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.radar_rounded, size: 18),
                        label: Text(
                          isTesting
                              ? 'Cihaz Test Ediliyor...'
                              : 'Bağlantıyı Şimdi Test Et',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('diag_pull_terminal_logs_button'),
                        onPressed: isPulling ? null : pullNow,
                        icon: isPulling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          isPulling
                              ? 'Hareketler Çekiliyor...'
                              : 'Cihazdan Hareketleri Şimdi Çek',
                        ),
                      ),
                    ],
                  ),
                  if (lastDiag != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: lastDiag!.isReachable
                            ? const Color(0xFF059669).withValues(alpha: 0.12)
                            : const Color(0xFFDC2626).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: lastDiag!.isReachable
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                lastDiag!.isReachable
                                    ? Icons.check_circle_rounded
                                    : Icons.error_outline_rounded,
                                color: lastDiag!.isReachable
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lastDiag!.isReachable
                                      ? 'BAĞLANTI BAŞARILI • CİHAZ ÇEVRİMİÇİ'
                                      : 'BAĞLANTI KURULAMADI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: lastDiag!.isReachable
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lastDiag!.message,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: pal.textPrimary,
                            ),
                          ),
                          if (lastDiag!.isReachable) ...[
                            const SizedBox(height: 6),
                            Text(
                              '• Protokol: TCP 4370 (CMD_CONNECT 1000 + CMD_AUTH 1102 Doğrulandı)\n'
                              '• Yanıt Süresi (Ping/Handshake): ${lastDiag!.latencyMs} ms\n'
                              '• Cihaz Hafızasındaki Hareket Kaydı: ${lastDiag!.recordCount} adet',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: pal.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (pullFeedback != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fact_check_rounded,
                            color: Color(0xFF0284C7),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pullFeedback!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: pal.textPrimary,
                              ),
                            ),
                          ),
                        ],
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
          ],
        );
      },
    ),
  );

  ipCtrl.dispose();
  portCtrl.dispose();
}

Future<void> pickPdksDateWithCalendar(
  BuildContext context,
  WidgetRef ref,
) async {
  final currentKey = ref.read(pdksDashboardProvider).selectedDate;
  final initialDate = DateTime.tryParse(currentKey) ?? DateTime.now();
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020, 1, 1),
    lastDate: DateTime(now.year + 2, 12, 31),
    helpText: 'PDKS Yoklama Tarihini Seçin',
    cancelText: 'İptal',
    confirmText: 'Tarihi Seç',
  );
  if (picked != null) {
    final key =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    ref.read(pdksDashboardProvider.notifier).setSelectedDate(key);
  }
}

Future<void> pullTerminalAndShowPopup(
  BuildContext context,
  WidgetRef ref, {
  int? onlyBranchId,
}) async {
  final summary = await ref
      .read(pdksDashboardProvider.notifier)
      .pullFromTenfeiTerminals(onlyBranchId: onlyBranchId);
  if (summary != null && context.mounted) {
    await showTerminalPullResultDialog(context, ref, summary);
  }
}

Future<void> showTerminalPullResultDialog(
  BuildContext context,
  WidgetRef ref,
  TerminalPullSummary summary,
) async {
  final selectedDateLabel =
      PdksDashboardNotifier.formatDisplayDate(summary.selectedDateAfterPull);
  final latestDateLabel = summary.latestPulledDateKey != null
      ? PdksDashboardNotifier.formatDisplayDate(summary.latestPulledDateKey!)
      : 'Kayıt Bulunamadı';
  final timeStr =
      '${summary.pulledAt.hour.toString().padLeft(2, '0')}:${summary.pulledAt.minute.toString().padLeft(2, '0')}:${summary.pulledAt.second.toString().padLeft(2, '0')}';

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final pal = HasibuPalette.of(dialogCtx);
      final statusColor = summary.anyReachable
          ? const Color(0xFF059669)
          : const Color(0xFFDC2626);

      return AlertDialog(
        key: const ValueKey('terminal_pull_result_popup'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              summary.anyReachable
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: statusColor,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                summary.anyReachable
                    ? 'Terminal Veri Çekimi Tamamlandı'
                    : 'Terminale Ulaşılamadı — Veri Çekilemedi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: pal.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    summary.anyReachable
                        ? 'Cihaz hafızasından toplam ${summary.totalFetched} hareket okundu ve ${summary.newInserted} yeni giriş/çıkış kaydı veritabanına eklendi (Saat: $timeStr).'
                        : 'Ağdaki Tenfei D35 (TCP 4370) yüz tanıma terminaline ulaşılamadı. Cihazın açık olduğunu ve aynı yerel ağda bulunduğunu kontrol edin (Saat: $timeStr).',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryMetricChip(
                      label: 'Cihazdan Okunan',
                      value: '${summary.totalFetched} Hareket',
                      color: const Color(0xFF0284C7),
                    ),
                    _SummaryMetricChip(
                      label: 'Yeni Eklenen',
                      value: '${summary.newInserted} Yeni Kayıt',
                      color: const Color(0xFF059669),
                    ),
                    _SummaryMetricChip(
                      label: 'Seçili Gün ($selectedDateLabel)',
                      value: '${summary.logsCountForSelectedDate} Hareket',
                      color: const Color(0xFF7C3AED),
                    ),
                    _SummaryMetricChip(
                      label: 'Cihazdaki Son Tarih',
                      value: latestDateLabel,
                      color: const Color(0xFFD97706),
                    ),
                  ],
                ),
                if (summary.branchMessages.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Terminal Bağlantı & Çekim Detayları:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final msg in summary.branchMessages)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: pal.subtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: pal.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            msg.contains('ulaşılamadı')
                                ? Icons.portable_wifi_off_rounded
                                : Icons.router_rounded,
                            size: 16,
                            color: msg.contains('ulaşılamadı')
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF059669),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: pal.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (summary.latestPulledDateKey != null &&
              summary.latestPulledDateKey != summary.selectedDateAfterPull)
            OutlinedButton.icon(
              key: const ValueKey('terminal_pull_jump_latest_date_button'),
              onPressed: () {
                ref
                    .read(pdksDashboardProvider.notifier)
                    .setSelectedDate(summary.latestPulledDateKey!);
                Navigator.of(dialogCtx).pop();
              },
              icon: const Icon(Icons.event_available_rounded, size: 16),
              label: Text('Son Hareket Gününe Git ($latestDateLabel)'),
            ),
          FilledButton.icon(
            key: const ValueKey('terminal_pull_popup_ok_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Tamam'),
          ),
        ],
      );
    },
  );
}

Future<void> showCreateHrRequestDialog(
  BuildContext context,
  WidgetRef ref, {
  required Employee employee,
  bool allowEmployeeSwitch = false,
  HrRequestType? initialRequestType,
}) async {
  final state = ref.read(pdksDashboardProvider);
  if (!state.canAccessBranch(employee.branchId)) {
    return;
  }
  final activeStatuses = state.dailyStatuses
      .where((s) => !s.employee.isSeparatedNow || s.employee.id == employee.id)
      .toList(growable: false);
  final selectableStatuses =
      activeStatuses.isNotEmpty ? activeStatuses : state.dailyStatuses;
  if (selectableStatuses.isEmpty) return;
  Employee selectedEmp =
      selectableStatuses.any((s) => s.employee.id == employee.id)
          ? employee
          : selectableStatuses.first.employee;
  HrRequestType selectedType =
      initialRequestType ?? HrRequestType.annualLeave;
  LeaveType selectedLeaveType = LeaveType.yillikIzin;
  bool isCheckInCorrection = false;

  final targetDateCtrl = TextEditingController(text: state.selectedDate);
  final endDateCtrl = TextEditingController(text: state.selectedDate);
  final timeCtrl = TextEditingController(text: '18:00');
  final overtimeCtrl = TextEditingController(text: '90');
  final reasonCtrl = TextEditingController(
    text: 'Resmi mazeret / vardiya bildirim talebi',
  );

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text(
          'Yeni İK Talebi Oluştur (İzin / Mesai / Hareket Düzeltme)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (allowEmployeeSwitch) ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedEmp.id,
                    decoration: const InputDecoration(
                      labelText: 'Personel Seçin',
                    ),
                    items: [
                      for (final s in selectableStatuses)
                        DropdownMenuItem<int>(
                          value: s.employee.id,
                          child: Text(
                            '${s.employee.fullName} (#${s.employee.cardNo})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (empId) {
                      if (empId == null) return;
                      final match = selectableStatuses.where(
                        (s) => s.employee.id == empId,
                      );
                      if (match.isNotEmpty) {
                        setDialogState(
                          () => selectedEmp = match.first.employee,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<HrRequestType>(
                  key: const ValueKey('hr_req_type_dropdown'),
                  isExpanded: true,
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Talep Türü',
                  ),
                  items: [
                    for (final t in HrRequestType.values)
                      DropdownMenuItem(
                        value: t,
                        child: Text(t.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedType = val);
                    }
                  },
                ),
                const SizedBox(height: 10),
                if (selectedType == HrRequestType.annualLeave) ...[
                  DropdownButtonFormField<LeaveType>(
                    isExpanded: true,
                    initialValue: selectedLeaveType,
                    decoration: const InputDecoration(
                      labelText: 'İzin Türü',
                    ),
                    items: [
                      for (final lt in LeaveType.values)
                        DropdownMenuItem(
                          value: lt,
                          child: Text(lt.label),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedLeaveType = v);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: targetDateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Başlangıç (YYYY-AA-GG)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: endDateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Bitiş (YYYY-AA-GG)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  TextField(
                    controller: targetDateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'İlgili Tarih (YYYY-AA-GG)',
                    ),
                  ),
                ],
                if (selectedType == HrRequestType.missingPunchCorrection) ...[
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Unutulan Giriş')),
                      ButtonSegment(
                        value: false,
                        label: Text('Unutulan Çıkış'),
                      ),
                    ],
                    selected: {isCheckInCorrection},
                    onSelectionChanged: (s) => setDialogState(
                      () => isCheckInCorrection = s.first,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Gerçekleşen Saat (SS:DD)',
                      hintText: '18:00',
                    ),
                  ),
                ],
                if (selectedType == HrRequestType.overtimeApproval) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: overtimeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fazla Mesai Süresi (Dakika)',
                      hintText: '90',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('hr_req_reason_field'),
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Talep Açıklaması / Gerekçe',
                  ),
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
          FilledButton.icon(
            key: const ValueKey('submit_hr_request_button'),
            onPressed: () async {
              final req = HrRequest(
                id: 'req_${selectedEmp.id}_${DateTime.now().millisecondsSinceEpoch}',
                employeeId: selectedEmp.id,
                employeeCardNo: selectedEmp.cardNo,
                employeeName: selectedEmp.fullName,
                type: selectedType,
                status: HrRequestStatus.pending,
                targetDate: targetDateCtrl.text.trim(),
                endDate: selectedType == HrRequestType.annualLeave
                    ? endDateCtrl.text.trim()
                    : null,
                requestedTime:
                    selectedType == HrRequestType.missingPunchCorrection
                        ? timeCtrl.text.trim()
                        : null,
                isCheckInCorrection: isCheckInCorrection,
                overtimeMinutes: selectedType == HrRequestType.overtimeApproval
                    ? (int.tryParse(overtimeCtrl.text.trim()) ?? 60)
                    : 0,
                leaveType: selectedLeaveType,
                reason: reasonCtrl.text.trim().isEmpty
                    ? selectedType.label
                    : reasonCtrl.text.trim(),
                createdAt: '${state.selectedDate} 09:00',
              );
              await ref
                  .read(pdksDashboardProvider.notifier)
                  .submitHrRequest(req);
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Talebi İK Onayına Gönder'),
          ),
        ],
      ),
    ),
  );

  targetDateCtrl.dispose();
  endDateCtrl.dispose();
  timeCtrl.dispose();
  overtimeCtrl.dispose();
  reasonCtrl.dispose();
}

Future<void> showGmailDriveSyncDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showCloudBackupCenterDialog(
    context,
    ref,
    onPickFolder: EmployeeProfileAvatar.pickFolderFromDesktop,
  );
}

Future<void> showPuantajCsvExportDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = ref.read(pdksDashboardProvider);
  if (state.isCommercialWriteLocked) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Salt-Okunur (Read-Only) Abonelik Kilidi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          '${state.licenseStatusMessage}\n\n'
          'Verileriniz silinmez ve güvenle görüntülenebilir; ancak Resmi Excel/CSV Puantaj dışa aktarımı aktif abonelik gerektirir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
    return;
  }
  final notifier = ref.read(pdksDashboardProvider.notifier);
  final csvContent = notifier.generateDailyPuantajCsv();
  final filePathCtrl = TextEditingController(
    text: 'Hasibu_Puantaj_${state.selectedDate}.csv',
  );
  String? exportFeedback;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final pal = HasibuPalette.of(ctx);
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.table_view_rounded, color: Color(0xFF059669)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Resmi PDKS & Puantaj Çizelgesi Dışa Aktarım (${state.selectedDate})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 680,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logo, Mikro, Netsis ve Excel ile doğrudan uyumlu (; ayraçlı) resmi puantaj verisi. Ek modül ücreti olmadan kopyalayabilir veya dosya olarak kaydedebilirsiniz.',
                  style: TextStyle(fontSize: 12, color: pal.textSecondary),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('puantaj_export_path_field'),
                  controller: filePathCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Kaydedilecek Dosya Adı / Yolu (.csv)',
                    prefixIcon: Icon(Icons.save_alt_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 240,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pal.subtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pal.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      csvContent,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11.5,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (exportFeedback != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    exportFeedback!,
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Kapat'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('copy_puantaj_csv_button'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csvContent));
                if (dialogCtx.mounted) {
                  setDialogState(() {
                    exportFeedback =
                        'Puantaj tablosu (${state.filteredByBranch.length} personel satırı) panoya kopyalandı.';
                  });
                }
              },
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Panoya Kopyala'),
            ),
            FilledButton.icon(
              key: const ValueKey('save_puantaj_csv_file_button'),
              onPressed: () async {
                try {
                  final targetPath = filePathCtrl.text.trim().isEmpty
                      ? 'Hasibu_Puantaj_${state.selectedDate}.csv'
                      : filePathCtrl.text.trim();
                  final f = File(targetPath);
                  await f.writeAsString('\uFEFF$csvContent');
                  if (dialogCtx.mounted) {
                    setDialogState(() {
                      exportFeedback =
                          'Excel uyumlu CSV dosyası kaydedildi: ${f.path}';
                    });
                  }
                } catch (_) {
                  if (dialogCtx.mounted) {
                    setDialogState(() {
                      exportFeedback =
                          'Panoya kopyalama hazır (Dosya yazma izni kısıtlı).';
                    });
                  }
                }
              },
              icon: const Icon(Icons.download_done_rounded, size: 16),
              label: const Text('CSV Olarak Kaydet'),
            ),
          ],
        );
      },
    ),
  );
  filePathCtrl.dispose();
}
