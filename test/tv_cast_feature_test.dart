import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/providers/tv_mode_provider.dart';
import 'package:zikirce/core/services/google_drive_backup_service.dart';
import 'package:zikirce/core/session/session_providers.dart';
import 'package:zikirce/core/session/user_session.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/features/tv/presentation/screens/zikirce_tv_hub_screen.dart';
import 'package:zikirce/features/tv/presentation/widgets/tv_cast_sheet.dart';
import 'package:zikirce/features/tv/providers/tv_cast_provider.dart';

class _FakeTvCastGateway implements TvCastPlatformGateway {
  @override
  bool get isMobileCastPlatform => true;

  @override
  bool isIosPlatform;

  Map<String, dynamic> statusPayload;
  Map<String, dynamic> openPickerResult;
  int openCastPickerCalls = 0;
  bool clearedStatusHandler = false;
  void Function(Map<String, dynamic> payload)? _handler;

  _FakeTvCastGateway({
    this.isIosPlatform = false,
    Map<String, dynamic>? initialStatus,
    Map<String, dynamic>? openPickerResult,
  })  : statusPayload = initialStatus ??
            <String, dynamic>{
              'supported': true,
              'isConnected': false,
              'isVisualMirroring': false,
              'deviceName': null,
              'connectionType': 'none',
              'platform': isIosPlatform ? 'ios' : 'android',
            },
        openPickerResult = openPickerResult ??
            <String, dynamic>{
              'opened': true,
              'mode': isIosPlatform ? 'ios_airplay_picker' : 'system_cast_settings',
            };

  @override
  Future<Map<String, dynamic>?> getCastStatus() async {
    return Map<String, dynamic>.from(statusPayload);
  }

  @override
  Future<Map<String, dynamic>?> openCastPicker() async {
    openCastPickerCalls++;
    return Map<String, dynamic>.from(openPickerResult);
  }

  @override
  void setOnStatusChanged(
    void Function(Map<String, dynamic> payload)? handler,
  ) {
    if (handler == null) {
      clearedStatusHandler = true;
    }
    _handler = handler;
  }

  void emitStatus(Map<String, dynamic> payload) {
    statusPayload = Map<String, dynamic>.from(payload);
    _handler?.call(Map<String, dynamic>.from(payload));
  }
}

class _FakeGoogleDriveBackupService extends GoogleDriveBackupService {
  _FakeGoogleDriveBackupService({required super.db, super.sessionId});

  @override
  Future<bool> isSignedIn() async => false;

  @override
  Future<String?> getUserEmail() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const batteryChannel =
      MethodChannel('com.akarworks.zikirce/battery_optimization');
  late AppDatabase db;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    TvModeService.setHardwareTvForTest(false);
    TvModeService.setTvModeActiveForTest(false);
    TvModeService.resetOrientationCacheForTest();
    TvModeService.testIsIosOverride = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase(NativeDatabase.memory());

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, (call) async {
      if (call.method == 'isTelevision') return false;
      if (call.method == 'setKeepScreenAwake') return true;
      return null;
    });
  });

  tearDown(() async {
    TvModeService.setHardwareTvForTest(false);
    TvModeService.setTvModeActiveForTest(false);
    TvModeService.resetOrientationCacheForTest();
    TvModeService.testIsIosOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, null);
    await db.close();
  });

  group('TvCastNotifier', () {
    test('Android status parsing, live connection update, picker, auto-prompt and dispose cleanup', () async {
      final gateway = _FakeTvCastGateway(isIosPlatform: false);
      final container = ProviderContainer(
        overrides: [
          tvCastGatewayProvider.overrideWithValue(gateway),
        ],
      );

      final initial = container.read(tvCastProvider);
      expect(initial.isSupported, isTrue);
      expect(initial.isAndroid, isTrue);
      expect(initial.isConnected, isFalse);

      gateway.emitStatus(<String, dynamic>{
        'supported': true,
        'isConnected': true,
        'isVisualMirroring': true,
        'deviceName': 'Samsung QLED 55',
        'connectionType': 'wireless',
        'platform': 'android',
      });

      final connected = container.read(tvCastProvider);
      expect(connected.isConnected, isTrue);
      expect(connected.isVisualMirroring, isTrue);
      expect(connected.deviceName, 'Samsung QLED 55');
      expect(connected.connectionType, TvCastConnectionType.wireless);

      final opened = await container.read(tvCastProvider.notifier).openCastPicker();
      expect(opened, isTrue);
      expect(gateway.openCastPickerCalls, 1);
      expect(container.read(tvCastProvider).isOpeningPicker, isFalse);

      container.read(tvCastProvider.notifier).requestAutoPromptOnTvEntry();
      expect(container.read(tvCastProvider).pendingAutoPrompt, isTrue);
      container.read(tvCastProvider.notifier).consumeAutoPrompt();
      expect(container.read(tvCastProvider).pendingAutoPrompt, isFalse);

      container.dispose();
      expect(gateway.clearedStatusHandler, isTrue);
    });

    test('iOS distinguishes airplay_audio from wireless visual mirroring', () async {
      final gateway = _FakeTvCastGateway(
        isIosPlatform: true,
        initialStatus: <String, dynamic>{
          'supported': true,
          'isConnected': true,
          'isVisualMirroring': false,
          'deviceName': 'Oturma Odası HomePod',
          'connectionType': 'airplay_audio',
          'platform': 'ios',
        },
      );
      final container = ProviderContainer(
        overrides: [
          tvCastGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await container.read(tvCastProvider.notifier).refreshStatus();
      final audioOnly = container.read(tvCastProvider);
      expect(audioOnly.isIos, isTrue);
      expect(audioOnly.isConnected, isTrue);
      expect(audioOnly.isVisualMirroring, isFalse);
      expect(audioOnly.connectionType, TvCastConnectionType.airplayAudio);

      gateway.emitStatus(<String, dynamic>{
        'supported': true,
        'isConnected': true,
        'isVisualMirroring': true,
        'deviceName': 'LG OLED TV',
        'connectionType': 'wireless',
        'platform': 'ios',
      });

      final mirroring = container.read(tvCastProvider);
      expect(mirroring.isVisualMirroring, isTrue);
      expect(mirroring.connectionType, TvCastConnectionType.wireless);
      expect(mirroring.deviceName, 'LG OLED TV');
    });

    test('Hardware Android TV marks cast as unsupported', () {
      TvModeService.setHardwareTvForTest(true);
      final gateway = _FakeTvCastGateway(isIosPlatform: false);
      final container = ProviderContainer(
        overrides: [
          tvCastGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(tvCastProvider).isSupported, isFalse);
    });
  });

  group('TvCastSheet UI & responsive viewports', () {
    for (final isIos in <bool>[false, true]) {
      for (final viewport in <Size>[
        const Size(740, 360),
        const Size(390, 844),
      ]) {
        testWidgets(
            '${isIos ? 'iOS' : 'Android'} ${viewport.width.toInt()}x${viewport.height.toInt()} renders without overflow, opens picker, shows connected card and auto-closes',
            (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final gateway = _FakeTvCastGateway(isIosPlatform: isIos);
          final container = ProviderContainer(
            overrides: [
              tvCastGatewayProvider.overrideWithValue(gateway),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: const Locale('tr'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: ThemeData(
                  brightness: Brightness.light,
                  extensions: const [AppThemeColors.greenLight],
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        key: const Key('open_sheet_trigger'),
                        onPressed: () => TvCastSheet.show(context),
                        child: const Text('Aç'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('open_sheet_trigger')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(TvCastSheet), findsOneWidget);

          final pickerButton = find.byKey(const Key('tv_cast_open_picker_button'));
          expect(pickerButton, findsOneWidget);
          await tester.ensureVisible(pickerButton);
          await tester.tap(pickerButton);
          await tester.pump();
          expect(gateway.openCastPickerCalls, 1);

          gateway.emitStatus(<String, dynamic>{
            'supported': true,
            'isConnected': true,
            'isVisualMirroring': true,
            'deviceName': isIos ? 'Apple TV Oturma Odası' : 'Samsung QLED 55',
            'connectionType': 'wireless',
            'platform': isIos ? 'ios' : 'android',
          });
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.text("TV'ye Yansıtılıyor"), findsOneWidget);

          await tester.pump(const Duration(milliseconds: 950));
          await tester.pumpAndSettle();
          expect(find.byType(TvCastSheet), findsNothing);
        });
      }
    }
  });

  group('ZikirceTvHubScreen TV Cast integration', () {
    Future<ProviderContainer> pumpTvHubWithCast(
      WidgetTester tester, {
      required _FakeTvCastGateway gateway,
      bool hardwareTv = false,
      bool requestAutoPrompt = false,
    }) async {
      TvModeService.setHardwareTvForTest(hardwareTv);
      TvModeService.setTvModeActiveForTest(true);
      SharedPreferences.setMockInitialValues(<String, Object>{
        TvModeService.prefsKey: true,
      });

      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          activeSessionProvider.overrideWithValue(UserSession.defaultSession()),
          initialIsTvModeProvider.overrideWithValue(true),
          tvCastGatewayProvider.overrideWithValue(gateway),
          googleDriveBackupServiceProvider.overrideWithValue(
            _FakeGoogleDriveBackupService(
              db: db,
              sessionId: UserSession.defaultSession().id,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      if (requestAutoPrompt) {
        container.read(tvCastProvider.notifier).requestAutoPromptOnTvEntry();
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('tr'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              brightness: Brightness.light,
              extensions: const [AppThemeColors.greenLight],
            ),
            home: const ZikirceTvHubScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return container;
    }

    testWidgets('shows tv_cast_button on mobile and opens TvCastSheet on tap without auto-prompting when not requested', (tester) async {
      final gateway = _FakeTvCastGateway(isIosPlatform: false);
      await pumpTvHubWithCast(tester, gateway: gateway);

      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.byType(TvCastSheet), findsNothing);

      final castButton = find.byKey(const Key('tv_cast_button'));
      expect(castButton, findsOneWidget);
      await tester.tap(castButton);
      await tester.pumpAndSettle();

      expect(find.byType(TvCastSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides tv_cast_button on hardware Android TV', (tester) async {
      final gateway = _FakeTvCastGateway(isIosPlatform: false);
      await pumpTvHubWithCast(
        tester,
        gateway: gateway,
        hardwareTv: true,
      );

      expect(find.byKey(const Key('tv_cast_button')), findsNothing);
      expect(find.byType(TvCastSheet), findsNothing);
    });

    testWidgets('auto-opens TvCastSheet after 350ms when requestAutoPromptOnTvEntry is set', (tester) async {
      final gateway = _FakeTvCastGateway(isIosPlatform: false);
      await pumpTvHubWithCast(
        tester,
        gateway: gateway,
        requestAutoPrompt: true,
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(TvCastSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
