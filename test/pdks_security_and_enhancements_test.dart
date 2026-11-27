import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/database/hasibu_pdks_schedule_dao.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';
import 'package:hasibu/core/services/google_drive_sync_service.dart';
import 'package:hasibu/features/pdks/data/tenfei_zk_client.dart';
import 'package:hasibu/features/pdks/domain/attendance_evaluation_engine.dart';
import 'package:hasibu/features/pdks/domain/attendance_report_engine.dart';
import 'package:hasibu/features/pdks/domain/employee_bulk_import_engine.dart';
import 'package:hasibu/features/pdks/domain/mobile_checkin_gateway.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/features/pdks/presentation/screens/branch_qr_gps_checkin_view.dart';
import 'package:hasibu/features/pdks/presentation/screens/monthly_puantaj_matrix_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocationGateway implements MobileLocationGateway {
  final MobileLocationReading reading;
  const _FakeLocationGateway(this.reading);

  @override
  Future<MobileLocationReading> getCurrentLocation({
    required Branch fallbackBranch,
  }) async {
    return reading;
  }
}

HasibuDatabase _createSeededTestDb() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  FlutterSecureStorage.setMockInitialValues(<String, String>{});
  final db = HasibuDatabase.inMemory();
  db.saveCompanySettings(
    db.getCompanySettings().copyWith(autoCloudBackupEnabled: false),
  );
  db.upsertBranch(
    const Branch(
      id: 1,
      code: 'MERKEZ',
      name: 'Merkez Şube',
      hasTerminal: false,
      latitude: 37.1674,
      longitude: 38.7955,
      geofenceRadiusMeters: 200,
    ),
  );
  db.upsertBranch(
    const Branch(
      id: 2,
      code: 'SUBE2',
      name: 'İkinci Şube',
      hasTerminal: false,
      latitude: 37.18,
      longitude: 38.80,
      geofenceRadiusMeters: 200,
    ),
  );
  db.upsertDepartment(const Department(id: 1, name: 'ÜRETİM', branchId: 1));
  db.upsertShift(
    const ShiftPlan(
      id: 1,
      name: 'Gündüz',
      startTime: '08:00',
      endTime: '18:00',
      toleranceMinutes: 15,
      breakMinutes: 60,
      overtimeThresholdMinutes: 15,
      roundingMinutes: 15,
      weeklyOffDays: [7],
    ),
  );
  db.upsertShift(
    const ShiftPlan(
      id: 2,
      name: 'Gece',
      startTime: '22:00',
      endTime: '06:00',
      toleranceMinutes: 15,
      breakMinutes: 0,
      overtimeThresholdMinutes: 15,
      roundingMinutes: 15,
      weeklyOffDays: [7],
    ),
  );
  return db;
}

void main() {
  group('QR Kaldırma & Personel GPS/PIN Güvenlik Sertleştirmesi', () {
    test('QR kod ile yoklama kaydı reddedilir', () async {
      final db = _createSeededTestDb();
      addTearDown(db.dispose);
      const emp = Employee(
        id: 10,
        cardNo: '00010',
        fullName: 'ALİ DEMİR',
        title: 'Uzman',
        departmentId: 1,
        branchId: 1,
        shiftId: 1,
        hireDate: '2025-01-01',
      );
      db.upsertEmployee(emp);

      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(sync),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pdksDashboardProvider.notifier);
      final branch = db.getBranches().first;
      final res = await notifier.recordBranchMobileCheckIn(
        employee: emp,
        branch: branch,
        source: AttendanceSource.mobileQr,
        isCheckIn: true,
        qrPayload: '123456',
      );

      expect(res, contains('kaldırılmıştır'));
      expect(db.getAttendanceLogsForEmployee('00010'), isEmpty);
    });

    test('Personel oturumu başkası adına GPS kaydı, simüle fallback GPS ve varsayılan PIN arka kapısını engeller', () async {
      final db = _createSeededTestDb();
      addTearDown(db.dispose);
      const emp1 = Employee(
        id: 11,
        cardNo: '00011',
        fullName: 'PERSONEL BİR',
        title: 'Teknisyen',
        departmentId: 1,
        branchId: 1,
        shiftId: 1,
        hireDate: '2025-01-01',
        password: 'OzelSifre#99',
      );
      const emp2 = Employee(
        id: 12,
        cardNo: '00012',
        fullName: 'PERSONEL İKİ',
        title: 'Teknisyen',
        departmentId: 1,
        branchId: 1,
        shiftId: 1,
        hireDate: '2025-01-01',
      );
      db.upsertEmployee(emp1);
      db.upsertEmployee(emp2);

      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(sync),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pdksDashboardProvider.notifier);

      // Varsayılan PIN (1234) özel parolalı hesapta reddedilmeli
      expect(notifier.loginAsEmployee(cardNo: '00011', pin: '1234'), isFalse);
      expect(
        notifier.loginAsEmployee(cardNo: '00011', pin: 'OzelSifre#99'),
        isTrue,
      );

      final state = container.read(pdksDashboardProvider);
      expect(state.authSession.effectiveScopedBranchIds, equals(<int>[1]));
      expect(state.branches.map((b) => b.id).toList(), equals(<int>[1]));

      final branch1 = db.getBranches().firstWhere((b) => b.id == 1);
      // Başkası adına GPS giriş denemesi reddedilmeli
      final buddyAttempt = await notifier.recordBranchMobileCheckIn(
        employee: emp2,
        branch: branch1,
        source: AttendanceSource.mobileGps,
        isCheckIn: true,
        currentLat: 37.1674,
        currentLng: 38.7955,
      );
      expect(buddyAttempt, contains('yalnızca kendi adınıza'));

      // Simüle fallback GPS personel oturumunda reddedilmeli
      final simulatedAttempt = await notifier.recordBranchMobileCheckIn(
        employee: emp1,
        branch: branch1,
        source: AttendanceSource.mobileGps,
        isCheckIn: true,
        currentLat: 37.1674,
        currentLng: 38.7955,
        isSimulatedFallback: true,
      );
      expect(simulatedAttempt, contains('Gerçek GPS sensörü doğrulanamadığı'));
    });

    testWidgets('BranchQrGpsCheckInView QR butonları içermez ve çalışan modunda yalnızca kendini gösterir', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = _createSeededTestDb();
      addTearDown(db.dispose);
      const emp1 = Employee(
        id: 21,
        cardNo: '00021',
        fullName: 'KENDİ KARTIM',
        title: 'Operatör',
        departmentId: 1,
        branchId: 1,
        shiftId: 1,
        hireDate: '2025-01-01',
        password: 'Pin#21',
      );
      const emp2 = Employee(
        id: 22,
        cardNo: '00022',
        fullName: 'DİĞER PERSONEL',
        title: 'Operatör',
        departmentId: 1,
        branchId: 1,
        shiftId: 1,
        hireDate: '2025-01-01',
      );
      db.upsertEmployee(emp1);
      db.upsertEmployee(emp2);

      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(sync),
          mobileLocationGatewayProvider.overrideWithValue(
            const _FakeLocationGateway(
              MobileLocationReading(
                latitude: 37.1674,
                longitude: 38.7955,
                isMocked: false,
                isSimulatedFallback: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(pdksDashboardProvider.notifier)
          .loginAsEmployee(cardNo: '00021', pin: 'Pin#21');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: BranchQrGpsCheckInView())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('QR Giriş'), findsNothing);
      expect(find.text('QR Çıkış'), findsNothing);
      expect(find.textContaining('KENDİ KARTIM'), findsOneWidget);
      expect(find.textContaining('DİĞER PERSONEL'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    });
  });

  group('Puantaj Motoru, İzin Bakiyesi (0.5), Tatil/Arefe & Vardiya Rotasyonu', () {
    const shift = ShiftPlan(
      id: 1,
      name: 'Gündüz',
      startTime: '08:00',
      endTime: '18:00',
      toleranceMinutes: 15,
      breakMinutes: 60,
      overtimeThresholdMinutes: 15,
      roundingMinutes: 15,
      weeklyOffDays: [7],
    );

    test('Yarım gün izin, Arefe yarım gün ve Hafta Tatili/Bayram çalışması doğru hesaplanır', () {
      // 1. Sabah yarım gün izinli personel 13:05 gelince geç kalmamış sayılır
      final halfDayEval = AttendanceEvaluationEngine.evaluateDay(
        rawDayLogs: [
          AttendanceLog(
            id: 'l1',
            cardNo: '00001',
            branchId: 1,
            deviceNo: 1,
            timestamp: DateTime(2026, 10, 20, 13, 5),
            isCheckIn: true,
            source: AttendanceSource.tenfeiD35,
            verifyMethod: VerifyMethod.face,
          ),
          AttendanceLog(
            id: 'l2',
            cardNo: '00001',
            branchId: 1,
            deviceNo: 1,
            timestamp: DateTime(2026, 10, 20, 18, 0),
            isCheckIn: false,
            source: AttendanceSource.tenfeiD35,
            verifyMethod: VerifyMethod.face,
          ),
        ],
        shift: shift,
        leave: const LeaveRecord(
          id: 'lv1',
          employeeId: 1,
          date: '2026-10-20',
          leaveType: LeaveType.yillikIzin,
          note: 'Sabah izin',
          isHalfDay: true,
        ),
        dateKey: '2026-10-20',
      );
      expect(halfDayEval.state, DailyAttendanceState.present);
      expect(halfDayEval.lateMinutes, 0);

      // 2. 28 Ekim Arefe yarım gün tatilinde 13:00 çıkışı erken çıkış olmaz
      final arefeEval = AttendanceEvaluationEngine.evaluateDay(
        rawDayLogs: [
          AttendanceLog(
            id: 'a1',
            cardNo: '00001',
            branchId: 1,
            deviceNo: 1,
            timestamp: DateTime(2026, 10, 28, 8, 0),
            isCheckIn: true,
            source: AttendanceSource.tenfeiD35,
            verifyMethod: VerifyMethod.face,
          ),
          AttendanceLog(
            id: 'a2',
            cardNo: '00001',
            branchId: 1,
            deviceNo: 1,
            timestamp: DateTime(2026, 10, 28, 13, 0),
            isCheckIn: false,
            source: AttendanceSource.tenfeiD35,
            verifyMethod: VerifyMethod.face,
          ),
        ],
        shift: shift,
        leave: null,
        publicHoliday: const PublicHoliday(
          id: 'tr_2026-10-28',
          dateKey: '2026-10-28',
          name: 'Cumhuriyet Bayramı Arifesi',
          isHalfDay: true,
        ),
        dateKey: '2026-10-28',
      );
      expect(arefeEval.earlyLeaveMinutes, 0);

      // 3. Pazar (Hafta Tatili) çalışmasında geç/erken yok, çalışma süresi FM sayılır
      final sundayEval = AttendanceEvaluationEngine.evaluateDay(
        rawDayLogs: [
          AttendanceLog(
            id: 's1',
            cardNo: '00001',
            branchId: 1,
            deviceNo: 1,
            timestamp: DateTime(2026, 10, 25, 9, 0),
            isCheckIn: true,
            source: AttendanceSource.tenfeiD35,
            verifyMethod: VerifyMethod.face,
          ),
          AttendanceLog(
            id: 's2',
            cardNo: '00001',
            branchId: 1,
            deviceNo: 1,
            timestamp: DateTime(2026, 10, 25, 13, 0),
            isCheckIn: false,
            source: AttendanceSource.tenfeiD35,
            verifyMethod: VerifyMethod.face,
          ),
        ],
        shift: shift,
        leave: null,
        dateKey: '2026-10-25',
      );
      expect(sundayEval.isWeeklyOffWork, isTrue);
      expect(sundayEval.lateMinutes, 0);
      expect(sundayEval.earlyLeaveMinutes, 0);
      expect(sundayEval.overtimeMinutes, 180); // 240dk span - 60dk mola = 180dk FM

      // 4. Geç gelip (10:00) normal süreyi doldurmadan 19:00'da çıkana FM yazılmaz
      final lateAndLateOutEval = AttendanceEvaluationEngine.evaluateDay(
        rawDayLogs: [
          AttendanceLog(
            id: 'x1',
            cardNo: '00001',
            branchId: 1,
            deviceNo: 1,
            timestamp: DateTime(2026, 10, 21, 10, 0),
            isCheckIn: true,
            source: AttendanceSource.tenfeiD35,
            verifyMethod: VerifyMethod.face,
          ),
          AttendanceLog(
            id: 'x2',
            cardNo: '00001',
            branchId: 1,
            deviceNo: 1,
            timestamp: DateTime(2026, 10, 21, 19, 0),
            isCheckIn: false,
            source: AttendanceSource.tenfeiD35,
            verifyMethod: VerifyMethod.face,
          ),
        ],
        shift: shift,
        leave: null,
        dateKey: '2026-10-21',
      );
      expect(lateAndLateOutEval.lateMinutes, 120);
      expect(lateAndLateOutEval.overtimeMinutes, 0);
    });

    test('Yarım gün yıllık izin 0.5 gün bakiye düşer ve silinince iade eder', () async {
      final db = _createSeededTestDb();
      addTearDown(db.dispose);
      const emp = Employee(
        id: 30,
        cardNo: '00030',
        fullName: 'İZİN TEST',
        title: 'Uzman',
        departmentId: 1,
        branchId: 1,
        shiftId: 1,
        hireDate: '2024-01-01',
        annualLeaveEntitlement: 14,
        usedAnnualLeave: 0,
      );
      db.upsertEmployee(emp);

      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(sync),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pdksDashboardProvider.notifier);
      await notifier.assignLeaveOrReport(
        employeeId: 30,
        leaveType: LeaveType.yillikIzin,
        note: 'Yarım gün izin',
        customDateKey: '2026-10-22',
        isHalfDay: true,
      );

      final afterAssign = db.getEmployees().firstWhere((e) => e.id == 30);
      expect(afterAssign.usedAnnualLeaveDays, closeTo(0.5, 0.001));
      expect(afterAssign.formattedRemainingAnnualLeave, '13.5');

      await notifier.deleteLeaveRecord('leave_30_2026-10-22');
      final afterDelete = db.getEmployees().firstWhere((e) => e.id == 30);
      expect(afterDelete.usedAnnualLeaveDays, closeTo(0.0, 0.001));
    });

    test('Tarih bazlı vardiya ataması geçmiş puantajı bozmaz ve 2026 tatilleri dini bayramları içerir', () {
      final db = _createSeededTestDb();
      addTearDown(db.dispose);
      final added = db.seedTurkeyOfficialHolidays(2026);
      expect(added, greaterThanOrEqualTo(17));
      final holidays = db.getPublicHolidays();
      expect(holidays.any((h) => h.dateKey == '2026-10-28' && h.isHalfDay), isTrue);
      expect(holidays.any((h) => h.dateKey == '2026-03-20'), isTrue); // Ramazan Bayramı
      expect(holidays.any((h) => h.dateKey == '2026-05-27'), isTrue); // Kurban Bayramı

      const emp = Employee(
        id: 40,
        cardNo: '00040',
        fullName: 'ROTASYON PERSONEL',
        title: 'Operatör',
        departmentId: 1,
        branchId: 1,
        shiftId: 2,
        hireDate: '2026-01-01',
      );
      final assignments = [
        const ShiftAssignment(
          id: 'sa1',
          employeeId: 40,
          shiftId: 1,
          validFrom: '2026-10-01',
          validTo: '2026-10-15',
        ),
        const ShiftAssignment(
          id: 'sa2',
          employeeId: 40,
          shiftId: 2,
          validFrom: '2026-10-16',
        ),
      ];
      final shiftMap = {
        1: db.getShifts().firstWhere((s) => s.id == 1),
        2: db.getShifts().firstWhere((s) => s.id == 2),
      };

      final oldDayShift = AttendanceEvaluationEngine.resolveShiftForDate(
        employee: emp,
        dateKey: '2026-10-10',
        shiftMap: shiftMap,
        fallbackShift: shiftMap[1]!,
        shiftAssignments: assignments,
      );
      final newDayShift = AttendanceEvaluationEngine.resolveShiftForDate(
        employee: emp,
        dateKey: '2026-10-20',
        shiftMap: shiftMap,
        fallbackShift: shiftMap[1]!,
        shiftAssignments: assignments,
      );
      expect(oldDayShift.id, 1);
      expect(newDayShift.id, 2);
    });
  });

  group('CSV Güvenliği, Toplu Aktarım, Terminal Encode, KVKK & Puantaj Lejantı', () {
    test('CSV formül enjeksiyonunu temizler ve toplu personel içe aktarım/atama çalışır', () async {
      expect(AttendanceReportEngine.sanitizeCsvCell('=CMD|calc'), "'=CMD|calc");
      expect(AttendanceReportEngine.sanitizeCsvCell('A;B'), '"A;B"');

      expect(HasibuSecurityService.maskNationalId('12345678901'), '123*****901');
      expect(HasibuSecurityService.maskIban('TR330006100519786457841326'), 'TR** **** **** **** 1326');

      final encoded = TenfeiZkClient.encodeCp1254('ŞÜKRÜ Ğİ', 12);
      expect(encoded.length, 12);
      expect(TenfeiZkClient.decodeCp1254(encoded), 'ŞÜKRÜ Ğİ');

      final db = _createSeededTestDb();
      addTearDown(db.dispose);
      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(sync),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pdksDashboardProvider.notifier);
      final res = await notifier.importEmployeesFromCsv(
        EmployeeBulkImportEngine.sampleCsvTemplate,
      );
      expect(res.validEmployees.length, 2);

      final ids = res.validEmployees.map((e) => e.id).toList();
      final updated = await notifier.bulkAssignEmployees(
        employeeIds: ids,
        shiftId: 2,
      );
      expect(updated, 2);
      expect(
        db.getEmployees().where((e) => ids.contains(e.id)).every((e) => e.shiftId == 2),
        isTrue,
      );
    });

    testWidgets('MonthlyPuantajMatrixView T: Hafta Tatili ve B: Resmi Tatil (UBGT) lejantını doğru gösterir', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = _createSeededTestDb();
      addTearDown(db.dispose);
      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(sync),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: MonthlyPuantajMatrixView())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('T: Hafta Tatili'), findsOneWidget);
      expect(find.text('B: Resmi Tatil (UBGT)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    });
  });
}
