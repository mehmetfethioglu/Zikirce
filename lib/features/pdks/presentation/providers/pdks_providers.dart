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
  final String searchQuery;
  final List<Branch> branches;
  final List<ShiftPlan> shifts;
  final List<Department> departments;
  final List<EmployeeDailyStatus> dailyStatuses;
  final List<LeaveRecord> allLeaveRecords;
  final List<PersonnelDocument> allPersonnelDocuments;
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
    this.searchQuery = '',
    this.branches = const <Branch>[],
    this.shifts = const <ShiftPlan>[],
    this.departments = const <Department>[],
    this.dailyStatuses = const <EmployeeDailyStatus>[],
    this.allLeaveRecords = const <LeaveRecord>[],
    this.allPersonnelDocuments = const <PersonnelDocument>[],
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

  List<EmployeeDailyStatus> get visibleStatuses {
    return filteredByBranch.where((item) {
      if (selectedStateFilter != null && item.state != selectedStateFilter) {
        return false;
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
    String? searchQuery,
    List<Branch>? branches,
    List<ShiftPlan>? shifts,
    List<Department>? departments,
    List<EmployeeDailyStatus>? dailyStatuses,
    List<LeaveRecord>? allLeaveRecords,
    List<PersonnelDocument>? allPersonnelDocuments,
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
      searchQuery: searchQuery ?? this.searchQuery,
      branches: branches ?? this.branches,
      shifts: shifts ?? this.shifts,
      departments: departments ?? this.departments,
      dailyStatuses: dailyStatuses ?? this.dailyStatuses,
      allLeaveRecords: allLeaveRecords ?? this.allLeaveRecords,
      allPersonnelDocuments:
          allPersonnelDocuments ?? this.allPersonnelDocuments,
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

      final checkIns =
          empLogs.where((l) => l.isCheckIn).toList(growable: false);
      final checkOuts =
          empLogs.where((l) => !l.isCheckIn).toList(growable: false);

      final AttendanceLog? firstIn = checkIns.isNotEmpty
          ? checkIns.first
          : (empLogs.isNotEmpty ? empLogs.first : null);
      final AttendanceLog? lastOut = checkOuts.isNotEmpty
          ? checkOuts.last
          : (empLogs.length > 1 ? empLogs.last : null);

      DailyAttendanceState dailyState;
      int lateMins = 0;

      if (firstIn != null) {
        lateMins = _calculateLateMinutes(
          firstIn.timestamp,
          shift.startTime,
          shift.toleranceMinutes,
        );
        dailyState = lateMins > 0
            ? DailyAttendanceState.late
            : DailyAttendanceState.present;
      } else if (leave != null) {
        if (leave.leaveType == LeaveType.saglikRaporu) {
          dailyState = DailyAttendanceState.sickReport;
        } else if (leave.leaveType == LeaveType.devamsiz) {
          dailyState = DailyAttendanceState.absent;
        } else {
          dailyState = DailyAttendanceState.onLeave;
        }
      } else {
        dailyState = DailyAttendanceState.absent;
      }

      statuses.add(
        EmployeeDailyStatus(
          employee: emp,
          department: dept,
          branch: branch,
          shift: shift,
          state: dailyState,
          firstCheckIn: firstIn,
          lastCheckOut: lastOut,
          allLogsOfDay: empLogs,
          leaveRecord: leave,
          lateMinutes: lateMins,
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

  void setBranchFilter(int? branchId) {
    state = state.copyWith(selectedBranchId: () => branchId);
  }

  void setStateFilter(DailyAttendanceState? filter) {
    state = state.copyWith(selectedStateFilter: () => filter);
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

      final checkIns =
          dayLogs.where((l) => l.isCheckIn).toList(growable: false);
      final checkOuts =
          dayLogs.where((l) => !l.isCheckIn).toList(growable: false);

      final AttendanceLog? firstIn = checkIns.isNotEmpty
          ? checkIns.first
          : (dayLogs.isNotEmpty ? dayLogs.first : null);
      final AttendanceLog? lastOut = checkOuts.isNotEmpty
          ? checkOuts.last
          : (dayLogs.length > 1 ? dayLogs.last : null);

      DailyAttendanceState dayState;
      int lateMins = 0;
      if (firstIn != null) {
        lateMins = _calculateLateMinutes(
          firstIn.timestamp,
          shift.startTime,
          shift.toleranceMinutes,
        );
        dayState = lateMins > 0
            ? DailyAttendanceState.late
            : DailyAttendanceState.present;
      } else if (lv != null) {
        if (lv.leaveType == LeaveType.saglikRaporu) {
          dayState = DailyAttendanceState.sickReport;
        } else if (lv.leaveType == LeaveType.devamsiz) {
          dayState = DailyAttendanceState.absent;
        } else {
          dayState = DailyAttendanceState.onLeave;
        }
      } else {
        dayState = DailyAttendanceState.absent;
      }

      entries.add(
        EmployeeHistoryDayEntry(
          dateKey: dKey,
          state: dayState,
          firstCheckIn: firstIn,
          lastCheckOut: lastOut,
          allLogs: dayLogs,
          leaveRecord: lv,
          lateMinutes: lateMins,
        ),
      );
    }
    return entries;
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
