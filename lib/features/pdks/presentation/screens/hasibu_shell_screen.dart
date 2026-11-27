import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/release/hasibu_release_notes.dart';
import '../../../../core/security/hasibu_security_service.dart';
import '../../../../core/services/google_drive_sync_service.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import '../widgets/employee_profile_avatar.dart';
import '../widgets/hasibu_theme_palette.dart';
import 'attendance_absence_report_view.dart';
import 'attendance_correction_settings_view.dart';
import 'branch_qr_gps_checkin_view.dart';
import 'company_branches_settings_view.dart';
import 'employee_portal_view.dart';
import 'employees_management_settings_view.dart';
import 'hasibu_login_screen.dart';
import 'hasibu_release_notes_dialog.dart';
import 'hr_requests_compliance_view.dart';
import 'leaves_and_reports_view.dart';
import 'live_attendance_dashboard_view.dart';
import 'monthly_puantaj_matrix_view.dart';
import 'pdks_operational_dialogs.dart';
import 'shift_tolerance_settings_view.dart';
import 'tenfei_terminals_sync_view.dart';

export 'hr_requests_compliance_view.dart'
    show HrRequestsAndComplianceView, showHrRequestsAndComplianceDialog;
export 'pdks_operational_dialogs.dart'
    show showCreateHrRequestDialog, showPuantajCsvExportDialog;

class _ShellNavDestination {
  final String id;
  final String sectionTitle;
  final HasibuModule module;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String mobileShortLabel;
  final Widget view;
  final int badgeCount;

  const _ShellNavDestination({
    required this.id,
    required this.sectionTitle,
    required this.module,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.mobileShortLabel,
    required this.view,
    this.badgeCount = 0,
  });
}

class HasibuShellScreen extends ConsumerStatefulWidget {
  const HasibuShellScreen({super.key});

  @override
  ConsumerState<HasibuShellScreen> createState() => _HasibuShellScreenState();
}

class _HasibuShellScreenState extends ConsumerState<HasibuShellScreen>
    with WidgetsBindingObserver {
  String _selectedDestId = 'live_pdks';
  bool _isAppInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HasibuSecurityService.setFlagSecureEnabled(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldShield = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if (_isAppInBackground != shouldShield && mounted) {
      setState(() => _isAppInBackground = shouldShield);
    }
  }

  List<_ShellNavDestination> _buildDestinations({
    required List<HasibuModule> allowedModules,
    required int pendingHrCount,
  }) {
    final dests = <_ShellNavDestination>[];
    final hasPdks = allowedModules.contains(HasibuModule.pdksHr);
    final hasPortal = allowedModules.contains(HasibuModule.employeePortal);
    final hasSettings = allowedModules.contains(HasibuModule.systemSettings);

    if (hasPdks) {
      dests.addAll([
        _ShellNavDestination(
          id: 'live_pdks',
          sectionTitle: 'PERSONEL & PDKS',
          module: HasibuModule.pdksHr,
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: 'Canlı Yoklama',
          mobileShortLabel: 'Yoklama',
          view: LiveAttendanceDashboardView(
            onOpenHrCompliance: () =>
                showHrRequestsAndComplianceDialog(context, ref),
          ),
        ),
        const _ShellNavDestination(
          id: 'attendance_report',
          sectionTitle: 'PERSONEL & PDKS',
          module: HasibuModule.pdksHr,
          icon: Icons.assessment_outlined,
          selectedIcon: Icons.assessment_rounded,
          label: 'Devam / Devamsızlık Raporu',
          mobileShortLabel: 'Rapor',
          view: AttendanceAbsenceReportView(),
        ),
        const _ShellNavDestination(
          id: 'monthly_puantaj',
          sectionTitle: 'PERSONEL & PDKS',
          module: HasibuModule.pdksHr,
          icon: Icons.grid_on_outlined,
          selectedIcon: Icons.grid_on_rounded,
          label: 'Aylık Puantaj Cetveli',
          mobileShortLabel: 'Puantaj',
          view: MonthlyPuantajMatrixView(),
        ),
        const _ShellNavDestination(
          id: 'leaves_reports',
          sectionTitle: 'PERSONEL & PDKS',
          module: HasibuModule.pdksHr,
          icon: Icons.medical_information_outlined,
          selectedIcon: Icons.medical_information_rounded,
          label: 'İzin & Raporlar',
          mobileShortLabel: 'İzinler',
          view: LeavesAndReportsSettingsView(),
        ),
        const _ShellNavDestination(
          id: 'attendance_correction',
          sectionTitle: 'PERSONEL & PDKS',
          module: HasibuModule.pdksHr,
          icon: Icons.edit_calendar_outlined,
          selectedIcon: Icons.edit_calendar_rounded,
          label: 'Hareket Düzeltme',
          mobileShortLabel: 'Düzeltme',
          view: AttendanceCorrectionSettingsView(),
        ),
        _ShellNavDestination(
          id: 'hr_requests',
          sectionTitle: 'PERSONEL & PDKS',
          module: HasibuModule.pdksHr,
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
          label: 'İK Talepleri & Uyum',
          mobileShortLabel: 'Talepler',
          view: const HrRequestsAndComplianceView(),
          badgeCount: pendingHrCount,
        ),
        const _ShellNavDestination(
          id: 'face_terminals',
          sectionTitle: 'PERSONEL & PDKS',
          module: HasibuModule.pdksHr,
          icon: Icons.face_retouching_natural_outlined,
          selectedIcon: Icons.face_retouching_natural_rounded,
          label: 'Yüz Okutma Terminali',
          mobileShortLabel: 'Terminal',
          view: TenfeiTerminalsAndSyncView(),
        ),
        const _ShellNavDestination(
          id: 'branch_qr_gps',
          sectionTitle: 'PERSONEL & PDKS',
          module: HasibuModule.pdksHr,
          icon: Icons.location_on_outlined,
          selectedIcon: Icons.location_on_rounded,
          label: 'Şube GPS Yoklama',
          mobileShortLabel: 'GPS',
          view: BranchQrGpsCheckInView(),
        ),
      ]);
    }

    if (hasPortal) {
      dests.add(
        const _ShellNavDestination(
          id: 'employee_portal',
          sectionTitle: 'PERSONEL PORTALI',
          module: HasibuModule.employeePortal,
          icon: Icons.badge_outlined,
          selectedIcon: Icons.badge_rounded,
          label: 'Personel Portalı',
          mobileShortLabel: 'Portalım',
          view: EmployeeSelfServicePortalView(),
        ),
      );
      if (!hasPdks) {
        dests.add(
          const _ShellNavDestination(
            id: 'branch_qr_gps',
            sectionTitle: 'PERSONEL PORTALI',
            module: HasibuModule.employeePortal,
            icon: Icons.location_on_outlined,
            selectedIcon: Icons.location_on_rounded,
            label: 'Şube GPS Yoklama',
            mobileShortLabel: 'GPS',
            view: BranchQrGpsCheckInView(),
          ),
        );
      }
    }

    if (hasSettings) {
      dests.addAll(const [
        _ShellNavDestination(
          id: 'employees_mgmt',
          sectionTitle: 'YÖNETİM & AYARLAR',
          module: HasibuModule.systemSettings,
          icon: Icons.manage_accounts_outlined,
          selectedIcon: Icons.manage_accounts_rounded,
          label: 'Personel & Bölüm',
          mobileShortLabel: 'Personel',
          view: EmployeesManagementSettingsView(),
        ),
        _ShellNavDestination(
          id: 'shifts_settings',
          sectionTitle: 'YÖNETİM & AYARLAR',
          module: HasibuModule.systemSettings,
          icon: Icons.schedule_outlined,
          selectedIcon: Icons.schedule_rounded,
          label: 'Mesai & Vardiya',
          mobileShortLabel: 'Vardiya',
          view: ShiftAndLateToleranceSettingsView(),
        ),
        _ShellNavDestination(
          id: 'company_branches',
          sectionTitle: 'YÖNETİM & AYARLAR',
          module: HasibuModule.systemSettings,
          icon: Icons.business_outlined,
          selectedIcon: Icons.business_rounded,
          label: 'Şirket, Şube & Cihazlar',
          mobileShortLabel: 'Ayarlar',
          view: CompanyAndBranchesSettingsView(),
        ),
      ]);
    }

    return dests;
  }

  List<_ShellNavDestination> _buildMobileBottomDestinations(
    List<_ShellNavDestination> all,
  ) {
    final byId = {for (final d in all) d.id: d};
    if (byId.containsKey('live_pdks')) {
      return [
        byId['live_pdks']!,
        if (byId.containsKey('attendance_report')) byId['attendance_report']!,
        if (byId.containsKey('leaves_reports')) byId['leaves_reports']!,
        if (byId.containsKey('company_branches'))
          byId['company_branches']!
        else if (byId.containsKey('employee_portal'))
          byId['employee_portal']!,
      ];
    }
    return all.take(4).toList(growable: false);
  }

  void _selectDestination(_ShellNavDestination dest) {
    setState(() => _selectedDestId = dest.id);
    if (ref.read(pdksDashboardProvider).activeModule != dest.module) {
      ref.read(pdksDashboardProvider.notifier).selectModule(dest.module);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authSession =
        ref.watch(pdksDashboardProvider.select((s) => s.authSession));
    final allowedModules = HasibuModule.filterActive(authSession.allowedModules);

    ref.listen<HasibuModule>(
      pdksDashboardProvider.select((s) => s.activeModule),
      (prev, next) {
        final pending = ref.read(pdksDashboardProvider).pendingHrRequestsCount;
        final all = _buildDestinations(
          allowedModules: allowedModules,
          pendingHrCount: pending,
        );
        if (all.isEmpty) return;
        final current = all.where((d) => d.id == _selectedDestId);
        if (current.isEmpty || current.first.module != next) {
          final target = all.firstWhere(
            (d) => d.module == next,
            orElse: () => all.first,
          );
          if (mounted && _selectedDestId != target.id) {
            setState(() => _selectedDestId = target.id);
          }
        }
      },
    );

    ref.listen<bool>(
      pdksDashboardProvider.select((s) => s.authSession.isAuthenticated),
      (prev, isAuth) {
        if (isAuth && prev != true) {
          final session = ref.read(pdksDashboardProvider).authSession;
          final activeMod = ref.read(pdksDashboardProvider).activeModule;
          final activeMods = HasibuModule.filterActive(session.allowedModules);
          final all = _buildDestinations(
            allowedModules: activeMods,
            pendingHrCount:
                ref.read(pdksDashboardProvider).pendingHrRequestsCount,
          );
          if (all.isNotEmpty) {
            final initial = all.firstWhere(
              (d) => d.module == activeMod,
              orElse: () => all.first,
            );
            if (mounted) {
              setState(() => _selectedDestId = initial.id);
            }
          }
        }
      },
    );

    if (!authSession.isAuthenticated) {
      return const HasibuLoginScreen();
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 860;
    final companySettings = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings),
    );
    final pendingHrCount = ref.watch(
      pdksDashboardProvider.select((s) => s.pendingHrRequestsCount),
    );
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final pal = HasibuPalette.of(context);
    String? scopedBranchLabel;
    if (authSession.isBranchScoped) {
      final scopedIds = authSession.effectiveScopedBranchIds;
      final matchedNames = branches
          .where((b) => scopedIds.contains(b.id))
          .map((b) => b.name)
          .toList(growable: false);
      if (matchedNames.isEmpty) {
        scopedBranchLabel = 'Şube #${scopedIds.join(",")}';
      } else if (matchedNames.length <= 2) {
        scopedBranchLabel = matchedNames.join(', ');
      } else {
        scopedBranchLabel = '${matchedNames.length} Yetkili Şube';
      }
    }

    final destinations = _buildDestinations(
      allowedModules: allowedModules,
      pendingHrCount: pendingHrCount,
    );
    final selectedDest = destinations.firstWhere(
      (d) => d.id == _selectedDestId,
      orElse: () => destinations.first,
    );
    final mobileBottomDests = _buildMobileBottomDestinations(destinations);
    final mobileBottomIdx = mobileBottomDests.indexWhere(
      (d) => d.id == selectedDest.id,
    );

    return Scaffold(
      backgroundColor: pal.bg,
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: pal.card,
              child: SafeArea(
                child: _HasibuSidebar(
                  companySettings: companySettings,
                  destinations: destinations,
                  selectedDestId: selectedDest.id,
                  showHeader: true,
                  onSelect: (dest) {
                    _selectDestination(dest);
                    Navigator.of(context).pop();
                  },
                  onOpenReleaseNotes: () {
                    Navigator.of(context).pop();
                    showHasibuReleaseNotesDialog(context);
                  },
                ),
              ),
            ),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: isWide ? 54 : 52,
        titleSpacing: isWide ? 16 : 8,
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
              size: isWide ? 32 : 28,
              borderRadius: 8,
              onTap: authSession.canAccess(HasibuModule.systemSettings)
                  ? () => showCompanyLogoDialog(context, ref)
                  : null,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    companySettings.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: isWide ? 14.5 : 13,
                      letterSpacing: -0.2,
                      color: pal.textPrimary,
                    ),
                  ),
                  if (!isWide)
                    Text(
                      selectedDest.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: pal.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (isWide) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pal.chip,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: pal.border),
                  ),
                  child: Text(
                    scopedBranchLabel != null
                        ? '${selectedDest.label} • ${authSession.displayName} • $scopedBranchLabel'
                        : '${selectedDest.label} • ${authSession.displayName}',
                    maxLines: 1,
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
          const SizedBox(width: 4),
          const UserThemeSelectorBar(compact: true),
          if (isWide) const ReleaseNotesAppBarButton(),
          if (authSession.canAccess(HasibuModule.systemSettings) && isWide)
            IconButton(
              key: const ValueKey('appbar_settings_button'),
              visualDensity: VisualDensity.compact,
              tooltip: 'Şirket, Şube & Cihaz Ayarları',
              onPressed: () {
                final settingsDest = destinations.firstWhere(
                  (d) => d.id == 'company_branches',
                  orElse: () => selectedDest,
                );
                _selectDestination(settingsDest);
              },
              icon: Icon(
                Icons.settings_outlined,
                size: 19,
                color: selectedDest.id == 'company_branches'
                    ? const Color(0xFF0284C7)
                    : pal.textSecondary,
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Oturumu Kapat (${authSession.displayName})',
            onPressed: () =>
                ref.read(pdksDashboardProvider.notifier).logout(),
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFDC2626),
              size: 19,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // [LIC-05] SALT-OKUNUR (READ-ONLY) ABONELİK SONU & SAAT MANİPÜLASYONU KALKANI BANDI
              Consumer(
                builder: (ctx, r, _) {
                  final isLocked = r.watch(
                    pdksDashboardProvider.select((s) => s.isCommercialWriteLocked),
                  );
                  final licenseMsg = r.watch(
                    pdksDashboardProvider.select((s) => s.licenseStatusMessage),
                  );
                  if (!isLocked) return const SizedBox.shrink();
                  return Container(
                    key: const ValueKey('read_only_paywall_banner'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    color: const Color(0xFFDC2626),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_clock_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'SALT-OKUNUR (READ-ONLY) KORUMA MODU: $licenseMsg • Verileriniz güvende; Tenfei D35 çekimi, Excel/CSV Puantaj dışa aktarımı, İK onayı ve Drive senkronizasyonu kilitlendi.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        FilledButton.tonal(
                          key: const ValueKey('restore_license_demo_button'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFDC2626),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => r
                              .read(pdksDashboardProvider.notifier)
                              .setSubscriptionExpiredForDemo(false),
                          child: const Text(
                            'Lisansı Yenile / Aktifleştir',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 244,
                            child: _HasibuSidebar(
                              companySettings: companySettings,
                              destinations: destinations,
                              selectedDestId: selectedDest.id,
                              showHeader: false,
                              onSelect: _selectDestination,
                              onOpenReleaseNotes: () =>
                                  showHasibuReleaseNotesDialog(context),
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: pal.border,
                          ),
                          Expanded(child: selectedDest.view),
                        ],
                      )
                    : selectedDest.view,
              ),
            ],
          ),
          // [AUD-03] Mobil İK ve Yönetici ekranlarında App Switcher hassas veri gizleme perdesi
          if (_isAppInBackground &&
              selectedDest.module != HasibuModule.employeePortal)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFF0F172A),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.security_rounded,
                        color: Color(0xFF38BDF8),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        companySettings.companyName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'İK ve Yönetici Verileri Korunuyor (FLAG_SECURE)',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: isWide || mobileBottomDests.length < 2
          ? null
          : NavigationBar(
              selectedIndex: mobileBottomIdx < 0 ? 0 : mobileBottomIdx,
              indicatorColor: mobileBottomIdx < 0
                  ? Colors.transparent
                  : const Color(0xFF0284C7).withValues(alpha: 0.14),
              onDestinationSelected: (idx) =>
                  _selectDestination(mobileBottomDests[idx]),
              destinations: [
                for (final d in mobileBottomDests)
                  NavigationDestination(
                    icon: Icon(d.icon, size: 21),
                    selectedIcon: Icon(
                      d.selectedIcon,
                      size: 21,
                      color: mobileBottomIdx < 0
                          ? null
                          : const Color(0xFF0284C7),
                    ),
                    label: d.mobileShortLabel,
                  ),
              ],
            ),
    );
  }
}

class _HasibuSidebar extends StatelessWidget {
  final CompanySettings companySettings;
  final List<_ShellNavDestination> destinations;
  final String selectedDestId;
  final bool showHeader;
  final ValueChanged<_ShellNavDestination> onSelect;
  final VoidCallback? onOpenReleaseNotes;

  const _HasibuSidebar({
    required this.companySettings,
    required this.destinations,
    required this.selectedDestId,
    required this.showHeader,
    required this.onSelect,
    this.onOpenReleaseNotes,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final grouped = <String, List<_ShellNavDestination>>{};
    for (final d in destinations) {
      grouped.putIfAbsent(d.sectionTitle, () => []).add(d);
    }

    return Container(
      color: pal.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  CompanyLogoBadge(
                    settings: companySettings,
                    size: 34,
                    borderRadius: 9,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companySettings.companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: pal.textPrimary,
                          ),
                        ),
                        Text(
                          'Personel & PDKS',
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
            Divider(height: 1, color: pal.border),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: pal.textMuted,
                      ),
                    ),
                  ),
                  for (final dest in entry.value)
                    _SidebarNavTile(
                      dest: dest,
                      isSelected: dest.id == selectedDestId,
                      onTap: () => onSelect(dest),
                    ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          if (onOpenReleaseNotes != null) ...[
            Divider(height: 1, color: pal.border),
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('sidebar_release_notes_button'),
                onTap: onOpenReleaseNotes,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.new_releases_outlined,
                        size: 18,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sürüm Notları',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'v$hasibuAppVersion',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarNavTile extends StatelessWidget {
  final _ShellNavDestination dest;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavTile({
    required this.dest,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    const activeColor = Color(0xFF0284C7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: isSelected
            ? activeColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('nav_${dest.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: activeColor.withValues(alpha: 0.38),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? dest.selectedIcon : dest.icon,
                  size: 18,
                  color: isSelected ? activeColor : pal.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dest.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? pal.textPrimary : pal.textSecondary,
                    ),
                  ),
                ),
                if (dest.badgeCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${dest.badgeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    final isCloudBusy =
        ref.watch(pdksDashboardProvider.select((s) => s.isCloudBusy));
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

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('appbar_terminal_diag_button'),
            visualDensity: VisualDensity.compact,
            tooltip: 'Cihaz Bağlantı Kontrolü',
            onPressed: () => showTerminalDiagnosticsDialog(context, ref),
            icon: Icon(Icons.radar_rounded, size: 19, color: termDotColor),
          ),
          IconButton(
            key: const ValueKey('appbar_terminal_pull_button'),
            visualDensity: VisualDensity.compact,
            tooltip: 'Terminalden Şimdi Veri Çek',
            onPressed: isPolling
                ? null
                : () => pullTerminalAndShowPopup(context, ref),
            icon: isPolling
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.sync_rounded,
                    size: 19,
                    color: Color(0xFF0284C7),
                  ),
          ),
          IconButton(
            key: const ValueKey('gmail_sync_setup_button'),
            visualDensity: VisualDensity.compact,
            tooltip: 'Gmail & Bulut Eşitleme',
            onPressed: () => showGmailDriveSyncDialog(context, ref),
            icon: isCloudBusy
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.cloud_sync_outlined, size: 19, color: dotColor),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: const ValueKey('appbar_terminal_diag_button'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => showTerminalDiagnosticsDialog(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: pal.subtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: pal.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radar_rounded, size: 14, color: termDotColor),
                const SizedBox(width: 5),
                Text(
                  'Terminal',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: pal.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          key: const ValueKey('appbar_terminal_pull_button'),
          borderRadius: BorderRadius.circular(8),
          onTap: isPolling
              ? null
              : () => pullTerminalAndShowPopup(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPolling)
                  const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.sync_rounded,
                    size: 14,
                    color: Color(0xFF0284C7),
                  ),
                const SizedBox(width: 5),
                Text(
                  isPolling ? 'Çekiliyor...' : 'Veri Çek',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          key: const ValueKey('gmail_sync_setup_button'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => showGmailDriveSyncDialog(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: pal.subtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: pal.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCloudBusy)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.cloud_sync_outlined,
                    size: 14,
                    color: pal.textSecondary,
                  ),
                ],
                const SizedBox(width: 4),
                Text(
                  'Bulut',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: pal.textPrimary,
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

