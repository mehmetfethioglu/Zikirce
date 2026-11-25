import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

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
  BrowserGoogleSignInResult nextResult;

  _FakeGoogleAuthAdapter({required this.nextResult});

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
    return nextResult;
  }

  @override
  Future<String?> refreshAccessTokenSilently() async => null;

  @override
  Future<void> signOut() async {}
}

class _PerTokenFakeDrive {
  final Map<String, Map<String, ({String id, String content, DateTime modified})>>
      buckets =
      <String, Map<String, ({String id, String content, DateTime modified})>>{};
  final Map<String, int> uploadCallsByToken = <String, int>{};

  Map<String, ({String id, String content, DateTime modified})> bucketFor(
    String token,
  ) =>
      buckets.putIfAbsent(
        token,
        () => <String, ({String id, String content, DateTime modified})>{},
      );

  Dio buildDio() {
    final dio = Dio();
    dio.httpClientAdapter = _StubHttpClientAdapter((options, bodyText) async {
      final auth =
          (options.headers[HttpHeaders.authorizationHeader] ?? '').toString();
      final token = auth.replaceFirst('Bearer ', '').trim();
      final files = bucketFor(token);
      final path = options.uri.path;

      if (path.endsWith('/drive/v3/files') && options.method == 'GET') {
        final q = (options.queryParameters['q'] ?? '').toString();
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
        final fileId = path.split('/').last;
        for (final entry in files.values) {
          if (entry.id == fileId) {
            return ResponseBody.fromString(entry.content, 200);
          }
        }
        return ResponseBody.fromString('Not found', 404);
      }

      if (path.contains('/upload/drive/v3/files')) {
        uploadCallsByToken[token] = (uploadCallsByToken[token] ?? 0) + 1;
        final body = bodyText ?? '';
        if (options.method == 'POST') {
          final metaMatch =
              RegExp(r'\{"name":"([^"]+)"[^}]*\}').firstMatch(body);
          final name = metaMatch?.group(1) ?? 'hasibu_sync.enc';
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

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await HasibuSecurityService.saveGoogleOAuthToken('');
    await HasibuSecurityService.saveWorkspaceSyncKey('');
  });

  group('Google Hesap Değişimi İzolasyonu', () {
    test(
      'switching from Account A to Account B after disconnect wipes Account A password/data and does not push to Account B Drive',
      () async {
        final drive = _PerTokenFakeDrive();
        final tempDir =
            await Directory.systemTemp.createTemp('hasibu_acct_switch_a_');
        addTearDown(() => tempDir.delete(recursive: true));
        final nonExistentDir = p.join(tempDir.path, 'isolated_b');

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        final adapter = _FakeGoogleAuthAdapter(
          nextResult: const BrowserGoogleSignInResult(
            success: true,
            accessToken: 'ya29.account-a',
            email: 'mehmetfethioglu@gmail.com',
            displayName: 'Mehmet Fethioğlu',
            message: 'OK',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            googleDriveSyncServiceProvider.overrideWithValue(sync),
            googleAuthAdapterProvider.overrideWithValue(adapter),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(pdksDashboardProvider.notifier);

        // Hesap A: özel yönetici parolası, özel personel, yetkili kullanıcı ve özel şifreleme parolası
        await notifier.signInWithGoogleViaBrowser(
          syncFolderPath: nonExistentDir,
          authenticateAppSession: true,
        );
        final pwErr = await notifier.completeInitialAdminPasswordUpdateAndLogin(
          username: 'admin',
          currentPassword: CompanySettings.defaultAdminPassword,
          newPassword: 'Mehmet#2026',
        );
        expect(pwErr, isNull);
        await notifier.saveAppUser(
          username: 'mehmet_ik',
          displayName: 'Mehmet İK',
          plainPassword: 'IkPass#2026',
          role: AppUserRole.hrManager,
          allowedModules: const [HasibuModule.pdksHr],
        );
        db.upsertEmployee(
          const Employee(
            id: 901,
            cardNo: '00901',
            fullName: 'HESAP A PERSONELI',
            title: 'USTA',
            departmentId: 1,
            branchId: 1,
            shiftId: 1,
            hireDate: '2026-01-01',
          ),
        );
        await notifier.setCloudEncryptionPassphrase('HesapAOzelParola99');
        expect(
          await sync.getCloudEncryptionKeyMode(),
          equals(CloudEncryptionKeyMode.customPassphrase),
        );
        notifier.refreshDashboard();

        // Hesap A bağlantısını kes -> Hesap B'ye (baklavacisemsettinmerkez@gmail.com) geç
        await notifier.disconnectGmailSyncAccount();
        adapter.nextResult = const BrowserGoogleSignInResult(
          success: true,
          accessToken: 'ya29.account-b',
          email: 'baklavacisemsettinmerkez@gmail.com',
          displayName: 'Baklavacı Şemsettin',
          message: 'OK',
        );

        await notifier.signInWithGoogleViaBrowser(
          authenticateAppSession: true,
        );

        // 1. Hesap A'nın admin parolası artık kabul edilmemeli!
        final oldLoginAttempt = notifier.attemptUnifiedLogin(
          identifier: 'admin',
          password: 'Mehmet#2026',
        );
        expect(oldLoginAttempt.outcome, equals(AdminLoginOutcome.failed));

        // 2. Hesap A verileri tamamen temizlenmiş olmalı
        expect(db.getEmployees(), isEmpty);
        expect(db.getAppUsers(), isEmpty);
        expect(
          db.getCompanySettings().syncGmailAccount,
          equals('baklavacisemsettinmerkez@gmail.com'),
        );

        // 3. Hesap B bulutuna boş/eski veri yüklenmemiş olmalı
        expect(drive.uploadCallsByToken['ya29.account-b'] ?? 0, equals(0));
        expect(drive.bucketFor('ya29.account-b'), isEmpty);

        // 4. Şifreleme modu yeni hesap için account_auto'ya sıfırlanmış olmalı
        expect(
          await sync.getCloudEncryptionKeyMode(),
          equals(CloudEncryptionKeyMode.accountAuto),
        );
      },
    );

    test(
      'reconnecting the SAME Google account after disconnect preserves local password and data',
      () async {
        final drive = _PerTokenFakeDrive();
        final tempDir =
            await Directory.systemTemp.createTemp('hasibu_acct_same_');
        addTearDown(() => tempDir.delete(recursive: true));
        final nonExistentDir = p.join(tempDir.path, 'isolated_same');

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        final adapter = _FakeGoogleAuthAdapter(
          nextResult: const BrowserGoogleSignInResult(
            success: true,
            accessToken: 'ya29.same-user',
            email: 'mehmetfethioglu@gmail.com',
            message: 'OK',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            googleDriveSyncServiceProvider.overrideWithValue(sync),
            googleAuthAdapterProvider.overrideWithValue(adapter),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(pdksDashboardProvider.notifier);
        await notifier.signInWithGoogleViaBrowser(
          syncFolderPath: nonExistentDir,
          authenticateAppSession: true,
        );
        final pwErr = await notifier.completeInitialAdminPasswordUpdateAndLogin(
          username: 'admin',
          currentPassword: CompanySettings.defaultAdminPassword,
          newPassword: 'Mehmet#2026',
        );
        expect(pwErr, isNull);
        db.upsertEmployee(
          const Employee(
            id: 902,
            cardNo: '00902',
            fullName: 'KALICI PERSONEL',
            title: 'USTA',
            departmentId: 1,
            branchId: 1,
            shiftId: 1,
            hireDate: '2026-01-01',
          ),
        );
        notifier.refreshDashboard();
        await notifier.backupToCloudNow();

        await notifier.disconnectGmailSyncAccount();
        await notifier.signInWithGoogleViaBrowser(
          syncFolderPath: nonExistentDir,
          authenticateAppSession: true,
        );

        expect(
          db.getEmployees().any((e) => e.cardNo == '00902'),
          isTrue,
        );
        final sameLogin = notifier.attemptUnifiedLogin(
          identifier: 'admin',
          password: 'Mehmet#2026',
        );
        expect(sameLogin.outcome, equals(AdminLoginOutcome.authenticated));
      },
    );
  });

  group('Mobilde Şube Kutusu (Branch Inbox) Geri Yükleme & Uyarı Testleri', () {
    test(
      'restoreFromCloudNow restores branch-inbox-only Drive backup, creates missing branch, and refreshes dailyStatuses',
      () async {
        final drive = _PerTokenFakeDrive();
        final tempDir =
            await Directory.systemTemp.createTemp('hasibu_mobile_inbox_');
        addTearDown(() => tempDir.delete(recursive: true));
        final nonExistentDir = p.join(tempDir.path, 'no_local_folder');

        const accountEmail = 'baklavacisemsettinmerkez@gmail.com';
        final autoKey = HasibuSecurityService.deriveAccountWorkspaceKey(
          googleEmail: accountEmail,
          cloudProfileId: 'default',
        );
        final todayKey = PdksDashboardNotifier.todayDateKey();
        final scanTs = '${todayKey}T08:42:10.000';
        final inboxPayload = <String, dynamic>{
          'schemaVersion': 1,
          'vaultRole': 'branch_inbox',
          'cloudProfileId': 'default',
          'deviceSlug': 'sube_d35',
          'branchId': 38,
          'branchCode': 'SUBE38',
          'branchName': 'Şemsettin Merkez Şube',
          'deviceName': 'Lenovo Şube Köprüsü',
          'exportedAt': '${todayKey}T08:42:15.000Z',
          'attendanceLogs': <Map<String, dynamic>>[
            {
              'id': TenfeiZkClient.buildDeterministicLogId(
                38,
                '00777',
                DateTime.parse(scanTs),
              ),
              'cardNo': '00777',
              'branchId': 38,
              'deviceNo': 1,
              'timestamp': scanTs,
              'isCheckIn': true,
              'source': 'tenfeiD35',
              'verifyMethod': 'face',
              'integrityHash': '',
            },
          ],
          'deviceUsers': const <Map<String, dynamic>>[
            {'cardNo': '00777', 'fullName': 'MEHMET FETHİOĞLU'},
          ],
        };
        final encryptedInbox =
            await HasibuSecurityService.encryptSyncJsonPayload(
          inboxPayload,
          workspaceKey: autoKey,
          vaultRole: 'branch_inbox',
          keyMode: 'account_auto',
        );
        drive.bucketFor('ya29.mobile-b')['hasibu_branch_inbox_sube_d35.enc'] = (
          id: 'drv-inbox-1',
          content: encryptedInbox,
          modified: DateTime.now(),
        );

        // Temiz telefon DB (ana hasibu_sync.enc yok, yalnızca şube kutusu var)
        final phoneDb = HasibuDatabase.inMemory();
        addTearDown(phoneDb.dispose);
        phoneDb.rawDb.execute('DELETE FROM employees;');
        phoneDb.rawDb.execute('DELETE FROM branches;');
        phoneDb.saveCompanySettings(
          phoneDb.getCompanySettings().copyWith(
                syncGmailAccount: accountEmail,
                syncFolderPath: nonExistentDir,
              ),
        );

        final phoneSync = GoogleDriveSyncService(
          db: phoneDb,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await phoneSync.saveOAuthTokens(accessToken: 'ya29.mobile-b');

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(phoneDb),
            googleDriveSyncServiceProvider.overrideWithValue(phoneSync),
            googleAuthAdapterProvider.overrideWithValue(
              _FakeGoogleAuthAdapter(
                nextResult: const BrowserGoogleSignInResult(
                  success: true,
                  accessToken: 'ya29.mobile-b',
                  email: accountEmail,
                  message: 'OK',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(pdksDashboardProvider.notifier);
        final res = await notifier.restoreFromCloudNow(
          mode: CloudRestoreMode.merge,
          cloudOnly: true,
        );

        expect(res.summary, isNotNull);
        expect(res.status.stage, equals(DriveSyncStage.synced));
        expect(res.status.isCloudApiVerified, isTrue);

        final st = container.read(pdksDashboardProvider);
        expect(
          st.branches.any(
            (b) => b.id == 38 && b.name == 'Şemsettin Merkez Şube',
          ),
          isTrue,
        );
        expect(
          st.dailyStatuses.any(
            (d) =>
                d.employee.cardNo == '00777' &&
                d.employee.fullName == 'MEHMET FETHİOĞLU',
          ),
          isTrue,
        );
      },
    );

    test(
      'restoreFromCloudNow in replace mode also pulls and layers branch inbox records on top of master vault',
      () async {
        final drive = _PerTokenFakeDrive();
        final tempDir =
            await Directory.systemTemp.createTemp('hasibu_mobile_replace_');
        addTearDown(() => tempDir.delete(recursive: true));
        final nonExistentDir = p.join(tempDir.path, 'no_local_folder');

        const accountEmail = 'baklavacisemsettinmerkez@gmail.com';
        final autoKey = HasibuSecurityService.deriveAccountWorkspaceKey(
          googleEmail: accountEmail,
          cloudProfileId: 'default',
        );

        // Eski master snapshot (00888 personeli yok)
        final masterDb = HasibuDatabase.inMemory();
        addTearDown(masterDb.dispose);
        masterDb.saveCompanySettings(
          masterDb.getCompanySettings().copyWith(
                companyName: 'BAKLAVACI ŞEMSETTİN',
                syncGmailAccount: accountEmail,
                syncFolderPath: nonExistentDir,
              ),
        );
        final masterSnapshot =
            masterDb.exportCloudSnapshot(deviceName: 'Merkez PC');
        final encryptedMaster =
            await HasibuSecurityService.encryptSyncJsonPayload(
          masterSnapshot,
          workspaceKey: autoKey,
          vaultRole: 'master_vault',
          keyMode: 'account_auto',
        );
        drive.bucketFor('ya29.mobile-r')['hasibu_sync.enc'] = (
          id: 'drv-master-1',
          content: encryptedMaster,
          modified: DateTime.now(),
        );

        // Şube kutusunda yeni okutma & isim (00888)
        final todayKey = PdksDashboardNotifier.todayDateKey();
        final scanTs = '${todayKey}T09:05:00.000';
        final inboxPayload = <String, dynamic>{
          'schemaVersion': 1,
          'vaultRole': 'branch_inbox',
          'cloudProfileId': 'default',
          'deviceSlug': 'sube_d35',
          'branchId': 1,
          'branchCode': 'MRK',
          'branchName': 'Merkez',
          'deviceName': 'Lenovo Köprüsü',
          'exportedAt': '${todayKey}T09:05:05.000Z',
          'attendanceLogs': <Map<String, dynamic>>[
            {
              'id': TenfeiZkClient.buildDeterministicLogId(
                1,
                '00888',
                DateTime.parse(scanTs),
              ),
              'cardNo': '00888',
              'branchId': 1,
              'deviceNo': 1,
              'timestamp': scanTs,
              'isCheckIn': true,
              'source': 'tenfeiD35',
              'verifyMethod': 'face',
              'integrityHash': '',
            },
          ],
          'deviceUsers': const <Map<String, dynamic>>[
            {'cardNo': '00888', 'fullName': 'YENİ ŞUBE PERSONELİ'},
          ],
        };
        final encryptedInbox =
            await HasibuSecurityService.encryptSyncJsonPayload(
          inboxPayload,
          workspaceKey: autoKey,
          vaultRole: 'branch_inbox',
          keyMode: 'account_auto',
        );
        drive.bucketFor('ya29.mobile-r')['hasibu_branch_inbox_sube_d35.enc'] = (
          id: 'drv-inbox-r',
          content: encryptedInbox,
          modified: DateTime.now(),
        );

        final phoneDb = HasibuDatabase.inMemory();
        addTearDown(phoneDb.dispose);
        phoneDb.saveCompanySettings(
          phoneDb.getCompanySettings().copyWith(
                syncGmailAccount: accountEmail,
                syncFolderPath: nonExistentDir,
              ),
        );
        final phoneSync = GoogleDriveSyncService(
          db: phoneDb,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await phoneSync.saveOAuthTokens(accessToken: 'ya29.mobile-r');

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(phoneDb),
            googleDriveSyncServiceProvider.overrideWithValue(phoneSync),
            googleAuthAdapterProvider.overrideWithValue(
              _FakeGoogleAuthAdapter(
                nextResult: const BrowserGoogleSignInResult(
                  success: true,
                  accessToken: 'ya29.mobile-r',
                  email: accountEmail,
                  message: 'OK',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final res = await container
            .read(pdksDashboardProvider.notifier)
            .restoreFromCloudNow(
              mode: CloudRestoreMode.replace,
              cloudOnly: true,
            );

        expect(res.summary, isNotNull);
        expect(res.status.stage, equals(DriveSyncStage.synced));
        final st = container.read(pdksDashboardProvider);
        expect(
          st.dailyStatuses.any(
            (d) =>
                d.employee.cardNo == '00888' &&
                d.employee.fullName == 'YENİ ŞUBE PERSONELİ',
          ),
          isTrue,
        );
      },
    );

    test(
      'pullAndMergeBranchInboxes decrypts account_auto inbox despite stale custom key and surfaces genuine mismatch warnings',
      () async {
        final drive = _PerTokenFakeDrive();
        final tempDir =
            await Directory.systemTemp.createTemp('hasibu_multikey_');
        addTearDown(() => tempDir.delete(recursive: true));
        final nonExistentDir = p.join(tempDir.path, 'no_local');

        const accountEmail = 'baklavacisemsettinmerkez@gmail.com';
        final autoKey = HasibuSecurityService.deriveAccountWorkspaceKey(
          googleEmail: accountEmail,
          cloudProfileId: 'default',
        );
        final todayKey = PdksDashboardNotifier.todayDateKey();
        final validInbox = await HasibuSecurityService.encryptSyncJsonPayload(
          {
            'schemaVersion': 1,
            'vaultRole': 'branch_inbox',
            'cloudProfileId': 'default',
            'deviceSlug': 'auto_d35',
            'branchId': 1,
            'branchCode': 'MRK',
            'branchName': 'Merkez',
            'deviceName': 'Köprü',
            'exportedAt': '${todayKey}T10:00:00.000Z',
            'attendanceLogs': const <dynamic>[],
            'deviceUsers': const <Map<String, dynamic>>[
              {'cardNo': '00555', 'fullName': 'OTO ANAHTAR PERSONEL'},
            ],
          },
          workspaceKey: autoKey,
          vaultRole: 'branch_inbox',
          keyMode: 'account_auto',
        );
        drive.bucketFor('ya29.mk')['hasibu_branch_inbox_auto_d35.enc'] = (
          id: 'drv-auto-1',
          content: validInbox,
          modified: DateTime.now(),
        );

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(
                syncGmailAccount: accountEmail,
                syncFolderPath: nonExistentDir,
              ),
        );
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await sync.saveOAuthTokens(accessToken: 'ya29.mk');
        // Eski / farklı bir özel anahtar kayıtlı olsa bile account_auto aday anahtarıyla çözülmeli
        await sync.saveWorkspaceKey('completely-different-legacy-key');

        final pullOk = await sync.pullAndMergeBranchInboxes(force: true);
        expect(pullOk.warnings, isEmpty);
        expect(pullOk.devices.length, equals(1));
        expect(
          db.getEmployees().any(
                (e) =>
                    e.cardNo == '00555' &&
                    e.fullName == 'OTO ANAHTAR PERSONEL',
              ),
          isTrue,
        );

        // Şimdi gerçekten uyumsuz başka bir anahtarla şifrelenmiş şube kutusu varsa uyarı görünür olmalı
        drive.bucketFor('ya29.mk').clear();
        final badInbox = await HasibuSecurityService.encryptSyncJsonPayload(
          {
            'schemaVersion': 1,
            'vaultRole': 'branch_inbox',
            'cloudProfileId': 'default',
            'deviceSlug': 'kilitli_d35',
            'branchId': 1,
            'attendanceLogs': const <dynamic>[],
            'deviceUsers': const <dynamic>[],
          },
          workspaceKey: 'unmatched-secret-key-xyz',
          vaultRole: 'branch_inbox',
        );
        drive.bucketFor('ya29.mk')['hasibu_branch_inbox_kilitli_d35.enc'] = (
          id: 'drv-bad-1',
          content: badInbox,
          modified: DateTime.now(),
        );

        final restoreFail = await sync.restoreFromCloud(cloudOnly: true);
        expect(restoreFail.summary, isNull);
        expect(restoreFail.status.stage, equals(DriveSyncStage.error));
        expect(restoreFail.status.isDecryptionKeyMismatch, isTrue);
        expect(
          restoreFail.status.message,
          contains('Şube cihaz kutuları okunamadı'),
        );
      },
    );
  });
}
