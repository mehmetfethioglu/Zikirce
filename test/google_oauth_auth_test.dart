import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/services/google_auth_adapter.dart';
import 'package:hasibu/core/services/google_drive_sync_service.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:path/path.dart' as p;

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
  bool signOutCalled = false;
  int signInCallCount = 0;

  _FakeGoogleAuthAdapter({
    required this.nextResult,
  });

  @override
  bool get isNativePlatform => true;

  @override
  Future<BrowserGoogleSignInResult> signIn({
    String? loginHintEmail,
    String? customClientId,
    String? customClientSecret,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    signInCallCount++;
    return nextResult;
  }

  @override
  Future<String?> refreshAccessTokenSilently() async => null;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google OAuth 2.0 (ihasibu) Yapılandırma & Yetkilendirme Testleri', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test(
        'discoverGoogleClientCredentialsInDirectories skips unrelated client_secret JSON and matches expectedClientId',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('hasibu_oauth_json_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final matchingFile = File(p.join(tempDir.path, 'client_secret_match.json'));
      await matchingFile.writeAsString(
        jsonEncode({
          'installed': {
            'client_id': GoogleDriveSyncService.defaultIhasibuClientId,
            'client_secret': 'test-matched-desktop-secret',
          },
        }),
      );

      // Yeni tarihli ancak başka bir projeye ait dosya yok sayılmalı
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final unrelatedFile =
          File(p.join(tempDir.path, 'client_secret_other_project.json'));
      await unrelatedFile.writeAsString(
        jsonEncode({
          'installed': {
            'client_id': '999999999999-other.apps.googleusercontent.com',
            'client_secret': 'test-unrelated-secret',
          },
        }),
      );

      final matched =
          GoogleDriveSyncService.discoverGoogleClientCredentialsInDirectories(
        [tempDir],
        expectedClientId: GoogleDriveSyncService.defaultIhasibuClientId,
      );
      expect(matched, isNotNull);
      expect(
        matched!.clientId,
        equals(GoogleDriveSyncService.defaultIhasibuClientId),
      );
      expect(matched.clientSecret, equals('test-matched-desktop-secret'));

      final missing =
          GoogleDriveSyncService.discoverGoogleClientCredentialsInDirectories(
        [tempDir],
        expectedClientId: '111111111111-missing.apps.googleusercontent.com',
      );
      expect(missing, isNull);
    });

    test(
        'exchangeAuthorizationCodeForToken & refreshAccessToken persist and refresh OAuth tokens',
        () async {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      final recordedBodies = <String>[];
      final dio = Dio();
      dio.httpClientAdapter = _StubHttpClientAdapter((options, bodyText) async {
        recordedBodies.add('${options.uri.path}|${options.data}');
        if (options.data is Map &&
            (options.data as Map)['grant_type'] == 'authorization_code') {
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'ya29.initial-access-token',
              'refresh_token': '1//initial-refresh-token',
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString(
          jsonEncode({
            'access_token': 'ya29.refreshed-access-token',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
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
      await syncService.saveOAuthClientCredentials(
        clientId: GoogleDriveSyncService.defaultIhasibuClientId,
        clientSecret: 'test-client-secret',
      );

      final exchange = await syncService.exchangeAuthorizationCodeForToken(
        code: '4/test-auth-code',
        clientId: GoogleDriveSyncService.defaultIhasibuClientId,
        clientSecret: 'test-client-secret',
        codeVerifier: 'test-verifier',
        redirectUri: 'http://127.0.0.1:43821/oauth2callback',
      );

      expect(exchange.error, isEmpty);
      expect(exchange.accessToken, equals('ya29.initial-access-token'));
      expect(exchange.refreshToken, equals('1//initial-refresh-token'));
      expect(
        await syncService.getAccessToken(),
        equals('ya29.initial-access-token'),
      );

      final refreshed = await syncService.refreshAccessToken();
      expect(refreshed, equals('ya29.refreshed-access-token'));
      expect(
        await syncService.getAccessToken(),
        equals('ya29.refreshed-access-token'),
      );
      expect(recordedBodies.length, equals(2));
    });

    test(
        'pushToCloud automatically refreshes expired access token on HTTP 401 and retries upload',
        () async {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      final authHeadersSeen = <String>[];
      final dio = Dio();
      dio.httpClientAdapter = _StubHttpClientAdapter((options, _) async {
        final path = options.uri.path;
        if (path == '/token') {
          return ResponseBody.fromString(
            jsonEncode({'access_token': 'ya29.fresh-after-401'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        final authHeader =
            (options.headers[HttpHeaders.authorizationHeader] ?? '').toString();
        authHeadersSeen.add(authHeader);

        if (authHeader == 'Bearer ya29.expired-token') {
          return ResponseBody.fromString(
            jsonEncode({'error': 'invalid_token'}),
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        if (options.method == 'GET') {
          return ResponseBody.fromString(
            jsonEncode({'files': <dynamic>[]}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        return ResponseBody.fromString(
          jsonEncode({'id': 'drive-file-1'}),
          200,
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
      await syncService.saveOAuthClientCredentials(
        clientId: GoogleDriveSyncService.defaultIhasibuClientId,
        clientSecret: 'test-client-secret',
      );
      await syncService.saveOAuthTokens(
        accessToken: 'ya29.expired-token',
        refreshToken: '1//valid-refresh-token',
      );

      final status = await syncService.pushToCloud(force: true);
      expect(status.stage, equals(DriveSyncStage.synced));
      expect(status.isCloudApiVerified, isTrue);
      expect(authHeadersSeen, contains('Bearer ya29.expired-token'));
      expect(authHeadersSeen, contains('Bearer ya29.fresh-after-401'));
    });

    test(
        'PdksDashboardNotifier authenticates Google session via GoogleAuthAdapter and calls signOut on disconnect',
        () async {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      final tempSyncDir =
          await Directory.systemTemp.createTemp('hasibu_oauth_sync_test_');
      addTearDown(() => tempSyncDir.delete(recursive: true));

      final stubDio = Dio()
        ..httpClientAdapter = _StubHttpClientAdapter((options, _) async {
          if (options.method == 'GET') {
            return ResponseBody.fromString(
              jsonEncode({'files': <dynamic>[]}),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'id': 'drive-mock-file'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
      final syncService = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
        dio: stubDio,
      );

      final fakeAdapter = _FakeGoogleAuthAdapter(
        nextResult: const BrowserGoogleSignInResult(
          success: true,
          accessToken: 'ya29.native-mobile-token',
          email: 'akarbilisimteknolojileri@gmail.com',
          displayName: 'Mehmet',
          message:
              'Google OAuth 2.0 oturumu açıldı (akarbilisimteknolojileri@gmail.com).',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(syncService),
          googleAuthAdapterProvider.overrideWithValue(fakeAdapter),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pdksDashboardProvider.notifier);
      final signInResult = await notifier.signInWithGoogleViaBrowser(
        syncFolderPath: tempSyncDir.path,
        authenticateAppSession: true,
      );

      expect(signInResult.success, isTrue);
      expect(fakeAdapter.signInCallCount, equals(1));

      final authedState = container.read(pdksDashboardProvider);
      expect(authedState.authSession.isAuthenticated, isTrue);
      expect(authedState.authSession.role, equals(UserRole.admin));
      expect(
        authedState.companySettings.syncGmailAccount,
        equals('akarbilisimteknolojileri@gmail.com'),
      );
      expect(authedState.syncStatus.isCloudApiVerified, isTrue);

      await notifier.disconnectGmailSyncAccount();
      expect(fakeAdapter.signOutCalled, isTrue);
      expect(
        container.read(pdksDashboardProvider).companySettings.syncGmailAccount,
        isEmpty,
      );
    });

    test(
        'getSavedOAuthClientId and getSavedOAuthClientSecret purge foreign-project Zikirce OAuth entries while preserving workspace key',
        () async {
      const storage = FlutterSecureStorage();
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'hasibu_google_oauth_client_id':
            '497197680323-cg9ra0da0iavgjlb47tlmnr1aqgrgq6u.apps.googleusercontent.com',
        'hasibu_google_oauth_client_secret': 'stale-foreign-secret',
        'hasibu_workspace_sync_key_v1': 'keep-my-workspace-key',
      });

      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);
      final syncService = GoogleDriveSyncService(
        db: db,
        secureStorage: storage,
      );

      final resolvedSecret = await syncService.getSavedOAuthClientSecret();
      final resolvedClientId = await syncService.getSavedOAuthClientId();

      expect(
        resolvedClientId,
        equals(GoogleDriveSyncService.defaultIhasibuClientId),
      );
      expect(resolvedSecret, isNot(equals('stale-foreign-secret')));
      expect(
        await storage.read(key: 'hasibu_google_oauth_client_id'),
        isNull,
      );
      expect(
        await storage.read(key: 'hasibu_google_oauth_client_secret'),
        isNull,
      );
      expect(
        await storage.read(key: 'hasibu_workspace_sync_key_v1'),
        equals('keep-my-workspace-key'),
      );
    });
  });
}
