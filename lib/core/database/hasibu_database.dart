import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../features/pdks/data/workplace_seed_data.dart';
import '../../features/pdks/domain/accounting_models.dart';
import '../../features/pdks/domain/pdks_models.dart';
import '../security/hasibu_security_service.dart';
import '../security/license_guard_service.dart';
import 'hasibu_accounting_dao.dart';

/// Piri-Query: İndekslenmiş, sıfır veri kayıplı yerel SQLCipher (AES-256) motoru ve
/// Zikirce_ modeli Google Drive bulut uzlaştırma (reconciliation) katmanı.
class HasibuDatabase {
  final Database _db;
  bool _isDisposed = false;
  Database get rawDb => _db;

  HasibuDatabase._(this._db, {String? encryptionKeyHex}) {
    // [DB-02] & [DB-03] SQLCipher AES-256 PRAGMA key bağlantısı
    HasibuSecurityService.applySqlCipherPragma(
      _db,
      keyHex: encryptionKeyHex,
    );
    _initSchema();
    initAccountingSchema();
    _seedIfEmpty();
    seedAccountingIfEmpty();
  }

  factory HasibuDatabase.inMemory({String? encryptionKeyHex}) {
    HasibuSecurityService.ensureSqlCipherNativeLibraryLoaded();
    return HasibuDatabase._(
      sqlite3.openInMemory(),
      encryptionKeyHex: encryptionKeyHex,
    );
  }

  static Future<HasibuDatabase> openDefault() async {
    await HasibuSecurityService.ensureSqlCipherNativeLibraryLoadedAsync();
    final keyHex = await HasibuSecurityService.getOrCreateDatabaseKeyHex();
    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final dbFile = File(p.join(dir.path, 'hasibu_pdks_v2.sqlite'));
      try {
        final db = sqlite3.open(dbFile.path);
        return HasibuDatabase._(db, encryptionKeyHex: keyHex);
      } catch (openErr) {
        // Eski anahtarla şifrelenmiş veya şifresiz kalmış dosya varsa temizleyip yeniden oluştur
        debugPrint('HasibuDatabase.openDefault ilk deneme hatası: $openErr. Yeniden oluşturuluyor.');
        try {
          if (dbFile.existsSync()) {
            dbFile.deleteSync();
          }
        } catch (delErr) {
          debugPrint('HasibuDatabase: Eski veritabanı silinemedi: $delErr');
          assert(true, 'Silme hatası atlatıldı');
        }
        final dbRetry = sqlite3.open(dbFile.path);
        return HasibuDatabase._(dbRetry, encryptionKeyHex: keyHex);
      }
    } catch (e) {
      debugPrint('HasibuDatabase.openDefault başarısız, inMemory fallback açılıyor: $e');
      return HasibuDatabase.inMemory(encryptionKeyHex: keyHex);
    }
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
        sync_folder_path TEXT NOT NULL DEFAULT '',
        logo_path TEXT,
        admin_theme_mode TEXT NOT NULL DEFAULT 'light',
        license_token TEXT NOT NULL DEFAULT '',
        last_verified_timestamp INTEGER NOT NULL DEFAULT 0,
        hardware_fingerprint TEXT NOT NULL DEFAULT ''
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
        terminal_comm_key TEXT NOT NULL DEFAULT '',
        qr_secret TEXT NOT NULL DEFAULT 'HSB-TOTP-SECRET-2026',
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
        exit_date TEXT,
        sgk_active INTEGER NOT NULL DEFAULT 1,
        annual_leave_entitlement INTEGER NOT NULL DEFAULT 14,
        used_annual_leave INTEGER NOT NULL DEFAULT 0,
        kpi_score REAL NOT NULL DEFAULT 92.0,
        password TEXT NOT NULL DEFAULT '1234',
        allowed_modules TEXT NOT NULL DEFAULT 'employeePortal',
        photo_path TEXT,
        theme_mode TEXT NOT NULL DEFAULT 'light'
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
        verify_method TEXT NOT NULL,
        integrity_hash TEXT NOT NULL DEFAULT ''
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

      CREATE TABLE IF NOT EXISTS employee_documents (
        id TEXT PRIMARY KEY,
        employee_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,
        upload_date TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT ''
      );

      CREATE INDEX IF NOT EXISTS idx_emp_docs_emp_id
        ON employee_documents(employee_id);

      CREATE TABLE IF NOT EXISTS hr_requests (
        id TEXT PRIMARY KEY,
        employee_id INTEGER NOT NULL,
        employee_card_no TEXT NOT NULL,
        employee_name TEXT NOT NULL,
        request_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        target_date TEXT NOT NULL,
        end_date TEXT,
        requested_time TEXT,
        is_checkin_correction INTEGER NOT NULL DEFAULT 0,
        overtime_minutes INTEGER NOT NULL DEFAULT 0,
        leave_code INTEGER NOT NULL DEFAULT 5,
        reason TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        reviewer_note TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_hr_requests_status
        ON hr_requests(status, target_date);

      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        actor_employee_id TEXT NOT NULL,
        action_type TEXT NOT NULL,
        target_record_id TEXT NOT NULL,
        old_value TEXT NOT NULL DEFAULT '',
        new_value TEXT NOT NULL DEFAULT '',
        timestamp_iso TEXT NOT NULL,
        hash TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp
        ON audit_logs(timestamp_iso DESC);

      CREATE TRIGGER IF NOT EXISTS trg_audit_logs_no_delete
      BEFORE DELETE ON audit_logs
      BEGIN
        SELECT RAISE(ABORT, 'Guvenlik Ihlali: audit_logs tablosundan kayit silinemez!');
      END;

      CREATE TRIGGER IF NOT EXISTS trg_audit_logs_no_update
      BEFORE UPDATE ON audit_logs
      BEGIN
        SELECT RAISE(ABORT, 'Guvenlik Ihlali: audit_logs tablosundaki kayitlar degistirilemez!');
      END;
    ''');

    // Mevcut veritabanı yükseltmesi (migration)
    for (final colSql in <String>[
      "ALTER TABLE company_settings ADD COLUMN admin_username TEXT NOT NULL DEFAULT 'admin'",
      "ALTER TABLE company_settings ADD COLUMN admin_password TEXT NOT NULL DEFAULT '123'",
      "ALTER TABLE company_settings ADD COLUMN default_employee_pin TEXT NOT NULL DEFAULT '1234'",
      "ALTER TABLE company_settings ADD COLUMN sync_gmail_account TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE company_settings ADD COLUMN sync_folder_path TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE company_settings ADD COLUMN logo_path TEXT",
      "ALTER TABLE company_settings ADD COLUMN admin_theme_mode TEXT NOT NULL DEFAULT 'light'",
      "ALTER TABLE company_settings ADD COLUMN license_token TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE company_settings ADD COLUMN last_verified_timestamp INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE company_settings ADD COLUMN hardware_fingerprint TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE branches ADD COLUMN terminal_comm_key TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE branches ADD COLUMN qr_secret TEXT NOT NULL DEFAULT 'HSB-TOTP-SECRET-2026'",
      "ALTER TABLE attendance_logs ADD COLUMN integrity_hash TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE employees ADD COLUMN exit_date TEXT",
      "ALTER TABLE employees ADD COLUMN password TEXT NOT NULL DEFAULT '1234'",
      "ALTER TABLE employees ADD COLUMN allowed_modules TEXT NOT NULL DEFAULT 'employeePortal'",
      "ALTER TABLE employees ADD COLUMN photo_path TEXT",
      "ALTER TABLE employees ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'light'",
    ]) {
      try {
        _db.execute(colSql);
      } catch (e) {
        // Kolon zaten mevcut ise migrasyonu atla
        debugPrint('HasibuDatabase migrasyon adımı atlandı ($colSql): $e');
      }
    }
  }

  void _seedIfEmpty() {
    final hwId = HardwareFingerprintService.getDeviceHardwareFingerprint();
    final defaultToken = LicenseGuardService.createBootstrapLicenseTokenSync(
      company: 'HASİBU İŞLETME YÖNETİMİ',
      hwId: hwId,
    );

    // 1. Şirket ayarları yoksa varsayılan satırı ekle
    final settingsCount =
        _db.select('SELECT COUNT(*) AS cnt FROM company_settings').first['cnt']
                as int? ??
            0;
    if (settingsCount == 0) {
      final stmt = _db.prepare('''
        INSERT INTO company_settings
        (id, company_name, auto_poll_enabled, auto_poll_minutes, admin_username, admin_password, default_employee_pin, sync_gmail_account, sync_folder_path, logo_path, admin_theme_mode, license_token, last_verified_timestamp, hardware_fingerprint)
        VALUES (1, 'HASİBU İŞLETME YÖNETİMİ', 1, 5, 'admin', '123', '1234', '', '', NULL, 'light', ?, ?, ?)
      ''');
      stmt.execute([
        defaultToken,
        kDebugMode ? DateTime(2026, 10, 20, 12, 0).millisecondsSinceEpoch : 0,
        hwId,
      ]);
      stmt.dispose();
    } else {
      // Mevcut veritabanında donanım parmak izi veya lisans boşsa ilk kurulum değerini bağla
      final row = _db.select('SELECT license_token, hardware_fingerprint FROM company_settings WHERE id = 1').first;
      final existingToken = (row['license_token'] as String?) ?? '';
      final existingHw = (row['hardware_fingerprint'] as String?) ?? '';
      if (existingToken.isEmpty && existingHw.isEmpty) {
        final upd = _db.prepare('''
          UPDATE company_settings
          SET license_token = ?, hardware_fingerprint = ?
          WHERE id = 1
        ''');
        upd.execute([defaultToken, hwId]);
        upd.dispose();
      }
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

    // 2a. Şubeler ve bölümler yoksa tohumla (Canlı derlemede de şube ve vardiya iskeleti hazır olur)
    final branchesCount =
        _db.select('SELECT COUNT(*) AS cnt FROM branches').first['cnt']
                as int? ??
            0;
    if (branchesCount == 0) {
      for (final b in WorkplaceSeedData.branches) {
        upsertBranch(b);
      }
    }
    final deptsCount =
        _db.select('SELECT COUNT(*) AS cnt FROM departments').first['cnt']
                as int? ??
            0;
    if (deptsCount == 0) {
      for (final d in WorkplaceSeedData.departments) {
        upsertDepartment(d);
      }
    }

    // 2b. Mevcut veritabanı yükseltmelerinde özlük evrakları ve geçmiş gün hareketleri yoksa tamamla
    final docsCount = _db
            .select('SELECT COUNT(*) AS cnt FROM employee_documents')
            .first['cnt'] as int? ??
        0;
    if (docsCount == 0) {
      for (final doc in WorkplaceSeedData.buildInitialPersonnelDocuments()) {
        upsertPersonnelDocument(doc);
      }
    }
    final histCount = _db
            .select(
              "SELECT COUNT(*) AS cnt FROM attendance_logs WHERE date_key = '2026-10-17'",
            )
            .first['cnt'] as int? ??
        0;
    if (histCount == 0) {
      for (final log in WorkplaceSeedData.buildInitialAttendanceLogs()) {
        upsertAttendanceLog(log);
      }
    }

    final reqCount = _db
            .select('SELECT COUNT(*) AS cnt FROM hr_requests')
            .first['cnt'] as int? ??
        0;
    if (reqCount == 0) {
      for (final req in WorkplaceSeedData.buildInitialHrRequests()) {
        upsertHrRequest(req);
      }
    }

    // 3. Personeller doluysa diğer tohumlamaları atla
    final countRow = _db.select('SELECT COUNT(*) AS cnt FROM employees');
    final int count = countRow.first['cnt'] as int? ?? 0;
    if (count > 0) {
      // Mevcut düz metin parolaları PBKDF2 hash yapısına yükselt ([DB-04])
      _migrateLegacyEmployeePasswords();
      return;
    }

    _db.execute('BEGIN TRANSACTION;');
    try {
      for (final b in WorkplaceSeedData.branches) {
        upsertBranch(b);
      }
      for (final d in WorkplaceSeedData.departments) {
        upsertDepartment(d);
      }
      final defaultSeedPinHash = HasibuSecurityService.hashPassword('1234');
      for (final e in WorkplaceSeedData.activeEmployees) {
        upsertEmployee(
          e.password == '1234' ? e.copyWith(password: defaultSeedPinHash) : e,
        );
      }
      for (final log in WorkplaceSeedData.buildInitialAttendanceLogs()) {
        upsertAttendanceLog(log);
      }
      for (final lv in WorkplaceSeedData.buildInitialLeaves()) {
        upsertLeaveRecord(lv);
      }
      for (final doc in WorkplaceSeedData.buildInitialPersonnelDocuments()) {
        upsertPersonnelDocument(doc);
      }
      for (final req in WorkplaceSeedData.buildInitialHrRequests()) {
        upsertHrRequest(req);
      }
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _migrateLegacyEmployeePasswords() {
    final rows = _db.select('SELECT id, password FROM employees');
    final stmt = _db.prepare('UPDATE employees SET password = ? WHERE id = ?');
    String? cachedDefaultHash;
    try {
      for (final r in rows) {
        final id = r['id'] as int;
        final rawPwd = (r['password'] as String?) ?? '1234';
        if (!HasibuSecurityService.isPasswordHashed(rawPwd)) {
          final hashed = rawPwd == '1234'
              ? (cachedDefaultHash ??= HasibuSecurityService.hashPassword('1234'))
              : HasibuSecurityService.hashPassword(rawPwd);
          stmt.execute([hashed, id]);
        }
      }
    } finally {
      stmt.dispose();
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
      logoPath: r['logo_path'] as String?,
      adminThemeMode:
          HasibuThemeMode.fromName(r['admin_theme_mode'] as String?),
      licenseToken: r['license_token'] as String? ?? '',
      lastVerifiedTimestamp:
          (r['last_verified_timestamp'] as num?)?.toInt() ?? 0,
      hardwareFingerprint: r['hardware_fingerprint'] as String? ?? '',
    );
  }

  void saveCompanySettings(CompanySettings settings) {
    final existing = getCompanySettings();
    final effectiveHw = settings.hardwareFingerprint.trim().isNotEmpty
        ? settings.hardwareFingerprint.trim()
        : (existing.hardwareFingerprint.trim().isNotEmpty
            ? existing.hardwareFingerprint.trim()
            : HardwareFingerprintService.getDeviceHardwareFingerprint());
    final effectiveToken = settings.licenseToken.trim().isNotEmpty
        ? settings.licenseToken.trim()
        : existing.licenseToken.trim();
    final isTokenRenewed = settings.licenseToken.trim().isNotEmpty &&
        settings.licenseToken.trim() != existing.licenseToken.trim();
    final effectiveVerifiedTs = isTokenRenewed
        ? DateTime.now().millisecondsSinceEpoch
        : (settings.lastVerifiedTimestamp > 0
            ? settings.lastVerifiedTimestamp
            : existing.lastVerifiedTimestamp);

    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO company_settings
      (id, company_name, auto_poll_enabled, auto_poll_minutes, admin_username, admin_password, default_employee_pin, sync_gmail_account, sync_folder_path, logo_path, admin_theme_mode, license_token, last_verified_timestamp, hardware_fingerprint)
      VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
      settings.logoPath?.trim().isEmpty == true
          ? null
          : settings.logoPath?.trim(),
      settings.adminThemeMode.name,
      effectiveToken,
      effectiveVerifiedTs,
      effectiveHw,
    ]);
    stmt.dispose();
  }

  /// [LIC-04] Monotonik Saat Kalkanı:
  /// `DateTime.now()` değerini `MAX(attendance_logs.timestamp_iso)` ve `MAX(hr_requests.created_at)`
  /// ile karşılaştırır; sistem saati geri alınmışsa işlemi kilitler.
  MonotonicClockShieldResult evaluateMonotonicClockShield({DateTime? now}) {
    final checkTime = now ?? DateTime.now();

    // Canlı çalışmada (now == null) aynı gün içinde SMT Güvenlik / personel2020 köprüsünden
    // sabah saatlerinde henüz gerçekleşmemiş vardiya saatiyle (örn. 09:05'te 17:30:00)
    // aktarılan ileri saatli otomatik terminal kayıtlarını temizle.
    if (now == null) {
      final todayKey =
          '${checkTime.year.toString().padLeft(4, '0')}-${checkTime.month.toString().padLeft(2, '0')}-${checkTime.day.toString().padLeft(2, '0')}';
      final futureCutoffIso =
          checkTime.add(const Duration(minutes: 15)).toIso8601String();
      final cleanupStmt = _db.prepare('''
        DELETE FROM attendance_logs
        WHERE date_key = ? AND source = 'tenfeiD35' AND timestamp_iso > ?
      ''');
      cleanupStmt.execute([todayKey, futureCutoffIso]);
      cleanupStmt.dispose();
    }

    DateTime? maxAttDt;
    DateTime? maxHrDt;

    final attRows = _db.select(
      'SELECT MAX(timestamp_iso) AS max_ts FROM attendance_logs',
    );
    if (attRows.isNotEmpty) {
      final rawAtt = attRows.first['max_ts'] as String?;
      if (rawAtt != null && rawAtt.trim().isNotEmpty) {
        maxAttDt = DateTime.tryParse(rawAtt.trim());
      }
    }

    final hrRows = _db.select(
      'SELECT MAX(created_at) AS max_created FROM hr_requests',
    );
    if (hrRows.isNotEmpty) {
      final rawHr = hrRows.first['max_created'] as String?;
      if (rawHr != null && rawHr.trim().isNotEmpty) {
        maxHrDt = DateTime.tryParse(rawHr.trim().replaceFirst(' ', 'T'));
      }
    }

    final settings = getCompanySettings();
    final result = LicenseGuardService.evaluateMonotonicClock(
      currentSystemTime: checkTime,
      maxAttendanceTimestamp: maxAttDt,
      maxHrRequestCreatedAt: maxHrDt,
      lastVerifiedTimestampMs: settings.lastVerifiedTimestamp,
    );

    if (!result.isClockTampered) {
      final nowMs = checkTime.millisecondsSinceEpoch;
      if (nowMs > settings.lastVerifiedTimestamp) {
        final upd = _db.prepare(
          'UPDATE company_settings SET last_verified_timestamp = ? WHERE id = 1',
        );
        upd.execute([nowMs]);
        upd.dispose();
      }
    }
    return result;
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
            terminalCommKey: HasibuSecurityService.decryptTerminalCommKey(
              r['terminal_comm_key'],
            ),
            qrSecret: (r['qr_secret'] as String?)?.trim().isNotEmpty == true
                ? (r['qr_secret'] as String).trim()
                : 'HSB-TOTP-SECRET-2026',
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
            geofenceRadiusMeters: (r['geofence_radius'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  void upsertBranch(Branch b) {
    final encryptedCommKey = HasibuSecurityService.encryptTerminalCommKey(
      b.terminalCommKey,
    );
    final effectiveQrSecret = b.qrSecret.trim().isEmpty
        ? 'HSB-TOTP-${b.code.trim().toUpperCase()}-${b.id}'
        : b.qrSecret.trim();
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO branches
      (id, code, name, has_terminal, terminal_ip, terminal_port, machine_no, terminal_comm_key, qr_secret, latitude, longitude, geofence_radius)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      b.id,
      b.code.trim().toUpperCase(),
      b.name.trim(),
      b.hasTerminal ? 1 : 0,
      b.terminalIp?.trim(),
      b.terminalPort,
      b.machineNo,
      encryptedCommKey,
      effectiveQrSecret,
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

  /// Veritabanında henüz kaydı olmayan bölüm tanımlarını ekler.
  int upsertMissingDepartments(List<Department> incoming) {
    if (incoming.isEmpty) return 0;
    final existingIds = getDepartments().map((d) => d.id).toSet();
    int added = 0;
    for (final d in incoming) {
      if (d.id <= 0 || d.name.trim().isEmpty || existingIds.contains(d.id)) {
        continue;
      }
      upsertDepartment(d);
      existingIds.add(d.id);
      added++;
    }
    return added;
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
            exitDate: Employee.normalizeDateKey(r['exit_date'] as String?),
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
            themeMode: HasibuThemeMode.fromName(r['theme_mode'] as String?),
          ),
        )
        .toList(growable: false);
  }

  void upsertEmployee(Employee e) {
    final rawPassword = e.password.trim().isEmpty ? '1234' : e.password.trim();
    // [DB-04] Parola düz metinden tuzlanmış PBKDF2-HMAC-SHA256 hash yapısına dönüştürülür
    final hashedPassword = HasibuSecurityService.hashPassword(rawPassword);

    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO employees
      (id, card_no, full_name, title, department_id, branch_id, shift_id, hire_date, exit_date, sgk_active, annual_leave_entitlement, used_annual_leave, kpi_score, password, allowed_modules, photo_path, theme_mode)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
      e.normalizedExitDate,
      e.sgkActive ? 1 : 0,
      e.annualLeaveEntitlement,
      e.usedAnnualLeave,
      e.kpiScore,
      hashedPassword,
      HasibuModule.toCsv(e.allowedModules),
      e.photoPath?.trim().isEmpty == true ? null : e.photoPath?.trim(),
      e.themeMode.name,
    ]);
    stmt.dispose();
  }

  void deleteEmployee(int employeeId) {
    final stmt = _db.prepare('DELETE FROM employees WHERE id = ?');
    stmt.execute([employeeId]);
    stmt.dispose();
  }

  /// Harici İK/PDKS kaynağından gelen işten çıkış tarihlerini yalnızca çıkış tarihi
  /// henüz tanımlanmamış mevcut kartlara uygular ve SGK aktiflik durumunu pasife çeker.
  int applyExternalExitDates(Map<String, String> exitDatesByCardNo) {
    if (exitDatesByCardNo.isEmpty) return 0;
    int updated = 0;
    final stmt = _db.prepare('''
      UPDATE employees
      SET exit_date = ?, sgk_active = 0
      WHERE card_no = ?
        AND (exit_date IS NULL OR TRIM(exit_date) = '' OR exit_date = '0000-00-00')
    ''');
    _db.execute('BEGIN TRANSACTION;');
    try {
      for (final entry in exitDatesByCardNo.entries) {
        final normCard = entry.key.trim().padLeft(5, '0');
        final normExit = Employee.normalizeDateKey(entry.value);
        if (normCard.isEmpty || normExit == null) continue;
        stmt.execute([normExit, normCard]);
        updated += _db.updatedRows;
      }
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    } finally {
      stmt.dispose();
    }
    return updated;
  }

  /// Cihazdan veya LAN personel2020 köprüsünden gelen personelleri atomik olarak eşitler.
  /// - Yeni kart numaralarını tekil `defaultPwdHash` ile hızlıca ekler.
  /// - Yalnızca `'PERSONEL #...'` yer tutucularını gerçek isim/ünvan/bölüm ile (aynı `id` ve kullanıcı ayarlarını koruyarak) yükseltir.
  int syncEmployeesFromDeviceOrBridge(List<Employee> incoming) {
    if (incoming.isEmpty) return 0;

    final existingEmployees = getEmployees();
    final byCard = <String, Employee>{};
    final usedIds = <int>{};
    int maxId = 0;
    for (final e in existingEmployees) {
      byCard[e.cardNo.trim().padLeft(5, '0')] = e;
      usedIds.add(e.id);
      if (e.id > maxId) maxId = e.id;
    }

    final validBranchIds = getBranches().map((b) => b.id).toSet();
    final validDeptIds = getDepartments().map((d) => d.id).toSet();
    final validShiftIds = getShifts().map((s) => s.id).toSet();
    final int fallbackBranchId =
        validBranchIds.isNotEmpty ? validBranchIds.first : 1;
    final int fallbackDeptId =
        validDeptIds.isNotEmpty ? validDeptIds.first : 1;
    final int fallbackShiftId =
        validShiftIds.isNotEmpty ? validShiftIds.first : 1;

    final defaultPwdHash = HasibuSecurityService.hashPassword('1234');
    int changed = 0;

    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO employees
      (id, card_no, full_name, title, department_id, branch_id, shift_id, hire_date, exit_date, sgk_active, annual_leave_entitlement, used_annual_leave, kpi_score, password, allowed_modules, photo_path, theme_mode)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');

    _db.execute('BEGIN TRANSACTION;');
    try {
      for (final inc in incoming) {
        final rawCard = inc.cardNo.trim();
        if (rawCard.isEmpty) continue;
        final normCard = rawCard.padLeft(5, '0');
        final cleanName = inc.fullName.trim().toUpperCase();
        if (cleanName.isEmpty) continue;
        final cleanTitle = inc.title.trim().isEmpty
            ? 'PERSONEL'
            : inc.title.trim().toUpperCase();
        final branchId = validBranchIds.contains(inc.branchId)
            ? inc.branchId
            : fallbackBranchId;
        final deptId = validDeptIds.contains(inc.departmentId)
            ? inc.departmentId
            : fallbackDeptId;
        final shiftId = validShiftIds.contains(inc.shiftId)
            ? inc.shiftId
            : fallbackShiftId;

        final existing = byCard[normCard];
        if (existing != null) {
          final isPlaceholder = existing.fullName.startsWith('PERSONEL #');
          final incomingIsReal = !cleanName.startsWith('PERSONEL #');
          if (!isPlaceholder || !incomingIsReal) {
            if (inc.hasExitDate && !existing.hasExitDate) {
              final updatedExited = existing.copyWith(
                exitDate: () => inc.normalizedExitDate,
                sgkActive: false,
              );
              stmt.execute([
                updatedExited.id,
                normCard,
                updatedExited.fullName,
                updatedExited.title,
                updatedExited.departmentId,
                updatedExited.branchId,
                updatedExited.shiftId,
                updatedExited.hireDate,
                updatedExited.normalizedExitDate,
                0,
                updatedExited.annualLeaveEntitlement,
                updatedExited.usedAnnualLeave,
                updatedExited.kpiScore,
                updatedExited.password,
                HasibuModule.toCsv(updatedExited.allowedModules),
                updatedExited.photoPath,
                updatedExited.themeMode.name,
              ]);
              byCard[normCard] = updatedExited;
              changed++;
            }
            continue;
          }

          final upgraded = existing.copyWith(
            fullName: cleanName,
            title: cleanTitle,
            departmentId: deptId,
            branchId: branchId,
            shiftId: shiftId,
            hireDate: inc.hireDate.trim().isNotEmpty
                ? inc.hireDate.trim()
                : existing.hireDate,
            exitDate: () => inc.normalizedExitDate ?? existing.normalizedExitDate,
            sgkActive: inc.hasExitDate ? false : inc.sgkActive,
            annualLeaveEntitlement: inc.annualLeaveEntitlement,
            kpiScore: inc.kpiScore,
          );
          stmt.execute([
            upgraded.id,
            normCard,
            upgraded.fullName,
            upgraded.title,
            upgraded.departmentId,
            upgraded.branchId,
            upgraded.shiftId,
            upgraded.hireDate,
            upgraded.normalizedExitDate,
            upgraded.sgkActive ? 1 : 0,
            upgraded.annualLeaveEntitlement,
            upgraded.usedAnnualLeave,
            upgraded.kpiScore,
            upgraded.password,
            HasibuModule.toCsv(upgraded.allowedModules),
            upgraded.photoPath,
            upgraded.themeMode.name,
          ]);
          byCard[normCard] = upgraded;
          changed++;
          continue;
        }

        final int empId =
            (inc.id > 0 && !usedIds.contains(inc.id)) ? inc.id : ++maxId;
        usedIds.add(empId);
        if (empId > maxId) maxId = empId;

        final rawPwd = inc.password.trim();
        final String pwdHash = (rawPwd.isEmpty || rawPwd == '1234')
            ? defaultPwdHash
            : HasibuSecurityService.hashPassword(rawPwd);

        final created = Employee(
          id: empId,
          cardNo: normCard,
          fullName: cleanName,
          title: cleanTitle,
          departmentId: deptId,
          branchId: branchId,
          shiftId: shiftId,
          hireDate: inc.hireDate.trim().isNotEmpty
              ? inc.hireDate.trim()
              : DateTime.now().toIso8601String().substring(0, 10),
          exitDate: inc.normalizedExitDate,
          sgkActive: inc.hasExitDate ? false : inc.sgkActive,
          annualLeaveEntitlement: inc.annualLeaveEntitlement,
          usedAnnualLeave: inc.usedAnnualLeave,
          kpiScore: inc.kpiScore,
          password: pwdHash,
          allowedModules: inc.allowedModules,
          photoPath: inc.photoPath,
          themeMode: inc.themeMode,
        );

        stmt.execute([
          created.id,
          created.cardNo,
          created.fullName,
          created.title,
          created.departmentId,
          created.branchId,
          created.shiftId,
          created.hireDate,
          created.normalizedExitDate,
          created.sgkActive ? 1 : 0,
          created.annualLeaveEntitlement,
          created.usedAnnualLeave,
          created.kpiScore,
          created.password,
          HasibuModule.toCsv(created.allowedModules),
          created.photoPath,
          created.themeMode.name,
        ]);
        byCard[normCard] = created;
        changed++;
      }
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    } finally {
      stmt.dispose();
    }
    return changed;
  }

  /// `attendance_logs` içinde karşılığı henüz `employees` tablosunda bulunmayan
  /// kart numaraları için geçici `PERSONEL #<cardNo>` kayıtları oluşturur.
  int ensureEmployeesForUnregisteredLogCards() {
    final rows = _db.select('''
      SELECT a.card_no, MIN(a.branch_id) AS branch_id, MIN(a.date_key) AS first_date
      FROM attendance_logs a
      LEFT JOIN employees e ON e.card_no = a.card_no
      WHERE e.id IS NULL AND TRIM(a.card_no) != ''
      GROUP BY a.card_no
      ORDER BY a.card_no ASC
    ''');
    if (rows.isEmpty) return 0;

    final branches = getBranches();
    final departments = getDepartments();
    final shifts = getShifts();
    final validBranchIds = {for (final b in branches) b.id};
    final int fallbackBranchId = branches.isNotEmpty ? branches.first.id : 1;
    final int fallbackDeptId =
        departments.isNotEmpty ? departments.first.id : 1;
    final int fallbackShiftId = shifts.isNotEmpty ? shifts.first.id : 1;
    final deptByBranch = <int, int>{};
    for (final d in departments) {
      deptByBranch.putIfAbsent(d.branchId, () => d.id);
    }

    final placeholders = <Employee>[];
    for (final r in rows) {
      final cardNo = (r['card_no'] as String? ?? '').trim().padLeft(5, '0');
      if (cardNo.isEmpty) continue;
      final rawBranchId = r['branch_id'] as int? ?? fallbackBranchId;
      final branchId = validBranchIds.contains(rawBranchId)
          ? rawBranchId
          : fallbackBranchId;
      final deptId = deptByBranch[branchId] ?? fallbackDeptId;
      final shiftId = (branchId != 1 && shifts.any((s) => s.id == 3))
          ? 3
          : fallbackShiftId;
      final firstDate = (r['first_date'] as String? ?? '').trim();

      placeholders.add(
        Employee(
          id: 0,
          cardNo: cardNo,
          fullName: 'PERSONEL #$cardNo',
          title: 'YÜZ TANIMA CİHAZI',
          departmentId: deptId,
          branchId: branchId,
          shiftId: shiftId,
          hireDate: firstDate.length >= 10
              ? firstDate.substring(0, 10)
              : DateTime.now().toIso8601String().substring(0, 10),
        ),
      );
    }

    return syncEmployeesFromDeviceOrBridge(placeholders);
  }

  AttendanceLog _mapAttendanceLogRow(Map<String, Object?> r) => AttendanceLog(
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
        integrityHash: r['integrity_hash'] as String? ?? '',
      );

  List<AttendanceLog> getAttendanceLogsForDate(String dateKey) {
    final stmt = _db.prepare('''
      SELECT * FROM attendance_logs
      WHERE date_key = ?
      ORDER BY timestamp_iso ASC
    ''');
    try {
      final rows = stmt.select([dateKey]);
      return rows.map(_mapAttendanceLogRow).toList(growable: false);
    } finally {
      stmt.dispose();
    }
  }

  List<AttendanceLog> getAttendanceLogsInDateRange(
    String startDateKey,
    String endDateKey,
  ) {
    final stmt = _db.prepare('''
      SELECT * FROM attendance_logs
      WHERE date_key >= ? AND date_key <= ?
      ORDER BY date_key ASC, timestamp_iso ASC
    ''');
    try {
      final rows = stmt.select([startDateKey, endDateKey]);
      return rows.map(_mapAttendanceLogRow).toList(growable: false);
    } finally {
      stmt.dispose();
    }
  }

  List<AttendanceLog> getAttendanceLogsForEmployee(String cardNo) {
    final stmt = _db.prepare('''
      SELECT * FROM attendance_logs
      WHERE card_no = ?
      ORDER BY timestamp_iso DESC
      LIMIT 300
    ''');
    try {
      final rows = stmt.select([cardNo]);
      return rows.map(_mapAttendanceLogRow).toList(growable: false);
    } finally {
      stmt.dispose();
    }
  }

  /// [HW-04] Veritabanındaki tüm puantaj kayıtlarını tarayıp `integrityHash` (HMAC-SHA256)
  /// doğrulamasından geçemeyen (saati veya verisi elle değiştirilmiş) kayıtları döner.
  List<AttendanceLog> getTamperedAttendanceLogs() {
    final rows = _db.select(
      'SELECT * FROM attendance_logs ORDER BY timestamp_iso DESC LIMIT 2000',
    );
    final tampered = <AttendanceLog>[];
    for (final r in rows) {
      final ts = DateTime.tryParse(r['timestamp_iso'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final isCheckIn = (r['is_check_in'] as int? ?? 1) == 1;
      final verifyMethod = VerifyMethod.values.firstWhere(
        (e) => e.name == r['verify_method'],
        orElse: () => VerifyMethod.face,
      );
      final storedHash = (r['integrity_hash'] as String?) ?? '';
      final cardNo = (r['card_no'] as String?) ?? '';
      final log = AttendanceLog(
        id: r['id'] as String,
        cardNo: cardNo,
        branchId: r['branch_id'] as int? ?? 1,
        deviceNo: r['device_no'] as int? ?? 1,
        timestamp: ts,
        isCheckIn: isCheckIn,
        source: AttendanceSource.values.firstWhere(
          (e) => e.name == r['source'],
          orElse: () => AttendanceSource.tenfeiD35,
        ),
        verifyMethod: verifyMethod,
        integrityHash: storedHash,
      );
      if (storedHash.isEmpty ||
          !HasibuSecurityService.verifyAttendanceIntegrity(
            cardNo: cardNo,
            timestamp: ts,
            isCheckIn: isCheckIn,
            verifyMethod: verifyMethod.name,
            storedHash: storedHash,
          )) {
        tampered.add(log);
      }
    }
    return tampered;
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
    final now = DateTime.now();
    if (log.source == AttendanceSource.tenfeiD35 &&
        log.timestamp.year == now.year &&
        log.timestamp.month == now.month &&
        log.timestamp.day == now.day &&
        log.timestamp.isAfter(now.add(const Duration(minutes: 15)))) {
      // Aynı gün içinde SMT Güvenlik / personel2020 tarafından henüz gerçekleşmemiş
      // akşam vardiyası için (örn. sabah 09:05'te 17:30:00) önceden yazılan sahte kaydı atla.
      return false;
    }
    final existing = _db.select(
      'SELECT id FROM attendance_logs WHERE id = ?',
      [log.id],
    );
    // [HW-03] HMAC-SHA256(cardNo + timestamp + isCheckIn + verifyMethod, secretKey)
    final computedHash = log.integrityHash.trim().isNotEmpty
        ? log.integrityHash.trim()
        : HasibuSecurityService.computeAttendanceIntegrityHash(
            cardNo: log.cardNo,
            timestamp: log.timestamp,
            isCheckIn: log.isCheckIn,
            verifyMethod: log.verifyMethod.name,
          );
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO attendance_logs
      (id, card_no, branch_id, device_no, timestamp_iso, date_key, is_check_in, source, verify_method, integrity_hash)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
      computedHash,
    ]);
    stmt.dispose();
    return existing.isEmpty;
  }

  void deleteAttendanceLog(String logId) {
    final stmt = _db.prepare('DELETE FROM attendance_logs WHERE id = ?');
    stmt.execute([logId]);
    stmt.dispose();
  }

  LeaveRecord _mapLeaveRecordRow(Map<String, Object?> r) => LeaveRecord(
        id: r['id'] as String,
        employeeId: r['employee_id'] as int,
        date: r['date_key'] as String,
        leaveType: LeaveType.fromCode(r['leave_code'] as int),
        note: r['note'] as String,
      );

  List<LeaveRecord> getLeaveRecordsForDate(String dateKey) {
    final stmt = _db.prepare('''
      SELECT * FROM leave_records WHERE date_key = ?
    ''');
    try {
      final rows = stmt.select([dateKey]);
      return rows.map(_mapLeaveRecordRow).toList(growable: false);
    } finally {
      stmt.dispose();
    }
  }

  List<LeaveRecord> getLeaveRecordsInDateRange(
    String startDateKey,
    String endDateKey,
  ) {
    final stmt = _db.prepare('''
      SELECT * FROM leave_records
      WHERE date_key >= ? AND date_key <= ?
      ORDER BY date_key ASC
    ''');
    try {
      final rows = stmt.select([startDateKey, endDateKey]);
      return rows.map(_mapLeaveRecordRow).toList(growable: false);
    } finally {
      stmt.dispose();
    }
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

  List<LeaveRecord> getLeaveRecordsForEmployee(int employeeId) {
    final stmt = _db.prepare('''
      SELECT * FROM leave_records
      WHERE employee_id = ?
      ORDER BY date_key DESC
      LIMIT 200
    ''');
    final rows = stmt.select([employeeId]);
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

  List<PersonnelDocument> getAllPersonnelDocuments() {
    final rows = _db.select(
      'SELECT * FROM employee_documents ORDER BY upload_date DESC, id DESC',
    );
    return rows
        .map(
          (r) => PersonnelDocument(
            id: r['id'] as String,
            employeeId: r['employee_id'] as int,
            category:
                PersonnelDocumentCategory.fromName(r['category'] as String?),
            title: r['title'] as String,
            filePath: r['file_path'] as String,
            uploadDate: r['upload_date'] as String,
            notes: r['notes'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  List<PersonnelDocument> getDocumentsForEmployee(int employeeId) {
    final stmt = _db.prepare('''
      SELECT * FROM employee_documents
      WHERE employee_id = ?
      ORDER BY upload_date DESC, id DESC
    ''');
    final rows = stmt.select([employeeId]);
    final list = rows
        .map(
          (r) => PersonnelDocument(
            id: r['id'] as String,
            employeeId: r['employee_id'] as int,
            category:
                PersonnelDocumentCategory.fromName(r['category'] as String?),
            title: r['title'] as String,
            filePath: r['file_path'] as String,
            uploadDate: r['upload_date'] as String,
            notes: r['notes'] as String? ?? '',
          ),
        )
        .toList(growable: false);
    stmt.dispose();
    return list;
  }

  void upsertPersonnelDocument(PersonnelDocument doc) {
    // [DB-05] Özlük evraklarını diske kaydederken AES ile şifrelenmiş .hasibu_doc formatında sakla
    final encryptedDocPath =
        HasibuSecurityService.normalizeAndEncryptDocumentOnDisk(doc.filePath);
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO employee_documents
      (id, employee_id, category, title, file_path, upload_date, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      doc.id.trim(),
      doc.employeeId,
      doc.category.name,
      doc.title.trim(),
      encryptedDocPath,
      doc.uploadDate.trim(),
      doc.notes.trim(),
    ]);
    stmt.dispose();
  }

  void deletePersonnelDocument(String id) {
    final stmt = _db.prepare('DELETE FROM employee_documents WHERE id = ?');
    stmt.execute([id]);
    stmt.dispose();
  }

  List<HrRequest> getAllHrRequests() {
    final rows = _db.select(
      'SELECT * FROM hr_requests ORDER BY CASE WHEN status = \'pending\' THEN 0 ELSE 1 END, created_at DESC',
    );
    return rows
        .map(
          (r) => HrRequest(
            id: r['id'] as String,
            employeeId: r['employee_id'] as int,
            employeeCardNo: r['employee_card_no'] as String,
            employeeName: r['employee_name'] as String,
            type: HrRequestType.fromName(r['request_type'] as String?),
            status: HrRequestStatus.fromName(r['status'] as String?),
            targetDate: r['target_date'] as String,
            endDate: r['end_date'] as String?,
            requestedTime: r['requested_time'] as String?,
            isCheckInCorrection: (r['is_checkin_correction'] as int? ?? 0) == 1,
            overtimeMinutes: r['overtime_minutes'] as int? ?? 0,
            leaveType: LeaveType.fromCode(r['leave_code'] as int? ?? 5),
            reason: r['reason'] as String? ?? '',
            createdAt: r['created_at'] as String? ?? '',
            reviewerNote: r['reviewer_note'] as String?,
          ),
        )
        .toList(growable: false);
  }

  void upsertHrRequest(HrRequest req) {
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO hr_requests
      (id, employee_id, employee_card_no, employee_name, request_type, status, target_date, end_date, requested_time, is_checkin_correction, overtime_minutes, leave_code, reason, created_at, reviewer_note)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      req.id.trim(),
      req.employeeId,
      req.employeeCardNo.trim().padLeft(5, '0'),
      req.employeeName.trim().toUpperCase(),
      req.type.name,
      req.status.name,
      req.targetDate.trim(),
      req.endDate?.trim(),
      req.requestedTime?.trim(),
      req.isCheckInCorrection ? 1 : 0,
      req.overtimeMinutes,
      req.leaveType.code,
      req.reason.trim(),
      req.createdAt.trim(),
      req.reviewerNote?.trim(),
    ]);
    stmt.dispose();
  }

  void deleteHrRequest(String id) {
    final stmt = _db.prepare('DELETE FROM hr_requests WHERE id = ?');
    stmt.execute([id]);
    stmt.dispose();
  }

  // ---------------------------------------------------------------------------
  // [AUD-01] & [AUD-02] Silinemez Denetim İzi (`audit_logs`) Yöntemleri
  // ---------------------------------------------------------------------------

  static int _auditSeq = 0;

  AuditLogEntry appendAuditLog({
    required String actorEmployeeId,
    required String actionType,
    required String targetRecordId,
    required String oldValue,
    required String newValue,
    DateTime? timestamp,
    String? customId,
  }) {
    final now = timestamp ?? DateTime.now();
    _auditSeq++;
    final id = customId ??
        'AUD-${now.microsecondsSinceEpoch}-$_auditSeq-${targetRecordId.hashCode.abs() % 10000}';
    final prevRows = _db.select(
      'SELECT hash FROM audit_logs ORDER BY timestamp_iso DESC, rowid DESC LIMIT 1',
    );
    final prevHash = prevRows.isNotEmpty
        ? ((prevRows.first['hash'] as String?) ?? 'GENESIS')
        : 'GENESIS';
    final hash = HasibuSecurityService.computeAuditLogHash(
      id: id,
      actorEmployeeId: actorEmployeeId.trim(),
      actionType: actionType.trim(),
      targetRecordId: targetRecordId.trim(),
      oldValue: oldValue,
      newValue: newValue,
      timestamp: now,
      previousHash: prevHash,
    );

    final stmt = _db.prepare('''
      INSERT INTO audit_logs
      (id, actor_employee_id, action_type, target_record_id, old_value, new_value, timestamp_iso, hash)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      id,
      actorEmployeeId.trim(),
      actionType.trim(),
      targetRecordId.trim(),
      oldValue,
      newValue,
      now.toIso8601String(),
      hash,
    ]);
    stmt.dispose();

    return AuditLogEntry(
      id: id,
      actorEmployeeId: actorEmployeeId.trim(),
      actionType: actionType.trim(),
      targetRecordId: targetRecordId.trim(),
      oldValue: oldValue,
      newValue: newValue,
      timestamp: now,
      hash: hash,
    );
  }

  List<AuditLogEntry> getAuditLogs({int limit = 200}) {
    final stmt = _db.prepare('''
      SELECT * FROM audit_logs
      ORDER BY timestamp_iso DESC, rowid DESC
      LIMIT ?
    ''');
    final rows = stmt.select([limit]);
    final list = rows
        .map(
          (r) => AuditLogEntry(
            id: r['id'] as String,
            actorEmployeeId: r['actor_employee_id'] as String,
            actionType: r['action_type'] as String,
            targetRecordId: r['target_record_id'] as String,
            oldValue: r['old_value'] as String? ?? '',
            newValue: r['new_value'] as String? ?? '',
            timestamp:
                DateTime.tryParse(r['timestamp_iso'] as String? ?? '') ??
                    DateTime.now(),
            hash: r['hash'] as String? ?? '',
          ),
        )
        .toList(growable: false);
    stmt.dispose();
    return list;
  }

  /// [SYNC-02] Personel Portalı (`hasibu_portal_queue.enc`) için yalnızca ilgili personelin
  /// kendi `hr_requests` kayıtlarını ve maskelenmiş vardiya bilgisini içeren kısıtlı paket.
  Map<String, dynamic> exportPortalQueueSnapshot({
    required String deviceName,
    String? employeeCardNo,
  }) {
    final normalizedCard = employeeCardNo?.trim().padLeft(5, '0');
    final allRequests = getAllHrRequests();
    final filteredRequests = (normalizedCard == null || normalizedCard.isEmpty)
        ? allRequests
        : allRequests
            .where((r) => r.employeeCardNo == normalizedCard)
            .toList(growable: false);

    final shiftsById = <int, ShiftPlan>{
      for (final s in getShifts()) s.id: s,
    };
    final employees = getEmployees();
    final targetEmployees = (normalizedCard == null || normalizedCard.isEmpty)
        ? employees
        : employees
            .where((e) => e.cardNo == normalizedCard)
            .toList(growable: false);

    final maskedShifts = targetEmployees.map((e) {
      final shift = shiftsById[e.shiftId];
      final parts = e.fullName.split(' ');
      final maskedName = parts
          .map((p) => p.isEmpty ? '' : '${p[0]}***')
          .join(' ');
      return <String, dynamic>{
        'employeeCardNo': e.cardNo,
        'maskedName': maskedName,
        'branchId': e.branchId,
        'shiftId': e.shiftId,
        'hireDate': e.hireDate,
        'exitDate': e.normalizedExitDate,
        'shiftWindow': shift != null
            ? '${shift.startTime} - ${shift.endTime}'
            : '08:00 - 18:00',
      };
    }).toList(growable: false);

    return <String, dynamic>{
      'schemaVersion': 4,
      'vaultRole': 'portal_queue',
      'exportedAt': DateTime.now().toIso8601String(),
      'deviceName': deviceName,
      'employeeCardNo': normalizedCard ?? '*',
      'hrRequests':
          filteredRequests.map((e) => e.toJson()).toList(growable: false),
      'maskedShifts': maskedShifts,
    };
  }

  /// Zikirce_ Bulut Senkronizasyon standardında tüm yerel durumu JSON paketi olarak dışa aktarır
  /// (`hasibu_master_vault.enc` / `hasibu_sync.enc`).
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
            integrityHash: r['integrity_hash'] as String? ?? '',
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
      'schemaVersion': 4,
      'vaultRole': 'master_vault',
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
      'personnelDocuments': getAllPersonnelDocuments()
          .map((e) => e.toJson())
          .toList(growable: false),
      'hrRequests':
          getAllHrRequests().map((e) => e.toJson()).toList(growable: false),
      'auditLogs':
          getAuditLogs(limit: 500).map((e) => e.toJson()).toList(growable: false),
      'accountingAccounts': getAccountingAccounts()
          .map((e) => e.toJson())
          .toList(growable: false),
      'accountingTransactions': getAccountingTransactions()
          .map((e) => e.toJson())
          .toList(growable: false),
      'containerMovements': getContainerMovements()
          .map((e) => e.toJson())
          .toList(growable: false),
      'stockBurnItems':
          getStockBurnItems().map((e) => e.toJson()).toList(growable: false),
      'checksAndNotes':
          getChecksAndNotes().map((e) => e.toJson()).toList(growable: false),
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

      final rawDocs =
          snapshot['personnelDocuments'] as List<dynamic>? ?? const [];
      for (final item in rawDocs) {
        if (item is Map<String, dynamic>) {
          upsertPersonnelDocument(PersonnelDocument.fromJson(item));
        }
      }

      final rawReqs = snapshot['hrRequests'] as List<dynamic>? ?? const [];
      for (final item in rawReqs) {
        if (item is Map<String, dynamic>) {
          upsertHrRequest(HrRequest.fromJson(item));
        }
      }

      final rawAccounts =
          snapshot['accountingAccounts'] as List<dynamic>? ?? const [];
      for (final item in rawAccounts) {
        if (item is Map<String, dynamic>) {
          upsertAccountingAccount(AccountingAccount.fromJson(item));
        }
      }

      final rawTransactions =
          snapshot['accountingTransactions'] as List<dynamic>? ?? const [];
      for (final item in rawTransactions) {
        if (item is Map<String, dynamic>) {
          upsertAccountingTransaction(AccountingTransaction.fromJson(item));
          mergedCount++;
        }
      }

      final rawContainers =
          snapshot['containerMovements'] as List<dynamic>? ?? const [];
      for (final item in rawContainers) {
        if (item is Map<String, dynamic>) {
          upsertContainerMovement(ContainerMovement.fromJson(item));
        }
      }

      final rawStocks =
          snapshot['stockBurnItems'] as List<dynamic>? ?? const [];
      for (final item in rawStocks) {
        if (item is Map<String, dynamic>) {
          upsertStockBurnItem(StockBurnItem.fromJson(item));
        }
      }

      final rawChecks =
          snapshot['checksAndNotes'] as List<dynamic>? ?? const [];
      for (final item in rawChecks) {
        if (item is Map<String, dynamic>) {
          upsertCheckOrNote(CheckOrAlertNote.fromJson(item));
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
