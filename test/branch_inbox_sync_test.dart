import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';
import 'package:hasibu/core/services/google_auth_adapter.dart';
import 'package:hasibu/core/services/google_drive_sync_service.dart';
import 'package:hasibu/features/pdks/data/tenfei_zk_client.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';

typedef _MockDioHandler = Future<ResponseBody> Function(
  RequestOptions options,
  String? bodyText,
);

class _StubHttpClientAdapter implements HttpClientAdapter {
  final _MockDioHandler _handler;

  _StubHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    String? bodyText;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      final bytes = chunks.expand((c) => c).toList(growable: false);
      bodyText = utf8.decode(bytes, allowMalformed: true);
    }
    return _handler(options, bodyText);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeGoogleAuthAdapter implements GoogleAuthAdapter {
  @override
  bool get isNativePlatform => true;

  @override
  Future<BrowserGoogleSignInResult> signIn({
    String? loginHintEmail,
    String? customClientId,
    String? customClientSecret,
    Duration timeout = const Duration(seconds: 120),
    List<String> extraScopes = const <String>[],
  }) async {
    return const BrowserGoogleSignInResult(
      success: true,
      accessToken: 'ya29.fake-token',
      email: 'merkez@gmail.com',
      message: 'OK',
    );
  }

  @override
  Future<String?> refreshAccessTokenSilently() async => null;

  @override
  Future<void> signOut() async {}
}

class _InMemoryBranchDrive {
  final Map<String, ({String id, String content, DateTime modified})> files =
      <String, ({String id, String content, DateTime modified})>{};
  final List<String> listQueries = <String>[];
  int downloadCalls = 0;
  bool force401OnRequests = false;

  Dio buildDio() {
    final dio = Dio();
    dio.httpClientAdapter = _StubHttpClientAdapter((options, bodyText) async {
      if (force401OnRequests) {
        return ResponseBody.fromString(
          jsonEncode({
            'error': {'code': 401, 'message': 'Invalid Credentials'},
          }),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      final path = options.uri.path;
      if (path.endsWith('/drive/v3/files') && options.method == 'GET') {
        final q = (options.queryParameters['q'] ?? '').toString();
        listQueries.add(q);
        final containsMatch = RegExp(r"name contains '([^']+)'").firstMatch(q);
        if (containsMatch != null) {
          final needle = containsMatch.group(1)!;
          final items = files.entries
              .where((e) => e.key.contains(needle))
              .map(
                (e) => <String, dynamic>{
                  'id': e.value.id,
                  'name': e.key,
                  'modifiedTime': e.value.modified.toUtc().toIso8601String(),
                  'size': utf8.encode(e.value.content).length.toString(),
                },
              )
              .toList(growable: false);
          return ResponseBody.fromString(
            jsonEncode({'files': items}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        final nameMatch = RegExp(r"name = '([^']+)'").firstMatch(q);
        if (nameMatch == null && q == 'trashed = false') {
          final items = files.entries
              .map(
                (e) => <String, dynamic>{
                  'id': e.value.id,
                  'name': e.key,
                  'modifiedTime': e.value.modified.toUtc().toIso8601String(),
                  'size': utf8.encode(e.value.content).length.toString(),
                },
              )
              .toList(growable: false);
          return ResponseBody.fromString(
            jsonEncode({'files': items}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        final targetName = nameMatch?.group(1) ?? '';
        final hit = files[targetName];
        return ResponseBody.fromString(
          jsonEncode({
            'files': hit == null
                ? <dynamic>[]
                : <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': hit.id,
                      'name': targetName,
                      'modifiedTime': hit.modified.toUtc().toIso8601String(),
                    },
                  ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }

      if (path.contains('/drive/v3/files/') &&
          options.uri.queryParameters['alt'] == 'media' &&
          options.method == 'GET') {
        downloadCalls++;
        final fileId = path.split('/').last;
        for (final entry in files.values) {
          if (entry.id == fileId) {
            return ResponseBody.fromString(entry.content, 200);
          }
        }
        return ResponseBody.fromString('Not found', 404);
      }

      if (path.contains('/upload/drive/v3/files')) {
        final body = bodyText ?? '';
        if (options.method == 'POST') {
          final metaMatch =
              RegExp(r'\{"name":"([^"]+)"[^}]*\}').firstMatch(body);
          final name = metaMatch?.group(1) ?? 'hasibu_branch_inbox_device.enc';
          final parts = body.split('Content-Type: application/octet-stream');
          String payload = '';
          if (parts.length >= 2) {
            payload = parts[1].trim();
            final endIdx = payload.indexOf('\r\n--hasibu_sync_');
            if (endIdx > 0) {
              payload = payload.substring(0, endIdx).trim();
            }
          }
          final id = 'drv-${files.length + 1}';
          files[name] = (id: id, content: payload, modified: DateTime.now());
          return ResponseBody.fromString(
            jsonEncode({'id': id}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        if (options.method == 'PATCH') {
          final fileId = path.split('/').last;
          final key =
              files.entries.firstWhere((e) => e.value.id == fileId).key;
          files[key] = (id: fileId, content: body, modified: DateTime.now());
          return ResponseBody.fromString(
            jsonEncode({'id': fileId}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
      }

      return ResponseBody.fromString(jsonEncode({'error': 'unhandled'}), 404);
    });
    return dio;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('Şube Cihaz Kutusu (Branch Inbox) Senkronizasyonu', () {
    test(
      'multi-branch inboxes merge losslessly into center DB without overwriting each other or company settings',
      () async {
        final drive = _InMemoryBranchDrive();
        final branchSyncDir =
            await Directory.systemTemp.createTemp('hasibu_branch_inbox_a_');
        addTearDown(() => branchSyncDir.delete(recursive: true));
        final centerSyncDir =
            await Directory.systemTemp.createTemp('hasibu_branch_inbox_center_');
        addTearDown(() => centerSyncDir.delete(recursive: true));

        // Şube 1 (Devteyşti) kendi şube kutusuna yükler
        final dbBranch1 = HasibuDatabase.inMemory();
        addTearDown(dbBranch1.dispose);
        dbBranch1.saveCompanySettings(
          dbBranch1.getCompanySettings().copyWith(
                syncFolderPath: branchSyncDir.path,
              ),
        );
        final syncBranch1 = GoogleDriveSyncService(
          db: dbBranch1,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await syncBranch1.saveOAuthTokens(accessToken: 'ya29.branch1');
        await syncBranch1.saveWorkspaceKey('shared-factory-key-2026');

        final status1 = await syncBranch1.pushBranchInboxSnapshot(
          deviceSlug: 'devteysti_d35',
          branchId: 38,
          branchCode: 'DEVTEYSTI',
          branchName: 'Şube Devteyşti',
          deviceName: 'Devteyşti Akıllı Terazi',
          logs: [
            AttendanceLog(
              id: TenfeiZkClient.buildDeterministicLogId(
                38,
                '00101',
                DateTime(2026, 11, 22, 8, 30, 12),
              ),
              cardNo: '00101',
              branchId: 38,
              deviceNo: 2,
              timestamp: DateTime(2026, 11, 22, 8, 30, 12),
              isCheckIn: true,
              source: AttendanceSource.tenfeiD35,
              verifyMethod: VerifyMethod.face,
            ),
          ],
          deviceUsers: const [
            {'cardNo': '00101', 'fullName': 'ALİ DEMİR'},
          ],
        );
        expect(status1.isCloudApiVerified, isTrue);
        expect(
          drive.files.containsKey('hasibu_branch_inbox_devteysti_d35.enc'),
          isTrue,
        );

        // Şube 2 (Yenişehir) kendi ayrı şube kutusuna yükler
        final status2 = await syncBranch1.pushBranchInboxSnapshot(
          deviceSlug: 'yenisehir_d35',
          branchId: 39,
          branchCode: 'YENISEHIR',
          branchName: 'Şube Yenişehir',
          deviceName: 'Yenişehir Akıllı Terazi',
          logs: [
            AttendanceLog(
              id: TenfeiZkClient.buildDeterministicLogId(
                39,
                '00202',
                DateTime(2026, 11, 22, 8, 35, 5),
              ),
              cardNo: '00202',
              branchId: 39,
              deviceNo: 3,
              timestamp: DateTime(2026, 11, 22, 8, 35, 5),
              isCheckIn: true,
              source: AttendanceSource.tenfeiD35,
              verifyMethod: VerifyMethod.face,
            ),
          ],
          deviceUsers: const [
            {'cardNo': '00202', 'fullName': 'AYŞE KAYA'},
          ],
        );
        expect(status2.isCloudApiVerified, isTrue);
        expect(
          drive.files.containsKey('hasibu_branch_inbox_yenisehir_d35.enc'),
          isTrue,
        );

        // Merkez DB: kendi firma ayarını koruyarak her iki şube kutusunu birden çeker
        final centerDb = HasibuDatabase.inMemory();
        addTearDown(centerDb.dispose);
        centerDb.upsertBranch(
          const Branch(
            id: 38,
            code: 'DEVTEYSTI',
            name: 'Şube Devteyşti',
            hasTerminal: true,
            terminalIp: '192.168.10.150',
            latitude: 37.1582,
            longitude: 38.7741,
          ),
        );
        centerDb.upsertBranch(
          const Branch(
            id: 39,
            code: 'YENISEHIR',
            name: 'Şube Yenişehir',
            hasTerminal: true,
            terminalIp: '192.168.11.150',
            latitude: 37.1712,
            longitude: 38.7988,
          ),
        );
        centerDb.saveCompanySettings(
          centerDb.getCompanySettings().copyWith(
                companyName: 'MERKEZ FABRİKA A.Ş.',
                syncGmailAccount: 'merkez@gmail.com',
                syncFolderPath: centerSyncDir.path,
              ),
        );

        final centerSync = GoogleDriveSyncService(
          db: centerDb,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await centerSync.saveOAuthTokens(accessToken: 'ya29.center');
        await centerSync.saveWorkspaceKey('shared-factory-key-2026');

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(centerDb),
            googleDriveSyncServiceProvider.overrideWithValue(centerSync),
            googleAuthAdapterProvider.overrideWithValue(_FakeGoogleAuthAdapter()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(pdksDashboardProvider.notifier);
        notifier.setSelectedDate('2026-11-22');
        final pullRes = await notifier.pullBranchInboxesNow(force: true);

        expect(pullRes.warnings, isEmpty);
        expect(pullRes.devices.length, equals(2));
        expect(pullRes.totalNewLogsInserted, equals(2));

        // Şirket adı ezilmedi
        expect(
          centerDb.getCompanySettings().companyName,
          equals('MERKEZ FABRİKA A.Ş.'),
        );

        final centerLogs = centerDb.getAttendanceLogsForDate('2026-11-22');
        expect(centerLogs.map((l) => l.cardNo).toSet(), equals({'00101', '00202'}));

        final employees = centerDb.getEmployees();
        expect(
          employees.any((e) => e.cardNo == '00101' && e.fullName == 'ALİ DEMİR'),
          isTrue,
        );
        expect(
          employees.any((e) => e.cardNo == '00202' && e.fullName == 'AYŞE KAYA'),
          isTrue,
        );

        final uiState = container.read(pdksDashboardProvider);
        expect(uiState.branchInboxStatuses.length, equals(2));

        // İkinci force=false çağrısında değişmeyen dosyalar yeniden indirilmemeli (0 ekstra download)
        final prevDownloads = drive.downloadCalls;
        await notifier.pullBranchInboxesNow(force: false);
        expect(drive.downloadCalls, equals(prevDownloads));

        // Yapılandırma JSON çıktısı client_secret sızdırmadan geçerli JSON üretmeli
        final cfgJson = await notifier.buildBranchBridgeConfigJson(
          uiState.branches.firstWhere((b) => b.id == 38),
        );
        final cfgMap = jsonDecode(cfgJson) as Map<String, dynamic>;
        expect(cfgMap['branchId'], equals(38));
        expect(cfgMap['deviceSlug'], equals('devteysti_d35'));
        expect(cfgMap['workspaceKey'], equals('shared-factory-key-2026'));
        expect(cfgMap.containsKey('clientSecret'), isFalse);
      },
    );

    test(
      'rejects master_vault payload when branch_inbox role is expected & decodes C#-compatible AES-256-GCM envelope',
      () async {
        final drive = _InMemoryBranchDrive();
        final isolatedDir =
            await Directory.systemTemp.createTemp('hasibu_branch_inbox_v2_');
        addTearDown(() => isolatedDir.delete(recursive: true));
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(
                syncFolderPath: isolatedDir.path,
              ),
        );

        const workspaceKey = '  cross-lang-key-2026  ';
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await sync.saveOAuthTokens(accessToken: 'ya29.center');
        await sync.saveWorkspaceKey(workspaceKey);

        // 1. Sahte rol ihlali: master_vault paketi hasibu_branch_inbox_* adıyla yüklenirse reddedilmeli
        final wrongRoleEnvelope =
            await HasibuSecurityService.encryptSyncJsonPayload(
          {'branchId': 1, 'attendanceLogs': <dynamic>[]},
          workspaceKey: workspaceKey,
          vaultRole: 'master_vault',
        );
        drive.files['hasibu_branch_inbox_sahte_d35.enc'] = (
          id: 'drv-wrong-role',
          content: wrongRoleEnvelope,
          modified: DateTime.now(),
        );

        // 2. C# HasibuSyncCrypto ile bit-düzeyinde aynı türetme (HMAC-SHA256 + AesGcm 256 + AAD)
        final keyBytes = crypto.Hmac(
          crypto.sha256,
          utf8.encode('hasibu_drive_aes256_gcm'),
        ).convert(utf8.encode(workspaceKey.trim())).bytes;

        final csharpLikePayload = <String, dynamic>{
          'schemaVersion': 1,
          'vaultRole': 'branch_inbox',
          'cloudProfileId': 'default',
          'deviceSlug': 'karakopru_d35',
          'branchId': 40,
          'branchCode': 'KARAKOPRU',
          'branchName': 'Şube Karaköprü',
          'deviceName': 'Karaköprü Terazi',
          'exportedAt': '2026-11-22T09:15:00.000Z',
          'attendanceLogs': <Map<String, dynamic>>[
            {
              'id': '40_00303_20261122_0915',
              'cardNo': '00303',
              'branchId': 40,
              'deviceNo': 4,
              'timestamp': '2026-11-22T09:15:08.000',
              'isCheckIn': true,
              'source': 'tenfeiD35',
              'verifyMethod': 'face',
              'integrityHash': '',
            },
          ],
          'deviceUsers': <Map<String, dynamic>>[
            {'cardNo': '00303', 'fullName': 'FATMA YILMAZ'},
          ],
        };

        final algorithm = AesGcm.with256bits();
        final nonce = algorithm.newNonce();
        final secretBox = await algorithm.encrypt(
          utf8.encode(jsonEncode(csharpLikePayload)),
          secretKey: SecretKey(keyBytes),
          nonce: nonce,
          aad: utf8.encode('hasibu-sync-v1:branch_inbox'),
        );
        final csharpEnvelope = jsonEncode({
          'format': 'hasibu_aes256_gcm_v1',
          'vaultRole': 'branch_inbox',
          'encryptedAt': '2026-11-22T09:15:02.000Z',
          'iv': base64Encode(nonce),
          'tag': base64Encode(secretBox.mac.bytes),
          'ciphertext': base64Encode(secretBox.cipherText),
        });
        drive.files['hasibu_branch_inbox_karakopru_d35.enc'] = (
          id: 'drv-csharp-vector',
          content: csharpEnvelope,
          modified: DateTime.now(),
        );

        final res = await sync.pullAndMergeBranchInboxes(force: true);
        expect(res.warnings.length, equals(1));
        expect(res.devices.length, equals(1));
        expect(res.devices.first.deviceSlug, equals('karakopru_d35'));
        expect(res.totalNewLogsInserted, equals(1));

        final logs = db.getAttendanceLogsForDate('2026-11-22');
        expect(logs.length, equals(1));
        expect(logs.first.cardNo, equals('00303'));
        // Yerel HMAC bütünlük imzası yeniden hesaplanmış olmalı ve geçerli kalmalı
        expect(logs.first.integrityHash, isNotEmpty);
        expect(logs.first.isIntegrityValid, isTrue);
      },
    );

    test(
      'TenfeiZkClient realtime event and batch fetch produce identical deterministic IDs (zero duplicates)',
      () async {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);

        // 40-byte ZK attendance record for card 777 at 2026-11-22 10:20:33
        final attRecord = Uint8List(40);
        utf8.encode('777').asMap().forEach((i, b) => attRecord[2 + i] = b);
        attRecord[26] = 15; // face
        final dt = DateTime(2026, 11, 22, 10, 20, 33);
        final packed = TenfeiZkClient.encodeZkTime(dt);
        ByteData.sublistView(attRecord).setUint32(27, packed, Endian.little);
        attRecord[31] = 0;

        // 32-byte realtime event for the same scan
        final rtPayload = Uint8List(32);
        utf8.encode('777').asMap().forEach((i, b) => rtPayload[i] = b);
        rtPayload[24] = 15;
        rtPayload[25] = 0;
        rtPayload[26] = 26;
        rtPayload[27] = 11;
        rtPayload[28] = 22;
        rtPayload[29] = 10;
        rtPayload[30] = 20;
        rtPayload[31] = 33;

        final serverSub = server.listen((Socket clientSock) {
          final rx = BytesBuilder(copy: false);
          clientSock.listen((data) {
            rx.add(data);
            final bytes = rx.toBytes();
            if (bytes.length < 16) return;
            rx.clear();
            final bd = ByteData.sublistView(bytes);
            final cmd = bd.getUint16(8, Endian.little);
            final session = bd.getUint16(12, Endian.little);
            final reply = bd.getUint16(14, Endian.little);

            if (cmd == TenfeiZkClient.cmdConnect) {
              clientSock.add(
                TenfeiZkClient.buildTcpFrame(
                  command: TenfeiZkClient.cmdAckOk,
                  sessionId: 7,
                  replyId: reply,
                  payload: Uint8List(0),
                ),
              );
            } else if (cmd == TenfeiZkClient.cmdRegEvent) {
              clientSock.add(
                TenfeiZkClient.buildTcpFrame(
                  command: TenfeiZkClient.cmdAckOk,
                  sessionId: session,
                  replyId: reply,
                  payload: Uint8List(0),
                ),
              );
              // Hemen arkasından canlı okutma olayı gönder
              clientSock.add(
                TenfeiZkClient.buildTcpFrame(
                  command: TenfeiZkClient.cmdRegEvent,
                  sessionId: session,
                  replyId: 0,
                  payload: rtPayload,
                ),
              );
            } else if (cmd == TenfeiZkClient.cmdAttLogRrq) {
              clientSock.add(
                TenfeiZkClient.buildTcpFrame(
                  command: TenfeiZkClient.cmdData,
                  sessionId: session,
                  replyId: reply,
                  payload: attRecord,
                ),
              );
            } else {
              clientSock.add(
                TenfeiZkClient.buildTcpFrame(
                  command: TenfeiZkClient.cmdAckOk,
                  sessionId: session,
                  replyId: reply,
                  payload: Uint8List(0),
                ),
              );
            }
          });
        });
        addTearDown(serverSub.cancel);

        final client = TenfeiZkClient(
          host: '127.0.0.1',
          port: server.port,
          branchId: 38,
          machineNo: 2,
        );
        addTearDown(client.dispose);

        final rtCompleter = Completer<AttendanceLog>();
        final rtSub = client.realtimeAttendanceStream.listen((log) {
          if (!rtCompleter.isCompleted) rtCompleter.complete(log);
        });
        addTearDown(rtSub.cancel);

        await client.connect();
        await client.enableRealtimeEvents();
        final rtLog = await rtCompleter.future.timeout(const Duration(seconds: 3));
        expect(await client.sendKeepAlive(), isTrue);

        final batchLogs = await client.fetchAttendanceLogs(
          includeLanBridge: false,
        );
        expect(batchLogs.length, equals(1));
        expect(rtLog.id, equals(batchLogs.first.id));
        expect(rtLog.id, equals('38_00777_20261122_1020'));

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        expect(db.upsertAttendanceLog(rtLog), isTrue);
        expect(db.upsertAttendanceLog(batchLogs.first), isFalse);
        expect(db.getAttendanceLogsForDate('2026-11-22').length, equals(1));
      },
    );

    test(
      'pullAndMergeBranchInboxes uses broad trashed=false query (avoids underscore prefix bug) & surfaces 401 session error',
      () async {
        final drive = _InMemoryBranchDrive();
        final isolatedDir =
            await Directory.systemTemp.createTemp('hasibu_drive_query_test_');
        addTearDown(() => isolatedDir.delete(recursive: true));

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(
                syncGmailAccount: 'baklavacisemsettinmerkez@gmail.com',
                syncFolderPath: isolatedDir.path,
              ),
        );
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await sync.saveOAuthTokens(accessToken: 'ya29.mobile-test');

        final autoKey = HasibuSecurityService.deriveAccountWorkspaceKey(
          googleEmail: 'baklavacisemsettinmerkez@gmail.com',
          cloudProfileId: 'default',
        );
        final inboxPayload = await HasibuSecurityService.encryptSyncJsonPayload(
          {
            'schemaVersion': 1,
            'vaultRole': 'branch_inbox',
            'cloudProfileId': 'default',
            'deviceSlug': 'merkez_d35',
            'branchId': 1,
            'branchCode': 'MERKEZ',
            'branchName': 'Merkez Fabrika & Üretim',
            'deviceName': 'Merkez Köprü',
            'exportedAt': '2026-11-25T07:34:45.000Z',
            'attendanceLogs': const <dynamic>[],
            'deviceUsers': const <Map<String, dynamic>>[
              {'cardNo': '00777', 'fullName': 'MEHMET FETHIOGLU'},
            ],
          },
          workspaceKey: autoKey,
          vaultRole: 'branch_inbox',
          keyMode: 'account_auto',
        );
        drive.files['hasibu_branch_inbox_merkez_d35.enc'] = (
          id: 'drv-merkez-1',
          content: inboxPayload,
          modified: DateTime.now(),
        );
        // Alakasız başka bir Drive dosyası yoksayılmalı
        drive.files['unrelated_report.pdf'] = (
          id: 'drv-other-1',
          content: 'pdf-bytes',
          modified: DateTime.now(),
        );

        final pullRes = await sync.pullAndMergeBranchInboxes(
          force: true,
          cloudApiOnly: true,
        );
        expect(pullRes.warnings, isEmpty);
        expect(pullRes.devices.length, equals(1));
        expect(pullRes.devices.first.deviceSlug, equals('merkez_d35'));
        expect(drive.listQueries, contains('trashed = false'));
        expect(
          drive.listQueries.any((q) => q.contains('name contains')),
          isFalse,
        );

        // Süresi dolmuş OAuth token (401) durumunda hata yutulmamalı, açık uyarı dönmeli
        drive.force401OnRequests = true;
        final expiredRestore = await sync.restoreFromCloud(
          cloudOnly: true,
          skipDriveFolderFallback: true,
        );
        expect(expiredRestore.summary, isNull);
        expect(expiredRestore.status.stage, equals(DriveSyncStage.error));
        expect(expiredRestore.status.message, contains('401'));
      },
    );

    test(
      'C# account_auto PBKDF2-HMAC-SHA256 vector matches Dart deriveAccountWorkspaceKey bit-for-bit',
      () {
        const expectedVector =
            '2b3e6cf0b5444cd7850e7eeca6c5bdab3ec5a7a232efe721bfa3bb09c69102c7';
        expect(
          HasibuSecurityService.deriveAccountWorkspaceKey(
            googleEmail: '  Merkez@Example.com  ',
            cloudProfileId: 'default',
          ),
          equals(expectedVector),
        );
      },
    );
  });
}
