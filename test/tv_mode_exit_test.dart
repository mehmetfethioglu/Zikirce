import 'dart:ui' as ui;
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
  late List<List<String>> recordedOrientations;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    recordedOrientations = <List<String>>[];
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        final args = (call.arguments as List<dynamic>).cast<String>();
        recordedOrientations.add(args);
      }
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await db.close();
  });

  group('TvModeService & TvModeNotifier', () {
    test('setTvMode(true) -> setTvMode(false) persists false and updates state',
        () async {
      final container = ProviderContainer(
        overrides: [
          initialIsTvModeProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(isTvModeProvider.notifier).setTvMode(true);
      expect(container.read(isTvModeProvider), isTrue);
      expect(TvModeService.isTvModeActive, isTrue);

      await container.read(isTvModeProvider.notifier).setTvMode(false);
      expect(container.read(isTvModeProvider), isFalse);
      expect(TvModeService.isTvModeActive, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(TvModeService.prefsKey), isFalse);
    });

    test(
        'detectTvModeAtStartup respects saved false override even when isHardwareTv is true',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        TvModeService.prefsKey: false,
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(batteryChannel, (call) async {
        if (call.method == 'isTelevision') return true;
        return null;
      });
      TvModeService.testIsIosOverride = false;

      final result = await TvModeService.detectTvModeAtStartup();
      expect(TvModeService.isHardwareTv, isTrue);
      expect(result, isFalse);
      expect(TvModeService.isTvModeActive, isFalse);
    });

    testWidgets(
        'setTvMode(false) enables foldable-safe multi-orientation on Android and iOS viewports',
        (tester) async {
      for (final viewport in <Size>[
        const Size(390, 844),
        const Size(740, 360),
      ]) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final isIos in <bool>[false, true]) {
          recordedOrientations.clear();
          TvModeService.resetOrientationCacheForTest();
          TvModeService.testIsIosOverride = isIos;

          final container = ProviderContainer(
            overrides: [
              initialIsTvModeProvider.overrideWithValue(false),
            ],
          );

          await container.read(isTvModeProvider.notifier).setTvMode(true);
          expect(
            recordedOrientations.last,
            equals(<String>[
              'DeviceOrientation.landscapeLeft',
              'DeviceOrientation.landscapeRight',
            ]),
          );

          await container.read(isTvModeProvider.notifier).setTvMode(false);
          expect(
            recordedOrientations.last,
            equals(<String>[
              'DeviceOrientation.portraitUp',
              'DeviceOrientation.portraitDown',
              'DeviceOrientation.landscapeLeft',
              'DeviceOrientation.landscapeRight',
            ]),
          );
          container.dispose();
        }
      }
    });

    testWidgets(
        'hasFoldingDisplayFeature & isCurrentDisplayFoldableOrLarge detect fold/hinge on compact clamshells and sync avoids duplicate calls',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(TvModeService.isCurrentDeviceTablet(), isFalse);
      expect(TvModeService.hasFoldingDisplayFeature(), isFalse);
      expect(TvModeService.isCurrentDisplayFoldableOrLarge(), isFalse);

      tester.view.displayFeatures = const <ui.DisplayFeature>[
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(0, 450, 412, 12),
          type: ui.DisplayFeatureType.fold,
          state: ui.DisplayFeatureState.postureHalfOpened,
        ),
      ];
      addTearDown(tester.view.resetDisplayFeatures);

      expect(TvModeService.isCurrentDeviceTablet(), isFalse);
      expect(TvModeService.hasFoldingDisplayFeature(), isTrue);
      expect(TvModeService.isCurrentDisplayFoldableOrLarge(), isTrue);

      TvModeService.testIsIosOverride = false;
      recordedOrientations.clear();
      await TvModeService.syncOrientationForCurrentDisplay(isTvMode: false);
      expect(recordedOrientations.length, 1);

      // Calling again with unchanged policy must be an O(1) no-op
      await TvModeService.syncOrientationForCurrentDisplay(isTvMode: false);
      expect(recordedOrientations.length, 1);
    });
  });

  group('ZikirceTvHubScreen responsive layout & exit button', () {
    Future<ProviderContainer> pumpTvHub(
      WidgetTester tester, {
      required Size size,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        TvModeService.prefsKey: true,
      });
      TvModeService.setTvModeActiveForTest(true);

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          activeSessionProvider.overrideWithValue(UserSession.defaultSession()),
          initialIsTvModeProvider.overrideWithValue(true),
          googleDriveBackupServiceProvider.overrideWithValue(
            _FakeGoogleDriveBackupService(
              db: db,
              sessionId: UserSession.defaultSession().id,
            ),
          ),
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
            home: const ZikirceTvHubScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return container;
    }

    for (final entry in <String, Size>{
      'iPhone portrait (390x844)': const Size(390, 844),
      'Android phone landscape (740x360)': const Size(740, 360),
      '1080p Android TV (960x540)': const Size(960, 540),
    }.entries) {
      testWidgets(
          '${entry.key} renders without overflow and tv_exit_button exits TV mode',
          (tester) async {
        final container = await pumpTvHub(tester, size: entry.value);

        expect(tester.takeException(), isNull);

        final exitFinder = find.byKey(const Key('tv_exit_button'));
        expect(exitFinder, findsOneWidget);

        final rect = tester.getRect(exitFinder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(entry.value.width));
        expect(rect.bottom, lessThanOrEqualTo(entry.value.height));

        await tester.tap(exitFinder);
        await tester.pumpAndSettle();

        expect(container.read(isTvModeProvider), isFalse);
        expect(TvModeService.isTvModeActive, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(TvModeService.prefsKey), isFalse);
      });
    }
  });
}
