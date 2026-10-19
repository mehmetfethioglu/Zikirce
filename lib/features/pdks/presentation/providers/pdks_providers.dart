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
  final String selectedDate; // YYYY-MM-DD
  final int? selectedBranchId; // null => Tüm Şubeler
  final DailyAttendanceState? selectedStateFilter; // null => Tümü
  final String searchQuery;
  final List<Branch> branches;
  final List<Department> departments;
  final List<EmployeeDailyStatus> dailyStatuses;
  final bool isPollingTerminal;
  final bool autoPollEnabled;
  final int autoPollMinutes;
  final String terminalStatusMessage;
  final DriveSyncStatus syncStatus;
  final String activeSelfServiceCardNo;

  const PdksDashboardState({
    required this.selectedDate,
    this.selectedBranchId,
    this.selectedStateFilter,
    this.searchQuery = '',
    this.branches = const <Branch>[],
    this.departments = const <Department>[],
    this.dailyStatuses = const <EmployeeDailyStatus>[],
    this.isPollingTerminal = false,
    this.autoPollEnabled = true,
    this.autoPollMinutes = 5,
    this.terminalStatusMessage =
        'Tenfei D35 (192.168.9.150:4370) otomatik dinleme hazır',
    this.syncStatus = const DriveSyncStatus(),
    this.activeSelfServiceCardNo = '00064',
  });

  int get totalCount => filteredByBranch.length;

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
    String? selectedDate,
    int? Function()? selectedBranchId,
    DailyAttendanceState? Function()? selectedStateFilter,
    String? searchQuery,
    List<Branch>? branches,
    List<Department>? departments,
    List<EmployeeDailyStatus>? dailyStatuses,
    bool? isPollingTerminal,
    bool? autoPollEnabled,
    int? autoPollMinutes,
    String? terminalStatusMessage,
    DriveSyncStatus? syncStatus,
    String? activeSelfServiceCardNo,
  }) {
    return PdksDashboardState(
      selectedDate: selectedDate ?? this.selectedDate,
      selectedBranchId:
          selectedBranchId != null ? selectedBranchId() : this.selectedBranchId,
      selectedStateFilter: selectedStateFilter != null
          ? selectedStateFilter()
          : this.selectedStateFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      branches: branches ?? this.branches,
      departments: departments ?? this.departments,
      dailyStatuses: dailyStatuses ?? this.dailyStatuses,
      isPollingTerminal: isPollingTerminal ?? this.isPollingTerminal,
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

  void refreshDashboard() {
    final branches = _db.getBranches();
    final departments = _db.getDepartments();
    final employees = _db.getEmployees();
    final logs = _db.getAttendanceLogsForDate(state.selectedDate);
    final leaves = _db.getLeaveRecordsForDate(state.selectedDate);

    final branchMap = {for (final b in branches) b.id: b};
    final deptMap = {for (final d in departments) d.id: d};
    final shiftMap = {for (final s in WorkplaceSeedData.shifts) s.id: s};
    final leaveMap = {for (final l in leaves) l.employeeId: l};

    final logsByCard = <String, List<AttendanceLog>>{};
    for (final log in logs) {
      logsByCard.putIfAbsent(log.cardNo, () => <AttendanceLog>[]).add(log);
    }

    final statuses = <EmployeeDailyStatus>[];
    for (final emp in employees) {
      final branch = branchMap[emp.branchId] ?? WorkplaceSeedData.branches.first;
      final dept = deptMap[emp.departmentId] ??
          const Department(id: 1, name: 'GENEL', branchId: 1);
      final shift = shiftMap[emp.shiftId] ?? WorkplaceSeedData.shifts.first;
      final empLogs = logsByCard[emp.cardNo] ?? const <AttendanceLog>[];
      final leave = leaveMap[emp.id];

      AttendanceLog? firstIn;
      AttendanceLog? lastOut;
      if (empLogs.isNotEmpty) {
        firstIn = empLogs.first;
        if (empLogs.length > 1) {
          lastOut = empLogs.last;
        }
      }

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
          leaveRecord: leave,
          lateMinutes: lateMins,
        ),
      );
    }

    state = state.copyWith(
      branches: branches,
      departments: departments,
      dailyStatuses: statuses,
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

  void toggleAutoPoll(bool enabled) {
    state = state.copyWith(
      autoPollEnabled: enabled,
      terminalStatusMessage: enabled
          ? 'Otomatik Tenfei D35 veri çekimi aktif (Her ${state.autoPollMinutes} dk)'
          : 'Otomatik Tenfei D35 veri çekimi duraklatıldı',
    );
    _configureAutoPollTimer();
  }

  void _configureAutoPollTimer() {
    _autoPollTimer?.cancel();
    _autoPollTimer = null;
    if (!state.autoPollEnabled) return;

    _autoPollTimer = Timer.periodic(
      Duration(minutes: state.autoPollMinutes),
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
        totalFetched += logs.length;
        newInserted += _db.upsertAttendanceLogsBatch(logs);
        messages.add('${branch.name} ($ip:${branch.terminalPort}): ${logs.length} kayıt');
      } catch (_) {
        messages.add(
          '${branch.name} ($ip:${branch.terminalPort}): Yerel ağ dışı — önbellek aktif',
        );
      } finally {
        await client.dispose();
      }
    }

    refreshDashboard();
    final syncResult = await _syncService.pushToCloud(
      deviceName: 'Hasibu Masaüstü (Tenfei D35 Köprüsü)',
    );

    state = state.copyWith(
      isPollingTerminal: false,
      terminalStatusMessage: messages.isEmpty
          ? 'Aktif terminal tanımlı değil.'
          : '${messages.join(' | ')} ($newInserted yeni, toplam $totalFetched)',
      syncStatus: syncResult,
    );
  }

  /// Şube terminali IP/Port yapılandırmasını günceller.
  void updateBranchTerminalConfig({
    required int branchId,
    required String ip,
    required int port,
    required bool enabled,
  }) {
    _db.updateBranchTerminal(
      branchId: branchId,
      terminalIp: ip.trim(),
      terminalPort: port,
      hasTerminal: enabled,
    );
    refreshDashboard();
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
  }) async {
    final record = LeaveRecord(
      id: 'leave_${employeeId}_${state.selectedDate}',
      employeeId: employeeId,
      date: state.selectedDate,
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
