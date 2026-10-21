import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/hasibu_database.dart';
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
    this.terminalStatusMessage =
        'Tenfei D35 (192.168.9.150:4370) otomatik dinleme hazır',
    this.syncStatus = const DriveSyncStatus(),
    this.activeSelfServiceCardNo = '00064',
  });

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

  /// Aktif oturumdaki kullanıcının (Yönetici veya Personel) kendine özgü tema seçimi.
  HasibuThemeMode get activeThemeMode {
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

  List<EmployeeDailyStatus> get filteredByBranch {
    if (selectedBranchId == null) return dailyStatuses;
    return dailyStatuses
        .where((s) => s.branch.id == selectedBranchId)
        .toList(growable: false);
  }

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
    return filteredByBranch.where((item) {
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
    );
  }
}

class PdksDashboardNotifier extends StateNotifier<PdksDashboardState> {
  final HasibuDatabase _db;
  final GoogleDriveSyncService _syncService;
  Timer? _autoPollTimer;
  final Map<int, TenfeiZkClient> _activeClients = <int, TenfeiZkClient>{};
  final List<StreamSubscription<AttendanceLog>> _realtimeSubs =
      <StreamSubscription<AttendanceLog>>[];

  PdksDashboardNotifier({
    required HasibuDatabase db,
    required GoogleDriveSyncService syncService,
  })  : _db = db,
        _syncService = syncService,
        super(const PdksDashboardState(selectedDate: '2026-10-19')) {
    refreshDashboard();
    _configureAutoPollTimer();
  }

  /// Yönetici / İK Girişi doğrular (tüm modüllere tam yetki).
  bool loginAsAdmin({required String username, required String password}) {
    final u = username.trim().toLowerCase();
    final p = password.trim();
    final expectedUser = state.companySettings.adminUsername.toLowerCase();
    final expectedPass = state.companySettings.adminPassword;

    if (u == expectedUser && p == expectedPass) {
      state = state.copyWith(
        authSession: AuthSession(
          isAuthenticated: true,
          username: username.trim(),
          displayName: 'Yönetim (${state.companySettings.companyName})',
          role: UserRole.admin,
          allowedModules: HasibuModule.values,
        ),
        activeModule: HasibuModule.pdksHr,
      );
      return true;
    }

    state = state.copyWith(
      authSession: state.authSession.copyWith(
        isAuthenticated: false,
        errorMessage: () =>
            'Kullanıcı adı veya parola hatalı (Varsayılan: $expectedUser / $expectedPass).',
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
      final expectedPassword =
          emp.password.trim().isNotEmpty ? emp.password.trim() : fallbackPin;

      if (pin.trim() == expectedPassword) {
        final modules = emp.allowedModules.isNotEmpty
            ? emp.allowedModules
            : const <HasibuModule>[HasibuModule.employeePortal];
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
    state = state.copyWith(
      authSession: const AuthSession(isAuthenticated: false),
      activeModule: HasibuModule.pdksHr,
    );
  }

  /// Üst modül seçme satırından aktif modülü değiştirir (yetki kontrolü ile).
  void selectModule(HasibuModule module) {
    if (!state.authSession.canAccess(module)) {
      return;
    }
    state = state.copyWith(activeModule: module);
  }

  void refreshDashboard() {
    final companySettings = _db.getCompanySettings();
    final branches = _db.getBranches();
    final shifts = _db.getShifts();
    final departments = _db.getDepartments();
    final employees = _db.getEmployees();
    final logs = _db.getAttendanceLogsForDate(state.selectedDate);
    final leaves = _db.getLeaveRecordsForDate(state.selectedDate);
    final allLeaves = _db.getAllLeaveRecords();
    final allDocs = _db.getAllPersonnelDocuments();
    final allRequests = _db.getAllHrRequests();

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
  }) {
    if (rawDayLogs.isEmpty) {
      final DailyAttendanceState st;
      if (leave != null) {
        if (leave.leaveType == LeaveType.saglikRaporu) {
          st = DailyAttendanceState.sickReport;
        } else if (leave.leaveType == LeaveType.devamsiz) {
          st = DailyAttendanceState.absent;
        } else {
          st = DailyAttendanceState.onLeave;
        }
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
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Ayarlar (${newSettings.companyName})',
    );
    state = state.copyWith(syncStatus: syncResult);
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

  /// Doğrudan Tenfei D35 (192.168.9.150:4370 ve aktif şube terminalleri) üzerinden
  /// TCP 4370 protokolüyle giriş-çıkış kayıtlarını çeker ve Google Drive'a yedekler.
  Future<void> pullFromTenfeiTerminals({int? onlyBranchId}) async {
    if (state.isPollingTerminal) return;
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
    bool anyReachable = false;
    String? latestPulledDateKey;
    final messages = <String>[];

    for (final branch in targetBranches) {
      final ip = branch.terminalIp ?? '192.168.9.150';
      final client = TenfeiZkClient(
        host: ip,
        port: branch.terminalPort,
        branchId: branch.id,
        machineNo: branch.machineNo,
      );

      try {
        final logs = await client.fetchAttendanceLogs();
        anyReachable = true;
        totalFetched += logs.length;
        newInserted += _db.upsertAttendanceLogsBatch(logs);
        for (final l in logs) {
          if (latestPulledDateKey == null ||
              l.dateKey.compareTo(latestPulledDateKey) > 0) {
            latestPulledDateKey = l.dateKey;
          }
        }
        messages.add(
          '${branch.name} ($ip:${branch.terminalPort}): ${logs.length} kayıt çekildi',
        );
      } catch (_) {
        messages.add(
          '${branch.name} ($ip:${branch.terminalPort}): Cihaza ulaşılamadı',
        );
      } finally {
        await client.dispose();
      }
    }

    if (latestPulledDateKey != null &&
        latestPulledDateKey != state.selectedDate) {
      state = state.copyWith(selectedDate: latestPulledDateKey);
    }

    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Masaüstü (Tenfei D35 Köprüsü)',
    );

    state = state.copyWith(
      isPollingTerminal: false,
      lastTerminalReachable: () => anyReachable,
      terminalStatusMessage: messages.isEmpty
          ? 'Aktif terminal tanımlı değil.'
          : '${messages.join(' | ')} ($newInserted yeni, toplam $totalFetched)',
      syncStatus: syncResult,
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
    final client = TenfeiZkClient(
      host: ip,
      port: branch.terminalPort,
      branchId: branch.id,
      machineNo: branch.machineNo,
    );
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
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Şube/Cihaz Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
  }

  Future<void> deleteBranch(int branchId) async {
    _db.deleteBranch(branchId);
    if (state.selectedBranchId == branchId) {
      state = state.copyWith(selectedBranchId: () => null);
    }
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Şube/Cihaz Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
  }

  /// Vardiya / Mesai Saat Aralığı ve Geç Kalma Toleransını ekler veya günceller.
  Future<void> saveShiftPlan(ShiftPlan shift) async {
    _db.upsertShift(shift);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Vardiya Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
  }

  Future<void> deleteShiftPlan(int shiftId) async {
    _db.deleteShift(shiftId);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Vardiya Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
  }

  /// Departman / Üretim Bölümü ekler veya günceller.
  Future<void> saveDepartment(Department dept) async {
    _db.upsertDepartment(dept);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Bölüm Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
  }

  /// Personel ekler veya mevcut personelin bilgilerini günceller.
  Future<void> saveEmployee(Employee employee) async {
    _db.upsertEmployee(employee);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Personel Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
  }

  Future<void> deleteEmployee(int employeeId) async {
    _db.deleteEmployee(employeeId);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Personel Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
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
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Hareket Düzeltme',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
  }

  Future<void> deleteAttendanceLog(String logId) async {
    _db.deleteAttendanceLog(logId);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Hareket Düzeltme',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
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
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Toplu Hareket Düzeltme',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
    return affected;
  }

  /// Google (Gmail) bulut eşitleme hesabını, yerel Drive klasörünü ve varsa OAuth anahtarını kaydeder.
  Future<void> saveGmailSyncAccount({
    required String gmailAccount,
    required String syncFolderPath,
    String? accessToken,
  }) async {
    final updated = state.companySettings.copyWith(
      syncGmailAccount: gmailAccount.trim(),
      syncFolderPath: syncFolderPath.trim(),
    );
    _db.saveCompanySettings(updated);
    if (accessToken != null) {
      if (accessToken.trim().isEmpty) {
        try {
          await _syncService.clearTokens();
        } catch (_) {}
      } else {
        try {
          await _syncService.saveOAuthTokens(accessToken: accessToken.trim());
        } catch (_) {}
      }
    }
    refreshDashboard();
    await syncWithGoogleDriveNow();
  }

  /// Cihaz olmayan şubelerde (Devteyşti, Yenişehir, Karaköprü) Mobil QR veya
  /// Konum (GPS Geofence) doğrulaması ile personel giriş-çıkış kaydı oluşturur.
  Future<String> recordBranchMobileCheckIn({
    required Employee employee,
    required Branch branch,
    required AttendanceSource source,
    required bool isCheckIn,
    double? currentLat,
    double? currentLng,
  }) async {
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

    final log = AttendanceLog(
      id: '${branch.id}_${employee.cardNo}_${logTime.millisecondsSinceEpoch}',
      cardNo: employee.cardNo,
      branchId: branch.id,
      deviceNo: branch.machineNo,
      timestamp: logTime,
      isCheckIn: isCheckIn,
      source: source,
      verifyMethod: source == AttendanceSource.mobileQr
          ? VerifyMethod.mobileQr
          : VerifyMethod.mobileGps,
    );

    _db.upsertAttendanceLog(log);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Mobil (${branch.name})',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
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
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu İK Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
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
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu İK İzin/Rapor Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
    return daysCount;
  }

  Future<void> deleteLeaveRecord(String leaveId) async {
    _db.deleteLeaveRecord(leaveId);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu İK İzin/Rapor Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
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
    await saveOrUpdateAttendanceLog(
      employee: item.employee,
      dateKey: state.selectedDate,
      timeHhMm: item.shift.endTime,
      isCheckIn: false,
      source: AttendanceSource.manual,
      verifyMethod: VerifyMethod.password,
    );
  }

  /// Seçili tarihte çıkış basmayı unutan tüm personellerin çıkış saatini kendi vardiya bitiş saatlerine göre toplu tamamlar.
  Future<int> batchCompleteAllMissingCheckOuts() async {
    final targets = state.filteredByBranch
        .where((s) => s.hasMissingCheckOut)
        .toList(growable: false);
    if (targets.isEmpty) return 0;

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
        ),
      );
    }

    _db.upsertAttendanceLogsBatch(logsToInsert);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Eksik Çıkış Otomasyonu',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
    return logsToInsert.length;
  }

  /// Personel Portalı veya İK üzerinden yeni talep (İzin, Fazla Mesai, Eksik Hareket, Avans) oluşturur.
  Future<void> submitHrRequest(HrRequest request) async {
    _db.upsertHrRequest(request);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Personel Talep Merkezi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
  }

  /// İK Yöneticisi personel talebini Tek Tıkla Onaylar veya Reddeder.
  /// Onaylandığında izin veya unutulan giriş/çıkış hareketi otomatik olarak puantaja işlenir!
  Future<String> reviewHrRequest({
    required HrRequest request,
    required bool approve,
    String? reviewerNote,
  }) async {
    final updated = request.copyWith(
      status: approve ? HrRequestStatus.approved : HrRequestStatus.rejected,
      reviewerNote: () => reviewerNote?.trim().isEmpty == true
          ? (approve ? 'İK tarafından onaylandı ve puantaja işlendi' : 'İK tarafından reddedildi')
          : reviewerNote?.trim(),
    );
    _db.upsertHrRequest(updated);

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
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu İK Onay Merkezi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
    return actionSummary;
  }

  /// 4857 sayılı İş Kanunu Md. 53 uyarınca kıdem yılına göre eksik tanımlanmış yıllık izin haklarını otomatik günceller.
  Future<int> syncStatutoryLeaveEntitlements() async {
    final employees = _db.getEmployees();
    int updatedCount = 0;
    for (final emp in employees) {
      if (emp.hasStatutoryLeaveMismatch) {
        _db.upsertEmployee(
          emp.copyWith(
            annualLeaveEntitlement: emp.statutoryAnnualLeaveEntitlement,
          ),
        );
        updatedCount++;
      }
    }
    if (updatedCount > 0) {
      refreshDashboard();
      final syncResult = await _syncService.pushToCloud(
        deviceName: 'Hasibu 4857 İzin Hakediş Eşitleme',
        force: true,
      );
      state = state.copyWith(syncStatus: syncResult);
    }
    return updatedCount;
  }

  /// Seçili tarihteki resmi PDKS & Puantaj çizelgesini Excel uyumlu (; ayraçlı) CSV metni olarak üretir.
  String generateDailyPuantajCsv({bool onlyVisible = false}) {
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

  /// Personelin özlük dosyasına resmi evrak dijital kopyası ekler veya günceller.
  Future<void> savePersonnelDocument(PersonnelDocument doc) async {
    _db.upsertPersonnelDocument(doc);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Özlük Dosyası Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
  }

  /// Personelin özlük dosyasından dijital evrak kaydını siler.
  Future<void> deletePersonnelDocument(String docId) async {
    _db.deletePersonnelDocument(docId);
    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Özlük Dosyası Yönetimi',
      force: true,
    );
    state = state.copyWith(syncStatus: syncResult);
  }

  /// Aktif kullanıcının (Yönetici veya Personel) kendine özgü temasını (Açık / Koyu / Sistem) günceller.
  Future<void> setCurrentUserThemeMode(HasibuThemeMode mode) async {
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
    state = state.copyWith(
      syncStatus: state.syncStatus.copyWith(
        stage: DriveSyncStage.syncing,
        message: 'Google Drive ile eşitleniyor...',
      ),
    );
    await _syncService.pullAndReconcile();
    final pushStatus = await _syncService.pushToCloud(
      deviceName: 'Hasibu Cihaz Senkronizasyonu',
      force: true,
    );
    refreshDashboard();
    state = state.copyWith(syncStatus: pushStatus);
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
  return PdksDashboardNotifier(db: db, syncService: sync);
});
