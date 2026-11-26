import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/app/router/app_deep_link_router.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/services/local_notification_service.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/core/widgets/notification_detail_bottom_sheet.dart';
import 'package:zikirce/features/gamification/providers/gamification_providers.dart';
import 'package:zikirce/features/gamification/services/golden_day_service.dart';
import 'package:zikirce/features/namaz_vakitleri/data/farz_32_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalNotificationService.consumeInitialNotificationPayload();
    LocalNotificationService.consumeInitialPrayerNotificationTap();
  });

  group('AppDeepLinkRouter.resolveNotificationPayload', () {
    test('routes prayer time, legacy farz, prayer question, and kaza payloads to /namaz with detail specs', () {
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('prayer_time|Öğle|1'),
        const AppNavigationIntent(
          baseRoute: '/namaz',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.prayerTimeFarz,
            prayerName: 'Öğle',
            farzId: 1,
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('farz_article|12'),
        const AppNavigationIntent(
          baseRoute: '/namaz',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.prayerTimeFarz,
            farzId: 12,
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('prayer_question|Akşam|2026-11-23'),
        const AppNavigationIntent(
          baseRoute: '/namaz',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.prayerQuestion,
            prayerName: 'Akşam',
            dateStr: '2026-11-23',
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('kaza_reminder'),
        const AppNavigationIntent(
          baseRoute: '/namaz',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.kazaReminder,
          ),
        ),
      );
    });

    test('routes special_spiritual payloads to /namaz with appropriate virtue sheet tab', () {
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('special_spiritual|feraciye'),
        const AppNavigationIntent(
          baseRoute: '/namaz',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.specialSpiritual,
            spiritualVirtueTab: 'feraciye',
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('special_spiritual|thursday_sela'),
        const AppNavigationIntent(
          baseRoute: '/namaz',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.specialSpiritual,
            spiritualVirtueTab: 'sela',
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('special_spiritual|friday_sela'),
        const AppNavigationIntent(
          baseRoute: '/namaz',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.specialSpiritual,
            spiritualVirtueTab: 'sela',
          ),
        ),
      );
    });

    test('routes quran, audio download, zikir, irfan, and stats notification payloads with detail specs', () {
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('quran_reminder'),
        const AppNavigationIntent(
          baseRoute: '/kuran',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.quranReminder,
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('quran_audio_download|completed|6236'),
        const AppNavigationIntent(
          baseRoute: '/kuran',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.quranAudioDownload,
            customTitle: 'Kur\'an Sesleri İndirildi',
            customBody:
                'Toplam 6236 ayet cihazınıza indirildi. Çevrimdışı dinleyebilirsiniz.',
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('quran_audio_download|progress|100|6236'),
        const AppNavigationIntent(
          baseRoute: '/kuran',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.quranAudioDownload,
            customTitle: 'Kur\'an Sesleri İndiriliyor',
            customBody:
                '100 / 6236 ayet indirildi. İndirme arka planda devam ediyor.',
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('zikir_reminder|42'),
        const AppNavigationIntent(
          baseRoute: '/zikir',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.zikirReminder,
            reminderItemId: 42,
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('zikir_reminder'),
        const AppNavigationIntent(
          baseRoute: '/zikir',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.zikirReminder,
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('irfan_reminder'),
        const AppNavigationIntent(
          baseRoute: '/irfan',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.irfanReminder,
          ),
        ),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('stats'),
        const AppNavigationIntent(
          baseRoute: '/',
          pushRoute: '/stats',
          notificationDetail: NotificationDetailSpec(
            kind: NotificationDetailKind.statsReminder,
          ),
        ),
      );
    });

    test('supports allowlisted direct routes and rejects invalid or unknown payloads', () {
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('/namaz'),
        const AppNavigationIntent(baseRoute: '/namaz'),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('/kuran'),
        const AppNavigationIntent(baseRoute: '/kuran'),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('/zikir'),
        const AppNavigationIntent(baseRoute: '/zikir'),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('/stats'),
        const AppNavigationIntent(baseRoute: '/', pushRoute: '/stats'),
      );
      expect(
        AppDeepLinkRouter.resolveNotificationPayload('/mushaf?page=12'),
        const AppNavigationIntent(
          baseRoute: '/kuran',
          pushRoute: '/mushaf?page=12',
        ),
      );

      expect(AppDeepLinkRouter.resolveNotificationPayload(null), isNull);
      expect(AppDeepLinkRouter.resolveNotificationPayload(''), isNull);
      expect(AppDeepLinkRouter.resolveNotificationPayload('   '), isNull);
      expect(AppDeepLinkRouter.resolveNotificationPayload('unknown_payload|1'), isNull);
      expect(AppDeepLinkRouter.resolveNotificationPayload('/not_allowlisted'), isNull);
    });
  });

  group('AppDeepLinkRouter.resolveWidgetUri', () {
    test('resolves all home widget URIs to matching pages with no notification detail sheet', () {
      final urisAndExpected = <String, AppNavigationIntent>{
        'zikirce://namaz?homeWidget':
            const AppNavigationIntent(baseRoute: '/namaz'),
        'zikirce://kuran?homeWidget':
            const AppNavigationIntent(baseRoute: '/kuran'),
        'zikirce://zikir?homeWidget':
            const AppNavigationIntent(baseRoute: '/zikir'),
        'zikirce://stats?homeWidget':
            const AppNavigationIntent(baseRoute: '/', pushRoute: '/stats'),
        'zikirce://irfan?homeWidget':
            const AppNavigationIntent(baseRoute: '/irfan'),
        'zikirce://kulliyat?bookId=book_mushaf&page=42&homeWidget':
            const AppNavigationIntent(
          baseRoute: '/kuran',
          pushRoute: '/kulliyat?bookId=book_mushaf&page=42',
        ),
        'zikirce://kulliyat?homeWidget':
            const AppNavigationIntent(baseRoute: '/kuran'),
      };

      for (final entry in urisAndExpected.entries) {
        final resolved = AppDeepLinkRouter.resolveWidgetUri(Uri.parse(entry.key));
        expect(resolved, entry.value);
        expect(resolved?.notificationDetail, isNull);
      }
    });

    test('returns null for null or unknown widget URIs', () {
      expect(AppDeepLinkRouter.resolveWidgetUri(null), isNull);
      expect(
        AppDeepLinkRouter.resolveWidgetUri(Uri.parse('zikirce://unknown?homeWidget')),
        isNull,
      );
      expect(AppDeepLinkRouter.resolveWidgetUri(Uri()), isNull);
    });
  });

  group('LocalNotificationService payload dispatch', () {
    test('buffers cold-start notification payloads when no listener is attached', () {
      for (final payload in const [
        'quran_reminder',
        'zikir_reminder|42',
        'prayer_time|İkindi|3',
        'special_spiritual|feraciye',
      ]) {
        LocalNotificationService.dispatchNotificationPayload(payload);
        expect(
          LocalNotificationService.consumeInitialNotificationPayload(),
          payload,
        );
        expect(
          LocalNotificationService.consumeInitialNotificationPayload(),
          isNull,
        );
      }

      LocalNotificationService.dispatchNotificationPayload(
        'prayer_question|Sabah|2026-11-23',
      );
      expect(
        LocalNotificationService.consumeInitialNotificationPayload(),
        'prayer_question|Sabah|2026-11-23',
      );
      final prayerTap =
          LocalNotificationService.consumeInitialPrayerNotificationTap();
      expect(prayerTap, isNotNull);
      expect(prayerTap!.prayerName, 'Sabah');
      expect(prayerTap.dateStr, '2026-11-23');
    });

    test('emits live notification payloads on unified stream and prayer stream', () async {
      final receivedPayloads = <String>[];
      final payloadSub = LocalNotificationService
          .notificationPayloadTapped.stream
          .listen(receivedPayloads.add);
      addTearDown(payloadSub.cancel);

      final prayerCompleter =
          Completer<({String prayerName, String dateStr})>();
      final prayerSub = LocalNotificationService
          .pendingPrayerNotificationTapped.stream
          .listen((event) {
        if (!prayerCompleter.isCompleted) {
          prayerCompleter.complete(event);
        }
      });
      addTearDown(prayerSub.cancel);

      const livePayloads = [
        'quran_reminder',
        'zikir_reminder|42',
        'prayer_time|İkindi|3',
        'special_spiritual|feraciye',
        'prayer_question|Sabah|2026-11-23',
      ];
      for (final p in livePayloads) {
        LocalNotificationService.dispatchNotificationPayload(p);
      }

      await pumpEventQueue();

      expect(receivedPayloads, livePayloads);
      expect(
        LocalNotificationService.consumeInitialNotificationPayload(),
        isNull,
      );

      final prayerEvent = await prayerCompleter.future;
      expect(prayerEvent.prayerName, 'Sabah');
      expect(prayerEvent.dateStr, '2026-11-23');
    });
  });

  group('NotificationDetailBottomSheet widget behavior', () {
    Widget buildSheetTestHarness({
      required String targetPageMarker,
      required NotificationDetailSpec spec,
    }) {
      return ProviderScope(
        overrides: [
          dailyGoalsStatusProvider.overrideWith(
            (ref) async => const DailyGoalsStatus(
              todayKuranPages: 2,
              kuranGoal: 5,
              todayZikirCount: 33,
              zikirGoal: 100,
            ),
          ),
        ],
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
              body: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(targetPageMarker),
                  ElevatedButton(
                    key: const Key('open_sheet_btn'),
                    onPressed: () {
                      NotificationDetailBottomSheet.show(context, spec: spec);
                    },
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('opens 32 Farz detail sheet on top of prayer page and keeps user on prayer page when closed', (tester) async {
      final firstFarz = kFarz32List.firstWhere((f) => f.id == 1);
      await tester.pumpWidget(
        buildSheetTestHarness(
          targetPageMarker: 'TargetPageNamaz',
          spec: const NotificationDetailSpec(
            kind: NotificationDetailKind.prayerTimeFarz,
            prayerName: 'Öğle',
            farzId: 1,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      expect(find.text('🕌 Öğle Vakti'), findsOneWidget);
      expect(find.text(firstFarz.title), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('🕌 Öğle Vakti'), findsNothing);
      expect(find.text('TargetPageNamaz'), findsOneWidget);
    });

    testWidgets('opens Quran reminder bottom sheet and keeps user on Quran page when dismissed', (tester) async {
      await tester.pumpWidget(
        buildSheetTestHarness(
          targetPageMarker: 'TargetPageKuran',
          spec: const NotificationDetailSpec(
            kind: NotificationDetailKind.quranReminder,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Günlük Kur\'an Hatırlatması'), findsOneWidget);
      expect(find.text('Bugünkü Hedef: 2 / 5 sayfa'), findsOneWidget);

      await tester.tap(find.text('Kur\'an Sayfasına Geç'));
      await tester.pumpAndSettle();

      expect(find.text('Günlük Kur\'an Hatırlatması'), findsNothing);
      expect(find.text('TargetPageKuran'), findsOneWidget);
    });

    testWidgets('opens Zikir reminder bottom sheet and keeps user on Zikir page when dismissed', (tester) async {
      await tester.pumpWidget(
        buildSheetTestHarness(
          targetPageMarker: 'TargetPageZikir',
          spec: const NotificationDetailSpec(
            kind: NotificationDetailKind.zikirReminder,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Günlük Zikir Hatırlatması'), findsOneWidget);
      expect(find.text('Bugünkü Hedef: 33 / 100 zikir'), findsOneWidget);

      await tester.tap(find.text('Zikre Başla'));
      await tester.pumpAndSettle();

      expect(find.text('Günlük Zikir Hatırlatması'), findsNothing);
      expect(find.text('TargetPageZikir'), findsOneWidget);
    });

    testWidgets('opens dismissible Prayer Question bottom sheet and keeps user on prayer page when closed', (tester) async {
      await tester.pumpWidget(
        buildSheetTestHarness(
          targetPageMarker: 'TargetPageNamazQuestion',
          spec: const NotificationDetailSpec(
            kind: NotificationDetailKind.prayerQuestion,
            prayerName: 'İkindi',
            dateStr: '2026-11-23',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      expect(find.text('İkindi Namazı'), findsOneWidget);
      expect(find.text('İkindi namazınızı kıldınız mı?'), findsOneWidget);
      expect(find.text('Evet, Kıldım'), findsOneWidget);
      expect(find.text('Hayır, Kazaya Ekle'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('İkindi namazınızı kıldınız mı?'), findsNothing);
      expect(find.text('TargetPageNamazQuestion'), findsOneWidget);
    });
  });
}
