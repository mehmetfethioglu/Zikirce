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
import 'package:hasibu/features/pdks/presentation/screens/attendance_absence_report_view.dart';
import 'package:hasibu/features/pdks/presentation/screens/employee_portal_view.dart';
import 'package:hasibu/features/pdks/presentation/screens/leaves_and_reports_view.dart';
import 'package:hasibu/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FakePasswordRecoveryEmailGateway
    implements PasswordRecoveryEmailGateway {
  final List<String> sentCodes = <String>[];
  final List<String> sentTargets = <String>[];

  @override
  Future<PasswordResetEmailResult> sendVerificationCodeEmail({
    required String accessToken,
    required String recipientEmail,
    required String companyName,
    required String targetUsername,
    required String verificationCode,
    required int expiresInMinutes,
  }) async {
    sentCodes.add(verificationCode);
    sentTargets.add(targetUsername);
    return const PasswordResetEmailResult(success: true, message: 'OK');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('Tekil Otomatik Giriş & Birleşik Şifre Kurtarma Testleri', () {
    testWidgets(
      'Unified login hides role tabs and auto-detects AppUser, Employee (padded & unpadded), and root admin',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(
                companyName: 'AKAR TEST GIDA A.Ş.',
                adminPasswordUpdated: true,
                adminPassword:
                    HasibuSecurityService.hashPassword('YeniAdmin#2026'),
                syncGmailAccount: 'sirket@gmail.com',
              ),
        );

        final sync = GoogleDriveSyncService(
          db: db,
          secureStorage: const FlutterSecureStorage(),
        );
        await sync.saveOAuthTokens(accessToken: 'ya29.unified-token');

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
                  accessToken: 'ya29.unified-token',
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
          plainPassword: 'User#2026',
          role: AppUserRole.hrManager,
          allowedModules: const [HasibuModule.pdksHr],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const HasibuApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 1. Ayrı Yönetici / Personel sekmesi kesinlikle olmamalı
        expect(find.byType(SegmentedButton<UserRole>), findsNothing);
        expect(find.text('Kullanıcı / Yönetici'), findsNothing);
        expect(find.text('Personel Girişi'), findsNothing);
        expect(find.text('Kullanıcı Adı / Kart No'), findsOneWidget);

        // 2. Yetkili Kullanıcı (AppUserAccount) otomatik algılanmalı
        await tester.enterText(
          find.byKey(const ValueKey('login_username_field')),
          'mehmet_akar',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          'User#2026',
        );
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        var session = container.read(pdksDashboardProvider).authSession;
        expect(session.isAuthenticated, isTrue);
        expect(session.role, equals(UserRole.admin));
        expect(session.username, equals('mehmet_akar'));

        notifier.logout();
        await tester.pumpAndSettle();

        // 3. Sıfırsız kısa kart no ('64' -> '00064') ile personel girişi otomatik algılanmalı
        await tester.enterText(
          find.byKey(const ValueKey('login_username_field')),
          '64',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          '1234',
        );
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        session = container.read(pdksDashboardProvider).authSession;
        expect(session.isAuthenticated, isTrue);
        expect(session.role, equals(UserRole.employee));
        expect(session.employeeCardNo, equals('00064'));

        notifier.logout();
        await tester.pumpAndSettle();

        // 4. Başında sıfır olan kart no ('00064') ile de otomatik algılanmalı
        await tester.enterText(
          find.byKey(const ValueKey('login_username_field')),
          '00064',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          '1234',
        );
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();

        session = container.read(pdksDashboardProvider).authSession;
        expect(session.isAuthenticated, isTrue);
        expect(session.role, equals(UserRole.employee));
        expect(session.employeeCardNo, equals('00064'));

        notifier.logout();
        await tester.pumpAndSettle();

        // 5. Kök yönetici ('admin') de aynı formdan otomatik algılanmalı
        await tester.enterText(
          find.byKey(const ValueKey('login_username_field')),
          'admin',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          'YeniAdmin#2026',
        );
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();

        session = container.read(pdksDashboardProvider).authSession;
        expect(session.isAuthenticated, isTrue);
        expect(session.role, equals(UserRole.admin));
        expect(session.username, equals('admin'));

        notifier.logout();
        await tester.pumpAndSettle();

        // 6. Şifremi Unuttum dialogunda rol ChoiceChip olmamalı ve '64' kartının şifresini sıfırlayabilmeli
        await tester.tap(
          find.byKey(const ValueKey('login_forgot_password_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('forgot_password_dialog')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('forgot_password_dialog')),
            matching: find.byType(ChoiceChip),
          ),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(const ValueKey('forgot_username_field')),
          '64',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot_send_code_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeGateway.sentCodes, equals(['482913']));
        expect(fakeGateway.sentTargets, equals(['00064']));

        await tester.enterText(
          find.byKey(const ValueKey('forgot_otp_code_field')),
          '482913',
        );
        await tester.enterText(
          find.byKey(const ValueKey('forgot_new_password_field')),
          '567890',
        );
        await tester.enterText(
          find.byKey(const ValueKey('forgot_confirm_password_field')),
          '567890',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot_reset_submit_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('forgot_password_dialog')),
          findsNothing,
        );

        // Yeni personel parolası ('567890') ile birleşik ekrandan giriş yapılabilmeli
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          '567890',
        );
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();
        session = container.read(pdksDashboardProvider).authSession;
        expect(session.isAuthenticated, isTrue);
        expect(session.role, equals(UserRole.employee));
        expect(session.employeeCardNo, equals('00064'));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );
  });

  group('Sadeleştirilmiş Devam/Devamsızlık, İzin Geçişi & Özlük Dosyası', () {
    testWidgets(
      'AttendanceAbsenceReportView renders simplified summary strip & employee cards cleanly on Desktop and Mobile',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
        final notifier = container.read(pdksDashboardProvider.notifier);
        await notifier.updateCloudBackupSettings(autoCloudBackupEnabled: false);
        notifier.loginAsAdmin(username: 'admin', password: '123');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: AttendanceAbsenceReportView()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.text('Çok Günlü Devam / Devamsızlık Raporu'), findsOneWidget);
        expect(find.text('Toplam Devam (Gün)'), findsOneWidget);
        expect(find.text('Devamsızlık (Gün)'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('report_employee_card_01406')),
          findsOneWidget,
        );

        // Kart tıklanınca detay dialog açılmalı
        await tester.ensureVisible(
          find.byKey(const ValueKey('report_employee_card_01406')),
        );
        await tester.tap(
          find.byKey(const ValueKey('report_employee_card_01406')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('employee_detail_tab_selector')),
          findsOneWidget,
        );
        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();

        // Mobil 390x844 taşma testi
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );

    testWidgets(
      'LeavesAndReportsSettingsView supports portal-style sidebar search, prev/next, leave creation, and mobile bottom sheet',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
        final notifier = container.read(pdksDashboardProvider.notifier);
        await notifier.updateCloudBackupSettings(autoCloudBackupEnabled: false);
        notifier.loginAsAdmin(username: 'admin', password: '123');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: LeavesAndReportsSettingsView()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 1. Masaüstü sol aramalı rehberde arama yap ve '01406' seç
        expect(
          find.byKey(const ValueKey('leaves_employee_search_field')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('leaves_employee_search_field')),
          '01406',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('leaves_employee_tile_01406')),
        );
        await tester.pumpAndSettle();
        expect(find.text('ABDULLAH YILDIZ'), findsWidgets);

        // Aramayı temizleyip ileri tuşuyla başka personele geç ve sonra tekrar 01406 seç
        await tester.enterText(
          find.byKey(const ValueKey('leaves_employee_search_field')),
          '',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('leaves_employee_next_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('leaves_employee_search_field')),
          '01406',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('leaves_employee_tile_01406')),
        );
        await tester.pumpAndSettle();

        // Rapor türü seç ve izin kaydı ekle
        await tester.tap(
          find.byKey(const ValueKey('leaves_type_saglikRaporu')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('leaves_save_record_button')),
        );
        await tester.tap(
          find.byKey(const ValueKey('leaves_save_record_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('ABDULLAH YILDIZ • Sağlık Raporu'),
          findsWidgets,
        );

        // Kapsam filtreleri ('Seçili Personel' / 'Tüm Personel')
        await tester.tap(find.byKey(const ValueKey('leaves_scope_all')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('leaves_scope_selected')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 2. Mobil görünüm (390x844): yapışkan seçici + bottom-sheet personel seçimi
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(
          find.byKey(const ValueKey('leaves_employee_picker_button')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('leaves_employee_picker_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('leaves_employee_search_field')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('leaves_employee_search_field')),
          '00064',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('leaves_employee_tile_00064')),
        );
        await tester.pumpAndSettle();
        expect(find.text('MEHMET SİNAN CENAN'), findsWidgets);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );

    testWidgets(
      'Portal KPI card opens simplified EmployeeDossierPanel where filters, quick upload dialog, and delete work cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
        final notifier = container.read(pdksDashboardProvider.notifier);
        await notifier.updateCloudBackupSettings(autoCloudBackupEnabled: false);
        notifier.loginAsEmployee(cardNo: '01406', pin: '1234');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: EmployeeSelfServicePortalView()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 1. Özlük Dosyası Durumu KPI kartına tıklayınca Özlük sekmesi doğrudan açılmalı
        await tester.tap(find.byKey(const ValueKey('portal_dossier_kpi_card')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(
          find.byKey(const ValueKey('dossier_add_document_button')),
          findsOneWidget,
        );
        expect(find.text('2 / 6 Zorunlu Evrak Tamam'), findsOneWidget);

        // 2. 'Eksikler' filtresi eksik zorunlu evrakları gösterir, yüklüleri gizler
        await tester.tap(find.byKey(const ValueKey('dossier_filter_missing')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('dossier_quick_upload_adliSicilKaydi')),
          findsOneWidget,
        );
        expect(find.text('T.C. Kimlik Kartı Dijital Kopyası'), findsNothing);

        // 3. Eksik evrak satırındaki 'Yükle' butonu sade evrak ekleme modalını ön seçimli açar
        await tester.tap(
          find.byKey(const ValueKey('dossier_quick_upload_adliSicilKaydi')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('dossier_dialog_save_button')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('dossier_dialog_save_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('3 / 6 Zorunlu Evrak Tamam'), findsOneWidget);

        // 4. 'Yüklü' filtresine geç ve yeni eklenen evrakı sil
        await tester.tap(find.byKey(const ValueKey('dossier_filter_uploaded')));
        await tester.pumpAndSettle();
        expect(find.text('Adli Sicil / Sabıka Kaydı'), findsWidgets);

        final uploadedDocs = container
            .read(pdksDashboardProvider)
            .documentsForEmployee(1620);
        final addedDoc = uploadedDocs.firstWhere(
          (d) => d.category == PersonnelDocumentCategory.adliSicilKaydi,
        );
        await tester.tap(
          find.byKey(ValueKey('dossier_delete_${addedDoc.id}')),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 / 6 Zorunlu Evrak Tamam'), findsOneWidget);

        // 5. Mobil görünümde (390x844) dialog & 'Evrak Ekle' modalı taşmasız açılmalı
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(const ValueKey('dossier_add_document_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('dossier_dialog_save_button')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('İptal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );
  });
}
