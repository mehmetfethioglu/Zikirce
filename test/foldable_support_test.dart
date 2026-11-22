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
import 'package:zikirce/core/layout/foldable_layout_info.dart';
import 'package:zikirce/core/layout/foldable_two_pane.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/services/changelog_service.dart';
import 'package:zikirce/core/services/local_notification_service.dart';
import 'package:zikirce/core/services/prayer_times_service.dart';
import 'package:zikirce/core/services/prayer_tracking_service.dart';
import 'package:zikirce/core/session/session_providers.dart';
import 'package:zikirce/core/session/user_session.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/features/dashboard/presentation/screens/bismillah_dashboard_screen.dart';
import 'package:zikirce/features/kuran/presentation/screens/mushaf_screen.dart';
import 'package:zikirce/features/namaz_vakitleri/presentation/screens/prayer_times_screen.dart';
import 'package:zikirce/features/namaz_vakitleri/presentation/screens/qibla_compass_screen.dart';
import 'package:zikirce/features/namaz_vakitleri/providers/prayer_providers.dart';
import 'package:zikirce/features/zikir/presentation/screens/zikir_counter_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    LocalNotificationService.consumeInitialPrayerNotificationTap();
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'Changelog_LastSeenVersionCode': ChangelogService.effectiveVersionCode,
      'LastProcessedKazaDate': todayStr,
      'SabahNotificationEnabled': false,
      'OgleNotificationEnabled': false,
      'ÖğleNotificationEnabled': false,
      'IkindiNotificationEnabled': false,
      'İkindiNotificationEnabled': false,
      'AksamNotificationEnabled': false,
      'AkşamNotificationEnabled': false,
      'YatsiNotificationEnabled': false,
      'YatsıNotificationEnabled': false,
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/magnetometer'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (call) async => null,
    );

    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.zikirs).insert(
          ZikirsCompanion.insert(
            name: 'Sübhanallah',
            arabic: const drift.Value('سُبْحَانَ اللهِ'),
            category: const drift.Value('Tesbihat'),
            totalCount: const drift.Value(330),
            currentCount: const drift.Value(12),
            target: const drift.Value(33),
          ),
        );
  });

  tearDown(() async {
    LocalNotificationService.consumeInitialPrayerNotificationTap();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/magnetometer'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      null,
    );
    await db.close();
  });

  Widget buildHarness({required Widget child}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activeSessionProvider.overrideWithValue(UserSession.defaultSession()),
        timeTickerStreamProvider.overrideWith(
          (ref) => Stream.value(DateTime.now()),
        ),
        prayerTimingsProvider.overrideWith(
          (ref) async => PrayerTimesService.calculateOfflinePrayerTimes(
            'İstanbul',
            DateTime.now(),
          ),
        ),
        pendingPastDaysProvider.overrideWith(
          (ref) async => const PastDaysCheckResult(
            recentDays: [],
            olderDates: [],
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        theme: ThemeData(
          brightness: Brightness.light,
          extensions: const [AppThemeColors.greenLight],
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1000));
  }

  group('FoldableLayoutInfo.fromMetrics', () {
    test('detects narrow folded cover screen and standard compact phone', () {
      for (final coverSize in const [Size(320, 840), Size(344, 840)]) {
        final info = FoldableLayoutInfo.fromMetrics(
          windowSize: coverSize,
          displayFeatures: const [],
        );
        expect(info.widthClass, WindowWidthClass.compact);
        expect(info.isCompact, isTrue);
        expect(info.isNarrowCoverScreen, isTrue);
        expect(info.useNavigationRail, isFalse);
        expect(info.supportsTwoPageSpread, isFalse);
      }

      final phoneInfo = FoldableLayoutInfo.fromMetrics(
        windowSize: const Size(390, 844),
        displayFeatures: const [],
      );
      expect(phoneInfo.widthClass, WindowWidthClass.compact);
      expect(phoneInfo.isNarrowCoverScreen, isFalse);
      expect(phoneInfo.useNavigationRail, isFalse);
      expect(phoneInfo.supportsTwoPaneHorizontal, isFalse);
    });

    test('detects compact phone landscape (two-pane horizontal, no book spread)',
        () {
      for (final landscapeSize in const [Size(740, 360), Size(844, 390)]) {
        final info = FoldableLayoutInfo.fromMetrics(
          windowSize: landscapeSize,
          displayFeatures: const [],
        );
        expect(info.supportsTwoPaneHorizontal, isTrue);
        expect(info.supportsTwoPageSpread, isFalse);
        expect(info.posture, FoldablePosture.flat);
      }
    });

    test('detects Android Galaxy Z Fold unfolded flat', () {
      final portraitUnfolded = FoldableLayoutInfo.fromMetrics(
        windowSize: const Size(673, 841),
        displayFeatures: const [
          ui.DisplayFeature(
            bounds: Rect.fromLTWH(336, 0, 1, 841),
            type: ui.DisplayFeatureType.fold,
            state: ui.DisplayFeatureState.postureFlat,
          ),
        ],
      );
      expect(portraitUnfolded.widthClass, WindowWidthClass.medium);
      expect(portraitUnfolded.useNavigationRail, isTrue);
      expect(portraitUnfolded.supportsTwoPageSpread, isTrue);
      expect(portraitUnfolded.hasPhysicalFoldFeature, isTrue);
      expect(portraitUnfolded.hingeBounds, const Rect.fromLTWH(336, 0, 1, 841));

      final landscapeUnfolded = FoldableLayoutInfo.fromMetrics(
        windowSize: const Size(841, 673),
        displayFeatures: const [
          ui.DisplayFeature(
            bounds: Rect.fromLTWH(0, 336, 841, 1),
            type: ui.DisplayFeatureType.fold,
            state: ui.DisplayFeatureState.postureFlat,
          ),
        ],
      );
      expect(landscapeUnfolded.widthClass, WindowWidthClass.expanded);
      expect(landscapeUnfolded.useNavigationRail, isTrue);
      expect(landscapeUnfolded.supportsTwoPageSpread, isTrue);
    });

    test('detects Android Book Mode and Tabletop/Flex Mode', () {
      final bookInfo = FoldableLayoutInfo.fromMetrics(
        windowSize: const Size(720, 840),
        displayFeatures: const [
          ui.DisplayFeature(
            bounds: Rect.fromLTWH(354, 0, 12, 840),
            type: ui.DisplayFeatureType.hinge,
            state: ui.DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );
      expect(bookInfo.posture, FoldablePosture.book);
      expect(bookInfo.isBookPosture, isTrue);
      expect(bookInfo.verticalHingeWidth(), 12.0);
      expect(bookInfo.useNavigationRail, isTrue);
      expect(bookInfo.supportsTwoPageSpread, isTrue);

      for (final clamshellOrBook in const [Size(412, 915), Size(841, 673)]) {
        final tabletop = FoldableLayoutInfo.fromMetrics(
          windowSize: clamshellOrBook,
          displayFeatures: [
            ui.DisplayFeature(
              bounds: Rect.fromLTWH(
                0,
                clamshellOrBook.height * 0.5 - 4,
                clamshellOrBook.width,
                8,
              ),
              type: ui.DisplayFeatureType.fold,
              state: ui.DisplayFeatureState.postureHalfOpened,
            ),
          ],
        );
        expect(tabletop.posture, FoldablePosture.tabletop);
        expect(tabletop.isTabletopPosture, isTrue);
        expect(tabletop.useNavigationRail, isFalse);
        expect(tabletop.supportsTwoPageSpread, isFalse);
      }
    });

    test('detects iOS Foldable iPhone unfolded via window size classes', () {
      for (final iosSize in const [Size(744, 920), Size(920, 744)]) {
        final info = FoldableLayoutInfo.fromMetrics(
          windowSize: iosSize,
          displayFeatures: const [],
        );
        expect(info.posture, FoldablePosture.flat);
        expect(info.hasPhysicalFoldFeature, isFalse);
        expect(info.useNavigationRail, isTrue);
        expect(info.supportsTwoPaneHorizontal, isTrue);
        expect(info.supportsTwoPageSpread, isTrue);
      }
    });
  });

  group('FoldablePaneMetrics.resolve', () {
    test('aligns vertical hinge accounting for NavigationRail origin offset',
        () {
      final layoutInfo = FoldableLayoutInfo.fromMetrics(
        windowSize: const Size(720, 840),
        displayFeatures: const [
          ui.DisplayFeature(
            bounds: Rect.fromLTWH(354, 0, 12, 840),
            type: ui.DisplayFeatureType.hinge,
            state: ui.DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );

      final metrics = FoldablePaneMetrics.resolve(
        availableSize: const Size(628, 840),
        windowOriginOffset: const Offset(92, 0),
        layoutInfo: layoutInfo,
        paneSpacing: 12.0,
      );

      expect(metrics.splitAxis, Axis.horizontal);
      expect(metrics.firstExtent, 262.0);
      expect(metrics.hingeGap, 12.0);
      expect(metrics.secondExtent, 354.0);
      expect(metrics.isHingeAligned, isTrue);
    });

    test('falls back to proportional split when hinge is too near edge', () {
      final layoutInfo = FoldableLayoutInfo.fromMetrics(
        windowSize: const Size(720, 840),
        displayFeatures: const [
          ui.DisplayFeature(
            bounds: Rect.fromLTWH(200, 0, 10, 840),
            type: ui.DisplayFeatureType.hinge,
            state: ui.DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );

      final metrics = FoldablePaneMetrics.resolve(
        availableSize: const Size(628, 840),
        windowOriginOffset: const Offset(92, 0),
        layoutInfo: layoutInfo,
        paneSpacing: 16.0,
        minHorizontalPaneWidth: 220.0,
      );

      expect(metrics.isHingeAligned, isFalse);
      expect(metrics.firstExtent, closeTo(306.0, 0.1));
      expect(metrics.secondExtent, closeTo(306.0, 0.1));
    });

    test('aligns horizontal tabletop split across top and bottom halves', () {
      final layoutInfo = FoldableLayoutInfo.fromMetrics(
        windowSize: const Size(412, 915),
        displayFeatures: const [
          ui.DisplayFeature(
            bounds: Rect.fromLTWH(0, 450, 412, 14),
            type: ui.DisplayFeatureType.fold,
            state: ui.DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );

      final metrics = FoldablePaneMetrics.resolve(
        availableSize: const Size(412, 915),
        windowOriginOffset: Offset.zero,
        layoutInfo: layoutInfo,
        paneSpacing: 10.0,
      );

      expect(metrics.splitAxis, Axis.vertical);
      expect(metrics.firstExtent, 450.0);
      expect(metrics.hingeGap, 14.0);
      expect(metrics.secondExtent, 451.0);
      expect(metrics.isHingeAligned, isTrue);
    });
  });

  group('FoldableTwoPane widget tests', () {
    testWidgets(
        'renders flat horizontal, book mode, reverseHorizontal RTL spread, and tabletop splits without overflow',
        (tester) async {
      // 1. Flat horizontal split (iOS / tablet)
      tester.view.physicalSize = const Size(768, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoldableTwoPane(
              startPane: SizedBox(key: Key('pane_start')),
              endPane: SizedBox(key: Key('pane_end')),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(const Key('pane_start'))).left,
        lessThan(tester.getRect(find.byKey(const Key('pane_end'))).left),
      );

      // 2. Book Mode + reverseHorizontal (RTL Mushaf: startPane sits on the RIGHT)
      tester.view.physicalSize = const Size(720, 840);
      tester.view.displayFeatures = const [
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(354, 0, 12, 840),
          type: ui.DisplayFeatureType.hinge,
          state: ui.DisplayFeatureState.postureHalfOpened,
        ),
      ];
      addTearDown(tester.view.resetDisplayFeatures);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoldableTwoPane(
              reverseHorizontal: true,
              startPane: SizedBox(key: Key('rtl_right_page')),
              endPane: SizedBox(key: Key('rtl_left_page')),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final rightPageRect =
          tester.getRect(find.byKey(const Key('rtl_right_page')));
      final leftPageRect =
          tester.getRect(find.byKey(const Key('rtl_left_page')));
      expect(rightPageRect.left, greaterThan(leftPageRect.left));
      expect(leftPageRect.right, lessThanOrEqualTo(354.0));
      expect(rightPageRect.left, greaterThanOrEqualTo(366.0));

      // 3. Tabletop vertical split
      tester.view.physicalSize = const Size(412, 915);
      tester.view.displayFeatures = const [
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(0, 450, 412, 16),
          type: ui.DisplayFeatureType.fold,
          state: ui.DisplayFeatureState.postureHalfOpened,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoldableTwoPane(
              startPane: SizedBox(key: Key('top_pane')),
              endPane: SizedBox(key: Key('bottom_pane')),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final topRect = tester.getRect(find.byKey(const Key('top_pane')));
      final bottomRect = tester.getRect(find.byKey(const Key('bottom_pane')));
      expect(topRect.bottom, lessThanOrEqualTo(450.0));
      expect(bottomRect.top, greaterThanOrEqualTo(466.0));
    });
  });

  group('Real screens on Foldable Android & iOS viewports', () {
    testWidgets(
        'BismillahDashboardScreen adapts cleanly across cover, landscape, Android unfolded, and iOS unfolded',
        (tester) async {
      // Narrow cover screen -> single column
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildHarness(child: const BismillahDashboardScreen()),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('dashboard_two_pane')), findsNothing);
      await disposeTree(tester);

      // Compact landscape -> two-pane
      tester.view.physicalSize = const Size(740, 360);
      await tester.pumpWidget(
        buildHarness(child: const BismillahDashboardScreen()),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('dashboard_two_pane')), findsOneWidget);
      await disposeTree(tester);

      // Android Book unfolded -> two-pane respecting hinge
      tester.view.physicalSize = const Size(720, 840);
      tester.view.displayFeatures = const [
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(354, 0, 12, 840),
          type: ui.DisplayFeatureType.hinge,
          state: ui.DisplayFeatureState.postureHalfOpened,
        ),
      ];
      addTearDown(tester.view.resetDisplayFeatures);
      await tester.pumpWidget(
        buildHarness(child: const BismillahDashboardScreen()),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('dashboard_two_pane')), findsOneWidget);
      await disposeTree(tester);

      // iOS unfolded -> two-pane
      tester.view.resetDisplayFeatures();
      tester.view.physicalSize = const Size(768, 960);
      await tester.pumpWidget(
        buildHarness(child: const BismillahDashboardScreen()),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('dashboard_two_pane')), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets(
        'ZikirCounterScreen adapts across cover, landscape, unfolded, and Tabletop Flex mode',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHarness(child: const ZikirCounterScreen()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('zikir_counter_circle')), findsOneWidget);
      await disposeTree(tester);

      // Landscape 740x360
      tester.view.physicalSize = const Size(740, 360);
      await tester.pumpWidget(buildHarness(child: const ZikirCounterScreen()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('zikir_horizontal_two_pane')),
        findsOneWidget,
      );
      await disposeTree(tester);

      // Unfolded 768x900
      tester.view.physicalSize = const Size(768, 900);
      await tester.pumpWidget(buildHarness(child: const ZikirCounterScreen()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('zikir_horizontal_two_pane')),
        findsOneWidget,
      );
      await disposeTree(tester);

      // Tabletop Flex Mode 412x915 -> Arabic above hinge, Tap counter below hinge
      tester.view.physicalSize = const Size(412, 915);
      tester.view.displayFeatures = const [
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(0, 450, 412, 16),
          type: ui.DisplayFeatureType.fold,
          state: ui.DisplayFeatureState.postureHalfOpened,
        ),
      ];
      addTearDown(tester.view.resetDisplayFeatures);

      await tester.pumpWidget(buildHarness(child: const ZikirCounterScreen()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('zikir_tabletop_two_pane')), findsOneWidget);

      final promptRect =
          tester.getRect(find.byKey(const Key('zikir_arabic_prompt_area')));
      final counterRect =
          tester.getRect(find.byKey(const Key('zikir_counter_circle')));
      expect(promptRect.bottom, lessThanOrEqualTo(450.0));
      expect(counterRect.top, greaterThanOrEqualTo(466.0));
      await disposeTree(tester);
    });

    testWidgets(
        'PrayerTimesScreen adapts across narrow cover screen and unfolded two-pane',
        (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHarness(child: const PrayerTimesScreen()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('prayer_times_two_pane')), findsNothing);
      await disposeTree(tester);

      tester.view.physicalSize = const Size(768, 900);
      await tester.pumpWidget(buildHarness(child: const PrayerTimesScreen()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('prayer_times_two_pane')), findsOneWidget);
      await disposeTree(tester);
    });

    test('MushafScreen spread math maps pages 1..605 accurately', () {
      expect(MushafScreen.spreadIndexForPage(1), 0);
      expect(MushafScreen.rightPageForSpread(0), 1);
      expect(MushafScreen.leftPageForSpread(0), 2);

      expect(MushafScreen.spreadIndexForPage(2), 0);
      expect(MushafScreen.spreadIndexForPage(3), 1);
      expect(MushafScreen.rightPageForSpread(1), 3);
      expect(MushafScreen.leftPageForSpread(1), 4);

      expect(MushafScreen.spreadIndexForPage(604), 301);
      expect(MushafScreen.rightPageForSpread(301), 603);
      expect(MushafScreen.leftPageForSpread(301), 604);

      expect(MushafScreen.spreadIndexForPage(605), 302);
      expect(MushafScreen.rightPageForSpread(302), 605);
      expect(MushafScreen.leftPageForSpread(302), isNull);
    });

    testWidgets(
        'QiblaCompassScreen scales cleanly on narrow cover and landscape foldables',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHarness(child: const QiblaCompassScreen()));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('qibla_compass_dial')), findsOneWidget);
      await disposeTree(tester);

      tester.view.physicalSize = const Size(740, 360);
      await tester.pumpWidget(buildHarness(child: const QiblaCompassScreen()));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('qibla_compass_dial')), findsOneWidget);
      await disposeTree(tester);
    });
  });
}
