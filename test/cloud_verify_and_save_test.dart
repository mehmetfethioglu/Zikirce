import 'dart:async';
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
import 'package:hasibu/core/services/google_auth_adapter.dart';
import 'package:hasibu/core/services/google_drive_sync_service.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/features/pdks/presentation/screens/cloud_backup_center_dialog.dart';
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
      email: 'test@gmail.com',
      message: 'OK',
    );
  }

  @override
  Future<String?> refreshAccessTokenSilently() async => null;

  @override
  Future<void> signOut() async {}
}

class _ThrowingPullDriveSyncService extends GoogleDriveSyncService {
  _ThrowingPullDriveSyncService({
    required super.db,
    super.secureStorage,
  });

  @override
  Future<DriveSyncStatus> pullAndReconcile({
    bool isEmployeePortalOnly = false,
  }) async {
    throw StateError('simulated unexpected sync failure');
  }
}

class _GatedVerifyDriveSyncService extends GoogleDriveSyncService {
  final Completer<void> verifyGate;

  _GatedVerifyDriveSyncService({
    required super.db,
    required this.verifyGate,
    super.secureStorage,
  });

  @override
  Future<DriveSyncStatus> verifyCloudConnection({
    DriveSyncStatus? previousStatus,
    bool tokenAlreadyVerified = false,
  }) async {
    await verifyGate.future;
    final settings = db.getCompanySettings();
    return DriveSyncStatus(
      stage: DriveSyncStage.synced,
      lastSyncTime: previousStatus?.lastSyncTime ?? DateTime.now(),
      connectedGmail: settings.syncGmailAccount.trim(),
      isCloudApiVerified: false,
      isDriveFolderMirrored: true,
      cloudProfileId: settings.cloudProfileId,
      lastOperation: 'verify',
      message:
          'Google Drive klasörü doğrulandı (${settings.syncFolderPath})',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await HasibuSecurityService.saveGoogleOAuthToken('');
  });

  group('Doğrula & Kaydet hafif doğrulama ve durum güvenliği testleri', () {
    test(
      'saveGmailSyncAccount verifies writable folder without rewriting hasibu_sync.enc or calling Drive files API',
      () async {
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);

        final tempDir =
            await Directory.systemTemp.createTemp('hasibu_verify_folder_');
        addTearDown(() => tempDir.delete(recursive: true));

        final existingBackup = File(p.join(tempDir.path, 'hasibu_sync.enc'));
        const existingContent = '{"format":"hasibu_aes256_gcm_v1","probe":"preserve"}';
        await existingBackup.writeAsString(existingContent, flush: true);
        final expectedBytes = await existingBackup.length();

        int driveFilesCalls = 0;
        final dio = Dio()
          ..httpClientAdapter = _StubHttpClientAdapter((options, _) async {
            if (options.uri.path.contains('/drive/v3/files')) {
              driveFilesCalls++;
            }
            return ResponseBody.fromString(
              jsonEncode({'error': 'unexpected_network_call'}),
              500,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          });

        final syncService = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
          dio: dio,
        );

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            googleDriveSyncServiceProvider.overrideWithValue(syncService),
            googleAuthAdapterProvider.overrideWithValue(_FakeGoogleAuthAdapter()),
          ],
        );
        addTearDown(container.dispose);

        final res = await container
            .read(pdksDashboardProvider.notifier)
            .saveGmailSyncAccount(
              gmailAccount: 'baklavacisemsettinmerkez@gmail.com',
              syncFolderPath: tempDir.path,
            );

        expect(res.stage, equals(DriveSyncStage.synced));
        expect(res.isTrulySynced, isTrue);
        expect(res.isDriveFolderMirrored, isTrue);
        expect(res.isCloudApiVerified, isFalse);
        expect(res.lastOperation, equals('verify'));
        expect(res.syncedFilePath, equals(existingBackup.path));
        expect(res.syncedBytes, equals(expectedBytes));
        expect(driveFilesCalls, equals(0));
        expect(await existingBackup.readAsString(), equals(existingContent));

        final leftovers = tempDir
            .listSync()
            .where((e) => p.basename(e.path).startsWith('.hasibu_verify_'))
            .toList();
        expect(leftovers, isEmpty);

        final state = container.read(pdksDashboardProvider);
        expect(state.isCloudBusy, isFalse);
        expect(state.syncStatus.isTrulySynced, isTrue);
      },
    );

    test(
      'saveGmailSyncAccount verifies saved ya29 token via userinfo without Drive file download/upload',
      () async {
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);

        final tempDir =
            await Directory.systemTemp.createTemp('hasibu_verify_token_');
        addTearDown(() => tempDir.delete(recursive: true));
        // Dosya yolunu klasör olarak vererek klasör probe'unun deterministic şekilde başarısız olmasını sağla
        final blockingFile = File(p.join(tempDir.path, 'not_a_directory'));
        await blockingFile.writeAsString('block');

        int userInfoCalls = 0;
        int driveFilesCalls = 0;
        final dio = Dio()
          ..httpClientAdapter = _StubHttpClientAdapter((options, _) async {
            final path = options.uri.path;
            if (path.endsWith('/oauth2/v3/userinfo')) {
              userInfoCalls++;
              return ResponseBody.fromString(
                jsonEncode({
                  'email': 'verified@gmail.com',
                  'name': 'Verified User',
                }),
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }
            if (path.contains('/drive/v3/files')) {
              driveFilesCalls++;
            }
            return ResponseBody.fromString(
              jsonEncode({'error': 'unexpected_drive_file_call'}),
              500,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          });

        final syncService = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
          dio: dio,
        );
        await syncService.saveOAuthTokens(accessToken: 'ya29.saved-valid-token');

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            googleDriveSyncServiceProvider.overrideWithValue(syncService),
            googleAuthAdapterProvider.overrideWithValue(_FakeGoogleAuthAdapter()),
          ],
        );
        addTearDown(container.dispose);

        final res = await container
            .read(pdksDashboardProvider.notifier)
            .saveGmailSyncAccount(
              gmailAccount: '',
              syncFolderPath: blockingFile.path,
            );

        expect(res.stage, equals(DriveSyncStage.synced));
        expect(res.isTrulySynced, isTrue);
        expect(res.isCloudApiVerified, isTrue);
        expect(res.isDriveFolderMirrored, isFalse);
        expect(res.connectedGmail, equals('verified@gmail.com'));
        expect(res.lastOperation, equals('verify'));
        expect(userInfoCalls, equals(1));
        expect(driveFilesCalls, equals(0));

        final state = container.read(pdksDashboardProvider);
        expect(state.isCloudBusy, isFalse);
        expect(
          state.companySettings.syncGmailAccount,
          equals('verified@gmail.com'),
        );
      },
    );

    test(
      'syncWithGoogleDriveNow resets isCloudBusy and transitions to error when an unexpected exception occurs',
      () async {
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);

        final throwingSync = _ThrowingPullDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            googleDriveSyncServiceProvider.overrideWithValue(throwingSync),
            googleAuthAdapterProvider.overrideWithValue(_FakeGoogleAuthAdapter()),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(pdksDashboardProvider.notifier)
            .syncWithGoogleDriveNow();

        final st = container.read(pdksDashboardProvider);
        expect(st.isCloudBusy, isFalse);
        expect(st.syncStatus.stage, equals(DriveSyncStage.error));
        expect(
          st.syncStatus.message,
          contains('simulated unexpected sync failure'),
        );
      },
    );

    testWidgets(
      'CloudBackupCenterDialog shows Doğrulanıyor / Eşitleniyor during syncing and closes cleanly on Doğrula & Kaydet',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final tempDir =
            Directory.systemTemp.createTempSync('hasibu_verify_dialog_');
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });
        final targetSyncFolder = p.join(tempDir.path, 'CloudSync');

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(
                syncGmailAccount: 'baklavacisemsettinmerkez@gmail.com',
                syncFolderPath: targetSyncFolder,
              ),
        );

        final gate = Completer<void>();
        final gatedSync = _GatedVerifyDriveSyncService(
          db: db,
          verifyGate: gate,
          secureStorage: const FlutterSecureStorage(),
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hasibuDatabaseProvider.overrideWithValue(db),
              googleDriveSyncServiceProvider.overrideWithValue(gatedSync),
              googleAuthAdapterProvider
                  .overrideWithValue(_FakeGoogleAuthAdapter()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    container = ProviderScope.containerOf(context);
                    return Center(
                      child: FilledButton(
                        key: const ValueKey('open_verify_dialog_btn'),
                        onPressed: () =>
                            showCloudBackupCenterDialog(context, ref),
                        child: const Text('Aç'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open_verify_dialog_btn')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('OAuth 2.0 / Drive Doğrulanmadı'),
          findsOneWidget,
        );

        final verifySaveBtn =
            find.byKey(const ValueKey('btn_verify_and_save_cloud'));
        expect(verifySaveBtn, findsOneWidget);
        await tester.tap(verifySaveBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.textContaining('Doğrulanıyor / Eşitleniyor'),
          findsOneWidget,
        );
        expect(
          find.textContaining('OAuth 2.0 / Drive Doğrulanmadı'),
          findsNothing,
        );
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        gate.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(verifySaveBtn, findsNothing);
        final finalState = container.read(pdksDashboardProvider);
        expect(finalState.isCloudBusy, isFalse);
        expect(finalState.syncStatus.isTrulySynced, isTrue);
      },
    );
  });
}
