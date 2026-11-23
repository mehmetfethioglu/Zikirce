import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/release/hasibu_release_notes.dart';
import '../../../../core/security/hasibu_security_service.dart';
import '../../../../core/services/google_drive_sync_service.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'attendance_absence_report_view.dart';
import 'cloud_backup_center_dialog.dart';
import 'employee_portal_view.dart';
import 'hasibu_login_screen.dart';
import 'hasibu_release_notes_dialog.dart';
import 'hasibu_settings_view.dart';

export 'hasibu_settings_view.dart' show showCreateHrRequestDialog;

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
        const _ShellNavDestination(
          id: 'live_pdks',
          sectionTitle: 'PERSONEL & PDKS',
          module: HasibuModule.pdksHr,
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: 'Canlı Yoklama',
          mobileShortLabel: 'Yoklama',
          view: _LiveAttendanceDashboardView(),
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
          view: _TenfeiTerminalsAndSyncView(),
        ),
        const _ShellNavDestination(
          id: 'branch_qr_gps',
          sectionTitle: 'PERSONEL & PDKS',
          module: HasibuModule.pdksHr,
          icon: Icons.qr_code_scanner_outlined,
          selectedIcon: Icons.qr_code_scanner_rounded,
          label: 'Şube QR / GPS Yoklama',
          mobileShortLabel: 'QR / GPS',
          view: _BranchQrGpsCheckInView(),
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
            icon: Icons.qr_code_scanner_outlined,
            selectedIcon: Icons.qr_code_scanner_rounded,
            label: 'Şube QR / GPS Yoklama',
            mobileShortLabel: 'QR / GPS',
            view: _BranchQrGpsCheckInView(),
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
    final pendingReqCount = ref.watch(
      pdksDashboardProvider.select((s) => s.pendingHrRequestsCount),
    );
    final pal = HasibuPalette.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 700;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 20,
              isMobile ? 12 : 16,
              isMobile ? 12 : 20,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ÖZET KPI KARTLARI (En üstte ferah ve net görünüm)
                const _KpiSummaryCards(),
                const SizedBox(height: 10),

                // 2. MODERN EXCEL RIBBON FİLTRE & ARAMA ŞERİDİ (Kompakt 2 satırlı şerit)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: pal.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pal.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => ref
                                  .read(pdksDashboardProvider.notifier)
                                  .setSearchQuery(val),
                              decoration: InputDecoration(
                                hintText:
                                    'Personel adı, sicil/kart no veya bölüm ara...',
                                prefixIcon:
                                    const Icon(Icons.search_rounded, size: 18),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                fillColor: pal.subtle,
                              ),
                            ),
                          ),
                          if (!isMobile) ...[
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              key: const ValueKey(
                                'open_hr_requests_modal_button',
                              ),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: pendingReqCount > 0
                                    ? const Color(0xFFD97706)
                                    : null,
                              ),
                              onPressed: () =>
                                  showHrRequestsAndComplianceDialog(
                                context,
                                ref,
                              ),
                              icon: const Icon(
                                Icons.fact_check_outlined,
                                size: 15,
                              ),
                              label: Text(
                                pendingReqCount > 0
                                    ? 'İK Talepleri ($pendingReqCount)'
                                    : 'İK Talepleri',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              key: const ValueKey(
                                'export_puantaj_csv_button',
                              ),
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
                                'Excel / CSV',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                            const SizedBox(width: 6),
                            FilledButton.tonalIcon(
                              key: const ValueKey(
                                'ribbon_terminal_pull_button',
                              ),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () =>
                                  pullTerminalAndShowPopup(context, ref),
                              icon: const Icon(
                                Icons.sync_rounded,
                                size: 15,
                              ),
                              label: const Text(
                                'Terminalden Veri Çek',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // TEK SATIRDA BİRLEŞTİRİLMİŞ EXCEL ŞERİDİ (Takvim Tarih Seçici | Şube | Durum Filtresi)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ActionChip(
                              key: const ValueKey(
                                'calendar_date_picker_button',
                              ),
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
                                    PdksDashboardNotifier.formatDisplayDate(
                                      selectedDate,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 16,
                                  ),
                                ],
                              ),
                              tooltip: 'Takvimden Tarih Seçmek İçin Dokunun',
                              onPressed: () =>
                                  pickPdksDateWithCalendar(context, ref),
                            ),
                            if (selectedDate !=
                                PdksDashboardNotifier.todayDateKey()) ...[
                              const SizedBox(width: 4),
                              ActionChip(
                                key: const ValueKey('jump_to_today_button'),
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(
                                  Icons.today_rounded,
                                  size: 14,
                                  color: Color(0xFF10B981),
                                ),
                                label: const Text(
                                  'Bugüne Dön',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => ref
                                    .read(pdksDashboardProvider.notifier)
                                    .setSelectedDate(
                                      PdksDashboardNotifier.todayDateKey(),
                                    ),
                              ),
                            ],
                            Container(
                              width: 1,
                              height: 22,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              color: pal.border,
                            ),
                            const _BranchSelectorChips(),
                            Container(
                              width: 1,
                              height: 22,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              color: pal.border,
                            ),
                            const _PdksAnomalyFilterRibbon(),
                          ],
                        ),
                      ),
                    ],
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
    final isBranchScoped =
        ref.watch(pdksDashboardProvider.select((s) => s.isBranchScoped));
    final isSingleBranchScoped = ref.watch(
      pdksDashboardProvider.select((s) => s.isSingleBranchScoped),
    );
    final selectedBranchId = ref.watch(
      pdksDashboardProvider.select((s) => s.effectiveSelectedBranchId),
    );

    if (isSingleBranchScoped) {
      final scopedMatch = branches.where((b) => b.id == selectedBranchId);
      final label = scopedMatch.isNotEmpty
          ? scopedMatch.first.name
          : 'Yetkili Şube #$selectedBranchId';
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              key: const ValueKey('locked_branch_scope_chip'),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.lock_outline_rounded, size: 14),
              label: Text(label, style: const TextStyle(fontSize: 11.5)),
              selected: true,
              onSelected: null,
            ),
          ],
        ),
      );
    }

    if (isBranchScoped) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              key: const ValueKey('scoped_all_my_branches_chip'),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.lock_outline_rounded, size: 14),
              label: Text(
                'Yetkili Şubelerim (${branches.length})',
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
                  size: 14,
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
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            visualDensity: VisualDensity.compact,
            label: const Text(
              'Tüm Şubeler & Merkez',
              style: TextStyle(fontSize: 11.5),
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
                size: 14,
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
        final double cardWidth;
        if (constraints.maxWidth >= 980) {
          cardWidth = (constraints.maxWidth - 50) / 6;
        } else if (constraints.maxWidth >= 560) {
          cardWidth = (constraints.maxWidth - 20) / 3;
        } else {
          cardWidth = (constraints.maxWidth - 16) / 3;
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatFilterCard(
              title: 'Toplam Kadro',
              count: total,
              color: pal.isDark
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF0F172A),
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
    final isCompactCard = width < 135;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: isCompactCard ? 9 : 12,
          vertical: isCompactCard ? 8 : 9,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : pal.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : pal.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isCompactCard ? 5 : 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: color, size: isCompactCard ? 15 : 17),
            ),
            SizedBox(width: isCompactCard ? 7 : 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompactCard ? 15 : 17,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompactCard ? 10.5 : 11,
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
    final terminatedCount = ref.watch(
      pdksDashboardProvider.select((s) => s.terminatedCount),
    );
    final selectedStateFilter = ref.watch(
      pdksDashboardProvider.select((s) => s.selectedStateFilter),
    );
    final pal = HasibuPalette.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(
            Icons.radar_rounded,
            size: 15,
            color: pal.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            'Filtre:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
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
          const SizedBox(width: 6),
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
          const SizedBox(width: 6),
          ChoiceChip(
            key: const ValueKey('anomaly_filter_overtime'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(
              Icons.more_time_rounded,
              size: 14,
              color: Color(0xFF059669),
            ),
            label: Text(
              'Fazla Mesai ($overtimeCount • +$totalOvertimeMins dk)',
              style: const TextStyle(fontSize: 11.5),
            ),
            selected: activeAnomaly == PdksAnomalyFilter.overtime,
            onSelected: (_) => ref
                .read(pdksDashboardProvider.notifier)
                .setAnomalyFilter(PdksAnomalyFilter.overtime),
          ),
          const SizedBox(width: 6),
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
          const SizedBox(width: 6),
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
          if (terminatedCount > 0) ...[
            const SizedBox(width: 6),
            ChoiceChip(
              key: const ValueKey('anomaly_filter_terminated'),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(
                Icons.person_off_outlined,
                size: 14,
                color: Color(0xFF64748B),
              ),
              label: Text(
                'İşten Ayrılan ($terminatedCount)',
                style: const TextStyle(fontSize: 11.5),
              ),
              selected: selectedStateFilter == DailyAttendanceState.terminated,
              onSelected: (selected) => ref
                  .read(pdksDashboardProvider.notifier)
                  .setStateFilter(
                    selected ? DailyAttendanceState.terminated : null,
                  ),
            ),
          ],
          if (missingOutCount > 0) ...[
            const SizedBox(width: 8),
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
              icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
              label: Text(
                'Eksik Çıkışları Tamamla ($missingOutCount)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
    final isMobile = MediaQuery.sizeOf(context).width < 700;

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
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 20,
        4,
        isMobile ? 12 : 20,
        24,
      ),
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

/// Sadeleştirilmiş Personel Kartı
/// Kart üzerinde yalnızca Avatar, Tam Ad Soyad, Bölüm/Giriş Saati ve Durum Rozeti yer alır.
/// Kart numaraları, vardiya saatleri, özlük evrakları ve hızlı aksiyonlar karta dokunulduğunda açılan pencerede gösterilir.
class _EmployeeStatusRowCard extends ConsumerWidget {
  final EmployeeDailyStatus item;

  const _EmployeeStatusRowCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final Color badgeColor = switch (item.state) {
      DailyAttendanceState.present => const Color(0xFF10B981),
      DailyAttendanceState.late => const Color(0xFFF59E0B),
      DailyAttendanceState.onLeave => const Color(0xFF38BDF8),
      DailyAttendanceState.sickReport => const Color(0xFFA855F7),
      DailyAttendanceState.absent => const Color(0xFFEF4444),
      DailyAttendanceState.terminated => const Color(0xFF64748B),
      DailyAttendanceState.notYetHired => const Color(0xFF94A3B8),
    };

    final String shortTimeText;
    if (item.firstCheckIn != null) {
      final outPart = item.lastCheckOut != null &&
              item.lastCheckOut!.id != item.firstCheckIn!.id
          ? ' - ${item.lastCheckOut!.timeFormatted}'
          : '';
      shortTimeText = '${item.firstCheckIn!.timeFormatted}$outPart';
    } else if (item.state == DailyAttendanceState.terminated) {
      shortTimeText = item.employee.hasExitDate
          ? 'Çıkış: ${PdksDashboardNotifier.formatDisplayDate(item.employee.normalizedExitDate!, includeTodayBadge: false)}'
          : 'İşten Ayrıldı';
    } else if (item.state == DailyAttendanceState.notYetHired) {
      shortTimeText =
          'Giriş: ${PdksDashboardNotifier.formatDisplayDate(item.employee.hireDate, includeTodayBadge: false)}';
    } else {
      shortTimeText = item.leaveRecord?.leaveType.label ?? 'Giriş Yok';
    }

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              EmployeeProfileAvatar(
                employee: item.employee,
                size: 40,
                borderColor: badgeColor.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 2),
                    Text(
                      '${item.department.name} • $shortTimeText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.lateMinutes > 0
                      ? '${item.state.label} (+${item.lateMinutes} dk)'
                      : item.state.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: pal.textMuted,
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

class _BranchQrGpsCheckInView extends ConsumerStatefulWidget {
  const _BranchQrGpsCheckInView();

  @override
  ConsumerState<_BranchQrGpsCheckInView> createState() =>
      _BranchQrGpsCheckInViewState();
}

class _BranchQrGpsCheckInViewState
    extends ConsumerState<_BranchQrGpsCheckInView> {
  int _selectedBranchId = 1;
  String? _lastActionFeedback;
  Timer? _totpTicker;
  DateTime _qrNow = DateTime.now();

  @override
  void initState() {
    super.initState();
    _totpTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _qrNow = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _totpTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    if (state.branches.isEmpty) {
      return const Center(
        child: Text('Yetkili şube kaydı bulunamadı.'),
      );
    }
    final effectiveBranchId =
        state.effectiveBranchScopeId ?? _selectedBranchId;
    final branch = state.branches.firstWhere(
      (b) => b.id == effectiveBranchId,
      orElse: () => state.branches.first,
    );
    final branchStaff = state.dailyStatuses
        .where((s) => s.branch.id == branch.id && !s.state.isNonActiveEmployment)
        .toList(growable: false);

    // [HW-05] 30 saniyede bir değişen TOTP (HMAC-SHA1) dinamik QR algoritması
    final totpCode = HasibuSecurityService.generateTotpCode(
      branch.qrSecret,
      timestamp: _qrNow,
    );
    final qrPayload = HasibuSecurityService.buildDynamicBranchQrPayload(
      branchId: branch.id.toString(),
      qrSecret: branch.qrSecret,
      timestamp: _qrNow,
    );
    final secondsRemaining = 30 - (_qrNow.second % 30);

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
                  if (state.isSingleBranchScoped)
                    ChoiceChip(
                      avatar: const Icon(Icons.lock_outline_rounded, size: 14),
                      label: Text(branch.name),
                      selected: true,
                      onSelected: null,
                    )
                  else
                    for (final b in state.branches)
                      ChoiceChip(
                        label: Text(b.name),
                        selected: branch.id == b.id,
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
                          'GPS Merkez: ${branch.latitude}, ${branch.longitude}\nGeofence Sınırı: ${branch.geofenceRadiusMeters.round()} metre\nDinamik TOTP (HMAC-SHA1): $totpCode (${secondsRemaining}s içinde yenilenir • >60sn reddedilir)\nPayload: $qrPayload',
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
                            qrPayload: qrPayload,
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

// ============================================================================
// YENİ REKABETÇİ MODÜL: İK TALEP ONAY MERKEZİ & 4857 UYUM RADARI
// ============================================================================
class _HrComplianceMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String subValue;

  const _HrComplianceMetricTile({
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
    final tamperedLogs = state.tamperedAttendanceLogs;
    final auditLogs = state.auditLogs;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // [HW-04] MANİPÜLE EDİLMİŞ KAYIT (HMAC-SHA256 integrityHash) KIRMIZI ALARM KALKANI
        if (tamperedLogs.isNotEmpty)
          Container(
            key: const ValueKey('tampered_attendance_alarm_card'),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.gpp_bad_rounded,
                      color: Color(0xFFDC2626),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'KIRMIZI ALARM — Manipüle Edilmiş Kayıt Tespit Edildi (${tamperedLogs.length} Kayıt)',
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aşağıdaki puantaj kayıtlarının veritabanındaki saati veya doğrulama verisi HMAC-SHA256 (integrityHash) imzasıyla uyuşmuyor:',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final tLog in tamperedLogs.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• Manipüle Edilmiş Kayıt: Kart #${tLog.cardNo} • Tarih/Saat: ${tLog.dateKey} ${tLog.timeFormatted} • Kayıt ID: ${tLog.id}',
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
                          final activeStaff = state.filteredByBranch;
                          final defaultEmp = activeStaff.isNotEmpty
                              ? activeStaff.first.employee
                              : (state.dailyStatuses.isNotEmpty
                                  ? state.dailyStatuses.first.employee
                                  : null);
                          if (defaultEmp != null) {
                            showCreateHrRequestDialog(
                              context,
                              ref,
                              employee: defaultEmp,
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
                  _HrComplianceMetricTile(
                    label: 'Onay Bekleyen Talepler',
                    value: '$pendingCount Talep',
                    subValue: 'Toplam Kayıt: ${requests.length}',
                  ),
                  _HrComplianceMetricTile(
                    label: 'Bugün Eksik Çıkış (Tek Okuma)',
                    value: '$missingOutCount Kişi',
                    subValue: 'Tarih: ${state.selectedDate}',
                  ),
                  _HrComplianceMetricTile(
                    label: 'Eksik Zorunlu Özlük Evrakı',
                    value: '$missingDocsCount Personel',
                    subValue: '6 zorunlu resmi evrak denetimi',
                  ),
                  _HrComplianceMetricTile(
                    label: '4857 Kıdem İzin Farkı',
                    value: '$mismatchCount Personel',
                    subValue: '1-5y: 14g • 5-15y: 20g • 15+y: 26g',
                  ),
                  _HrComplianceMetricTile(
                    label: 'HMAC-SHA256 Bütünlük Denetimi',
                    value: tamperedLogs.isEmpty
                        ? 'Tam Bütünlük'
                        : '${tamperedLogs.length} Manipüle Kayıt!',
                    subValue: tamperedLogs.isEmpty
                        ? 'Tüm puantaj imzaları doğrulandı'
                        : 'Manipüle Edilmiş Kayıt Alarmı',
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
                        onPressed: state.isCommercialWriteLocked
                            ? null
                            : () async {
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
                        label: Text(
                          state.isCommercialWriteLocked
                              ? 'Salt-Okunur Kilitli'
                              : 'Onayla & Puantaja İşle',
                        ),
                      ),
                      OutlinedButton.icon(
                        key: ValueKey('reject_hr_req_${req.id}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: state.isCommercialWriteLocked
                            ? null
                            : () async {
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
        const SizedBox(height: 18),
        // [AUD-01] & [AUD-02] SİLİNEMEZ DENETİM İZİ (audit_logs) TABLOSU
        Container(
          key: const ValueKey('immutable_audit_logs_section'),
          padding: const EdgeInsets.all(16),
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
                  const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF0284C7),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Silinemez Denetim İzi — Audit Logs (${auditLogs.length} Kayıt)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '1-Tıkla Eksik Çıkış Tamamlama, İK Talep Onaylama, Yıllık İzin Hakediş Eşitleme ve Sahte GPS engellemeleri HMAC-SHA256 zinciriyle değiştirilemez şekilde kaydedilir.',
                style: TextStyle(fontSize: 11.5, color: pal.textSecondary),
              ),
              const SizedBox(height: 8),
              if (auditLogs.isEmpty)
                Text(
                  'Henüz denetim izi kaydı oluşmadı.',
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              for (final entry in auditLogs.take(8))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '[${entry.timestamp.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}] '
                    '${entry.actionType} • Aktör: ${entry.actorEmployeeId} • Hedef: ${entry.targetRecordId} '
                    '(${entry.oldValue} -> ${entry.newValue}) • Hash: #${entry.hash.substring(0, 10)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: pal.textPrimary,
                    ),
                  ),
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
