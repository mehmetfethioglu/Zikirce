import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/google_drive_sync_service.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'hasibu_enterprise_modules_view.dart';
import 'hasibu_settings_view.dart';

class _ModuleNavTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget view;

  const _ModuleNavTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.view,
  });
}

class HasibuShellScreen extends ConsumerStatefulWidget {
  const HasibuShellScreen({super.key});

  @override
  ConsumerState<HasibuShellScreen> createState() => _HasibuShellScreenState();
}

class _HasibuShellScreenState extends ConsumerState<HasibuShellScreen> {
  final Map<HasibuModule, int> _tabIndexByModule = <HasibuModule, int>{
    for (final m in HasibuModule.values) m: 0,
  };

  List<_ModuleNavTab> _buildTabsForModule(HasibuModule module) {
    switch (module) {
      case HasibuModule.pdksHr:
        return const <_ModuleNavTab>[
          _ModuleNavTab(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Canlı PDKS & Şubeler',
            view: _LiveAttendanceDashboardView(),
          ),
          _ModuleNavTab(
            icon: Icons.router_outlined,
            selectedIcon: Icons.router_rounded,
            label: 'Tenfei D35 & Drive Sync',
            view: _TenfeiTerminalsAndSyncView(),
          ),
          _ModuleNavTab(
            icon: Icons.qr_code_scanner_outlined,
            selectedIcon: Icons.qr_code_scanner_rounded,
            label: 'Şube QR / GPS Yoklama',
            view: _BranchQrGpsCheckInView(),
          ),
          _ModuleNavTab(
            icon: Icons.edit_calendar_outlined,
            selectedIcon: Icons.edit_calendar_rounded,
            label: 'Hareket Düzeltme',
            view: AttendanceCorrectionSettingsView(),
          ),
          _ModuleNavTab(
            icon: Icons.medical_information_outlined,
            selectedIcon: Icons.medical_information_rounded,
            label: 'İzin & Rapor Girişi',
            view: LeavesAndReportsSettingsView(),
          ),
        ];

      case HasibuModule.leanProduction:
        return const <_ModuleNavTab>[
          _ModuleNavTab(
            icon: Icons.precision_manufacturing_outlined,
            selectedIcon: Icons.precision_manufacturing_rounded,
            label: '27 İstasyon Canlı Akış',
            view: LeanProductionStationsView(),
          ),
          _ModuleNavTab(
            icon: Icons.leaderboard_outlined,
            selectedIcon: Icons.leaderboard_rounded,
            label: 'Personel KPI Sıralaması',
            view: LeanKpiLeaderboardView(),
          ),
          _ModuleNavTab(
            icon: Icons.manage_accounts_outlined,
            selectedIcon: Icons.manage_accounts_rounded,
            label: 'Bölüm & Kadro Tanımları',
            view: EmployeesManagementSettingsView(),
          ),
        ];

      case HasibuModule.preAccounting:
        return const <_ModuleNavTab>[
          _ModuleNavTab(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: 'Günlük Puantaj & Bordro',
            view: PreAccountingPayrollSummaryView(),
          ),
          _ModuleNavTab(
            icon: Icons.schedule_outlined,
            selectedIcon: Icons.schedule_rounded,
            label: 'Mesai & Kesinti Kuralları',
            view: ShiftAndLateToleranceSettingsView(),
          ),
        ];

      case HasibuModule.employeePortal:
        return const <_ModuleNavTab>[
          _ModuleNavTab(
            icon: Icons.badge_outlined,
            selectedIcon: Icons.badge_rounded,
            label: 'Özlük, SGK & KPI Kartım',
            view: _EmployeeSelfServicePortalView(),
          ),
          _ModuleNavTab(
            icon: Icons.qr_code_scanner_outlined,
            selectedIcon: Icons.qr_code_scanner_rounded,
            label: 'Şube Mobil QR / GPS',
            view: _BranchQrGpsCheckInView(),
          ),
        ];

      case HasibuModule.systemSettings:
        return const <_ModuleNavTab>[
          _ModuleNavTab(
            icon: Icons.business_outlined,
            selectedIcon: Icons.business_rounded,
            label: '1. Şirket, Şube & Cihaz Ayarları',
            view: CompanyAndBranchesSettingsView(),
          ),
          _ModuleNavTab(
            icon: Icons.schedule_outlined,
            selectedIcon: Icons.schedule_rounded,
            label: '2. Mesai Saatleri & Geç Kalma',
            view: ShiftAndLateToleranceSettingsView(),
          ),
          _ModuleNavTab(
            icon: Icons.manage_accounts_outlined,
            selectedIcon: Icons.manage_accounts_rounded,
            label: '3. Personel & Bölüm Yönetimi',
            view: EmployeesManagementSettingsView(),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final authSession =
        ref.watch(pdksDashboardProvider.select((s) => s.authSession));
    if (!authSession.isAuthenticated) {
      return const HasibuLoginScreen();
    }

    final isWide = MediaQuery.sizeOf(context).width >= 860;
    final companyName = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.companyName),
    );
    final rawActiveModule =
        ref.watch(pdksDashboardProvider.select((s) => s.activeModule));
    final allowedModules = authSession.allowedModules.isNotEmpty
        ? authSession.allowedModules
        : const <HasibuModule>[HasibuModule.employeePortal];
    final HasibuModule activeModule = allowedModules.contains(rawActiveModule)
        ? rawActiveModule
        : allowedModules.first;

    final tabs = _buildTabsForModule(activeModule);
    final int rawIndex = _tabIndexByModule[activeModule] ?? 0;
    final int safeIndex = rawIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                companyName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                authSession.displayName,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (authSession.canAccess(HasibuModule.pdksHr) ||
              authSession.canAccess(HasibuModule.systemSettings))
            const _CloudSyncAppBarBadge(),
          const SizedBox(width: 6),
          if (authSession.canAccess(HasibuModule.systemSettings))
            IconButton(
              tooltip: 'Ayarlar & Yönetim',
              onPressed: () => ref
                  .read(pdksDashboardProvider.notifier)
                  .selectModule(HasibuModule.systemSettings),
              icon: Icon(
                Icons.settings_outlined,
                color: activeModule == HasibuModule.systemSettings
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF475569),
              ),
            ),
          IconButton(
            tooltip: 'Oturumu Kapat (${authSession.displayName})',
            onPressed: () =>
                ref.read(pdksDashboardProvider.notifier).logout(),
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFDC2626),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ÜST MODÜL SEÇME SATIRI (Kullanıcının yetkili olduğu modülleri listeler)
          _TopModuleSelectorRibbon(
            allowedModules: allowedModules,
            activeModule: activeModule,
            onSelectModule: (m) =>
                ref.read(pdksDashboardProvider.notifier).selectModule(m),
          ),
          Expanded(
            child: Row(
              children: [
                if (isWide)
                  NavigationRail(
                    selectedIndex: safeIndex,
                    onDestinationSelected: (idx) => setState(
                      () => _tabIndexByModule[activeModule] = idx,
                    ),
                    extended: MediaQuery.sizeOf(context).width >= 1150,
                    backgroundColor: Colors.white,
                    indicatorColor: const Color(0xFFF0F9FF),
                    selectedIconTheme:
                        const IconThemeData(color: Color(0xFF0284C7)),
                    unselectedIconTheme:
                        const IconThemeData(color: Color(0xFF64748B)),
                    selectedLabelTextStyle: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    destinations: [
                      for (final t in tabs)
                        NavigationRailDestination(
                          icon: Icon(t.icon, size: 20),
                          selectedIcon: Icon(t.selectedIcon, size: 20),
                          label: Text(t.label),
                        ),
                    ],
                  ),
                if (isWide)
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Color(0xFFE2E8F0),
                  ),
                Expanded(child: tabs[safeIndex].view),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide || tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (idx) =>
                  setState(() => _tabIndexByModule[activeModule] = idx),
              destinations: [
                for (final t in tabs)
                  NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: t.label,
                  ),
              ],
            ),
    );
  }
}

class _TopModuleSelectorRibbon extends StatelessWidget {
  final List<HasibuModule> allowedModules;
  final HasibuModule activeModule;
  final ValueChanged<HasibuModule> onSelectModule;

  const _TopModuleSelectorRibbon({
    required this.allowedModules,
    required this.activeModule,
    required this.onSelectModule,
  });

  IconData _iconForModule(HasibuModule m) {
    switch (m) {
      case HasibuModule.pdksHr:
        return Icons.fingerprint_rounded;
      case HasibuModule.leanProduction:
        return Icons.precision_manufacturing_rounded;
      case HasibuModule.preAccounting:
        return Icons.account_balance_wallet_rounded;
      case HasibuModule.employeePortal:
        return Icons.badge_rounded;
      case HasibuModule.systemSettings:
        return Icons.tune_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWidth = MediaQuery.sizeOf(context).width >= 960;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: isDesktopWidth
          ? Row(
              children: [
                for (var i = 0; i < allowedModules.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _TopModuleButton(
                      module: allowedModules[i],
                      icon: _iconForModule(allowedModules[i]),
                      isSelected: allowedModules[i] == activeModule,
                      onTap: () => onSelectModule(allowedModules[i]),
                    ),
                  ),
                ],
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final m in allowedModules) ...[
                    _TopModuleButton(
                      module: m,
                      icon: _iconForModule(m),
                      isSelected: m == activeModule,
                      onTap: () => onSelectModule(m),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
    );
  }
}

class _TopModuleButton extends StatelessWidget {
  final HasibuModule module;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopModuleButton({
    required this.module,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
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
    final gmail = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.syncGmailAccount),
    );
    final isPolling =
        ref.watch(pdksDashboardProvider.select((s) => s.isPollingTerminal));

    final Color dotColor;
    switch (syncStatus.stage) {
      case DriveSyncStage.synced:
        dotColor = const Color(0xFF10B981);
      case DriveSyncStage.syncing:
        dotColor = const Color(0xFFF59E0B);
      case DriveSyncStage.offlineSaved:
        dotColor = const Color(0xFF0284C7);
      case DriveSyncStage.error:
        dotColor = const Color(0xFFEF4444);
      case DriveSyncStage.idle:
        dotColor = const Color(0xFF94A3B8);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          onPressed: isPolling
              ? null
              : () => ref
                  .read(pdksDashboardProvider.notifier)
                  .pullFromTenfeiTerminals(),
          icon: isPolling
              ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: Color(0xFF0284C7),
                ),
          label: const Text(
            'Terminal Çek',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          key: const ValueKey('gmail_sync_setup_button'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => showGmailDriveSyncDialog(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.cloud_sync_outlined,
                  size: 15,
                  color: Color(0xFF475569),
                ),
                const SizedBox(width: 5),
                Text(
                  gmail.isNotEmpty ? gmail : 'Gmail Eşitleme',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              terminalMsg,
                              style: const TextStyle(
                                fontSize: 12.5,
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
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tarih: $selectedDate',
                            style: const TextStyle(
                              fontSize: 12.5,
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
                  decoration: const InputDecoration(
                    hintText:
                        'Personel adı, kart no (örn. 00064) veya üretim bölümü ara...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    fillColor: Colors.white,
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
                b.hasTerminal
                    ? Icons.face_retouching_natural
                    : Icons.storefront,
                size: 15,
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
          color: const Color(0xFF059669),
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 152,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
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
    final Color badgeColor = switch (item.state) {
      DailyAttendanceState.present => const Color(0xFF059669),
      DailyAttendanceState.late => const Color(0xFFD97706),
      DailyAttendanceState.onLeave => const Color(0xFF0284C7),
      DailyAttendanceState.sickReport => const Color(0xFF7C3AED),
      DailyAttendanceState.absent => const Color(0xFFDC2626),
    };

    final String checkInText;
    if (item.firstCheckIn != null) {
      final outPart = item.lastCheckOut != null &&
              item.lastCheckOut!.id != item.firstCheckIn!.id
          ? ' • Çıkış: ${item.lastCheckOut!.timeFormatted}'
          : '';
      checkInText =
          'Giriş: ${item.firstCheckIn!.timeFormatted}$outPart (${item.firstCheckIn!.verifyMethod.label})';
    } else {
      checkInText = item.leaveRecord?.note ?? 'Giriş Yok';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          EmployeeProfileAvatar(
            employee: item.employee,
            size: 42,
            borderColor: badgeColor.withValues(alpha: 0.45),
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
                          fontSize: 13.5,
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
                const SizedBox(height: 3),
                Text(
                  '${item.branch.name} • ${item.department.name} • Mesai: ${item.shift.startTime}-${item.shift.endTime}',
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.lateMinutes > 0
                      ? '${item.state.label} (+${item.lateMinutes} dk)'
                      : item.state.label,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                checkInText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          PopupMenuButton<LeaveType>(
            tooltip: 'İzin / Rapor Durumu Ata',
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF64748B),
            ),
            onSelected: (leaveType) {
              ref.read(pdksDashboardProvider.notifier).assignLeaveOrReport(
                    employeeId: item.employee.id,
                    leaveType: leaveType,
                    note: '${leaveType.label} (Hızlı Atama)',
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
    final gmail = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.syncGmailAccount),
    );
    final terminalMsg =
        ref.watch(pdksDashboardProvider.select((s) => s.terminalStatusMessage));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sensors_rounded, color: Color(0xFF0284C7)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Yüz Tanıma & Parmak İzi Terminali (TCP 4370) ve Gmail Bulut Eşitleme',
                      style: TextStyle(
                        fontSize: 15,
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
              const SizedBox(height: 6),
              const Text(
                'Ağdaki yüz ve parmak izi terminallerine doğrudan TCP 4370 protokolüyle bağlanarak giriş-çıkış hareketlerini çeker ve tanımladığınız Gmail / Google Drive hesabıyla eşitler.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12.5,
                ),
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gmail / Drive (${gmail.isEmpty ? "Henüz tanımlanmadı" : gmail}): ${syncStatus.message}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
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
                          onPressed: () => ref
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
        const Text(
          'Kayıtlı Terminaller & Şube Bağlantıları',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (final b in branches)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: b.hasTerminal
                    ? const Color(0xFFF0F9FF)
                    : const Color(0xFFF1F5F9),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              subtitle: Text(
                b.hasTerminal
                    ? 'Aktif Terminal • IP: ${b.terminalIp}:${b.terminalPort} (Cihaz No: ${b.machineNo})'
                    : 'Mobil QR / GPS Geofence Modu (${b.geofenceRadiusMeters.round()}m) • IP: ${b.terminalIp}:${b.terminalPort}',
                style: const TextStyle(fontSize: 12),
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
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Şube Mobil QR & Konum (GPS Geofence) Giriş-Çıkış Sistemi',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Yüz tanıma terminali bulunmayan şubelerde personeller şube QR kodunu okutarak veya GPS konum doğrulaması ile giriş-çıkış yapar.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
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
                      size: 112,
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
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _lastActionFeedback!,
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${branch.name} Personelleri (${branchStaff.length} Kişi)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final s in branchStaff)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: EmployeeProfileAvatar(employee: s.employee, size: 38),
              title: Text(
                '${s.employee.fullName} (#${s.employee.cardNo})',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
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
                    icon: const Icon(Icons.qr_code_rounded, size: 15),
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
                    icon: const Icon(Icons.my_location_rounded, size: 15),
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
    final authRole =
        ref.watch(pdksDashboardProvider.select((s) => s.authSession.role));

    if (statuses.isEmpty) {
      return const Center(child: Text('Personel verisi bulunamadı.'));
    }

    final current = statuses.firstWhere(
      (s) => s.employee.cardNo == selectedCard,
      orElse: () => statuses.first,
    );
    final emp = current.employee;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (authRole == UserRole.admin)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personel Mobil Self-Servis Ekranı (Yönetici Önizleme)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Personeller kendi Kart No ve kişisel parolalarıyla oturum açtığında yetki verilen modülleri ve özlük kartlarını görürler.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: current.employee.cardNo,
                  decoration: const InputDecoration(
                    labelText: 'Önizlenecek Personeli Seçin',
                  ),
                  items: [
                    for (final s in statuses)
                      DropdownMenuItem<String>(
                        value: s.employee.cardNo,
                        child: Text(
                          '${s.employee.fullName} (#${s.employee.cardNo} - ${s.department.name})',
                          overflow: TextOverflow.ellipsis,
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
        if (authRole == UserRole.admin) const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EmployeeProfileAvatar(
                    employee: emp,
                    size: 56,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.fullName,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${current.department.name} • ${emp.title} (${current.branch.name})',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final mod in emp.allowedModules)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFBAE6FD),
                                  ),
                                ),
                                child: Text(
                                  'Yetki: ${mod.title}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0369A1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      emp.sgkActive ? 'SGK AKTİF' : 'SGK PASİF',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
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
                        : '${current.shift.startTime}-${current.shift.endTime}',
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
