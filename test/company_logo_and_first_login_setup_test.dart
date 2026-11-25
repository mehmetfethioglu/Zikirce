import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';
import 'package:hasibu/core/services/company_logo_service.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/features/pdks/presentation/screens/hasibu_settings_view.dart';
import 'package:hasibu/main.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const String _sample1x1PngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

class _FakeCompanyLogoPickerGateway implements CompanyLogoPickerGateway {
  String? nextPath;

  _FakeCompanyLogoPickerGateway({this.nextPath});

  @override
  Future<String?> pickLogoImagePath() async => nextPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('CompanyLogoService Birim Testleri', () {
    test('normalizes quoted paths, validates headers, rejects invalid files, and copies Turkish-named PNGs', () async {
      final tempDir = Directory.systemTemp.createTempSync('hasibu_logo_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      expect(
        CompanyLogoService.normalizeInputPath('  "C:\\Masaüstü\\logo.png"  '),
        equals(r'C:\Masaüstü\logo.png'),
      );

      const baseSettings = CompanySettings();

      // 1. Olmayan dosya reddedilmeli
      final missing = await CompanyLogoService.prepareLogoForSave(
        rawInput: p.join(tempDir.path, 'yok_logo.png'),
        currentSettings: baseSettings,
        storageDirOverride: tempDir,
      );
      expect(missing.isValid, isFalse);
      expect(missing.errorMessage, contains('bulunamadı'));

      // 2. Geçersiz görsel içeriği reddedilmeli
      final fakeImg = File(p.join(tempDir.path, 'sahte.png'));
      await fakeImg.writeAsString('bu bir png degildir');
      final badHeader = await CompanyLogoService.prepareLogoForSave(
        rawInput: fakeImg.path,
        currentSettings: baseSettings,
        storageDirOverride: tempDir,
      );
      expect(badHeader.isValid, isFalse);
      expect(badHeader.errorMessage, contains('Desteklenmeyen'));

      // 3. Türkçe adlı geçerli PNG doğrulanmalı, kalıcı kopyalanmalı ve Base64 üretmeli
      final pngBytes = base64Decode(_sample1x1PngBase64);
      final turkishLogo = File(
        p.join(tempDir.path, 'Şirket_Logosu_İğüöç.png'),
      );
      await turkishLogo.writeAsBytes(pngBytes, flush: true);

      final prepared = await CompanyLogoService.prepareLogoForSave(
        rawInput: '"${turkishLogo.path}"',
        currentSettings: baseSettings,
        storageDirOverride: tempDir,
      );
      expect(prepared.isValid, isTrue);
      expect(prepared.storedPath, isNotNull);
      expect(File(prepared.storedPath!).existsSync(), isTrue);
      expect(prepared.storedPath, contains('Hasibu_Logos'));
      expect(prepared.base64Data, equals(_sample1x1PngBase64));

      // 4. Hazır stil kodu ('logo:hasibu') ve boş sıfırlama
      final preset = await CompanyLogoService.prepareLogoForSave(
        rawInput: 'logo:hasibu',
        currentSettings: baseSettings,
        storageDirOverride: tempDir,
      );
      expect(preset.isValid, isTrue);
      expect(preset.storedPath, equals('logo:hasibu'));
      expect(preset.base64Data, isNull);

      final cleared = await CompanyLogoService.prepareLogoForSave(
        rawInput: '',
        currentSettings: baseSettings,
        storageDirOverride: tempDir,
      );
      expect(cleared.isValid, isTrue);
      expect(cleared.storedPath, isNull);
      expect(cleared.base64Data, isNull);
    });
  });

  group('Logo Seçme Hatası Düzeltmesi ve İlk Oturum İşletme/Logo Kurulumu', () {
    testWidgets(
      'showCompanyLogoDialog validates invalid paths inline and applies Turkish-named picked image file',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final tempDir = Directory.systemTemp.createTempSync('hasibu_dlg_logo_');
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });
        final logoFile = File(p.join(tempDir.path, 'Şirket_Logosu_İğüöç.png'));
        logoFile.writeAsBytesSync(base64Decode(_sample1x1PngBase64));

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(
                autoCloudBackupEnabled: false,
                autoPollEnabled: false,
              ),
        );
        final fakePicker = _FakeCompanyLogoPickerGateway(
          nextPath: logoFile.path,
        );

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            companyLogoPickerGatewayProvider.overrideWithValue(fakePicker),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (ctx, ref, _) => FilledButton(
                    key: const ValueKey('open_logo_dlg_test_btn'),
                    onPressed: () => showCompanyLogoDialog(ctx, ref),
                    child: const Text('Logo Penceresi'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open_logo_dlg_test_btn')));
        await tester.pumpAndSettle();

        // 1. Geçersiz yol girilirse hata banner'ı gösterilmeli ve pencere kapanmamalı
        await tester.enterText(
          find.byKey(const ValueKey('company_logo_path_field')),
          p.join(tempDir.path, 'olmayan_dosya.png'),
        );
        await tester.tap(find.byKey(const ValueKey('save_company_logo_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('company_logo_error_banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('save_company_logo_button')),
          findsOneWidget,
        );

        // 2. "Dosya Seç" ile Türkçe adlı PNG seçilip kaydedildiğinde başarıyla uygulanmalı
        await tester.tap(
          find.byKey(const ValueKey('company_logo_pick_file_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('company_logo_error_banner')),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(const ValueKey('company_logo_name_field')),
          'YENİ ŞİRKET A.Ş.',
        );
        await tester.tap(find.byKey(const ValueKey('save_company_logo_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('save_company_logo_button')),
          findsNothing,
        );

        final saved = db.getCompanySettings();
        expect(saved.companyName, equals('YENİ ŞİRKET A.Ş.'));
        expect(saved.logoPath, equals(logoFile.path));
        expect(saved.logoDataBase64, equals(_sample1x1PngBase64));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );

    testWidgets(
      'First admin login onboarding saves company name and logo and displays them on login screen',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final tempDir = Directory.systemTemp.createTempSync('hasibu_onboard_');
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });
        final logoFile = File(p.join(tempDir.path, 'Yıldız_Kurumsal_Logo.png'));
        logoFile.writeAsBytesSync(base64Decode(_sample1x1PngBase64));

        final db = HasibuDatabase.inMemory();
        addTearDown(db.dispose);
        db.saveCompanySettings(
          db.getCompanySettings().copyWith(
                autoCloudBackupEnabled: false,
                autoPollEnabled: false,
              ),
        );
        final fakePicker = _FakeCompanyLogoPickerGateway(
          nextPath: logoFile.path,
        );

        final container = ProviderContainer(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            companyLogoPickerGatewayProvider.overrideWithValue(fakePicker),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const HasibuApp(),
          ),
        );
        await tester.pumpAndSettle();

        // İlk açılışta varsayılan bilgilerle yönetici girişi
        await tester.tap(
          find.byKey(const ValueKey('login_fill_initial_admin_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('force_admin_password_dialog')),
          findsOneWidget,
        );

        // İşletme adı ve logo ekle + yeni parola gir
        await tester.enterText(
          find.byKey(const ValueKey('force_admin_company_name_field')),
          'YILDIZ LOJİSTİK A.Ş.',
        );
        await tester.tap(
          find.byKey(const ValueKey('force_admin_pick_logo_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('force_admin_new_password_field')),
          'GucluParola#2026',
        );
        await tester.enterText(
          find.byKey(const ValueKey('force_admin_confirm_password_field')),
          'GucluParola#2026',
        );
        await tester.tap(
          find.byKey(const ValueKey('force_admin_password_submit_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(
          container.read(pdksDashboardProvider).authSession.isAuthenticated,
          isTrue,
        );
        final updatedSettings = db.getCompanySettings();
        expect(updatedSettings.companyName, equals('YILDIZ LOJİSTİK A.Ş.'));
        expect(updatedSettings.logoPath, equals(logoFile.path));
        expect(updatedSettings.logoDataBase64, equals(_sample1x1PngBase64));
        expect(updatedSettings.adminPasswordUpdated, isTrue);
        expect(
          HasibuSecurityService.isPasswordHashed(updatedSettings.adminPassword),
          isTrue,
        );

        // Oturum kapatılınca Login ekranında yeni işletme adı ve logo görünmeli
        container.read(pdksDashboardProvider.notifier).logout();
        await tester.pumpAndSettle();

        expect(find.text('YILDIZ LOJİSTİK A.Ş.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('login_company_logo_badge')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('logo_file_${logoFile.path}')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
      },
    );
  });
}
