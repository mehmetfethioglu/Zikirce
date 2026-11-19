import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/app/router/app_router.dart';
import 'package:zikirce/core/database/app_database.dart';
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
import 'package:zikirce/features/dashboard/presentation/screens/detailed_stats_screen.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/activity_trend_chart.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/annual_heatmap_widget.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/bento/bento_daily_zikir_card.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/bento/bento_home_action_cards.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/bento/bento_streak_rhythm_card.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/bento/last_7_days_activity_trend_card.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/bento/minimal_home_header.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/stats_treasury_summary_card.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/zikir_distribution_donut.dart';
import 'package:zikirce/features/dashboard/presentation/widgets/zikir_history_section.dart';
import 'package:zikirce/features/dashboard/providers/dashboard_providers.dart';
import 'package:zikirce/features/namaz_vakitleri/providers/prayer_providers.dart';
import 'package:zikirce/features/settings/providers/settings_provider.dart';
import 'package:zikirce/features/zikir/providers/zikir_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    AppStartupRouteConfig.openDirectlyOnZikir = false;
    LocalNotificationService.consumeInitialPrayerNotificationTap();
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
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
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    AppStartupRouteConfig.openDirectlyOnZikir = false;
    LocalNotificationService.consumeInitialPrayerNotificationTap();
    await db.close();
  });

  Widget buildHarness({
    required Widget child,
    required AppThemeColors themeColors,
    required Brightness brightness,
  }) {
    final baseTheme = ThemeData(
      brightness: brightness,
      extensions: [themeColors],
    );
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
        theme: baseTheme,
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

  group('Startup Route & Settings Preference', () {
    test('AppStartupRouteConfig resolves "/" by default and "/zikir" when enabled', () {
      AppStartupRouteConfig.openDirectlyOnZikir = false;
      expect(
        AppStartupRouteConfig.resolveInitialLocation(isHardwareTv: false),
        '/',
      );

      AppStartupRouteConfig.openDirectlyOnZikir = true;
      expect(
        AppStartupRouteConfig.resolveInitialLocation(isHardwareTv: false),
        '/zikir',
      );
      expect(
        AppStartupRouteConfig.resolveInitialLocation(isHardwareTv: true),
        '/',
      );
    });

    test('SettingsNotifier.toggleStartOnZikir persists preference and updates startup config', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          activeSessionProvider.overrideWithValue(UserSession.defaultSession()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userSettingsProvider.notifier);
      expect(container.read(userSettingsProvider).isStartOnZikirEnabled, isFalse);

      await notifier.toggleStartOnZikir(true);

      expect(container.read(userSettingsProvider).isStartOnZikirEnabled, isTrue);
      expect(AppStartupRouteConfig.openDirectlyOnZikir, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('IsStartOnZikirEnabled'), isTrue);
    });
  });

  group('Last 7 Days Trend, Favorite Zikirs & Notification Routing Unit Tests', () {
    test('buildLast7DaysTrendData always computes rolling 7 days ending today with no future dates', () {
      final anchor = DateTime(2026, 11, 16); // Monday
      final trend = buildLast7DaysTrendData(
        anchorDate: anchor,
        countsByDate: {
          '2026-11-05': 50, // previous 7-day window
          '2026-11-10': 100,
          '2026-11-12': 200,
          '2026-11-16': 400,
          '2026-11-17': 999, // future date must be excluded
        },
      );

      expect(trend.days.length, 7);
      expect(trend.days.first.dateStr, '2026-11-10');
      expect(trend.days.last.dateStr, '2026-11-16');
      expect(trend.days.last.isToday, isTrue);
      for (int i = 0; i < 6; i++) {
        expect(trend.days[i].isToday, isFalse);
      }
      expect(trend.days.any((d) => d.dateStr == '2026-11-17'), isFalse);
      expect(trend.sevenDayTotal, 700);
      expect(trend.dailyAverage, 100);
      expect(trend.peakCount, 400);
    });

    test('buildFavoriteZikirCardItems sorts practiced zikirs descending by effectiveTotal', () {
      final now = DateTime(2026, 11, 16);
      final zikirs = [
        Zikir(
          id: 1,
          name: 'Sübhanallah',
          arabic: 'سُبْحَانَ اللّٰهِ',
          target: 33,
          currentCount: 5,
          totalCount: 10,
          lap: 0,
          isFavorite: false,
          category: 'Tesbihat',
          soundEffect: 'bulbul',
          vibrationEnabled: true,
          createdAt: now,
          lastPracticed: now,
        ),
        Zikir(
          id: 2,
          name: 'Elhamdülillah',
          arabic: 'اَلْحَمْدُ لِلّٰهِ',
          target: 33,
          currentCount: 12,
          totalCount: 250,
          lap: 7,
          isFavorite: true,
          category: 'Tesbihat',
          soundEffect: 'bulbul',
          vibrationEnabled: true,
          createdAt: now,
          lastPracticed: now,
        ),
        Zikir(
          id: 3,
          name: 'Allahu Ekber',
          arabic: 'اَللّٰهُ اَكْبَرُ',
          target: 33,
          currentCount: 0,
          totalCount: 80,
          lap: 2,
          isFavorite: false,
          category: 'Tesbihat',
          soundEffect: 'bulbul',
          vibrationEnabled: true,
          createdAt: now,
          lastPracticed: now,
        ),
      ];

      final sorted = buildFavoriteZikirCardItems(
        zikirs: zikirs,
        logTotalsByZikirId: const {1: 10, 2: 250, 3: 80},
        activeZikirId: 3,
      );

      expect(sorted.map((e) => e.id).toList(), [2, 3, 1]);
      expect(sorted.map((e) => e.effectiveTotal).toList(), [250, 80, 10]);
      expect(sorted[1].isActive, isTrue);
    });

    test('LocalNotificationService dispatches prayer_question taps live and buffers cold-start taps', () async {
      // 1. No listener attached (cold-start scenario)
      LocalNotificationService.dispatchNotificationPayload(
        'prayer_question|Sabah|2026-11-16',
      );
      final coldTap =
          LocalNotificationService.consumeInitialPrayerNotificationTap();
      expect(coldTap, isNotNull);
      expect(coldTap!.prayerName, 'Sabah');
      expect(coldTap.dateStr, '2026-11-16');
      expect(
        LocalNotificationService.consumeInitialPrayerNotificationTap(),
        isNull,
      );

      // 2. Listener attached (app open / backgrounded)
      final completer =
          Completer<({String prayerName, String dateStr})>();
      final sub = LocalNotificationService
          .pendingPrayerNotificationTapped.stream
          .listen((event) {
        if (!completer.isCompleted) {
          completer.complete(event);
        }
      });
      addTearDown(sub.cancel);

      LocalNotificationService.dispatchNotificationPayload(
        'prayer_question|Akşam|2026-11-16',
      );
      final liveEvent = await completer.future;
      expect(liveEvent.prayerName, 'Akşam');
      expect(liveEvent.dateStr, '2026-11-16');
      expect(
        LocalNotificationService.consumeInitialPrayerNotificationTap(),
        isNull,
      );
    });
  });

  group('Minimal Bento Home & Detailed Stats Widget Tests', () {
    Future<void> disposeWidgetTree(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets(
      'BismillahDashboardScreen renders simplified profile card, single-card favorite zikirs & clean wave trends without prayer card',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(
            child: const BismillahDashboardScreen(),
            themeColors: AppThemeColors.greenLight,
            brightness: Brightness.light,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(MinimalHomeHeader), findsOneWidget);
        expect(find.byType(BentoDailyZikirCard), findsOneWidget);
        expect(find.byType(BentoStreakRhythmCard), findsOneWidget);
        expect(find.byType(FavoriteZikirsCarouselCard), findsOneWidget);
        expect(find.byType(Last7DaysActivityTrendCard), findsOneWidget);

        // Prayers card and removed cluttered titles/nested side-by-side metrics must not appear
        expect(find.text('Günün Namazları'), findsNothing);
        expect(find.text('Bu Hafta'), findsNothing);
        expect(find.text('Günlük Ort.'), findsNothing);
        expect(find.text('Favori Zikirler'), findsNothing);
        expect(find.text('Tümünü Gör'), findsNothing);
        expect(find.text('Aktivite Trendleri'), findsNothing);
        expect(find.text('Son 7 Gün'), findsNothing);
        expect(find.text('Detaylar'), findsNothing);

        // Descriptive summary is rendered directly inside the profile card
        expect(find.textContaining('Manevi yolculuğun başlıyor'), findsOneWidget);

        // Profile header maintains a clean proportional height
        final headerSize = tester.getSize(find.byType(MinimalHomeHeader));
        expect(headerSize.height, greaterThanOrEqualTo(100));

        // Greeting is thin (w300) and username is bold (w800)
        final greetingText = tester.widget<Text>(find.text('Selamün Aleyküm'));
        expect(greetingText.style?.fontWeight, FontWeight.w300);

        final nameText = tester.widget<Text>(find.text('Ana Profil'));
        expect(nameText.style?.fontWeight, FontWeight.w800);

        await disposeWidgetTree(tester);
      },
    );

    testWidgets('BismillahDashboardScreen renders cleanly in dark theme without overflow', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: const BismillahDashboardScreen(),
          themeColors: AppThemeColors.dark,
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(MinimalHomeHeader), findsOneWidget);
      expect(find.byType(FavoriteZikirsCarouselCard), findsOneWidget);
      expect(find.byType(Last7DaysActivityTrendCard), findsOneWidget);

      await disposeWidgetTree(tester);
    });

    testWidgets(
      'FavoriteZikirsCarouselCard shows 1 zikir at a time with Arabic text, dots indicator and Zikre Başla button',
      (tester) async {
        final firstId = await db.into(db.zikirs).insert(
              ZikirsCompanion.insert(
                name: 'Birinci Zikir',
                arabic: const drift.Value('سُبْحَانَ اللهِ'),
                category: const drift.Value('Tesbihat'),
                totalCount: const drift.Value(500),
                currentCount: const drift.Value(12),
                target: const drift.Value(33),
              ),
            );
        final secondId = await db.into(db.zikirs).insert(
              ZikirsCompanion.insert(
                name: 'İkinci Zikir',
                arabic: const drift.Value('الْحَمْدُ لِلَّهِ'),
                category: const drift.Value('Tesbihat'),
                totalCount: const drift.Value(120),
                currentCount: const drift.Value(5),
                target: const drift.Value(99),
              ),
            );

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: FavoriteZikirsCarouselCard(),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/zikir',
              builder: (_, __) => const Scaffold(
                body: Center(child: Text('Zikir Route')),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              activeSessionProvider.overrideWithValue(UserSession.defaultSession()),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp.router(
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
                  routerConfig: router,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Favori Zikirler'), findsNothing);
        expect(find.text('Tümünü Gör'), findsNothing);
        expect(find.text('Birinci Zikir'), findsOneWidget);
        expect(find.text('İkinci Zikir'), findsNothing);
        expect(find.textContaining('سُبْحَانَ', findRichText: true), findsOneWidget);
        expect(find.byKey(const Key('favorite_zikir_dots_indicator')), findsOneWidget);
        expect(find.text('Zikre Başla'), findsOneWidget);
        expect(find.byKey(Key('favorite_zikir_continue_$firstId')), findsOneWidget);

        // Swipe horizontally to reveal the second zikir card
        await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
        await tester.pumpAndSettle();

        expect(find.text('İkinci Zikir'), findsOneWidget);
        expect(find.text('Birinci Zikir'), findsNothing);
        expect(find.textContaining('الْحَمْدُ', findRichText: true), findsOneWidget);

        final startBtn = find.byKey(Key('favorite_zikir_continue_$secondId'));
        expect(startBtn, findsOneWidget);
        await tester.tap(startBtn);
        await tester.pumpAndSettle();

        expect(container.read(selectedZikirIdProvider), secondId);
        expect(find.text('Zikir Route'), findsOneWidget);

        await disposeWidgetTree(tester);
      },
    );

    testWidgets(
      'BismillahDashboardScreen fits proportionally inside 360x740, 393x852 and 412x915 viewports above bottom bar',
      (tester) async {
        final zikirId = await db.into(db.zikirs).insert(
              ZikirsCompanion.insert(
                name: 'İstiğfar',
                arabic: const drift.Value('أَسْتَغْفِرُ اللهَ'),
                category: const drift.Value('Hadislerden Zikirler'),
                totalCount: const drift.Value(355200),
                currentCount: const drift.Value(33),
                target: const drift.Value(1000),
              ),
            );
        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        await db.into(db.zikirLogs).insert(
              ZikirLogsCompanion.insert(
                zikirId: zikirId,
                count: 1200,
                dateStr: todayStr,
              ),
            );

        for (final size in const [
          Size(360, 740),
          Size(393, 852),
          Size(412, 915),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            buildHarness(
              child: const Scaffold(
                extendBody: true,
                body: BismillahDashboardScreen(),
                bottomNavigationBar: SizedBox(
                  key: Key('mock_bottom_nav'),
                  height: 82,
                ),
              ),
              themeColors: AppThemeColors.greenLight,
              brightness: Brightness.light,
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));

          expect(
            tester.takeException(),
            isNull,
            reason: 'Unexpected layout exception at viewport $size',
          );
          expect(find.byType(MinimalHomeHeader), findsOneWidget);
          expect(find.byType(FavoriteZikirsCarouselCard), findsOneWidget);
          expect(find.byType(Last7DaysActivityTrendCard), findsOneWidget);

          final trendBottom =
              tester.getBottomLeft(find.byType(Last7DaysActivityTrendCard)).dy;
          final navTop =
              tester.getTopLeft(find.byKey(const Key('mock_bottom_nav'))).dy;
          expect(
            trendBottom,
            lessThanOrEqualTo(navTop),
            reason: 'Trend card overflowed behind bottom bar at $size',
          );

          await disposeWidgetTree(tester);
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets('DetailedStatsScreen renders treasury summary, charts, heatmap, and history', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: const DetailedStatsScreen(),
          themeColors: AppThemeColors.greenLight,
          brightness: Brightness.light,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(StatsTreasurySummaryCard), findsOneWidget);
      expect(find.byType(ActivityTrendChart), findsOneWidget);

      final outerScrollable = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(
        find.byType(ZikirDistributionDonut),
        200,
        scrollable: outerScrollable,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(ZikirDistributionDonut), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(AnnualHeatmapWidget),
        200,
        scrollable: outerScrollable,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(AnnualHeatmapWidget), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(ZikirHistorySection),
        200,
        scrollable: outerScrollable,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(ZikirHistorySection), findsOneWidget);

      await disposeWidgetTree(tester);
    });
  });
}
