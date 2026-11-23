import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/services/google_auth_adapter.dart';
import 'package:hasibu/core/services/google_drive_sync_service.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/features/pdks/presentation/screens/cloud_backup_center_dialog.dart';
import 'package:hasibu/features/pdks/presentation/screens/hasibu_login_screen.dart';
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

class _InMemoryFakeDrive {
  final Map<String, ({String id, String content, DateTime modified})> files =
      <String, ({String id, String content, DateTime modified})>{};
  int uploadCalls = 0;

  Dio buildDio() {
    final dio = Dio();
    dio.httpClientAdapter = _StubHttpClientAdapter((options, bodyText) async {
      final path = options.uri.path;
      if (path.endsWith('/drive/v3/files') && options.method == 'GET') {
        final q = (options.queryParameters['q'] ?? '').toString();
        final nameMatch = RegExp(r"name = '([^']+)'").firstMatch(q);
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
        uploadCalls++;
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

      return ResponseBody.fromString(
        jsonEncode({'error': 'unhandled'}),
        404,
      );
    });
    return dio;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Otomatik Hesap Şifreleme & Parola Eşleştirme', () {
    test(
      'same Gmail devices decrypt cloud backup automatically without manual Workspace Key while different Gmail fails',
      () async {
        final drive = _InMemoryFakeDrive();
        final dirA = await Directory.systemTemp.createTemp('hasibu_auto_a_');
        final dirB = await Directory.systemTemp.createTemp('hasibu_auto_b_');
        final dirC = await Directory.systemTemp.createTemp('hasibu_auto_c_');
        addTearDown(() async {
          await dirA.delete(recursive: true);
          await dirB.delete(recursive: true);
          await dirC.delete(recursive: true);
        });

        // Cihaz A (Laptop): ortak@gmail.com, manuel Workspace Key girilmemiş
        final dbA = HasibuDatabase.inMemory();
        addTearDown(dbA.dispose);
        dbA.saveCompanySettings(
          dbA.getCompanySettings().copyWith(
                companyName: 'AKAR MERKEZ A.Ş.',
                syncGmailAccount: 'Ortak@Gmail.com',
                syncFolderPath: dirA.path,
              ),
        );
        final syncA = GoogleDriveSyncService(
          db: dbA,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await syncA.saveOAuthTokens(accessToken: 'ya29.laptop-a');

        final containerA = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(dbA),
            googleDriveSyncServiceProvider.overrideWithValue(syncA),
            googleAuthAdapterProvider.overrideWithValue(
              _FakeGoogleAuthAdapter(
                nextResult: const BrowserGoogleSignInResult(
                  success: true,
                  accessToken: 'ya29.laptop-a',
                  email: 'ortak@gmail.com',
                  message: 'OK',
                ),
              ),
            ),
          ],
        );
        addTearDown(containerA.dispose);

        final notifierA = containerA.read(pdksDashboardProvider.notifier);
        await notifierA.saveAppUser(
          username: 'ik_ayse',
          displayName: 'Ayşe İK',
          plainPassword: 'Ayse#2026',
          role: AppUserRole.hrManager,
          allowedModules: const [HasibuModule.pdksHr],
          linkedGmail: 'ortak@gmail.com',
        );
        await notifierA.saveAppUser(
          username: 'sube_ahmet',
          displayName: 'Ahmet Şube',
          plainPassword: 'Ahmet#2026',
          role: AppUserRole.branchSupervisor,
          allowedModules: const [HasibuModule.pdksHr],
          allowedBranchId: 38,
        );

        final backupStatus = await notifierA.backupToCloudNow();
        expect(backupStatus.stage, equals(DriveSyncStage.synced));

        // Cihaz B (Telefon): tamamen boş local storage & DB, aynı Gmail
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final dbB = HasibuDatabase.inMemory();
        addTearDown(dbB.dispose);
        dbB.saveCompanySettings(
          dbB.getCompanySettings().copyWith(
                syncGmailAccount: 'ortak@gmail.com',
                syncFolderPath: dirB.path,
              ),
        );
        final syncB = GoogleDriveSyncService(
          db: dbB,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await syncB.saveOAuthTokens(accessToken: 'ya29.phone-b');

        final containerB = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(dbB),
            googleDriveSyncServiceProvider.overrideWithValue(syncB),
            googleAuthAdapterProvider.overrideWithValue(
              _FakeGoogleAuthAdapter(
                nextResult: const BrowserGoogleSignInResult(
                  success: true,
                  accessToken: 'ya29.phone-b',
                  email: 'ortak@gmail.com',
                  message: 'OK',
                ),
              ),
            ),
          ],
        );
        addTearDown(containerB.dispose);

        final restoreB = await containerB
            .read(pdksDashboardProvider.notifier)
            .restoreFromCloudNow(
              mode: CloudRestoreMode.merge,
              cloudOnly: true,
            );
        expect(restoreB.summary, isNotNull);
        expect(restoreB.status.isDecryptionKeyMismatch, isFalse);
        expect(
          dbB.getAppUsers().map((u) => u.username),
          containsAll(['ik_ayse', 'sube_ahmet']),
        );

        // Cihaz C: farklı bir Gmail hesabıyla aynı dosyayı çözememeli
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final dbC = HasibuDatabase.inMemory();
        addTearDown(dbC.dispose);
        dbC.saveCompanySettings(
          dbC.getCompanySettings().copyWith(
                syncGmailAccount: 'baska@gmail.com',
                syncFolderPath: dirC.path,
              ),
        );
        final syncC = GoogleDriveSyncService(
          db: dbC,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await syncC.saveOAuthTokens(accessToken: 'ya29.other-c');

        final restoreC = await syncC.restoreFromCloud(cloudOnly: true);
        expect(restoreC.summary, isNull);
        expect(restoreC.status.stage, equals(DriveSyncStage.error));
        expect(restoreC.status.isDecryptionKeyMismatch, isTrue);
      },
    );

    test(
      'custom cloud sync passphrase encrypts backup and unlocks on another device without long hex key',
      () async {
        final drive = _InMemoryFakeDrive();
        final dirA = await Directory.systemTemp.createTemp('hasibu_pass_a_');
        final dirB = await Directory.systemTemp.createTemp('hasibu_pass_b_');
        addTearDown(() async {
          await dirA.delete(recursive: true);
          await dirB.delete(recursive: true);
        });

        final dbA = HasibuDatabase.inMemory();
        addTearDown(dbA.dispose);
        dbA.saveCompanySettings(
          dbA.getCompanySettings().copyWith(
                syncGmailAccount: 'ortak@gmail.com',
                syncFolderPath: dirA.path,
              ),
        );
        final syncA = GoogleDriveSyncService(
          db: dbA,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await syncA.saveOAuthTokens(accessToken: 'ya29.pass-a');
        await syncA.saveCloudSyncPassphrase('Sirket2026!');
        dbA.upsertShift(
          const ShiftPlan(
            id: 777,
            name: 'Özel Parola Vardiyası',
            startTime: '07:00',
            endTime: '16:00',
          ),
        );
        final pushRes = await syncA.pushToCloud(force: true);
        expect(pushRes.stage, equals(DriveSyncStage.synced));

        // Hedef cihaz parolayı bilmeden açamamalı
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final dbB = HasibuDatabase.inMemory();
        addTearDown(dbB.dispose);
        dbB.saveCompanySettings(
          dbB.getCompanySettings().copyWith(
                syncGmailAccount: 'ortak@gmail.com',
                syncFolderPath: dirB.path,
              ),
        );
        final syncB = GoogleDriveSyncService(
          db: dbB,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await syncB.saveOAuthTokens(accessToken: 'ya29.pass-b');

        final failed = await syncB.restoreFromCloud(cloudOnly: true);
        expect(failed.summary, isNull);
        expect(failed.status.isDecryptionKeyMismatch, isTrue);

        // Kısa parolayı girince açılıp kaydedilmeli
        final unlocked = await syncB.restoreFromCloud(
          cloudOnly: true,
          overrideWorkspaceKey: 'Sirket2026!',
        );
        expect(unlocked.summary, isNotNull);
        expect(
          dbB.getShifts().any((s) => s.id == 777),
          isTrue,
        );
        expect(
          await syncB.getCloudEncryptionKeyMode(),
          equals(CloudEncryptionKeyMode.customPassphrase),
        );
      },
    );

    test(
      'syncWithGoogleDriveNow aborts without overwriting Drive backup when decryption fails',
      () async {
        final drive = _InMemoryFakeDrive();
        final dirA = await Directory.systemTemp.createTemp('hasibu_prot_a_');
        final dirB = await Directory.systemTemp.createTemp('hasibu_prot_b_');
        addTearDown(() async {
          await dirA.delete(recursive: true);
          await dirB.delete(recursive: true);
        });

        final dbA = HasibuDatabase.inMemory();
        addTearDown(dbA.dispose);
        dbA.saveCompanySettings(
          dbA.getCompanySettings().copyWith(
                syncGmailAccount: 'ortak@gmail.com',
                syncFolderPath: dirA.path,
              ),
        );
        final syncA = GoogleDriveSyncService(
          db: dbA,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await syncA.saveOAuthTokens(accessToken: 'ya29.prot-a');
        await syncA.saveWorkspaceKey('device-a-only-secret-key');
        await syncA.pushToCloud(force: true);
        final uploadsBefore = drive.uploadCalls;

        // Cihaz B farklı anahtarla syncWithGoogleDriveNow() çağırırsa Drive'ı ezmemeli
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final dbB = HasibuDatabase.inMemory();
        addTearDown(dbB.dispose);
        dbB.saveCompanySettings(
          dbB.getCompanySettings().copyWith(
                syncGmailAccount: 'ortak@gmail.com',
                syncFolderPath: dirB.path,
              ),
        );
        final syncB = GoogleDriveSyncService(
          db: dbB,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await syncB.saveOAuthTokens(accessToken: 'ya29.prot-b');

        final containerB = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(dbB),
            googleDriveSyncServiceProvider.overrideWithValue(syncB),
            googleAuthAdapterProvider.overrideWithValue(
              _FakeGoogleAuthAdapter(
                nextResult: const BrowserGoogleSignInResult(
                  success: true,
                  accessToken: 'ya29.prot-b',
                  email: 'ortak@gmail.com',
                  message: 'OK',
                ),
              ),
            ),
          ],
        );
        addTearDown(containerB.dispose);

        await containerB
            .read(pdksDashboardProvider.notifier)
            .syncWithGoogleDriveNow();
        final st = containerB.read(pdksDashboardProvider).syncStatus;
        expect(st.stage, equals(DriveSyncStage.error));
        expect(st.isDecryptionKeyMismatch, isTrue);
        expect(drive.uploadCalls, equals(uploadsBefore));
      },
    );
  });

  group('Kalıcı Google Oturumu & Çoklu Kullanıcı Girişi', () {
    test(
      'restorePersistedGoogleSession keeps Gmail connected across restarts while authSession starts unauthenticated',
      () async {
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(syncGmailAccount: 'ortak@gmail.com'),
        );
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );
        await sync.saveOAuthTokens(
          accessToken: 'ya29.persisted-token',
          refreshToken: '1//persisted-refresh',
        );

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            googleDriveSyncServiceProvider.overrideWithValue(sync),
            googleAuthAdapterProvider.overrideWithValue(
              _FakeGoogleAuthAdapter(
                nextResult: const BrowserGoogleSignInResult(
                  success: true,
                  accessToken: 'ya29.persisted-token',
                  email: 'ortak@gmail.com',
                  message: 'OK',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(pdksDashboardProvider.notifier)
            .restorePersistedGoogleSession();

        final st = container.read(pdksDashboardProvider);
        expect(st.isGoogleCloudConnected, isTrue);
        expect(st.syncStatus.connectedGmail, equals('ortak@gmail.com'));
        expect(st.authSession.isAuthenticated, isFalse);
      },
    );

    test(
      'signInWithGoogleViaBrowser pulls cloud users and prompts user/password login when appUsers exist, and logout preserves Gmail connection',
      () async {
        final drive = _InMemoryFakeDrive();
        final dirA = await Directory.systemTemp.createTemp('hasibu_usr_a_');
        final dirB = await Directory.systemTemp.createTemp('hasibu_usr_b_');
        addTearDown(() async {
          await dirA.delete(recursive: true);
          await dirB.delete(recursive: true);
        });

        // Cihaz A'da 2 kullanıcı oluştur ve yedekle
        final dbA = HasibuDatabase.inMemory();
        addTearDown(dbA.dispose);
        dbA.saveCompanySettings(
          dbA.getCompanySettings().copyWith(
                syncGmailAccount: 'ortak@gmail.com',
                syncFolderPath: dirA.path,
              ),
        );
        final syncA = GoogleDriveSyncService(
          db: dbA,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        await syncA.saveOAuthTokens(accessToken: 'ya29.usr-a');
        final containerA = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(dbA),
            googleDriveSyncServiceProvider.overrideWithValue(syncA),
            googleAuthAdapterProvider.overrideWithValue(
              _FakeGoogleAuthAdapter(
                nextResult: const BrowserGoogleSignInResult(
                  success: true,
                  accessToken: 'ya29.usr-a',
                  email: 'ortak@gmail.com',
                  message: 'OK',
                ),
              ),
            ),
          ],
        );
        addTearDown(containerA.dispose);
        final notifierA = containerA.read(pdksDashboardProvider.notifier);
        await notifierA.saveAppUser(
          username: 'ik_ayse',
          displayName: 'Ayşe İK',
          plainPassword: 'Ayse#2026',
          role: AppUserRole.hrManager,
          allowedModules: const [HasibuModule.pdksHr],
          linkedGmail: 'ortak@gmail.com',
        );
        await notifierA.saveAppUser(
          username: 'sube_mehmet',
          displayName: 'Mehmet Şube',
          plainPassword: 'Mehmet#2026',
          role: AppUserRole.branchSupervisor,
          allowedModules: const [HasibuModule.pdksHr],
          allowedBranchId: 2,
        );
        await notifierA.backupToCloudNow();

        // Cihaz B Google ile bağlandığında kullanıcıları çekip kullanıcı girişi istemeli
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final dbB = HasibuDatabase.inMemory();
        addTearDown(dbB.dispose);
        dbB.saveCompanySettings(
          dbB.getCompanySettings().copyWith(syncFolderPath: dirB.path),
        );
        final syncB = GoogleDriveSyncService(
          db: dbB,
          secureStorage: const FlutterSecureStorage(),
          dio: drive.buildDio(),
        );
        final containerB = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(dbB),
            googleDriveSyncServiceProvider.overrideWithValue(syncB),
            googleAuthAdapterProvider.overrideWithValue(
              _FakeGoogleAuthAdapter(
                nextResult: const BrowserGoogleSignInResult(
                  success: true,
                  accessToken: 'ya29.usr-b',
                  email: 'ortak@gmail.com',
                  displayName: 'Ortak Hesap',
                  message: 'OK',
                ),
              ),
            ),
          ],
        );
        addTearDown(containerB.dispose);
        final notifierB = containerB.read(pdksDashboardProvider.notifier);

        final signInRes = await notifierB.signInWithGoogleViaBrowser(
          authenticateAppSession: true,
        );
        expect(signInRes.success, isTrue);
        expect(signInRes.requiresUserLogin, isTrue);
        expect(signInRes.suggestedUsername, equals('ik_ayse'));

        final afterGoogle = containerB.read(pdksDashboardProvider);
        expect(afterGoogle.isGoogleCloudConnected, isTrue);
        expect(afterGoogle.authSession.isAuthenticated, isFalse);
        expect(afterGoogle.appUsers.length, equals(2));

        // Oluşturulan kullanıcı ile yetkili giriş ve çıkış sonrası bulut bağlantısının korunması
        final ok = notifierB.loginAsAdmin(
          username: 'sube_mehmet',
          password: 'Mehmet#2026',
        );
        expect(ok, isTrue);
        expect(
          containerB.read(pdksDashboardProvider).authSession.scopedBranchId,
          equals(2),
        );

        notifierB.logout();
        final afterLogout = containerB.read(pdksDashboardProvider);
        expect(afterLogout.authSession.isAuthenticated, isFalse);
        expect(afterLogout.isGoogleCloudConnected, isTrue);
      },
    );
  });

  group('Giriş Ekranı Remember Username & Responsive Widget Testleri', () {
    Future<void> runLoginScreenFlow(
      WidgetTester tester, {
      required Size viewportSize,
    }) async {
      tester.view.physicalSize = viewportSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});

      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);
      db.saveCompanySettings(
        db.getCompanySettings().copyWith(syncGmailAccount: 'ortak@gmail.com'),
      );
      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
      );
      await sync.saveOAuthTokens(
        accessToken: 'ya29.widget-token',
        refreshToken: '1//widget-refresh',
      );

      final fakeAdapter = _FakeGoogleAuthAdapter(
        nextResult: const BrowserGoogleSignInResult(
          success: true,
          accessToken: 'ya29.widget-token',
          email: 'ortak@gmail.com',
          message: 'OK',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(sync),
          googleAuthAdapterProvider.overrideWithValue(fakeAdapter),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pdksDashboardProvider.notifier);
      await notifier.updateCloudBackupSettings(autoCloudBackupEnabled: false);
      await notifier.saveAppUser(
        username: 'ik_ayse',
        displayName: 'Ayşe İK',
        plainPassword: 'Ayse#2026',
        role: AppUserRole.hrManager,
        allowedModules: const [HasibuModule.pdksHr],
      );
      await notifier.restorePersistedGoogleSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HasibuLoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byKey(const ValueKey('login_hasibu_brand')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('login_company_logo_badge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('login_cloud_session_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('login_forgot_password_button')),
        findsOneWidget,
      );
      // Kayıtlı kullanıcı listesi ve büyük bulut banner'ı ana ekranda gizli olmalı
      expect(find.byKey(const ValueKey('login_user_chip_ik_ayse')), findsNothing);
      expect(
        find.byKey(const ValueKey('login_google_connected_banner')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('login_remember_username_checkbox')),
        findsOneWidget,
      );

      // Üst minimalist bulut ikonuna tıklanınca bulut oturumu diyaloğu açılmalı
      await tester.tap(find.byKey(const ValueKey('login_cloud_session_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('login_google_connected_banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('login_btn_pull_cloud_users')),
        findsOneWidget,
      );
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();

      // Kullanıcı adı elle girilip oturum açılınca SharedPreferences'a kaydedilmeli
      await tester.enterText(
        find.byKey(const ValueKey('login_username_field')),
        'ik_ayse',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login_password_field')),
        'Ayse#2026',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('login_submit_button')),
      );
      await tester.tap(find.byKey(const ValueKey('login_submit_button')));
      await tester.pumpAndSettle();
      expect(
        container.read(pdksDashboardProvider).authSession.username,
        equals('ik_ayse'),
      );

      // Yeniden başlatma simülasyonu: kullanıcı adı hatırlanmalı, parola boş olmalı
      notifier.logout();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HasibuLoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final usernameField = tester.widget<TextField>(
        find.byKey(const ValueKey('login_username_field')),
      );
      final passwordField = tester.widget<TextField>(
        find.byKey(const ValueKey('login_password_field')),
      );
      expect(usernameField.controller?.text, equals('ik_ayse'));
      expect(passwordField.controller?.text, isEmpty);

      // "Kullanıcı adını hatırla" kapatılınca tercih temizlenmeli
      await tester.ensureVisible(
        find.byKey(const ValueKey('login_remember_username_checkbox')),
      );
      await tester.tap(
        find.byKey(const ValueKey('login_remember_username_checkbox')),
      );
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hasibu_login_saved_username_v1'), isNull);
      expect(prefs.getBool('hasibu_login_remember_username_v1'), isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
    }

    testWidgets('Desktop 1440x900 login persistence & overflow check', (tester) async {
      await runLoginScreenFlow(
        tester,
        viewportSize: const Size(1440, 900),
      );
    });

    testWidgets('Mobile 390x844 login persistence & overflow check', (tester) async {
      await runLoginScreenFlow(
        tester,
        viewportSize: const Size(390, 844),
      );
    });

    testWidgets(
      'Mobile 390x844 CloudBackupCenterDialog encryption modes & pairing QR render cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hasibuDatabaseProvider.overrideWithValue(db),
              googleDriveSyncServiceProvider.overrideWithValue(sync),
              googleAuthAdapterProvider.overrideWithValue(
                _FakeGoogleAuthAdapter(
                  nextResult: const BrowserGoogleSignInResult(
                    success: true,
                    accessToken: 'ya29.qr-test',
                    email: 'ortak@gmail.com',
                    message: 'OK',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => Center(
                    child: FilledButton(
                      key: const ValueKey('open_dialog_btn'),
                      onPressed: () => showCloudBackupCenterDialog(context, ref),
                      child: const Text('Aç'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(
          find.byKey(const ValueKey('encryption_mode_account_auto')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('encryption_mode_custom')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('btn_show_pairing_qr')),
          findsOneWidget,
        );

        // Özel parola moduna geçip parola kaydet
        await tester.ensureVisible(
          find.byKey(const ValueKey('encryption_mode_custom')),
        );
        await tester.tap(find.byKey(const ValueKey('encryption_mode_custom')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('cloud_sync_passphrase_field')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('cloud_sync_passphrase_field')),
          'OrtakSifre99',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('btn_save_cloud_passphrase')),
        );
        await tester.tap(find.byKey(const ValueKey('btn_save_cloud_passphrase')));
        await tester.pumpAndSettle();
        expect(
          await sync.getCloudEncryptionKeyMode(),
          equals(CloudEncryptionKeyMode.customPassphrase),
        );

        // QR eşleştirme diyalogu sorunsuz açılmalı
        await tester.ensureVisible(
          find.byKey(const ValueKey('btn_show_pairing_qr')),
        );
        await tester.tap(find.byKey(const ValueKey('btn_show_pairing_qr')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Cihaz Eşleştirme QR Kodu'), findsWidgets);
      },
    );
  });
}
