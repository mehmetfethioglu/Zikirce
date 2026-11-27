import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';
import 'package:hasibu/core/services/google_drive_sync_service.dart';
import 'package:hasibu/features/pdks/domain/attendance_evaluation_engine.dart';
import 'package:hasibu/features/pdks/domain/attendance_report_engine.dart';
import 'package:hasibu/features/pdks/domain/mobile_checkin_gateway.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/domain/pdks_print_builders.dart';
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

HasibuDatabase _buildTestDb() {
  final db = HasibuDatabase.inMemory();
  db.saveCompanySettings(
    db.getCompanySettings().copyWith(
          companyName: 'AKAR TEST MÜHENDİSLİK A.Ş.',
          adminPasswordUpdated: true,
          adminPassword: HasibuSecurityService.hashPassword('Admin#2026'),
          autoCloudBackupEnabled: false,
          autoCloudBackupOnChange: false,
          autoPollEnabled: false,
        ),
  );
  db.upsertBranch(
    const Branch(
      id: 1,
      code: 'MRK',
      name: 'Merkez Şube',
      hasTerminal: false,
      latitude: 37.1674,
      longitude: 38.7955,
      geofenceRadiusMeters: 200,
    ),
  );
  db.upsertDepartment(
    const Department(id: 1, name: 'ÜRETİM', branchId: 1),
  );
  return db;
}

AttendanceLog _log({
  required String id,
  required String cardNo,
  required DateTime ts,
  required bool isCheckIn,
  int branchId = 1,
}) {
  return AttendanceLog(
    id: id,
    cardNo: cardNo,
    branchId: branchId,
    deviceNo: 1,
    timestamp: ts,
    isCheckIn: isCheckIn,
    source: AttendanceSource.tenfeiD35,
    verifyMethod: VerifyMethod.face,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('Katman 1 — PDKS Değerlendirme Motoru (SOLID Pure Domain)', () {
    test(
      'Night-shift cross-midnight matches next-day check-out and filters consumed morning spillover',
      () {
        const nightShift = ShiftPlan(
          id: 10,
          name: 'Gece Vardiyası',
          startTime: '19:00',
          endTime: '07:00',
          toleranceMinutes: 15,
          breakMinutes: 60,
        );
        expect(nightShift.isNightShift, isTrue);

        const emp = Employee(
          id: 501,
          cardNo: '00501',
          fullName: 'GECE PERSONELİ',
          title: 'Operatör',
          departmentId: 1,
          branchId: 1,
          shiftId: 10,
          hireDate: '2024-01-01',
        );

        final prevLogs = <AttendanceLog>[];
        final dayLogs = <AttendanceLog>[
          _log(
            id: 'in_d',
            cardNo: '00501',
            ts: DateTime(2026, 10, 12, 19, 5),
            isCheckIn: true,
          ),
        ];
        final nextDayLogs = <AttendanceLog>[
          _log(
            id: 'out_d1',
            cardNo: '00501',
            ts: DateTime(2026, 10, 13, 7, 10),
            isCheckIn: false,
          ),
        ];

        final dayEval = AttendanceEvaluationEngine.evaluateDay(
          rawDayLogs: dayLogs,
          previousDayLogs: prevLogs,
          nextDayLogs: nextDayLogs,
          shift: nightShift,
          leave: null,
          employee: emp,
          dateKey: '2026-10-12',
        );

        expect(dayEval.state, DailyAttendanceState.present);
        expect(dayEval.hasMissingCheckOut, isFalse);
        expect(dayEval.firstIn?.id, 'in_d');
        expect(dayEval.lastOut?.id, 'out_d1');
        expect(dayEval.breakDeductedMinutes, 60);
        // 19:05 -> 07:10 = 725 dk - 60 dk mola = 665 dk
        expect(dayEval.workedMinutes, 665);

        // Ertesi gün (2026-10-13) sabahki 07:10 çıkışı yeni giriş sayılmamalı
        final nextDayEval = AttendanceEvaluationEngine.evaluateDay(
          rawDayLogs: nextDayLogs,
          previousDayLogs: dayLogs,
          nextDayLogs: const [],
          shift: nightShift,
          leave: null,
          employee: emp,
          dateKey: '2026-10-13',
        );
        expect(nextDayEval.state, DailyAttendanceState.absent);
        expect(nextDayEval.firstIn, isNull);
      },
    );

    test(
      'Break deduction, multi-session intraday gaps, overtimeThresholdMinutes & roundingMinutes work accurately',
      () {
        const shift = ShiftPlan(
          id: 1,
          name: 'Standart Gündüz',
          startTime: '08:00',
          endTime: '18:00',
          toleranceMinutes: 15,
          breakMinutes: 60,
          overtimeThresholdMinutes: 20,
          roundingMinutes: 15,
        );
        const emp = Employee(
          id: 502,
          cardNo: '00502',
          fullName: 'GÜNDÜZ PERSONELİ',
          title: 'Teknisyen',
          departmentId: 1,
          branchId: 1,
          shiftId: 1,
          hireDate: '2024-01-01',
        );

        // 1. Tek oturum + 60 dk zorunlu mola düşümü + 50 dk fazla mesai -> 15 dk katına yuvarlama (45 dk)
        final singleEval = AttendanceEvaluationEngine.evaluateDay(
          rawDayLogs: [
            _log(
              id: 's_in',
              cardNo: '00502',
              ts: DateTime(2026, 10, 14, 8, 0),
              isCheckIn: true,
            ),
            _log(
              id: 's_out',
              cardNo: '00502',
              ts: DateTime(2026, 10, 14, 18, 50),
              isCheckIn: false,
            ),
          ],
          shift: shift,
          leave: null,
          employee: emp,
          dateKey: '2026-10-14',
        );
        expect(singleEval.breakDeductedMinutes, 60);
        expect(singleEval.workedMinutes, 650 - 60);
        expect(singleEval.overtimeMinutes, 45);

        // 2. Gün içi ara çıkış (08:00-12:00 + 13:30-18:00): 90 dk ara çıkış hariç tutulur = 510 dk
        final splitEval = AttendanceEvaluationEngine.evaluateDay(
          rawDayLogs: [
            _log(
              id: 'p1_in',
              cardNo: '00502',
              ts: DateTime(2026, 10, 15, 8, 0),
              isCheckIn: true,
            ),
            _log(
              id: 'p1_out',
              cardNo: '00502',
              ts: DateTime(2026, 10, 15, 12, 0),
              isCheckIn: false,
            ),
            _log(
              id: 'p2_in',
              cardNo: '00502',
              ts: DateTime(2026, 10, 15, 13, 30),
              isCheckIn: true,
            ),
            _log(
              id: 'p2_out',
              cardNo: '00502',
              ts: DateTime(2026, 10, 15, 18, 0),
              isCheckIn: false,
            ),
          ],
          shift: shift,
          leave: null,
          employee: emp,
          dateKey: '2026-10-15',
        );
        expect(splitEval.workedMinutes, 510);
      },
    );

    test(
      'PublicHoliday and WeeklyOff (shift & employee override) avoid false absences',
      () {
        const shiftWithSundayOff = ShiftPlan(
          id: 2,
          name: 'Hafta İçi',
          startTime: '08:00',
          endTime: '18:00',
          weeklyOffDays: [DateTime.sunday],
        );
        const empCustomOff = Employee(
          id: 503,
          cardNo: '00503',
          fullName: 'HAFTA TATİLİ TESTİ',
          title: 'Uzman',
          departmentId: 1,
          branchId: 1,
          shiftId: 2,
          hireDate: '2024-01-01',
          weeklyOffDay: DateTime.saturday,
        );

        final holidayEval = AttendanceEvaluationEngine.evaluateDay(
          rawDayLogs: const [],
          shift: shiftWithSundayOff,
          leave: null,
          employee: empCustomOff,
          dateKey: '2026-10-29',
          publicHoliday: const PublicHoliday(
            id: 'hol_20261029',
            dateKey: '2026-10-29',
            name: 'Cumhuriyet Bayramı',
          ),
        );
        expect(holidayEval.state, DailyAttendanceState.publicHoliday);

        // 2026-10-17 Cumartesi -> personel özel hafta tatili
        final customOffEval = AttendanceEvaluationEngine.evaluateDay(
          rawDayLogs: const [],
          shift: shiftWithSundayOff,
          leave: null,
          employee: empCustomOff,
          dateKey: '2026-10-17',
        );
        expect(customOffEval.state, DailyAttendanceState.weeklyOff);

        // 2026-10-18 Pazar -> vardiya hafta tatili
        final shiftOffEval = AttendanceEvaluationEngine.evaluateDay(
          rawDayLogs: const [],
          shift: shiftWithSundayOff,
          leave: null,
          employee: const Employee(
            id: 504,
            cardNo: '00504',
            fullName: 'PAZAR TATİLİ',
            title: 'Uzman',
            departmentId: 1,
            branchId: 1,
            shiftId: 2,
            hireDate: '2024-01-01',
          ),
          dateKey: '2026-10-18',
        );
        expect(shiftOffEval.state, DailyAttendanceState.weeklyOff);
      },
    );
  });

  group('Katman 2 & 3 — İzin Bakiyesi, Resmi Tatiller, Limit & Audit Loglar', () {
    test(
      'Annual leave syncs usedAnnualLeave on assign/delete, excludes holidays & off-days, preserves >200 rows, and writes audit logs',
      () async {
        final db = _buildTestDb();
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

        db.upsertShift(
          const ShiftPlan(
            id: 1,
            name: 'Hafta İçi',
            startTime: '08:00',
            endTime: '18:00',
            weeklyOffDays: [DateTime.sunday],
          ),
        );
        const emp = Employee(
          id: 701,
          cardNo: '00701',
          fullName: 'İZİN BAKİYE TESTİ',
          title: 'Analist',
          departmentId: 1,
          branchId: 1,
          shiftId: 1,
          hireDate: '2021-01-01',
          annualLeaveEntitlement: 20,
          usedAnnualLeave: 0,
        );

        final notifier = container.read(pdksDashboardProvider.notifier);
        await notifier.saveEmployee(emp);
        expect(
          db.getAuditLogs().any(
                (a) =>
                    a.actionType == 'EMPLOYEE_EMPLOYMENT_DATES_UPDATED' &&
                    a.targetRecordId == '00701',
              ),
          isTrue,
        );
        await notifier.saveEmployee(emp.copyWith(title: 'Kıdemli Analist'));
        expect(
          db.getAuditLogs().any(
                (a) =>
                    a.actionType == 'EMPLOYEE_SAVED' &&
                    a.targetRecordId == '00701',
              ),
          isTrue,
        );

        final seededCount = await notifier.seedTurkeyOfficialHolidays(2026);
        expect(seededCount, greaterThanOrEqualTo(7));
        expect(
          container.read(pdksDashboardProvider).publicHolidays,
          isNotEmpty,
        );

        // 2026-10-28 (Çar), 2026-10-29 (Cumhuriyet Bayramı - Resmi Tatil), 2026-10-30 (Cum)
        // Resmi tatil hariç tutulmalı -> sadece 2 iş günü izin yazılmalı!
        final assignedDays = await notifier.assignLeaveDateRange(
          employeeId: 701,
          startDate: DateTime(2026, 10, 28),
          endDate: DateTime(2026, 10, 30),
          leaveType: LeaveType.yillikIzin,
          note: 'Sonbahar izni',
          excludeOffDaysAndHolidays: true,
        );
        expect(assignedDays, 2);

        final afterAssign = db.getEmployees().firstWhere((e) => e.id == 701);
        expect(afterAssign.usedAnnualLeave, 2);
        expect(afterAssign.remainingAnnualLeave, 18);

        // Saatlik mazeret izni kaydet & metadata + audit kontrolü
        await notifier.assignLeaveOrReport(
          employeeId: 701,
          leaveType: LeaveType.mazeretIzni,
          note: 'Banka işi',
          customDateKey: '2026-10-27',
          durationHours: 2.5,
          startTime: '14:00',
          endTime: '16:30',
        );
        final hourly = db
            .getLeaveRecordsForEmployee(701)
            .firstWhere((r) => r.id == 'leave_701_2026-10-27');
        expect(hourly.durationHours, 2.5);
        expect(hourly.startTime, '14:00');
        expect(hourly.endTime, '16:30');

        // 1 günlük yıllık izni sil -> bakiye 2'den 1'e iade edilmeli
        await notifier.deleteLeaveRecord('leave_701_2026-10-28');
        final afterDelete = db.getEmployees().firstWhere((e) => e.id == 701);
        expect(afterDelete.usedAnnualLeave, 1);

        // Toplu hareket ve personel silme denetim izleri
        await notifier.saveBulkManualAttendance(
          employees: [afterDelete],
          dateKey: '2026-10-26',
          checkInTime: '08:05',
          checkOutTime: '18:05',
        );
        await notifier.deleteEmployee(701);

        final actions = db.getAuditLogs().map((a) => a.actionType).toSet();
        expect(
          actions,
          containsAll(<String>[
            'EMPLOYEE_SAVED',
            'LEAVE_ASSIGNED',
            'LEAVE_RANGE_ASSIGNED',
            'LEAVE_DELETED',
            'BULK_MANUAL_ATTENDANCE_APPLIED',
            'EMPLOYEE_DELETED',
          ]),
        );

        // >200 izin kaydı limitsiz dönmeli (215 kayıt ekle)
        for (int i = 0; i < 215; i++) {
          final dt = DateTime(2025, 1, 1).add(Duration(days: i));
          final dKey = AttendanceEvaluationEngine.formatDateKey(dt);
          db.upsertLeaveRecord(
            LeaveRecord(
              id: 'bulk_leave_$i',
              employeeId: 701,
              date: dKey,
              leaveType: LeaveType.ucretliIzin,
              note: 'Toplu test $i',
            ),
          );
        }
        expect(db.getAllLeaveRecords().length, greaterThanOrEqualTo(215));
        expect(
          db.getLeaveRecordsForEmployee(701).length,
          greaterThanOrEqualTo(215),
        );
      },
    );
  });

  group('Proaktif Uyarı Motoru, Aylık Puantaj Matrisi & Mobil Çıkış UI', () {
    test(
      'Proactive alerts detect 4857 25/II-g consecutive absences, expired doc, probation ending, and missing check-out',
      () {
        const branch = Branch(
          id: 1,
          code: 'MRK',
          name: 'Merkez',
          hasTerminal: false,
          latitude: 37.1674,
          longitude: 38.7955,
        );
        const dept = Department(id: 1, name: 'ÜRETİM', branchId: 1);
        const shift = ShiftPlan(
          id: 1,
          name: 'Standart',
          startTime: '08:00',
          endTime: '18:00',
        );
        const empMissingOut = Employee(
          id: 801,
          cardNo: '00801',
          fullName: 'EKSİK ÇIKIŞ PERSONELİ',
          title: 'Personel',
          departmentId: 1,
          branchId: 1,
          shiftId: 1,
          hireDate: '2025-01-01',
          probationEndDate: '2026-10-25',
        );
        const empConsecAbsent = Employee(
          id: 802,
          cardNo: '00802',
          fullName: 'ARDIŞIK DEVAMSIZ PERSONEL',
          title: 'Personel',
          departmentId: 1,
          branchId: 1,
          shiftId: 1,
          hireDate: '2025-01-01',
        );

        // 801 için 2026-10-19 tek giriş (eksik çıkış), önceki günlerde normal çalışma
        final logs = [
          _log(
            id: 'in_prev1',
            cardNo: '00801',
            ts: DateTime(2026, 10, 18, 8, 0),
            isCheckIn: true,
          ),
          _log(
            id: 'in_today',
            cardNo: '00801',
            ts: DateTime(2026, 10, 19, 8, 5),
            isCheckIn: true,
          ),
        ];
        final status801 = EmployeeDailyStatus(
          employee: empMissingOut,
          department: dept,
          branch: branch,
          shift: shift,
          state: DailyAttendanceState.present,
          firstCheckIn: logs.last,
          hasMissingCheckOut: true,
          allLogsOfDay: [logs.last],
        );
        final status802 = EmployeeDailyStatus(
          employee: empConsecAbsent,
          department: dept,
          branch: branch,
          shift: shift,
          state: DailyAttendanceState.absent,
          allLogsOfDay: const [],
        );

        final docs = [
          const PersonnelDocument(
            id: 'doc_isg',
            employeeId: 801,
            category: PersonnelDocumentCategory.saglikRaporu,
            title: 'İSG Sağlık Raporu',
            filePath: 'arsiv/isg.pdf',
            uploadDate: '2025-10-01',
            expiryDate: '2026-10-10', // 19 Ekim'e göre süresi dolmuş
          ),
        ];

        final alerts = AttendanceReportEngine.buildProactiveAlerts(
          anchorDateKey: '2026-10-19',
          employees: const [empMissingOut, empConsecAbsent],
          todayStatuses: [status801, status802],
          shiftMap: const {1: shift},
          fallbackShift: shift,
          recentLogs: logs,
          recentLeaves: const [],
          holidays: const {},
          documents: docs,
        );

        final categories = alerts.map((a) => a.category).toSet();
        expect(
          categories,
          containsAll(<PdksAlertCategory>[
            PdksAlertCategory.consecutiveAbsence,
            PdksAlertCategory.probationEnding,
            PdksAlertCategory.documentExpiry,
            PdksAlertCategory.missingCheckOut,
          ]),
        );
      },
    );

    testWidgets(
      'MonthlyPuantajMatrixView renders 31-day cells and opens printable employee signature sheet',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = _buildTestDb();
        addTearDown(db.dispose);
        db.upsertEmployee(
          const Employee(
            id: 810,
            cardNo: '00810',
            fullName: 'PUANTAJ TEST PERSONELİ',
            title: 'Operatör',
            departmentId: 1,
            branchId: 1,
            shiftId: 1,
            hireDate: '2024-01-01',
          ),
        );
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

        final notifier = container.read(pdksDashboardProvider.notifier);
        notifier.setSelectedDate('2026-10-19');
        await notifier.saveOrUpdateAttendanceLog(
          employee: db.getEmployees().firstWhere((e) => e.id == 810),
          dateKey: '2026-10-19',
          timeHhMm: '08:02',
          isCheckIn: true,
        );
        await notifier.saveOrUpdateAttendanceLog(
          employee: db.getEmployees().firstWhere((e) => e.id == 810),
          dateKey: '2026-10-19',
          timeHhMm: '18:04',
          isCheckIn: false,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MonthlyPuantajMatrixView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('monthly_puantaj_period_label')),
          findsOneWidget,
        );
        expect(find.text('Ekim 2026'), findsOneWidget);
        expect(find.text('PUANTAJ TEST PERSONELİ'), findsOneWidget);

        // Satırdaki imzalı yazdırma butonuna dokun -> PrintableDocument önizlemesi açılmalı
        final printBtn =
            find.byKey(const ValueKey('monthly_puantaj_print_00810'));
        await tester.scrollUntilVisible(
          printBtn,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(printBtn, findsOneWidget);
        await tester.tap(printBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('İmza'), findsWidgets);

        // Domain buildMonthlyPuantajSignatureDocument doğrudan kontrolü
        final matrix = notifier.buildMonthlyPuantajMatrix(
          year: 2026,
          month: 10,
        );
        final doc = HasibuPrintBuilders.buildMonthlyPuantajSignatureDocument(
          companySettings: db.getCompanySettings(),
          row: matrix.firstWhere((r) => r.employee.id == 810),
        );
        expect(doc.title.toUpperCase(), contains('PUANTAJ'));

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
      },
    );

    testWidgets(
      'BranchQrGpsCheckInView supports Çıkış Yap toggle and records check-out via MobileLocationGateway',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = _buildTestDb();
        addTearDown(db.dispose);
        const emp = Employee(
          id: 820,
          cardNo: '00820',
          fullName: 'MOBİL ÇIKIŞ PERSONELİ',
          title: 'Saha Uzmanı',
          departmentId: 1,
          branchId: 1,
          shiftId: 1,
          hireDate: '2024-01-01',
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
            mobileLocationGatewayProvider.overrideWithValue(
              const _FakeLocationGateway(
                MobileLocationReading(
                  latitude: 37.1674,
                  longitude: 38.7955,
                  isMocked: false,
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: BranchQrGpsCheckInView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Varsayılan mod: Giriş -> "Çıkış Yap" seçimine geç
        expect(
          find.byKey(const ValueKey('branch_qr_gps_direction_selector')),
          findsOneWidget,
        );
        await tester.tap(find.text('Çıkış Yap'));
        await tester.pumpAndSettle();

        expect(find.text('QR Çıkış'), findsNothing);
        expect(find.text('GPS Çıkış'), findsWidgets);

        final gpsBtn = find.byKey(const ValueKey('branch_gps_action_00820'));
        await tester.scrollUntilVisible(
          gpsBtn,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(gpsBtn);
        await tester.pumpAndSettle();

        final todayKey = PdksDashboardNotifier.todayDateKey();
        final logs = db.getAttendanceLogsForDate(todayKey);
        expect(
          logs.any(
            (l) =>
                l.cardNo == '00820' &&
                !l.isCheckIn &&
                l.source == AttendanceSource.mobileGps,
          ),
          isTrue,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
      },
    );
  });
}
