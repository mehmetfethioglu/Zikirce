import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';
import 'package:hasibu/core/services/google_auth_adapter.dart';
import 'package:hasibu/core/services/google_drive_sync_service.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/features/pdks/presentation/screens/app_users_management_card.dart';
import 'package:hasibu/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGoogleAuthAdapter implements GoogleAuthAdapter {
  @override
  bool get isNativePlatform => true;

  @override
  Future<BrowserGoogleSignInResult> signIn({
    String? loginHintEmail,
    String? customClientId,
    String? customClientSecret,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    return const BrowserGoogleSignInResult(
      success: false,
      message: 'Fake Google Auth',
    );
  }

  @override
  Future<String?> refreshAccessTokenSilently() async => null;

  @override
  Future<void> signOut() async {}
}

void main() {
  group('Şube Sorumlusu Katı İzolasyonu (Unit & Provider)', () {
    late HasibuDatabase db;
    late ProviderContainer container;
    late PdksDashboardNotifier notifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      db = HasibuDatabase.inMemory();
      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
      );
      container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(sync),
          googleAuthAdapterProvider.overrideWithValue(_FakeGoogleAuthAdapter()),
        ],
      );
      notifier = container.read(pdksDashboardProvider.notifier);
      await notifier.updateCloudBackupSettings(autoCloudBackupEnabled: false);
      notifier.setSelectedDate('2026-10-19');
    });

    tearDown(() {
      container.dispose();
      db.dispose();
    });

    test(
      'saveAppUser rejects branchSupervisor without allowedBranchId and legacy null-branch fails closed at login',
      () async {
        final nullBranchErr = await notifier.saveAppUser(
          username: 'eksik_sube',
          displayName: 'Eksik Şube',
          plainPassword: 'Pass#2026',
          role: AppUserRole.branchSupervisor,
          allowedModules: const [HasibuModule.pdksHr],
          allowedBranchId: null,
        );
        expect(nullBranchErr, isNotNull);
        expect(db.findAppUserByUsername('eksik_sube'), isNull);

        final okErr = await notifier.saveAppUser(
          username: 'sube_devteysti',
          displayName: 'Fuat Devteyşti',
          plainPassword: 'Dev#2026',
          role: AppUserRole.branchSupervisor,
          allowedModules: const [
            HasibuModule.pdksHr,
            HasibuModule.employeePortal,
          ],
          allowedBranchId: 38,
        );
        expect(okErr, isNull);

        // Eski DB kaydı (allowedBranchId == null olan branchSupervisor) giriş yapamamalı
        db.upsertAppUser(
          AppUserAccount(
            id: 'USR-LEGACY-NULL',
            username: 'legacy_sube',
            displayName: 'Legacy Şube',
            passwordHash: HasibuSecurityService.hashPassword('Legacy#2026'),
            role: AppUserRole.branchSupervisor,
            allowedModules: const [HasibuModule.pdksHr],
            allowedBranchId: null,
            createdAtIso: DateTime.now().toIso8601String(),
          ),
        );

        final legacyLogin = notifier.loginAsAdmin(
          username: 'legacy_sube',
          password: 'Legacy#2026',
        );
        expect(legacyLogin, isFalse);
        final failedSession = container.read(pdksDashboardProvider).authSession;
        expect(failedSession.isAuthenticated, isFalse);
        expect(failedSession.errorMessage, contains('şube atanmamış'));
      },
    );

    test(
      'branchSupervisor sees zero Merkez data across state, queries, reports, CSVs and cannot mutate Merkez',
      () async {
        // Hazırlık: Merkez (branch 1) ve Şube Devteyşti (branch 38) personellerini bul
        final allEmps = db.getEmployees();
        final merkezEmp = allEmps.firstWhere((e) => e.branchId == 1);
        final branch38Emp = allEmps.firstWhere((e) => e.branchId == 38);

        // Merkez personeline yasal izin uyumsuzluğu ver (syncStatutoryLeaveEntitlements testine hazırlık)
        db.upsertEmployee(
          merkezEmp.copyWith(
            hireDate: '2018-01-01',
            annualLeaveEntitlement: 5,
          ),
        );
        db.upsertEmployee(
          branch38Emp.copyWith(
            hireDate: '2018-01-01',
            annualLeaveEntitlement: 5,
          ),
        );

        // Her iki şube için izin, evrak, İK talebi, audit log ve manipüle log oluştur
        db.upsertLeaveRecord(
          LeaveRecord(
            id: 'leave_merkez_test',
            employeeId: merkezEmp.id,
            date: '2026-10-19',
            leaveType: LeaveType.yillikIzin,
            note: 'Merkez İzin',
          ),
        );
        db.upsertLeaveRecord(
          LeaveRecord(
            id: 'leave_b38_test',
            employeeId: branch38Emp.id,
            date: '2026-10-19',
            leaveType: LeaveType.yillikIzin,
            note: 'Devteyşti İzin',
          ),
        );

        db.upsertPersonnelDocument(
          PersonnelDocument(
            id: 'doc_merkez_test',
            employeeId: merkezEmp.id,
            category: PersonnelDocumentCategory.kimlikFotokopisi,
            title: 'Merkez Kimlik',
            filePath: '/tmp/merkez.pdf',
            uploadDate: '2026-10-19',
          ),
        );
        db.upsertPersonnelDocument(
          PersonnelDocument(
            id: 'doc_b38_test',
            employeeId: branch38Emp.id,
            category: PersonnelDocumentCategory.kimlikFotokopisi,
            title: 'Devteyşti Kimlik',
            filePath: '/tmp/b38.pdf',
            uploadDate: '2026-10-19',
          ),
        );

        db.upsertHrRequest(
          HrRequest(
            id: 'req_merkez_test',
            employeeId: merkezEmp.id,
            employeeCardNo: merkezEmp.cardNo,
            employeeName: merkezEmp.fullName,
            type: HrRequestType.annualLeave,
            status: HrRequestStatus.pending,
            targetDate: '2026-10-20',
            reason: 'Merkez talebi',
            createdAt: '2026-10-19 09:00',
          ),
        );
        db.upsertHrRequest(
          HrRequest(
            id: 'req_b38_test',
            employeeId: branch38Emp.id,
            employeeCardNo: branch38Emp.cardNo,
            employeeName: branch38Emp.fullName,
            type: HrRequestType.annualLeave,
            status: HrRequestStatus.pending,
            targetDate: '2026-10-20',
            reason: 'Devteyşti talebi',
            createdAt: '2026-10-19 09:05',
          ),
        );

        // Hareket ve manipüle hareket oluştur
        final merkezLog = AttendanceLog(
          id: 'log_merkez_1',
          cardNo: merkezEmp.cardNo,
          branchId: 1,
          deviceNo: 1,
          timestamp: DateTime(2026, 10, 19, 8, 5),
          isCheckIn: true,
          source: AttendanceSource.tenfeiD35,
          verifyMethod: VerifyMethod.face,
        );
        final branch38Log = AttendanceLog(
          id: 'log_b38_1',
          cardNo: branch38Emp.cardNo,
          branchId: 38,
          deviceNo: 2,
          timestamp: DateTime(2026, 10, 19, 8, 10),
          isCheckIn: true,
          source: AttendanceSource.mobileQr,
          verifyMethod: VerifyMethod.mobileQr,
        );
        db.upsertAttendanceLog(merkezLog);
        db.upsertAttendanceLog(branch38Log);
        db.rawDb.execute(
          "UPDATE attendance_logs SET integrity_hash = 'TAMPERED' WHERE id IN ('log_merkez_1', 'log_b38_1')",
        );

        db.appendAuditLog(
          actorEmployeeId: 'admin',
          actionType: 'EMPLOYEE_EMPLOYMENT_DATES_UPDATED',
          targetRecordId: merkezEmp.cardNo,
          oldValue: 'old',
          newValue: 'new',
        );
        db.appendAuditLog(
          actorEmployeeId: 'admin',
          actionType: 'EMPLOYEE_EMPLOYMENT_DATES_UPDATED',
          targetRecordId: branch38Emp.cardNo,
          oldValue: 'old',
          newValue: 'new',
        );

        // Şube Sorumlusu (Branch 38) oluştur ve giriş yap
        final saveErr = await notifier.saveAppUser(
          username: 'sorumlu_38',
          displayName: 'Devteyşti Sorumlusu',
          plainPassword: 'Pass#38',
          role: AppUserRole.branchSupervisor,
          allowedModules: const [
            HasibuModule.pdksHr,
            HasibuModule.employeePortal,
          ],
          allowedBranchId: 38,
        );
        expect(saveErr, isNull);

        expect(
          notifier.loginAsAdmin(username: 'sorumlu_38', password: 'Pass#38'),
          isTrue,
        );

        final scopedState = container.read(pdksDashboardProvider);
        expect(scopedState.isBranchScoped, isTrue);
        expect(scopedState.effectiveBranchScopeId, equals(38));
        expect(scopedState.branches.map((b) => b.id).toList(), equals([38]));
        expect(
          scopedState.departments.every((d) => d.branchId == 38),
          isTrue,
        );
        expect(scopedState.dailyStatuses, isNotEmpty);
        expect(
          scopedState.dailyStatuses.every((s) => s.branch.id == 38),
          isTrue,
        );
        expect(
          scopedState.dailyStatuses.any((s) => s.branch.id == 1),
          isFalse,
        );
        expect(
          scopedState.filteredByBranch.every((s) => s.branch.id == 38),
          isTrue,
        );
        expect(
          scopedState.visibleStatuses.every((s) => s.branch.id == 38),
          isTrue,
        );
        final scopedEmpIds = {
          for (final e in allEmps.where((e) => e.branchId == 38)) e.id,
        };
        final scopedCardNos = {
          for (final e in allEmps.where((e) => e.branchId == 38)) e.cardNo,
        };
        expect(
          scopedState.allLeaveRecords.every(
            (l) => scopedEmpIds.contains(l.employeeId),
          ),
          isTrue,
        );
        expect(
          scopedState.allLeaveRecords.any((l) => l.id == 'leave_b38_test'),
          isTrue,
        );
        expect(
          scopedState.allLeaveRecords.any((l) => l.id == 'leave_merkez_test'),
          isFalse,
        );
        expect(
          scopedState.allPersonnelDocuments.every(
            (d) => scopedEmpIds.contains(d.employeeId),
          ),
          isTrue,
        );
        expect(
          scopedState.allPersonnelDocuments.any((d) => d.id == 'doc_b38_test'),
          isTrue,
        );
        expect(
          scopedState.allPersonnelDocuments.any(
            (d) => d.id == 'doc_merkez_test',
          ),
          isFalse,
        );
        expect(
          scopedState.allHrRequests.every(
            (r) =>
                scopedEmpIds.contains(r.employeeId) ||
                scopedCardNos.contains(r.employeeCardNo),
          ),
          isTrue,
        );
        expect(
          scopedState.allHrRequests.any((r) => r.id == 'req_b38_test'),
          isTrue,
        );
        expect(
          scopedState.allHrRequests.any((r) => r.id == 'req_merkez_test'),
          isFalse,
        );
        expect(
          scopedState.pendingHrRequestsCount,
          equals(
            scopedState.allHrRequests
                .where((r) => r.status == HrRequestStatus.pending)
                .length,
          ),
        );
        expect(
          scopedState.tamperedAttendanceLogs.map((l) => l.id).toList(),
          equals(['log_b38_1']),
        );
        expect(
          scopedState.auditLogs.any((a) => a.targetRecordId == merkezEmp.cardNo),
          isFalse,
        );
        expect(
          scopedState.auditLogs.any((a) => a.targetRecordId == branch38Emp.cardNo),
          isTrue,
        );
        expect(
          scopedState.dailyStatuses.any(
            (s) => s.employee.cardNo == scopedState.activeSelfServiceCardNo,
          ),
          isTrue,
        );

        // Filtre / self-service / rapor kaçış denemeleri kilitli kalmalı
        notifier.setBranchFilter(null);
        expect(
          container.read(pdksDashboardProvider).effectiveSelectedBranchId,
          equals(38),
        );
        notifier.setBranchFilter(1);
        expect(
          container.read(pdksDashboardProvider).effectiveSelectedBranchId,
          equals(38),
        );

        final initialPortalCard =
            container.read(pdksDashboardProvider).activeSelfServiceCardNo;
        notifier.setSelfServiceEmployee(merkezEmp.cardNo);
        expect(
          container.read(pdksDashboardProvider).activeSelfServiceCardNo,
          equals(initialPortalCard),
        );

        final periodNull = notifier.buildAttendancePeriodReport(
          startDateKey: '2026-10-19',
          endDateKey: '2026-10-19',
          branchId: null,
        );
        expect(periodNull, isNotEmpty);
        expect(periodNull.every((r) => r.branch.id == 38), isTrue);

        final periodMerkez = notifier.buildAttendancePeriodReport(
          startDateKey: '2026-10-19',
          endDateKey: '2026-10-19',
          branchId: 1,
        );
        expect(periodMerkez.every((r) => r.branch.id == 38), isTrue);

        final periodCsv = notifier.generatePeriodAttendanceReportCsv(
          startDateKey: '2026-10-19',
          endDateKey: '2026-10-19',
          branchId: 1,
        );
        expect(periodCsv, isNot(contains(merkezEmp.fullName)));
        expect(periodCsv, contains(branch38Emp.fullName));

        final dailyCsv = notifier.generateDailyPuantajCsv();
        expect(dailyCsv, isNot(contains(merkezEmp.fullName)));
        expect(dailyCsv, contains(branch38Emp.fullName));

        expect(notifier.getEmployeeHistory(merkezEmp), isEmpty);
        expect(notifier.getEmployeeHistory(branch38Emp), isNotEmpty);

        // 4857 İzin hakediş eşitleme Merkez personeline dokunmamalı
        final syncedCount = await notifier.syncStatutoryLeaveEntitlements();
        expect(syncedCount, greaterThanOrEqualTo(1));
        final dbEmpsAfterSync = db.getEmployees();
        expect(
          dbEmpsAfterSync
              .firstWhere((e) => e.id == merkezEmp.id)
              .annualLeaveEntitlement,
          equals(5),
        );
        expect(
          dbEmpsAfterSync
              .firstWhere((e) => e.id == branch38Emp.id)
              .annualLeaveEntitlement,
          greaterThan(5),
        );

        // Çapraz şube yazma / silme / cihaz kontrolü korumaları
        await notifier.saveEmployee(
          merkezEmp.copyWith(fullName: 'HACKED MERKEZ'),
        );
        expect(
          db.getEmployees().firstWhere((e) => e.id == merkezEmp.id).fullName,
          equals(merkezEmp.fullName),
        );
        await notifier.deleteEmployee(merkezEmp.id);
        expect(
          db.getEmployees().any((e) => e.id == merkezEmp.id),
          isTrue,
        );

        final beforeMerkezLogsCount = db
            .getAttendanceLogsForDate('2026-10-19')
            .where((l) => l.cardNo == merkezEmp.cardNo && l.branchId == 1)
            .length;
        await notifier.saveOrUpdateAttendanceLog(
          employee: merkezEmp,
          dateKey: '2026-10-19',
          timeHhMm: '09:00',
          isCheckIn: true,
        );
        expect(
          db.getAttendanceLogsForDate('2026-10-19').where(
                (l) => l.cardNo == merkezEmp.cardNo && l.branchId == 1,
              ),
          hasLength(beforeMerkezLogsCount),
        );
        await notifier.deleteAttendanceLog('log_merkez_1');
        expect(db.getAttendanceLogById('log_merkez_1'), isNotNull);

        final bulkCount = await notifier.saveBulkManualAttendance(
          employees: [merkezEmp],
          dateKey: '2026-10-19',
          checkInTime: '08:00',
        );
        expect(bulkCount, equals(0));

        final merkezBranch =
            db.getBranches().firstWhere((b) => b.id == 1);
        final qrRes = await notifier.recordBranchMobileCheckIn(
          employee: merkezEmp,
          branch: merkezBranch,
          source: AttendanceSource.mobileGps,
          isCheckIn: true,
        );
        expect(qrRes, contains('Yetki kapsamınız dışındaki'));

        await notifier.assignLeaveOrReport(
          employeeId: merkezEmp.id,
          leaveType: LeaveType.saglikRaporu,
          note: 'Hack',
        );
        await notifier.deleteLeaveRecord('leave_merkez_test');
        expect(
          db.getAllLeaveRecords().any((l) => l.id == 'leave_merkez_test'),
          isTrue,
        );

        await notifier.savePersonnelDocument(
          PersonnelDocument(
            id: 'doc_merkez_hack',
            employeeId: merkezEmp.id,
            category: PersonnelDocumentCategory.digerEvrak,
            title: 'Hack',
            filePath: '/tmp/hack.pdf',
            uploadDate: '2026-10-19',
          ),
        );
        expect(
          db.getAllPersonnelDocuments().any((d) => d.id == 'doc_merkez_hack'),
          isFalse,
        );
        await notifier.deletePersonnelDocument('doc_merkez_test');
        expect(
          db.getAllPersonnelDocuments().any((d) => d.id == 'doc_merkez_test'),
          isTrue,
        );

        await notifier.submitHrRequest(
          HrRequest(
            id: 'req_merkez_hack',
            employeeId: merkezEmp.id,
            employeeCardNo: merkezEmp.cardNo,
            employeeName: merkezEmp.fullName,
            type: HrRequestType.advancePayment,
            targetDate: '2026-10-19',
            reason: 'Hack',
            createdAt: '2026-10-19 10:00',
          ),
        );
        expect(
          db.getAllHrRequests().any((r) => r.id == 'req_merkez_hack'),
          isFalse,
        );

        final reviewMsg = await notifier.reviewHrRequest(
          request: db
              .getAllHrRequests()
              .firstWhere((r) => r.id == 'req_merkez_test'),
          approve: true,
        );
        expect(reviewMsg, contains('Yetki kapsamınız dışındaki'));
        expect(
          db
              .getAllHrRequests()
              .firstWhere((r) => r.id == 'req_merkez_test')
              .status,
          equals(HrRequestStatus.pending),
        );

        await notifier.saveBranch(
          merkezBranch.copyWith(name: 'Hacked Merkez'),
        );
        expect(
          db.getBranches().firstWhere((b) => b.id == 1).name,
          equals(merkezBranch.name),
        );
        await notifier.deleteBranch(39);
        expect(db.getBranches().any((b) => b.id == 39), isTrue);

        await notifier.saveDepartment(
          const Department(id: 999, name: 'HACK_DEPT', branchId: 1),
        );
        expect(db.getDepartments().any((d) => d.id == 999), isFalse);

        final diag = await notifier.testBranchTerminalConnection(merkezBranch);
        expect(diag.isReachable, isFalse);
        expect(diag.message, contains('Yetki kapsamınız dışındaki'));

        // Çıkış ve Ana Yönetici girişi tüm şubeleri geri getirmeli
        notifier.logout();
        expect(notifier.loginAsAdmin(username: 'admin', password: '123'), isTrue);
        final adminState = container.read(pdksDashboardProvider);
        expect(adminState.isBranchScoped, isFalse);
        expect(adminState.selectedBranchId, isNull);
        expect(adminState.branches.any((b) => b.id == 1), isTrue);
        expect(adminState.dailyStatuses.any((s) => s.branch.id == 1), isTrue);
      },
    );
  });

  group('Şube Sorumlusu UI & Widget İzolasyon Testleri', () {
    testWidgets(
      'HasibuShellScreen never displays Merkez data across all allowed tabs for branchSupervisor',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(autoCloudBackupEnabled: false),
        );

        db.upsertAppUser(
          AppUserAccount(
            id: 'USR-SUBE-38',
            username: 'devteysti_mgr',
            displayName: 'Devteyşti Sorumlusu',
            passwordHash: HasibuSecurityService.hashPassword('Dev#2026'),
            role: AppUserRole.branchSupervisor,
            allowedModules: const [
              HasibuModule.pdksHr,
              HasibuModule.employeePortal,
            ],
            allowedBranchId: 38,
            createdAtIso: DateTime.now().toIso8601String(),
          ),
        );

        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hasibuDatabaseProvider.overrideWithValue(db),
              googleDriveSyncServiceProvider.overrideWithValue(sync),
              googleAuthAdapterProvider
                  .overrideWithValue(_FakeGoogleAuthAdapter()),
            ],
            child: const HasibuApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Login ekranından Şube Sorumlusu ile giriş yap
        await tester.tap(find.byKey(const ValueKey('login_user_chip_devteysti_mgr')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          'Dev#2026',
        );
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Canlı Yoklama
        expect(find.text('Tüm Şubeler & Merkez'), findsNothing);
        expect(find.text('Merkez Fabrika & Üretim'), findsNothing);
        expect(find.text('MEHMET AKAR'), findsNothing);
        expect(find.text('MEHMET SİNAN CENAN'), findsNothing);
        expect(find.byKey(const ValueKey('locked_branch_scope_chip')), findsOneWidget);
        expect(find.text('Şube Devteyşti'), findsWidgets);
        expect(find.text('FUAT GÜMÜŞKOLAN'), findsWidgets);

        // Diğer izinli sekmelerde Merkez verisi sızmamalı
        for (final navKey in const [
          'nav_attendance_report',
          'nav_leaves_reports',
          'nav_attendance_correction',
          'nav_hr_requests',
          'nav_face_terminals',
          'nav_employee_portal',
        ]) {
          await tester.tap(find.byKey(ValueKey(navKey)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Exception on $navKey');
          expect(
            find.text('Merkez Fabrika & Üretim'),
            findsNothing,
            reason: 'Merkez branch leaked on $navKey',
          );
          expect(
            find.text('MEHMET AKAR'),
            findsNothing,
            reason: 'Merkez employee leaked on $navKey',
          );
        }

        // QR / GPS ekranında 1 saniyelik TOTP sayacı olduğundan pump() kullan
        await tester.tap(find.byKey(const ValueKey('nav_branch_qr_gps')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('Merkez Fabrika & Üretim'), findsNothing);
        expect(find.text('Şube Devteyşti'), findsWidgets);
      },
    );

    testWidgets(
      'HasibuShellScreen handles branchSupervisor with unknown/empty branch cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(autoCloudBackupEnabled: false),
        );

        db.upsertAppUser(
          AppUserAccount(
            id: 'USR-SUBE-999',
            username: 'empty_mgr',
            displayName: 'Boş Şube Sorumlusu',
            passwordHash: HasibuSecurityService.hashPassword('Empty#999'),
            role: AppUserRole.branchSupervisor,
            allowedModules: const [
              HasibuModule.pdksHr,
              HasibuModule.employeePortal,
            ],
            allowedBranchId: 999,
            createdAtIso: DateTime.now().toIso8601String(),
          ),
        );

        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hasibuDatabaseProvider.overrideWithValue(db),
              googleDriveSyncServiceProvider.overrideWithValue(sync),
              googleAuthAdapterProvider
                  .overrideWithValue(_FakeGoogleAuthAdapter()),
            ],
            child: const HasibuApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('login_user_chip_empty_mgr')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          'Empty#999',
        );
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final navKey in const [
          'nav_attendance_report',
          'nav_leaves_reports',
          'nav_attendance_correction',
          'nav_hr_requests',
          'nav_face_terminals',
          'nav_employee_portal',
        ]) {
          await tester.tap(find.byKey(ValueKey(navKey)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Exception on $navKey');
        }

        await tester.tap(find.byKey(const ValueKey('nav_branch_qr_gps')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('Yetkili şube kaydı bulunamadı.'), findsOneWidget);
      },
    );

    testWidgets(
      'AppUsersManagementCard auto-selects non-Merkez branch and hides Tüm Şubeler when role switches to Şube Sorumlusu',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(autoCloudBackupEnabled: false),
        );
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hasibuDatabaseProvider.overrideWithValue(db),
              googleDriveSyncServiceProvider.overrideWithValue(sync),
              googleAuthAdapterProvider
                  .overrideWithValue(_FakeGoogleAuthAdapter()),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AppUsersManagementCard(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('btn_add_app_user')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Başlangıç rolü İK Yöneticisi => "Tüm Şubeler" çipi mevcut
        expect(
          find.byKey(const ValueKey('app_user_branch_chip_all')),
          findsOneWidget,
        );

        // Rolü Şube Sorumlusu olarak değiştir
        await tester.tap(find.byKey(const ValueKey('app_user_role_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppUserRole.branchSupervisor.label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // "Tüm Şubeler" çipi gizlenmiş ve merkez olmayan bir şube otomatik seçilmiş olmalı
        expect(
          find.byKey(const ValueKey('app_user_branch_chip_all')),
          findsNothing,
        );
        expect(
          find.text(
            'Şube Sorumlusu yalnızca seçili şubelerin verilerini görür (birden fazla şube seçebilirsiniz).',
          ),
          findsOneWidget,
        );
        final chip38 = tester.widget<FilterChip>(
          find.byKey(const ValueKey('app_user_branch_chip_38')),
        );
        expect(chip38.selected, isTrue);

        // İkinci şube olarak Yenişehir'i (39) de seç ve kaydet -> [38, 39]
        await tester.tap(find.byKey(const ValueKey('app_user_branch_chip_39')));
        await tester.pumpAndSettle();
        expect(find.text('2 Şube Seçili'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('app_user_username_field')),
          'bolge_38_39',
        );
        await tester.enterText(
          find.byKey(const ValueKey('app_user_display_name_field')),
          'Bölge Sorumlusu',
        );
        await tester.enterText(
          find.byKey(const ValueKey('app_user_password_field')),
          'Bolge#2026',
        );
        await tester.tap(find.byKey(const ValueKey('btn_save_app_user')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('btn_save_app_user')), findsNothing);

        final savedUser = db.findAppUserByUsername('bolge_38_39');
        expect(savedUser, isNotNull);
        expect(savedUser!.effectiveAllowedBranchIds, equals([38, 39]));
        expect(
          find.textContaining('Şube: Şube Devteyşti, Şube Yenişehir'),
          findsOneWidget,
        );

        // İK Yöneticisi için "Merkez Hariç Tümü" kısayolu [38, 39, 40] seçmeli
        await tester.ensureVisible(find.byKey(const ValueKey('btn_add_app_user')));
        await tester.tap(find.byKey(const ValueKey('btn_add_app_user')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('app_user_branch_select_non_merkez')),
        );
        await tester.pumpAndSettle();
        expect(find.text('3 Şube Seçili'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('app_user_username_field')),
          'ik_subeler',
        );
        await tester.enterText(
          find.byKey(const ValueKey('app_user_display_name_field')),
          'İK Şubeler',
        );
        await tester.enterText(
          find.byKey(const ValueKey('app_user_password_field')),
          'Ik#2026',
        );
        await tester.tap(find.byKey(const ValueKey('btn_save_app_user')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('btn_save_app_user')), findsNothing);
        expect(
          db.findAppUserByUsername('ik_subeler')?.effectiveAllowedBranchIds,
          equals([38, 39, 40]),
        );
      },
    );

    testWidgets(
      'HasibuShellScreen supports multi-branch supervisor [38, 39] filtering without leaking Merkez or branch 40',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(autoCloudBackupEnabled: false),
        );

        db.upsertAppUser(
          AppUserAccount(
            id: 'USR-MULTI-38-39',
            username: 'bolge_mgr',
            displayName: 'Bölge Sorumlusu',
            passwordHash: HasibuSecurityService.hashPassword('Multi#2026'),
            role: AppUserRole.branchSupervisor,
            allowedModules: const [
              HasibuModule.pdksHr,
              HasibuModule.employeePortal,
            ],
            allowedBranchIds: const [38, 39],
            createdAtIso: DateTime.now().toIso8601String(),
          ),
        );

        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hasibuDatabaseProvider.overrideWithValue(db),
              googleDriveSyncServiceProvider.overrideWithValue(sync),
              googleAuthAdapterProvider
                  .overrideWithValue(_FakeGoogleAuthAdapter()),
            ],
            child: const HasibuApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('login_user_chip_bolge_mgr')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          'Multi#2026',
        );
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.text('Tüm Şubeler & Merkez'), findsNothing);
        expect(find.text('Merkez Fabrika & Üretim'), findsNothing);
        expect(find.text('Şube Karaköprü'), findsNothing);
        expect(find.text('MEHMET AKAR'), findsNothing);
        expect(find.text('İSMAİL İNANÇ'), findsNothing);

        expect(
          find.byKey(const ValueKey('scoped_all_my_branches_chip')),
          findsOneWidget,
        );
        expect(find.text('Yetkili Şubelerim (2)'), findsOneWidget);
        expect(find.text('Şube Devteyşti'), findsWidgets);
        expect(find.text('Şube Yenişehir'), findsWidgets);
        expect(find.text('FUAT GÜMÜŞKOLAN'), findsWidgets);
        expect(find.text('MEHMET SALİH YEDİKARDEŞ'), findsWidgets);

        // Tek bir yetkili şube çipine tıklandığında diğer şube filtrelenir
        await tester.tap(find.widgetWithText(ChoiceChip, 'Şube Yenişehir'));
        await tester.pumpAndSettle();
        expect(find.text('FUAT GÜMÜŞKOLAN'), findsNothing);
        expect(find.text('MEHMET SALİH YEDİKARDEŞ'), findsWidgets);

        // "Yetkili Şubelerim (2)" çipine dönünce her iki yetkili şube tekrar görünür
        await tester.tap(
          find.byKey(const ValueKey('scoped_all_my_branches_chip')),
        );
        await tester.pumpAndSettle();
        expect(find.text('FUAT GÜMÜŞKOLAN'), findsWidgets);
        expect(find.text('MEHMET SALİH YEDİKARDEŞ'), findsWidgets);

        for (final navKey in const [
          'nav_attendance_report',
          'nav_leaves_reports',
          'nav_attendance_correction',
          'nav_hr_requests',
          'nav_face_terminals',
          'nav_employee_portal',
        ]) {
          await tester.tap(find.byKey(ValueKey(navKey)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Exception on $navKey');
          expect(find.text('Merkez Fabrika & Üretim'), findsNothing);
          expect(find.text('Şube Karaköprü'), findsNothing);
          expect(find.text('MEHMET AKAR'), findsNothing);
        }

        await tester.tap(find.byKey(const ValueKey('nav_branch_qr_gps')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('Merkez Fabrika & Üretim'), findsNothing);
        expect(find.text('Şube Karaköprü'), findsNothing);
        expect(find.text('Şube Devteyşti'), findsWidgets);
        expect(find.text('Şube Yenişehir'), findsWidgets);
      },
    );
  });

  group('Çoklu Şube Kapsamı (Multi-Branch Isolation & Persistence)', () {
    test(
      'multi-branch allowedBranchIds [38, 39] persists in SQLite & Cloud Snapshot, enforces isolation against Merkez (1) and Branch 40, and allows authorized branch switching',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(autoCloudBackupEnabled: false),
        );
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );
        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            googleDriveSyncServiceProvider.overrideWithValue(sync),
            googleAuthAdapterProvider.overrideWithValue(_FakeGoogleAuthAdapter()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(pdksDashboardProvider.notifier);
        await notifier.updateCloudBackupSettings(autoCloudBackupEnabled: false);
        notifier.setSelectedDate('2026-10-19');

        final allEmps = db.getEmployees();
        final merkezEmp = allEmps.firstWhere((e) => e.branchId == 1);
        final b38Emp = allEmps.firstWhere((e) => e.branchId == 38);
        final b39Emp = allEmps.firstWhere((e) => e.branchId == 39);
        final b40Emp = allEmps.firstWhere((e) => e.branchId == 40);

        // Her 4 şube için izin, evrak, talep, manipüle log ve audit log ekle
        for (final entry in [
          (emp: merkezEmp, key: 'merkez'),
          (emp: b38Emp, key: 'b38'),
          (emp: b39Emp, key: 'b39'),
          (emp: b40Emp, key: 'b40'),
        ]) {
          db.upsertLeaveRecord(
            LeaveRecord(
              id: 'lv_mb_${entry.key}',
              employeeId: entry.emp.id,
              date: '2026-10-19',
              leaveType: LeaveType.yillikIzin,
              note: 'İzin ${entry.key}',
            ),
          );
          db.upsertPersonnelDocument(
            PersonnelDocument(
              id: 'doc_mb_${entry.key}',
              employeeId: entry.emp.id,
              category: PersonnelDocumentCategory.kimlikFotokopisi,
              title: 'Kimlik ${entry.key}',
              filePath: '/tmp/${entry.key}.pdf',
              uploadDate: '2026-10-19',
            ),
          );
          db.upsertHrRequest(
            HrRequest(
              id: 'req_mb_${entry.key}',
              employeeId: entry.emp.id,
              employeeCardNo: entry.emp.cardNo,
              employeeName: entry.emp.fullName,
              type: HrRequestType.annualLeave,
              targetDate: '2026-10-20',
              reason: 'Talep ${entry.key}',
              createdAt: '2026-10-19 09:00',
            ),
          );
          db.upsertAttendanceLog(
            AttendanceLog(
              id: 'log_mb_${entry.key}',
              cardNo: entry.emp.cardNo,
              branchId: entry.emp.branchId,
              deviceNo: entry.emp.branchId,
              timestamp: DateTime(2026, 10, 19, 8, 15),
              isCheckIn: true,
              source: AttendanceSource.mobileQr,
              verifyMethod: VerifyMethod.mobileQr,
            ),
          );
          db.appendAuditLog(
            actorEmployeeId: 'admin',
            actionType: 'EMPLOYEE_EMPLOYMENT_DATES_UPDATED',
            targetRecordId: entry.emp.cardNo,
            oldValue: 'old',
            newValue: 'new',
          );
        }
        db.rawDb.execute(
          "UPDATE attendance_logs SET integrity_hash = 'TAMPERED' WHERE id LIKE 'log_mb_%'",
        );

        // Çok şubeli Şube Sorumlusu + Çok şubeli İK Yöneticisi kaydet
        expect(
          await notifier.saveAppUser(
            username: 'bolge_38_39',
            displayName: 'Bölge 38-39',
            plainPassword: 'Bolge#3839',
            role: AppUserRole.branchSupervisor,
            allowedModules: const [
              HasibuModule.pdksHr,
              HasibuModule.employeePortal,
            ],
            allowedBranchIds: const [39, 38, 39],
          ),
          isNull,
        );
        expect(
          await notifier.saveAppUser(
            username: 'ik_38_39',
            displayName: 'İK 38-39',
            plainPassword: 'Ik#3839',
            role: AppUserRole.hrManager,
            allowedModules: const [HasibuModule.pdksHr],
            allowedBranchIds: const [38, 39],
          ),
          isNull,
        );

        // SQLite kolon doğrulaması
        final rawRow = db.rawDb.select(
          "SELECT allowed_branch_id, allowed_branch_ids FROM app_users WHERE username = 'bolge_38_39'",
        ).first;
        expect(rawRow['allowed_branch_id'], equals(38));
        expect(rawRow['allowed_branch_ids'], equals('38,39'));

        // Cloud snapshot export / restore round-trip doğrulaması
        final snapshot = db.exportCloudSnapshot(deviceName: 'Merkez PC');
        final db2 = HasibuDatabase.inMemory();
        addTearDown(db2.dispose);
        db2.restoreCloudSnapshot(snapshot, mode: CloudRestoreMode.merge);
        final restoredUser = db2.findAppUserByUsername('bolge_38_39');
        expect(restoredUser?.effectiveAllowedBranchIds, equals([38, 39]));

        // Çoklu şube sorumlusu ile giriş yap
        expect(
          notifier.loginAsAdmin(username: 'bolge_38_39', password: 'Bolge#3839'),
          isTrue,
        );

        final st = container.read(pdksDashboardProvider);
        expect(st.isBranchScoped, isTrue);
        expect(st.isSingleBranchScoped, isFalse);
        expect(st.effectiveBranchScopeIds, equals([38, 39]));
        expect(st.branches.map((b) => b.id).toList(), equals([38, 39]));
        expect(
          st.dailyStatuses.map((s) => s.branch.id).toSet(),
          equals({38, 39}),
        );
        expect(st.allLeaveRecords.any((l) => l.id == 'lv_mb_b38'), isTrue);
        expect(st.allLeaveRecords.any((l) => l.id == 'lv_mb_b39'), isTrue);
        expect(st.allLeaveRecords.any((l) => l.id == 'lv_mb_merkez'), isFalse);
        expect(st.allLeaveRecords.any((l) => l.id == 'lv_mb_b40'), isFalse);

        expect(
          st.allPersonnelDocuments.any((d) => d.id == 'doc_mb_b38'),
          isTrue,
        );
        expect(
          st.allPersonnelDocuments.any((d) => d.id == 'doc_mb_b39'),
          isTrue,
        );
        expect(
          st.allPersonnelDocuments.any((d) => d.id == 'doc_mb_merkez'),
          isFalse,
        );
        expect(
          st.allPersonnelDocuments.any((d) => d.id == 'doc_mb_b40'),
          isFalse,
        );

        expect(st.allHrRequests.any((r) => r.id == 'req_mb_b38'), isTrue);
        expect(st.allHrRequests.any((r) => r.id == 'req_mb_b39'), isTrue);
        expect(st.allHrRequests.any((r) => r.id == 'req_mb_merkez'), isFalse);
        expect(st.allHrRequests.any((r) => r.id == 'req_mb_b40'), isFalse);

        expect(
          st.tamperedAttendanceLogs.map((l) => l.id).toSet(),
          containsAll({'log_mb_b38', 'log_mb_b39'}),
        );
        expect(
          st.tamperedAttendanceLogs.any(
            (l) => l.id == 'log_mb_merkez' || l.id == 'log_mb_b40',
          ),
          isFalse,
        );
        expect(
          st.auditLogs.any((a) => a.targetRecordId == b38Emp.cardNo),
          isTrue,
        );
        expect(
          st.auditLogs.any((a) => a.targetRecordId == b39Emp.cardNo),
          isTrue,
        );
        expect(
          st.auditLogs.any(
            (a) =>
                a.targetRecordId == merkezEmp.cardNo ||
                a.targetRecordId == b40Emp.cardNo,
          ),
          isFalse,
        );

        // Yetkili şubeler arasında filtreleme çalışmalı, yetkisizler reddedilmeli
        notifier.setBranchFilter(38);
        expect(
          container
              .read(pdksDashboardProvider)
              .filteredByBranch
              .map((s) => s.branch.id)
              .toSet(),
          equals({38}),
        );
        notifier.setBranchFilter(39);
        expect(
          container
              .read(pdksDashboardProvider)
              .filteredByBranch
              .map((s) => s.branch.id)
              .toSet(),
          equals({39}),
        );
        notifier.setBranchFilter(null);
        expect(
          container
              .read(pdksDashboardProvider)
              .filteredByBranch
              .map((s) => s.branch.id)
              .toSet(),
          equals({38, 39}),
        );
        notifier.setBranchFilter(1);
        expect(
          container.read(pdksDashboardProvider).effectiveSelectedBranchId,
          isNull,
        );
        notifier.setBranchFilter(40);
        expect(
          container.read(pdksDashboardProvider).effectiveSelectedBranchId,
          isNull,
        );

        // Rapor & CSV filtreleri
        final repAll = notifier.buildAttendancePeriodReport(
          startDateKey: '2026-10-19',
          endDateKey: '2026-10-19',
          branchId: null,
        );
        expect(repAll.map((r) => r.branch.id).toSet(), equals({38, 39}));

        final rep39 = notifier.buildAttendancePeriodReport(
          startDateKey: '2026-10-19',
          endDateKey: '2026-10-19',
          branchId: 39,
        );
        expect(rep39.map((r) => r.branch.id).toSet(), equals({39}));

        final repMerkez = notifier.buildAttendancePeriodReport(
          startDateKey: '2026-10-19',
          endDateKey: '2026-10-19',
          branchId: 1,
        );
        expect(repMerkez.map((r) => r.branch.id).toSet(), equals({38, 39}));

        final rep40 = notifier.buildAttendancePeriodReport(
          startDateKey: '2026-10-19',
          endDateKey: '2026-10-19',
          branchId: 40,
        );
        expect(rep40.map((r) => r.branch.id).toSet(), equals({38, 39}));

        // Yetkili şubelerde (38 & 39) yazma çalışmalı, Merkez (1) ve 40 engellenmeli
        await notifier.assignLeaveOrReport(
          employeeId: b39Emp.id,
          leaveType: LeaveType.yillikIzin,
          note: 'Yetkili 39 Güncelleme',
        );
        expect(
          db.getAllLeaveRecords().any(
                (l) =>
                    l.employeeId == b39Emp.id &&
                    l.note == 'Yetkili 39 Güncelleme',
              ),
          isTrue,
        );

        await notifier.assignLeaveOrReport(
          employeeId: b40Emp.id,
          leaveType: LeaveType.saglikRaporu,
          note: 'Yetkisiz 40',
        );
        expect(
          db.getAllLeaveRecords().any((l) => l.note == 'Yetkisiz 40'),
          isFalse,
        );
        await notifier.deleteLeaveRecord('lv_mb_merkez');
        expect(
          db.getAllLeaveRecords().any((l) => l.id == 'lv_mb_merkez'),
          isTrue,
        );

        // Çok şubeli İK Yöneticisi de yalnızca [38, 39] görmeli
        notifier.logout();
        expect(
          notifier.loginAsAdmin(username: 'ik_38_39', password: 'Ik#3839'),
          isTrue,
        );
        expect(
          container
              .read(pdksDashboardProvider)
              .branches
              .map((b) => b.id)
              .toList(),
          equals([38, 39]),
        );
      },
    );
  });
}
