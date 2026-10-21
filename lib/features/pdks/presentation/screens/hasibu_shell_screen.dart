import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/google_drive_sync_service.dart';
import '../../../../router.dart';
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
          _ModuleNavTab(
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_rounded,
            label: 'İK Talep & Uyum Radarı',
            view: HrRequestsAndComplianceView(),
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

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 860;
    final companySettings = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings),
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
    final pal = HasibuPalette.of(context);

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: pal.card,
        foregroundColor: pal.textPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: pal.border),
        ),
        title: Row(
          children: [
            CompanyLogoBadge(
              key: const ValueKey('appbar_company_logo_badge'),
              settings: companySettings,
              size: 34,
              borderRadius: 9,
              onTap: authSession.canAccess(HasibuModule.systemSettings)
                  ? () => showCompanyLogoDialog(context, ref)
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                companySettings.companyName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: isWide ? 15 : 13.5,
                  letterSpacing: -0.2,
                  color: pal.textPrimary,
                ),
              ),
            ),
            if (screenWidth >= 1020) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: pal.chip,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    authSession.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: pal.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (authSession.canAccess(HasibuModule.pdksHr) ||
              authSession.canAccess(HasibuModule.systemSettings))
            _CloudSyncAppBarBadge(compact: !isWide),
          const SizedBox(width: 6),
          const UserThemeSelectorBar(compact: true),
          IconButton(
            key: const ValueKey('appbar_mobile_mode_button'),
            tooltip: 'Özel Mobil Görünüm',
            icon: const Icon(Icons.smartphone_rounded, size: 20),
            onPressed: () => HasibuRouter.navigateToMobile(context),
          ),
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
                    : pal.textSecondary,
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
          const SizedBox(width: 6),
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
                    extended: screenWidth >= 1150,
                    backgroundColor: pal.card,
                    indicatorColor:
                        const Color(0xFF0284C7).withValues(alpha: 0.14),
                    selectedIconTheme:
                        const IconThemeData(color: Color(0xFF0284C7)),
                    unselectedIconTheme:
                        IconThemeData(color: pal.textSecondary),
                    selectedLabelTextStyle: TextStyle(
                      color: pal.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    unselectedLabelTextStyle: TextStyle(
                      color: pal.textSecondary,
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
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: pal.border,
                  ),
                Expanded(child: tabs[safeIndex].view),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide || tabs.length < 2
          ? null
          : Container(
              decoration: BoxDecoration(
                color: pal.card,
                border: Border(
                  top: BorderSide(color: pal.border, width: 1),
                ),
              ),
              child: NavigationBar(
                height: 64,
                backgroundColor: pal.card,
                indicatorColor:
                    const Color(0xFF0284C7).withValues(alpha: 0.15),
                selectedIndex: safeIndex.clamp(0, (tabs.length > 5 ? 5 : tabs.length) - 1),
                onDestinationSelected: (idx) =>
                    setState(() => _tabIndexByModule[activeModule] = idx),
                destinations: [
                  for (final t in tabs.take(5))
                    NavigationDestination(
                      icon: Icon(t.icon, color: pal.textSecondary, size: 20),
                      selectedIcon: Icon(
                        t.selectedIcon,
                        color: const Color(0xFF0284C7),
                        size: 20,
                      ),
                      label: t.label,
                    ),
                ],
              ),
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
    final pal = HasibuPalette.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: pal.card,
        border: Border(
          bottom: BorderSide(color: pal.border, width: 1),
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
    final pal = HasibuPalette.of(context);
    final Color activeBg =
        pal.isDark ? const Color(0xFF0284C7) : const Color(0xFF0F172A);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : pal.subtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeBg : pal.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : pal.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : pal.textPrimary,
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
  final bool compact;

  const _CloudSyncAppBarBadge({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus =
        ref.watch(pdksDashboardProvider.select((s) => s.syncStatus));
    final gmail = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.syncGmailAccount),
    );
    final isPolling =
        ref.watch(pdksDashboardProvider.select((s) => s.isPollingTerminal));
    final lastReachable =
        ref.watch(pdksDashboardProvider.select((s) => s.lastTerminalReachable));
    final pal = HasibuPalette.of(context);

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

    final Color termDotColor = switch (lastReachable) {
      true => const Color(0xFF10B981),
      false => const Color(0xFFEF4444),
      null => const Color(0xFF0284C7),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('appbar_terminal_diag_button'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: pal.border),
          ),
          onPressed: () => showTerminalDiagnosticsDialog(context, ref),
          icon: Icon(
            Icons.radar_rounded,
            size: 15,
            color: termDotColor,
          ),
          label: Text(
            compact ? 'Cihaz Test' : 'Bağlantı Kontrolü',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        if (!compact) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: pal.border),
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
        ],
        InkWell(
          key: const ValueKey('gmail_sync_setup_button'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => showGmailDriveSyncDialog(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: pal.subtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: pal.border),
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
                Icon(
                  Icons.cloud_sync_outlined,
                  size: 15,
                  color: pal.textSecondary,
                ),
                if (!compact) ...[
                  const SizedBox(width: 5),
                  Text(
                    gmail.isNotEmpty ? gmail : 'Gmail Eşitleme',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pal.textPrimary,
                    ),
                  ),
                ],
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
    final pendingReqCount = ref.watch(
      pdksDashboardProvider.select((s) => s.pendingHrRequestsCount),
    );
    final pal = HasibuPalette.of(context);

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
                    color: pal.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pal.border),
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
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: pal.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('open_hr_requests_modal_button'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: pendingReqCount > 0
                                  ? const Color(0xFFD97706)
                                  : null,
                            ),
                            onPressed: () =>
                                showHrRequestsAndComplianceDialog(context, ref),
                            icon: const Icon(
                              Icons.fact_check_outlined,
                              size: 15,
                            ),
                            label: Text(
                              pendingReqCount > 0
                                  ? 'İK Talepleri ($pendingReqCount Bekleyen)'
                                  : 'İK Talep & Uyum',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('export_puantaj_csv_button'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () =>
                                showPuantajCsvExportDialog(context, ref),
                            icon: const Icon(
                              Icons.table_view_rounded,
                              size: 15,
                            ),
                            label: const Text(
                              'Puantaj CSV / Excel',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () =>
                                showTerminalDiagnosticsDialog(context, ref),
                            icon: const Icon(
                              Icons.network_check_rounded,
                              size: 15,
                            ),
                            label: const Text(
                              'Cihaz Bağlantı Kontrolü',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('prev_day_button'),
                            tooltip: 'Önceki Gün',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => ref
                                .read(pdksDashboardProvider.notifier)
                                .shiftSelectedDateByDays(-1),
                            icon: const Icon(Icons.chevron_left_rounded, size: 18),
                          ),
                          for (final d in const [
                            '2026-10-20',
                            '2026-10-19',
                            '2026-10-17',
                          ])
                            ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                d == '2026-10-20' ? '$d (Bugün)' : d,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              selected: selectedDate == d,
                              onSelected: (_) => ref
                                  .read(pdksDashboardProvider.notifier)
                                  .setSelectedDate(d),
                            ),
                          IconButton(
                            key: const ValueKey('next_day_button'),
                            tooltip: 'Sonraki Gün',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => ref
                                .read(pdksDashboardProvider.notifier)
                                .shiftSelectedDateByDays(1),
                            icon: const Icon(Icons.chevron_right_rounded, size: 18),
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
                const SizedBox(height: 10),
                const _PdksAnomalyFilterRibbon(),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (val) => ref
                      .read(pdksDashboardProvider.notifier)
                      .setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText:
                        'Personel adı, kart no (örn. 00064) veya bölüm ara... (Personel geçmişi & özlük dosyası için karta dokunun)',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    fillColor: pal.card,
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
    final pal = HasibuPalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cardWidth = isNarrow ? (constraints.maxWidth - 10) / 2 : 152.0;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
        _StatFilterCard(
          title: 'Toplam Kadro',
          count: total,
          color: pal.isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
          icon: Icons.groups_rounded,
          isSelected: activeFilter == null,
          width: cardWidth,
          onTap: () =>
              ref.read(pdksDashboardProvider.notifier).setStateFilter(null),
        ),
        _StatFilterCard(
          title: 'Giriş Yapan',
          count: present,
          color: const Color(0xFF059669),
          icon: Icons.check_circle_rounded,
          isSelected: activeFilter == DailyAttendanceState.present,
          width: cardWidth,
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
          width: cardWidth,
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
          width: cardWidth,
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
          width: cardWidth,
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
          width: cardWidth,
          onTap: () => ref
              .read(pdksDashboardProvider.notifier)
              .setStateFilter(DailyAttendanceState.sickReport),
        ),
      ],
    );
      },
    );
  }
}

class _StatFilterCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final double width;
  final VoidCallback onTap;

  const _StatFilterCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    required this.isSelected,
    this.width = 152.0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : pal.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : pal.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
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
                    style: TextStyle(
                      fontSize: 11.5,
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

class _PdksAnomalyFilterRibbon extends ConsumerWidget {
  const _PdksAnomalyFilterRibbon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAnomaly = ref.watch(
      pdksDashboardProvider.select((s) => s.selectedAnomalyFilter),
    );
    final missingOutCount = ref.watch(
      pdksDashboardProvider.select((s) => s.missingCheckOutCount),
    );
    final overtimeCount = ref.watch(
      pdksDashboardProvider.select((s) => s.overtimeStaffCount),
    );
    final totalOvertimeMins = ref.watch(
      pdksDashboardProvider.select((s) => s.totalOvertimeMinutes),
    );
    final earlyLeaveCount = ref.watch(
      pdksDashboardProvider.select((s) => s.earlyLeaveCount),
    );
    final missingDocsCount = ref.watch(
      pdksDashboardProvider.select((s) => s.missingDocsStaffCount),
    );
    final pal = HasibuPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.radar_rounded,
                size: 16,
                color: pal.textSecondary,
              ),
              Text(
                'Anomali & Mesai Radarı:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: pal.textSecondary,
                ),
              ),
              ChoiceChip(
                key: const ValueKey('anomaly_filter_all'),
                visualDensity: VisualDensity.compact,
                label: const Text(
                  'Tüm Kadro',
                  style: TextStyle(fontSize: 11.5),
                ),
                selected: activeAnomaly == PdksAnomalyFilter.all,
                onSelected: (_) => ref
                    .read(pdksDashboardProvider.notifier)
                    .setAnomalyFilter(PdksAnomalyFilter.all),
              ),
              ChoiceChip(
                key: const ValueKey('anomaly_filter_missing_out'),
                visualDensity: VisualDensity.compact,
                avatar: const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Color(0xFFD97706),
                ),
                label: Text(
                  'Eksik Çıkış ($missingOutCount)',
                  style: const TextStyle(fontSize: 11.5),
                ),
                selected: activeAnomaly == PdksAnomalyFilter.missingCheckOut,
                onSelected: (_) => ref
                    .read(pdksDashboardProvider.notifier)
                    .setAnomalyFilter(PdksAnomalyFilter.missingCheckOut),
              ),
              ChoiceChip(
                key: const ValueKey('anomaly_filter_overtime'),
                visualDensity: VisualDensity.compact,
                avatar: const Icon(
                  Icons.more_time_rounded,
                  size: 14,
                  color: Color(0xFF059669),
                ),
                label: Text(
                  'Fazla Mesai ($overtimeCount Kişi • +$totalOvertimeMins dk)',
                  style: const TextStyle(fontSize: 11.5),
                ),
                selected: activeAnomaly == PdksAnomalyFilter.overtime,
                onSelected: (_) => ref
                    .read(pdksDashboardProvider.notifier)
                    .setAnomalyFilter(PdksAnomalyFilter.overtime),
              ),
              ChoiceChip(
                key: const ValueKey('anomaly_filter_early_leave'),
                visualDensity: VisualDensity.compact,
                avatar: const Icon(
                  Icons.directions_run_rounded,
                  size: 14,
                  color: Color(0xFFDC2626),
                ),
                label: Text(
                  'Erken Çıkış ($earlyLeaveCount)',
                  style: const TextStyle(fontSize: 11.5),
                ),
                selected: activeAnomaly == PdksAnomalyFilter.earlyLeave,
                onSelected: (_) => ref
                    .read(pdksDashboardProvider.notifier)
                    .setAnomalyFilter(PdksAnomalyFilter.earlyLeave),
              ),
              ChoiceChip(
                key: const ValueKey('anomaly_filter_missing_docs'),
                visualDensity: VisualDensity.compact,
                avatar: const Icon(
                  Icons.folder_off_outlined,
                  size: 14,
                  color: Color(0xFF7C3AED),
                ),
                label: Text(
                  'Eksik Evrak ($missingDocsCount)',
                  style: const TextStyle(fontSize: 11.5),
                ),
                selected: activeAnomaly == PdksAnomalyFilter.missingDocs,
                onSelected: (_) => ref
                    .read(pdksDashboardProvider.notifier)
                    .setAnomalyFilter(PdksAnomalyFilter.missingDocs),
              ),
            ],
          ),
          if (missingOutCount > 0)
            FilledButton.tonalIcon(
              key: const ValueKey('batch_complete_missing_out_button'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () async {
                final count = await ref
                    .read(pdksDashboardProvider.notifier)
                    .batchCompleteAllMissingCheckOuts();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$count personelin eksik çıkış hareketi vardiya bitiş saatine göre tamamlandı.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
              label: Text(
                'Eksik Çıkışları Vardiya Sonuna Tamamla ($missingOutCount)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
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
    final pal = HasibuPalette.of(context);
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

    final docCount = ref.watch(
      pdksDashboardProvider.select(
        (s) => s.documentsForEmployee(item.employee.id).length,
      ),
    );

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: pal.textPrimary,
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
                            color: pal.chip,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${item.employee.cardNo}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: pal.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.branch.name} • ${item.department.name} • Mesai: ${item.shift.startTime}-${item.shift.endTime}',
                      style: TextStyle(
                        fontSize: 12,
                        color: pal.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        InkWell(
                          key: ValueKey(
                            'employee_history_btn_${item.employee.cardNo}',
                          ),
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => showEmployeeHistoryAndDossierDialog(
                            context,
                            ref,
                            item.employee,
                            initialTabIndex: 0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 12,
                                  color: Color(0xFF0284C7),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Personel Geçmişi',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          key: ValueKey(
                            'employee_dossier_btn_${item.employee.cardNo}',
                          ),
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => showEmployeeHistoryAndDossierDialog(
                            context,
                            ref,
                            item.employee,
                            initialTabIndex: 1,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.folder_shared_rounded,
                                  size: 12,
                                  color: Color(0xFF059669),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Özlük Dosyası ($docCount Evrak)',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (item.workedMinutes > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: pal.chip,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Net Çalışma: ${item.workedDurationFormatted}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: pal.textPrimary,
                              ),
                            ),
                          ),
                        if (item.overtimeMinutes > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${item.overtimeMinutes} dk Fazla Mesai',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        if (item.earlyLeaveMinutes > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-${item.earlyLeaveMinutes} dk Erken Çıkış',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        if (item.duplicateScansFiltered > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Anti-Passback: ${item.duplicateScansFiltered} Mükerrer Elendi',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        if (item.hasMissingCheckOut)
                          InkWell(
                            key: ValueKey(
                              'quick_complete_out_${item.employee.cardNo}',
                            ),
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => ref
                                .read(pdksDashboardProvider.notifier)
                                .quickCompleteMissingCheckOut(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFD97706)
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: 12,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Eksik Çıkış (${item.shift.endTime} Tamamla)',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: pal.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              PopupMenuButton<LeaveType>(
                tooltip: 'İzin / Rapor Durumu Ata',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: pal.textSecondary,
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
        ),
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
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
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
                    : 'Mobil QR / GPS Geofence Modu (${b.geofenceRadiusMeters.round()}m) • IP: ${b.terminalIp}:${b.terminalPort}',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
              trailing: Wrap(
                spacing: 8,
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
                  FilledButton.tonal(
                    onPressed: () => ref
                        .read(pdksDashboardProvider.notifier)
                        .pullFromTenfeiTerminals(onlyBranchId: b.id),
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
    final pal = HasibuPalette.of(context);
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
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Şube Mobil QR & Konum (GPS Geofence) Giriş-Çıkış Sistemi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Yüz tanıma terminali bulunmayan şubelerde personeller şube QR kodunu okutarak veya GPS konum doğrulaması ile giriş-çıkış yapar.',
                style: TextStyle(fontSize: 12.5, color: pal.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: pal.border),
                    ),
                    child: QrImageView(
                      data: qrPayload,
                      size: 112,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'GPS Merkez: ${branch.latitude}, ${branch.longitude}\nGeofence Sınırı: ${branch.geofenceRadiusMeters.round()} metre\nDinamik QR: $qrPayload',
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
              if (_lastActionFeedback != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _lastActionFeedback!,
                    style: const TextStyle(
                      color: Color(0xFF059669),
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final s in branchStaff)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: ListTile(
              leading: EmployeeProfileAvatar(employee: s.employee, size: 38),
              title: Text(
                '${s.employee.fullName} (#${s.employee.cardNo})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: pal.textPrimary,
                ),
              ),
              subtitle: Text(
                '${s.employee.title} • Durum: ${s.state.label}',
                style: TextStyle(color: pal.textSecondary, fontSize: 12),
              ),
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
    final companySettings = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings),
    );
    final pal = HasibuPalette.of(context);

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
              color: pal.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pal.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personel Mobil Self-Servis Ekranı (Yönetici Önizleme)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personeller kendi Kart No ve kişisel parolalarıyla oturum açtığında yetki verilen modülleri, kişisel temalarını ve özlük kartlarını görürler.',
                  style: TextStyle(fontSize: 12.5, color: pal.textSecondary),
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
        // MOBİL & MASAÜSTÜ MİNİMALİST PERSONEL PORTALI KARTI
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ŞİRKET LOGOSU VE KURUMSAL BAŞLIK BANDI
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Row(
                  children: [
                    CompanyLogoBadge(
                      settings: companySettings,
                      size: 36,
                      borderRadius: 9,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companySettings.companyName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: pal.textPrimary,
                            ),
                          ),
                          Text(
                            'Kurumsal Mobil & Masaüstü Personel Portalı',
                            style: TextStyle(
                              fontSize: 11,
                              color: pal.textSecondary,
                            ),
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
                        color: const Color(0xFF059669).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
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
              ),
              const SizedBox(height: 16),
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
                          style: TextStyle(
                            color: pal.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${current.department.name} • ${emp.title} (${current.branch.name})',
                          style: TextStyle(
                            color: pal.textSecondary,
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
                                  color: const Color(0xFF0284C7)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Yetki: ${mod.title}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
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
                    label: 'İşe Giriş & Kıdem (4857)',
                    value: '${emp.tenureYearsAt()} Yıl Kıdem',
                    subValue:
                        'Giriş: ${emp.hireDate} • Yasal Hak: ${emp.statutoryAnnualLeaveEntitlement} Gün',
                  ),
                  _SelfServiceMetricTile(
                    label: 'Bugünkü Durum',
                    value: current.state.label,
                    subValue: current.firstCheckIn != null
                        ? 'Giriş: ${current.firstCheckIn!.timeFormatted}${current.lastCheckOut != null ? " • Çıkış: ${current.lastCheckOut!.timeFormatted}" : ""}'
                        : '${current.shift.startTime}-${current.shift.endTime}',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('self_service_new_request_button'),
                    onPressed: () => showCreateHrRequestDialog(
                      context,
                      ref,
                      employee: emp,
                    ),
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: const Text(
                      'Yeni İK Talebi Oluştur (İzin / Mesai / Hareket)',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => showEmployeeHistoryAndDossierDialog(
                      context,
                      ref,
                      emp,
                      initialTabIndex: 0,
                    ),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Giriş-Çıkış Geçmişini Aç'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showEmployeeHistoryAndDossierDialog(
                      context,
                      ref,
                      emp,
                      initialTabIndex: 1,
                    ),
                    icon: const Icon(Icons.folder_shared_rounded, size: 18),
                    label: const Text('Özlük Dosyası & Resmi Evraklar'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _EmployeeSelfServiceRequestsSection(employeeId: emp.id),
              const SizedBox(height: 18),
              // HER KULLANICIYA ÖZGÜ KİŞİSEL TEMA SEÇİCİ (Açık / Koyu / Sistem)
              const UserThemeSelectorBar(),
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
    final pal = HasibuPalette.of(context);
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: pal.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: pal.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: TextStyle(color: pal.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmployeeSelfServiceRequestsSection extends ConsumerWidget {
  final int employeeId;

  const _EmployeeSelfServiceRequestsSection({required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(
      pdksDashboardProvider.select((s) => s.requestsForEmployee(employeeId)),
    );
    final pal = HasibuPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'İK Taleplerim & Onay Durumu (${reqs.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: pal.textPrimary,
                ),
              ),
              Text(
                'Onaylanan talepler puantaja otomatik işlenir',
                style: TextStyle(fontSize: 11.5, color: pal.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (reqs.isEmpty)
            Text(
              'Henüz oluşturduğunuz bir izin, fazla mesai veya hareket düzeltme talebi bulunmuyor.',
              style: TextStyle(fontSize: 12, color: pal.textSecondary),
            ),
          for (final r in reqs)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: pal.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pal.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.type.label} (${r.targetDate}${r.endDate != null ? " - ${r.endDate}" : ""})',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.reason,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: switch (r.status) {
                        HrRequestStatus.pending =>
                          const Color(0xFFD97706).withValues(alpha: 0.15),
                        HrRequestStatus.approved =>
                          const Color(0xFF059669).withValues(alpha: 0.15),
                        HrRequestStatus.rejected =>
                          const Color(0xFFDC2626).withValues(alpha: 0.15),
                      },
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: switch (r.status) {
                          HrRequestStatus.pending => const Color(0xFFD97706),
                          HrRequestStatus.approved => const Color(0xFF059669),
                          HrRequestStatus.rejected => const Color(0xFFDC2626),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// YENİ REKABETÇİ MODÜL: İK TALEP ONAY MERKEZİ & 4857 UYUM RADARI
// ============================================================================
class HrRequestsAndComplianceView extends ConsumerStatefulWidget {
  const HrRequestsAndComplianceView({super.key});

  @override
  ConsumerState<HrRequestsAndComplianceView> createState() =>
      _HrRequestsAndComplianceViewState();
}

class _HrRequestsAndComplianceViewState
    extends ConsumerState<HrRequestsAndComplianceView> {
  String? _lastFeedback;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final requests = state.allHrRequests;
    final pendingCount = state.pendingHrRequestsCount;
    final mismatchCount = state.statutoryLeaveMismatchCount;
    final missingOutCount = state.missingCheckOutCount;
    final missingDocsCount = state.missingDocsStaffCount;

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
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İK Talep Onay Merkezi & 4857 İş Kanunu Uyum Radarı',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Personel portalından gelen izin, fazla mesai ve unutulan giriş/çıkış taleplerini tek tıkla onaylayın; onaylanan kayıtlar doğrudan puantaja işlenir.',
                        style: TextStyle(
                          fontSize: 12,
                          color: pal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('hr_radar_new_request_button'),
                        onPressed: () {
                          if (state.dailyStatuses.isNotEmpty) {
                            showCreateHrRequestDialog(
                              context,
                              ref,
                              employee: state.dailyStatuses.first.employee,
                              allowEmployeeSwitch: true,
                            );
                          }
                        },
                        icon: const Icon(Icons.add_task_rounded, size: 16),
                        label: const Text('Yeni Talep Kaydı Aç'),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('sync_4857_leave_button'),
                        onPressed: () async {
                          final updated = await ref
                              .read(pdksDashboardProvider.notifier)
                              .syncStatutoryLeaveEntitlements();
                          if (mounted) {
                            setState(() {
                              _lastFeedback = updated > 0
                                  ? '4857 İş Kanunu Md. 53 uyarınca $updated personelin yıllık izin hakedişi kıdem yılına göre güncellendi.'
                                  : 'Tüm personellerin yıllık izin hakedişleri 4857 İş Kanunu kıdem süreleriyle tam uyumlu.';
                            });
                          }
                        },
                        icon: const Icon(Icons.gavel_rounded, size: 16),
                        label: Text(
                          mismatchCount > 0
                              ? '4857 Kıdem İzinlerini Eşitle ($mismatchCount)'
                              : '4857 Kıdem İzin Uyumunu Denetle',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SelfServiceMetricTile(
                    label: 'Onay Bekleyen Talepler',
                    value: '$pendingCount Talep',
                    subValue: 'Toplam Kayıt: ${requests.length}',
                  ),
                  _SelfServiceMetricTile(
                    label: 'Bugün Eksik Çıkış (Tek Okuma)',
                    value: '$missingOutCount Kişi',
                    subValue: 'Tarih: ${state.selectedDate}',
                  ),
                  _SelfServiceMetricTile(
                    label: 'Eksik Zorunlu Özlük Evrakı',
                    value: '$missingDocsCount Personel',
                    subValue: '6 zorunlu resmi evrak denetimi',
                  ),
                  _SelfServiceMetricTile(
                    label: '4857 Kıdem İzin Farkı',
                    value: '$mismatchCount Personel',
                    subValue: '1-5y: 14g • 5-15y: 20g • 15+y: 26g',
                  ),
                ],
              ),
              if (_lastFeedback != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _lastFeedback!,
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w700,
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
          'Personel İzin, Fazla Mesai & Hareket Düzeltme Talepleri (${requests.length})',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final req in requests)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: req.status == HrRequestStatus.pending
                    ? const Color(0xFFD97706).withValues(alpha: 0.45)
                    : pal.border,
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${req.employeeName} (#${req.employeeCardNo})',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: pal.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              req.type.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: switch (req.status) {
                                HrRequestStatus.pending =>
                                  const Color(0xFFD97706).withValues(alpha: 0.15),
                                HrRequestStatus.approved =>
                                  const Color(0xFF059669).withValues(alpha: 0.15),
                                HrRequestStatus.rejected =>
                                  const Color(0xFFDC2626).withValues(alpha: 0.15),
                              },
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              req.status.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: switch (req.status) {
                                  HrRequestStatus.pending =>
                                    const Color(0xFFD97706),
                                  HrRequestStatus.approved =>
                                    const Color(0xFF059669),
                                  HrRequestStatus.rejected =>
                                    const Color(0xFFDC2626),
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tarih: ${req.targetDate}${req.endDate != null ? " -> ${req.endDate}" : ""}'
                        '${req.requestedTime != null ? " • Saat: ${req.requestedTime}" : ""}'
                        '${req.overtimeMinutes > 0 ? " • Süre: +${req.overtimeMinutes} dk" : ""}'
                        ' • Açıklama: ${req.reason}',
                        style: TextStyle(
                          fontSize: 12,
                          color: pal.textSecondary,
                        ),
                      ),
                      if (req.reviewerNote != null &&
                          req.reviewerNote!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'İK Notu: ${req.reviewerNote}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: pal.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (req.status == HrRequestStatus.pending)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        key: ValueKey('approve_hr_req_${req.id}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final msg = await ref
                              .read(pdksDashboardProvider.notifier)
                              .reviewHrRequest(
                                request: req,
                                approve: true,
                              );
                          if (mounted) {
                            setState(() => _lastFeedback = msg);
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Onayla & Puantaja İşle'),
                      ),
                      OutlinedButton.icon(
                        key: ValueKey('reject_hr_req_${req.id}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final msg = await ref
                              .read(pdksDashboardProvider.notifier)
                              .reviewHrRequest(
                                request: req,
                                approve: false,
                              );
                          if (mounted) {
                            setState(() => _lastFeedback = msg);
                          }
                        },
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reddet'),
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

Future<void> showHrRequestsAndComplianceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Flexible(
            child: Text(
              'İK Talep Onay Merkezi & 4857 Uyum Radarı',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: const SizedBox(
        width: 860,
        height: 540,
        child: HrRequestsAndComplianceView(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}

Future<void> showCreateHrRequestDialog(
  BuildContext context,
  WidgetRef ref, {
  required Employee employee,
  bool allowEmployeeSwitch = false,
}) async {
  final state = ref.read(pdksDashboardProvider);
  Employee selectedEmp = employee;
  HrRequestType selectedType = HrRequestType.annualLeave;
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
                      for (final s in state.dailyStatuses)
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
                      final match = state.dailyStatuses.where(
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

Future<void> showPuantajCsvExportDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = ref.read(pdksDashboardProvider);
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
                  // UTF-8 BOM ekleyerek Türkçe karakterlerin Excel'de bozulmasını önle
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
