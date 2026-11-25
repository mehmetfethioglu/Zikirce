import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';
import 'package:hasibu/core/services/hasibu_print_service.dart';
import 'package:hasibu/core/utils/turkish_search.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/domain/pdks_print_builders.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/features/pdks/presentation/screens/attendance_absence_report_view.dart';
import 'package:hasibu/features/pdks/presentation/screens/hasibu_settings_view.dart';
import 'package:hasibu/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHasibuPrintGateway implements HasibuPrintGateway {
  final List<PrintableDocument> printedDocs = <PrintableDocument>[];
  final List<PrintableDocument> savedDocs = <PrintableDocument>[];

  @override
  Future<PrintDispatchResult> printDocument(PrintableDocument document) async {
    printedDocs.add(document);
    return PrintDispatchResult(
      success: true,
      message: 'Yazdırma başlatıldı: ${document.jobName}',
      outputPath: '/tmp/${document.jobName}.html',
    );
  }

  @override
  Future<PrintDispatchResult> savePrintableFile(
    PrintableDocument document, {
    String? customPath,
  }) async {
    savedDocs.add(document);
    return PrintDispatchResult(
      success: true,
      message: 'Belge kaydedildi: ${document.jobName}',
      outputPath: customPath ?? '/tmp/${document.jobName}.html',
    );
  }
}

HasibuDatabase _buildTestDb() {
  final db = HasibuDatabase.inMemory();
  db.saveCompanySettings(
    db.getCompanySettings().copyWith(
          companyName: 'AKAR TEST GIDA A.Ş.',
          adminPasswordUpdated: true,
          adminPassword: HasibuSecurityService.hashPassword('TestAdmin#2026'),
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
      title: 'Kalite Uzmanı',
      departmentId: 1,
      branchId: 1,
      shiftId: 1,
      hireDate: '2023-05-15',
    ),
  );
  db.upsertEmployee(
    const Employee(
      id: 903,
      cardNo: '99903',
      fullName: 'İBRAHİM ŞAHİN',
      title: 'Lojistik Sorumlusu',
      departmentId: 1,
      branchId: 1,
      shiftId: 1,
      hireDate: '2021-01-10',
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

  group('Türkçe Arama Normalizasyonu & State Sıfırlama Birim Testleri', () {
    test('normalizeTurkishSearch and matchesTurkishSearch fold Turkish characters and trim spaces', () {
      expect(normalizeTurkishSearch('   '), isEmpty);
      expect(normalizeTurkishSearch('Mehmet'), equals('mehmet'));
      expect(normalizeTurkishSearch('İBRAHİM'), equals('ibrahim'));
      expect(normalizeTurkishSearch('IŞIK'), equals('işik'));

      expect(matchesTurkishSearch('İBRAHİM ŞAHİN', normalizeTurkishSearch('ibrahim')), isTrue);
      expect(matchesTurkishSearch('MEHMET KARAHANLI', normalizeTurkishSearch('mehmet')), isTrue);
      expect(matchesTurkishSearch('AYŞE KAYA', normalizeTurkishSearch('mehmet')), isFalse);
      expect(matchesTurkishSearch('AYŞE KAYA', ''), isTrue);
    });

    test('PdksDashboardNotifier clears filter when searchQuery becomes empty or whitespace', () {
      final db = _buildTestDb();
      addTearDown(db.dispose);

      final container = ProviderContainer(
        overrides: [hasibuDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pdksDashboardProvider.notifier);
      final initialCount = container.read(pdksDashboardProvider).visibleStatuses.length;
      expect(initialCount, greaterThanOrEqualTo(3));

      notifier.setSearchQuery('mehmet');
      final mehmetOnly = container.read(pdksDashboardProvider).visibleStatuses;
      expect(mehmetOnly, isNotEmpty);
      expect(
        mehmetOnly.every((s) => s.employee.fullName.toUpperCase().contains('MEHMET')),
        isTrue,
      );
      expect(mehmetOnly.length, lessThan(initialCount));

      // Silindikten sonra (boş veya sadece boşluk) tüm kadro geri gelmelidir
      notifier.setSearchQuery('');
      expect(
        container.read(pdksDashboardProvider).visibleStatuses.length,
        equals(initialCount),
      );

      notifier.setSearchQuery('mehmet');
      notifier.setSearchQuery('   ');
      expect(container.read(pdksDashboardProvider).searchQuery, isEmpty);
      expect(
        container.read(pdksDashboardProvider).visibleStatuses.length,
        equals(initialCount),
      );
    });
  });

  group('A4 Yazdırılabilir Belge Üreticileri', () {
    test('All 5 HasibuPrintBuilders generate valid escaped A4 HTML and plain text', () {
      final db = _buildTestDb();
      addTearDown(db.dispose);

      final container = ProviderContainer(
        overrides: [hasibuDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final state = container.read(pdksDashboardProvider);
      final notifier = container.read(pdksDashboardProvider.notifier);
      final mehmetStatus = state.dailyStatuses.firstWhere(
        (s) => s.employee.cardNo == '99901',
      );

      final cardDoc = HasibuPrintBuilders.buildEmployeeCardDocument(
        companySettings: state.companySettings.copyWith(
          companyName: 'AKAR <TEST> & GIDA',
        ),
        status: mehmetStatus,
        selectedDateKey: state.selectedDate,
        documents: state.documentsForEmployee(mehmetStatus.employee.id),
        historyEntries: notifier.getEmployeeHistory(mehmetStatus.employee),
      );
      expect(cardDoc.landscape, isFalse);
      expect(cardDoc.htmlContent, contains('@page { size: A4 portrait'));
      expect(cardDoc.htmlContent, contains('AKAR &lt;TEST&gt; &amp; GIDA'));
      expect(cardDoc.htmlContent, contains('MEHMET KARAHANLI'));
      expect(cardDoc.plainTextSummary, contains('99901'));

      final dirDoc = HasibuPrintBuilders.buildEmployeeDirectoryListDocument(
        companySettings: state.companySettings,
        items: state.dailyStatuses,
        documentCountsByEmployeeId: const {901: 2, 902: 1},
        filterDescription: 'Tüm Kadro',
      );
      expect(dirDoc.landscape, isTrue);
      expect(dirDoc.htmlContent, contains('@page { size: A4 landscape'));
      expect(dirDoc.htmlContent, contains('MEHMET KARAHANLI'));
      expect(dirDoc.htmlContent, contains('AYŞE KAYA'));

      final liveDoc = HasibuPrintBuilders.buildLiveAttendanceListDocument(
        companySettings: state.companySettings,
        selectedDateKey: state.selectedDate,
        filterDescription: 'Tüm Şubeler',
        items: state.visibleStatuses,
        totalCount: state.totalCount,
        presentCount: state.presentCount,
        lateCount: state.lateCount,
        absentCount: state.absentCount,
        onLeaveCount: state.onLeaveCount,
        sickReportCount: state.sickReportCount,
      );
      expect(liveDoc.landscape, isTrue);
      expect(liveDoc.htmlContent, contains('Canlı Yoklama Çizelgesi'));

      final periodRows = notifier.buildAttendancePeriodReport(
        startDateKey: state.selectedDate,
        endDateKey: state.selectedDate,
      );
      final reportDoc = HasibuPrintBuilders.buildAttendancePeriodReportDocument(
        companySettings: state.companySettings,
        startDateKey: state.selectedDate,
        endDateKey: state.selectedDate,
        filterDescription: 'Tüm Şubeler',
        rows: periodRows,
      );
      expect(reportDoc.landscape, isTrue);
      expect(reportDoc.htmlContent, contains('Devam / Devamsızlık Raporu'));

      final leaveDoc = HasibuPrintBuilders.buildLeaveRecordsReportDocument(
        companySettings: state.companySettings,
        scopeTitle: 'MEHMET KARAHANLI (#99901)',
        records: const [
          LeaveRecord(
            id: 'lv_1',
            employeeId: 901,
            date: '2026-11-25',
            leaveType: LeaveType.yillikIzin,
            note: 'Yıllık izin',
          ),
        ],
        statusByEmployeeId: {for (final s in state.dailyStatuses) s.employee.id: s},
        singleEmployeeStatus: mehmetStatus,
      );
      expect(leaveDoc.landscape, isFalse);
      expect(leaveDoc.htmlContent, contains('Yıllık İzin'));
      expect(leaveDoc.plainTextSummary, contains('MEHMET KARAHANLI'));
    });
  });

  group('Canlı Yoklama Arama Sıfırlama ve Yazdırma UI Testleri', () {
    testWidgets(
      'Clearing search box in Live Attendance restores full list and syncs across navigation',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = _buildTestDb();
        addTearDown(db.dispose);
        final fakePrint = _FakeHasibuPrintGateway();

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            hasibuPrintGatewayProvider.overrideWithValue(fakePrint),
          ],
        );
        addTearDown(container.dispose);

        container.read(pdksDashboardProvider.notifier).loginAsAdmin(
              username: 'admin',
              password: 'TestAdmin#2026',
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const HasibuApp(),
          ),
        );
        await tester.pumpAndSettle();

        final allStatuses = container.read(pdksDashboardProvider).visibleStatuses;
        final initialCount = allStatuses.length;
        final nonMehmetTopName = allStatuses
            .firstWhere((s) => !s.employee.fullName.toUpperCase().contains('MEHMET'))
            .employee
            .fullName;
        expect(find.text(nonMehmetTopName), findsAtLeastNWidgets(1));

        // 1. Arama kutusuna 'mehmet' yaz
        await tester.enterText(
          find.byKey(const ValueKey('live_pdks_search_field')),
          'mehmet',
        );
        await tester.pumpAndSettle();

        expect(find.text('MEHMET KARAHANLI'), findsOneWidget);
        expect(find.text(nonMehmetTopName), findsNothing);
        expect(
          find.byKey(const ValueKey('live_pdks_active_search_chip')),
          findsOneWidget,
        );

        // 2. Arama kutusundaki metni sil -> tüm liste hemen geri gelmeli
        await tester.enterText(
          find.byKey(const ValueKey('live_pdks_search_field')),
          '',
        );
        await tester.pumpAndSettle();

        expect(
          container.read(pdksDashboardProvider).visibleStatuses.length,
          equals(initialCount),
        );
        expect(find.text(nonMehmetTopName), findsAtLeastNWidgets(1));
        expect(
          find.byKey(const ValueKey('live_pdks_active_search_chip')),
          findsNothing,
        );

        // 3. Tekrar 'mehmet' yaz, başka sekmeye geç ve geri dön -> kutu 'mehmet' ile senkron kalmalı
        await tester.enterText(
          find.byKey(const ValueKey('live_pdks_search_field')),
          'mehmet',
        );
        await tester.pumpAndSettle();
        expect(find.text(nonMehmetTopName), findsNothing);

        await tester.tap(find.text('Personel & Bölüm'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Canlı Yoklama'));
        await tester.pumpAndSettle();

        final fieldWidget = tester.widget<TextField>(
          find.byKey(const ValueKey('live_pdks_search_field')),
        );
        expect(fieldWidget.controller?.text, equals('mehmet'));
        expect(find.text(nonMehmetTopName), findsNothing);

        // 4. Temizle (x) ikonuyla sil -> tüm kadro tekrar görünmeli
        await tester.tap(
          find.byKey(const ValueKey('live_pdks_clear_search_button')),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(pdksDashboardProvider).visibleStatuses.length,
          equals(initialCount),
        );
        expect(find.text(nonMehmetTopName), findsAtLeastNWidgets(1));

        // 5. Canlı Yoklama listesini yazdır
        await tester.tap(
          find.byKey(const ValueKey('live_pdks_print_list_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('print_dialog_execute_button')),
        );
        await tester.pumpAndSettle();

        expect(fakePrint.printedDocs.length, equals(1));
        expect(fakePrint.printedDocs.first.jobName, startsWith('Canli_Yoklama_'));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );

    testWidgets(
      'Personnel management list, employee card, dossier, and reports support printing',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = _buildTestDb();
        addTearDown(db.dispose);
        final fakePrint = _FakeHasibuPrintGateway();

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            hasibuPrintGatewayProvider.overrideWithValue(fakePrint),
          ],
        );
        addTearDown(container.dispose);

        container.read(pdksDashboardProvider.notifier).loginAsAdmin(
              username: 'admin',
              password: 'TestAdmin#2026',
            );

        // 1. Personel & Bölüm Listesi ve Personel Kartı Yazdırma
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: EmployeesManagementSettingsView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('employees_print_list_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('print_dialog_execute_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();

        expect(fakePrint.printedDocs.last.jobName, equals('Personel_Listesi'));

        // 99901 personelini arayıp tekil kart ve özlük yazdırmasını test et
        await tester.enterText(
          find.byKey(const ValueKey('employees_search_field')),
          '99901',
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('print_employee_card_99901')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('print_dialog_execute_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();

        expect(
          fakePrint.printedDocs.last.jobName,
          contains('Personel_Karti_99901'),
        );

        // 1b. Özlük Dosyası & Geçmiş Penceresinden Yazdırma
        await tester.tap(find.text('MEHMET KARAHANLI (#99901)'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('print_dossier_dialog_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('print_dialog_execute_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kapat').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kapat').last);
        await tester.pumpAndSettle();

        expect(
          fakePrint.printedDocs.last.jobName,
          contains('Personel_Karti_99901'),
        );

        // 2. Devam / Devamsızlık Raporu Yazdırma
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: AttendanceAbsenceReportView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('report_print_button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('print_dialog_execute_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();

        expect(
          fakePrint.printedDocs.last.jobName,
          startsWith('Devam_Devamsizlik_Raporu_'),
        );

        // 3. İzin & Raporlar Yazdırma
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: LeavesAndReportsSettingsView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('leaves_print_button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('print_dialog_execute_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();

        expect(
          fakePrint.printedDocs.last.jobName,
          equals('Izin_ve_Raporlar'),
        );
        expect(fakePrint.printedDocs.length, equals(5));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );
  });
}
