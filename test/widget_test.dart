import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/features/pdks/data/tenfei_zk_client.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/main.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/providers/mobil_arayuz_iyilestirme_provider.dart';
import 'package:hasibu/router.dart';
import 'package:hasibu/screens/mobil_arayuz_iyilestirme_screen.dart';


void main() {
  group('Tenfei D35 ZKTeco TCP 4370 Protocol Tests', () {
    test('encodeZkTime and decodeZkTime round-trip accurately', () {
      final dt = DateTime(2026, 10, 19, 5, 45, 0);
      final packed = TenfeiZkClient.encodeZkTime(dt);
      final decoded = TenfeiZkClient.decodeZkTime(packed);
      expect(decoded, equals(dt));
    });

    test('TenfeiZkClient fetches 40-byte binary attendance logs over TCP',
        () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      final record40 = Uint8List(40);
      final bd = ByteData.sublistView(record40);
      bd.setUint16(0, 1, Endian.little);
      final pinBytes = ascii.encode('00064');
      record40.setRange(2, 2 + pinBytes.length, pinBytes);
      record40[26] = 15; // Yüz tanıma (Face)
      bd.setUint32(
        27,
        TenfeiZkClient.encodeZkTime(DateTime(2026, 10, 19, 5, 45, 0)),
        Endian.little,
      );
      record40[31] = 0; // Giriş

      server.listen((Socket clientSocket) {
        clientSocket.listen((Uint8List data) {
          if (data.length < 16) return;
          final inBd = ByteData.sublistView(data);
          final cmd = inBd.getUint16(8, Endian.little);
          final replyId = inBd.getUint16(14, Endian.little);

          if (cmd == TenfeiZkClient.cmdConnect ||
              cmd == TenfeiZkClient.cmdDisableDevice ||
              cmd == TenfeiZkClient.cmdEnableDevice ||
              cmd == TenfeiZkClient.cmdFreeData ||
              cmd == TenfeiZkClient.cmdExit) {
            clientSocket.add(
              TenfeiZkClient.buildTcpFrame(
                command: TenfeiZkClient.cmdAckOk,
                sessionId: 77,
                replyId: replyId,
                payload: Uint8List(0),
              ),
            );
          } else if (cmd == TenfeiZkClient.cmdAttLogRrq) {
            final sizePayload = ByteData(4)..setUint32(0, 40, Endian.little);
            clientSocket.add(
              TenfeiZkClient.buildTcpFrame(
                command: TenfeiZkClient.cmdPrepareData,
                sessionId: 77,
                replyId: replyId,
                payload: sizePayload.buffer.asUint8List(),
              ),
            );
            clientSocket.add(
              TenfeiZkClient.buildTcpFrame(
                command: TenfeiZkClient.cmdData,
                sessionId: 77,
                replyId: replyId,
                payload: record40,
              ),
            );
          }
        });
      });

      final client = TenfeiZkClient(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        branchId: 1,
        machineNo: 1,
      );
      addTearDown(client.dispose);

      final logs = await client.fetchAttendanceLogs();
      expect(logs.length, 1);
      expect(logs.first.cardNo, '00064');
      expect(logs.first.isCheckIn, isTrue);
      expect(logs.first.timestamp, DateTime(2026, 10, 19, 5, 45, 0));
    });

    test(
        'TenfeiZkClient authenticates CMD_ACK_UNAUTH (2005) via CMD_AUTH (1102) and parses 4-byte length-prefixed CMD_DATA with trailing CMD_ACK_OK',
        () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      // Build 2 records (morning check-in + evening check-out) prefixed by 4-byte inner table length (80)
      final payload84 = Uint8List(84);
      final pBd = ByteData.sublistView(payload84);
      pBd.setUint32(0, 80, Endian.little);

      final pinBytes = ascii.encode('00064');
      // Record 1 at offset 4: 05:25 check-in
      pBd.setUint16(4, 1, Endian.little);
      payload84.setRange(6, 6 + pinBytes.length, pinBytes);
      payload84[4 + 26] = 15;
      pBd.setUint32(
        4 + 27,
        TenfeiZkClient.encodeZkTime(DateTime(2026, 10, 20, 5, 25, 0)),
        Endian.little,
      );
      payload84[4 + 31] = 0;

      // Record 2 at offset 44: 17:10 second scan (classified as check-out)
      pBd.setUint16(44, 1, Endian.little);
      payload84.setRange(46, 46 + pinBytes.length, pinBytes);
      payload84[44 + 26] = 15;
      pBd.setUint32(
        44 + 27,
        TenfeiZkClient.encodeZkTime(DateTime(2026, 10, 20, 17, 10, 0)),
        Endian.little,
      );
      payload84[44 + 31] = 0;

      bool authenticated = false;

      server.listen((Socket clientSocket) {
        clientSocket.listen((Uint8List data) {
          if (data.length < 16) return;
          final inBd = ByteData.sublistView(data);
          final cmd = inBd.getUint16(8, Endian.little);
          final replyId = inBd.getUint16(14, Endian.little);

          if (cmd == TenfeiZkClient.cmdConnect) {
            // Return 2005 (CMD_ACK_UNAUTH) like the live Tenfei D35 at 192.168.9.150
            clientSocket.add(
              TenfeiZkClient.buildTcpFrame(
                command: TenfeiZkClient.cmdAckUnauth,
                sessionId: 4999,
                replyId: replyId,
                payload: Uint8List(0),
              ),
            );
          } else if (cmd == TenfeiZkClient.cmdAuth) {
            authenticated = true;
            clientSocket.add(
              TenfeiZkClient.buildTcpFrame(
                command: TenfeiZkClient.cmdAckOk,
                sessionId: 4999,
                replyId: replyId,
                payload: Uint8List(0),
              ),
            );
          } else if (cmd == TenfeiZkClient.cmdDisableDevice ||
              cmd == TenfeiZkClient.cmdEnableDevice ||
              cmd == TenfeiZkClient.cmdFreeData ||
              cmd == TenfeiZkClient.cmdExit) {
            clientSocket.add(
              TenfeiZkClient.buildTcpFrame(
                command: TenfeiZkClient.cmdAckOk,
                sessionId: 4999,
                replyId: replyId,
                payload: Uint8List(0),
              ),
            );
          } else if (cmd == TenfeiZkClient.cmdAttLogRrq && authenticated) {
            final sizePayload = ByteData(4)..setUint32(0, 84, Endian.little);
            clientSocket.add(
              TenfeiZkClient.buildTcpFrame(
                command: TenfeiZkClient.cmdPrepareData,
                sessionId: 4999,
                replyId: replyId,
                payload: sizePayload.buffer.asUint8List(),
              ),
            );
            clientSocket.add(
              TenfeiZkClient.buildTcpFrame(
                command: TenfeiZkClient.cmdData,
                sessionId: 4999,
                replyId: replyId,
                payload: payload84,
              ),
            );
            clientSocket.add(
              TenfeiZkClient.buildTcpFrame(
                command: TenfeiZkClient.cmdAckOk,
                sessionId: 4999,
                replyId: replyId,
                payload: Uint8List(0),
              ),
            );
          }
        });
      });

      final client = TenfeiZkClient(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        branchId: 1,
        machineNo: 1,
      );
      addTearDown(client.dispose);

      final logs = await client.fetchAttendanceLogs();
      expect(authenticated, isTrue);
      expect(logs.length, 2);
      expect(logs[0].cardNo, '00064');
      expect(logs[0].isCheckIn, isTrue);
      expect(logs[1].cardNo, '00064');
      expect(logs[1].isCheckIn, isFalse);
    });
  });

  group('HasibuDatabase & Settings CRUD Tests', () {
    test(
        'Persists company settings, company logo, per-user themes, shifts, branches, employees and exports snapshot',
        () {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      expect(db.getBranches().length, 4);
      expect(db.getShifts().length, 4);
      expect(db.getDepartments().length, 27);
      expect(db.getEmployees().isNotEmpty, isTrue);

      db.saveCompanySettings(
        const CompanySettings(
          companyName: 'AKAR GIDA & BAKLAVA A.Ş.',
          autoPollEnabled: true,
          autoPollMinutes: 10,
          logoPath: 'logo:2',
          adminThemeMode: HasibuThemeMode.dark,
        ),
      );
      final savedSettings = db.getCompanySettings();
      expect(savedSettings.companyName, 'AKAR GIDA & BAKLAVA A.Ş.');
      expect(savedSettings.logoPath, 'logo:2');
      expect(savedSettings.adminThemeMode, HasibuThemeMode.dark);

      db.upsertShift(
        const ShiftPlan(
          id: 99,
          name: 'Gece Üretim',
          startTime: '22:00',
          endTime: '06:00',
          toleranceMinutes: 10,
        ),
      );
      expect(db.getShifts().any((s) => s.id == 99 && s.toleranceMinutes == 10),
          isTrue);

      final snapshot = db.exportCloudSnapshot(deviceName: 'Test-Laptop');
      expect(snapshot['deviceName'], 'Test-Laptop');
      expect((snapshot['shifts'] as List).length, 5);

      // Kişisel parola, modül yetkisi, profil fotoğrafı ve kullanıcıya özgü tema kaydı
      final sampleEmp = db.getEmployees().first.copyWith(
            password: '9876',
            allowedModules: const <HasibuModule>[
              HasibuModule.leanProduction,
              HasibuModule.employeePortal,
            ],
            photoPath: () => 'preset:3',
            themeMode: HasibuThemeMode.dark,
          );
      db.upsertEmployee(sampleEmp);
      final reloadedEmp =
          db.getEmployees().firstWhere((e) => e.id == sampleEmp.id);
      expect(reloadedEmp.password, '9876');
      expect(
        reloadedEmp.allowedModules,
        containsAll(<HasibuModule>[
          HasibuModule.leanProduction,
          HasibuModule.employeePortal,
        ]),
      );
      expect(reloadedEmp.photoPath, 'preset:3');
      expect(reloadedEmp.themeMode, HasibuThemeMode.dark);

      // Toplu Hareket Düzenleme (Bulk Attendance)
      final affected = db.applyBulkManualAttendance(
        employees: db.getEmployees().take(3).toList(),
        dateKey: '2026-10-25',
        checkInTime: '08:00',
        checkOutTime: '18:00',
      );
      expect(affected, 6); // 3 personel x (giriş + çıkış)
      expect(db.getAttendanceLogsForDate('2026-10-25').length, 6);

      // Özlük Dosyası & Resmi Evraklar CRUD
      final initialDocs = db.getDocumentsForEmployee(sampleEmp.id);
      expect(initialDocs.isNotEmpty, isTrue);

      db.upsertPersonnelDocument(
        PersonnelDocument(
          id: 'doc_test_999',
          employeeId: sampleEmp.id,
          category: PersonnelDocumentCategory.sgkIseGirisBildirgesi,
          title: 'SGK İşe Giriş Bildirgesi (E-Bildirge)',
          filePath: r'C:\Hasibu_Ozluk_Arsivi\00064_SGK_Bildirge.pdf',
          uploadDate: '2026-10-20',
          notes: 'E-Devlet barkodlu kopya',
        ),
      );
      final updatedDocs = db.getDocumentsForEmployee(sampleEmp.id);
      expect(
        updatedDocs.any((d) => d.id == 'doc_test_999'),
        isTrue,
      );
      db.deletePersonnelDocument('doc_test_999');
      expect(
        db.getDocumentsForEmployee(sampleEmp.id).any((d) => d.id == 'doc_test_999'),
        isFalse,
      );
    });
  });

  testWidgets(
      'HasibuApp enforces Login Gate with Company Logo, Per-User Theme Switching, Top Module Ribbon, Bulk Attendance, and Gmail Sync Modal',
      (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: HasibuApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Uygulama doğrudan açılmaz, Oturum Açma (Login Gate) ekranı ve Şirket Logosu gelir
    expect(find.byKey(const ValueKey('login_submit_button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('login_company_logo_badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('login_company_logo_button')),
      findsOneWidget,
    );
    expect(find.text('Tüm Şubeler & Merkez'), findsNothing);

    // 2. Yönetici olarak oturum aç (varsayılan admin / 123 dolu gelir)
    await tester.tap(find.byKey(const ValueKey('login_submit_button')));
    await tester.pumpAndSettle();

    // 3. Uygulama içerisinde üst barda Şirket Logosu ve Kişisel Tema seçici görünür
    expect(
      find.byKey(const ValueKey('appbar_company_logo_badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('appbar_theme_selector_button')),
      findsOneWidget,
    );

    // 4. Üst Modül Seçme Satırı (5 ana modül) ve PDKS & İK sol menüsündeki 5 sekme görünür
    expect(find.text('PDKS & İK'), findsOneWidget);
    expect(find.text('Yalın Üretim & KPI'), findsOneWidget);
    expect(find.text('Ön Muhasebe & Puantaj'), findsOneWidget);
    expect(find.text('Personel Portalı'), findsOneWidget);
    expect(find.text('Sistem & Ayarlar'), findsOneWidget);

    expect(find.text('Canlı PDKS & Şubeler'), findsOneWidget);
    expect(find.text('Tenfei D35 & Drive Sync'), findsOneWidget);
    expect(find.text('Şube QR / GPS Yoklama'), findsOneWidget);
    expect(find.text('Hareket Düzeltme'), findsOneWidget);
    expect(find.text('İzin & Rapor Girişi'), findsOneWidget);

    // 4b. Personel kartına dokununca Personel Geçmişi ve Özlük Dosyası (Resmi Evraklar) açılır
    expect(find.byKey(const ValueKey('employee_card_01406')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('employee_card_01406')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('employee_detail_tab_selector')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Personel Geçmişi ('),
      findsOneWidget,
    );

    // Özlük Dosyası sekmesine geç ve resmi evrak ekleme formunu doğrula
    await tester.tap(find.textContaining('Özlük Dosyası & Resmi Evraklar'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dossier_add_document_button')),
      findsOneWidget,
    );
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    // 4c. Üst bardaki Cihaz Bağlantı Kontrolü butonuna tıkla -> Bağlantı Tanılama penceresi açılır
    await tester.tap(find.byKey(const ValueKey('appbar_terminal_diag_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('run_terminal_diag_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('diag_pull_terminal_logs_button')),
      findsOneWidget,
    );
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    // 5. Hareket Düzeltme sekmesine tıkla -> Toplu Hareket Düzenleme paneli açılır
    await tester.tap(find.text('Hareket Düzeltme'));
    await tester.pumpAndSettle();
    expect(
      find.text('Toplu Hareket Düzenleme & Çoklu Giriş/Çıkış Atama'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bulk_attendance_apply_button')),
      findsOneWidget,
    );

    // 6. Üst bardaki Gmail Eşitleme butonuna tıkla -> Gmail & Google Drive kurulum penceresi açılır
    await tester.tap(find.byKey(const ValueKey('gmail_sync_setup_button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Gmail & Google Drive Veri Eşitleme Ayarları'),
      findsOneWidget,
    );
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    // 7. Üst modül satırından "Sistem & Ayarlar" modülüne tıkla -> Sol menü Ayar sekmelerine dönüşür
    await tester.tap(find.text('Sistem & Ayarlar'));
    await tester.pumpAndSettle();

    expect(find.text('1. Şirket, Şube & Cihaz Ayarları'), findsOneWidget);
    expect(find.text('2. Mesai Saatleri & Geç Kalma'), findsOneWidget);
    expect(find.text('3. Personel & Bölüm Yönetimi'), findsOneWidget);
    expect(find.byIcon(Icons.add_business_rounded), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings_company_logo_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings_theme_segmented_button')),
      findsOneWidget,
    );
  });

  group('Mobil Arayüz İyileştirmeleri & Durum Yönetimi (Antigravity 2.0)', () {
    test('MobileUiNotifier updates density mode, quick filters and search query deterministically', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mobileUiProvider.notifier);
      expect(container.read(mobileUiProvider).densityMode, equals(MobileDensityMode.comfortable));
      expect(container.read(mobileUiProvider).isCompact, isFalse);

      notifier.toggleDensityMode();
      expect(container.read(mobileUiProvider).densityMode, equals(MobileDensityMode.compact));
      expect(container.read(mobileUiProvider).isCompact, isTrue);

      notifier.setQuickFilter(DailyAttendanceState.late);
      expect(container.read(mobileUiProvider).activeQuickFilter, equals(DailyAttendanceState.late));

      notifier.setQuickFilter(DailyAttendanceState.late);
      expect(container.read(mobileUiProvider).activeQuickFilter, isNull);

      notifier.setQuickSearchQuery('00064');
      expect(container.read(mobileUiProvider).quickSearchQuery, equals('00064'));

      notifier.clearSearch();
      expect(container.read(mobileUiProvider).quickSearchQuery, isEmpty);
    });

    test('HasibuRouter generates valid routes for mobile dashboard, login, settings and home', () {
      final homeRoute = HasibuRouter.generateRoute(const RouteSettings(name: HasibuRoutes.home));
      expect(homeRoute, isA<MaterialPageRoute>());

      final mobileRoute = HasibuRouter.generateRoute(const RouteSettings(name: HasibuRoutes.mobileDashboard));
      expect(mobileRoute, isA<MaterialPageRoute>());

      final loginRoute = HasibuRouter.generateRoute(const RouteSettings(name: HasibuRoutes.login));
      expect(loginRoute, isA<MaterialPageRoute>());

      final settingsRoute = HasibuRouter.generateRoute(const RouteSettings(name: HasibuRoutes.settings));
      expect(settingsRoute, isA<MaterialPageRoute>());
    });

    testWidgets('MobilArayuzIyilestirmeScreen renders on smartphone viewport with responsive 2-column KPI grid and quick menu',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: MobilArayuzIyilestirmeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobil başlık ve marka bileşenleri
      expect(find.byKey(const ValueKey('mobile_company_logo_badge')), findsOneWidget);
      expect(find.text('Mobil PDKS & Saha Yönetimi'), findsOneWidget);

      // Responsive 2-kolon KPI kartları
      expect(find.text('Toplam Kadro'), findsOneWidget);
      expect(find.text('Zamanında'), findsOneWidget);
      expect(find.text('Geç Kalan'), findsOneWidget);
      expect(find.text('Devamsız'), findsOneWidget);

      // Görünüm yoğunluğu değiştirme (Ferah -> Kompakt)
      expect(find.byTooltip('Kompakt Liste'), findsOneWidget);
      await tester.tap(find.byTooltip('Kompakt Liste'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ferah Kart Görünümü'), findsOneWidget);

      // Geri al
      await tester.tap(find.byTooltip('Ferah Kart Görünümü'));
      await tester.pumpAndSettle();

      // Mobil Hızlı Menü (Bottom Sheet)
      await tester.tap(find.byTooltip('Hızlı İşlemler'));
      await tester.pumpAndSettle();

      expect(find.text('Cihaz Bağlantı Tanılama (Tenfei D35)'), findsOneWidget);
      expect(find.text('Google Drive & Gmail Eşitleme'), findsOneWidget);
      expect(find.text('Sistem & Firma Parametreleri'), findsOneWidget);
    });

    test('Anti-Passback debounce, overtime/early-leave calculation, missing check-out completion & Puantaj CSV work deterministically', () async {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final statuses = container.read(pdksDashboardProvider).dailyStatuses;

      // 00064 (Mehmet Sinan Cenan): 05:45 giriş, 05:46 mükerrer okuma (Anti-Passback ile filtrelenmeli), 16:30 çıkış -> +90 dk fazla mesai
      final sinanStatus = statuses.firstWhere((s) => s.employee.cardNo == '00064');
      expect(sinanStatus.duplicateScansFiltered, equals(1));
      expect(sinanStatus.overtimeMinutes, equals(90));
      expect(sinanStatus.hasMissingCheckOut, isFalse);

      // 00046: 05:48 giriş, 14:10 çıkış (15:00 vardiya bitişi) -> 50 dk erken çıkış
      final harunStatus = statuses.firstWhere((s) => s.employee.cardNo == '00046');
      expect(harunStatus.earlyLeaveMinutes, equals(50));
      expect(harunStatus.hasMissingCheckOut, isFalse);

      // 00058: Sadece giriş var, çıkış yok -> eksik çıkış anomalisi
      final missingOutBefore = statuses.firstWhere((s) => s.employee.cardNo == '00058');
      expect(missingOutBefore.hasMissingCheckOut, isTrue);

      // Tek tıkla eksik çıkış tamamlama
      await container
          .read(pdksDashboardProvider.notifier)
          .quickCompleteMissingCheckOut(missingOutBefore);

      final statusesAfter = container.read(pdksDashboardProvider).dailyStatuses;
      final missingOutAfter = statusesAfter.firstWhere((s) => s.employee.cardNo == '00058');
      expect(missingOutAfter.hasMissingCheckOut, isFalse);
      expect(missingOutAfter.lastCheckOut, isNotNull);
      expect(missingOutAfter.lastCheckOut!.timestamp.hour, equals(15));
      expect(missingOutAfter.lastCheckOut!.timestamp.minute, equals(0));

      // Toplu eksik çıkış tamamlama
      final batchCount = await container
          .read(pdksDashboardProvider.notifier)
          .batchCompleteAllMissingCheckOuts();
      expect(batchCount, greaterThan(0));
      final remainingMissing = container
          .read(pdksDashboardProvider)
          .dailyStatuses
          .where((s) => s.hasMissingCheckOut)
          .length;
      expect(remainingMissing, equals(0));

      // Resmi Puantaj CSV çıktısı doğrulaması
      final csv = container.read(pdksDashboardProvider.notifier).generateDailyPuantajCsv();
      expect(csv, contains('Tarih;Kart No;Ad Soyad'));
      expect(csv, contains('00064;MEHMET SİNAN CENAN'));
    });

    test('HrRequest workflow (leave & missing punch auto-processing) and 4857 Md. 53 statutory leave sync work accurately', () async {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final initialPending = container.read(pdksDashboardProvider).pendingHrRequestsCount;
      expect(initialPending, equals(3));

      // Eksik çıkış düzeltme talebini (req_2125_missing_out_20261019 - 01110 Müslüm Öncel) onayla -> otomatik AttendanceLog oluşmalı
      final req1 = container
          .read(pdksDashboardProvider)
          .allHrRequests
          .firstWhere((r) => r.id == 'req_2125_missing_out_20261019');
      await container.read(pdksDashboardProvider.notifier).reviewHrRequest(
            request: req1,
            approve: true,
            reviewerNote: 'Kamera kaydı ile doğrulandı.',
          );

      final muslumStatus = container
          .read(pdksDashboardProvider)
          .dailyStatuses
          .firstWhere((s) => s.employee.cardNo == '01110');
      expect(muslumStatus.hasMissingCheckOut, isFalse);
      expect(muslumStatus.lastCheckOut, isNotNull);

      // İzin talebini (req_1620_leave_20261022 - 01406 Abdullah Yıldız) onayla -> otomatik LeaveRecord oluşmalı
      final req2 = container
          .read(pdksDashboardProvider)
          .allHrRequests
          .firstWhere((r) => r.id == 'req_1620_leave_20261022');
      final leavesBefore = container
          .read(pdksDashboardProvider)
          .allLeaveRecords
          .where((l) => l.employeeId == req2.employeeId)
          .length;
      await container.read(pdksDashboardProvider.notifier).reviewHrRequest(
            request: req2,
            approve: true,
            reviewerNote: 'Mazeret izni onaylandı.',
          );
      final leavesAfter = container
          .read(pdksDashboardProvider)
          .allLeaveRecords
          .where((l) => l.employeeId == req2.employeeId)
          .length;
      expect(leavesAfter, greaterThan(leavesBefore));

      // 4857 Sayılı İş Kanunu Md. 53 kıdeme göre yasal izin senkronizasyonu
      final updatedCount = await container
          .read(pdksDashboardProvider.notifier)
          .syncStatutoryLeaveEntitlements();
      expect(updatedCount, greaterThanOrEqualTo(0));
      final mismatchesAfter = container
          .read(pdksDashboardProvider)
          .statutoryLeaveMismatchCount;
      expect(mismatchesAfter, equals(0));
    });
  });
}
