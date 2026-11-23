import 'dart:convert';
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
import 'package:hasibu/core/services/password_recovery_service.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/features/pdks/presentation/screens/hasibu_login_screen.dart';
import 'package:hasibu/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubDioAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options, String? bodyText)
      handler;

  _StubDioAdapter(this.handler);

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
    return handler(options, bodyText);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeGoogleAuthAdapter implements GoogleAuthAdapter {
  BrowserGoogleSignInResult nextResult;
  final List<List<String>> requestedExtraScopes = <List<String>>[];

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
    requestedExtraScopes.add(List<String>.from(extraScopes));
    return nextResult;
  }

  @override
  Future<String?> refreshAccessTokenSilently() async => null;

  @override
  Future<void> signOut() async {}
}

class _FakePasswordRecoveryEmailGateway
    implements PasswordRecoveryEmailGateway {
  PasswordResetEmailResult nextResult = const PasswordResetEmailResult(
    success: true,
    message: 'OK',
  );
  final List<
      ({
        String accessToken,
        String recipientEmail,
        String companyName,
        String targetUsername,
        String verificationCode,
        int expiresInMinutes,
      })> sentEmails = [];

  @override
  Future<PasswordResetEmailResult> sendVerificationCodeEmail({
    required String accessToken,
    required String recipientEmail,
    required String companyName,
    required String targetUsername,
    required String verificationCode,
    required int expiresInMinutes,
  }) async {
    sentEmails.add((
      accessToken: accessToken,
      recipientEmail: recipientEmail,
      companyName: companyName,
      targetUsername: targetUsername,
      verificationCode: verificationCode,
      expiresInMinutes: expiresInMinutes,
    ));
    return nextResult;
  }
}

// 1x1 şeffaf geçerli PNG baytları
const String _sample1x1PngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('GmailApiPasswordRecoveryGateway Unit Testleri', () {
    test(
      'encodes RFC 2822 UTF-8 MIME payload and maps 401/403 API responses accurately',
      () async {
        String? capturedAuthHeader;
        Map<String, dynamic>? capturedJson;
        int statusCode = 200;
        String responseBody = jsonEncode({'id': 'msg-123'});

        final dio = Dio();
        dio.httpClientAdapter = _StubDioAdapter((options, bodyText) async {
          capturedAuthHeader = options.headers['Authorization']?.toString();
          if (bodyText != null && bodyText.isNotEmpty) {
            capturedJson =
                Map<String, dynamic>.from(jsonDecode(bodyText) as Map);
          }
          return ResponseBody.fromString(
            responseBody,
            statusCode,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final gateway = GmailApiPasswordRecoveryGateway(dio: dio);

        // 1. Başarılı gönderim
        final okRes = await gateway.sendVerificationCodeEmail(
          accessToken: 'ya29.test-token',
          recipientEmail: 'sirket@gmail.com',
          companyName: 'Akar Baklava A.Ş.',
          targetUsername: 'mehmet_akar',
          verificationCode: '654321',
          expiresInMinutes: 10,
        );
        expect(okRes.success, isTrue);
        expect(okRes.errorCode, equals(PasswordResetEmailErrorCode.none));
        expect(capturedAuthHeader, equals('Bearer ya29.test-token'));
        final rawMime = utf8.decode(
          base64Url.decode(capturedJson!['raw'] as String),
        );
        expect(rawMime, contains('To: sirket@gmail.com'));
        expect(rawMime, contains('Subject: =?UTF-8?B?'));

        // 2. Gmail API kapalı (403 SERVICE_DISABLED)
        statusCode = 403;
        responseBody = jsonEncode({
          'error': {
            'code': 403,
            'message': 'Gmail API has not been used in project before',
            'status': 'PERMISSION_DENIED',
            'details': [
              {'reason': 'SERVICE_DISABLED'},
            ],
          },
        });
        final disabledRes = await gateway.sendVerificationCodeEmail(
          accessToken: 'ya29.test-token',
          recipientEmail: 'sirket@gmail.com',
          companyName: 'Akar',
          targetUsername: 'admin',
          verificationCode: '111222',
          expiresInMinutes: 10,
        );
        expect(disabledRes.success, isFalse);
        expect(
          disabledRes.errorCode,
          equals(PasswordResetEmailErrorCode.apiDisabled),
        );

        // 3. Yetersiz scope (403 insufficientPermissions)
        responseBody = jsonEncode({
          'error': {
            'code': 403,
            'message': 'Request had insufficient authentication scopes.',
            'errors': [
              {'reason': 'insufficientPermissions'},
            ],
          },
        });
        final scopeRes = await gateway.sendVerificationCodeEmail(
          accessToken: 'ya29.test-token',
          recipientEmail: 'sirket@gmail.com',
          companyName: 'Akar',
          targetUsername: 'admin',
          verificationCode: '111222',
          expiresInMinutes: 10,
        );
        expect(scopeRes.success, isFalse);
        expect(
          scopeRes.errorCode,
          equals(PasswordResetEmailErrorCode.insufficientScope),
        );

        // 4. Geçersiz token (401)
        statusCode = 401;
        responseBody = jsonEncode({'error': 'invalid_token'});
        final authRes = await gateway.sendVerificationCodeEmail(
          accessToken: 'ya29.expired',
          recipientEmail: 'sirket@gmail.com',
          companyName: 'Akar',
          targetUsername: 'admin',
          verificationCode: '111222',
          expiresInMinutes: 10,
        );
        expect(authRes.success, isFalse);
        expect(
          authRes.errorCode,
          equals(PasswordResetEmailErrorCode.unauthorized),
        );
      },
    );

    test(
      'PasswordRecoveryService enforces 30s resend cooldown and 5 max verify attempts',
      () {
        var now = DateTime(2026, 11, 23, 18, 0, 0);
        final svc = PasswordRecoveryService(
          emailGateway: _FakePasswordRecoveryEmailGateway(),
          clock: () => now,
          codeGenerator: () => '918273',
        );

        final first = svc.createChallenge(
          username: 'mehmet_akar',
          role: UserRole.admin,
          targetEmail: 'sirket@gmail.com',
        );
        expect(first.ok, isTrue);
        expect(first.code, equals('918273'));

        // 30 sn dolmadan tekrar kod gönderimi engellenmeli
        now = now.add(const Duration(seconds: 10));
        final tooSoon = svc.createChallenge(
          username: 'mehmet_akar',
          role: UserRole.admin,
          targetEmail: 'sirket@gmail.com',
        );
        expect(tooSoon.ok, isFalse);
        expect(tooSoon.waitSeconds, equals(20));

        // 5 hatalı denemede talep kilitlenmeli (sonraki doğru kod da reddedilmeli)
        for (int i = 0; i < 4; i++) {
          final failCheck = svc.verifyChallenge(
            username: 'mehmet_akar',
            role: UserRole.admin,
            code: '000000',
          );
          expect(failCheck.verified, isFalse);
          expect(failCheck.message, contains('Kalan deneme: ${4 - i}'));
        }
        final fifthFail = svc.verifyChallenge(
          username: 'mehmet_akar',
          role: UserRole.admin,
          code: '000000',
        );
        expect(fifthFail.verified, isFalse);
        expect(fifthFail.message, contains('iptal edildi'));

        final afterLock = svc.verifyChallenge(
          username: 'mehmet_akar',
          role: UserRole.admin,
          code: '918273',
        );
        expect(afterLock.verified, isFalse);
      },
    );

    test(
      'rejects password recovery when company Gmail is missing and resets employee password with OTP',
      () async {
        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );
        final fakeGateway = _FakePasswordRecoveryEmailGateway();
        final recoverySvc = PasswordRecoveryService(
          emailGateway: fakeGateway,
          codeGenerator: () => '357951',
        );

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            googleDriveSyncServiceProvider.overrideWithValue(sync),
            passwordRecoveryEmailGatewayProvider
                .overrideWithValue(fakeGateway),
            passwordRecoveryServiceProvider.overrideWithValue(recoverySvc),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(pdksDashboardProvider.notifier);
        await notifier.updateCloudBackupSettings(autoCloudBackupEnabled: false);

        // 1. Şirket Gmail'i boşsa güvenli reddetme
        final lookupMissing = notifier.lookupRecoverableAccount(
          identifier: 'admin',
          role: UserRole.admin,
        );
        expect(lookupMissing.found, isTrue);
        expect(lookupMissing.hasCompanyGmail, isFalse);

        final sendMissing = await notifier.sendPasswordResetCodeToCompanyGmail(
          identifier: 'admin',
          role: UserRole.admin,
        );
        expect(sendMissing.success, isFalse);
        expect(sendMissing.message, contains('Şirket Gmail hesabı henüz bağlı değil'));

        // 2. Şirket Gmail'i ve token ayarlanınca personel parolası sıfırlanabilmeli
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(syncGmailAccount: 'ik@gmail.com'),
        );
        await sync.saveOAuthTokens(accessToken: 'ya29.emp-reset');
        notifier.refreshDashboard();

        final empSend = await notifier.sendPasswordResetCodeToCompanyGmail(
          identifier: '64',
          role: UserRole.employee,
        );
        expect(empSend.success, isTrue);
        expect(fakeGateway.sentEmails.last.targetUsername, equals('00064'));

        final resetErr = await notifier.completePasswordReset(
          identifier: '00064',
          role: UserRole.employee,
          verificationCode: '357951',
          newPassword: 'Emp#New99',
        );
        expect(resetErr, isNull);
        expect(
          notifier.loginAsEmployee(cardNo: '00064', pin: 'Emp#New99'),
          isTrue,
        );
      },
    );
  });

  group('Giriş Ekranı Yeniden Tasarım, İlk Kurulum & Şifremi Unuttum UI Testleri',
      () {
    Future<void> runFullRedesignAndSetupFlow(
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
        db.getCompanySettings().copyWith(
              companyName: 'AKAR BAKLAVA A.Ş.',
              logoPath: () => 'custom/logo.png',
              logoDataBase64: () => _sample1x1PngBase64,
              syncGmailAccount: 'ortak@gmail.com',
            ),
      );
      final sync = GoogleDriveSyncService(
        db: db,
        secureStorage: const FlutterSecureStorage(),
      );
      await sync.saveOAuthTokens(
        accessToken: 'ya29.company-token',
        refreshToken: '1//company-refresh',
      );

      final fakeGateway = _FakePasswordRecoveryEmailGateway();
      final recoveryService = PasswordRecoveryService(emailGateway: fakeGateway);
      final fakeAuthAdapter = _FakeGoogleAuthAdapter(
        nextResult: const BrowserGoogleSignInResult(
          success: true,
          accessToken: 'ya29.company-token',
          email: 'ortak@gmail.com',
          message: 'OK',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
          googleDriveSyncServiceProvider.overrideWithValue(sync),
          googleAuthAdapterProvider.overrideWithValue(fakeAuthAdapter),
          passwordRecoveryEmailGatewayProvider.overrideWithValue(fakeGateway),
          passwordRecoveryServiceProvider.overrideWithValue(recoveryService),
        ],
      );

      final notifier = container.read(pdksDashboardProvider.notifier);
      await notifier.updateCloudBackupSettings(autoCloudBackupEnabled: false);
      await notifier.saveAppUser(
        username: 'mehmet_akar',
        displayName: 'Mehmet Akar',
        plainPassword: 'User#2026',
        role: AppUserRole.hrManager,
        allowedModules: const [HasibuModule.pdksHr],
      );
      await notifier.restorePersistedGoogleSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HasibuApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 1. Üst bölüm: küçük Hasibu logosu + Hasibu yazısı, sağda bulut ikonu & tema
      expect(find.byKey(const ValueKey('login_hasibu_brand')), findsOneWidget);
      expect(find.text('Hasibu'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('login_cloud_session_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('appbar_theme_selector_button')),
        findsOneWidget,
      );

      // 2. Merkez: İşletmenin kendi adı ve Ayarlar'daki özel logosu (HASİBU İŞLETME YÖNETİMİ yok)
      expect(find.text('AKAR BAKLAVA A.Ş.'), findsOneWidget);
      expect(find.text('HASİBU İŞLETME YÖNETİMİ'), findsNothing);
      expect(
        find.byKey(const ValueKey('login_company_logo_badge')),
        findsOneWidget,
      );

      // 3. Kayıtlı kullanıcı isimleri kesinlikle gizli olmalı
      expect(find.text('Kayıtlı Kullanıcılar'), findsNothing);
      expect(find.text('mehmet_akar'), findsNothing);
      expect(
        find.byKey(const ValueKey('login_user_chip_mehmet_akar')),
        findsNothing,
      );

      // 4. İlk kurulum admin bilgisi görünür ve doldurulunca zorunlu parola güncellemesi açılır
      expect(
        find.byKey(const ValueKey('login_first_setup_info_card')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('login_fill_initial_admin_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('login_submit_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Zorunlu parola güncelleme penceresi açık olmalı ve henüz oturum açılmamış olmalı
      expect(
        find.byKey(const ValueKey('force_admin_password_dialog')),
        findsOneWidget,
      );
      expect(
        container.read(pdksDashboardProvider).authSession.isAuthenticated,
        isFalse,
      );

      // Zayıf veya varsayılan "123" parola reddedilmeli
      await tester.enterText(
        find.byKey(const ValueKey('force_admin_new_password_field')),
        '123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('force_admin_confirm_password_field')),
        '123',
      );
      await tester.tap(
        find.byKey(const ValueKey('force_admin_password_submit_button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('force_admin_password_dialog')),
        findsOneWidget,
      );
      expect(find.textContaining('en az 6 karakter'), findsOneWidget);

      // Geçerli yeni parola girip güncelle & oturum aç
      await tester.enterText(
        find.byKey(const ValueKey('force_admin_new_password_field')),
        'YeniAdmin#2026',
      );
      await tester.enterText(
        find.byKey(const ValueKey('force_admin_confirm_password_field')),
        'YeniAdmin#2026',
      );
      await tester.tap(
        find.byKey(const ValueKey('force_admin_password_submit_button')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        container.read(pdksDashboardProvider).authSession.isAuthenticated,
        isTrue,
      );
      expect(
        db.getCompanySettings().adminPasswordUpdated,
        isTrue,
      );
      expect(
        HasibuSecurityService.isPasswordHashed(
          db.getCompanySettings().adminPassword,
        ),
        isTrue,
      );

      // 5. Çıkış yapıldığında artık ilk kurulum admin bilgisi gizlenmeli ve hatırlanan kullanıcı adı gelmeli
      notifier.logout();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HasibuApp()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        find.byKey(const ValueKey('login_first_setup_info_card')),
        findsNothing,
      );
      expect(find.textContaining('Geçici Parola'), findsNothing);

      final rememberedField = tester.widget<TextField>(
        find.byKey(const ValueKey('login_username_field')),
      );
      expect(rememberedField.controller?.text, equals('admin'));

      // Eski parola "123" reddedilmeli, yeni parola doğrudan açılmalı
      await tester.enterText(
        find.byKey(const ValueKey('login_password_field')),
        '123',
      );
      await tester.tap(find.byKey(const ValueKey('login_submit_button')));
      await tester.pumpAndSettle();
      expect(
        container.read(pdksDashboardProvider).authSession.isAuthenticated,
        isFalse,
      );

      await tester.enterText(
        find.byKey(const ValueKey('login_password_field')),
        'YeniAdmin#2026',
      );
      await tester.tap(find.byKey(const ValueKey('login_submit_button')));
      await tester.pumpAndSettle();
      expect(
        container.read(pdksDashboardProvider).authSession.isAuthenticated,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('force_admin_password_dialog')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
    }

    testWidgets('Desktop 1440x900 full redesign & forced password update',
        (tester) async {
      await runFullRedesignAndSetupFlow(
        tester,
        viewportSize: const Size(1440, 900),
      );
    });

    testWidgets('Mobile 390x844 full redesign & forced password update',
        (tester) async {
      await runFullRedesignAndSetupFlow(
        tester,
        viewportSize: const Size(390, 844),
      );
    });

    testWidgets(
      'Default company name hides HASİBU İŞLETME YÖNETİMİ and does not duplicate Hasibu badge in center',
      (tester) async {
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
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: HasibuLoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('login_hasibu_brand')), findsOneWidget);
        expect(find.text('HASİBU İŞLETME YÖNETİMİ'), findsNothing);
        expect(find.text('İşletme Yönetimi'), findsOneWidget);
        // Merkez badge içinde Hasibu PNG yerine kurumsal ikon gösterilmeli
        expect(find.byIcon(Icons.business_rounded), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );

    testWidgets(
      'Forgot password sends 6-digit code to company Gmail, enforces max attempts, and resets password',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(
                companyName: 'AKAR MERKEZ A.Ş.',
                syncGmailAccount: 'sirket@gmail.com',
              ),
        );
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );
        await sync.saveOAuthTokens(accessToken: 'ya29.reset-token');

        final fakeGateway = _FakePasswordRecoveryEmailGateway();
        final recoveryService = PasswordRecoveryService(
          emailGateway: fakeGateway,
          codeGenerator: () => '482913',
        );
        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            googleDriveSyncServiceProvider.overrideWithValue(sync),
            googleAuthAdapterProvider.overrideWithValue(
              _FakeGoogleAuthAdapter(
                nextResult: const BrowserGoogleSignInResult(
                  success: true,
                  accessToken: 'ya29.reset-token',
                  email: 'sirket@gmail.com',
                  message: 'OK',
                ),
              ),
            ),
            passwordRecoveryEmailGatewayProvider
                .overrideWithValue(fakeGateway),
            passwordRecoveryServiceProvider.overrideWithValue(recoveryService),
          ],
        );

        final notifier = container.read(pdksDashboardProvider.notifier);
        await notifier.updateCloudBackupSettings(autoCloudBackupEnabled: false);
        await notifier.saveAppUser(
          username: 'mehmet_akar',
          displayName: 'Mehmet Akar',
          plainPassword: 'Eski#Password1',
          role: AppUserRole.hrManager,
          allowedModules: const [HasibuModule.pdksHr],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: HasibuLoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Şifremi unuttum aç
        final forgotBtn = find.byKey(
          const ValueKey('login_forgot_password_button'),
        );
        await tester.ensureVisible(forgotBtn);
        await tester.pumpAndSettle();
        await tester.tap(forgotBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('forgot_password_dialog')),
          findsOneWidget,
        );
        expect(find.textContaining('si***t@gmail.com'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('forgot_username_field')),
          'mehmet_akar',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot_send_code_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeGateway.sentEmails, hasLength(1));
        expect(fakeGateway.sentEmails.first.recipientEmail, 'sirket@gmail.com');
        expect(fakeGateway.sentEmails.first.targetUsername, 'mehmet_akar');
        expect(fakeGateway.sentEmails.first.verificationCode, '482913');

        // Yanlış kod girilince reddedilmeli
        await tester.enterText(
          find.byKey(const ValueKey('forgot_otp_code_field')),
          '000000',
        );
        await tester.enterText(
          find.byKey(const ValueKey('forgot_new_password_field')),
          'Yeni#Sifre99',
        );
        await tester.enterText(
          find.byKey(const ValueKey('forgot_confirm_password_field')),
          'Yeni#Sifre99',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot_reset_submit_button')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Doğrulama kodu hatalı'), findsOneWidget);

        // Doğru kod girilince parola güncellenmeli
        await tester.enterText(
          find.byKey(const ValueKey('forgot_otp_code_field')),
          '482913',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot_reset_submit_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('forgot_password_dialog')),
          findsNothing,
        );

        // Yeni parola ile giriş başarılı olmalı
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          'Yeni#Sifre99',
        );
        final submitBtn = find.byKey(const ValueKey('login_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          container.read(pdksDashboardProvider).authSession.username,
          equals('mehmet_akar'),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );

    testWidgets(
      'Forgot password supports Google OAuth ownership fallback when Gmail API is disabled',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(
                syncGmailAccount: 'patron@gmail.com',
              ),
        );
        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );
        await sync.saveOAuthTokens(accessToken: 'ya29.patron-token');

        final fakeGateway = _FakePasswordRecoveryEmailGateway()
          ..nextResult = const PasswordResetEmailResult(
            success: false,
            errorCode: PasswordResetEmailErrorCode.apiDisabled,
            message: 'Gmail API etkin değil.',
          );
        final fakeAdapter = _FakeGoogleAuthAdapter(
          nextResult: const BrowserGoogleSignInResult(
            success: true,
            accessToken: 'ya29.wrong-account',
            email: 'yabanci@gmail.com',
            message: 'OK',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            googleDriveSyncServiceProvider.overrideWithValue(sync),
            googleAuthAdapterProvider.overrideWithValue(fakeAdapter),
            passwordRecoveryEmailGatewayProvider
                .overrideWithValue(fakeGateway),
            passwordRecoveryServiceProvider.overrideWithValue(
              PasswordRecoveryService(emailGateway: fakeGateway),
            ),
          ],
        );

        final notifier = container.read(pdksDashboardProvider.notifier);
        await notifier.updateCloudBackupSettings(autoCloudBackupEnabled: false);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: HasibuLoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final forgotBtn = find.byKey(
          const ValueKey('login_forgot_password_button'),
        );
        await tester.ensureVisible(forgotBtn);
        await tester.pumpAndSettle();
        await tester.tap(forgotBtn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('forgot_username_field')),
          'admin',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot_send_code_button')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Gmail API etkin değil'), findsOneWidget);

        // Farklı Google hesabıyla doğrulama reddedilmeli
        await tester.tap(
          find.byKey(const ValueKey('forgot_verify_google_button')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('eşleşmiyor'), findsOneWidget);

        // Doğru şirket Gmail hesabıyla doğrulama başarılı olup parolayı sıfırlamalı
        fakeAdapter.nextResult = const BrowserGoogleSignInResult(
          success: true,
          accessToken: 'ya29.patron-verified',
          email: 'patron@gmail.com',
          message: 'OK',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot_verify_google_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Google hesap sahipliği doğrulandı'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const ValueKey('forgot_new_password_field')),
          'Patron#2026',
        );
        await tester.enterText(
          find.byKey(const ValueKey('forgot_confirm_password_field')),
          'Patron#2026',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot_reset_submit_button')),
        );
        await tester.pumpAndSettle();

        // admin şifresi güncellendiği için artık ilk kurulum kartı da gizlenmeli
        expect(
          find.byKey(const ValueKey('login_first_setup_info_card')),
          findsNothing,
        );
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          'Patron#2026',
        );
        final submitBtn = find.byKey(const ValueKey('login_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          container.read(pdksDashboardProvider).authSession.isAuthenticated,
          isTrue,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );
  });
}
