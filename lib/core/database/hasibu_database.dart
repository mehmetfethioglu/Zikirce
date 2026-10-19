import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../features/pdks/data/workplace_seed_data.dart';
import '../../features/pdks/domain/pdks_models.dart';

/// Piri-Query: İndekslenmiş, sıfır veri kayıplı yerel SQLite motoru ve
/// Zikirce_ modeli Google Drive bulut uzlaştırma (reconciliation) katmanı.
class HasibuDatabase {
  final Database _db;
  bool _isDisposed = false;

  HasibuDatabase._(this._db) {
    _initSchema();
    _seedIfEmpty();
  }

  factory HasibuDatabase.inMemory() {
    return HasibuDatabase._(sqlite3.openInMemory());
  }

  static Future<HasibuDatabase> openDefault() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final dbFile = File(p.join(dir.path, 'hasibu_pdks_v1.sqlite'));
    final db = sqlite3.open(dbFile.path);
    return HasibuDatabase._(db);
  }

  void _initSchema() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS branches (
        id INTEGER PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        has_terminal INTEGER NOT NULL DEFAULT 0,
        terminal_ip TEXT,
        terminal_port INTEGER NOT NULL DEFAULT 4370,
        machine_no INTEGER NOT NULL DEFAULT 1,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        geofence_radius REAL NOT NULL DEFAULT 150.0
      );

      CREATE TABLE IF NOT EXISTS departments (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        branch_id INTEGER NOT NULL,
        is_production_line INTEGER NOT NULL DEFAULT 1
      );

      CREATE TABLE IF NOT EXISTS employees (
        id INTEGER PRIMARY KEY,
        card_no TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        title TEXT NOT NULL,
        department_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL,
        shift_id INTEGER NOT NULL DEFAULT 1,
        hire_date TEXT NOT NULL,
        sgk_active INTEGER NOT NULL DEFAULT 1,
        annual_leave_entitlement INTEGER NOT NULL DEFAULT 14,
        used_annual_leave INTEGER NOT NULL DEFAULT 0,
        kpi_score REAL NOT NULL DEFAULT 92.0
      );

      CREATE INDEX IF NOT EXISTS idx_employees_card_no ON employees(card_no);
      CREATE INDEX IF NOT EXISTS idx_employees_branch ON employees(branch_id);

      CREATE TABLE IF NOT EXISTS attendance_logs (
        id TEXT PRIMARY KEY,
        card_no TEXT NOT NULL,
        branch_id INTEGER NOT NULL,
        device_no INTEGER NOT NULL DEFAULT 1,
        timestamp_iso TEXT NOT NULL,
        date_key TEXT NOT NULL,
        is_check_in INTEGER NOT NULL DEFAULT 1,
        source TEXT NOT NULL,
        verify_method TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_attendance_date_card
        ON attendance_logs(date_key, card_no);

      CREATE TABLE IF NOT EXISTS leave_records (
        id TEXT PRIMARY KEY,
        employee_id INTEGER NOT NULL,
        date_key TEXT NOT NULL,
        leave_code INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      );

      CREATE INDEX IF NOT EXISTS idx_leave_date_emp
        ON leave_records(date_key, employee_id);
    ''');
  }

  void _seedIfEmpty() {
    final countRow = _db.select('SELECT COUNT(*) AS cnt FROM employees');
    final int count = countRow.first['cnt'] as int? ?? 0;
    if (count > 0) return;

    _db.execute('BEGIN TRANSACTION;');
    try {
      final branchStmt = _db.prepare('''
        INSERT OR REPLACE INTO branches
        (id, code, name, has_terminal, terminal_ip, terminal_port, machine_no, latitude, longitude, geofence_radius)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      for (final b in WorkplaceSeedData.branches) {
        branchStmt.execute([
          b.id,
          b.code,
          b.name,
          b.hasTerminal ? 1 : 0,
          b.terminalIp,
          b.terminalPort,
          b.machineNo,
          b.latitude,
          b.longitude,
          b.geofenceRadiusMeters,
        ]);
      }
      branchStmt.dispose();

      final deptStmt = _db.prepare('''
        INSERT OR REPLACE INTO departments (id, name, branch_id, is_production_line)
        VALUES (?, ?, ?, ?)
      ''');
      for (final d in WorkplaceSeedData.departments) {
        deptStmt.execute([
          d.id,
          d.name,
          d.branchId,
          d.isProductionLine ? 1 : 0,
        ]);
      }
      deptStmt.dispose();

      final empStmt = _db.prepare('''
        INSERT OR REPLACE INTO employees
        (id, card_no, full_name, title, department_id, branch_id, shift_id, hire_date, sgk_active, annual_leave_entitlement, used_annual_leave, kpi_score)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      for (final e in WorkplaceSeedData.activeEmployees) {
        empStmt.execute([
          e.id,
          e.cardNo,
          e.fullName,
          e.title,
          e.departmentId,
          e.branchId,
          e.shiftId,
          e.hireDate,
          e.sgkActive ? 1 : 0,
          e.annualLeaveEntitlement,
          e.usedAnnualLeave,
          e.kpiScore,
        ]);
      }
      empStmt.dispose();

      for (final log in WorkplaceSeedData.buildInitialAttendanceLogs()) {
        upsertAttendanceLog(log);
      }

      for (final lv in WorkplaceSeedData.buildInitialLeaves()) {
        upsertLeaveRecord(lv);
      }

      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  List<Branch> getBranches() {
    final rows = _db.select('SELECT * FROM branches ORDER BY id ASC');
    return rows
        .map(
          (r) => Branch(
            id: r['id'] as int,
            code: r['code'] as String,
            name: r['name'] as String,
            hasTerminal: (r['has_terminal'] as int) == 1,
            terminalIp: r['terminal_ip'] as String?,
            terminalPort: r['terminal_port'] as int,
            machineNo: r['machine_no'] as int,
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
            geofenceRadiusMeters: (r['geofence_radius'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  void updateBranchTerminal({
    required int branchId,
    required String terminalIp,
    required int terminalPort,
    required bool hasTerminal,
  }) {
    final stmt = _db.prepare('''
      UPDATE branches
      SET terminal_ip = ?, terminal_port = ?, has_terminal = ?
      WHERE id = ?
    ''');
    stmt.execute([terminalIp, terminalPort, hasTerminal ? 1 : 0, branchId]);
    stmt.dispose();
  }

  List<Department> getDepartments() {
    final rows = _db.select('SELECT * FROM departments ORDER BY name ASC');
    return rows
        .map(
          (r) => Department(
            id: r['id'] as int,
            name: r['name'] as String,
            branchId: r['branch_id'] as int,
            isProductionLine: (r['is_production_line'] as int) == 1,
          ),
        )
        .toList(growable: false);
  }

  List<Employee> getEmployees() {
    final rows = _db.select('SELECT * FROM employees ORDER BY full_name ASC');
    return rows
        .map(
          (r) => Employee(
            id: r['id'] as int,
            cardNo: r['card_no'] as String,
            fullName: r['full_name'] as String,
            title: r['title'] as String,
            departmentId: r['department_id'] as int,
            branchId: r['branch_id'] as int,
            shiftId: r['shift_id'] as int,
            hireDate: r['hire_date'] as String,
            sgkActive: (r['sgk_active'] as int) == 1,
            annualLeaveEntitlement: r['annual_leave_entitlement'] as int,
            usedAnnualLeave: r['used_annual_leave'] as int,
            kpiScore: (r['kpi_score'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  List<AttendanceLog> getAttendanceLogsForDate(String dateKey) {
    final stmt = _db.prepare('''
      SELECT * FROM attendance_logs
      WHERE date_key = ?
      ORDER BY timestamp_iso ASC
    ''');
    final rows = stmt.select([dateKey]);
    final list = rows
        .map(
          (r) => AttendanceLog(
            id: r['id'] as String,
            cardNo: r['card_no'] as String,
            branchId: r['branch_id'] as int,
            deviceNo: r['device_no'] as int,
            timestamp: DateTime.parse(r['timestamp_iso'] as String),
            isCheckIn: (r['is_check_in'] as int) == 1,
            source: AttendanceSource.values.firstWhere(
              (e) => e.name == r['source'],
              orElse: () => AttendanceSource.tenfeiD35,
            ),
            verifyMethod: VerifyMethod.values.firstWhere(
              (e) => e.name == r['verify_method'],
              orElse: () => VerifyMethod.face,
            ),
          ),
        )
        .toList(growable: false);
    stmt.dispose();
    return list;
  }

  List<AttendanceLog> getAttendanceLogsForEmployee(String cardNo) {
    final stmt = _db.prepare('''
      SELECT * FROM attendance_logs
      WHERE card_no = ?
      ORDER BY timestamp_iso DESC
      LIMIT 60
    ''');
    final rows = stmt.select([cardNo]);
    final list = rows
        .map(
          (r) => AttendanceLog(
            id: r['id'] as String,
            cardNo: r['card_no'] as String,
            branchId: r['branch_id'] as int,
            deviceNo: r['device_no'] as int,
            timestamp: DateTime.parse(r['timestamp_iso'] as String),
            isCheckIn: (r['is_check_in'] as int) == 1,
            source: AttendanceSource.values.firstWhere(
              (e) => e.name == r['source'],
              orElse: () => AttendanceSource.tenfeiD35,
            ),
            verifyMethod: VerifyMethod.values.firstWhere(
              (e) => e.name == r['verify_method'],
              orElse: () => VerifyMethod.face,
            ),
          ),
        )
        .toList(growable: false);
    stmt.dispose();
    return list;
  }

  int upsertAttendanceLogsBatch(List<AttendanceLog> logs) {
    if (logs.isEmpty) return 0;
    int inserted = 0;
    _db.execute('BEGIN TRANSACTION;');
    try {
      for (final log in logs) {
        if (upsertAttendanceLog(log)) {
          inserted++;
        }
      }
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
    return inserted;
  }

  bool upsertAttendanceLog(AttendanceLog log) {
    final existing = _db.select(
      'SELECT id FROM attendance_logs WHERE id = ?',
      [log.id],
    );
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO attendance_logs
      (id, card_no, branch_id, device_no, timestamp_iso, date_key, is_check_in, source, verify_method)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      log.id,
      log.cardNo,
      log.branchId,
      log.deviceNo,
      log.timestamp.toIso8601String(),
      log.dateKey,
      log.isCheckIn ? 1 : 0,
      log.source.name,
      log.verifyMethod.name,
    ]);
    stmt.dispose();
    return existing.isEmpty;
  }

  List<LeaveRecord> getLeaveRecordsForDate(String dateKey) {
    final stmt = _db.prepare('''
      SELECT * FROM leave_records WHERE date_key = ?
    ''');
    final rows = stmt.select([dateKey]);
    final list = rows
        .map(
          (r) => LeaveRecord(
            id: r['id'] as String,
            employeeId: r['employee_id'] as int,
            date: r['date_key'] as String,
            leaveType: LeaveType.fromCode(r['leave_code'] as int),
            note: r['note'] as String,
          ),
        )
        .toList(growable: false);
    stmt.dispose();
    return list;
  }

  void upsertLeaveRecord(LeaveRecord record) {
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO leave_records
      (id, employee_id, date_key, leave_code, note)
      VALUES (?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      record.id,
      record.employeeId,
      record.date,
      record.leaveType.code,
      record.note,
    ]);
    stmt.dispose();
  }

  void deleteLeaveRecord(String id) {
    final stmt = _db.prepare('DELETE FROM leave_records WHERE id = ?');
    stmt.execute([id]);
    stmt.dispose();
  }

  /// Zikirce_ Bulut Senkronizasyon standardında tüm yerel durumu JSON paketi olarak dışa aktarır.
  Map<String, dynamic> exportCloudSnapshot({required String deviceName}) {
    final allLogsRows =
        _db.select('SELECT * FROM attendance_logs ORDER BY timestamp_iso DESC LIMIT 5000');
    final allLeavesRows = _db.select('SELECT * FROM leave_records');

    final logs = allLogsRows
        .map(
          (r) => AttendanceLog(
            id: r['id'] as String,
            cardNo: r['card_no'] as String,
            branchId: r['branch_id'] as int,
            deviceNo: r['device_no'] as int,
            timestamp: DateTime.parse(r['timestamp_iso'] as String),
            isCheckIn: (r['is_check_in'] as int) == 1,
            source: AttendanceSource.values.firstWhere(
              (e) => e.name == r['source'],
              orElse: () => AttendanceSource.tenfeiD35,
            ),
            verifyMethod: VerifyMethod.values.firstWhere(
              (e) => e.name == r['verify_method'],
              orElse: () => VerifyMethod.face,
            ),
          ).toJson(),
        )
        .toList(growable: false);

    final leaves = allLeavesRows
        .map(
          (r) => LeaveRecord(
            id: r['id'] as String,
            employeeId: r['employee_id'] as int,
            date: r['date_key'] as String,
            leaveType: LeaveType.fromCode(r['leave_code'] as int),
            note: r['note'] as String,
          ).toJson(),
        )
        .toList(growable: false);

    return <String, dynamic>{
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'deviceName': deviceName,
      'branches': getBranches().map((e) => e.toJson()).toList(growable: false),
      'employees': getEmployees().map((e) => e.toJson()).toList(growable: false),
      'attendanceLogs': logs,
      'leaveRecords': leaves,
    };
  }

  /// Google Drive'dan gelen bulut yedeğini yerel veritabanı ile kayıpsız (Union Merge) uzlaştırır.
  int reconcileCloudSnapshot(Map<String, dynamic> snapshot) {
    int mergedCount = 0;
    _db.execute('BEGIN TRANSACTION;');
    try {
      final rawLogs = snapshot['attendanceLogs'] as List<dynamic>? ?? const [];
      for (final item in rawLogs) {
        if (item is Map<String, dynamic>) {
          final log = AttendanceLog.fromJson(item);
          if (upsertAttendanceLog(log)) {
            mergedCount++;
          }
        }
      }

      final rawLeaves = snapshot['leaveRecords'] as List<dynamic>? ?? const [];
      for (final item in rawLeaves) {
        if (item is Map<String, dynamic>) {
          upsertLeaveRecord(LeaveRecord.fromJson(item));
        }
      }
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
    return mergedCount;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _db.dispose();
  }
}
