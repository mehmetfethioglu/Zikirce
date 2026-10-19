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
      CREATE TABLE IF NOT EXISTS company_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        company_name TEXT NOT NULL DEFAULT 'HASİBU İŞLETME YÖNETİMİ',
        auto_poll_enabled INTEGER NOT NULL DEFAULT 1,
        auto_poll_minutes INTEGER NOT NULL DEFAULT 5,
        admin_username TEXT NOT NULL DEFAULT 'admin',
        admin_password TEXT NOT NULL DEFAULT '123',
        default_employee_pin TEXT NOT NULL DEFAULT '1234',
        sync_gmail_account TEXT NOT NULL DEFAULT '',
        sync_folder_path TEXT NOT NULL DEFAULT ''
      );
    ''');

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

      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        tolerance_minutes INTEGER NOT NULL DEFAULT 15
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
        kpi_score REAL NOT NULL DEFAULT 92.0,
        password TEXT NOT NULL DEFAULT '1234',
        allowed_modules TEXT NOT NULL DEFAULT 'employeePortal',
        photo_path TEXT
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

    // Mevcut veritabanı yükseltmesi (migration)
    for (final colSql in <String>[
      "ALTER TABLE company_settings ADD COLUMN admin_username TEXT NOT NULL DEFAULT 'admin'",
      "ALTER TABLE company_settings ADD COLUMN admin_password TEXT NOT NULL DEFAULT '123'",
      "ALTER TABLE company_settings ADD COLUMN default_employee_pin TEXT NOT NULL DEFAULT '1234'",
      "ALTER TABLE company_settings ADD COLUMN sync_gmail_account TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE company_settings ADD COLUMN sync_folder_path TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE employees ADD COLUMN password TEXT NOT NULL DEFAULT '1234'",
      "ALTER TABLE employees ADD COLUMN allowed_modules TEXT NOT NULL DEFAULT 'employeePortal'",
      "ALTER TABLE employees ADD COLUMN photo_path TEXT",
    ]) {
      try {
        _db.execute(colSql);
      } catch (_) {}
    }
  }

  void _seedIfEmpty() {
    // 1. Şirket ayarları yoksa varsayılan satırı ekle
    final settingsCount =
        _db.select('SELECT COUNT(*) AS cnt FROM company_settings').first['cnt']
                as int? ??
            0;
    if (settingsCount == 0) {
      _db.execute('''
        INSERT INTO company_settings
        (id, company_name, auto_poll_enabled, auto_poll_minutes, admin_username, admin_password, default_employee_pin, sync_gmail_account, sync_folder_path)
        VALUES (1, 'HASİBU İŞLETME YÖNETİMİ', 1, 5, 'admin', '123', '1234', '', '')
      ''');
    }

    // 2. Vardiyalar yoksa tohumla (mevcut veritabanı yükseltmesi için bağımsız kontrol)
    final shiftsCount =
        _db.select('SELECT COUNT(*) AS cnt FROM shifts').first['cnt'] as int? ??
            0;
    if (shiftsCount == 0) {
      for (final s in WorkplaceSeedData.shifts) {
        upsertShift(s);
      }
    }

    // 3. Personeller doluysa diğer tohumlamaları atla
    final countRow = _db.select('SELECT COUNT(*) AS cnt FROM employees');
    final int count = countRow.first['cnt'] as int? ?? 0;
    if (count > 0) return;

    _db.execute('BEGIN TRANSACTION;');
    try {
      for (final b in WorkplaceSeedData.branches) {
        upsertBranch(b);
      }
      for (final d in WorkplaceSeedData.departments) {
        upsertDepartment(d);
      }
      for (final e in WorkplaceSeedData.activeEmployees) {
        upsertEmployee(e);
      }
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

  CompanySettings getCompanySettings() {
    final rows = _db.select('SELECT * FROM company_settings WHERE id = 1');
    if (rows.isEmpty) return const CompanySettings();
    final r = rows.first;
    return CompanySettings(
      companyName: r['company_name'] as String,
      autoPollEnabled: (r['auto_poll_enabled'] as int) == 1,
      autoPollMinutes: r['auto_poll_minutes'] as int,
      adminUsername: r['admin_username'] as String? ?? 'admin',
      adminPassword: r['admin_password'] as String? ?? '123',
      defaultEmployeePin: r['default_employee_pin'] as String? ?? '1234',
      syncGmailAccount: r['sync_gmail_account'] as String? ?? '',
      syncFolderPath: r['sync_folder_path'] as String? ?? '',
    );
  }

  void saveCompanySettings(CompanySettings settings) {
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO company_settings
      (id, company_name, auto_poll_enabled, auto_poll_minutes, admin_username, admin_password, default_employee_pin, sync_gmail_account, sync_folder_path)
      VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      settings.companyName.trim().isEmpty
          ? 'HASİBU İŞLETME YÖNETİMİ'
          : settings.companyName.trim(),
      settings.autoPollEnabled ? 1 : 0,
      settings.autoPollMinutes.clamp(1, 1440),
      settings.adminUsername.trim().isEmpty
          ? 'admin'
          : settings.adminUsername.trim(),
      settings.adminPassword.trim().isEmpty
          ? '123'
          : settings.adminPassword.trim(),
      settings.defaultEmployeePin.trim().isEmpty
          ? '1234'
          : settings.defaultEmployeePin.trim(),
      settings.syncGmailAccount.trim(),
      settings.syncFolderPath.trim(),
    ]);
    stmt.dispose();
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

  void upsertBranch(Branch b) {
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO branches
      (id, code, name, has_terminal, terminal_ip, terminal_port, machine_no, latitude, longitude, geofence_radius)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      b.id,
      b.code.trim().toUpperCase(),
      b.name.trim(),
      b.hasTerminal ? 1 : 0,
      b.terminalIp?.trim(),
      b.terminalPort,
      b.machineNo,
      b.latitude,
      b.longitude,
      b.geofenceRadiusMeters,
    ]);
    stmt.dispose();
  }

  void deleteBranch(int branchId) {
    if (branchId == 1) return; // Merkez şube silinmez
    final stmt = _db.prepare('DELETE FROM branches WHERE id = ?');
    stmt.execute([branchId]);
    stmt.dispose();
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

  List<ShiftPlan> getShifts() {
    final rows = _db.select('SELECT * FROM shifts ORDER BY id ASC');
    return rows
        .map(
          (r) => ShiftPlan(
            id: r['id'] as int,
            name: r['name'] as String,
            startTime: r['start_time'] as String,
            endTime: r['end_time'] as String,
            toleranceMinutes: r['tolerance_minutes'] as int,
          ),
        )
        .toList(growable: false);
  }

  void upsertShift(ShiftPlan s) {
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO shifts
      (id, name, start_time, end_time, tolerance_minutes)
      VALUES (?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      s.id,
      s.name.trim(),
      s.startTime.trim(),
      s.endTime.trim(),
      s.toleranceMinutes.clamp(0, 240),
    ]);
    stmt.dispose();
  }

  void deleteShift(int shiftId) {
    if (shiftId == 1) return; // Varsayılan vardiya silinmez
    final stmt = _db.prepare('DELETE FROM shifts WHERE id = ?');
    stmt.execute([shiftId]);
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

  void upsertDepartment(Department d) {
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO departments (id, name, branch_id, is_production_line)
      VALUES (?, ?, ?, ?)
    ''');
    stmt.execute([
      d.id,
      d.name.trim().toUpperCase(),
      d.branchId,
      d.isProductionLine ? 1 : 0,
    ]);
    stmt.dispose();
  }

  void deleteDepartment(int departmentId) {
    final stmt = _db.prepare('DELETE FROM departments WHERE id = ?');
    stmt.execute([departmentId]);
    stmt.dispose();
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
            password: (r['password'] as String?)?.isNotEmpty == true
                ? r['password'] as String
                : '1234',
            allowedModules:
                HasibuModule.parseCsv(r['allowed_modules'] as String?),
            photoPath: r['photo_path'] as String?,
          ),
        )
        .toList(growable: false);
  }

  void upsertEmployee(Employee e) {
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO employees
      (id, card_no, full_name, title, department_id, branch_id, shift_id, hire_date, sgk_active, annual_leave_entitlement, used_annual_leave, kpi_score, password, allowed_modules, photo_path)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      e.id,
      e.cardNo.trim().padLeft(5, '0'),
      e.fullName.trim().toUpperCase(),
      e.title.trim().toUpperCase(),
      e.departmentId,
      e.branchId,
      e.shiftId,
      e.hireDate.trim(),
      e.sgkActive ? 1 : 0,
      e.annualLeaveEntitlement,
      e.usedAnnualLeave,
      e.kpiScore,
      e.password.trim().isEmpty ? '1234' : e.password.trim(),
      HasibuModule.toCsv(e.allowedModules),
      e.photoPath?.trim().isEmpty == true ? null : e.photoPath?.trim(),
    ]);
    stmt.dispose();
  }

  void deleteEmployee(int employeeId) {
    final stmt = _db.prepare('DELETE FROM employees WHERE id = ?');
    stmt.execute([employeeId]);
    stmt.dispose();
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

  /// Seçili personeller için belirtilen tarihte toplu giriş ve/veya çıkış hareketi uygular.
  int applyBulkManualAttendance({
    required List<Employee> employees,
    required String dateKey,
    String? checkInTime,
    String? checkOutTime,
    bool replaceExistingForDay = true,
  }) {
    if (employees.isEmpty) return 0;
    final dp = dateKey.split('-');
    final year = dp.isNotEmpty ? (int.tryParse(dp[0]) ?? 2026) : 2026;
    final month = dp.length > 1 ? (int.tryParse(dp[1]) ?? 10) : 10;
    final day = dp.length > 2 ? (int.tryParse(dp[2]) ?? 19) : 19;

    int affected = 0;
    _db.execute('BEGIN TRANSACTION;');
    try {
      final delStmt = _db.prepare(
        'DELETE FROM attendance_logs WHERE card_no = ? AND date_key = ?',
      );
      for (final emp in employees) {
        if (replaceExistingForDay) {
          delStmt.execute([emp.cardNo, dateKey]);
        }
        if (checkInTime != null && checkInTime.trim().isNotEmpty) {
          final tp = checkInTime.trim().split(':');
          final h = tp.isNotEmpty ? (int.tryParse(tp[0]) ?? 8) : 8;
          final m = tp.length > 1 ? (int.tryParse(tp[1]) ?? 0) : 0;
          final dt = DateTime(year, month, day, h, m);
          upsertAttendanceLog(
            AttendanceLog(
              id: 'BULK-IN-${emp.cardNo}-$dateKey-${h.toString().padLeft(2, '0')}${m.toString().padLeft(2, '0')}',
              cardNo: emp.cardNo,
              branchId: emp.branchId,
              deviceNo: 99,
              timestamp: dt,
              isCheckIn: true,
              source: AttendanceSource.manual,
              verifyMethod: VerifyMethod.password,
            ),
          );
          affected++;
        }
        if (checkOutTime != null && checkOutTime.trim().isNotEmpty) {
          final tp = checkOutTime.trim().split(':');
          final h = tp.isNotEmpty ? (int.tryParse(tp[0]) ?? 18) : 18;
          final m = tp.length > 1 ? (int.tryParse(tp[1]) ?? 0) : 0;
          final dt = DateTime(year, month, day, h, m);
          upsertAttendanceLog(
            AttendanceLog(
              id: 'BULK-OUT-${emp.cardNo}-$dateKey-${h.toString().padLeft(2, '0')}${m.toString().padLeft(2, '0')}',
              cardNo: emp.cardNo,
              branchId: emp.branchId,
              deviceNo: 99,
              timestamp: dt,
              isCheckIn: false,
              source: AttendanceSource.manual,
              verifyMethod: VerifyMethod.password,
            ),
          );
          affected++;
        }
      }
      delStmt.dispose();
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
    return affected;
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

  void deleteAttendanceLog(String logId) {
    final stmt = _db.prepare('DELETE FROM attendance_logs WHERE id = ?');
    stmt.execute([logId]);
    stmt.dispose();
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

  List<LeaveRecord> getAllLeaveRecords() {
    final rows = _db.select(
      'SELECT * FROM leave_records ORDER BY date_key DESC LIMIT 200',
    );
    return rows
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
    final allLogsRows = _db.select(
      'SELECT * FROM attendance_logs ORDER BY timestamp_iso DESC LIMIT 5000',
    );
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
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'deviceName': deviceName,
      'companySettings': getCompanySettings().toJson(),
      'branches': getBranches().map((e) => e.toJson()).toList(growable: false),
      'shifts': getShifts().map((e) => e.toJson()).toList(growable: false),
      'departments':
          getDepartments().map((e) => e.toJson()).toList(growable: false),
      'employees':
          getEmployees().map((e) => e.toJson()).toList(growable: false),
      'attendanceLogs': logs,
      'leaveRecords': leaves,
    };
  }

  /// Google Drive'dan gelen bulut yedeğini yerel veritabanı ile kayıpsız (Union Merge) uzlaştırır.
  int reconcileCloudSnapshot(Map<String, dynamic> snapshot) {
    int mergedCount = 0;
    _db.execute('BEGIN TRANSACTION;');
    try {
      final rawCompany = snapshot['companySettings'];
      if (rawCompany is Map<String, dynamic>) {
        saveCompanySettings(CompanySettings.fromJson(rawCompany));
      }

      final rawBranches = snapshot['branches'] as List<dynamic>? ?? const [];
      for (final item in rawBranches) {
        if (item is Map<String, dynamic>) {
          upsertBranch(Branch.fromJson(item));
        }
      }

      final rawShifts = snapshot['shifts'] as List<dynamic>? ?? const [];
      for (final item in rawShifts) {
        if (item is Map<String, dynamic>) {
          upsertShift(ShiftPlan.fromJson(item));
        }
      }

      final rawDepts = snapshot['departments'] as List<dynamic>? ?? const [];
      for (final item in rawDepts) {
        if (item is Map<String, dynamic>) {
          upsertDepartment(Department.fromJson(item));
        }
      }

      final rawEmployees = snapshot['employees'] as List<dynamic>? ?? const [];
      for (final item in rawEmployees) {
        if (item is Map<String, dynamic>) {
          upsertEmployee(Employee.fromJson(item));
        }
      }

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
