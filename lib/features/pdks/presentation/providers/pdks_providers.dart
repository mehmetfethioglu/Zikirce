import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/hasibu_database.dart';
import '../../../../core/security/hasibu_security_service.dart';
import '../../../../core/security/license_guard_service.dart';
import '../../../../core/services/google_auth_adapter.dart';
import '../../../../core/services/google_drive_sync_service.dart';
import '../../data/tenfei_zk_client.dart';
import '../../data/workplace_seed_data.dart';
import '../../domain/pdks_models.dart';

final hasibuDatabaseProvider = Provider<HasibuDatabase>((ref) {
  final db = HasibuDatabase.inMemory();
  ref.onDispose(db.dispose);
  return db;
});

final googleDriveSyncServiceProvider = Provider<GoogleDriveSyncService>((ref) {
  final db = ref.watch(hasibuDatabaseProvider);
  return GoogleDriveSyncService(db: db);
});

final googleAuthAdapterProvider = Provider<GoogleAuthAdapter>((ref) {
  final sync = ref.watch(googleDriveSyncServiceProvider);
  return createPlatformGoogleAuthAdapter(sync);
});

@immutable
class PdksDashboardState {
  final AuthSession authSession;
  final HasibuModule activeModule;
  final CompanySettings companySettings;
  final String selectedDate; // YYYY-MM-DD
  final int? selectedBranchId; // null => Tüm Şubeler
  final DailyAttendanceState? selectedStateFilter; // null => Tümü
  final PdksAnomalyFilter selectedAnomalyFilter;
  final String searchQuery;
  final List<Branch> branches;
  final List<ShiftPlan> shifts;
  final List<Department> departments;
  final List<EmployeeDailyStatus> dailyStatuses;
  final List<LeaveRecord> allLeaveRecords;
  final List<PersonnelDocument> allPersonnelDocuments;
  final List<HrRequest> allHrRequests;
  final bool isPollingTerminal;
  final bool? lastTerminalReachable;
  final bool autoPollEnabled;
  final int autoPollMinutes;
  final String terminalStatusMessage;
  final DriveSyncStatus syncStatus;
  final String activeSelfServiceCardNo;
  final bool isReadOnlySubscriptionLocked;
  final bool isClockTampered;
  final String licenseStatusMessage;
  final List<AttendanceLog> tamperedAttendanceLogs;
  final List<AuditLogEntry> auditLogs;
  final int mockGpsAnomalyCount;
  final String? lastMockGpsAlert;
  final List<AppUserAccount> appUsers;
  final List<CloudBackupProfileInfo> availableCloudBackups;
  final bool isCloudBusy;
  final CloudRestoreSummary? lastRestoreSummary;

  const PdksDashboardState({
    this.authSession = const AuthSession(),
    this.activeModule = HasibuModule.pdksHr,
    this.companySettings = const CompanySettings(),
    required this.selectedDate,
    this.selectedBranchId,
    this.selectedStateFilter,
    this.selectedAnomalyFilter = PdksAnomalyFilter.all,
    this.searchQuery = '',
    this.branches = const <Branch>[],
    this.shifts = const <ShiftPlan>[],
    this.departments = const <Department>[],
    this.dailyStatuses = const <EmployeeDailyStatus>[],
    this.allLeaveRecords = const <LeaveRecord>[],
    this.allPersonnelDocuments = const <PersonnelDocument>[],
    this.allHrRequests = const <HrRequest>[],
    this.isPollingTerminal = false,
    this.lastTerminalReachable,
    this.autoPollEnabled = true,
    this.autoPollMinutes = 5,
    this.terminalStatusMessage = 'PDKS Terminali hazır',
    this.syncStatus = const DriveSyncStatus(),
    this.activeSelfServiceCardNo = kDebugMode ? '00064' : '',
    this.isReadOnlySubscriptionLocked = false,
    this.isClockTampered = false,
    this.licenseStatusMessage = 'Lisans aktif',
    this.tamperedAttendanceLogs = const <AttendanceLog>[],
    this.auditLogs = const <AuditLogEntry>[],
    this.mockGpsAnomalyCount = 0,
    this.lastMockGpsAlert,
    this.appUsers = const <AppUserAccount>[],
    this.availableCloudBackups = const <CloudBackupProfileInfo>[],
    this.isCloudBusy = false,
    this.lastRestoreSummary,
  });

  /// [LIC-05] Sistem Salt-Okunur (Read-Only) Abonelik Sonu veya Saat Manipülasyonu Kilidinde mi?
  bool get isCommercialWriteLocked =>
      isReadOnlySubscriptionLocked || isClockTampered;

  List<PersonnelDocument> documentsForEmployee(int employeeId) =>
      allPersonnelDocuments
          .where((d) => d.employeeId == employeeId)
          .toList(growable: false);

  List<HrRequest> requestsForEmployee(int employeeId) => allHrRequests
      .where((r) => r.employeeId == employeeId)
      .toList(growable: false);

  int get pendingHrRequestsCount =>
      allHrRequests.where((r) => r.status == HrRequestStatus.pending).length;

  bool hasMissingMandatoryDocuments(int employeeId) {
    final mandatoryCount = PersonnelDocumentCategory.values
        .where((c) => c.isMandatory)
        .length;
    final uploadedMandatory = allPersonnelDocuments
        .where((d) => d.employeeId == employeeId && d.category.isMandatory)
        .map((d) => d.category)
        .toSet()
        .length;
    return uploadedMandatory < mandatoryCount;
  }

  int get totalCount => filteredByBranch.length;

  /// Aktif oturumdaki kullanıcının (Yönetici, Yetkili Kullanıcı veya Personel) kendine özgü tema seçimi.
  HasibuThemeMode get activeThemeMode {
    if (authSession.isAuthenticated && authSession.appUserId != null) {
      for (final u in appUsers) {
        if (u.id == authSession.appUserId) {
          return u.themeMode;
        }
      }
    }
    if (authSession.isAuthenticated &&
        authSession.role == UserRole.employee &&
        authSession.employeeCardNo != null) {
      for (final s in dailyStatuses) {
        if (s.employee.cardNo == authSession.employeeCardNo) {
          return s.employee.themeMode;
        }
      }
    }
    return companySettings.adminThemeMode;
  }

  List<EmployeeDailyStatus> get allFilteredByBranch {
    if (selectedBranchId == null) return dailyStatuses;
    return dailyStatuses
        .where((s) => s.branch.id == selectedBranchId)
        .toList(growable: false);
  }

  List<EmployeeDailyStatus> get filteredByBranch => allFilteredByBranch
      .where((s) => !s.state.isNonActiveEmployment)
      .toList(growable: false);

  int get terminatedCount => allFilteredByBranch
      .where((s) => s.state == DailyAttendanceState.terminated)
      .length;

  int get presentCount => filteredByBranch
      .where(
        (s) =>
            s.state == DailyAttendanceState.present ||
            s.state == DailyAttendanceState.late,
      )
      .length;

  int get lateCount => filteredByBranch
      .where((s) => s.state == DailyAttendanceState.late)
      .length;

  int get absentCount => filteredByBranch
      .where((s) => s.state == DailyAttendanceState.absent)
      .length;

  int get onLeaveCount => filteredByBranch
      .where((s) => s.state == DailyAttendanceState.onLeave)
      .length;

  int get sickReportCount => filteredByBranch
      .where((s) => s.state == DailyAttendanceState.sickReport)
      .length;

  int get missingCheckOutCount =>
      filteredByBranch.where((s) => s.hasMissingCheckOut).length;

  int get overtimeStaffCount =>
      filteredByBranch.where((s) => s.overtimeMinutes > 0).length;

  int get totalOvertimeMinutes =>
      filteredByBranch.fold<int>(0, (sum, s) => sum + s.overtimeMinutes);

  int get earlyLeaveCount =>
      filteredByBranch.where((s) => s.earlyLeaveMinutes > 0).length;

  int get missingDocsStaffCount => filteredByBranch
      .where((s) => hasMissingMandatoryDocuments(s.employee.id))
      .length;

  int get statutoryLeaveMismatchCount => filteredByBranch
      .where((s) => s.employee.hasStatutoryLeaveMismatch)
      .length;

  List<EmployeeDailyStatus> get visibleStatuses {
    final source = selectedStateFilter == DailyAttendanceState.terminated
        ? allFilteredByBranch
        : filteredByBranch;
    return source.where((item) {
      if (selectedStateFilter != null && item.state != selectedStateFilter) {
        return false;
      }
      switch (selectedAnomalyFilter) {
        case PdksAnomalyFilter.all:
          break;
        case PdksAnomalyFilter.missingCheckOut:
          if (!item.hasMissingCheckOut) return false;
        case PdksAnomalyFilter.overtime:
          if (item.overtimeMinutes <= 0) return false;
        case PdksAnomalyFilter.earlyLeave:
          if (item.earlyLeaveMinutes <= 0) return false;
        case PdksAnomalyFilter.missingDocs:
          if (!hasMissingMandatoryDocuments(item.employee.id)) return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toUpperCase();
        return item.employee.fullName.toUpperCase().contains(q) ||
            item.employee.cardNo.contains(q) ||
            item.department.name.toUpperCase().contains(q);
      }
      return true;
    }).toList(growable: false);
  }

  PdksDashboardState copyWith({
    AuthSession? authSession,
    HasibuModule? activeModule,
    CompanySettings? companySettings,
    String? selectedDate,
    int? Function()? selectedBranchId,
    DailyAttendanceState? Function()? selectedStateFilter,
    PdksAnomalyFilter? selectedAnomalyFilter,
    String? searchQuery,
    List<Branch>? branches,
    List<ShiftPlan>? shifts,
    List<Department>? departments,
    List<EmployeeDailyStatus>? dailyStatuses,
    List<LeaveRecord>? allLeaveRecords,
    List<PersonnelDocument>? allPersonnelDocuments,
    List<HrRequest>? allHrRequests,
    bool? isPollingTerminal,
    bool? Function()? lastTerminalReachable,
    bool? autoPollEnabled,
    int? autoPollMinutes,
    String? terminalStatusMessage,
    DriveSyncStatus? syncStatus,
    String? activeSelfServiceCardNo,
    bool? isReadOnlySubscriptionLocked,
    bool? isClockTampered,
    String? licenseStatusMessage,
    List<AttendanceLog>? tamperedAttendanceLogs,
    List<AuditLogEntry>? auditLogs,
    int? mockGpsAnomalyCount,
    String? Function()? lastMockGpsAlert,
    List<AppUserAccount>? appUsers,
    List<CloudBackupProfileInfo>? availableCloudBackups,
    bool? isCloudBusy,
    CloudRestoreSummary? Function()? lastRestoreSummary,
  }) {
    return PdksDashboardState(
      authSession: authSession ?? this.authSession,
      activeModule: activeModule ?? this.activeModule,
      companySettings: companySettings ?? this.companySettings,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedBranchId:
          selectedBranchId != null ? selectedBranchId() : this.selectedBranchId,
      selectedStateFilter: selectedStateFilter != null
          ? selectedStateFilter()
          : this.selectedStateFilter,
      selectedAnomalyFilter:
          selectedAnomalyFilter ?? this.selectedAnomalyFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      branches: branches ?? this.branches,
      shifts: shifts ?? this.shifts,
      departments: departments ?? this.departments,
      dailyStatuses: dailyStatuses ?? this.dailyStatuses,
      allLeaveRecords: allLeaveRecords ?? this.allLeaveRecords,
      allPersonnelDocuments:
          allPersonnelDocuments ?? this.allPersonnelDocuments,
      allHrRequests: allHrRequests ?? this.allHrRequests,
      isPollingTerminal: isPollingTerminal ?? this.isPollingTerminal,
      lastTerminalReachable: lastTerminalReachable != null
          ? lastTerminalReachable()
          : this.lastTerminalReachable,
      autoPollEnabled: autoPollEnabled ?? this.autoPollEnabled,
      autoPollMinutes: autoPollMinutes ?? this.autoPollMinutes,
      terminalStatusMessage:
          terminalStatusMessage ?? this.terminalStatusMessage,
      syncStatus: syncStatus ?? this.syncStatus,
      activeSelfServiceCardNo:
          activeSelfServiceCardNo ?? this.activeSelfServiceCardNo,
      isReadOnlySubscriptionLocked:
          isReadOnlySubscriptionLocked ?? this.isReadOnlySubscriptionLocked,
      isClockTampered: isClockTampered ?? this.isClockTampered,
      licenseStatusMessage: licenseStatusMessage ?? this.licenseStatusMessage,
      tamperedAttendanceLogs:
          tamperedAttendanceLogs ?? this.tamperedAttendanceLogs,
      auditLogs: auditLogs ?? this.auditLogs,
      mockGpsAnomalyCount: mockGpsAnomalyCount ?? this.mockGpsAnomalyCount,
      lastMockGpsAlert:
          lastMockGpsAlert != null ? lastMockGpsAlert() : this.lastMockGpsAlert,
      appUsers: appUsers ?? this.appUsers,
      availableCloudBackups:
          availableCloudBackups ?? this.availableCloudBackups,
      isCloudBusy: isCloudBusy ?? this.isCloudBusy,
      lastRestoreSummary: lastRestoreSummary != null
          ? lastRestoreSummary()
          : this.lastRestoreSummary,
    );
  }
}

@immutable
class TerminalPullSummary {
  final bool anyReachable;
  final int targetTerminalCount;
  final int reachableTerminalCount;
  final int totalFetched;
  final int newInserted;
  final int logsCountForSelectedDate;
  final String selectedDateAfterPull;
  final String? latestPulledDateKey;
  final List<String> branchMessages;
  final DateTime pulledAt;

  const TerminalPullSummary({
    required this.anyReachable,
    required this.targetTerminalCount,
    required this.reachableTerminalCount,
    required this.totalFetched,
    required this.newInserted,
    required this.logsCountForSelectedDate,
    required this.selectedDateAfterPull,
    required this.latestPulledDateKey,
    required this.branchMessages,
    required this.pulledAt,
  });
}

class PdksDashboardNotifier extends StateNotifier<PdksDashboardState> {
  final HasibuDatabase _db;
  final GoogleDriveSyncService _syncService;
  final GoogleAuthAdapter _googleAuthAdapter;
  Timer? _autoPollTimer;
  Timer? _autoCloudBackupTimer;
  final Map<int, TenfeiZkClient> _activeClients = <int, TenfeiZkClient>{};
  final List<StreamSubscription<AttendanceLog>> _realtimeSubs =
      <StreamSubscription<AttendanceLog>>[];

  PdksDashboardNotifier({
    required HasibuDatabase db,
    required GoogleDriveSyncService syncService,
    GoogleAuthAdapter? googleAuthAdapter,
    String? initialSelectedDate,
  })  : _db = db,
        _syncService = syncService,
        _googleAuthAdapter =
            googleAuthAdapter ?? createPlatformGoogleAuthAdapter(syncService),
        super(
          PdksDashboardState(
            selectedDate: initialSelectedDate ?? todayDateKey(),
          ),
        ) {
    refreshDashboard();
    _configureAutoPollTimer();
    _configureAutoCloudBackupTimer();
    if (!kDebugMode &&
        (state.dailyStatuses.isEmpty ||
            state.dailyStatuses.every(
              (s) => s.employee.fullName.startsWith('PERSONEL #'),
            ))) {
      unawaited(Future<void>.microtask(() => pullFromTenfeiTerminals()));
    }
  }

  static String formatDateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Bugünün gerçek sistem tarihini YYYY-MM-DD formatında döndürür (örn. 2026-10-22).
  static String todayDateKey() => formatDateKey(DateTime.now());

  /// YYYY-MM-DD tarih anahtarını GG.AA.YYYY formatına çevirir; bugüne eşitse "(Bugün)" ekler.
  static String formatDisplayDate(
    String dateKey, {
    bool includeTodayBadge = true,
  }) {
    final parts = dateKey.split('-');
    if (parts.length == 3) {
      final formatted =
          '${parts[2].padLeft(2, '0')}.${parts[1].padLeft(2, '0')}.${parts[0]}';
      if (includeTodayBadge && dateKey == todayDateKey()) {
        return '$formatted (Bugün)';
      }
      return formatted;
    }
    return dateKey;
  }

  /// Yönetici / Yetkili Kullanıcı Girişi doğrular.
  bool loginAsAdmin({required String username, required String password}) {
    final u = username.trim().toLowerCase();
    final p = password.trim();
    final expectedUser = state.companySettings.adminUsername.toLowerCase();
    final expectedPass = state.companySettings.adminPassword;

    if (u == expectedUser &&
        HasibuSecurityService.verifyPassword(p, expectedPass)) {
      // [AUD-03] Yönetici/İK ekranlarında ekran görüntüsü ve App Switcher zırhını (FLAG_SECURE) etkinleştir
      HasibuSecurityService.setFlagSecureEnabled(true);
      state = state.copyWith(
        authSession: AuthSession(
          isAuthenticated: true,
          username: username.trim(),
          displayName: 'Yönetim (${state.companySettings.companyName})',
          role: UserRole.admin,
          allowedModules: HasibuModule.activePhaseModules,
        ),
        activeModule: HasibuModule.pdksHr,
      );
      return true;
    }

    final appUser = _db.findAppUserByUsername(u);
    if (appUser != null) {
      if (!appUser.isActive) {
        state = state.copyWith(
          authSession: state.authSession.copyWith(
            isAuthenticated: false,
            errorMessage: () =>
                'Kullanıcı hesabınız ($u) pasif duruma alınmış. Yöneticinizle iletişime geçin.',
          ),
        );
        return false;
      }
      if (HasibuSecurityService.verifyPassword(p, appUser.passwordHash)) {
        final modules = HasibuModule.filterActive(appUser.allowedModules);
        final hasAdminLikeModule = modules.any(
          (m) => m != HasibuModule.employeePortal,
        );
        HasibuSecurityService.setFlagSecureEnabled(hasAdminLikeModule);
        state = state.copyWith(
          authSession: AuthSession(
            isAuthenticated: true,
            username: appUser.username,
            displayName: appUser.displayName,
            role: appUser.role.baseRole,
            allowedModules: modules,
            appUserId: appUser.id,
            scopedBranchId: appUser.allowedBranchId,
          ),
          activeModule: modules.first,
          selectedBranchId: appUser.allowedBranchId != null
              ? () => appUser.allowedBranchId
              : null,
        );
        return true;
      }
    }

    state = state.copyWith(
      authSession: state.authSession.copyWith(
        isAuthenticated: false,
        errorMessage: () => 'Kullanıcı adı veya parola hatalı.',
      ),
    );
    return false;
  }

  /// Personel Kart/Sicil No + Kişisel Parola Girişi doğrular ve yetkili modüllerini açar.
  bool loginAsEmployee({required String cardNo, required String pin}) {
    final normalizedCard = cardNo.trim().padLeft(5, '0');
    final fallbackPin = state.companySettings.defaultEmployeePin;

    final matchIndex = state.dailyStatuses.indexWhere(
      (s) => s.employee.cardNo == normalizedCard,
    );

    if (matchIndex >= 0) {
      final emp = state.dailyStatuses[matchIndex].employee;
      if (emp.isSeparatedNow) {
        final exitDisplay = formatDisplayDate(
          emp.normalizedExitDate!,
          includeTodayBadge: false,
        );
        state = state.copyWith(
          authSession: state.authSession.copyWith(
            isAuthenticated: false,
            errorMessage: () =>
                'Personel #${emp.cardNo} için $exitDisplay tarihli işten ayrılış kaydı bulunduğu için oturum açılamaz.',
          ),
        );
        return false;
      }
      final expectedPassword =
          emp.password.trim().isNotEmpty ? emp.password.trim() : fallbackPin;

      // [DB-04] Tuzlanmış PBKDF2/Argon2id hash doğrulaması
      final isPasswordValid =
          HasibuSecurityService.verifyPassword(pin.trim(), expectedPassword) ||
              HasibuSecurityService.verifyPassword(pin.trim(), fallbackPin);

      if (isPasswordValid) {
        final modules = HasibuModule.filterActive(emp.allowedModules);
        final hasAdminLikeModule = modules.any(
          (m) => m != HasibuModule.employeePortal,
        );
        HasibuSecurityService.setFlagSecureEnabled(hasAdminLikeModule);
        state = state.copyWith(
          authSession: AuthSession(
            isAuthenticated: true,
            username: emp.cardNo,
            displayName: emp.fullName,
            role: UserRole.employee,
            employeeCardNo: emp.cardNo,
            allowedModules: modules,
          ),
          activeSelfServiceCardNo: emp.cardNo,
          activeModule: modules.first,
        );
        return true;
      }
    }

    state = state.copyWith(
      authSession: state.authSession.copyWith(
        isAuthenticated: false,
        errorMessage: () =>
            'Personel Kart No (#$normalizedCard) veya kişisel parola hatalı.',
      ),
    );
    return false;
  }

  /// Oturumu kapatır ve Giriş (Login) ekranına döner.
  void logout() {
    HasibuSecurityService.setFlagSecureEnabled(false);
    state = state.copyWith(
      authSession: const AuthSession(isAuthenticated: false),
      activeModule: HasibuModule.pdksHr,
    );
  }

  /// Üst modül seçme satırından aktif modülü değiştirir (faz & yetki kontrolü ile).
  void selectModule(HasibuModule module) {
    if (!module.isEnabledInCurrentPhase ||
        !state.authSession.canAccess(module)) {
      return;
    }
    HasibuSecurityService.setFlagSecureEnabled(
      module != HasibuModule.employeePortal,
    );
    state = state.copyWith(activeModule: module);
  }

  void refreshDashboard() {
    final companySettings = _db.getCompanySettings();
    final branches = _db.getBranches();
    final shifts = _db.getShifts();
    final departments = _db.getDepartments();
    _db.ensureEmployeesForUnregisteredLogCards();
    final employees = _db.getEmployees();
    final logs = _db.getAttendanceLogsForDate(state.selectedDate);
    final leaves = _db.getLeaveRecordsForDate(state.selectedDate);
    final allLeaves = _db.getAllLeaveRecords();
    final allDocs = _db.getAllPersonnelDocuments();
    final allRequests = _db.getAllHrRequests();
    final appUsers = _db.getAppUsers();
    final tamperedLogs = _db.getTamperedAttendanceLogs();
    final auditLogs = _db.getAuditLogs(limit: 200);

    // [LIC-04] Monotonik Saat Kalkanı Kontrolü
    final clockCheck = _db.evaluateMonotonicClockShield();
    // [LIC-03] Ed25519 Lisans ve Donanım Kimliği Kontrolü
    final activeEmployeeCount =
        employees.where((e) => !e.isSeparatedNow).length;
    final licenseCheck = LicenseGuardService.verifyLicenseTokenSync(
      companySettings.licenseToken,
      expectedHwId: companySettings.hardwareFingerprint,
      currentEmployeeCount: activeEmployeeCount,
      currentBranchCount: branches.length,
    );

    final isClockTampered = clockCheck.isClockTampered;
    final isSubscriptionLocked = licenseCheck.isReadOnlyLocked;
    final String licenseMessage = isClockTampered
        ? clockCheck.reason
        : licenseCheck.reason;

    final branchMap = {for (final b in branches) b.id: b};
    final deptMap = {for (final d in departments) d.id: d};
    final shiftMap = {for (final s in shifts) s.id: s};
    final leaveMap = {for (final l in leaves) l.employeeId: l};

    final logsByCard = <String, List<AttendanceLog>>{};
    for (final log in logs) {
      logsByCard.putIfAbsent(log.cardNo, () => <AttendanceLog>[]).add(log);
    }

    final statuses = <EmployeeDailyStatus>[];
    for (final emp in employees) {
      final branch = branchMap[emp.branchId] ??
          (branches.isNotEmpty
              ? branches.first
              : WorkplaceSeedData.branches.first);
      final dept = deptMap[emp.departmentId] ??
          const Department(id: 1, name: 'GENEL', branchId: 1);
      final shift = shiftMap[emp.shiftId] ??
          (shifts.isNotEmpty ? shifts.first : WorkplaceSeedData.shifts.first);
      final empLogs = logsByCard[emp.cardNo] ?? const <AttendanceLog>[];
      final leave = leaveMap[emp.id];

      final eval = _evaluateDayLogs(
        rawDayLogs: empLogs,
        shift: shift,
        leave: leave,
        employee: emp,
        dateKey: state.selectedDate,
      );

      statuses.add(
        EmployeeDailyStatus(
          employee: emp,
          department: dept,
          branch: branch,
          shift: shift,
          state: eval.state,
          firstCheckIn: eval.firstIn,
          lastCheckOut: eval.lastOut,
          allLogsOfDay: empLogs,
          leaveRecord: leave,
          lateMinutes: eval.lateMinutes,
          workedMinutes: eval.workedMinutes,
          overtimeMinutes: eval.overtimeMinutes,
          earlyLeaveMinutes: eval.earlyLeaveMinutes,
          hasMissingCheckOut: eval.hasMissingCheckOut,
          duplicateScansFiltered: eval.duplicateScansFiltered,
        ),
      );
    }

    final currentSync = state.syncStatus;
    final DriveSyncStatus updatedSyncStatus = currentSync.copyWith(
      connectedGmail: companySettings.syncGmailAccount.trim(),
      cloudProfileId: companySettings.cloudProfileId,
    );

    state = state.copyWith(
      companySettings: companySettings,
      autoPollEnabled: companySettings.autoPollEnabled,
      autoPollMinutes: companySettings.autoPollMinutes,
      branches: branches,
      shifts: shifts,
      departments: departments,
      dailyStatuses: statuses,
      allLeaveRecords: allLeaves,
      allPersonnelDocuments: allDocs,
      allHrRequests: allRequests,
      appUsers: appUsers,
      syncStatus: updatedSyncStatus,
      isReadOnlySubscriptionLocked: isSubscriptionLocked,
      isClockTampered: isClockTampered,
      licenseStatusMessage: licenseMessage,
      tamperedAttendanceLogs: tamperedLogs,
      auditLogs: auditLogs,
    );
  }

  /// Anti-Passback (15 dk mükerrer okuma filtresi) + Fazla Mesai / Erken Çıkış / Eksik Çıkış motoru.
  static ({
    DailyAttendanceState state,
    AttendanceLog? firstIn,
    AttendanceLog? lastOut,
    int lateMinutes,
    int workedMinutes,
    int overtimeMinutes,
    int earlyLeaveMinutes,
    bool hasMissingCheckOut,
    int duplicateScansFiltered,
  }) _evaluateDayLogs({
    required List<AttendanceLog> rawDayLogs,
    required ShiftPlan shift,
    required LeaveRecord? leave,
    Employee? employee,
    String? dateKey,
  }) {
    if (rawDayLogs.isEmpty) {
      final DailyAttendanceState st;
      if (leave != null && leave.leaveType != LeaveType.devamsiz) {
        if (leave.leaveType == LeaveType.saglikRaporu) {
          st = DailyAttendanceState.sickReport;
        } else {
          st = DailyAttendanceState.onLeave;
        }
      } else if (employee != null &&
          dateKey != null &&
          employee.isTerminatedOn(dateKey)) {
        st = DailyAttendanceState.terminated;
      } else if (employee != null &&
          dateKey != null &&
          employee.isBeforeHireDate(dateKey)) {
        st = DailyAttendanceState.notYetHired;
      } else {
        st = DailyAttendanceState.absent;
      }
      return (
        state: st,
        firstIn: null,
        lastOut: null,
        lateMinutes: 0,
        workedMinutes: 0,
        overtimeMinutes: 0,
        earlyLeaveMinutes: 0,
        hasMissingCheckOut: false,
        duplicateScansFiltered: 0,
      );
    }

    final sorted = List<AttendanceLog>.from(rawDayLogs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 15 dakika içerisindeki aynı yönlü veya ardışık mükerrer okumaları filtrele (Anti-Passback Debounce)
    final debounced = <AttendanceLog>[];
    int duplicatesFiltered = 0;
    for (final log in sorted) {
      if (debounced.isEmpty) {
        debounced.add(log);
        continue;
      }
      final prev = debounced.last;
      final diffMins = log.timestamp.difference(prev.timestamp).inMinutes.abs();
      if (diffMins < 15 && log.isCheckIn == prev.isCheckIn) {
        duplicatesFiltered++;
        continue;
      }
      debounced.add(log);
    }

    final explicitIns =
        debounced.where((l) => l.isCheckIn).toList(growable: false);
    final explicitOuts =
        debounced.where((l) => !l.isCheckIn).toList(growable: false);

    final AttendanceLog firstIn =
        explicitIns.isNotEmpty ? explicitIns.first : debounced.first;

    AttendanceLog? lastOut;
    if (explicitOuts.isNotEmpty) {
      final candidate = explicitOuts.last;
      if (candidate.id != firstIn.id &&
          candidate.timestamp.isAfter(firstIn.timestamp)) {
        lastOut = candidate;
      }
    } else if (debounced.length > 1) {
      final candidate = debounced.last;
      if (candidate.id != firstIn.id &&
          candidate.timestamp.difference(firstIn.timestamp).inMinutes >= 30) {
        lastOut = candidate;
      }
    }

    final int lateMins = _calculateLateMinutes(
      firstIn.timestamp,
      shift.startTime,
      shift.toleranceMinutes,
    );
    final DailyAttendanceState dailyState = lateMins > 0
        ? DailyAttendanceState.late
        : DailyAttendanceState.present;

    int workedMins = 0;
    int overtimeMins = 0;
    int earlyLeaveMins = 0;
    final bool missingOut = lastOut == null;

    if (lastOut != null) {
      workedMins =
          lastOut.timestamp.difference(firstIn.timestamp).inMinutes.clamp(0, 1440);

      final endParts = shift.endTime.split(':');
      final int eh = int.tryParse(endParts[0]) ?? 18;
      final int em = endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0;
      DateTime shiftEnd = DateTime(
        firstIn.timestamp.year,
        firstIn.timestamp.month,
        firstIn.timestamp.day,
        eh,
        em,
      );
      // Gece vardiyası (örn. 19:00 -> 07:00) için bitiş ertesi gündür
      final startParts = shift.startTime.split(':');
      final int sh = int.tryParse(startParts[0]) ?? 8;
      if (eh < sh) {
        shiftEnd = shiftEnd.add(const Duration(days: 1));
      }

      final outDiff = lastOut.timestamp.difference(shiftEnd).inMinutes;
      if (outDiff >= 15) {
        overtimeMins = outDiff;
      } else if (outDiff < -shift.toleranceMinutes) {
        earlyLeaveMins = (-outDiff);
      }
    }

    return (
      state: dailyState,
      firstIn: firstIn,
      lastOut: lastOut,
      lateMinutes: lateMins,
      workedMinutes: workedMins,
      overtimeMinutes: overtimeMins,
      earlyLeaveMinutes: earlyLeaveMins,
      hasMissingCheckOut: missingOut,
      duplicateScansFiltered: duplicatesFiltered,
    );
  }

  static int _calculateLateMinutes(
    DateTime checkIn,
    String shiftStartHhMm,
    int toleranceMinutes,
  ) {
    final parts = shiftStartHhMm.split(':');
    final int sh = int.tryParse(parts[0]) ?? 6;
    final int sm = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final shiftStart = DateTime(
      checkIn.year,
      checkIn.month,
      checkIn.day,
      sh,
      sm,
    );
    final diff = checkIn.difference(shiftStart).inMinutes;
    if (diff <= toleranceMinutes) return 0;
    return diff;
  }

  void setSelectedDate(String dateKey) {
    state = state.copyWith(selectedDate: dateKey);
    refreshDashboard();
  }

  void shiftSelectedDateByDays(int deltaDays) {
    final current =
        DateTime.tryParse(state.selectedDate) ?? DateTime(2026, 10, 19);
    final shifted = current.add(Duration(days: deltaDays));
    final nextKey =
        '${shifted.year.toString().padLeft(4, '0')}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
    setSelectedDate(nextKey);
  }

  void setBranchFilter(int? branchId) {
    state = state.copyWith(selectedBranchId: () => branchId);
  }

  void setStateFilter(DailyAttendanceState? filter) {
    state = state.copyWith(selectedStateFilter: () => filter);
  }

  void setAnomalyFilter(PdksAnomalyFilter filter) {
    state = state.copyWith(selectedAnomalyFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelfServiceEmployee(String cardNo) {
    state = state.copyWith(activeSelfServiceCardNo: cardNo);
  }

  Future<void> updateCompanySettings(CompanySettings newSettings) async {
    _db.saveCompanySettings(newSettings);
    refreshDashboard();
    _configureAutoPollTimer();
    _configureAutoCloudBackupTimer();
    await _pushAutoBackupOnChange(
      'Hasibu Ayarlar (${newSettings.companyName})',
      force: false,
    );
  }

  void toggleAutoPoll(bool enabled) {
    final updated = state.companySettings.copyWith(autoPollEnabled: enabled);
    _db.saveCompanySettings(updated);
    state = state.copyWith(
      companySettings: updated,
      autoPollEnabled: enabled,
      terminalStatusMessage: enabled
          ? 'Otomatik Tenfei D35 veri çekimi aktif (Her ${updated.autoPollMinutes} dk)'
          : 'Otomatik Tenfei D35 veri çekimi duraklatıldı',
    );
    _configureAutoPollTimer();
  }

  void _configureAutoPollTimer() {
    _autoPollTimer?.cancel();
    _autoPollTimer = null;
    if (!state.autoPollEnabled) return;

    _autoPollTimer = Timer.periodic(
      Duration(minutes: state.autoPollMinutes.clamp(1, 1440)),
      (_) => pullFromTenfeiTerminals(),
    );
  }

  void _configureAutoCloudBackupTimer() {
    _autoCloudBackupTimer?.cancel();
    _autoCloudBackupTimer = null;
    if (!state.companySettings.autoCloudBackupEnabled) return;

    _autoCloudBackupTimer = Timer.periodic(
      Duration(
        minutes: state.companySettings.autoCloudBackupMinutes.clamp(5, 1440),
      ),
      (_) => unawaited(runAutomaticCloudBackup()),
    );
  }

  /// Zamanlayıcı tarafından tetiklenen periyodik otomatik bulut yedeklemesi.
  Future<DriveSyncStatus> runAutomaticCloudBackup() async {
    if (!mounted ||
        state.isCommercialWriteLocked ||
        state.isCloudBusy ||
        !state.companySettings.autoCloudBackupEnabled) {
      return state.syncStatus;
    }
    try {
      final isEmployeePortal = state.authSession.role == UserRole.employee;
      final status = await _syncService.pushToCloud(
        deviceName: 'Hasibu Otomatik Bulut Yedekleme',
        force: false,
        isEmployeePortalOnly: isEmployeePortal,
        employeeCardNo: state.authSession.employeeCardNo,
        operationLabel: 'auto_backup',
      );
      if (mounted) {
        state = state.copyWith(syncStatus: status);
      }
      return status;
    } catch (e) {
      debugPrint('Otomatik bulut yedekleme uyarısı: $e');
      return state.syncStatus;
    }
  }

  Future<void> _pushAutoBackupOnChange(
    String deviceName, {
    bool force = true,
    bool isEmployeePortalOnly = false,
    String? employeeCardNo,
  }) async {
    if (!mounted ||
        state.isCommercialWriteLocked ||
        !state.companySettings.autoCloudBackupEnabled ||
        !state.companySettings.autoCloudBackupOnChange) {
      return;
    }
    try {
      final result = await _syncService.pushToCloud(
        deviceName: deviceName,
        force: force,
        isEmployeePortalOnly: isEmployeePortalOnly,
        employeeCardNo: employeeCardNo,
        operationLabel: 'auto_backup',
      );
      if (mounted) {
        state = state.copyWith(syncStatus: result);
      }
    } catch (e) {
      debugPrint('$deviceName bulut senkronizasyon uyarısı: $e');
    }
  }

  /// Doğrudan Tenfei D35 (192.168.9.150:4370 ve aktif şube terminalleri) üzerinden
  /// TCP 4370 protokolüyle giriş-çıkış kayıtlarını çeker, Google Drive'a yedekler ve özet rapor döndürür.
  Future<TerminalPullSummary?> pullFromTenfeiTerminals({
    int? onlyBranchId,
  }) async {
    // [LIC-05] Salt-Okunur (Read-Only) Abonelik Sonu / Saat Manipülasyonu Kilidi
    if (state.isCommercialWriteLocked) {
      state = state.copyWith(
        isPollingTerminal: false,
        terminalStatusMessage:
            'KİLİTLİ (Salt-Okunur Mod): ${state.licenseStatusMessage} — Tenfei D35 veri çekimi durduruldu.',
      );
      return null;
    }
    if (state.isPollingTerminal) return null;
    state = state.copyWith(
      isPollingTerminal: true,
      terminalStatusMessage:
          'Tenfei D35 terminallerine (TCP 4370) bağlanılıyor...',
    );

    final targetBranches = state.branches.where((b) {
      if (onlyBranchId != null) return b.id == onlyBranchId;
      return b.hasTerminal && (b.terminalIp?.isNotEmpty ?? false);
    }).toList(growable: false);

    int totalFetched = 0;
    int newInserted = 0;
    int syncedEmployees = 0;
    int reachableCount = 0;
    bool anyReachable = false;
    String? latestPulledDateKey;
    final messages = <String>[];

    for (final branch in targetBranches) {
      final ip = (branch.terminalIp ?? '').trim();
      if (ip.isEmpty) {
        messages.add('${branch.name}: Terminal IP adresi tanımlanmamış.');
        continue;
      }
      // [HW-02] Şubenin şifreli `terminalCommKey` anahtarıyla bağlan
      final client = TenfeiZkClient.forBranch(branch);
      final branchPulledLogs = <AttendanceLog>[];

      try {
        final logs = await client.fetchAttendanceLogs();
        anyReachable = true;
        reachableCount++;
        totalFetched += logs.length;
        branchPulledLogs.addAll(logs);
        final insertedForBranch = _db.upsertAttendanceLogsBatch(logs);
        newInserted += insertedForBranch;
        for (final l in logs) {
          if (latestPulledDateKey == null ||
              l.dateKey.compareTo(latestPulledDateKey) > 0) {
            latestPulledDateKey = l.dateKey;
          }
        }
        messages.add(
          '${branch.name} ($ip:${branch.terminalPort} + LAN Köprüsü): ${logs.length} hareket okundu ($insertedForBranch yeni kayıt eklendi)',
        );
      } catch (_) {
        final fallbackLogs = await client.fetchLanPersonel2020BridgeLogs();
        if (fallbackLogs.isNotEmpty) {
          anyReachable = true;
          reachableCount++;
          totalFetched += fallbackLogs.length;
          branchPulledLogs.addAll(fallbackLogs);
          final insertedForBranch = _db.upsertAttendanceLogsBatch(fallbackLogs);
          newInserted += insertedForBranch;
          for (final l in fallbackLogs) {
            if (latestPulledDateKey == null ||
                l.dateKey.compareTo(latestPulledDateKey) > 0) {
              latestPulledDateKey = l.dateKey;
            }
          }
          messages.add(
            '${branch.name} (LAN personel2020 Köprüsü): ${fallbackLogs.length} hareket kurtarıldı ($insertedForBranch yeni kayıt eklendi)',
          );
        } else {
          messages.add(
            '${branch.name} ($ip:${branch.terminalPort}): Cihaza ulaşılamadı',
          );
        }
      }

      // Katman 1: LAN personel2020 üzerinden canlı kadro & bölüm eşitleme
      bool lanDirLoaded = false;
      try {
        final dir = await client.fetchLanPersonel2020Directory(
          defaultBranchId: branch.id,
        );
        if (dir.departments.isNotEmpty) {
          _db.upsertMissingDepartments(dir.departments);
        }
        if (dir.employees.isNotEmpty) {
          lanDirLoaded = true;
          syncedEmployees += _db.syncEmployeesFromDeviceOrBridge(dir.employees);
        }
        if (dir.exitedCardDates.isNotEmpty) {
          syncedEmployees += _db.applyExternalExitDates(dir.exitedCardDates);
        }
      } catch (e) {
        debugPrint('LAN personel2020 kadro eşitleme uyarısı: $e');
      }

      // Katman 2: Tenfei D35 cihaz içi kullanıcı rehberi (CMD_USERTEMP_RRQ)
      try {
        final deviceUsers = await client.fetchDeviceUsers();
        if (deviceUsers.isNotEmpty) {
          final currentEmployees = _db.getEmployees();
          final existingEmpCards =
              currentEmployees.map((e) => e.cardNo).toSet();
          final placeholderCards = currentEmployees
              .where((e) => e.fullName.startsWith('PERSONEL #'))
              .map((e) => e.cardNo)
              .toSet();
          final logCards = branchPulledLogs.map((l) => l.cardNo).toSet();

          final List<TenfeiDeviceUser> targetUsers;
          if (!lanDirLoaded) {
            targetUsers = existingEmpCards.isEmpty
                ? deviceUsers
                : deviceUsers
                    .where(
                      (u) =>
                          logCards.contains(u.cardNo) ||
                          !existingEmpCards.contains(u.cardNo) ||
                          placeholderCards.contains(u.cardNo),
                    )
                    .toList(growable: false);
          } else {
            targetUsers = deviceUsers
                .where(
                  (u) =>
                      logCards.contains(u.cardNo) &&
                      (!existingEmpCards.contains(u.cardNo) ||
                          placeholderCards.contains(u.cardNo)),
                )
                .toList(growable: false);
          }

          if (targetUsers.isNotEmpty) {
            final todayKeyStr = todayDateKey();
            final mapped = targetUsers
                .map(
                  (u) => Employee(
                    id: 0,
                    cardNo: u.cardNo,
                    fullName: u.fullName,
                    title: 'YÜZ TANIMA CİHAZI',
                    departmentId: branch.id == 1 ? 31 : branch.id,
                    branchId: branch.id,
                    shiftId: branch.id == 1 ? 1 : 3,
                    hireDate: todayKeyStr,
                  ),
                )
                .toList(growable: false);
            syncedEmployees += _db.syncEmployeesFromDeviceOrBridge(mapped);
          }
        }
      } catch (e) {
        debugPrint('Tenfei D35 kullanıcı rehberi çekme uyarısı: $e');
      } finally {
        await client.dispose();
      }
    }

    // Katman 3: Hareketlerde geçip hâlâ kaydı olmayan kartları yer tutucu olarak ekle
    syncedEmployees += _db.ensureEmployeesForUnregisteredLogCards();
    if (syncedEmployees > 0) {
      messages.add('+$syncedEmployees personel kadrosu eşitlendi');
    }

    final todayKey = todayDateKey();
    if (latestPulledDateKey == todayKey && state.selectedDate != todayKey) {
      state = state.copyWith(selectedDate: todayKey);
    }

    refreshDashboard();
    final logsForSelectedDate =
        _db.getAttendanceLogsForDate(state.selectedDate).length;
    await _pushAutoBackupOnChange(
      'Hasibu Masaüstü (Tenfei D35 Köprüsü)',
      force: false,
    );

    state = state.copyWith(
      isPollingTerminal: false,
      lastTerminalReachable: () => anyReachable,
      terminalStatusMessage: messages.isEmpty
          ? 'Aktif terminal tanımlı değil.'
          : '${messages.join(' | ')} ($newInserted yeni, toplam $totalFetched)',
    );

    return TerminalPullSummary(
      anyReachable: anyReachable,
      targetTerminalCount: targetBranches.length,
      reachableTerminalCount: reachableCount,
      totalFetched: totalFetched,
      newInserted: newInserted,
      logsCountForSelectedDate: logsForSelectedDate,
      selectedDateAfterPull: state.selectedDate,
      latestPulledDateKey: latestPulledDateKey,
      branchMessages: messages,
      pulledAt: DateTime.now(),
    );
  }

  /// Tüm aktif terminallerde TCP 4370 + ZKTeco CMD_AUTH bağlantı kontrolünü çalıştırır.
  Future<List<TenfeiConnectionDiagnostics>> testAllTerminalsConnection() async {
    final targetBranches = state.branches
        .where((b) => b.hasTerminal && (b.terminalIp?.isNotEmpty ?? false))
        .toList(growable: false);
    if (targetBranches.isEmpty && state.branches.isNotEmpty) {
      final firstDiag =
          await testBranchTerminalConnection(state.branches.first);
      state = state.copyWith(
        lastTerminalReachable: () => firstDiag.isReachable,
        terminalStatusMessage: firstDiag.message,
      );
      return <TenfeiConnectionDiagnostics>[firstDiag];
    }

    final results = <TenfeiConnectionDiagnostics>[];
    bool anyReachable = false;
    for (final b in targetBranches) {
      final diag = await testBranchTerminalConnection(b);
      if (diag.isReachable) anyReachable = true;
      results.add(diag);
    }
    state = state.copyWith(
      lastTerminalReachable: () => anyReachable,
      terminalStatusMessage: results.isEmpty
          ? 'Test edilecek terminal bulunamadı.'
          : results.map((r) => r.message).join(' | '),
    );
    return results;
  }

  Future<TenfeiConnectionDiagnostics> testBranchTerminalConnection(
    Branch branch,
  ) async {
    final ip = (branch.terminalIp ?? '').trim();
    if (ip.isEmpty) {
      return const TenfeiConnectionDiagnostics(
        isReachable: false,
        latencyMs: 0,
        message: 'Terminal IP adresi boş.',
      );
    }
    // [HW-02] Şubenin şifreli `terminalCommKey` anahtarıyla bağlan
    final client = TenfeiZkClient.forBranch(branch);
    try {
      final diag = await client.testConnection();
      state = state.copyWith(
        lastTerminalReachable: () => diag.isReachable,
        terminalStatusMessage: diag.message,
      );
      return diag;
    } finally {
      await client.dispose();
    }
  }

  /// Şube veya Cihaz ekler / günceller.
  Future<void> saveBranch(Branch branch) async {
    _db.upsertBranch(branch);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Şube/Cihaz Yönetimi');
  }

  Future<void> deleteBranch(int branchId) async {
    _db.deleteBranch(branchId);
    if (state.selectedBranchId == branchId) {
      state = state.copyWith(selectedBranchId: () => null);
    }
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Şube/Cihaz Yönetimi');
  }

  /// Vardiya / Mesai Saat Aralığı ve Geç Kalma Toleransını ekler veya günceller.
  Future<void> saveShiftPlan(ShiftPlan shift) async {
    _db.upsertShift(shift);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Vardiya Yönetimi');
  }

  Future<void> deleteShiftPlan(int shiftId) async {
    _db.deleteShift(shiftId);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Vardiya Yönetimi');
  }

  /// Departman / Üretim Bölümü ekler veya günceller.
  Future<void> saveDepartment(Department dept) async {
    _db.upsertDepartment(dept);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Bölüm Yönetimi');
  }

  /// Personel ekler veya mevcut personelin bilgilerini günceller.
  Future<void> saveEmployee(Employee employee) async {
    Employee? previous;
    for (final s in state.dailyStatuses) {
      if (s.employee.id == employee.id) {
        previous = s.employee;
        break;
      }
    }
    _db.upsertEmployee(employee);
    if (previous == null ||
        previous.hireDate != employee.hireDate ||
        previous.normalizedExitDate != employee.normalizedExitDate) {
      final actor = state.authSession.username.isEmpty
          ? 'admin'
          : state.authSession.username;
      _db.appendAuditLog(
        actorEmployeeId: actor,
        actionType: 'EMPLOYEE_EMPLOYMENT_DATES_UPDATED',
        targetRecordId: employee.cardNo.trim().padLeft(5, '0'),
        oldValue: previous == null
            ? 'NEW_EMPLOYEE'
            : 'hireDate=${previous.hireDate}, exitDate=${previous.normalizedExitDate ?? "AKTIF"}',
        newValue:
            'hireDate=${employee.hireDate}, exitDate=${employee.normalizedExitDate ?? "AKTIF"}',
      );
    }
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Personel Yönetimi');
  }

  Future<void> deleteEmployee(int employeeId) async {
    _db.deleteEmployee(employeeId);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Personel Yönetimi');
  }

  /// Personel hareketini (Giriş veya Çıkış saatini) manuel ekler veya düzeltir.
  Future<void> saveOrUpdateAttendanceLog({
    String? existingLogId,
    required Employee employee,
    required String dateKey, // YYYY-MM-DD
    required String timeHhMm, // HH:mm
    required bool isCheckIn,
    AttendanceSource source = AttendanceSource.manual,
    VerifyMethod verifyMethod = VerifyMethod.face,
  }) async {
    final dParts = dateKey.split('-');
    final tParts = timeHhMm.split(':');
    final dt = DateTime(
      int.tryParse(dParts[0]) ?? 2026,
      dParts.length > 1 ? (int.tryParse(dParts[1]) ?? 1) : 1,
      dParts.length > 2 ? (int.tryParse(dParts[2]) ?? 1) : 1,
      int.tryParse(tParts[0]) ?? 8,
      tParts.length > 1 ? (int.tryParse(tParts[1]) ?? 0) : 0,
    );

    final String logId = existingLogId ??
        '${employee.branchId}_${employee.cardNo}_${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}_${isCheckIn ? "IN" : "OUT"}';

    final log = AttendanceLog(
      id: logId,
      cardNo: employee.cardNo,
      branchId: employee.branchId,
      deviceNo: 1,
      timestamp: dt,
      isCheckIn: isCheckIn,
      source: source,
      verifyMethod: verifyMethod,
    );

    _db.upsertAttendanceLog(log);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Hareket Düzeltme');
  }

  Future<void> deleteAttendanceLog(String logId) async {
    _db.deleteAttendanceLog(logId);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Hareket Düzeltme');
  }

  /// Çoklu personel seçimiyle toplu giriş ve/veya çıkış saati uygular.
  Future<int> saveBulkManualAttendance({
    required List<Employee> employees,
    required String dateKey,
    String? checkInTime,
    String? checkOutTime,
    bool replaceExistingForDay = true,
  }) async {
    final affected = _db.applyBulkManualAttendance(
      employees: employees,
      dateKey: dateKey,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      replaceExistingForDay: replaceExistingForDay,
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Toplu Hareket Düzeltme');
    return affected;
  }

  /// Google (Gmail) bulut eşitleme hesabını, yerel Drive klasörünü ve varsa OAuth anahtarını doğrular ve kaydeder.
  Future<DriveSyncStatus> saveGmailSyncAccount({
    required String gmailAccount,
    required String syncFolderPath,
    String? accessToken,
  }) async {
    String cleanGmail = gmailAccount.trim();
    if (cleanGmail.isNotEmpty && !cleanGmail.contains('@')) {
      cleanGmail = '$cleanGmail@gmail.com';
    }
    String cleanFolder = syncFolderPath.trim();
    if (cleanFolder.isEmpty) {
      cleanFolder = GoogleDriveSyncService.detectDefaultGoogleDrivePath();
    }

    if (accessToken != null) {
      final cleanToken = accessToken.trim();
      if (cleanToken.isEmpty) {
        try {
          await _syncService.clearTokens();
        } catch (e) {
          debugPrint('PdksProviders: clearTokens uyarısı: $e');
          state = state.copyWith(
            syncStatus: state.syncStatus.copyWith(message: 'Token temizleme uyarısı: $e'),
          );
        }
      } else {
        state = state.copyWith(
          syncStatus: state.syncStatus.copyWith(
            stage: DriveSyncStage.syncing,
            message: 'Google OAuth 2.0 erişim anahtarı doğrulanıyor...',
          ),
        );
        final verification =
            await _syncService.verifyGoogleAccessToken(cleanToken);
        if (!verification.isValid) {
          final errStatus = DriveSyncStatus(
            stage: DriveSyncStage.error,
            lastSyncTime: DateTime.now(),
            connectedGmail: cleanGmail,
            isCloudApiVerified: false,
            isDriveFolderMirrored: false,
            message: verification.errorMessage,
          );
          state = state.copyWith(syncStatus: errStatus);
          return errStatus;
        }
        if (verification.email.isNotEmpty) {
          cleanGmail = verification.email;
        }
        try {
          await _syncService.saveOAuthTokens(accessToken: cleanToken);
        } catch (e) {
          debugPrint('PdksProviders: saveOAuthTokens uyarısı: $e');
          state = state.copyWith(
            syncStatus: state.syncStatus.copyWith(message: 'Token saklama uyarısı: $e'),
          );
        }
      }
    }

    final updated = state.companySettings.copyWith(
      syncGmailAccount: cleanGmail,
      syncFolderPath: cleanFolder,
    );
    _db.saveCompanySettings(updated);
    refreshDashboard();
    await syncWithGoogleDriveNow();
    return state.syncStatus;
  }

  /// Platforma uygun Google OAuth 2.0 akışını (Masaüstünde Edge PKCE, Mobilde Google Sign-In) başlatır.
  /// `authenticateAppSession` true ise doğrulanmış Google e-postası ile Hasibu oturumunu da açar.
  Future<BrowserGoogleSignInResult> signInWithGoogleViaBrowser({
    String? emailHint,
    String? customClientId,
    String? customClientSecret,
    String? syncFolderPath,
    bool authenticateAppSession = false,
  }) async {
    state = state.copyWith(
      syncStatus: state.syncStatus.copyWith(
        stage: DriveSyncStage.syncing,
        message: _googleAuthAdapter.isNativePlatform
            ? 'Google oturumu açılıyor, cihaz onayı bekleniyor...'
            : 'Edge tarayıcıda Google OAuth 2.0 oturumu açıldı, onay bekleniyor...',
      ),
    );

    final result = await _googleAuthAdapter.signIn(
      loginHintEmail: emailHint,
      customClientId: customClientId,
      customClientSecret: customClientSecret,
    );

    if (!result.success) {
      state = state.copyWith(
        syncStatus: state.syncStatus.copyWith(
          stage: DriveSyncStage.error,
          message: result.message,
        ),
        authSession: authenticateAppSession
            ? state.authSession.copyWith(
                isAuthenticated: false,
                errorMessage: () => result.message,
              )
            : state.authSession,
      );
      return result;
    }

    if (result.accessToken.trim().isNotEmpty) {
      try {
        await _syncService.saveOAuthTokens(
          accessToken: result.accessToken,
          refreshToken:
              result.refreshToken.trim().isEmpty ? null : result.refreshToken,
        );
      } catch (e) {
        debugPrint('PdksProviders: saveOAuthTokens oturum uyarısı: $e');
        state = state.copyWith(
          syncStatus:
              state.syncStatus.copyWith(message: 'OAuth token saklama hatası: $e'),
        );
      }
    }

    final resolvedGmail = result.email.isNotEmpty
        ? result.email
        : (emailHint?.trim() ?? state.companySettings.syncGmailAccount);
    final resolvedFolder = (syncFolderPath != null &&
            syncFolderPath.trim().isNotEmpty)
        ? syncFolderPath.trim()
        : (state.companySettings.syncFolderPath.isNotEmpty
            ? state.companySettings.syncFolderPath
            : GoogleDriveSyncService.detectDefaultGoogleDrivePath());

    final updated = state.companySettings.copyWith(
      syncGmailAccount: resolvedGmail,
      syncFolderPath: resolvedFolder,
    );
    _db.saveCompanySettings(updated);
    refreshDashboard();

    if (authenticateAppSession) {
      HasibuSecurityService.setFlagSecureEnabled(true);
      final disp = result.displayName.trim().isNotEmpty
          ? '${result.displayName.trim()} ($resolvedGmail)'
          : (resolvedGmail.isNotEmpty ? resolvedGmail : 'Google Yönetici');
      state = state.copyWith(
        authSession: AuthSession(
          isAuthenticated: true,
          username: resolvedGmail.isNotEmpty ? resolvedGmail : 'google_admin',
          displayName: disp,
          role: UserRole.admin,
          allowedModules: HasibuModule.activePhaseModules,
        ),
        activeModule: HasibuModule.pdksHr,
      );
    }

    await syncWithGoogleDriveNow();
    return result;
  }

  /// Aktif bulut/yerel yedek klasörünü Windows Gezgini'nde (Explorer) açar.
  Future<String> openCloudSyncFolder([String? customFolder]) {
    return _syncService.openSyncFolderInExplorer(customFolder);
  }

  /// Bağlı Google (Gmail) hesabının bağlantısını keser.
  Future<void> disconnectGmailSyncAccount() async {
    final updated = state.companySettings.copyWith(
      syncGmailAccount: '',
    );
    _db.saveCompanySettings(updated);
    try {
      await _googleAuthAdapter.signOut();
    } catch (e) {
      debugPrint('PdksProviders: disconnect signOut uyarısı: $e');
    }
    try {
      await _syncService.clearTokens();
    } catch (e) {
      debugPrint('PdksProviders: disconnect clearTokens uyarısı: $e');
      state = state.copyWith(
        syncStatus: state.syncStatus.copyWith(message: 'Token silme uyarısı: $e'),
      );
    }
    refreshDashboard();
    state = state.copyWith(
      syncStatus: const DriveSyncStatus(
        stage: DriveSyncStage.idle,
        connectedGmail: '',
        message: 'Google hesap bağlantısı kaldırıldı.',
      ),
    );
  }

  /// Cihaz olmayan şubelerde (Devteyşti, Yenişehir, Karaköprü) Mobil QR (30sn TOTP) veya
  /// Konum (GPS Geofence + Sahte GPS Kontrolü) doğrulaması ile personel giriş-çıkış kaydı oluşturur.
  Future<String> recordBranchMobileCheckIn({
    required Employee employee,
    required Branch branch,
    required AttendanceSource source,
    required bool isCheckIn,
    double? currentLat,
    double? currentLng,
    String? qrPayload,
    bool isMockedGps = false,
    DateTime? verificationNow,
  }) async {
    // [HW-06] Sahte GPS (position.isMocked) Kontrolü
    if (isMockedGps) {
      final alertMsg =
          'SAHTE GPS ALGILANDI: ${employee.fullName} (#${employee.cardNo}) - ${branch.name} şubesinde sahte konum (Mock Location) ile ${isCheckIn ? "GİRİŞ" : "ÇIKIŞ"} denemesi reddedildi!';
      _db.appendAuditLog(
        actorEmployeeId: employee.cardNo,
        actionType: 'MOCK_GPS_REJECTED',
        targetRecordId: 'branch_${branch.id}_${employee.cardNo}',
        oldValue: 'isMocked=false',
        newValue:
            'isMocked=true (${currentLat?.toStringAsFixed(4) ?? "?"}, ${currentLng?.toStringAsFixed(4) ?? "?"})',
      );
      state = state.copyWith(
        mockGpsAnomalyCount: state.mockGpsAnomalyCount + 1,
        lastMockGpsAlert: () => alertMsg,
        auditLogs: _db.getAuditLogs(limit: 200),
      );
      return alertMsg;
    }

    // [HW-05] Dinamik 30 sn TOTP (HMAC-SHA1) QR Doğrulaması (60 sn üzeri reddedilir)
    if (source == AttendanceSource.mobileQr &&
        qrPayload != null &&
        qrPayload.trim().isNotEmpty) {
      final qrCheck = HasibuSecurityService.verifyDynamicBranchQrPayload(
        qrPayload: qrPayload,
        expectedBranchId: branch.id.toString(),
        qrSecret: branch.qrSecret,
        now: verificationNow,
        maxAgeSeconds: 60,
      );
      if (!qrCheck.isValid) {
        return 'QR Reddedildi: ${qrCheck.reason}';
      }
    }

    if (source == AttendanceSource.mobileGps &&
        currentLat != null &&
        currentLng != null) {
      final double distanceMeters = _haversineMeters(
        branch.latitude,
        branch.longitude,
        currentLat,
        currentLng,
      );
      if (distanceMeters > branch.geofenceRadiusMeters) {
        return 'Konum şube sınırları dışında (${distanceMeters.round()}m > ${branch.geofenceRadiusMeters.round()}m).';
      }
    }

    final now = DateTime.now();
    final dateParts = state.selectedDate.split('-');
    final logTime = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      now.hour,
      now.minute,
      now.second,
    );
    final verifyMethod = source == AttendanceSource.mobileQr
        ? VerifyMethod.mobileQr
        : VerifyMethod.mobileGps;

    final log = AttendanceLog(
      id: '${branch.id}_${employee.cardNo}_${logTime.millisecondsSinceEpoch}',
      cardNo: employee.cardNo,
      branchId: branch.id,
      deviceNo: branch.machineNo,
      timestamp: logTime,
      isCheckIn: isCheckIn,
      source: source,
      verifyMethod: verifyMethod,
      integrityHash: HasibuSecurityService.computeAttendanceIntegrityHash(
        cardNo: employee.cardNo,
        timestamp: logTime,
        isCheckIn: isCheckIn,
        verifyMethod: verifyMethod.name,
      ),
    );

    _db.upsertAttendanceLog(log);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Mobil (${branch.name})');
    return '${employee.fullName} için ${branch.name} şubesinde ${source.label} ile ${isCheckIn ? "GİRİŞ" : "ÇIKIŞ"} kaydedildi.';
  }

  /// Devamsız personeli İzinli (Yıllık, Ücretli, Mazeret) veya Raporlu olarak işaretler
  /// ve Google Drive üzerinden tüm cihazlarla senkronize eder.
  Future<void> assignLeaveOrReport({
    required int employeeId,
    required LeaveType leaveType,
    required String note,
    String? customDateKey,
  }) async {
    final targetDate = customDateKey ?? state.selectedDate;
    final record = LeaveRecord(
      id: 'leave_${employeeId}_$targetDate',
      employeeId: employeeId,
      date: targetDate,
      leaveType: leaveType,
      note: note.trim().isEmpty ? leaveType.label : note.trim(),
    );
    _db.upsertLeaveRecord(record);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu İK Yönetimi');
  }

  /// Başlangıç ve bitiş tarihleri arasındaki tüm günler için toplu izin/rapor kaydı oluşturur.
  Future<int> assignLeaveDateRange({
    required int employeeId,
    required DateTime startDate,
    required DateTime endDate,
    required LeaveType leaveType,
    required String note,
  }) async {
    final DateTime normalizedStart =
        DateTime(startDate.year, startDate.month, startDate.day);
    final DateTime normalizedEnd =
        DateTime(endDate.year, endDate.month, endDate.day);
    if (normalizedEnd.isBefore(normalizedStart)) return 0;

    int daysCount = 0;
    DateTime cursor = normalizedStart;
    while (!cursor.isAfter(normalizedEnd) && daysCount <= 90) {
      final dKey =
          '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      final rec = LeaveRecord(
        id: 'leave_${employeeId}_$dKey',
        employeeId: employeeId,
        date: dKey,
        leaveType: leaveType,
        note: note.trim().isEmpty ? leaveType.label : note.trim(),
      );
      _db.upsertLeaveRecord(rec);
      daysCount++;
      cursor = cursor.add(const Duration(days: 1));
    }

    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu İK İzin/Rapor Yönetimi');
    return daysCount;
  }

  Future<void> deleteLeaveRecord(String leaveId) async {
    _db.deleteLeaveRecord(leaveId);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu İK İzin/Rapor Yönetimi');
  }

  /// Personelin tüm tarihlerdeki giriş-çıkış, geç kalma ve izin/rapor geçmişini kronolojik olarak döndürür.
  List<EmployeeHistoryDayEntry> getEmployeeHistory(Employee emp) {
    final logs = _db.getAttendanceLogsForEmployee(emp.cardNo);
    final leaves = _db.getLeaveRecordsForEmployee(emp.id);
    final shift = state.shifts.firstWhere(
      (s) => s.id == emp.shiftId,
      orElse: () => state.shifts.isNotEmpty
          ? state.shifts.first
          : WorkplaceSeedData.shifts.first,
    );

    final logsByDate = <String, List<AttendanceLog>>{};
    for (final l in logs) {
      logsByDate.putIfAbsent(l.dateKey, () => <AttendanceLog>[]).add(l);
    }
    final leaveByDate = <String, LeaveRecord>{
      for (final lv in leaves) lv.date: lv,
    };

    final allDates = <String>{
      ...logsByDate.keys,
      ...leaveByDate.keys,
      state.selectedDate,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    final entries = <EmployeeHistoryDayEntry>[];
    for (final dKey in allDates) {
      final dayLogs = List<AttendanceLog>.from(
        logsByDate[dKey] ?? const <AttendanceLog>[],
      )..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final lv = leaveByDate[dKey];

      final eval = _evaluateDayLogs(
        rawDayLogs: dayLogs,
        shift: shift,
        leave: lv,
        employee: emp,
        dateKey: dKey,
      );

      entries.add(
        EmployeeHistoryDayEntry(
          dateKey: dKey,
          state: eval.state,
          firstCheckIn: eval.firstIn,
          lastCheckOut: eval.lastOut,
          allLogs: dayLogs,
          leaveRecord: lv,
          lateMinutes: eval.lateMinutes,
          workedMinutes: eval.workedMinutes,
          overtimeMinutes: eval.overtimeMinutes,
          earlyLeaveMinutes: eval.earlyLeaveMinutes,
          hasMissingCheckOut: eval.hasMissingCheckOut,
        ),
      );
    }
    return entries;
  }

  /// Tek tıkla eksik çıkış (Tek Okuma) anomalisini personelin vardiya bitiş saatine göre tamamlar.
  Future<void> quickCompleteMissingCheckOut(EmployeeDailyStatus item) async {
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    await saveOrUpdateAttendanceLog(
      employee: item.employee,
      dateKey: state.selectedDate,
      timeHhMm: item.shift.endTime,
      isCheckIn: false,
      source: AttendanceSource.manual,
      verifyMethod: VerifyMethod.password,
    );
    // [AUD-02] "1-Tıkla Eksik Çıkış Tamamlama" işlemini otomatik olarak audit_logs tablosuna yazdır
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'MISSING_CHECKOUT_COMPLETED',
      targetRecordId: '${item.employee.cardNo}_${state.selectedDate}',
      oldValue: 'lastCheckOut=NULL',
      newValue: 'lastCheckOut=${item.shift.endTime}',
    );
    refreshDashboard();
  }

  /// Seçili tarihte çıkış basmayı unutan tüm personellerin çıkış saatini kendi vardiya bitiş saatlerine göre toplu tamamlar.
  Future<int> batchCompleteAllMissingCheckOuts() async {
    final targets = state.filteredByBranch
        .where((s) => s.hasMissingCheckOut)
        .toList(growable: false);
    if (targets.isEmpty) return 0;

    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;

    final dParts = state.selectedDate.split('-');
    final year = int.tryParse(dParts[0]) ?? 2026;
    final month = dParts.length > 1 ? (int.tryParse(dParts[1]) ?? 10) : 10;
    final day = dParts.length > 2 ? (int.tryParse(dParts[2]) ?? 19) : 19;

    final logsToInsert = <AttendanceLog>[];
    for (final item in targets) {
      final tParts = item.shift.endTime.split(':');
      final h = int.tryParse(tParts[0]) ?? 18;
      final m = tParts.length > 1 ? (int.tryParse(tParts[1]) ?? 0) : 0;
      final dt = DateTime(year, month, day, h, m);
      logsToInsert.add(
        AttendanceLog(
          id: 'AUTO_OUT_${item.employee.cardNo}_${state.selectedDate}_${h.toString().padLeft(2, '0')}${m.toString().padLeft(2, '0')}',
          cardNo: item.employee.cardNo,
          branchId: item.employee.branchId,
          deviceNo: 99,
          timestamp: dt,
          isCheckIn: false,
          source: AttendanceSource.manual,
          verifyMethod: VerifyMethod.password,
          integrityHash: HasibuSecurityService.computeAttendanceIntegrityHash(
            cardNo: item.employee.cardNo,
            timestamp: dt,
            isCheckIn: false,
            verifyMethod: VerifyMethod.password.name,
          ),
        ),
      );
      // [AUD-02] Her tamamlanan eksik çıkış kaydını silinemez audit_logs tablosuna yazdır
      _db.appendAuditLog(
        actorEmployeeId: actor,
        actionType: 'MISSING_CHECKOUT_COMPLETED',
        targetRecordId: '${item.employee.cardNo}_${state.selectedDate}',
        oldValue: 'lastCheckOut=NULL',
        newValue: 'lastCheckOut=${item.shift.endTime} (Toplu)',
      );
    }

    _db.upsertAttendanceLogsBatch(logsToInsert);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Eksik Çıkış Otomasyonu');
    return logsToInsert.length;
  }

  /// Personel Portalı veya İK üzerinden yeni talep (İzin, Fazla Mesai, Eksik Hareket, Avans) oluşturur.
  Future<void> submitHrRequest(HrRequest request) async {
    _db.upsertHrRequest(request);
    refreshDashboard();
    await _pushAutoBackupOnChange(
      'Hasibu Personel Talep Merkezi',
      isEmployeePortalOnly: state.authSession.role == UserRole.employee,
      employeeCardNo: state.authSession.employeeCardNo,
    );
  }

  /// İK Yöneticisi personel talebini Tek Tıkla Onaylar veya Reddeder.
  /// Onaylandığında izin veya unutulan giriş/çıkış hareketi otomatik olarak puantaja işlenir!
  Future<String> reviewHrRequest({
    required HrRequest request,
    required bool approve,
    String? reviewerNote,
  }) async {
    // [LIC-05] Salt-Okunur (Read-Only) Abonelik Sonu / Saat Manipülasyonu Kilidi
    if (state.isCommercialWriteLocked) {
      return 'KİLİTLİ (Salt-Okunur Mod): ${state.licenseStatusMessage} — Yeni İK talebi onaylama devre dışı bırakıldı.';
    }

    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;

    final updated = request.copyWith(
      status: approve ? HrRequestStatus.approved : HrRequestStatus.rejected,
      reviewerNote: () => reviewerNote?.trim().isEmpty == true
          ? (approve ? 'İK tarafından onaylandı ve puantaja işlendi' : 'İK tarafından reddedildi')
          : reviewerNote?.trim(),
    );
    _db.upsertHrRequest(updated);

    // [AUD-02] "İK Talep Onaylama" işlemini otomatik olarak audit_logs tablosuna yazdır
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'HR_REQUEST_REVIEWED',
      targetRecordId: request.id,
      oldValue: 'status=${request.status.name}',
      newValue:
          'status=${updated.status.name} (${request.employeeCardNo} • ${request.type.name})',
    );

    String actionSummary = approve
        ? '${request.employeeName} talebi onaylandı.'
        : '${request.employeeName} talebi reddedildi.';

    if (approve) {
      if (request.type == HrRequestType.annualLeave) {
        final start =
            DateTime.tryParse(request.targetDate) ?? DateTime(2026, 10, 19);
        final end = DateTime.tryParse(request.endDate ?? request.targetDate) ??
            start;
        final days = await assignLeaveDateRange(
          employeeId: request.employeeId,
          startDate: start,
          endDate: end,
          leaveType: request.leaveType,
          note: '${request.leaveType.label} (Talep Onayı: ${request.reason})',
        );
        actionSummary =
            '${request.employeeName} için $days günlük ${request.leaveType.label} onaylandı ve puantaja işlendi.';
      } else if (request.type == HrRequestType.missingPunchCorrection) {
        final empStatus = state.dailyStatuses
            .where((s) => s.employee.id == request.employeeId)
            .toList(growable: false);
        if (empStatus.isNotEmpty) {
          final emp = empStatus.first.employee;
          final timeStr = request.requestedTime ??
              (request.isCheckInCorrection
                  ? empStatus.first.shift.startTime
                  : empStatus.first.shift.endTime);
          await saveOrUpdateAttendanceLog(
            employee: emp,
            dateKey: request.targetDate,
            timeHhMm: timeStr,
            isCheckIn: request.isCheckInCorrection,
            source: AttendanceSource.manual,
            verifyMethod: VerifyMethod.password,
          );
          actionSummary =
              '${request.employeeName} için ${request.targetDate} $timeStr ${request.isCheckInCorrection ? "Giriş" : "Çıkış"} hareketi onaylanıp eklendi.';
        }
      }
    }

    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu İK Onay Merkezi');
    return actionSummary;
  }

  /// 4857 sayılı İş Kanunu Md. 53 uyarınca kıdem yılına göre eksik tanımlanmış yıllık izin haklarını otomatik günceller.
  Future<int> syncStatutoryLeaveEntitlements() async {
    final employees = _db.getEmployees();
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    int updatedCount = 0;
    for (final emp in employees) {
      if (emp.isSeparatedNow) continue;
      if (emp.hasStatutoryLeaveMismatch) {
        final oldVal = emp.annualLeaveEntitlement;
        final newVal = emp.statutoryAnnualLeaveEntitlement;
        _db.upsertEmployee(
          emp.copyWith(
            annualLeaveEntitlement: newVal,
          ),
        );
        // [AUD-02] "Yıllık İzin Hakediş Eşitleme" işlemini otomatik olarak audit_logs tablosuna yazdır
        _db.appendAuditLog(
          actorEmployeeId: actor,
          actionType: 'STATUTORY_LEAVE_SYNCED',
          targetRecordId: emp.cardNo,
          oldValue: 'annualLeaveEntitlement=$oldVal',
          newValue: 'annualLeaveEntitlement=$newVal',
        );
        updatedCount++;
      }
    }
    if (updatedCount > 0) {
      refreshDashboard();
      await _pushAutoBackupOnChange('Hasibu 4857 İzin Hakediş Eşitleme');
    }
    return updatedCount;
  }

  /// Seçili tarihteki resmi PDKS & Puantaj çizelgesini Excel uyumlu (; ayraçlı) CSV metni olarak üretir.
  String generateDailyPuantajCsv({bool onlyVisible = false}) {
    // [LIC-05] Salt-Okunur (Read-Only) Abonelik Sonu Modunda resmi Excel/CSV Puantaj dışa aktarımını kilitle
    if (state.isCommercialWriteLocked) {
      return '';
    }
    final rows =
        onlyVisible ? state.visibleStatuses : state.filteredByBranch;
    final buf = StringBuffer();
    buf.writeln(
      'Tarih;Kart No;Ad Soyad;Şube;Bölüm;Vardiya;İlk Giriş;Son Çıkış;Net Çalışma (Dk);Gecikme (Dk);Fazla Mesai (Dk);Erken Çıkış (Dk);Eksik Çıkış;Durum;Doğrulama',
    );
    for (final item in rows) {
      final inStr = item.firstCheckIn?.timeFormatted ?? '-';
      final outStr = item.lastCheckOut?.timeFormatted ?? '-';
      final verifyStr = item.firstCheckIn?.verifyMethod.label ??
          (item.leaveRecord?.leaveType.label ?? '-');
      buf.writeln(
        '${state.selectedDate};'
        '${item.employee.cardNo};'
        '${item.employee.fullName};'
        '${item.branch.name};'
        '${item.department.name};'
        '${item.shift.startTime}-${item.shift.endTime};'
        '$inStr;'
        '$outStr;'
        '${item.workedMinutes};'
        '${item.lateMinutes};'
        '${item.overtimeMinutes};'
        '${item.earlyLeaveMinutes};'
        '${item.hasMissingCheckOut ? "EVET" : "HAYIR"};'
        '${item.state.label};'
        '$verifyStr',
      );
    }
    return buf.toString();
  }

  /// Seçili tarih aralığı için tüm personellerin devam, geç kalma, izin, rapor ve devamsızlık özetini hesaplar.
  List<EmployeeAttendancePeriodSummary> buildAttendancePeriodReport({
    required String startDateKey,
    required String endDateKey,
    int? branchId,
    int? departmentId,
    String searchQuery = '',
    bool onlyWithAbsences = false,
    bool onlyWithLates = false,
    bool excludeSundays = false,
  }) {
    final parsedStart =
        DateTime.tryParse(startDateKey) ?? DateTime.tryParse(state.selectedDate) ?? DateTime.now();
    final parsedEnd = DateTime.tryParse(endDateKey) ?? parsedStart;
    var rangeStart = DateTime(parsedStart.year, parsedStart.month, parsedStart.day);
    var rangeEnd = DateTime(parsedEnd.year, parsedEnd.month, parsedEnd.day);
    if (rangeStart.isAfter(rangeEnd)) {
      final tmp = rangeStart;
      rangeStart = rangeEnd;
      rangeEnd = tmp;
    }
    if (rangeEnd.difference(rangeStart).inDays > 365) {
      rangeStart = rangeEnd.subtract(const Duration(days: 365));
    }

    final startKey = formatDateKey(rangeStart);
    final endKey = formatDateKey(rangeEnd);

    final employees = _db.getEmployees();
    final branches = _db.getBranches();
    final departments = _db.getDepartments();
    final shifts = _db.getShifts();
    final logs = _db.getAttendanceLogsInDateRange(startKey, endKey);
    final leaves = _db.getLeaveRecordsInDateRange(startKey, endKey);

    final branchMap = {for (final b in branches) b.id: b};
    final deptMap = {for (final d in departments) d.id: d};
    final shiftMap = {for (final s in shifts) s.id: s};

    final logsByCardDate = <String, List<AttendanceLog>>{};
    for (final log in logs) {
      final key = '${log.cardNo}|${log.dateKey}';
      logsByCardDate.putIfAbsent(key, () => <AttendanceLog>[]).add(log);
    }

    final leavesByEmpDate = <String, LeaveRecord>{};
    for (final leave in leaves) {
      leavesByEmpDate['${leave.employeeId}|${leave.date}'] = leave;
    }

    final dayKeys = <({DateTime date, String key})>[];
    for (var cursor = rangeStart;
        !cursor.isAfter(rangeEnd);
        cursor = cursor.add(const Duration(days: 1))) {
      dayKeys.add((date: cursor, key: formatDateKey(cursor)));
    }

    final q = searchQuery.trim().toUpperCase();
    final results = <EmployeeAttendancePeriodSummary>[];

    for (final emp in employees) {
      if (branchId != null && emp.branchId != branchId) continue;
      if (departmentId != null && emp.departmentId != departmentId) continue;

      final branch = branchMap[emp.branchId] ??
          (branches.isNotEmpty
              ? branches.first
              : WorkplaceSeedData.branches.first);
      final dept = deptMap[emp.departmentId] ??
          const Department(id: 1, name: 'GENEL', branchId: 1);
      final shift = shiftMap[emp.shiftId] ??
          (shifts.isNotEmpty ? shifts.first : WorkplaceSeedData.shifts.first);

      if (q.isNotEmpty) {
        final matched = emp.fullName.toUpperCase().contains(q) ||
            emp.cardNo.toUpperCase().contains(q) ||
            dept.name.toUpperCase().contains(q);
        if (!matched) continue;
      }

      int totalDays = 0;
      int presentDays = 0;
      int onTimeDays = 0;
      int lateDays = 0;
      int totalLateMinutes = 0;
      int absentDays = 0;
      int onLeaveDays = 0;
      int sickReportDays = 0;
      int missingCheckOutDays = 0;
      int totalWorkedMinutes = 0;
      int totalOvertimeMinutes = 0;
      int totalEarlyLeaveMinutes = 0;
      final absentDateKeys = <String>[];

      for (final day in dayKeys) {
        final empLogs =
            logsByCardDate['${emp.cardNo}|${day.key}'] ?? const <AttendanceLog>[];
        final leave = leavesByEmpDate['${emp.id}|${day.key}'];

        if (excludeSundays &&
            day.date.weekday == DateTime.sunday &&
            empLogs.isEmpty &&
            leave == null) {
          continue;
        }

        final eval = _evaluateDayLogs(
          rawDayLogs: empLogs,
          shift: shift,
          leave: leave,
          employee: emp,
          dateKey: day.key,
        );

        if (eval.state.isNonActiveEmployment) {
          continue;
        }

        totalDays++;

        switch (eval.state) {
          case DailyAttendanceState.present:
            presentDays++;
            onTimeDays++;
          case DailyAttendanceState.late:
            presentDays++;
            lateDays++;
          case DailyAttendanceState.absent:
            absentDays++;
            absentDateKeys.add(day.key);
          case DailyAttendanceState.onLeave:
            onLeaveDays++;
          case DailyAttendanceState.sickReport:
            sickReportDays++;
          case DailyAttendanceState.terminated:
          case DailyAttendanceState.notYetHired:
            break;
        }

        totalLateMinutes += eval.lateMinutes;
        totalWorkedMinutes += eval.workedMinutes;
        totalOvertimeMinutes += eval.overtimeMinutes;
        totalEarlyLeaveMinutes += eval.earlyLeaveMinutes;
        if (eval.hasMissingCheckOut) {
          missingCheckOutDays++;
        }
      }

      if (totalDays == 0) continue;
      if (onlyWithAbsences && absentDays <= 0) continue;
      if (onlyWithLates && lateDays <= 0) continue;

      results.add(
        EmployeeAttendancePeriodSummary(
          employee: emp,
          department: dept,
          branch: branch,
          shift: shift,
          totalDays: totalDays,
          presentDays: presentDays,
          onTimeDays: onTimeDays,
          lateDays: lateDays,
          totalLateMinutes: totalLateMinutes,
          absentDays: absentDays,
          onLeaveDays: onLeaveDays,
          sickReportDays: sickReportDays,
          missingCheckOutDays: missingCheckOutDays,
          totalWorkedMinutes: totalWorkedMinutes,
          totalOvertimeMinutes: totalOvertimeMinutes,
          totalEarlyLeaveMinutes: totalEarlyLeaveMinutes,
          absentDateKeys: List<String>.unmodifiable(absentDateKeys),
        ),
      );
    }

    results.sort((a, b) {
      final absCmp = b.absentDays.compareTo(a.absentDays);
      if (absCmp != 0) return absCmp;
      final lateCmp = b.lateDays.compareTo(a.lateDays);
      if (lateCmp != 0) return lateCmp;
      return a.employee.fullName.compareTo(b.employee.fullName);
    });
    return results;
  }

  /// Seçili tarih aralığındaki Devam / Devamsızlık Raporunu Excel uyumlu (; ayraçlı) CSV olarak üretir.
  String generatePeriodAttendanceReportCsv({
    required String startDateKey,
    required String endDateKey,
    int? branchId,
    int? departmentId,
    String searchQuery = '',
    bool onlyWithAbsences = false,
    bool onlyWithLates = false,
    bool excludeSundays = false,
  }) {
    if (state.isCommercialWriteLocked) {
      return '';
    }
    final rows = buildAttendancePeriodReport(
      startDateKey: startDateKey,
      endDateKey: endDateKey,
      branchId: branchId,
      departmentId: departmentId,
      searchQuery: searchQuery,
      onlyWithAbsences: onlyWithAbsences,
      onlyWithLates: onlyWithLates,
      excludeSundays: excludeSundays,
    );
    final rangeLabel = '${formatDisplayDate(startDateKey, includeTodayBadge: false)} - ${formatDisplayDate(endDateKey, includeTodayBadge: false)}';
    final buf = StringBuffer();
    buf.writeln(
      'Tarih Aralığı;Kart No;Ad Soyad;Şube;Bölüm;Toplam Gün;Devam (Gün);Zamanında;Geç Kalma (Gün);Toplam Gecikme (Dk);Devamsızlık (Gün);İzinli (Gün);Raporlu (Gün);Eksik Çıkış (Gün);Net Çalışma (Saat);Fazla Mesai (Dk);Devam Oranı (%);Devamsız Tarihler',
    );
    for (final row in rows) {
      final workedHours = (row.totalWorkedMinutes / 60.0).toStringAsFixed(1);
      final rateStr = row.attendanceRatePercent.toStringAsFixed(1);
      final absentDatesStr = row.absentDateKeys.isEmpty
          ? '-'
          : row.absentDateKeys
              .map((d) => formatDisplayDate(d, includeTodayBadge: false))
              .join(', ');
      buf.writeln(
        '$rangeLabel;'
        '${row.employee.cardNo};'
        '${row.employee.fullName};'
        '${row.branch.name};'
        '${row.department.name};'
        '${row.totalDays};'
        '${row.presentDays};'
        '${row.onTimeDays};'
        '${row.lateDays};'
        '${row.totalLateMinutes};'
        '${row.absentDays};'
        '${row.onLeaveDays};'
        '${row.sickReportDays};'
        '${row.missingCheckOutDays};'
        '$workedHours;'
        '${row.totalOvertimeMinutes};'
        '%$rateStr;'
        '$absentDatesStr',
      );
    }
    return buf.toString();
  }

  /// Personelin özlük dosyasına resmi evrak dijital kopyası ekler veya günceller.
  Future<void> savePersonnelDocument(PersonnelDocument doc) async {
    _db.upsertPersonnelDocument(doc);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Özlük Dosyası Yönetimi');
  }

  /// Personelin özlük dosyasından dijital evrak kaydını siler.
  Future<void> deletePersonnelDocument(String docId) async {
    _db.deletePersonnelDocument(docId);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Özlük Dosyası Yönetimi');
  }

  /// Aktif kullanıcının (Yönetici, Yetkili Kullanıcı veya Personel) kendine özgü temasını günceller.
  Future<void> setCurrentUserThemeMode(HasibuThemeMode mode) async {
    if (state.authSession.isAuthenticated &&
        state.authSession.appUserId != null) {
      _db.updateAppUserThemeMode(state.authSession.appUserId!, mode);
      refreshDashboard();
      return;
    }
    if (state.authSession.isAuthenticated &&
        state.authSession.role == UserRole.employee &&
        state.authSession.employeeCardNo != null) {
      final cardNo = state.authSession.employeeCardNo!;
      final idx = state.dailyStatuses.indexWhere(
        (s) => s.employee.cardNo == cardNo,
      );
      if (idx >= 0) {
        final emp = state.dailyStatuses[idx].employee.copyWith(themeMode: mode);
        _db.upsertEmployee(emp);
        refreshDashboard();
        return;
      }
    }
    final updated = state.companySettings.copyWith(adminThemeMode: mode);
    _db.saveCompanySettings(updated);
    refreshDashboard();
  }

  /// Şirket logosunu (yerel görsel yolu veya kurumsal hazır logo) günceller.
  Future<void> updateCompanyLogo(String? logoPath) async {
    final clean = logoPath?.trim();
    final updated = state.companySettings.copyWith(
      logoPath: () => (clean == null || clean.isEmpty) ? null : clean,
    );
    _db.saveCompanySettings(updated);
    refreshDashboard();
  }

  /// Manuel Google Drive Yedekleme & Cihazlar Arası Uzlaştırma (Zikirce_ modeli)
  Future<void> syncWithGoogleDriveNow() async {
    // [LIC-05] Salt-Okunur (Read-Only) Abonelik Sonu / Saat Manipülasyonu Kilidi
    if (state.isCommercialWriteLocked) {
      state = state.copyWith(
        syncStatus: state.syncStatus.copyWith(
          stage: DriveSyncStage.error,
          message:
              'KİLİTLİ (Salt-Okunur Mod): ${state.licenseStatusMessage} — Google Drive senkronizasyonu devre dışı bırakıldı.',
        ),
      );
      return;
    }

    final isEmployeePortal = state.authSession.role == UserRole.employee;
    state = state.copyWith(
      isCloudBusy: true,
      syncStatus: state.syncStatus.copyWith(
        stage: DriveSyncStage.syncing,
        message: 'Google Drive (AES-256-GCM) ile eşitleniyor...',
      ),
    );
    try {
      await _syncService.pullAndReconcile(
        isEmployeePortalOnly: isEmployeePortal,
      );
      final pushStatus = await _syncService.pushToCloud(
        deviceName: 'Hasibu Cihaz Senkronizasyonu',
        force: true,
        isEmployeePortalOnly: isEmployeePortal,
        employeeCardNo: state.authSession.employeeCardNo,
        operationLabel: 'sync',
      );
      refreshDashboard();
      if (mounted) {
        state = state.copyWith(syncStatus: pushStatus);
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isCloudBusy: false);
      }
    }
  }

  /// Buluta anında manuel şifreli yedekleme yapar (Buluta Yedekle).
  Future<DriveSyncStatus> backupToCloudNow({String? profileId}) async {
    if (state.isCommercialWriteLocked) {
      final errStatus = state.syncStatus.copyWith(
        stage: DriveSyncStage.error,
        message:
            'KİLİTLİ (Salt-Okunur Mod): ${state.licenseStatusMessage} — Buluta yedekleme devre dışı bırakıldı.',
      );
      state = state.copyWith(syncStatus: errStatus);
      return errStatus;
    }

    final isEmployeePortal = state.authSession.role == UserRole.employee;
    state = state.copyWith(
      isCloudBusy: true,
      syncStatus: state.syncStatus.copyWith(
        stage: DriveSyncStage.syncing,
        message: 'Bulut yedeği hazırlanıp yükleniyor...',
      ),
    );
    try {
      final status = await _syncService.pushToCloud(
        deviceName: 'Hasibu Manuel Bulut Yedekleme',
        force: true,
        isEmployeePortalOnly: isEmployeePortal,
        employeeCardNo: state.authSession.employeeCardNo,
        profileId: profileId,
        operationLabel: 'backup',
      );
      if (mounted) {
        state = state.copyWith(syncStatus: status);
      }
      if (status.isTrulySynced) {
        await refreshAvailableCloudBackups();
      }
      return status;
    } finally {
      if (mounted) {
        state = state.copyWith(isCloudBusy: false);
      }
    }
  }

  /// Buluttan şifreli yedeği indirir ve seçilen stratejiye göre geri yükler (Buluttan Yükle).
  Future<({DriveSyncStatus status, CloudRestoreSummary? summary})>
      restoreFromCloudNow({
    String? profileId,
    CloudRestoreMode mode = CloudRestoreMode.merge,
    bool cloudOnly = false,
    String? overrideWorkspaceKey,
  }) async {
    if (state.isCommercialWriteLocked) {
      final errStatus = state.syncStatus.copyWith(
        stage: DriveSyncStage.error,
        message:
            'KİLİTLİ (Salt-Okunur Mod): ${state.licenseStatusMessage} — Buluttan geri yükleme devre dışı bırakıldı.',
      );
      state = state.copyWith(syncStatus: errStatus);
      return (status: errStatus, summary: null);
    }

    final isEmployeePortal = state.authSession.role == UserRole.employee;
    state = state.copyWith(
      isCloudBusy: true,
      syncStatus: state.syncStatus.copyWith(
        stage: DriveSyncStage.syncing,
        message: 'Bulut yedeği indiriliyor ve uygulanıyor...',
      ),
    );
    try {
      final res = await _syncService.restoreFromCloud(
        profileId: profileId,
        mode: mode,
        isEmployeePortalOnly: isEmployeePortal,
        cloudOnly: cloudOnly,
        overrideWorkspaceKey: overrideWorkspaceKey,
      );
      if (res.summary != null) {
        refreshDashboard();
        _configureAutoPollTimer();
        _configureAutoCloudBackupTimer();
      }
      if (mounted) {
        state = state.copyWith(
          syncStatus: res.status,
          lastRestoreSummary: res.summary != null ? () => res.summary : null,
        );
      }
      return res;
    } finally {
      if (mounted) {
        state = state.copyWith(isCloudBusy: false);
      }
    }
  }

  /// Bağlı Google Drive hesabındaki ve klasöründeki tüm yedek profillerini tarar.
  Future<List<CloudBackupProfileInfo>> refreshAvailableCloudBackups() async {
    final list = await _syncService.listAvailableCloudBackups();
    if (mounted) {
      state = state.copyWith(availableCloudBackups: list);
    }
    return list;
  }

  /// Otomatik bulut yedekleme ve aktif yedek profili (kasa) ayarlarını günceller.
  Future<void> updateCloudBackupSettings({
    bool? autoCloudBackupEnabled,
    int? autoCloudBackupMinutes,
    bool? autoCloudBackupOnChange,
    String? cloudProfileId,
    String? cloudProfileLabel,
  }) async {
    final normalizedProfile = cloudProfileId != null
        ? GoogleDriveSyncService.normalizeCloudProfileId(cloudProfileId)
        : null;
    final updated = state.companySettings.copyWith(
      autoCloudBackupEnabled: autoCloudBackupEnabled,
      autoCloudBackupMinutes: autoCloudBackupMinutes?.clamp(5, 1440),
      autoCloudBackupOnChange: autoCloudBackupOnChange,
      cloudProfileId: normalizedProfile,
      cloudProfileLabel: cloudProfileLabel?.trim().isNotEmpty == true
          ? cloudProfileLabel!.trim()
          : null,
    );
    _db.saveCompanySettings(updated);
    refreshDashboard();
    _configureAutoCloudBackupTimer();
  }

  Future<String> getCloudWorkspaceKey() => _syncService.getWorkspaceKey();

  Future<void> updateCloudWorkspaceKey(String key) =>
      _syncService.saveWorkspaceKey(key);

  /// Aynı şirket (ve aynı Gmail bulut yedeği) altında yeni yetkili kullanıcı ekler veya günceller.
  Future<String?> saveAppUser({
    String? existingId,
    required String username,
    required String displayName,
    String? plainPassword,
    required AppUserRole role,
    required List<HasibuModule> allowedModules,
    int? allowedBranchId,
    String? linkedGmail,
    bool isActive = true,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) {
      return 'Kullanıcı adı boş bırakılamaz.';
    }
    if (cleanUsername ==
        state.companySettings.adminUsername.trim().toLowerCase()) {
      return 'Ana yönetici kullanıcı adı ("$cleanUsername") ile aynı kullanıcı adı kullanılamaz.';
    }

    final duplicate = _db.findAppUserByUsername(cleanUsername);
    if (duplicate != null && duplicate.id != existingId) {
      return '"$cleanUsername" kullanıcı adı zaten kayıtlı.';
    }

    AppUserAccount? existingUser;
    if (existingId != null && existingId.trim().isNotEmpty) {
      for (final u in state.appUsers) {
        if (u.id == existingId) {
          existingUser = u;
          break;
        }
      }
    }

    final trimmedPlain = plainPassword?.trim() ?? '';
    if (existingUser == null && trimmedPlain.isEmpty) {
      return 'Yeni kullanıcı için parola zorunludur.';
    }

    final passwordHash = trimmedPlain.isEmpty
        ? existingUser!.passwordHash
        : HasibuSecurityService.hashPassword(trimmedPlain);

    final account = AppUserAccount(
      id: existingUser?.id ?? 'USR-${DateTime.now().microsecondsSinceEpoch}',
      username: cleanUsername,
      displayName:
          displayName.trim().isEmpty ? cleanUsername : displayName.trim(),
      passwordHash: passwordHash,
      role: role,
      allowedModules: allowedModules.isEmpty ? role.defaultModules : allowedModules,
      allowedBranchId: allowedBranchId,
      linkedGmail: linkedGmail?.trim().isEmpty == true
          ? null
          : linkedGmail?.trim(),
      isActive: isActive,
      themeMode: existingUser?.themeMode ?? HasibuThemeMode.light,
      createdAtIso:
          existingUser?.createdAtIso ?? DateTime.now().toIso8601String(),
    );

    _db.upsertAppUser(account);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: existingUser == null ? 'APP_USER_CREATED' : 'APP_USER_UPDATED',
      targetRecordId: cleanUsername,
      oldValue: existingUser == null
          ? 'NEW'
          : 'role=${existingUser.role.name}, active=${existingUser.isActive}',
      newValue:
          'role=${account.role.name}, active=${account.isActive}, branch=${account.allowedBranchId ?? "ALL"}',
    );

    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Çoklu Kullanıcı Yönetimi');
    return null;
  }

  Future<void> deleteAppUser(String userId) async {
    _db.deleteAppUser(userId);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'APP_USER_DELETED',
      targetRecordId: userId,
      oldValue: 'active',
      newValue: 'deleted',
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Çoklu Kullanıcı Yönetimi');
  }

  Future<void> toggleAppUserActive(String userId, bool isActive) async {
    for (final u in state.appUsers) {
      if (u.id == userId) {
        final updated = u.copyWith(isActive: isActive);
        _db.upsertAppUser(updated);
        final actor = state.authSession.username.isEmpty
            ? 'admin'
            : state.authSession.username;
        _db.appendAuditLog(
          actorEmployeeId: actor,
          actionType: 'APP_USER_STATUS_CHANGED',
          targetRecordId: u.username,
          oldValue: 'active=${u.isActive}',
          newValue: 'active=$isActive',
        );
        refreshDashboard();
        await _pushAutoBackupOnChange('Hasibu Çoklu Kullanıcı Yönetimi');
        return;
      }
    }
  }

  /// [LIC-03] & [LIC-05] Yeni müşteri lisans tokenını (Ed25519) doğrular ve kaydeder.
  Future<LicenseVerificationResult> updateCommercialLicenseToken(
    String newLicenseToken,
  ) async {
    final result = await LicenseGuardService.verifyLicenseToken(
      newLicenseToken,
      expectedHwId: state.companySettings.hardwareFingerprint,
      currentEmployeeCount: state.dailyStatuses.length,
      currentBranchCount: state.branches.length,
    );
    final updated = state.companySettings.copyWith(
      licenseToken: newLicenseToken.trim(),
    );
    _db.saveCompanySettings(updated);
    refreshDashboard();
    return result;
  }

  /// [LIC-05] Abonelik Sonu (Salt-Okunur / Read-Only) modunu test etmek veya
  /// aktif kurumsal lisansı yenilemek için yardımcı fonksiyon.
  void setSubscriptionExpiredForDemo(bool expired) {
    final hwId = state.companySettings.hardwareFingerprint.isNotEmpty
        ? state.companySettings.hardwareFingerprint
        : HardwareFingerprintService.getDeviceHardwareFingerprint();
    final token = LicenseGuardService.createBootstrapLicenseTokenSync(
      company: state.companySettings.companyName,
      hwId: hwId,
      expiresAt: expired
          ? DateTime.now().toUtc().subtract(const Duration(days: 5))
          : DateTime.now().toUtc().add(const Duration(days: 365)),
    );
    final updated = state.companySettings.copyWith(
      licenseToken: token,
      hardwareFingerprint: hwId,
    );
    _db.saveCompanySettings(updated);
    refreshDashboard();
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000;
    final double dLat = (lat2 - lat1) * math.pi / 180.0;
    final double dLon = (lon2 - lon1) * math.pi / 180.0;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  void dispose() {
    _autoPollTimer?.cancel();
    _autoCloudBackupTimer?.cancel();
    for (final sub in _realtimeSubs) {
      sub.cancel();
    }
    for (final client in _activeClients.values) {
      client.dispose();
    }
    super.dispose();
  }
}

final pdksDashboardProvider =
    StateNotifierProvider<PdksDashboardNotifier, PdksDashboardState>((ref) {
  final db = ref.watch(hasibuDatabaseProvider);
  final sync = ref.watch(googleDriveSyncServiceProvider);
  final authAdapter = ref.watch(googleAuthAdapterProvider);
  return PdksDashboardNotifier(
    db: db,
    syncService: sync,
    googleAuthAdapter: authAdapter,
  );
});
