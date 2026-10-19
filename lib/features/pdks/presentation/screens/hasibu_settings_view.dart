import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';

/// Hasibu Ayarlar & Yönetim Merkezi:
/// 1) Şirket İsmi, Şube Özelleştirme ve Tenfei D35 Cihaz Bağlantı Ayarları
/// 2) Mesai Saat Aralıkları (Vardiyalar) ve Geç Kalma Tolerans Süreleri
/// 3) Personel Ekleme, Güncelleme ve Bölüm Atama
/// 4) Personel Giriş-Çıkış Hareketlerini Düzeltme / Manuel Ekleme
/// 5) İzinli ve Raporlu Personel Kayıt Yönetimi
class HasibuSettingsView extends StatefulWidget {
  const HasibuSettingsView({super.key});

  @override
  State<HasibuSettingsView> createState() => _HasibuSettingsViewState();
}

class _HasibuSettingsViewState extends State<HasibuSettingsView> {
  int _activeSubTab = 0;

  @override
  Widget build(BuildContext context) {
    const sections = <Widget>[
      _CompanyAndBranchesSection(),
      _ShiftAndLateToleranceSection(),
      _EmployeesManagementSection(),
      _AttendanceCorrectionSection(),
      _LeavesAndReportsSection(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SubTabChip(
                  index: 0,
                  activeIndex: _activeSubTab,
                  icon: Icons.business_rounded,
                  label: '1. Şirket, Şube & Cihaz Ayarları',
                  onTap: () => setState(() => _activeSubTab = 0),
                ),
                const SizedBox(width: 8),
                _SubTabChip(
                  index: 1,
                  activeIndex: _activeSubTab,
                  icon: Icons.schedule_rounded,
                  label: '2. Mesai Saatleri & Geç Kalma',
                  onTap: () => setState(() => _activeSubTab = 1),
                ),
                const SizedBox(width: 8),
                _SubTabChip(
                  index: 3,
                  activeIndex: _activeSubTab,
                  icon: Icons.edit_calendar_rounded,
                  label: '3. Hareket Düzeltme (Giriş/Çıkış)',
                  onTap: () => setState(() => _activeSubTab = 3),
                ),
                const SizedBox(width: 8),
                _SubTabChip(
                  index: 4,
                  activeIndex: _activeSubTab,
                  icon: Icons.medical_information_rounded,
                  label: '4. İzin & Rapor Girişi',
                  onTap: () => setState(() => _activeSubTab = 4),
                ),
                const SizedBox(width: 8),
                _SubTabChip(
                  index: 2,
                  activeIndex: _activeSubTab,
                  icon: Icons.manage_accounts_rounded,
                  label: '5. Personel & Bölüm Yönetimi',
                  onTap: () => setState(() => _activeSubTab = 2),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: sections[_activeSubTab]),
      ],
    );
  }
}

class _SubTabChip extends StatelessWidget {
  final int index;
  final int activeIndex;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SubTabChip({
    required this.index,
    required this.activeIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = index == activeIndex;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : const Color(0xFF0284C7),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : const Color(0xFF1E293B),
        ),
      ),
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: const Color(0xFFF1F5F9),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

// ============================================================================
// 1. ŞİRKET, ŞUBE VE TENFEI D35 CİHAZ BAĞLANTI AYARLARI
// ============================================================================
class _CompanyAndBranchesSection extends ConsumerStatefulWidget {
  const _CompanyAndBranchesSection();

  @override
  ConsumerState<_CompanyAndBranchesSection> createState() =>
      _CompanyAndBranchesSectionState();
}

class _CompanyAndBranchesSectionState
    extends ConsumerState<_CompanyAndBranchesSection> {
  late final TextEditingController _companyNameCtrl;
  late final TextEditingController _pollMinutesCtrl;
  String? _connectionTestFeedback;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(pdksDashboardProvider).companySettings;
    _companyNameCtrl = TextEditingController(text: settings.companyName);
    _pollMinutesCtrl =
        TextEditingController(text: settings.autoPollMinutes.toString());
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _pollMinutesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(pdksDashboardProvider.select((s) => s.companySettings));
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Şirket ve Otomasyon Kartı
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Şirket Kimliği & Otomatik Veri Çekme Ayarları',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 340,
                      child: TextField(
                        controller: _companyNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Şirket / İşletme Adı (Üst Başlıkta Görünür)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.apartment_rounded),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _pollMinutesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Otomatik Çekim (Dakika)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer_outlined),
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
                          'Otomatik Tenfei D35 Çekimi',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final mins =
                            int.tryParse(_pollMinutesCtrl.text.trim()) ?? 5;
                        await ref
                            .read(pdksDashboardProvider.notifier)
                            .updateCompanySettings(
                              settings.copyWith(
                                companyName: _companyNameCtrl.text.trim(),
                                autoPollMinutes: mins.clamp(1, 1440),
                              ),
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Şirket ve otomasyon ayarları kaydedildi.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Şirket Ayarlarını Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Şubeler & Tenfei D35 Yüz/Parmak İzi Terminalleri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            FilledButton.icon(
              onPressed: () => _showBranchDialog(context, null),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Yeni Şube / Cihaz Ekle'),
            ),
          ],
        ),
        if (_connectionTestFeedback != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF38BDF8)),
            ),
            child: Text(
              _connectionTestFeedback!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0369A1),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        for (final branch in branches)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: branch.hasTerminal
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFE0F2FE),
                        child: Icon(
                          branch.hasTerminal
                              ? Icons.router_rounded
                              : Icons.storefront_rounded,
                          color: branch.hasTerminal
                              ? const Color(0xFF15803D)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${branch.name} (Kod: ${branch.code})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Terminal Durumu: ${branch.hasTerminal ? "AKTİF (Tenfei D35)" : "Mobil QR / GPS Modu"}\n'
                              'Cihaz IP / Port: ${branch.terminalIp ?? "-"}:${branch.terminalPort} • Makine No: ${branch.machineNo}\n'
                              'GPS Konum: ${branch.latitude}, ${branch.longitude} (${branch.geofenceRadiusMeters.round()}m Geofence)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
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
          ),
      ],
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
    final ipCtrl =
        TextEditingController(text: existing?.terminalIp ?? '192.168.9.150');
    final portCtrl = TextEditingController(
      text: (existing?.terminalPort ?? 4370).toString(),
    );
    final machineCtrl = TextEditingController(
      text: (existing?.machineNo ?? 1).toString(),
    );
    final latCtrl = TextEditingController(
      text: (existing?.latitude ?? 37.1674).toString(),
    );
    final lngCtrl = TextEditingController(
      text: (existing?.longitude ?? 38.7955).toString(),
    );
    final radiusCtrl = TextEditingController(
      text: (existing?.geofenceRadiusMeters ?? 150).round().toString(),
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
                          labelText: 'Şube / Lokasyon Adı (örn. Şube Karaköprü)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Şube Kısa Kodu (örn. KARAKOPRU)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Bu Şubede Tenfei D35 / ZKTeco Terminal Var',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: portCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'TCP Port (4370)',
                                border: OutlineInputBorder(),
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
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
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
                                border: OutlineInputBorder(),
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
                                border: OutlineInputBorder(),
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
                                border: OutlineInputBorder(),
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
                      latitude: double.tryParse(latCtrl.text.trim()) ?? 37.1674,
                      longitude:
                          double.tryParse(lngCtrl.text.trim()) ?? 38.7955,
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
    latCtrl.dispose();
    lngCtrl.dispose();
    radiusCtrl.dispose();
  }
}

// ============================================================================
// 2. MESAİ SAAT ARALIKLARI (VARDİYALAR) & GEÇ KALMA TOLERANS SÜRELERİ
// ============================================================================
class _ShiftAndLateToleranceSection extends ConsumerWidget {
  const _ShiftAndLateToleranceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(pdksDashboardProvider.select((s) => s.shifts));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mesai Saat Aralıkları & Geç Kalma Tolerans Süreleri',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Personellerin hangi saat aralığında işe geleceğini ve kaç dakika gecikmeden sonra "Geç Geldi" sayılacağını buradan tanımlayabilirsiniz.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _showShiftDialog(context, ref, null),
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text('Yeni Mesai Saat Aralığı Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final shift in shifts)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFEF3C7),
                child: Icon(Icons.access_time_filled_rounded, color: Color(0xFFD97706)),
              ),
              title: Text(
                shift.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'İşe Geliş - Çıkış Aralığı: ${shift.startTime} - ${shift.endTime}  •  Geç Kalma Toleransı: ${shift.toleranceMinutes} dakika',
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _showShiftDialog(context, ref, shift),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Saat & Toleransı Düzenle'),
                  ),
                  if (shift.id != 1)
                    IconButton(
                      color: const Color(0xFFDC2626),
                      onPressed: () => ref
                          .read(pdksDashboardProvider.notifier)
                          .deleteShiftPlan(shift.id),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showShiftDialog(
    BuildContext context,
    WidgetRef ref,
    ShiftPlan? existing,
  ) async {
    final shifts = ref.read(pdksDashboardProvider).shifts;
    final nextId = existing?.id ??
        (shifts.isEmpty
            ? 1
            : shifts.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final startCtrl =
        TextEditingController(text: existing?.startTime ?? '08:00');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '18:00');
    final tolCtrl = TextEditingController(
      text: (existing?.toleranceMinutes ?? 15).toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          existing == null
              ? 'Yeni Mesai Saat Aralığı Tanımla'
              : 'Mesai Saatlerini & Geç Kalma Süresini Düzenle',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vardiya / Grup Adı (örn. Üretim Sabah)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Giriş Saati (SS:DD)',
                        hintText: '06:00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Çıkış Saati (SS:DD)',
                        hintText: '15:00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tolCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Geç Kalma Tolerans Süresi (Dakika)',
                  helperText:
                      'Örn: 15 yazılırsa 06:00 vardiyasında 06:16 ve sonrası Geç Geldi sayılır.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
              final shift = ShiftPlan(
                id: nextId,
                name: nameCtrl.text.trim(),
                startTime: startCtrl.text.trim(),
                endTime: endCtrl.text.trim(),
                toleranceMinutes: int.tryParse(tolCtrl.text.trim()) ?? 15,
              );
              await ref
                  .read(pdksDashboardProvider.notifier)
                  .saveShiftPlan(shift);
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    tolCtrl.dispose();
  }
}

// ============================================================================
// 3. PERSONEL HAREKETLERİNİ DÜZELTME & MANUEL GİRİŞ/ÇIKIŞ EKLEME
// ============================================================================
class _AttendanceCorrectionSection extends ConsumerStatefulWidget {
  const _AttendanceCorrectionSection();

  @override
  ConsumerState<_AttendanceCorrectionSection> createState() =>
      _AttendanceCorrectionSectionState();
}

class _AttendanceCorrectionSectionState
    extends ConsumerState<_AttendanceCorrectionSection> {
  late final TextEditingController _dateCtrl;
  late final TextEditingController _filterCtrl;

  @override
  void initState() {
    super.initState();
    final date = ref.read(pdksDashboardProvider).selectedDate;
    _dateCtrl = TextEditingController(text: date);
    _filterCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final q = _filterCtrl.text.trim().toUpperCase();
    final filtered = state.dailyStatuses.where((s) {
      if (q.isEmpty) return true;
      return s.employee.fullName.toUpperCase().contains(q) ||
          s.employee.cardNo.contains(q) ||
          s.branch.name.toUpperCase().contains(q);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'İşlem Tarihi (YYYY-AA-GG)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    final d = _dateCtrl.text.trim();
                    if (d.length >= 8) {
                      ref
                          .read(pdksDashboardProvider.notifier)
                          .setSelectedDate(d);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tarihi Yükle'),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _filterCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Personel veya Kart No Ara',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in filtered)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.employee.fullName} (#${item.employee.cardNo})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.branch.name} • ${item.department.name} • Vardiya: ${item.shift.startTime}-${item.shift.endTime} (${item.shift.toleranceMinutes} dk tol.)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (item.allLogsOfDay.isEmpty)
                              const Text(
                                'Bu tarihte giriş/çıkış hareketi yok',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            for (final log in item.allLogsOfDay)
                              Chip(
                                backgroundColor: log.isCheckIn
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
                                label: Text(
                                  '${log.isCheckIn ? "GİRİŞ" : "ÇIKIŞ"}: ${log.timeFormatted} (${log.source.label})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => ref
                                    .read(pdksDashboardProvider.notifier)
                                    .deleteAttendanceLog(log.id),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showEditAttendanceDialog(
                          context,
                          item.employee,
                          state.selectedDate,
                          existingLog: item.firstCheckIn,
                          defaultIsCheckIn: true,
                        ),
                        icon: const Icon(Icons.login_rounded, size: 16),
                        label: Text(
                          item.firstCheckIn == null
                              ? 'Giriş Saati Gir'
                              : 'Girişi Düzelt (${item.firstCheckIn!.timeFormatted})',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showEditAttendanceDialog(
                          context,
                          item.employee,
                          state.selectedDate,
                          existingLog: item.lastCheckOut,
                          defaultIsCheckIn: false,
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: Text(
                          item.lastCheckOut == null
                              ? 'Çıkış Saati Gir'
                              : 'Çıkışı Düzelt (${item.lastCheckOut!.timeFormatted})',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showEditAttendanceDialog(
    BuildContext context,
    Employee employee,
    String dateKey, {
    AttendanceLog? existingLog,
    required bool defaultIsCheckIn,
  }) async {
    final timeCtrl = TextEditingController(
      text: existingLog?.timeFormatted ?? (defaultIsCheckIn ? '06:00' : '15:00'),
    );
    bool isCheckIn = existingLog?.isCheckIn ?? defaultIsCheckIn;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${employee.fullName} Hareket Düzeltme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tarih: $dateKey • Kart No: #${employee.cardNo}'),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('İşe Giriş')),
                  ButtonSegment(value: false, label: Text('İşten Çıkış')),
                ],
                selected: {isCheckIn},
                onSelectionChanged: (s) =>
                    setDialogState(() => isCheckIn = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Saat (SS:DD)',
                  hintText: '06:00',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(pdksDashboardProvider.notifier)
                    .saveOrUpdateAttendanceLog(
                      existingLogId: existingLog?.id,
                      employee: employee,
                      dateKey: dateKey,
                      timeHhMm: timeCtrl.text.trim(),
                      isCheckIn: isCheckIn,
                    );
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    timeCtrl.dispose();
  }
}

// ============================================================================
// 4. İZİNLİ VE RAPORLU PERSONEL BİLGİLERİNİ GİRME / YÖNETME
// ============================================================================
class _LeavesAndReportsSection extends ConsumerStatefulWidget {
  const _LeavesAndReportsSection();

  @override
  ConsumerState<_LeavesAndReportsSection> createState() =>
      _LeavesAndReportsSectionState();
}

class _LeavesAndReportsSectionState
    extends ConsumerState<_LeavesAndReportsSection> {
  int? _selectedEmployeeId;
  LeaveType _selectedLeaveType = LeaveType.yillikIzin;
  late final TextEditingController _startDateCtrl;
  late final TextEditingController _endDateCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    final date = ref.read(pdksDashboardProvider).selectedDate;
    _startDateCtrl = TextEditingController(text: date);
    _endDateCtrl = TextEditingController(text: date);
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final employees =
        state.dailyStatuses.map((e) => e.employee).toList(growable: false);
    final empMap = {for (final e in employees) e.id: e};

    if (_selectedEmployeeId == null && employees.isNotEmpty) {
      _selectedEmployeeId = employees.first.id;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'İzinli veya Raporlu Personel Kaydı Oluştur',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 320,
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedEmployeeId,
                        decoration: const InputDecoration(
                          labelText: 'Personel Seçin',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final e in employees)
                            DropdownMenuItem(
                              value: e.id,
                              child: Text('${e.fullName} (#${e.cardNo})'),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedEmployeeId = v),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<LeaveType>(
                        initialValue: _selectedLeaveType,
                        decoration: const InputDecoration(
                          labelText: 'İzin / Rapor Türü',
                          border: OutlineInputBorder(),
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
                            setState(() => _selectedLeaveType = v);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: TextField(
                        controller: _startDateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Başlangıç (YYYY-AA-GG)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: TextField(
                        controller: _endDateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bitiş (YYYY-AA-GG)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama / Rapor Notu',
                          hintText: 'Örn: 3 Günlük Hastane Raporu',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final empId = _selectedEmployeeId;
                        if (empId == null) return;
                        final start =
                            DateTime.tryParse(_startDateCtrl.text.trim()) ??
                                DateTime(2026, 10, 19);
                        final end =
                            DateTime.tryParse(_endDateCtrl.text.trim()) ??
                                start;
                        final count = await ref
                            .read(pdksDashboardProvider.notifier)
                            .assignLeaveDateRange(
                              employeeId: empId,
                              startDate: start,
                              endDate: end,
                              leaveType: _selectedLeaveType,
                              note: _noteCtrl.text,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$count günlük ${_selectedLeaveType.label} kaydı eklendi.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('İzin / Rapor Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Kayıtlı İzinler & Sağlık Raporları (${state.allLeaveRecords.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final rec in state.allLeaveRecords)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: rec.leaveType == LeaveType.saglikRaporu
                    ? const Color(0xFFEDE9FE)
                    : const Color(0xFFE0F2FE),
                child: Icon(
                  rec.leaveType == LeaveType.saglikRaporu
                      ? Icons.local_hospital_rounded
                      : Icons.beach_access_rounded,
                  color: rec.leaveType == LeaveType.saglikRaporu
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF0284C7),
                ),
              ),
              title: Text(
                '${empMap[rec.employeeId]?.fullName ?? "Personel #${rec.employeeId}"} • ${rec.leaveType.label}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('Tarih: ${rec.date} • Not: ${rec.note}'),
              trailing: IconButton(
                color: const Color(0xFFDC2626),
                tooltip: 'İzin/Rapor Kaydını Sil',
                onPressed: () => ref
                    .read(pdksDashboardProvider.notifier)
                    .deleteLeaveRecord(rec.id),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 5. PERSONEL & DEPARTMAN (ÜRETİM BÖLÜMÜ) YÖNETİMİ
// ============================================================================
class _EmployeesManagementSection extends ConsumerStatefulWidget {
  const _EmployeesManagementSection();

  @override
  ConsumerState<_EmployeesManagementSection> createState() =>
      _EmployeesManagementSectionState();
}

class _EmployeesManagementSectionState
    extends ConsumerState<_EmployeesManagementSection> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final q = _searchCtrl.text.trim().toUpperCase();
    final filtered = state.dailyStatuses.where((s) {
      if (q.isEmpty) return true;
      return s.employee.fullName.toUpperCase().contains(q) ||
          s.employee.cardNo.contains(q) ||
          s.department.name.toUpperCase().contains(q);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Personel Adı, Kart No veya Bölüm Ara',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAddDepartmentDialog(context),
                  icon: const Icon(Icons.category_rounded),
                  label: const Text('Yeni Bölüm Ekle'),
                ),
                FilledButton.icon(
                  onPressed: () => _showEmployeeDialog(context, null),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Yeni Personel Ekle'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final item in filtered)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              title: Text(
                '${item.employee.fullName} (Kart No: #${item.employee.cardNo})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'Şube: ${item.branch.name} • Bölüm: ${item.department.name} • Unvan: ${item.employee.title}\n'
                'Mesai: ${item.shift.name} • Yıllık İzin: ${item.employee.remainingAnnualLeave}/${item.employee.annualLeaveEntitlement} Gün • KPI: %${item.employee.kpiScore.toStringAsFixed(0)}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 6,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _showEmployeeDialog(context, item.employee),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Düzenle'),
                  ),
                  IconButton(
                    color: const Color(0xFFDC2626),
                    tooltip: 'Personeli Sil',
                    onPressed: () => ref
                        .read(pdksDashboardProvider.notifier)
                        .deleteEmployee(item.employee.id),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showAddDepartmentDialog(BuildContext context) async {
    final state = ref.read(pdksDashboardProvider);
    final nameCtrl = TextEditingController();
    int selectedBranchId =
        state.branches.isNotEmpty ? state.branches.first.id : 1;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Üretim Bölümü / Departman Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bölüm Adı (örn. PAKETLEME)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedBranchId,
                decoration: const InputDecoration(
                  labelText: 'Bağlı Şube',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final b in state.branches)
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedBranchId = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final nextId = state.departments.isEmpty
                    ? 1
                    : state.departments
                            .map((d) => d.id)
                            .reduce((a, b) => a > b ? a : b) +
                        1;
                await ref.read(pdksDashboardProvider.notifier).saveDepartment(
                      Department(
                        id: nextId,
                        name: nameCtrl.text.trim(),
                        branchId: selectedBranchId,
                      ),
                    );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _showEmployeeDialog(
    BuildContext context,
    Employee? existing,
  ) async {
    final state = ref.read(pdksDashboardProvider);
    final nextId = existing?.id ??
        (state.dailyStatuses.isEmpty
            ? 3000
            : state.dailyStatuses
                    .map((s) => s.employee.id)
                    .reduce((a, b) => a > b ? a : b) +
                1);

    final cardCtrl = TextEditingController(
      text: existing?.cardNo ?? nextId.toString().padLeft(5, '0'),
    );
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final titleCtrl =
        TextEditingController(text: existing?.title ?? 'ÜRETİM PERSONELİ');
    final hireCtrl =
        TextEditingController(text: existing?.hireDate ?? '2026-10-19');
    final leaveEntCtrl = TextEditingController(
      text: (existing?.annualLeaveEntitlement ?? 14).toString(),
    );
    final leaveUsedCtrl = TextEditingController(
      text: (existing?.usedAnnualLeave ?? 0).toString(),
    );
    final kpiCtrl = TextEditingController(
      text: (existing?.kpiScore ?? 95.0).toStringAsFixed(0),
    );

    int branchId = existing?.branchId ??
        (state.branches.isNotEmpty ? state.branches.first.id : 1);
    int deptId = existing?.departmentId ??
        (state.departments.isNotEmpty ? state.departments.first.id : 1);
    int shiftId = existing?.shiftId ??
        (state.shifts.isNotEmpty ? state.shifts.first.id : 1);
    bool sgkActive = existing?.sgkActive ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Yeni Personel Kaydı'
                : '${existing.fullName} Bilgilerini Güncelle',
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cardCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tenfei D35 Kart/PIN No (örn. 00064)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ad Soyad',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Görev / Unvan',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: hireCtrl,
                          decoration: const InputDecoration(
                            labelText: 'İşe Giriş (YYYY-AA-GG)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: branchId,
                    decoration: const InputDecoration(
                      labelText: 'Çalıştığı Şube / Merkez',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final b in state.branches)
                        DropdownMenuItem(value: b.id, child: Text(b.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => branchId = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: deptId,
                    decoration: const InputDecoration(
                      labelText: 'Bölüm / Departman',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final d in state.departments)
                        DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => deptId = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: shiftId,
                    decoration: const InputDecoration(
                      labelText: 'Mesai Saat Aralığı (Vardiya)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final s in state.shifts)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.name} (${s.startTime}-${s.endTime} • ${s.toleranceMinutes} dk tol.)',
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => shiftId = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: leaveEntCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Yıllık İzin Hakkı',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: leaveUsedCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Kullanılan İzin',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: kpiCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'KPI Puanı (%)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('SGK Sigortalılık Durumu Aktif'),
                    value: sgkActive,
                    onChanged: (v) => setDialogState(() => sgkActive = v),
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
                final emp = Employee(
                  id: nextId,
                  cardNo: cardCtrl.text.trim().padLeft(5, '0'),
                  fullName: nameCtrl.text.trim().toUpperCase(),
                  title: titleCtrl.text.trim().toUpperCase(),
                  departmentId: deptId,
                  branchId: branchId,
                  shiftId: shiftId,
                  hireDate: hireCtrl.text.trim(),
                  sgkActive: sgkActive,
                  annualLeaveEntitlement:
                      int.tryParse(leaveEntCtrl.text.trim()) ?? 14,
                  usedAnnualLeave: int.tryParse(leaveUsedCtrl.text.trim()) ?? 0,
                  kpiScore: double.tryParse(kpiCtrl.text.trim()) ?? 92.0,
                );
                await ref
                    .read(pdksDashboardProvider.notifier)
                    .saveEmployee(emp);
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    cardCtrl.dispose();
    nameCtrl.dispose();
    titleCtrl.dispose();
    hireCtrl.dispose();
    leaveEntCtrl.dispose();
    leaveUsedCtrl.dispose();
    kpiCtrl.dispose();
  }
}
