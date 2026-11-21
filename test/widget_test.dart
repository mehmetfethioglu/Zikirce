import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';
import 'package:hasibu/core/security/license_guard_service.dart';
import 'package:hasibu/features/pdks/domain/accounting_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/accounting_providers.dart';
import 'package:hasibu/features/pdks/presentation/screens/hasibu_accounting_views.dart';
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

    test(
        'TenfeiZkClient.decodeCp1254 and decodeUserBuffer parse 4-byte length-prefixed 72-byte Turkish user records',
        () {
      expect(
        TenfeiZkClient.decodeCp1254(
          <int>[0x59, 0x41, 0xDE, 0x41, 0x52, 0x20, 0xD0, 0xDD, 0xFE, 0xFD, 0xF0, 0x00, 0x41],
        ),
        'YAŞAR Ğİşığ',
      );

      final buf76 = Uint8List(76);
      final bd = ByteData.sublistView(buf76);
      bd.setUint32(0, 72, Endian.little);
      bd.setUint16(4, 15, Endian.little); // uid = 15

      // Name offset 11..35 (CP1254 Turkish characters)
      final nameBytes = <int>[
        0x4D, 0x45, 0x48, 0x4D, 0x45, 0x54, 0x20, // "MEHMET "
        0xDE, 0xDD, 0x4D, 0xDE, 0x45, 0x4B, // "ŞİMŞEK"
      ];
      buf76.setRange(4 + 11, 4 + 11 + nameBytes.length, nameBytes);

      // PIN offset 48..72 (ASCII unpadded card "72")
      final pinBytes = ascii.encode('72');
      buf76.setRange(4 + 48, 4 + 48 + pinBytes.length, pinBytes);

      final users = TenfeiZkClient.decodeUserBuffer(buf76);
      expect(users.length, 1);
      expect(users.first.uid, 15);
      expect(users.first.cardNo, '00072');
      expect(users.first.fullName, 'MEHMET ŞİMŞEK');
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
      expect(HasibuSecurityService.isPasswordHashed(reloadedEmp.password), isTrue);
      expect(HasibuSecurityService.verifyPassword('9876', reloadedEmp.password), isTrue);
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
      final doc999 = updatedDocs.firstWhere((d) => d.id == 'doc_test_999');
      expect(doc999.filePath.endsWith('.hasibu_doc'), isTrue);
      db.deletePersonnelDocument('doc_test_999');
      expect(
        db.getDocumentsForEmployee(sampleEmp.id).any((d) => d.id == 'doc_test_999'),
        isFalse,
      );
    });

    test(
        'Release scenario: unregistered attendance_logs auto-create placeholders so dashboard is never 0, and upgrade to real names preserving ID',
        () {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      // Canlı (Release) veritabanı durumunu simüle et: employees boş, ancak cihazdan okutma çekilmiş
      db.rawDb.execute('DELETE FROM employees');
      expect(db.getEmployees(), isEmpty);

      final now = DateTime.now();
      final todayDt = DateTime(now.year, now.month, now.day, 6, 5);
      db.upsertAttendanceLogsBatch(<AttendanceLog>[
        AttendanceLog(
          id: 'rel_00072_${todayDt.millisecondsSinceEpoch}',
          cardNo: '00072',
          branchId: 1,
          deviceNo: 1,
          timestamp: todayDt,
          isCheckIn: true,
          source: AttendanceSource.tenfeiD35,
          verifyMethod: VerifyMethod.face,
        ),
      ]);

      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      // refreshDashboard() yetim kartları otomatik yer tutucuya dönüştürmeli (0 KPI olmamalı)
      final initialState = container.read(pdksDashboardProvider);
      expect(initialState.totalCount, greaterThan(0));
      expect(initialState.presentCount, greaterThan(0));

      final placeholder = db.getEmployees().firstWhere((e) => e.cardNo == '00072');
      expect(placeholder.fullName, 'PERSONEL #00072');
      final placeholderId = placeholder.id;

      // Katman 1/2 gerçek kadro geldiğinde aynı ID korunarak gerçek isme yükseltilmeli
      final upgradedCount = db.syncEmployeesFromDeviceOrBridge(<Employee>[
        const Employee(
          id: 261,
          cardNo: '00072',
          fullName: 'MAHRAM MUHAMMED',
          title: 'ÇEVİRME',
          departmentId: 9,
          branchId: 1,
          shiftId: 1,
          hireDate: '2018-01-28',
        ),
      ]);
      expect(upgradedCount, 1);

      final upgraded = db.getEmployees().firstWhere((e) => e.cardNo == '00072');
      expect(upgraded.id, placeholderId);
      expect(upgraded.fullName, 'MAHRAM MUHAMMED');
      expect(upgraded.departmentId, 9);

      // Mevcut gerçek isimli personel kaydı tekrar senkronize edildiğinde ezilmemeli
      final secondPass = db.syncEmployeesFromDeviceOrBridge(<Employee>[
        const Employee(
          id: 261,
          cardNo: '00072',
          fullName: 'FARKLI İSİM DENEMESİ',
          title: 'DİĞER',
          departmentId: 1,
          branchId: 1,
          shiftId: 2,
          hireDate: '2025-01-01',
        ),
      ]);
      expect(secondPass, 0);
      expect(
        db.getEmployees().firstWhere((e) => e.cardNo == '00072').fullName,
        'MAHRAM MUHAMMED',
      );

      container.read(pdksDashboardProvider.notifier).refreshDashboard();
      final finalState = container.read(pdksDashboardProvider);
      final mahramStatus = finalState.dailyStatuses.firstWhere(
        (s) => s.employee.cardNo == '00072',
      );
      expect(mahramStatus.firstCheckIn, isNotNull);
      expect(mahramStatus.department.name, 'ÇEVİRME');
    });
  });

  testWidgets(
      'HasibuApp enforces Login Gate, Lean PDKS Sidebar, Period Absence Report, Clean Employee Portal, and Settings',
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

    // 3. Uygulama içerisinde üst barda Şirket Logosu, Kişisel Tema ve Ayarlar butonu görünür; mobil geçici buton kaldırılmıştır
    expect(
      find.byKey(const ValueKey('appbar_company_logo_badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('appbar_theme_selector_button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('appbar_settings_button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('appbar_mobile_mode_button')),
      findsNothing,
    );

    // 4. Tek katmanlı yalın sol menüde yalnızca Faz 1 Personel & PDKS hedefleri görünür
    expect(find.text('Canlı Yoklama'), findsWidgets);
    expect(find.text('Devam / Devamsızlık Raporu'), findsOneWidget);
    expect(find.text('İzin & Raporlar'), findsOneWidget);
    expect(find.text('Hareket Düzeltme'), findsOneWidget);
    expect(find.text('İK Talepleri & Uyum'), findsOneWidget);
    expect(find.text('Yüz Okutma Terminali'), findsOneWidget);
    expect(find.text('Şube QR / GPS Yoklama'), findsOneWidget);
    expect(find.text('Personel Portalı'), findsOneWidget);
    expect(find.text('Personel & Bölüm'), findsOneWidget);
    expect(find.text('Mesai & Vardiya'), findsOneWidget);
    expect(find.text('Şirket, Şube & Cihazlar'), findsOneWidget);

    // Ön Muhasebe, ERP, Şube POS, Bordro ve Yalın Üretim arayüzleri gizlidir
    expect(find.text('Ön Muhasebe & Puantaj'), findsNothing);
    expect(find.text('Şube & Mağaza'), findsNothing);
    expect(find.text('Yalın Üretim & KPI'), findsNothing);
    expect(find.text('4. Veri, Göç Sihirbazı & SaaS'), findsNothing);
    expect(find.text('GMS.NET Bordro Zarfım & Tazminat'), findsNothing);
    expect(find.text('Cari İşlemler'), findsNothing);

    // 4a-takvim. Tarih seçici üzerinde bugünün gerçek tarihi "(Bugün)" ile yazar ve dokununca takvim (DatePicker) açılır
    expect(
      find.byKey(const ValueKey('calendar_date_picker_button')),
      findsOneWidget,
    );
    expect(
      find.text(
        PdksDashboardNotifier.formatDisplayDate(
          PdksDashboardNotifier.todayDateKey(),
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('calendar_date_picker_button')));
    await tester.pumpAndSettle();
    expect(find.text('PDKS Yoklama Tarihini Seçin'), findsOneWidget);
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();

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

    // 5. Devam / Devamsızlık Raporu sekmesine geç -> KPI kartları, filtreler ve CSV dışa aktarımı çalışır
    await tester.tap(find.byKey(const ValueKey('nav_attendance_report')));
    await tester.pumpAndSettle();
    expect(
      find.text('Çok Günlü Devam / Devamsızlık Raporu'),
      findsOneWidget,
    );
    expect(find.text('Toplam Devam (Gün)'), findsOneWidget);
    expect(find.text('Devamsızlık (Gün)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report_filter_only_absent')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('report_filter_only_late')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('report_filter_exclude_sundays')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('report_export_period_csv_button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Devam / Devamsızlık Raporu CSV'),
      findsOneWidget,
    );
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    // 6. Hareket Düzeltme menüsüne tıkla -> Toplu Hareket Düzenleme paneli açılır
    await tester.tap(find.byKey(const ValueKey('nav_attendance_correction')));
    await tester.pumpAndSettle();
    expect(
      find.text('Toplu Hareket Düzenleme & Çoklu Giriş/Çıkış Atama'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bulk_attendance_apply_button')),
      findsOneWidget,
    );

    // 7. Üst bardaki Gmail Eşitleme butonuna tıkla -> Google OAuth 2.0 & Drive kurulum penceresi açılır
    await tester.tap(find.byKey(const ValueKey('gmail_sync_setup_button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Google OAuth 2.0 & Drive Veri Eşitleme Merkezi'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('btn_google_browser_oauth')),
      findsOneWidget,
    );
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    // 8. Personel Portalına geç -> GMS/KPI olmadan yalnızca İK & PDKS özetleri görünür
    await tester.tap(find.byKey(const ValueKey('nav_employee_portal')));
    await tester.pumpAndSettle();
    expect(find.text('Kalan Yıllık İzin'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('self_service_new_request_button')),
      findsOneWidget,
    );
    expect(find.textContaining('GMS.NET Net Maaş'), findsNothing);
    expect(find.text('Yalın Üretim KPI'), findsNothing);

    // 9. Üst bardaki Ayarlar ikonuna tıkla -> Şirket, Şube & Cihaz Ayarları açılır
    await tester.tap(find.byKey(const ValueKey('appbar_settings_button')));
    await tester.pumpAndSettle();
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

  testWidgets(
      'HasibuShellScreen renders cleanly on mobile viewport with NavigationBar and Drawer',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: HasibuApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Login screen overflow');

    await tester.tap(find.byKey(const ValueKey('login_submit_button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Live PDKS screen overflow');

    // Alt navigasyon çubuğunda 4 sade hedef görünür
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Yoklama'), findsOneWidget);
    expect(find.text('Rapor'), findsOneWidget);
    expect(find.text('İzinler'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);

    // Drawer menüsü açılır ve navigasyon hedefleri listelenir
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Drawer overflow');
    expect(find.byKey(const ValueKey('nav_attendance_report')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav_attendance_report')));
    await tester.pumpAndSettle();

    expect(
      find.text('Çok Günlü Devam / Devamsızlık Raporu'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull, reason: 'Report screen overflow');
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
      expect(find.text('Zamanında'), findsWidgets);
      expect(find.text('Geç Kalan'), findsWidgets);
      expect(find.text('Devamsız'), findsWidgets);

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

      // Varsayılan tarih her zaman bugünün gerçek sistem tarihidir
      expect(
        container.read(pdksDashboardProvider).selectedDate,
        equals(PdksDashboardNotifier.todayDateKey()),
      );
      expect(
        PdksDashboardNotifier.formatDisplayDate('2026-10-20'),
        equals('20.10.2026'),
      );

      // 2026-10-19 örnek verilerini test etmek için tarihi 2026-10-19 olarak seç
      container.read(pdksDashboardProvider.notifier).setSelectedDate('2026-10-19');
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

    test('buildAttendancePeriodReport & generatePeriodAttendanceReportCsv compute multi-day attendance, lates, leaves, sick reports and Sunday exclusion accurately', () async {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pdksDashboardProvider.notifier);
      final sinan = db.getEmployees().firstWhere((e) => e.cardNo == '00064');

      // 2026-10-19 (Pzt): mevcut seed verisi -> 05:45 giriş, 16:30 çıkış (Zamanında devam)
      // 2026-10-20 (Sal): 05:50 giriş, 15:00 çıkış (Zamanında devam)
      await notifier.saveOrUpdateAttendanceLog(
        employee: sinan,
        dateKey: '2026-10-20',
        timeHhMm: '05:50',
        isCheckIn: true,
        source: AttendanceSource.tenfeiD35,
        verifyMethod: VerifyMethod.face,
      );
      await notifier.saveOrUpdateAttendanceLog(
        employee: sinan,
        dateKey: '2026-10-20',
        timeHhMm: '15:00',
        isCheckIn: false,
        source: AttendanceSource.tenfeiD35,
        verifyMethod: VerifyMethod.face,
      );

      // 2026-10-21 (Çar): 07:30 giriş, 15:00 çıkış (Geç kalma)
      await notifier.saveOrUpdateAttendanceLog(
        employee: sinan,
        dateKey: '2026-10-21',
        timeHhMm: '07:30',
        isCheckIn: true,
        source: AttendanceSource.tenfeiD35,
        verifyMethod: VerifyMethod.face,
      );
      await notifier.saveOrUpdateAttendanceLog(
        employee: sinan,
        dateKey: '2026-10-21',
        timeHhMm: '15:00',
        isCheckIn: false,
        source: AttendanceSource.tenfeiD35,
        verifyMethod: VerifyMethod.face,
      );

      // 2026-10-22 (Per): Yıllık İzin
      await notifier.assignLeaveDateRange(
        employeeId: sinan.id,
        startDate: DateTime(2026, 10, 22),
        endDate: DateTime(2026, 10, 22),
        leaveType: LeaveType.yillikIzin,
        note: 'Test Yıllık İzin',
      );

      // 2026-10-23 (Cum): Sağlık Raporu
      await notifier.assignLeaveDateRange(
        employeeId: sinan.id,
        startDate: DateTime(2026, 10, 23),
        endDate: DateTime(2026, 10, 23),
        leaveType: LeaveType.saglikRaporu,
        note: 'Test Sağlık Raporu',
      );
      // 2026-10-24 (Cmt): Kayıt yok -> Devamsız
      // 2026-10-25 (Paz): Pazar (excludeSundays=true ile hariç tutulmalı)

      final withSundays = notifier.buildAttendancePeriodReport(
        startDateKey: '2026-10-19',
        endDateKey: '2026-10-25',
        searchQuery: '00064',
        excludeSundays: false,
      );
      expect(withSundays.length, equals(1));
      expect(withSundays.first.totalDays, equals(7));
      expect(withSundays.first.absentDateKeys, containsAll(['2026-10-24', '2026-10-25']));

      final withoutSundays = notifier.buildAttendancePeriodReport(
        startDateKey: '2026-10-19',
        endDateKey: '2026-10-25',
        searchQuery: '00064',
        excludeSundays: true,
      );
      expect(withoutSundays.length, equals(1));
      final sinanSummary = withoutSundays.first;
      expect(sinanSummary.totalDays, equals(6));
      expect(sinanSummary.presentDays, equals(3));
      expect(sinanSummary.onTimeDays, equals(2));
      expect(sinanSummary.lateDays, equals(1));
      expect(sinanSummary.totalLateMinutes, greaterThan(0));
      expect(sinanSummary.onLeaveDays, equals(1));
      expect(sinanSummary.sickReportDays, equals(1));
      expect(sinanSummary.absentDays, equals(1));
      expect(sinanSummary.absentDateKeys, equals(['2026-10-24']));

      final onlyAbsent = notifier.buildAttendancePeriodReport(
        startDateKey: '2026-10-19',
        endDateKey: '2026-10-25',
        onlyWithAbsences: true,
        excludeSundays: true,
      );
      expect(onlyAbsent.every((r) => r.absentDays > 0), isTrue);

      final periodCsv = notifier.generatePeriodAttendanceReportCsv(
        startDateKey: '2026-10-19',
        endDateKey: '2026-10-25',
        searchQuery: '00064',
        excludeSundays: true,
      );
      expect(periodCsv, contains('Tarih Aralığı;Kart No;Ad Soyad;Şube;Bölüm'));
      expect(periodCsv, contains('00064;MEHMET SİNAN CENAN'));
      expect(periodCsv, contains('24.10.2026'));
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

      container.read(pdksDashboardProvider.notifier).setSelectedDate('2026-10-19');

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

      // Faz 1, Faz 2 & Faz 3 Doğrulaması (Temiz Sıfır Veritabanı vs İzole Demo Paketi, Otomatik Puantaj->Cari Hakediş, Emanet Kap, Kritik Stok & Göç Sihirbazı)
      final accNotifier = container.read(accountingProvider.notifier);
      expect(container.read(accountingProvider).isDemoModeActive, isTrue);
      expect(container.read(accountingProvider).accounts.isNotEmpty, isTrue);
      expect(
        container.read(accountingProvider).stockBurnItems.first.remainingDays,
        equals(8),
      );

      accNotifier.switchToCleanZeroDatabase();
      expect(container.read(accountingProvider).isDemoModeActive, isFalse);
      expect(container.read(accountingProvider).accounts, isEmpty);
      expect(container.read(accountingProvider).transactions, isEmpty);
      expect(container.read(accountingProvider).stockBurnItems, isEmpty);

      accNotifier.loadIsolatedDemoPackage();
      expect(container.read(accountingProvider).isDemoModeActive, isTrue);

      final accruedCount = accNotifier.accrueAllPuantajToLedger();
      expect(accruedCount, greaterThan(0));
      final sinanRow = container
          .read(accountingProvider)
          .puantajRows
          .firstWhere((r) => r.cardNo == '00064');
      expect(sinanRow.isAccruedToLedger, isTrue);
      expect(sinanRow.hourlyRate, closeTo(36000.0 / 225.0, 0.01));
      expect(sinanRow.currentLedgerBalance, greaterThan(0));

      accNotifier.payEmployeeSalary(row: sinanRow, viaBank: false);
      final sinanAfterPay = container
          .read(accountingProvider)
          .puantajRows
          .firstWhere((r) => r.cardNo == '00064');
      expect(sinanAfterPay.currentLedgerBalance, closeTo(0.0, 0.01));

      // GMS.NET Bordro & Puantaj Motoru Doğrulamaları (Kanun No, Eksik Gün, BES, İcra, Kıdem/İhbar & Pusula Onayı)
      expect(sinanAfterPay.ubgtDays, equals(1));
      expect(sinanAfterPay.grossTotalEarningsTl, greaterThan(sinanAfterPay.grossAccrualPay));
      expect(sinanAfterPay.sgkTreasurySubsidyTl, greaterThan(0));
      expect(sinanAfterPay.calculateSeveranceNet(), greaterThan(0));
      expect(sinanAfterPay.calculateNoticeNet(), greaterThan(0));

      accNotifier.toggleGmsNetToGrossMode();
      expect(
        container.read(accountingProvider).gmsPayrollParams.isNetToGross,
        isTrue,
      );
      accNotifier.setEmployeeSgkLaw('00064', GmsSgkIncentiveLaw.law17103);
      accNotifier.signEmployeePayrollEnvelope('00064');
      final sinanGmsUpdated = container
          .read(accountingProvider)
          .puantajRows
          .firstWhere((r) => r.cardNo == '00064');
      expect(sinanGmsUpdated.sgkLaw, equals(GmsSgkIncentiveLaw.law17103));
      expect(sinanGmsUpdated.isEnvelopeSignedByEmployee, isTrue);

      final mahsupCount = accNotifier.accrueGmsIntegratedMahsupToLedger();
      expect(mahsupCount, greaterThan(0));

      final branchAcc = container
          .read(accountingProvider)
          .accounts
          .firstWhere((a) => a.id == 'acc_demo_branch_1');
      final initialTrays = branchAcc.trayBalance;
      accNotifier.addContainerMovement(
        account: branchAcc,
        containerType: 'Tepsi',
        givenQty: 30,
        returnedQty: 10,
        note: 'Test Tepsi Sevkiyatı',
      );
      final updatedBranchAcc = container
          .read(accountingProvider)
          .accounts
          .firstWhere((a) => a.id == 'acc_demo_branch_1');
      expect(updatedBranchAcc.trayBalance, equals(initialTrays + 20));

      accNotifier.updateSaaSSubscription(
        tier: SaaSTier.enterpriseMultiBranch,
        channel: StoreDistributionChannel.appleAppStore,
      );
      expect(
        container.read(accountingProvider).subscriptionState.activeTier,
        equals(SaaSTier.enterpriseMultiBranch),
      );

      final migRes = accNotifier.runLegacyMigrationWizard(
        'CARI;GOC-777;ÖRNEK GÖÇ BAYİ A.Ş.;customer;10000;45000;50;0\n'
        'STOK;STK-777;ÖRNEK AMBALAJ KOLİSİ;ADET;500;25;40',
      );
      expect(migRes.accountsImported, equals(1));
      expect(migRes.stocksImported, equals(1));
      expect(migRes.transactionsCreated, equals(2));

      // Ön Muhasebe İşlemler Şeridi (Ribbon - 32 Başlık) Giriş / Çıkış Doğrulaması
      expect(PreAccountingOperationModule.values.length, equals(32));

      // Hasibu ERP: Sipariş -> İrsaliye -> Fatura -> Tahsilat & KDV Yansıtma
      final erpCountBefore =
          container.read(accountingProvider).erpOrdersWaybillsInvoices.length;
      accNotifier.createErpOrderOrInvoice(
        account: branchAcc,
        regionGroup: 'Marmara Bayi (Fiyat-2)',
        priceTier: 2,
        stockCode: 'BKL-001',
        stockName: 'FISTIKLI KARE BAKLAVA',
        orderedQtyKg: 100.0,
        trayCount: 25,
        unitPriceTl: 650.0,
      );
      final createdErp =
          container.read(accountingProvider).erpOrdersWaybillsInvoices.first;
      expect(
        container.read(accountingProvider).erpOrdersWaybillsInvoices.length,
        equals(erpCountBefore + 1),
      );
      expect(createdErp.stage, equals('SIPARIS'));

      accNotifier.advanceErpDocumentStage(createdErp.id);
      final afterWaybill = container
          .read(accountingProvider)
          .erpOrdersWaybillsInvoices
          .firstWhere((e) => e.id == createdErp.id);
      expect(afterWaybill.stage, equals('IRSALIYE_SEVK'));
      expect(afterWaybill.waybillDocNo, isNotNull);

      accNotifier.advanceErpDocumentStage(createdErp.id);
      final afterInvoice = container
          .read(accountingProvider)
          .erpOrdersWaybillsInvoices
          .firstWhere((e) => e.id == createdErp.id);
      expect(afterInvoice.stage, equals('FATURALANDI'));
      expect(afterInvoice.invoiceDocNo, isNotNull);

      accNotifier.collectPaymentAgainstInvoice(createdErp.id);
      accNotifier.reflectOfficialVatToMainLedger(createdErp.id);
      final afterVat = container
          .read(accountingProvider)
          .erpOrdersWaybillsInvoices
          .firstWhere((e) => e.id == createdErp.id);
      expect(afterVat.isOfficialVatReflected, isTrue);

      // Hasibu Mağaza Dokunmatik POS, Terazi, Kutu Dara & 360° Şube Denetimi
      expect(HasibuModule.values.contains(HasibuModule.branchStore), isTrue);
      accNotifier.setLiveScaleWeightKg(1.250);
      final firstPosBtn =
          container.read(accountingProvider).posQuickButtons.first;
      accNotifier.addQuickButtonToPosCart(firstPosBtn);
      expect(
        container.read(accountingProvider).activePosCart.length,
        equals(1),
      );
      expect(
        container.read(accountingProvider).requiresBoxContainerAlert,
        isTrue,
      );

      // Askıya Al ve Askıdan Çağır
      accNotifier.suspendCurrentPosCart(labelNote: 'Test Askı Fişi');
      expect(container.read(accountingProvider).activePosCart, isEmpty);
      final suspId =
          container.read(accountingProvider).suspendedPosReceipts.first.id;
      accNotifier.recallSuspendedPosReceipt(suspId);
      expect(
        container.read(accountingProvider).activePosCart.length,
        equals(1),
      );

      // 5'li POS Ödeme Motoru ile Fiş Kesimi
      final rcpBefore =
          container.read(accountingProvider).branchPosReceipts.length;
      accNotifier.completePosCheckout(
        paymentMethod: BranchPosPaymentMethod.cash,
        receivedCashOverride: 2000.0,
      );
      expect(
        container.read(accountingProvider).branchPosReceipts.length,
        equals(rcpBefore + 1),
      );

      // Gün Sonu Kasa Teslim Tutanağı + Kutu Dara Denkleştirme + 360° Şube Denetimi
      final eodBefore =
          container.read(accountingProvider).branchEndOfDaySettlements.length;
      accNotifier.submitBranchEndOfDayAndCashHandover(
        actualCountedCashTl: 44000.0,
        coinCashTl: 500.0,
        actualPosZReportTl: 78400.0,
        handedOverBy: 'Test Kasiyer',
        receivedBy: 'Test Müdür',
        witnessName: 'Test Şahit',
      );
      expect(
        container.read(accountingProvider).branchEndOfDaySettlements.length,
        equals(eodBefore + 1),
      );

      final audBefore =
          container.read(accountingProvider).branchAuditInspections.length;
      accNotifier.run360BranchAuditInspection(
        inspectorName: 'Başdenetçi',
        blindCashVarianceTl: 0.0,
        blindStockVarianceTl: 0.0,
        coldChainTempCelsius: -18.5,
        hygieneChecklistScore: 98,
        findingSummary: 'Tam mutabakat',
        actionPlan: 'Standart devam',
      );
      expect(
        container.read(accountingProvider).branchAuditInspections.length,
        equals(audBefore + 1),
      );

      final cashBefore = container.read(accountingProvider).cockpitSummary.cashOnHand;
      accNotifier.selectOperationModule(PreAccountingOperationModule.kasaIslemleri);
      accNotifier.recordOperationalEntryExit(
        module: PreAccountingOperationModule.kasaIslemleri,
        isIncoming: true,
        account: branchAcc,
        amount: 25000,
        cashOrBankName: 'Merkez TL Kasa',
        description: 'Şube Kasa Tahsilat Girişi',
      );
      final cashAfterIn = container.read(accountingProvider).cockpitSummary.cashOnHand;
      expect(cashAfterIn, closeTo(cashBefore + 25000, 0.01));

      accNotifier.recordOperationalEntryExit(
        module: PreAccountingOperationModule.kasaIslemleri,
        isIncoming: false,
        account: branchAcc,
        amount: 5000,
        cashOrBankName: 'Merkez TL Kasa',
        description: 'Kasa Nakit Tediye Çıkışı',
      );
      final cashAfterOut = container.read(accountingProvider).cockpitSummary.cashOnHand;
      expect(cashAfterOut, closeTo(cashAfterIn - 5000, 0.01));

      // Çek Girişi & Vade Kaydı
      final checksBefore = container.read(accountingProvider).checksAndNotes.length;
      accNotifier.recordOperationalEntryExit(
        module: PreAccountingOperationModule.cekIslemleri,
        isIncoming: true,
        account: branchAcc,
        amount: 40000,
        dueDateKey: '2026-11-15',
        description: 'Müşteri Çeki Portföy Girişi',
      );
      expect(
        container.read(accountingProvider).checksAndNotes.length,
        equals(checksBefore + 1),
      );

      // Çift Taraflı Virman (Cari -> Cari)
      final secondAcc = container
          .read(accountingProvider)
          .accounts
          .firstWhere((a) => a.id != branchAcc.id);
      final txCountBeforeVirman = container.read(accountingProvider).transactions.length;
      accNotifier.recordOperationalEntryExit(
        module: PreAccountingOperationModule.virmanlar,
        isIncoming: true,
        account: branchAcc,
        counterPartyAccount: secondAcc,
        amount: 12000,
        description: 'Şubeler Arası Cari Virman',
      );
      expect(
        container.read(accountingProvider).transactions.length,
        equals(txCountBeforeVirman + 2),
      );

      // Stok Fişi Giriş (+) ve Dondurma Satış Stok Düşümü (-)
      final firstStock = container.read(accountingProvider).stockBurnItems.first;
      final qtyBefore = firstStock.currentQty;
      accNotifier.recordOperationalEntryExit(
        module: PreAccountingOperationModule.stokFisleri,
        isIncoming: true,
        amount: 15000,
        stockId: firstStock.id,
        stockQuantity: 50,
        description: 'Depo Hammadde Giriş Fişi',
      );
      final qtyAfterIn = container
          .read(accountingProvider)
          .stockBurnItems
          .firstWhere((s) => s.id == firstStock.id)
          .currentQty;
      expect(qtyAfterIn, closeTo(qtyBefore + 50, 0.01));

      accNotifier.recordOperationalEntryExit(
        module: PreAccountingOperationModule.dondurmaSatislar,
        isIncoming: true,
        amount: 8500,
        stockId: firstStock.id,
        stockQuantity: 10,
        description: 'Toptan Dondurma Satış Çıkışı',
      );
      final qtyAfterSale = container
          .read(accountingProvider)
          .stockBurnItems
          .firstWhere((s) => s.id == firstStock.id)
          .currentQty;
      expect(qtyAfterSale, closeTo(qtyAfterIn - 10, 0.01));
    });

    testWidgets(
        'AccountingCockpitAndActionCenterView opens modern entry/exit popup via button without static form card on both desktop and mobile viewports',
        (WidgetTester tester) async {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      // 1. Mobil görünüm (390x844) doğrulaması
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AccountingCockpitAndActionCenterView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sabit form alanı ana ekranda yer tutmamalı, yalnızca buton görünmeli
      expect(
        find.byKey(const ValueKey('dialog_accounting_entry_exit')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('btn_open_entry_exit_popup')),
        findsOneWidget,
      );

      // Butona tıklayınca modern popup açılmalı
      await tester.tap(find.byKey(const ValueKey('btn_open_entry_exit_popup')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dialog_accounting_entry_exit')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('input_op_amount')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('input_op_amount')),
        '18500',
      );
      await tester.enterText(
        find.byKey(const ValueKey('input_op_desc')),
        'Mobil Popup Tahsilat Girişi',
      );
      await tester.tap(
        find.byKey(const ValueKey('btn_execute_op_entry_exit')),
      );
      await tester.pumpAndSettle();

      // Kayıt sonrası popup otomatik kapanmalı ve yeni hareket listede görünmeli
      expect(
        find.byKey(const ValueKey('dialog_accounting_entry_exit')),
        findsNothing,
      );
      expect(
        find.textContaining('Mobil Popup Tahsilat Girişi'),
        findsOneWidget,
      );

      // 2. Masaüstü görünüm (1440x900) doğrulaması
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('btn_open_entry_exit_popup')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog_accounting_entry_exit')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('btn_close_entry_exit_popup')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog_accounting_entry_exit')),
        findsNothing,
      );

      // Aksiyon Kokpitinde Gün Sonu KPI kartları yer almamalı (ayrı sekmede olmalı)
      expect(find.text('GÜNCEL BAKİYE'), findsNothing);

      // 3. Ayrıştırılmış Gün Sonu Özeti & Nakit Akışı (AccountingEndOfDaySummaryView) doğrulaması
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AccountingEndOfDaySummaryView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Gün Sonu Özeti & Nakit / Bakiye Akışı'),
        findsOneWidget,
      );
      expect(find.text('GÜNCEL BAKİYE'), findsOneWidget);
      expect(find.text('KASADAKİ NAKİT'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('btn_eod_summary_pick_date')),
        findsOneWidget,
      );
    });
  });

  group('FAZ 1-5: Güvenlik, Kriptografi ve Ticari Lisanslama Zırhı Testleri', () {
    test(
        'FAZ 1-5: Salted PBKDF2/Argon2id hash, AES-256-GCM Drive Sync, Ed25519 License & Monotonic Clock Shield, TOTP + HMAC-SHA256 Integrity, and Immutable Audit Logs',
        () async {
      // [DB-04] Salted PBKDF2 & Argon2id password hashing
      final pbkdf2Hash = HasibuSecurityService.hashPassword('Hasibu#2026');
      expect(HasibuSecurityService.isPasswordHashed(pbkdf2Hash), isTrue);
      expect(
        HasibuSecurityService.verifyPassword('Hasibu#2026', pbkdf2Hash),
        isTrue,
      );
      expect(
        HasibuSecurityService.verifyPassword('WrongPass', pbkdf2Hash),
        isFalse,
      );

      final argonHash =
          await HasibuSecurityService.hashPasswordArgon2id('Argon#Secret');
      expect(HasibuSecurityService.isPasswordHashed(argonHash), isTrue);

      // [SYNC-01] AES-256-GCM sync payload encryption & decryption
      final rawSnapshot = <String, dynamic>{
        'company': 'HASİBU GIDA A.Ş.',
        'records': 42,
      };
      final encryptedEnvelope =
          await HasibuSecurityService.encryptSyncJsonPayload(rawSnapshot);
      expect(encryptedEnvelope.contains('hasibu_aes256_gcm_v1'), isTrue);
      final decryptedSnapshot =
          await HasibuSecurityService.decryptSyncJsonPayload(encryptedEnvelope);
      expect(decryptedSnapshot['company'], equals('HASİBU GIDA A.Ş.'));
      expect(decryptedSnapshot['records'], equals(42));

      // [HW-01] & [HW-02] Branch terminalCommKey encryption & non-zero commKey
      final encComm = HasibuSecurityService.encryptTerminalCommKey(437029);
      expect(encComm.startsWith('enc_ck_v1:'), isTrue);
      expect(
        HasibuSecurityService.decryptTerminalCommKey(encComm),
        equals(437029),
      );

      // [HW-05] Dynamic 30s TOTP (HMAC-SHA1) QR generation & 60s window validation
      const qrSecret = 'HASIBU-MERKEZ-TOTP-SECRET-2026';
      final fixedTime = DateTime(2026, 10, 23, 12, 0, 10);
      final totpNow = HasibuSecurityService.generateTotpCode(
        qrSecret,
        timestamp: fixedTime,
      );
      expect(totpNow.length, equals(6));
      final validCheck = HasibuSecurityService.verifyDynamicBranchQrPayload(
        qrPayload: totpNow,
        expectedBranchId: '1',
        qrSecret: qrSecret,
        now: fixedTime.add(const Duration(seconds: 25)),
      );
      expect(validCheck.isValid, isTrue);

      // 95 saniye eski QR kodu reddedilmeli (>60 sn)
      final expiredCheck = HasibuSecurityService.verifyDynamicBranchQrPayload(
        qrPayload: totpNow,
        expectedBranchId: '1',
        qrSecret: qrSecret,
        now: fixedTime.add(const Duration(seconds: 95)),
      );
      expect(expiredCheck.isValid, isFalse);

      // [LIC-02], [LIC-03], [LIC-04] Hardware Fingerprint, Ed25519 License & Monotonic Clock Shield
      final hwId = HardwareFingerprintService.getDeviceHardwareFingerprint();
      expect(hwId.startsWith('HSB-HW-'), isTrue);

      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      // [HW-03] & [HW-04] AttendanceLog HMAC-SHA256 integrityHash & Tamper Detection
      final allLogs = db.getAttendanceLogsForDate('2026-10-19');
      expect(allLogs.isNotEmpty, isTrue);
      expect(db.getTamperedAttendanceLogs(), isEmpty);

      // Veritabanında saati elle değiştirilmiş (manipüle edilmiş) kayıt oluştur
      final targetLog = allLogs.first;
      db.rawDb.execute(
        'UPDATE attendance_logs SET timestamp_iso = ? WHERE id = ?',
        <Object?>['2026-10-19T04:11:00.000', targetLog.id],
      );
      final tamperedList = db.getTamperedAttendanceLogs();
      expect(tamperedList.any((l) => l.id == targetLog.id), isTrue);

      // [LIC-04] Monotonik Saat Kalkanı: Sistem saati geri alındığında kilitle
      final clockCheckBackwards = db.evaluateMonotonicClockShield(
        now: DateTime(2020, 1, 1),
      );
      expect(clockCheckBackwards.isClockTampered, isTrue);

      // [SYNC-02] Rol İzolasyonu: Portal Queue yalnızca ilgili personelin kendi kayıtlarını içerir
      final portalSnap = db.exportPortalQueueSnapshot(
        deviceName: 'Test-Mobile',
        employeeCardNo: '00064',
      );
      expect(portalSnap['vaultRole'], equals('portal_queue'));
      expect(portalSnap.containsKey('employees'), isFalse);

      // [AUD-01] Silinemez 10. tablo audit_logs ve SQLite BEFORE DELETE / UPDATE trigger koruması
      final entry = db.appendAuditLog(
        actorEmployeeId: 'ADMIN:admin',
        actionType: 'QUICK_COMPLETE_CHECKOUT',
        targetRecordId: '00064:2026-10-19',
        oldValue: 'Çıkış Yok',
        newValue: '17:00',
      );
      expect(entry.hash.length, equals(64));
      expect(db.getAuditLogs().isNotEmpty, isTrue);

      expect(
        () => db.rawDb.execute('DELETE FROM audit_logs WHERE id = ?', [entry.id]),
        throwsA(anything),
      );
      expect(
        () => db.rawDb.execute(
          "UPDATE audit_logs SET new_value = 'HACK' WHERE id = ?",
          [entry.id],
        ),
        throwsA(anything),
      );
    });
  });

  group('Personel Portalı, İşe Giriş/Çıkış Tarihleri ve Devamsızlık Koruması', () {
    test(
        'Employee exitDate & hireDate SQLite persistence, Cloud Snapshot merge, external exit sync, and capped tenure work accurately',
        () {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      final sinan = db.getEmployees().firstWhere((e) => e.cardNo == '00064');
      expect(sinan.hireDate, equals('2025-12-22'));
      expect(sinan.exitDate, isNull);
      expect(sinan.isSeparatedNow, isFalse);

      // 1. İşten çıkış tarihini kaydet ve SQLite gidiş-dönüşünü doğrula
      final exitedSinan = sinan.copyWith(
        exitDate: () => '2026-10-15',
        sgkActive: false,
      );
      db.upsertEmployee(exitedSinan);

      final reloaded = db.getEmployees().firstWhere((e) => e.cardNo == '00064');
      expect(reloaded.exitDate, equals('2026-10-15'));
      expect(reloaded.hasExitDate, isTrue);
      expect(reloaded.sgkActive, isFalse);
      // Kıdem hesabı çıkış tarihine sabitlenmeli (2025-12-22 -> 2026-10-15 = 0 yıl)
      expect(reloaded.tenureYearsAt(DateTime(2030, 12, 31)), equals(0));
      expect(reloaded.tenureSummaryAt(DateTime(2030, 12, 31)), equals('9 Ay'));

      // 2. Bulut yedek / geri yükleme (exportCloudSnapshot -> reconcileCloudSnapshot) exitDate'i korumalı
      final snapshot = db.exportCloudSnapshot(deviceName: 'Test-Export');
      final dbTarget = HasibuDatabase.inMemory();
      addTearDown(dbTarget.dispose);
      dbTarget.reconcileCloudSnapshot(snapshot);
      final reconciled =
          dbTarget.getEmployees().firstWhere((e) => e.cardNo == '00064');
      expect(reconciled.exitDate, equals('2026-10-15'));
      expect(reconciled.sgkActive, isFalse);

      // 3. Harici çıkış tarihleri yalnızca çıkışı boş olan kartlara uygulanmalı
      final appliedCount = db.applyExternalExitDates(const <String, String>{
        '01406': '2026-10-18',
        '00064': '2026-10-20', // Zaten çıkış tarihi olduğu için ezilmemeli
      });
      expect(appliedCount, equals(1));
      final abdullah = db.getEmployees().firstWhere((e) => e.cardNo == '01406');
      expect(abdullah.exitDate, equals('2026-10-18'));
      expect(abdullah.sgkActive, isFalse);
      expect(
        db.getEmployees().firstWhere((e) => e.cardNo == '00064').exitDate,
        equals('2026-10-15'),
      );

      // 4. Çıkış tarihini temizleme (tekrar aktif etme)
      db.upsertEmployee(reloaded.copyWith(exitDate: () => null, sgkActive: true));
      final rehired = db.getEmployees().firstWhere((e) => e.cardNo == '00064');
      expect(rehired.exitDate, isNull);
      expect(rehired.hasExitDate, isFalse);
      expect(rehired.sgkActive, isTrue);
    });

    test(
        'Terminated and not-yet-hired employees never count as absent in daily dashboard, period reports, or portal login',
        () async {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      // Test için yeni bir aktif personel (99001) ve henüz işe başlamamış personel (99002) ekle
      db.upsertEmployee(
        const Employee(
          id: 99001,
          cardNo: '99001',
          fullName: 'AYRILAN TEST PERSONELİ',
          title: 'ÜRETİM',
          departmentId: 1,
          branchId: 1,
          shiftId: 1,
          hireDate: '2025-01-01',
        ),
      );
      db.upsertEmployee(
        const Employee(
          id: 99002,
          cardNo: '99002',
          fullName: 'YENİ BAŞLAYACAK PERSONEL',
          title: 'ÜRETİM',
          departmentId: 1,
          branchId: 1,
          shiftId: 1,
          hireDate: '2026-10-22',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pdksDashboardProvider.notifier);
      notifier.setSelectedDate('2026-10-19');

      final beforeState = container.read(pdksDashboardProvider);
      final active99001 = beforeState.dailyStatuses
          .firstWhere((s) => s.employee.cardNo == '99001');
      final future99002 = beforeState.dailyStatuses
          .firstWhere((s) => s.employee.cardNo == '99002');
      expect(active99001.state, equals(DailyAttendanceState.absent));
      expect(future99002.state, equals(DailyAttendanceState.notYetHired));

      final int absentBeforeExit = beforeState.absentCount;
      final int totalBeforeExit = beforeState.totalCount;

      // 99001 için 2026-10-15 işten çıkış tarihi tanımla
      await notifier.saveEmployee(
        active99001.employee.copyWith(
          exitDate: () => '2026-10-15',
          sgkActive: false,
        ),
      );

      final afterState = container.read(pdksDashboardProvider);
      expect(afterState.absentCount, equals(absentBeforeExit - 1));
      expect(afterState.totalCount, equals(totalBeforeExit - 1));
      expect(afterState.terminatedCount, greaterThanOrEqualTo(1));

      final terminated99001 = afterState.dailyStatuses
          .firstWhere((s) => s.employee.cardNo == '99001');
      expect(terminated99001.state, equals(DailyAttendanceState.terminated));
      expect(
        afterState.visibleStatuses.any((s) => s.employee.cardNo == '99001'),
        isFalse,
      );

      // İşten Ayrılan filtresi seçilince görünmeli
      notifier.setStateFilter(DailyAttendanceState.terminated);
      expect(
        container
            .read(pdksDashboardProvider)
            .visibleStatuses
            .any((s) => s.employee.cardNo == '99001'),
        isTrue,
      );
      notifier.setStateFilter(null);

      // Çıkış gününden 1 gün önce (2026-10-14) kaydı yoksa Devamsız sayılmalı
      notifier.setSelectedDate('2026-10-14');
      expect(
        container
            .read(pdksDashboardProvider)
            .dailyStatuses
            .firstWhere((s) => s.employee.cardNo == '99001')
            .state,
        equals(DailyAttendanceState.absent),
      );

      // Çıkış gününde (2026-10-15) okutma yoksa İşten Ayrıldı; okutma varsa Giriş Yaptı olmalı
      notifier.setSelectedDate('2026-10-15');
      expect(
        container
            .read(pdksDashboardProvider)
            .dailyStatuses
            .firstWhere((s) => s.employee.cardNo == '99001')
            .state,
        equals(DailyAttendanceState.terminated),
      );
      await notifier.saveOrUpdateAttendanceLog(
        employee: terminated99001.employee,
        dateKey: '2026-10-15',
        timeHhMm: '05:55',
        isCheckIn: true,
      );
      expect(
        container
            .read(pdksDashboardProvider)
            .dailyStatuses
            .firstWhere((s) => s.employee.cardNo == '99001')
            .state,
        equals(DailyAttendanceState.present),
      );

      // Çok günlü Devam/Devamsızlık raporu çıkış sonrası dönemde 99001'i tamamen hariç tutmalı
      final postExitReport = notifier.buildAttendancePeriodReport(
        startDateKey: '2026-10-19',
        endDateKey: '2026-10-25',
      );
      expect(
        postExitReport.any((r) => r.employee.cardNo == '99001'),
        isFalse,
      );

      // Çıkışı kapsayan dönemde (2026-10-12 .. 2026-10-20) yalnızca aktif günler sayılmalı
      final spanReport = notifier.buildAttendancePeriodReport(
        startDateKey: '2026-10-12',
        endDateKey: '2026-10-20',
        searchQuery: '99001',
        excludeSundays: false,
      );
      expect(spanReport.length, equals(1));
      expect(spanReport.first.absentDays, equals(3)); // 12, 13, 14 Ekim
      expect(spanReport.first.presentDays, equals(1)); // 15 Ekim gerçek okutma
      expect(spanReport.first.totalDays, equals(4));

      // İşten ayrılan personel portal oturumu açamamalı
      final loginOk = notifier.loginAsEmployee(cardNo: '99001', pin: '1234');
      expect(loginOk, isFalse);
      final authState = container.read(pdksDashboardProvider).authSession;
      expect(authState.isAuthenticated, isFalse);
      expect(authState.errorMessage, contains('işten ayrılış'));
    });

    testWidgets(
        'Employee cards support hire/exit dates and redesigned Employee Portal directory works on desktop and mobile',
        (WidgetTester tester) async {
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

      // Yönetici oturumu aç
      await tester.tap(find.byKey(const ValueKey('login_submit_button')));
      await tester.pumpAndSettle();

      // 1. Personel & Bölüm ekranında kartlarda İşe Giriş tarihi ve Çıkış tarihi düzenlemesi
      await tester.tap(find.byKey(const ValueKey('nav_employees_mgmt')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('İşe Giriş:'), findsWidgets);
      expect(
        find.byKey(const ValueKey('employees_filter_all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employees_filter_active')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employees_filter_terminated')),
        findsOneWidget,
      );

      // 00058 kartını ara ve işten çıkış tarihi tanımla
      await tester.enterText(find.byType(TextField).first, '00058');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('edit_employee_btn_00058')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('edit_employee_btn_00058')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('employee_dialog_hire_date_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('employee_dialog_exit_date_field')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('employee_dialog_exit_date_field')),
        '2026-10-15',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('employee_dialog_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('İŞTEN AYRILDI'), findsOneWidget);
      expect(find.textContaining('İşten Çıkış: 15.10.2026'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('employees_filter_active')));
      await tester.pumpAndSettle();
      expect(find.textContaining('(#00058)'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('employees_filter_terminated')));
      await tester.pumpAndSettle();
      expect(find.textContaining('(#00058)'), findsOneWidget);

      // 2. Yeniden tasarlanan Personel Portalı (Masaüstü Master-Detail Rehber)
      await tester.tap(find.byKey(const ValueKey('nav_employee_portal')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        find.byKey(const ValueKey('portal_employee_search_field')),
        findsOneWidget,
      );
      expect(find.text('Kalan Yıllık İzin'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('self_service_new_request_button')),
        findsOneWidget,
      );
      expect(find.textContaining('GMS.NET Net Maaş'), findsNothing);
      expect(find.text('Yalın Üretim KPI'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('portal_employee_search_field')),
        '01406',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('portal_employee_tile_01406')));
      await tester.pumpAndSettle();
      expect(find.text('ABDULLAH YILDIZ'), findsWidgets);
      expect(tester.takeException(), isNull);

      // 3. Mobil görünümde (390x844) sticky seçici ve arama modalı taşmasız açılır
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        find.byKey(const ValueKey('portal_employee_picker_button')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('portal_employee_picker_button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('portal_employee_search_field')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
