import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';
import 'package:hasibu/core/services/google_drive_sync_service.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

HasibuDatabase _buildTestDb() {
  final db = HasibuDatabase.inMemory();
  db.saveCompanySettings(
    db.getCompanySettings().copyWith(
          companyName: 'AKAR TEST GIDA A.Ş.',
          adminPasswordUpdated: true,
          adminPassword: HasibuSecurityService.hashPassword('TestAdmin#2026'),
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
    ),
  );
  db.upsertBranch(
    const Branch(
      id: 2,
      code: 'SB2',
      name: 'İkinci Şube',
      hasTerminal: false,
      latitude: 37.1700,
      longitude: 38.8000,
    ),
  );
  db.upsertEmployee(
    const Employee(
      id: 901,
      cardNo: '99901',
      fullName: 'MEHMET KARAHANLI',
      title: 'Üretim Ustası',
      departmentId: 1,
      branchId: 1,
      shiftId: 1,
      hireDate: '2022-03-01',
    ),
  );
  db.upsertEmployee(
    const Employee(
      id: 902,
      cardNo: '99902',
      fullName: 'AYŞE KAYA',
      title: 'Mağaza Sorumlusu',
      departmentId: 1,
      branchId: 2,
      shiftId: 1,
      hireDate: '2023-05-15',
    ),
  );
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('Canlı Yoklama Giriş/Çıkış Hareketi Ekleme Testleri', () {
    test('parseStrictTimeHhMm validates 24h HH:mm strings strictly', () {
      expect(
        PdksDashboardNotifier.parseStrictTimeHhMm('08:30'),
        equals((hour: 8, minute: 30)),
      );
      expect(
        PdksDashboardNotifier.parseStrictTimeHhMm('8:05'),
        equals((hour: 8, minute: 5)),
      );
      expect(
        PdksDashboardNotifier.parseStrictTimeHhMm('23:59'),
        equals((hour: 23, minute: 59)),
      );
      expect(PdksDashboardNotifier.parseStrictTimeHhMm('00:00'),
          equals((hour: 0, minute: 0)));
      expect(PdksDashboardNotifier.parseStrictTimeHhMm('24:00'), isNull);
      expect(PdksDashboardNotifier.parseStrictTimeHhMm('12:60'), isNull);
      expect(PdksDashboardNotifier.parseStrictTimeHhMm('abc'), isNull);
      expect(PdksDashboardNotifier.parseStrictTimeHhMm(''), isNull);
    });

    testWidgets(
      'Row quick punch validates input, adds check-in, defaults to check-out next, and supports deletion with audit logs',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        final notifier = container.read(pdksDashboardProvider.notifier);
        notifier.setSelectedDate('2026-10-19');
        expect(
          notifier.loginAsAdmin(
            username: 'admin',
            password: 'TestAdmin#2026',
          ),
          isTrue,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const HasibuApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 0. Hedef personeli görünür alana getir
        await tester.enterText(
          find.byKey(const ValueKey('live_pdks_search_field')),
          '99901',
        );
        await tester.pumpAndSettle();

        // 1. Satır kartı üzerindeki hızlı hareket butonuna tıkla
        final quickPunchBtn =
            find.byKey(const ValueKey('employee_quick_punch_99901'));
        expect(quickPunchBtn, findsOneWidget);
        await tester.tap(quickPunchBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('live_attendance_punch_dialog')),
          findsOneWidget,
        );

        // 2. Geçersiz saat ile kaydetmeye çalış -> hata mesajı gösterilmeli, dialog kapanmamalı
        await tester.enterText(
          find.byKey(const ValueKey('live_punch_time_field')),
          '25:99',
        );
        await tester.tap(find.byKey(const ValueKey('live_punch_save_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Geçerli bir saat girin'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('live_attendance_punch_dialog')),
          findsOneWidget,
        );

        // 3. Geçerli giriş saati (08:12) ve açıklama girip kaydet
        await tester.enterText(
          find.byKey(const ValueKey('live_punch_time_field')),
          '08:12',
        );
        await tester.enterText(
          find.byKey(const ValueKey('live_punch_note_field')),
          'Kapı okuyucu geçici arızası',
        );
        await tester.tap(find.byKey(const ValueKey('live_punch_save_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('live_attendance_punch_dialog')),
          findsNothing,
        );

        final logsAfterIn = notifier.getAttendanceLogsForEmployeeOnDate(
          '99901',
          '2026-10-19',
        );
        expect(logsAfterIn.length, equals(1));
        expect(logsAfterIn.first.isCheckIn, isTrue);
        expect(logsAfterIn.first.timeFormatted, equals('08:12'));
        expect(logsAfterIn.first.source, equals(AttendanceSource.manual));
        expect(logsAfterIn.first.verifyMethod, equals(VerifyMethod.manual));
        expect(logsAfterIn.first.integrityHash, isNotEmpty);

        // Satır kartı 08:12 girişini göstermeli
        final rowFinder = find.byKey(const ValueKey('employee_card_99901'));
        expect(
          find.descendant(
            of: rowFinder,
            matching: find.textContaining('08:12'),
          ),
          findsOneWidget,
        );

        // Audit log kaydı oluşmuş olmalı
        final addedAudits = db
            .getAuditLogs(limit: 20)
            .where((a) => a.actionType == 'MANUAL_ATTENDANCE_ADDED')
            .toList();
        expect(addedAudits, isNotEmpty);
        expect(addedAudits.first.newValue, contains('08:12 IN'));
        expect(
          addedAudits.first.newValue,
          contains('Kapı okuyucu geçici arızası'),
        );

        // 4. Tekrar açınca giriş olduğu için varsayılan Çıkış olmalı ve mevcut giriş çipi görünmeli
        await tester.tap(quickPunchBtn);
        await tester.pumpAndSettle();

        final inLogId = logsAfterIn.first.id;
        expect(
          find.byKey(ValueKey('live_punch_existing_log_$inLogId')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const ValueKey('live_punch_time_field')),
          '18:05',
        );
        await tester.tap(find.byKey(const ValueKey('live_punch_save_button')));
        await tester.pumpAndSettle();

        final logsAfterOut = notifier.getAttendanceLogsForEmployeeOnDate(
          '99901',
          '2026-10-19',
        );
        expect(logsAfterOut.length, equals(2));
        expect(logsAfterOut.last.isCheckIn, isFalse);
        expect(logsAfterOut.last.timeFormatted, equals('18:05'));

        expect(
          find.descendant(
            of: rowFinder,
            matching: find.textContaining('08:12 - 18:05'),
          ),
          findsOneWidget,
        );

        // 5. Dialogdan mevcut çıkış çipini sil -> hareket silinmeli ve audit log yazılmalı
        await tester.tap(quickPunchBtn);
        await tester.pumpAndSettle();

        final outChip =
            find.byKey(ValueKey('live_punch_existing_log_${logsAfterOut.last.id}'));
        expect(outChip, findsOneWidget);
        await tester.tap(
          find.descendant(
            of: outChip,
            matching: find.byIcon(Icons.close_rounded),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          notifier
              .getAttendanceLogsForEmployeeOnDate('99901', '2026-10-19')
              .length,
          equals(1),
        );
        expect(
          db
              .getAuditLogs(limit: 20)
              .any((a) => a.actionType == 'MANUAL_ATTENDANCE_DELETED'),
          isTrue,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );

    testWidgets(
      'Toolbar Hareket Ekle opens employee picker, searches Turkish text, and respects branchSupervisor isolation',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        final notifier = container.read(pdksDashboardProvider.notifier);
        notifier.setSelectedDate('2026-10-19');
        await notifier.saveAppUser(
          username: 'merkez_sorumlu',
          displayName: 'Merkez Şube Sorumlusu',
          plainPassword: 'User#2026',
          role: AppUserRole.branchSupervisor,
          allowedBranchIds: const [1],
          allowedModules: const [HasibuModule.pdksHr],
        );

        expect(
          notifier.loginAsAdmin(
            username: 'merkez_sorumlu',
            password: 'User#2026',
          ),
          isTrue,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const HasibuApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Araç çubuğundaki Hareket Ekle butonuna tıkla
        await tester.tap(find.byKey(const ValueKey('live_pdks_add_punch_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('live_punch_employee_search_field')),
          findsOneWidget,
        );
        // Şube 2 personeli (99902) şube sorumlusu listesinde görünmemeli
        await tester.enterText(
          find.byKey(const ValueKey('live_punch_employee_search_field')),
          '99902',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('live_punch_emp_option_99902')),
          findsNothing,
        );

        // Arama ve seçim ile kaydet
        await tester.enterText(
          find.byKey(const ValueKey('live_punch_employee_search_field')),
          'mehmet karahanli',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('live_punch_emp_option_99901')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('live_punch_emp_option_99901')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('live_punch_time_field')),
          '07:55',
        );
        await tester.tap(find.byKey(const ValueKey('live_punch_save_button')));
        await tester.pumpAndSettle();

        final logs = notifier.getAttendanceLogsForEmployeeOnDate(
          '99901',
          '2026-10-19',
        );
        expect(logs.length, equals(1));
        expect(logs.first.timeFormatted, equals('07:55'));

        // Doğrudan API çağrısı da şube 2 personeli için reddetmeli
        final blocked = await notifier.saveOrUpdateAttendanceLog(
          employee: const Employee(
            id: 902,
            cardNo: '99902',
            fullName: 'AYŞE KAYA',
            title: 'Mağaza Sorumlusu',
            departmentId: 1,
            branchId: 2,
            shiftId: 1,
            hireDate: '2023-05-15',
          ),
          dateKey: '2026-10-19',
          timeHhMm: '08:00',
          isCheckIn: true,
        );
        expect(blocked, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );

    testWidgets(
      'Detail dialog button and mobile toolbar button add punches with zero overflow',
      (tester) async {
        // 1. Önce masaüstünde personel detay penceresindeki butonu doğrula
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        final notifier = container.read(pdksDashboardProvider.notifier);
        notifier.setSelectedDate('2026-10-19');
        notifier.loginAsAdmin(username: 'admin', password: 'TestAdmin#2026');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const HasibuApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('live_pdks_search_field')),
          '99901',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('employee_card_99901')));
        await tester.pumpAndSettle();

        final detailAddBtn =
            find.byKey(const ValueKey('detail_add_punch_99901'));
        expect(detailAddBtn, findsOneWidget);
        await tester.tap(detailAddBtn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('live_punch_time_field')),
          '08:02',
        );
        await tester.tap(find.byKey(const ValueKey('live_punch_save_button')));
        await tester.pumpAndSettle();

        expect(
          notifier
              .getAttendanceLogsForEmployeeOnDate('99901', '2026-10-19')
              .single
              .timeFormatted,
          equals('08:02'),
        );

        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();

        // 2. Mobil görünümde (390x844) taşma olmadan hareket eklenebilmeli
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final mobileAddBtn = find.byKey(
          const ValueKey('live_pdks_mobile_add_punch_button'),
        );
        expect(mobileAddBtn, findsOneWidget);
        await tester.tap(mobileAddBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.enterText(
          find.byKey(const ValueKey('live_punch_employee_search_field')),
          '99901',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('live_punch_emp_option_99901')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('live_punch_time_field')),
          '17:45',
        );
        await tester.tap(find.byKey(const ValueKey('live_punch_save_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final logs = notifier.getAttendanceLogsForEmployeeOnDate(
          '99901',
          '2026-10-19',
        );
        expect(logs.length, equals(2));
        expect(logs.last.timeFormatted, equals('17:45'));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );
  });
}
