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
  });

  group('HasibuDatabase & Settings CRUD Tests', () {
    test(
        'Persists company settings, shifts, branches, employees and exports snapshot',
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
        ),
      );
      expect(db.getCompanySettings().companyName, 'AKAR GIDA & BAKLAVA A.Ş.');

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
    });
  });

  testWidgets(
      'HasibuApp renders Live PDKS Dashboard and navigates to Settings View', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HasibuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('HASİBU'), findsOneWidget);
    expect(find.text('Tüm Şubeler & Merkez'), findsOneWidget);

    // Ayarlar ikonuna tıkla ve 5 yönetim alt sekmesinin açıldığını doğrula
    await tester.tap(find.byTooltip('Ayarlar & Yönetim'));
    await tester.pumpAndSettle();

    expect(find.text('1. Şirket, Şube & Cihaz Ayarları'), findsOneWidget);
    expect(find.text('2. Mesai Saatleri & Geç Kalma'), findsOneWidget);
    expect(find.text('3. Hareket Düzeltme (Giriş/Çıkış)'), findsOneWidget);
    expect(find.text('4. İzin & Rapor Girişi'), findsOneWidget);
    expect(find.text('5. Personel & Bölüm Yönetimi'), findsOneWidget);
    expect(find.byIcon(Icons.add_business_rounded), findsOneWidget);
  });
}
