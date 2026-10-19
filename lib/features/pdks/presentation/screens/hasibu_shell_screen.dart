import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/google_drive_sync_service.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';

class HasibuShellScreen extends ConsumerStatefulWidget {
  const HasibuShellScreen({super.key});

  @override
  ConsumerState<HasibuShellScreen> createState() => _HasibuShellScreenState();
}

class _HasibuShellScreenState extends ConsumerState<HasibuShellScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;

    const pages = <Widget>[
      _LiveAttendanceDashboardView(),
      _TenfeiTerminalsAndSyncView(),
      _BranchQrGpsCheckInView(),
      _EmployeeSelfServicePortalView(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.precision_manufacturing_rounded, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'HASİBU • Yalın Üretim, Çok Şubeli PDKS & İK',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ],
        ),
        actions: const [
          _CloudSyncAppBarBadge(),
          SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: (idx) =>
                  setState(() => _selectedTabIndex = idx),
              extended: MediaQuery.sizeOf(context).width >= 1150,
              backgroundColor: Colors.white,
              selectedIconTheme: const IconThemeData(color: Color(0xFF0284C7)),
              selectedLabelTextStyle: const TextStyle(
                color: Color(0xFF0284C7),
                fontWeight: FontWeight.w700,
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: Text('Canlı PDKS & Şubeler'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.router_outlined),
                  selectedIcon: Icon(Icons.router_rounded),
                  label: Text('Tenfei D35 & Drive Sync'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.qr_code_scanner_outlined),
                  selectedIcon: Icon(Icons.qr_code_scanner_rounded),
                  label: Text('Şube QR / GPS Yoklama'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.badge_outlined),
                  selectedIcon: Icon(Icons.badge_rounded),
                  label: Text('Personel Mobil Portalı'),
                ),
              ],
            ),
          if (isWide) const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: pages[_selectedTabIndex]),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: (idx) =>
                  setState(() => _selectedTabIndex = idx),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Canlı PDKS',
                ),
                NavigationDestination(
                  icon: Icon(Icons.router_outlined),
                  selectedIcon: Icon(Icons.router_rounded),
                  label: 'Tenfei D35',
                ),
                NavigationDestination(
                  icon: Icon(Icons.qr_code_scanner_outlined),
                  selectedIcon: Icon(Icons.qr_code_scanner_rounded),
                  label: 'Şube QR/GPS',
                ),
                NavigationDestination(
                  icon: Icon(Icons.badge_outlined),
                  selectedIcon: Icon(Icons.badge_rounded),
                  label: 'Personel',
                ),
              ],
            ),
    );
  }
}

class _CloudSyncAppBarBadge extends ConsumerWidget {
  const _CloudSyncAppBarBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus =
        ref.watch(pdksDashboardProvider.select((s) => s.syncStatus));
    final isPolling =
        ref.watch(pdksDashboardProvider.select((s) => s.isPollingTerminal));

    final Color dotColor;
    switch (syncStatus.stage) {
      case DriveSyncStage.synced:
        dotColor = const Color(0xFF22C55E);
      case DriveSyncStage.syncing:
        dotColor = const Color(0xFFF59E0B);
      case DriveSyncStage.offlineSaved:
        dotColor = const Color(0xFF38BDF8);
      case DriveSyncStage.error:
        dotColor = const Color(0xFFEF4444);
      case DriveSyncStage.idle:
        dotColor = const Color(0xFF94A3B8);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
          ),
          onPressed: isPolling
              ? null
              : () => ref
                  .read(pdksDashboardProvider.notifier)
                  .pullFromTenfeiTerminals(),
          icon: isPolling
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF38BDF8)),
          label: const Text('Tenfei D35 Çek'),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => ref
              .read(pdksDashboardProvider.notifier)
              .syncWithGoogleDriveNow(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.cloud_sync_rounded, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                const Text(
                  'Drive Sync',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveAttendanceDashboardView extends ConsumerStatefulWidget {
  const _LiveAttendanceDashboardView();

  @override
  ConsumerState<_LiveAttendanceDashboardView> createState() =>
      _LiveAttendanceDashboardViewState();
}

class _LiveAttendanceDashboardViewState
    extends ConsumerState<_LiveAttendanceDashboardView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedDate));
    final terminalMsg =
        ref.watch(pdksDashboardProvider.select((s) => s.terminalStatusMessage));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst Bilgi & Tarih Şeridi
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sensors_rounded,
                            color: Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              terminalMsg,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tarih: $selectedDate',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _BranchSelectorChips(),
                const SizedBox(height: 12),
                const _KpiSummaryCards(),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (val) => ref
                      .read(pdksDashboardProvider.notifier)
                      .setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText:
                        'Personel adı, kart no (örn. 00064) veya üretim bölümü (Fıstık Sarma, Şerbetleme, Şube) ara...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const _EmployeeDailyStatusSliverList(),
      ],
    );
  }
}

class _BranchSelectorChips extends ConsumerWidget {
  const _BranchSelectorChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final selectedBranchId =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedBranchId));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tüm Şubeler & Merkez'),
            selected: selectedBranchId == null,
            onSelected: (_) => ref
                .read(pdksDashboardProvider.notifier)
                .setBranchFilter(null),
          ),
          const SizedBox(width: 8),
          for (final b in branches) ...[
            ChoiceChip(
              avatar: Icon(
                b.hasTerminal ? Icons.face_retouching_natural : Icons.storefront,
                size: 16,
              ),
              label: Text(b.name),
              selected: selectedBranchId == b.id,
              onSelected: (_) => ref
                  .read(pdksDashboardProvider.notifier)
                  .setBranchFilter(b.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _KpiSummaryCards extends ConsumerWidget {
  const _KpiSummaryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(pdksDashboardProvider.select((s) => s.totalCount));
    final present =
        ref.watch(pdksDashboardProvider.select((s) => s.presentCount));
    final lateCount =
        ref.watch(pdksDashboardProvider.select((s) => s.lateCount));
    final absent =
        ref.watch(pdksDashboardProvider.select((s) => s.absentCount));
    final onLeave =
        ref.watch(pdksDashboardProvider.select((s) => s.onLeaveCount));
    final sick =
        ref.watch(pdksDashboardProvider.select((s) => s.sickReportCount));
    final activeFilter =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedStateFilter));

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatFilterCard(
          title: 'Toplam Kadro',
          count: total,
          color: const Color(0xFF0F172A),
          icon: Icons.groups_rounded,
          isSelected: activeFilter == null,
          onTap: () =>
              ref.read(pdksDashboardProvider.notifier).setStateFilter(null),
        ),
        _StatFilterCard(
          title: 'Giriş Yapan',
          count: present,
          color: const Color(0xFF16A34A),
          icon: Icons.check_circle_rounded,
          isSelected: activeFilter == DailyAttendanceState.present,
          onTap: () => ref
              .read(pdksDashboardProvider.notifier)
              .setStateFilter(DailyAttendanceState.present),
        ),
        _StatFilterCard(
          title: 'Geç Gelen',
          count: lateCount,
          color: const Color(0xFFD97706),
          icon: Icons.schedule_rounded,
          isSelected: activeFilter == DailyAttendanceState.late,
          onTap: () => ref
              .read(pdksDashboardProvider.notifier)
              .setStateFilter(DailyAttendanceState.late),
        ),
        _StatFilterCard(
          title: 'Devamsız',
          count: absent,
          color: const Color(0xFFDC2626),
          icon: Icons.person_off_rounded,
          isSelected: activeFilter == DailyAttendanceState.absent,
          onTap: () => ref
              .read(pdksDashboardProvider.notifier)
              .setStateFilter(DailyAttendanceState.absent),
        ),
        _StatFilterCard(
          title: 'İzinli',
          count: onLeave,
          color: const Color(0xFF0284C7),
          icon: Icons.beach_access_rounded,
          isSelected: activeFilter == DailyAttendanceState.onLeave,
          onTap: () => ref
              .read(pdksDashboardProvider.notifier)
              .setStateFilter(DailyAttendanceState.onLeave),
        ),
        _StatFilterCard(
          title: 'Raporlu',
          count: sick,
          color: const Color(0xFF7C3AED),
          icon: Icons.medical_services_rounded,
          isSelected: activeFilter == DailyAttendanceState.sickReport,
          onTap: () => ref
              .read(pdksDashboardProvider.notifier)
              .setStateFilter(DailyAttendanceState.sickReport),
        ),
      ],
    );
  }
}

class _StatFilterCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatFilterCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 155,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
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

class _EmployeeDailyStatusSliverList extends ConsumerWidget {
  const _EmployeeDailyStatusSliverList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(pdksDashboardProvider.select((s) => s.visibleStatuses));

    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('Seçili filtreye uygun personel kaydı bulunamadı.'),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return _EmployeeStatusRowCard(item: item);
        },
      ),
    );
  }
}

class _EmployeeStatusRowCard extends ConsumerWidget {
  final EmployeeDailyStatus item;

  const _EmployeeStatusRowCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (Color badgeColor, IconData badgeIcon) = switch (item.state) {
      DailyAttendanceState.present => (
          const Color(0xFF16A34A),
          Icons.verified_rounded
        ),
      DailyAttendanceState.late => (
          const Color(0xFFD97706),
          Icons.access_time_filled_rounded
        ),
      DailyAttendanceState.onLeave => (
          const Color(0xFF0284C7),
          Icons.event_available_rounded
        ),
      DailyAttendanceState.sickReport => (
          const Color(0xFF7C3AED),
          Icons.local_hospital_rounded
        ),
      DailyAttendanceState.absent => (
          const Color(0xFFDC2626),
          Icons.warning_amber_rounded
        ),
    };

    final checkInText = item.firstCheckIn != null
        ? '${item.firstCheckIn!.timeFormatted} (${item.firstCheckIn!.verifyMethod.label})'
        : (item.leaveRecord?.note ?? 'Giriş Yok');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: badgeColor.withValues(alpha: 0.14),
            foregroundColor: badgeColor,
            child: Icon(badgeIcon, size: 20),
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
                        item.employee.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${item.employee.cardNo}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.branch.name} • ${item.department.name} • ${item.employee.title}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.lateMinutes > 0
                      ? '${item.state.label} (+${item.lateMinutes} dk)'
                      : item.state.label,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                checkInText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          PopupMenuButton<LeaveType>(
            tooltip: 'İzin / Rapor Durumu Ata',
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
            onSelected: (leaveType) {
              ref.read(pdksDashboardProvider.notifier).assignLeaveOrReport(
                    employeeId: item.employee.id,
                    leaveType: leaveType,
                    note: '${leaveType.label} (Mobil/İK Onaylı)',
                  );
            },
            itemBuilder: (_) => [
              for (final lt in LeaveType.values)
                PopupMenuItem<LeaveType>(
                  value: lt,
                  child: Text('${lt.label} Olarak İşaretle'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TenfeiTerminalsAndSyncView extends ConsumerWidget {
  const _TenfeiTerminalsAndSyncView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final autoPoll =
        ref.watch(pdksDashboardProvider.select((s) => s.autoPollEnabled));
    final syncStatus =
        ref.watch(pdksDashboardProvider.select((s) => s.syncStatus));
    final terminalMsg =
        ref.watch(pdksDashboardProvider.select((s) => s.terminalStatusMessage));

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
                Row(
                  children: [
                    const Icon(Icons.memory_rounded, color: Color(0xFF0284C7)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tenfei D35 Doğrudan TCP/UDP (Port 4370) Otomasyon Motoru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
                const SizedBox(height: 8),
                Text(
                  'Eski SMT.exe veya 32-bit zkemkeeper.dll kullanmadan doğrudan 192.168.9.150:4370 protokolüyle yüz ve parmak izi hareketlerini çeker ve Google Drive yedeğini günceller.',
                  style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Son Durum: $terminalMsg\nDrive Yedek Durumu: ${syncStatus.message}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Kayıtlı Terminaller & Şube Bağlantıları',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final b in branches)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: b.hasTerminal
                    ? const Color(0xFFE0F2FE)
                    : const Color(0xFFF1F5F9),
                child: Icon(
                  b.hasTerminal
                      ? Icons.face_retouching_natural_rounded
                      : Icons.qr_code_2_rounded,
                  color: const Color(0xFF0284C7),
                ),
              ),
              title: Text(
                '${b.name} (${b.code})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                b.hasTerminal
                    ? 'Tenfei D35 Aktif • IP: ${b.terminalIp}:${b.terminalPort} (Cihaz No: ${b.machineNo})'
                    : 'Mobil QR / GPS Geofence Modu (${b.geofenceRadiusMeters.round()}m yarıçap) • Terminal IP: ${b.terminalIp}:${b.terminalPort}',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => ref
                    .read(pdksDashboardProvider.notifier)
                    .pullFromTenfeiTerminals(onlyBranchId: b.id),
                child: const Text('Şimdi Çek'),
              ),
            ),
          ),
      ],
    );
  }
}

class _BranchQrGpsCheckInView extends ConsumerStatefulWidget {
  const _BranchQrGpsCheckInView();

  @override
  ConsumerState<_BranchQrGpsCheckInView> createState() =>
      _BranchQrGpsCheckInViewState();
}

class _BranchQrGpsCheckInViewState
    extends ConsumerState<_BranchQrGpsCheckInView> {
  int _selectedBranchId = 38; // Şube Devteyşti
  String? _lastActionFeedback;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final branch = state.branches.firstWhere(
      (b) => b.id == _selectedBranchId,
      orElse: () => state.branches.first,
    );
    final branchStaff = state.dailyStatuses
        .where((s) => s.branch.id == branch.id)
        .toList(growable: false);

    final qrPayload =
        'HASIBU_CHECKIN|BRANCH:${branch.code}|DATE:${state.selectedDate}';

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
                  'Şube Mobil QR & Konum (GPS Geofence) Giriş-Çıkış Sistemi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Yüz tanıma terminali bulunmayan şubelerde (Devteyşti, Yenişehir, Karaköprü) personeller şube QR kodunu okutarak veya GPS konum doğrulaması ile giriş-çıkış yapar.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final b in state.branches)
                      ChoiceChip(
                        label: Text(b.name),
                        selected: _selectedBranchId == b.id,
                        onSelected: (_) =>
                            setState(() => _selectedBranchId = b.id),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: QrImageView(
                        data: qrPayload,
                        size: 120,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'GPS Merkez: ${branch.latitude}, ${branch.longitude}\nGeofence Sınırı: ${branch.geofenceRadiusMeters.round()} metre\nDinamik QR: $qrPayload',
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
                if (_lastActionFeedback != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _lastActionFeedback!,
                      style: const TextStyle(
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${branch.name} Personelleri (${branchStaff.length} Kişi)',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final s in branchStaff)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              title: Text(
                '${s.employee.fullName} (#${s.employee.cardNo})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${s.employee.title} • Durum: ${s.state.label}'),
              trailing: Wrap(
                spacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final msg = await ref
                          .read(pdksDashboardProvider.notifier)
                          .recordBranchMobileCheckIn(
                            employee: s.employee,
                            branch: branch,
                            source: AttendanceSource.mobileQr,
                            isCheckIn: true,
                          );
                      if (mounted) {
                        setState(() => _lastActionFeedback = msg);
                      }
                    },
                    icon: const Icon(Icons.qr_code_rounded, size: 16),
                    label: const Text('QR Giriş'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final msg = await ref
                          .read(pdksDashboardProvider.notifier)
                          .recordBranchMobileCheckIn(
                            employee: s.employee,
                            branch: branch,
                            source: AttendanceSource.mobileGps,
                            isCheckIn: true,
                            currentLat: branch.latitude,
                            currentLng: branch.longitude,
                          );
                      if (mounted) {
                        setState(() => _lastActionFeedback = msg);
                      }
                    },
                    icon: const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text('GPS Giriş'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EmployeeSelfServicePortalView extends ConsumerWidget {
  const _EmployeeSelfServicePortalView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses =
        ref.watch(pdksDashboardProvider.select((s) => s.dailyStatuses));
    final selectedCard = ref.watch(
      pdksDashboardProvider.select((s) => s.activeSelfServiceCardNo),
    );

    if (statuses.isEmpty) {
      return const Center(child: Text('Personel verisi bulunamadı.'));
    }

    final current = statuses.firstWhere(
      (s) => s.employee.cardNo == selectedCard,
      orElse: () => statuses.first,
    );
    final emp = current.employee;

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
                  'Personel Mobil Self-Servis Ekranı (Önizleme)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Personeller telefonlarına Hasibu uygulamasını yükleyip firma bilgileriyle giriş yaptığında kendi yıllık izin, sigortalılık, departman, vardiya ve yalın üretim KPI puanlarını görür.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: current.employee.cardNo,
                  decoration: const InputDecoration(
                    labelText: 'Önizlenecek Personeli Seçin',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in statuses)
                      DropdownMenuItem<String>(
                        value: s.employee.cardNo,
                        child: Text(
                          '${s.employee.fullName} (#${s.employee.cardNo} - ${s.department.name})',
                        ),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref
                          .read(pdksDashboardProvider.notifier)
                          .setSelfServiceEmployee(val);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white24,
                    child: Text(
                      emp.fullName.substring(0, 1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${current.department.name} • ${emp.title} (${current.branch.name})',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF4ADE80)),
                    ),
                    child: Text(
                      emp.sgkActive ? 'SGK AKTİF' : 'SGK PASİF',
                      style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SelfServiceMetricTile(
                    label: 'Kalan Yıllık İzin',
                    value: '${emp.remainingAnnualLeave} Gün',
                    subValue:
                        'Toplam Hak: ${emp.annualLeaveEntitlement} / Kullanılan: ${emp.usedAnnualLeave}',
                  ),
                  _SelfServiceMetricTile(
                    label: 'Yalın Üretim KPI',
                    value: '%${emp.kpiScore.toStringAsFixed(0)}',
                    subValue: 'Bölüm: ${current.department.name}',
                  ),
                  _SelfServiceMetricTile(
                    label: 'İşe Giriş Tarihi',
                    value: emp.hireDate,
                    subValue: 'Kart No: #${emp.cardNo}',
                  ),
                  _SelfServiceMetricTile(
                    label: 'Bugünkü Durum',
                    value: current.state.label,
                    subValue: current.firstCheckIn != null
                        ? 'Giriş: ${current.firstCheckIn!.timeFormatted}'
                        : current.shift.name,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelfServiceMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String subValue;

  const _SelfServiceMetricTile({
    required this.label,
    required this.value,
    required this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
