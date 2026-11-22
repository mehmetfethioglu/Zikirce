import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';
import 'package:hasibu/core/security/license_guard_service.dart';
import 'package:hasibu/core/services/google_auth_adapter.dart';
import 'package:hasibu/core/services/google_drive_sync_service.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/features/pdks/presentation/screens/app_users_management_card.dart';
import 'package:hasibu/features/pdks/presentation/screens/cloud_backup_center_dialog.dart';

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
  }) async {
    return const BrowserGoogleSignInResult(
      success: true,
      accessToken: 'ya29.fake-token',
      email: 'test@gmail.com',
      message: 'OK',
    );
  }

  @override
  Future<void> signOut() async {}
}

/// Basit bellek içi Google Drive API sahtesi (upload/download/list simülasyonu).
class _InMemoryFakeDrive {
  final Map<String, ({String id, String content, DateTime modified})> files =
      <String, ({String id, String content, DateTime modified})>{};
  int uploadCalls = 0;
  int listCalls = 0;

  Dio buildDio() {
    final dio = Dio();
    dio.httpClientAdapter = _StubHttpClientAdapter((options, bodyText) async {
      final path = options.uri.path;
      if (path.endsWith('/drive/v3/files') && options.method == 'GET') {
        final q = (options.queryParameters['q'] ?? '').toString();
        if (q.contains("name contains 'hasibu_sync'")) {
          listCalls++;
          final items = files.entries
              .where((e) => e.key.contains('hasibu_sync'))
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
          final key = files.entries
              .firstWhere((e) => e.value.id == fileId)
              .key;
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
  });

  group('1. Manuel Bulut Yedekleme & Geri Yükleme (Birleştir / Üzerine Yaz)', () {
    test(
        'backupToCloudNow & restoreFromCloudNow support merge and replace while protecting audit_logs & local device bindings',
        () async {
      final drive = _InMemoryFakeDrive();
      final dbA = HasibuDatabase.inMemory();
      addTearDown(dbA.dispose);
      final syncDirA =
          await Directory.systemTemp.createTemp('hasibu_cloud_a_');
      addTearDown(() => syncDirA.delete(recursive: true));

      final syncA = GoogleDriveSyncService(
        db: dbA,
        secureStorage: const FlutterSecureStorage(),
        dio: drive.buildDio(),
      );
      await syncA.saveOAuthTokens(accessToken: 'ya29.test-a');
      await syncA.saveWorkspaceKey('shared-secret-key-2026');
      dbA.saveCompanySettings(
        dbA.getCompanySettings().copyWith(
              companyName: 'BULUT KAYNAK ŞİRKETİ',
              syncGmailAccount: 'ortak@gmail.com',
              syncFolderPath: syncDirA.path,
            ),
      );
      dbA.upsertShift(
        const ShiftPlan(
          id: 901,
          name: 'Bulut Vardiyası',
          startTime: '09:00',
          endTime: '18:00',
        ),
      );

      final containerA = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(dbA),
          googleDriveSyncServiceProvider.overrideWithValue(syncA),
          googleAuthAdapterProvider.overrideWithValue(_FakeGoogleAuthAdapter()),
        ],
      );
      addTearDown(containerA.dispose);

      final pushStatus =
          await containerA.read(pdksDashboardProvider.notifier).backupToCloudNow();
      expect(pushStatus.stage, equals(DriveSyncStage.synced));
      expect(pushStatus.isCloudApiVerified, isTrue);
      expect(drive.files.containsKey('hasibu_sync.enc'), isTrue);

      // Hedef cihaz B: yerel bir ekstra vardiya (902) ve kendi cihaz donanım kimliği olsun
      final dbB = HasibuDatabase.inMemory();
      addTearDown(dbB.dispose);
      final syncDirB =
          await Directory.systemTemp.createTemp('hasibu_cloud_b_');
      addTearDown(() => syncDirB.delete(recursive: true));

      final localLicenseB =
          LicenseGuardService.createBootstrapLicenseTokenSync(
        company: 'CIHAZ B',
        hwId: 'HSB-HW-DEVICE-B-LOCAL',
      );
      final originalBSettings = dbB.getCompanySettings().copyWith(
            syncGmailAccount: 'ortak@gmail.com',
            syncFolderPath: syncDirB.path,
            hardwareFingerprint: 'HSB-HW-DEVICE-B-LOCAL',
            licenseToken: localLicenseB,
          );
      dbB.saveCompanySettings(originalBSettings);
      dbB.upsertShift(
        const ShiftPlan(
          id: 902,
          name: 'Yerel Ekstra Vardiya',
          startTime: '10:00',
          endTime: '19:00',
        ),
      );

      final syncB = GoogleDriveSyncService(
        db: dbB,
        secureStorage: const FlutterSecureStorage(),
        dio: drive.buildDio(),
      );
      await syncB.saveOAuthTokens(accessToken: 'ya29.test-b');
      await syncB.saveWorkspaceKey('shared-secret-key-2026');

      final containerB = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(dbB),
          googleDriveSyncServiceProvider.overrideWithValue(syncB),
          googleAuthAdapterProvider.overrideWithValue(_FakeGoogleAuthAdapter()),
        ],
      );
      addTearDown(containerB.dispose);
      final notifierB = containerB.read(pdksDashboardProvider.notifier);

      // 1a) Merge: hem 901 (bulut) hem 902 (yerel) korunmalı
      final mergeRes = await notifierB.restoreFromCloudNow(
        mode: CloudRestoreMode.merge,
        cloudOnly: true,
      );
      expect(mergeRes.summary, isNotNull);
      expect(mergeRes.summary!.mode, equals(CloudRestoreMode.merge));
      expect(dbB.getShifts().any((s) => s.id == 901), isTrue);
      expect(dbB.getShifts().any((s) => s.id == 902), isTrue);

      // 1b) Replace: 902 silinmeli, 901 kalmalı, yerel donanım kimliği & lisans korunmalı, audit_logs sağlam olmalı
      final replaceRes = await notifierB.restoreFromCloudNow(
        mode: CloudRestoreMode.replace,
        cloudOnly: true,
      );
      expect(replaceRes.summary, isNotNull);
      expect(replaceRes.summary!.mode, equals(CloudRestoreMode.replace));
      expect(dbB.getShifts().any((s) => s.id == 901), isTrue);
      expect(dbB.getShifts().any((s) => s.id == 902), isFalse);
      expect(
        dbB.getCompanySettings().hardwareFingerprint,
        equals('HSB-HW-DEVICE-B-LOCAL'),
      );
      expect(
        dbB.getCompanySettings().licenseToken,
        equals(localLicenseB),
      );
      expect(
        dbB
            .getAuditLogs()
            .any((a) => a.actionType == 'CLOUD_RESTORE_REPLACE'),
        isTrue,
      );
    });

    test('portal_queue snapshot rejects CloudRestoreMode.replace', () {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);
      final portalSnap = db.exportPortalQueueSnapshot(
        deviceName: 'Mobile',
        employeeCardNo: '00064',
      );
      expect(
        () => db.restoreCloudSnapshot(
          portalSnap,
          mode: CloudRestoreMode.replace,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('2. Otomatik Bulut Yedekleme Ayarları & Akışı', () {
    test(
        'autoCloudBackup settings persist and gate on-change backups & deduplicate unchanged timer runs',
        () async {
      final drive = _InMemoryFakeDrive();
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);
      final tempDir =
          await Directory.systemTemp.createTemp('hasibu_autobackup_');
      addTearDown(() => tempDir.delete(recursive: true));
      db.saveCompanySettings(
        db.getCompanySettings().copyWith(syncFolderPath: tempDir.path),
      );

      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
        dio: drive.buildDio(),
      );
      await sync.saveOAuthTokens(accessToken: 'ya29.auto-token');

      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(sync),
          googleAuthAdapterProvider.overrideWithValue(_FakeGoogleAuthAdapter()),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(pdksDashboardProvider.notifier);

      // Kalıcılık kontrolü
      await notifier.updateCloudBackupSettings(
        autoCloudBackupEnabled: false,
        autoCloudBackupMinutes: 60,
        autoCloudBackupOnChange: false,
      );
      final saved1 = db.getCompanySettings();
      expect(saved1.autoCloudBackupEnabled, isFalse);
      expect(saved1.autoCloudBackupMinutes, equals(60));
      expect(saved1.autoCloudBackupOnChange, isFalse);

      // Kapalıyken değişiklikte otomatik yedekleme yapılmamalı
      await notifier.saveShiftPlan(
        const ShiftPlan(
          id: 950,
          name: 'Sessiz Vardiya',
          startTime: '08:00',
          endTime: '17:00',
        ),
      );
      expect(drive.uploadCalls, equals(0));

      // Otomatik yedek açık ama değişiklikte yedekleme kapalı -> yine yüklememeli
      await notifier.updateCloudBackupSettings(
        autoCloudBackupEnabled: true,
        autoCloudBackupOnChange: false,
      );
      await notifier.saveShiftPlan(
        const ShiftPlan(
          id: 951,
          name: 'Ara Vardiya',
          startTime: '08:00',
          endTime: '17:00',
        ),
      );
      expect(drive.uploadCalls, equals(0));

      // İkisi de açık -> değişiklikte otomatik yüklemeli
      await notifier.updateCloudBackupSettings(
        autoCloudBackupEnabled: true,
        autoCloudBackupOnChange: true,
      );
      await notifier.saveShiftPlan(
        const ShiftPlan(
          id: 952,
          name: 'Otomatik Vardiya',
          startTime: '08:00',
          endTime: '17:00',
        ),
      );
      expect(drive.uploadCalls, equals(1));

      // runAutomaticCloudBackup: veri değişmediyse mükerrer yükleme yapmamalı
      await notifier.runAutomaticCloudBackup();
      expect(drive.uploadCalls, equals(1));
    });
  });

  group('3. Aynı Gmailde Çoklu Yedek Profili & Çalışma Alanı Anahtarı', () {
    test(
        'normalizeCloudProfileId, listAvailableCloudBackups and workspace key mismatch recovery work',
        () async {
      expect(
        GoogleDriveSyncService.normalizeCloudProfileId('  Şube Bursa 01! '),
        equals('sube_bursa_01'),
      );
      expect(
        GoogleDriveSyncService.backupFileNameForProfile('default'),
        equals('hasibu_sync.enc'),
      );
      expect(
        GoogleDriveSyncService.backupFileNameForProfile('Şube Bursa'),
        equals('hasibu_sync_sube_bursa.enc'),
      );

      final drive = _InMemoryFakeDrive();
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);
      final tempDir =
          await Directory.systemTemp.createTemp('hasibu_multiprofile_');
      addTearDown(() => tempDir.delete(recursive: true));
      db.saveCompanySettings(
        db.getCompanySettings().copyWith(syncFolderPath: tempDir.path),
      );

      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
        dio: drive.buildDio(),
      );
      await sync.saveOAuthTokens(accessToken: 'ya29.profile-token');
      await sync.saveWorkspaceKey('key-profile-one');

      // Profil 1: default
      await sync.pushToCloud(force: true, profileId: 'default');
      // Profil 2: sube_bursa
      db.upsertBranch(
        const Branch(
          id: 99,
          code: 'BRS',
          name: 'Bursa Şubesi',
          hasTerminal: false,
          latitude: 40.18,
          longitude: 29.06,
        ),
      );
      await sync.pushToCloud(force: true, profileId: 'sube_bursa');

      final listed = await sync.listAvailableCloudBackups();
      expect(listed.map((e) => e.profileId), containsAll(['default', 'sube_bursa']));

      // Yanlış workspace key ile geri yükleme Türkçe hata vermeli
      final dbTarget = HasibuDatabase.inMemory();
      addTearDown(dbTarget.dispose);
      final syncTarget = GoogleDriveSyncService(
        db: dbTarget,
        secureStorage: const FlutterSecureStorage(),
        dio: drive.buildDio(),
      );
      await syncTarget.saveOAuthTokens(accessToken: 'ya29.target');
      await syncTarget.saveWorkspaceKey('wrong-key');

      final failedRestore = await syncTarget.restoreFromCloud(
        profileId: 'sube_bursa',
        cloudOnly: true,
      );
      expect(failedRestore.summary, isNull);
      expect(failedRestore.status.stage, equals(DriveSyncStage.error));
      expect(
        failedRestore.status.message,
        contains('Çalışma Alanı Anahtarı'),
      );

      // Doğru overrideWorkspaceKey ile çözülmeli
      final okRestore = await syncTarget.restoreFromCloud(
        profileId: 'sube_bursa',
        cloudOnly: true,
        overrideWorkspaceKey: 'key-profile-one',
      );
      expect(okRestore.summary, isNotNull);
      expect(
        dbTarget.getBranches().any((b) => b.name == 'Bursa Şubesi'),
        isTrue,
      );
    });
  });

  group('4. Aynı Şirkette Çoklu Yetkili Kullanıcı & Bulut Aktarımı', () {
    test(
        'saveAppUser hashes passwords, blocks duplicates/inactive, scopes branches & syncs via snapshot',
        () async {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);
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

      await notifier.updateCloudBackupSettings(
        autoCloudBackupEnabled: false,
      );

      final rootDupErr = await notifier.saveAppUser(
        username: 'admin',
        displayName: 'Sahte Admin',
        plainPassword: 'secret',
        role: AppUserRole.superAdmin,
        allowedModules: HasibuModule.activePhaseModules,
      );
      expect(rootDupErr, isNotNull);

      final createErr = await notifier.saveAppUser(
        username: 'sube_sorumlusu',
        displayName: 'Ahmet Şube',
        plainPassword: 'Sube#2026',
        role: AppUserRole.branchSupervisor,
        allowedModules: const <HasibuModule>[HasibuModule.pdksHr],
        allowedBranchId: 2,
        linkedGmail: 'ahmet@gmail.com',
      );
      expect(createErr, isNull);

      final dupErr = await notifier.saveAppUser(
        username: 'SUBE_SORUMLUSU',
        displayName: 'Tekrar',
        plainPassword: '123',
        role: AppUserRole.hrManager,
        allowedModules: const <HasibuModule>[HasibuModule.pdksHr],
      );
      expect(dupErr, isNotNull);

      final stored = db.findAppUserByUsername('sube_sorumlusu');
      expect(stored, isNotNull);
      expect(
        HasibuSecurityService.isPasswordHashed(stored!.passwordHash),
        isTrue,
      );

      // Giriş kontrolü
      final loggedIn = notifier.loginAsAdmin(
        username: 'sube_sorumlusu',
        password: 'Sube#2026',
      );
      expect(loggedIn, isTrue);
      final session = container.read(pdksDashboardProvider).authSession;
      expect(session.appUserId, equals(stored.id));
      expect(session.scopedBranchId, equals(2));
      expect(session.canAccess(HasibuModule.pdksHr), isTrue);
      expect(session.canAccess(HasibuModule.systemSettings), isFalse);

      // Pasif yapıldığında giriş engellenmeli
      await notifier.toggleAppUserActive(stored.id, false);
      notifier.logout();
      expect(
        notifier.loginAsAdmin(
          username: 'sube_sorumlusu',
          password: 'Sube#2026',
        ),
        isFalse,
      );
      await notifier.toggleAppUserActive(stored.id, true);

      // Snapshot ile ikinci veritabanına aktarım
      final snapshot = db.exportCloudSnapshot(deviceName: 'Kaynak PC');
      final db2 = HasibuDatabase.inMemory();
      addTearDown(db2.dispose);
      final summary = db2.restoreCloudSnapshot(
        snapshot,
        mode: CloudRestoreMode.merge,
      );
      expect(summary.appUsersCount, greaterThanOrEqualTo(1));

      final container2 = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db2),
          googleDriveSyncServiceProvider.overrideWithValue(
            GoogleDriveSyncService(
              db: db2,
              secureStorage: const FlutterSecureStorage(),
            ),
          ),
          googleAuthAdapterProvider.overrideWithValue(_FakeGoogleAuthAdapter()),
        ],
      );
      addTearDown(container2.dispose);
      expect(
        container2.read(pdksDashboardProvider.notifier).loginAsAdmin(
              username: 'sube_sorumlusu',
              password: 'Sube#2026',
            ),
        isTrue,
      );
    });
  });

  group('5. Widget Duman Testleri (Masaüstü 1440x900 & Mobil 390x844)', () {
    Future<void> pumpCloudAndUsersHost(
      WidgetTester tester, {
      required Size viewportSize,
    }) async {
      tester.view.physicalSize = viewportSize;
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
            googleAuthAdapterProvider
                .overrideWithValue(_FakeGoogleAuthAdapter()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CloudBackupQuickCard(),
                      const SizedBox(height: 16),
                      const AppUsersManagementCard(),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const ValueKey('test_open_cloud_center'),
                        onPressed: () =>
                            showCloudBackupCenterDialog(context, ref),
                        child: const Text('Bulut Merkezi Aç'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byKey(const ValueKey('quick_btn_cloud_backup')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_btn_cloud_restore')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_add_app_user')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('test_open_cloud_center')),
      );
      await tester.tap(find.byKey(const ValueKey('test_open_cloud_center')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byKey(const ValueKey('btn_cloud_backup_now')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_cloud_restore_now')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('switch_auto_cloud_backup')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dropdown_auto_cloud_interval')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('switch_auto_cloud_on_change')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('btn_save_cloud_profile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('btn_scan_cloud_profiles')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('btn_google_browser_oauth')),
        findsOneWidget,
      );

      // Buluttan Yükle diyalogunda Tam Geri Yükle onay kilidini doğrula
      await tester.tap(find.byKey(const ValueKey('btn_cloud_restore_now')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('restore_mode_replace')));
      await tester.pumpAndSettle();
      final confirmBtn = tester.widget<FilledButton>(
        find.byKey(const ValueKey('btn_confirm_cloud_restore')),
      );
      expect(confirmBtn.onPressed, isNull);
    }

    testWidgets('Desktop 1440x900 renders without overflow', (tester) async {
      await pumpCloudAndUsersHost(
        tester,
        viewportSize: const Size(1440, 900),
      );
    });

    testWidgets('Mobile 390x844 renders without overflow', (tester) async {
      await pumpCloudAndUsersHost(
        tester,
        viewportSize: const Size(390, 844),
      );
    });
  });
}
