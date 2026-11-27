import 'package:flutter/foundation.dart';

import '../../../../core/services/google_drive_sync_service.dart';
import '../../../../core/utils/turkish_search.dart';
import '../../domain/pdks_models.dart';

enum AdminLoginOutcome {
  authenticated,
  requiresInitialPasswordUpdate,
  failed,
}

@immutable
class UnifiedLoginResult {
  final AdminLoginOutcome outcome;
  final UserRole? resolvedRole;
  final String resolvedUsername;

  const UnifiedLoginResult({
    required this.outcome,
    this.resolvedRole,
    this.resolvedUsername = '',
  });
}

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
  final List<ShiftAssignment> shiftAssignments;
  final List<Department> departments;
  final List<EmployeeDailyStatus> dailyStatuses;
  final List<LeaveRecord> allLeaveRecords;
  final List<PublicHoliday> publicHolidays;
  final List<PersonnelDocument> allPersonnelDocuments;
  final List<HrRequest> allHrRequests;
  final List<PdksProactiveAlert> proactiveAlerts;
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
  final List<BranchInboxDeviceStatus> branchInboxStatuses;
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
    this.shiftAssignments = const <ShiftAssignment>[],
    this.departments = const <Department>[],
    this.dailyStatuses = const <EmployeeDailyStatus>[],
    this.allLeaveRecords = const <LeaveRecord>[],
    this.publicHolidays = const <PublicHoliday>[],
    this.allPersonnelDocuments = const <PersonnelDocument>[],
    this.allHrRequests = const <HrRequest>[],
    this.proactiveAlerts = const <PdksProactiveAlert>[],
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
    this.branchInboxStatuses = const <BranchInboxDeviceStatus>[],
    this.isCloudBusy = false,
    this.lastRestoreSummary,
  });

  /// [LIC-05] Sistem Salt-Okunur (Read-Only) Abonelik Sonu veya Saat Manipülasyonu Kilidinde mi?
  bool get isCommercialWriteLocked =>
      isReadOnlySubscriptionLocked || isClockTampered;

  List<int> get effectiveBranchScopeIds => authSession.isAuthenticated
      ? authSession.effectiveScopedBranchIds
      : const <int>[];

  int? get effectiveBranchScopeId => effectiveBranchScopeIds.length == 1
      ? effectiveBranchScopeIds.first
      : null;

  bool get isBranchScoped => effectiveBranchScopeIds.isNotEmpty;

  bool get isSingleBranchScoped => effectiveBranchScopeIds.length == 1;

  bool canAccessBranch(int branchId) =>
      !isBranchScoped || effectiveBranchScopeIds.contains(branchId);

  int? get effectiveSelectedBranchId {
    final scoped = effectiveBranchScopeIds;
    if (scoped.length == 1) return scoped.first;
    if (scoped.length > 1) {
      return (selectedBranchId != null && scoped.contains(selectedBranchId))
          ? selectedBranchId
          : null;
    }
    return selectedBranchId;
  }

  /// Kalıcı Google Bulut / Drive oturumu aktif mi?
  bool get isGoogleCloudConnected =>
      syncStatus.connectedGmail.trim().isNotEmpty &&
      (syncStatus.isTrulySynced ||
          syncStatus.isCloudApiVerified ||
          syncStatus.isDriveFolderMirrored);

  List<PersonnelDocument> documentsForEmployee(int employeeId) =>
      allPersonnelDocuments
          .where((d) => d.employeeId == employeeId)
          .toList(growable: false);

  List<HrRequest> requestsForEmployee(int employeeId) => allHrRequests
      .where((r) => r.employeeId == employeeId)
      .toList(growable: false);

  int get pendingHrRequestsCount =>
      allHrRequests.where((r) => r.status == HrRequestStatus.pending).length;

  int get criticalProactiveAlertsCount => proactiveAlerts
      .where(
        (a) =>
            a.severity == PdksAlertSeverity.critical ||
            a.severity == PdksAlertSeverity.warning,
      )
      .length;

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
    final scoped = effectiveBranchScopeIds;
    final branchFilter = effectiveSelectedBranchId;
    if (branchFilter != null) {
      return dailyStatuses
          .where((s) => s.branch.id == branchFilter)
          .toList(growable: false);
    }
    if (scoped.isNotEmpty) {
      return dailyStatuses
          .where((s) => scoped.contains(s.branch.id))
          .toList(growable: false);
    }
    return dailyStatuses;
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
      final q = normalizeTurkishSearch(searchQuery);
      if (q.isNotEmpty) {
        return matchesTurkishSearch(item.employee.fullName, q) ||
            matchesTurkishSearch(item.employee.cardNo, q) ||
            matchesTurkishSearch(item.department.name, q) ||
            matchesTurkishSearch(item.employee.title, q);
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
    List<ShiftAssignment>? shiftAssignments,
    List<Department>? departments,
    List<EmployeeDailyStatus>? dailyStatuses,
    List<LeaveRecord>? allLeaveRecords,
    List<PublicHoliday>? publicHolidays,
    List<PersonnelDocument>? allPersonnelDocuments,
    List<HrRequest>? allHrRequests,
    List<PdksProactiveAlert>? proactiveAlerts,
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
    List<BranchInboxDeviceStatus>? branchInboxStatuses,
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
      shiftAssignments: shiftAssignments ?? this.shiftAssignments,
      departments: departments ?? this.departments,
      dailyStatuses: dailyStatuses ?? this.dailyStatuses,
      allLeaveRecords: allLeaveRecords ?? this.allLeaveRecords,
      publicHolidays: publicHolidays ?? this.publicHolidays,
      allPersonnelDocuments:
          allPersonnelDocuments ?? this.allPersonnelDocuments,
      allHrRequests: allHrRequests ?? this.allHrRequests,
      proactiveAlerts: proactiveAlerts ?? this.proactiveAlerts,
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
      branchInboxStatuses: branchInboxStatuses ?? this.branchInboxStatuses,
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
