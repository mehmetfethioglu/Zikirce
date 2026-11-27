import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pdks/domain/pdks_models.dart';
import '../features/pdks/domain/pdks_print_builders.dart';
import '../features/pdks/presentation/providers/pdks_providers.dart';
import '../features/pdks/presentation/screens/hasibu_print_preview_dialog.dart';
import '../features/pdks/presentation/screens/hasibu_settings_view.dart';
import '../providers/mobil_arayuz_iyilestirme_provider.dart';

/// [HW-06] Mobil saha konum verisi (Sahte GPS `position.isMocked` denetimi için)
class MobileGpsPosition {
  final double latitude;
  final double longitude;
  final bool isMocked;

  const MobileGpsPosition({
    required this.latitude,
    required this.longitude,
    this.isMocked = false,
  });
}

/// Modern Mobil Kullanıcı Arayüzü Ekranı
/// Tek elle rahat kullanım, responsive kart hiyerarşisi ve akıcı dokunmatik etkileşim.
class MobilArayuzIyilestirmeScreen extends ConsumerWidget {
  const MobilArayuzIyilestirmeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final companySettings = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings),
    );
    final authSession = ref.watch(
      pdksDashboardProvider.select((s) => s.authSession),
    );
    final densityMode = ref.watch(
      mobileUiProvider.select((s) => s.densityMode),
    );
    final isCompact = densityMode == MobileDensityMode.compact;

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: pal.card,
        foregroundColor: pal.textPrimary,
        titleSpacing: 12,
        title: Row(
          children: [
            CompanyLogoBadge(
              key: const ValueKey('mobile_company_logo_badge'),
              settings: companySettings,
              size: 32,
              borderRadius: 8,
              onTap: authSession.canAccess(HasibuModule.systemSettings)
                  ? () => showCompanyLogoDialog(context, ref)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    companySettings.companyName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: pal.textPrimary,
                    ),
                  ),
                  Text(
                    'Mobil PDKS & Saha Yönetimi',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: pal.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('mobile_print_list_button'),
            tooltip: 'Listeyi Yazdır',
            icon: const Icon(Icons.print_outlined, size: 20),
            onPressed: () {
              final s = ref.read(pdksDashboardProvider);
              final doc = HasibuPrintBuilders.buildLiveAttendanceListDocument(
                companySettings: s.companySettings,
                selectedDateKey: s.selectedDate,
                filterDescription: s.searchQuery.trim().isNotEmpty
                    ? 'Mobil Görünüm • Arama: "${s.searchQuery.trim()}"'
                    : 'Mobil Görünüm',
                items: s.visibleStatuses,
                totalCount: s.totalCount,
                presentCount: s.presentCount,
                lateCount: s.lateCount,
                absentCount: s.absentCount,
                onLeaveCount: s.onLeaveCount,
                sickReportCount: s.sickReportCount,
              );
              showHasibuPrintPreviewDialog(context, ref, document: doc);
            },
          ),
          // Görünüm yoğunluğu değiştirici (Ferah / Kompakt)
          IconButton(
            tooltip: isCompact ? 'Ferah Kart Görünümü' : 'Kompakt Liste',
            icon: Icon(
              isCompact ? Icons.view_agenda_rounded : Icons.view_headline_rounded,
              size: 20,
              color: const Color(0xFF0284C7),
            ),
            onPressed: () =>
                ref.read(mobileUiProvider.notifier).toggleDensityMode(),
          ),
          // Tema değiştirici
          const UserThemeSelectorBar(compact: true),
          // Mobil Hızlı Menü
          IconButton(
            tooltip: 'Hızlı İşlemler',
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onPressed: () => _showMobileActionMenu(context, ref),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: pal.border),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0284C7),
        backgroundColor: pal.card,
        onRefresh: () async {
          await ref.read(mobileUiProvider.notifier).triggerMobileRefresh(
            onRefreshCallback: () async {
              await pullTerminalAndShowPopup(context, ref);
            },
          );
        },
        child: const CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _MobileTopHeaderSection()),
            SliverToBoxAdapter(child: _MobileFilterAndSearchSection()),
            _MobileEmployeeSliverList(),
          ],
        ),
      ),
      bottomNavigationBar: const _MobileBottomNavigationBar(),
    );
  }

  void _showMobileActionMenu(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final authSession = ref.read(
      pdksDashboardProvider.select((s) => s.authSession),
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: pal.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.radar_rounded, color: Color(0xFF0284C7)),
                  title: const Text('Cihaz Bağlantı Tanılama (Tenfei D35)'),
                  subtitle: const Text('TCP 4370 soket ve veri akış testi'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showTerminalDiagnosticsDialog(context, ref);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF10B981)),
                  title: const Text('Google Drive & Gmail Eşitleme'),
                  subtitle: const Text('Bulut yedekleme ve anlık veri aktarımı'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showGmailDriveSyncDialog(context, ref);
                  },
                ),
                if (authSession.canAccess(HasibuModule.systemSettings))
                  ListTile(
                    leading: const Icon(Icons.settings_suggest_rounded, color: Color(0xFFF59E0B)),
                    title: const Text('Sistem & Firma Parametreleri'),
                    subtitle: const Text('Şubeler, vardiyalar ve kullanıcı yetkileri'),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref
                          .read(pdksDashboardProvider.notifier)
                          .selectModule(HasibuModule.systemSettings);
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  title: Text(
                    'Oturumu Kapat (${authSession.displayName})',
                    style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(pdksDashboardProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Üst Tarih ve Durum Bilgi Şeridi
class _MobileTopHeaderSection extends ConsumerWidget {
  const _MobileTopHeaderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final selectedDate =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedDate));
    final terminalMsg =
        ref.watch(pdksDashboardProvider.select((s) => s.terminalStatusMessage));
    final isPolling =
        ref.watch(pdksDashboardProvider.select((s) => s.isPollingTerminal));
    final mockGpsCount =
        ref.watch(pdksDashboardProvider.select((s) => s.mockGpsAnomalyCount));

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canlı durum kapsülü
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: pal.border),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPolling ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    terminalMsg,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
                if (isPolling)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Takvim Tarih Seçici & Canlı Veri Çekme Şeridi
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  key: const ValueKey('mobile_calendar_date_picker_button'),
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(
                    Icons.calendar_month_rounded,
                    size: 15,
                    color: Color(0xFF0284C7),
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        PdksDashboardNotifier.formatDisplayDate(selectedDate),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, size: 16),
                    ],
                  ),
                  onPressed: () => pickPdksDateWithCalendar(context, ref),
                ),
                if (selectedDate != PdksDashboardNotifier.todayDateKey()) ...[
                  const SizedBox(width: 6),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(
                      Icons.today_rounded,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    label: const Text(
                      'Bugüne Dön',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => ref
                        .read(pdksDashboardProvider.notifier)
                        .setSelectedDate(PdksDashboardNotifier.todayDateKey()),
                  ),
                ],
                const SizedBox(width: 6),
                ActionChip(
                  key: const ValueKey('mobile_terminal_pull_button'),
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(
                    Icons.sync_rounded,
                    size: 15,
                    color: Color(0xFF0284C7),
                  ),
                  label: const Text(
                    'Veri Çek',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: isPolling
                      ? null
                      : () => pullTerminalAndShowPopup(context, ref),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  key: const ValueKey('mobile_qr_gps_checkin_button'),
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(
                    Icons.my_location_rounded,
                    size: 15,
                    color: Color(0xFF10B981),
                  ),
                  label: const Text(
                    'Saha GPS Giriş',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => _showMobileQrGpsCheckInSheet(context, ref),
                ),
                if (mockGpsCount > 0) ...[
                  const SizedBox(width: 6),
                  ActionChip(
                    key: const ValueKey('mobile_mock_gps_anomaly_chip'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        const Color(0xFFDC2626).withValues(alpha: 0.16),
                    avatar: const Icon(
                      Icons.gps_off_rounded,
                      size: 15,
                      color: Color(0xFFDC2626),
                    ),
                    label: Text(
                      'Sahte GPS Anomalisi ($mockGpsCount)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    onPressed: () => ref
                        .read(pdksDashboardProvider.notifier)
                        .setAnomalyFilter(PdksAnomalyFilter.missingCheckOut),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Mobil Uyumlu Responsive KPI Özeti
          const _MobileResponsiveKpiCards(),
        ],
      ),
    );
  }

  /// [HW-06] Mobil konumda `position.isMocked` (Sahte GPS) kontrolü yapar.
  static Future<String> submitMobilePositionCheckIn({
    required WidgetRef ref,
    required Employee employee,
    required Branch branch,
    required bool isCheckIn,
    required MobileGpsPosition position,
  }) async {
    return ref.read(pdksDashboardProvider.notifier).recordBranchMobileCheckIn(
          employee: employee,
          branch: branch,
          source: AttendanceSource.mobileGps,
          isCheckIn: isCheckIn,
          currentLat: position.latitude,
          currentLng: position.longitude,
          isMockedGps: position.isMocked,
        );
  }

  Future<void> _showMobileQrGpsCheckInSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final state = ref.read(pdksDashboardProvider);
    if (state.dailyStatuses.isEmpty || state.branches.isEmpty) return;
    Employee selectedEmp = state.dailyStatuses.first.employee;
    Branch selectedBranch = state.branches.first;
    bool isCheckIn = true;
    bool simulateMockedGps = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Mobil Saha GPS Yoklama (Geofence + Anti-Spoof)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedBranch.id,
                    decoration: const InputDecoration(labelText: 'Şube'),
                    items: [
                      for (final b in state.branches)
                        DropdownMenuItem(value: b.id, child: Text(b.name)),
                    ],
                    onChanged: state.isSingleBranchScoped
                        ? null
                        : (v) {
                            if (v == null) return;
                            setDialogState(() {
                              selectedBranch =
                                  state.branches.firstWhere((b) => b.id == v);
                            });
                          },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Sahte Konum (position.isMocked) Testi',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Açıkken hareket reddedilir ve anomali çipine düşürülür.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: simulateMockedGps,
                    onChanged: (v) =>
                        setDialogState(() => simulateMockedGps = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Kapat'),
              ),
              FilledButton(
                onPressed: () async {
                  final position = MobileGpsPosition(
                    latitude: selectedBranch.latitude,
                    longitude: selectedBranch.longitude,
                    isMocked: simulateMockedGps,
                  );
                  final res = await submitMobilePositionCheckIn(
                    ref: ref,
                    employee: selectedEmp,
                    branch: selectedBranch,
                    isCheckIn: isCheckIn,
                    position: position,
                  );
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res)),
                    );
                  }
                },
                child: const Text('Kaydı Gönder'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Mobil Ekrana Tam Uyum Sağlayan 2x3 Responsive KPI Izgarası
class _MobileResponsiveKpiCards extends ConsumerWidget {
  const _MobileResponsiveKpiCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(pdksDashboardProvider.select((s) => s.totalCount));
    final present = ref.watch(pdksDashboardProvider.select((s) => s.presentCount));
    final lateCount = ref.watch(pdksDashboardProvider.select((s) => s.lateCount));
    final absent = ref.watch(pdksDashboardProvider.select((s) => s.absentCount));
    final onLeave = ref.watch(pdksDashboardProvider.select((s) => s.onLeaveCount));
    final sick = ref.watch(pdksDashboardProvider.select((s) => s.sickReportCount));
    final activeFilter =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedStateFilter));

    final items = [
      _KpiData(
        title: 'Toplam Kadro',
        count: total,
        color: const Color(0xFF0284C7),
        icon: Icons.people_alt_rounded,
        filter: null,
      ),
      _KpiData(
        title: 'Zamanında',
        count: present,
        color: const Color(0xFF059669),
        icon: Icons.check_circle_rounded,
        filter: DailyAttendanceState.present,
      ),
      _KpiData(
        title: 'Geç Kalan',
        count: lateCount,
        color: const Color(0xFFD97706),
        icon: Icons.access_time_filled_rounded,
        filter: DailyAttendanceState.late,
      ),
      _KpiData(
        title: 'Devamsız',
        count: absent,
        color: const Color(0xFFDC2626),
        icon: Icons.cancel_rounded,
        filter: DailyAttendanceState.absent,
      ),
      _KpiData(
        title: 'İzinli',
        count: onLeave,
        color: const Color(0xFF0EA5E9),
        icon: Icons.beach_access_rounded,
        filter: DailyAttendanceState.onLeave,
      ),
      _KpiData(
        title: 'Raporlu',
        count: sick,
        color: const Color(0xFF7C3AED),
        icon: Icons.medical_services_rounded,
        filter: DailyAttendanceState.sickReport,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 eşit sütun hesaplama
        final cardWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              _MobileKpiTile(
                data: item,
                width: cardWidth,
                isSelected: activeFilter == item.filter,
                onTap: () {
                  ref
                      .read(pdksDashboardProvider.notifier)
                      .setStateFilter(item.filter);
                },
              ),
          ],
        );
      },
    );
  }
}

class _KpiData {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final DailyAttendanceState? filter;

  const _KpiData({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    this.filter,
  });
}

class _MobileKpiTile extends StatelessWidget {
  final _KpiData data;
  final double width;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileKpiTile({
    required this.data,
    required this.width,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? data.color.withValues(alpha: 0.12) : pal.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? data.color : pal.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(data.icon, color: data.color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${data.count}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: data.color,
                    ),
                  ),
                  Text(
                    data.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: pal.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arama ve Şube Filtreleme
class _MobileFilterAndSearchSection extends ConsumerStatefulWidget {
  const _MobileFilterAndSearchSection();

  @override
  ConsumerState<_MobileFilterAndSearchSection> createState() =>
      _MobileFilterAndSearchSectionState();
}

class _MobileFilterAndSearchSectionState
    extends ConsumerState<_MobileFilterAndSearchSection> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(pdksDashboardProvider).searchQuery;
    _searchController = TextEditingController(text: initial);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final text = _searchController.text;
    final normalized = text.trim().isEmpty ? '' : text;
    if (ref.read(pdksDashboardProvider).searchQuery != normalized) {
      ref.read(pdksDashboardProvider.notifier).setSearchQuery(text);
    }
    if (ref.read(mobileUiProvider).quickSearchQuery != normalized) {
      ref.read(mobileUiProvider.notifier).setQuickSearchQuery(normalized);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(
      pdksDashboardProvider.select((s) => s.searchQuery),
      (prev, next) {
        if (_searchController.text != next) {
          _searchController.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
      },
    );

    final pal = HasibuPalette.of(context);
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final activeQuery =
        ref.watch(pdksDashboardProvider.select((s) => s.searchQuery));
    final isBranchScoped =
        ref.watch(pdksDashboardProvider.select((s) => s.isBranchScoped));
    final isSingleBranchScoped = ref.watch(
      pdksDashboardProvider.select((s) => s.isSingleBranchScoped),
    );
    final selectedBranchId = ref.watch(
      pdksDashboardProvider.select((s) => s.effectiveSelectedBranchId),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Şube Filtreleme Çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (isSingleBranchScoped)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.lock_outline_rounded, size: 13),
                    label: Text(
                      branches
                              .where((b) => b.id == selectedBranchId)
                              .map((b) => b.name)
                              .firstOrNull ??
                          'Yetkili Şube #$selectedBranchId',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    selected: true,
                    onSelected: null,
                  )
                else ...[
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    avatar: isBranchScoped
                        ? const Icon(Icons.lock_outline_rounded, size: 13)
                        : null,
                    label: Text(
                      isBranchScoped ? 'Yetkili (${branches.length})' : 'Tümü',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    selected: selectedBranchId == null,
                    onSelected: (_) => ref
                        .read(pdksDashboardProvider.notifier)
                        .setBranchFilter(null),
                  ),
                  const SizedBox(width: 6),
                  for (final b in branches) ...[
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        b.hasTerminal
                            ? Icons.face_retouching_natural
                            : Icons.storefront,
                        size: 13,
                      ),
                      label: Text(b.name, style: const TextStyle(fontSize: 11.5)),
                      selected: selectedBranchId == b.id,
                      onSelected: (_) => ref
                          .read(pdksDashboardProvider.notifier)
                          .setBranchFilter(b.id),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Hızlı Arama
          TextField(
            key: const ValueKey('mobile_pdks_search_field'),
            controller: _searchController,
            onChanged: (val) {
              ref.read(pdksDashboardProvider.notifier).setSearchQuery(val);
              ref.read(mobileUiProvider.notifier).setQuickSearchQuery(val);
            },
            decoration: InputDecoration(
              hintText: 'Personel adı, kart no veya bölüm ara...',
              hintStyle: TextStyle(fontSize: 12.5, color: pal.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: activeQuery.isNotEmpty
                  ? IconButton(
                      key: const ValueKey('mobile_pdks_clear_search_button'),
                      tooltip: 'Aramayı Temizle',
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(pdksDashboardProvider.notifier)
                            .clearSearchQuery();
                        ref.read(mobileUiProvider.notifier).clearSearch();
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              fillColor: pal.card,
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Personel Durum Listesi (Mobil Uyumlu)
class _MobileEmployeeSliverList extends ConsumerWidget {
  const _MobileEmployeeSliverList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(pdksDashboardProvider.select((s) => s.visibleStatuses));
    final densityMode =
        ref.watch(mobileUiProvider.select((s) => s.densityMode));
    final isCompact = densityMode == MobileDensityMode.compact;

    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Aramaya veya filtreye uygun personel bulunamadı.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: isCompact ? 4 : 8),
        itemBuilder: (context, index) {
          final item = items[index];
          if (isCompact) {
            return _MobileCompactEmployeeTile(item: item);
          }
          return _MobileComfortableEmployeeCard(item: item);
        },
      ),
    );
  }
}

/// Ferah Görünüm Kartı (Sadeleştirilmiş Tek Satır — Detaylar Dokununca Açılan Pencerede)
class _MobileComfortableEmployeeCard extends ConsumerWidget {
  final EmployeeDailyStatus item;

  const _MobileComfortableEmployeeCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final Color badgeColor = switch (item.state) {
      DailyAttendanceState.present => const Color(0xFF059669),
      DailyAttendanceState.late => const Color(0xFFD97706),
      DailyAttendanceState.onLeave => const Color(0xFF0284C7),
      DailyAttendanceState.sickReport => const Color(0xFF7C3AED),
      DailyAttendanceState.publicHoliday => const Color(0xFF0EA5E9),
      DailyAttendanceState.weeklyOff => const Color(0xFF6366F1),
      DailyAttendanceState.absent => const Color(0xFFDC2626),
      DailyAttendanceState.terminated => const Color(0xFF64748B),
      DailyAttendanceState.notYetHired => const Color(0xFF94A3B8),
    };

    final String timeBrief = item.firstCheckIn != null
        ? (item.lastCheckOut != null &&
                item.lastCheckOut!.id != item.firstCheckIn!.id
            ? '${item.firstCheckIn!.timeFormatted} - ${item.lastCheckOut!.timeFormatted}'
            : item.firstCheckIn!.timeFormatted)
        : (item.state == DailyAttendanceState.terminated &&
                item.employee.hasExitDate
            ? 'Çıkış: ${PdksDashboardNotifier.formatDisplayDate(item.employee.normalizedExitDate!, includeTodayBadge: false)}'
            : (item.state == DailyAttendanceState.notYetHired
                ? 'İşe Başlamadı'
                : (item.leaveRecord?.note ?? 'Giriş Yok')));

    return Material(
      color: pal.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('employee_card_${item.employee.cardNo}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => showEmployeeHistoryAndDossierDialog(
          context,
          ref,
          item.employee,
          initialTabIndex: 0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EmployeeProfileAvatar(
                employee: item.employee,
                size: 40,
                borderColor: badgeColor.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.employee.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.department.name} • $timeBrief',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.state.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: pal.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kompakt Liste Satırı (Hızlı Tarama)
class _MobileCompactEmployeeTile extends ConsumerWidget {
  final EmployeeDailyStatus item;

  const _MobileCompactEmployeeTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final Color badgeColor = switch (item.state) {
      DailyAttendanceState.present => const Color(0xFF059669),
      DailyAttendanceState.late => const Color(0xFFD97706),
      DailyAttendanceState.onLeave => const Color(0xFF0284C7),
      DailyAttendanceState.sickReport => const Color(0xFF7C3AED),
      DailyAttendanceState.publicHoliday => const Color(0xFF0EA5E9),
      DailyAttendanceState.weeklyOff => const Color(0xFF6366F1),
      DailyAttendanceState.absent => const Color(0xFFDC2626),
      DailyAttendanceState.terminated => const Color(0xFF64748B),
      DailyAttendanceState.notYetHired => const Color(0xFF94A3B8),
    };

    final time = item.firstCheckIn?.timeFormatted ?? '-';

    return Material(
      color: pal.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey('employee_compact_${item.employee.cardNo}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => showEmployeeHistoryAndDossierDialog(
          context,
          ref,
          item.employee,
          initialTabIndex: 0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.employee.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: Text(
                  item.department.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: pal.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobil Alt Gezinme Çubuğu
class _MobileBottomNavigationBar extends ConsumerWidget {
  const _MobileBottomNavigationBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final activeModule =
        ref.watch(pdksDashboardProvider.select((s) => s.activeModule));
    final allowedModules = HasibuModule.filterActive(
      ref.watch(
        pdksDashboardProvider.select((s) => s.authSession.allowedModules),
      ),
    );

    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: pal.card,
        border: Border(top: BorderSide(color: pal.border, width: 1)),
      ),
      child: Row(
        children: [
          for (final m in allowedModules)
            Expanded(
              child: InkWell(
                onTap: () => ref
                    .read(pdksDashboardProvider.notifier)
                    .selectModule(m),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _moduleIcon(m),
                      color: m == activeModule
                          ? const Color(0xFF0284C7)
                          : pal.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _shortModuleTitle(m),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: m == activeModule
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: m == activeModule
                            ? const Color(0xFF0284C7)
                            : pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _moduleIcon(HasibuModule m) {
    switch (m) {
      case HasibuModule.pdksHr:
        return Icons.fingerprint_rounded;
      case HasibuModule.leanProduction:
        return Icons.precision_manufacturing_rounded;
      case HasibuModule.preAccounting:
        return Icons.account_balance_wallet_rounded;
      case HasibuModule.branchStore:
        return Icons.storefront_rounded;
      case HasibuModule.employeePortal:
        return Icons.badge_rounded;
      case HasibuModule.systemSettings:
        return Icons.tune_rounded;
    }
  }

  static String _shortModuleTitle(HasibuModule m) {
    switch (m) {
      case HasibuModule.pdksHr:
        return 'PDKS';
      case HasibuModule.leanProduction:
        return 'Üretim';
      case HasibuModule.preAccounting:
        return 'Muhasebe';
      case HasibuModule.branchStore:
        return 'Şube POS';
      case HasibuModule.employeePortal:
        return 'Portal';
      case HasibuModule.systemSettings:
        return 'Ayarlar';
    }
  }
}
