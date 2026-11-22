import 'dart:convert';
import 'dart:typed_data';

import 'package:cuedeck/main.dart';
import 'package:cuedeck/models/cue_models.dart';
import 'package:cuedeck/providers/cuedeck_providers.dart';
import 'package:cuedeck/screens/cuedeck_home_screen.dart';
import 'package:cuedeck/services/adb_tv_service.dart';
import 'package:cuedeck/services/cue_monetization_service.dart';
import 'package:cuedeck/services/cue_notification_service.dart';
import 'package:cuedeck/services/share/cue_share_intent_service.dart';
import 'package:cuedeck/widgets/tactile_dpad_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCueNotificationService extends CueNotificationService {
  int shownNotificationCount = 0;
  int syncedAlarmCount = 0;
  String? lastNotificationTitle;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> showReminderNotification(
    WatchCueItem item, {
    bool isLeadReminder = false,
  }) async {
    shownNotificationCount++;
    lastNotificationTitle = item.title;
    return true;
  }

  @override
  Future<int> syncScheduledReminders(
    List<WatchCueItem> items, {
    DateTime? now,
  }) async {
    final payloads = CueNotificationService.buildAlarmPayloads(items, now: now);
    syncedAlarmCount = payloads.length;
    return syncedAlarmCount;
  }
}

class _FakeAdbTvService extends AdbTvService {
  _FakeAdbTvService();

  @override
  Future<bool> pingTv(
    String ip, {
    int port = 5555,
    Duration timeout = const Duration(milliseconds: 220),
    bool warmupRetry = false,
  }) async =>
      true;

  @override
  Future<List<TvDevice>> discoverDevices({
    String preferredIp = '',
    bool forceFullSubnetScan = false,
  }) async {
    return <TvDevice>[
      const TvDevice(
        name: 'TCL Google TV (Salon)',
        ip: '192.168.1.42',
        port: 5555,
        boardInfo: 'TCL • Google TV 12',
        isOnline: true,
      ),
      const TvDevice(
        name: 'Sony BRAVIA 4K TV',
        ip: '192.168.1.145',
        port: 5555,
        boardInfo: 'Sony BRAVIA • Android TV 12',
        isOnline: true,
      ),
      const TvDevice(
        name: 'Arçelik 43" Smart TV',
        ip: '192.168.1.188',
        port: 8085,
        protocol: TvConnectionProtocol.arcelikGrundig8085,
        boardInfo: 'Arçelik Smart Inter@ctive TV • Port 8085 Aktif',
        isOnline: true,
        isPaired: true,
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> startPin6467PairingSession(
    TvDevice device, {
    int pairingPort = 6467,
    bool forceRestart = false,
  }) async {
    return <String, dynamic>{
      'pinDisplayed': true,
      'adb5555Open': true,
      'message':
          'TV ekranında 6 haneli PIN kodu gösteriliyor (${device.ip}). Lütfen ekrandaki kodu girin.',
    };
  }

  @override
  Future<TvDevice> pairWithTv(TvDevice device) async {
    return device.copyWith(
      name: 'Sony BRAVIA 4K TV',
      boardInfo: 'Sony BRAVIA • Android TV 12 (RSA Eşleşti)',
      isOnline: true,
    );
  }

  @override
  Future<TvDevice> pairWithPin6466(
    TvDevice device,
    String sixDigitPin, {
    int pairingPort = 6467,
  }) async {
    return device.copyWith(
      port: 6466,
      protocol: TvConnectionProtocol.remotePort6466,
      isPaired: true,
      isOnline: true,
      boardInfo: 'Google TV • Standart Mod (PIN Eşleşti • Port 6466)',
    );
  }

  int mouseEnabledCount = 0;
  int mouseDisabledCount = 0;
  int mouseClickCount = 0;
  int mouseWheelScrollCount = 0;
  int lastWheelClicks = 0;
  final List<String> typedTexts = <String>[];
  int backspaceCount = 0;
  int enterKeyCount = 0;

  @override
  Future<bool> enableTvMouseCursor(TvDevice device) async {
    mouseEnabledCount++;
    return true;
  }

  @override
  Future<void> disableTvMouseCursor(TvDevice device) async {
    mouseDisabledCount++;
  }

  @override
  Future<bool> moveTvMouseCursor(
    TvDevice device,
    double dx,
    double dy,
  ) async =>
      true;

  @override
  Future<bool> clickTvMouseCursor(
    TvDevice device, {
    bool rightClick = false,
  }) async {
    mouseClickCount++;
    return true;
  }

  @override
  Future<bool> scrollTvMouseWheel(TvDevice device, int wheelClicks) async {
    mouseWheelScrollCount++;
    lastWheelClicks = wheelClicks;
    return true;
  }

  @override
  Future<bool> sendSearchText(
    TvDevice device,
    String rawText, {
    bool submitEnter = false,
  }) async {
    typedTexts.add(rawText);
    if (submitEnter) enterKeyCount++;
    return true;
  }

  @override
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) async {
    backspaceCount += count;
    return true;
  }

  @override
  Future<bool> sendEnterKey(TvDevice device) async {
    enterKeyCount++;
    return true;
  }

  @override
  Future<bool> sendKeyCommand(TvDevice device, TvKeyCommand command) async =>
      true;

  @override
  Future<bool> launchPlatformOrDeepLink(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async =>
      true;

  @override
  Future<String?> listenPhoneMicrophone({String locale = 'tr-TR'}) async =>
      'YouTube\'da Haberler';

  @override
  Future<String> executeVoiceCommand(
    TvDevice device,
    String transcript,
  ) async =>
      '🎙️ Sesli komut çalıştırıldı: "$transcript"';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'CueDeck renders G10 Reference Remote, Plan Card Carousel, Bottom Touchpad, Simplified Settings, and Theme Switcher',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeNotifications = _FakeCueNotificationService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adbTvServiceProvider.overrideWithValue(_FakeAdbTvService()),
            cueNotificationServiceProvider.overrideWithValue(fakeNotifications),
          ],
          child: const CueDeckApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify True Black (#000000) Dark Mode default & no bottom NavigationBar
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF000000));
      expect(find.byType(NavigationBar), findsNothing);
      expect(fakeNotifications.syncedAlarmCount, greaterThan(0));

      // 2. Verify icon-only TV status on main remote
      expect(find.byIcon(Icons.tv_rounded), findsOneWidget);
      expect(find.text('Redline Android TV (Salon)'), findsNothing);

      // 3. Verify G10 remote keys, Plan toggle, Modern Mic, Mouse Cursor Arrow & 2-slot App Dock
      expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.input_rounded), findsOneWidget);
      expect(find.byKey(const Key('remote_plan_toggle_button')), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
      expect(find.byKey(const Key('remote_voice_button')), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byKey(const Key('dpad_ok')), findsOneWidget);
      expect(
        find.byKey(const Key('remote_keyboard_toggle_button')),
        findsOneWidget,
      );
      final touchpadToggle = find.byKey(
        const Key('remote_touchpad_toggle_button'),
      );
      expect(touchpadToggle, findsOneWidget);
      expect(
        find.descendant(
          of: touchpadToggle,
          matching: find.byType(MouseCursorArrowIcon),
        ),
        findsOneWidget,
      );

      // Only 2 quick-launch app buttons (YouTube & NETFLIX) and no bottom utility chips
      final appDock = find.byType(QuickLaunchAppDock);
      expect(
        find.descendant(of: appDock, matching: find.text('YouTube')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: appDock, matching: find.text('NETFLIX')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: appDock, matching: find.text('beIN')),
        findsNothing,
      );
      expect(
        find.descendant(of: appDock, matching: find.text('tabii')),
        findsNothing,
      );
      expect(
        find.descendant(of: appDock, matching: find.text('CueTV Ulusal')),
        findsNothing,
      );
      expect(
        find.descendant(of: appDock, matching: find.text('Zikirce')),
        findsNothing,
      );
      expect(find.byKey(const Key('remote_link_beam_chip')), findsNothing);
      expect(find.byKey(const Key('remote_ir_mode_chip')), findsNothing);

      // Plan deck is active by default; toggling Plan hides & re-opens it WITHOUT opening keyboard
      expect(find.byKey(const Key('remote_plan_deck')), findsOneWidget);
      await tester.tap(find.byKey(const Key('remote_plan_toggle_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote_keyboard_sheet')), findsNothing);
      expect(find.byKey(const Key('remote_plan_deck')), findsNothing);

      await tester.tap(find.byKey(const Key('remote_plan_toggle_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote_plan_deck')), findsOneWidget);

      // Open Keyboard button and type live with phone keyboard
      await tester.tap(find.byKey(const Key('remote_keyboard_toggle_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote_keyboard_sheet')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('remote_keyboard_text_field')),
        'Gassal',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('remote_keyboard_backspace_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('remote_keyboard_send_button')));
      await tester.pumpAndSettle();

      // Switch Bottom Deck to Touchpad while keeping Donut D-Pad visible
      await tester.tap(touchpadToggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dpad_ok')), findsOneWidget);
      expect(find.byKey(const Key('remote_touchpad_deck')), findsOneWidget);
      expect(find.byKey(const Key('dpad_touchpad_surface')), findsOneWidget);
      expect(find.byKey(const Key('touchpad_scroll_wheel')), findsOneWidget);
      expect(find.byKey(const Key('touchpad_wheel_up_button')), findsOneWidget);
      expect(find.byKey(const Key('touchpad_wheel_down_button')), findsOneWidget);
      expect(find.byKey(const Key('touchpad_left_click_button')), findsOneWidget);
      expect(find.byKey(const Key('touchpad_right_click_button')), findsOneWidget);
      expect(find.byKey(const Key('touchpad_sensitivity_chip')), findsOneWidget);
      expect(find.text('TOUCHPAD'), findsOneWidget);

      await tester.tap(find.byKey(const Key('touchpad_sensitivity_chip')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('touchpad_wheel_up_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('touchpad_wheel_down_button')));
      await tester.pump();
      await tester.drag(
        find.byKey(const Key('touchpad_scroll_wheel')),
        const Offset(0, -36),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byKey(const Key('dpad_touchpad_surface')));
      await tester.pump();
      await tester.drag(
        find.byKey(const Key('dpad_touchpad_surface')),
        const Offset(35, -20),
      );
      await tester.pump(const Duration(milliseconds: 40));

      // Tapping Plan button switches smoothly from Touchpad back to Plan Cards
      await tester.tap(find.byKey(const Key('remote_plan_toggle_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote_plan_deck')), findsOneWidget);
      expect(find.byKey(const Key('remote_touchpad_deck')), findsNothing);
      expect(find.byKey(const Key('dpad_ok')), findsOneWidget);
      expect(find.byIcon(Icons.home_filled), findsOneWidget);

      // 4. Add a YouTube Playlist from the remote's "+ Ekle" button on Plan Carousel
      final addDeckPlanBtn = find.byKey(const Key('deck_add_plan_button'));
      await tester.ensureVisible(addDeckPlanBtn);
      await tester.tap(addDeckPlanBtn);
      await tester.pumpAndSettle();

      expect(find.text('Yeni Kişisel İzleme Planı Ekle'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'İçerik / Oynatma Listesi Adı'),
        'Flutter 120 FPS Eğitim Serisi',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'YouTube Playlist / Video Linki'),
        'https://www.youtube.com/playlist?list=PLflutter120fps99',
      );
      await tester.pump();
      expect(
        find.text(
          '✓ YouTube Oynatma Listesi (Playlist) algılandı — TV\'de doğrudan liste açılacak',
        ),
        findsOneWidget,
      );

      final weekendChip = find.text('Hafta Sonu');
      await tester.ensureVisible(weekendChip);
      await tester.tap(weekendChip);
      await tester.pump();

      final saveBtn = find.text('Plana Ekle');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Nearest plan card is visible; tap it to open WatchPlanDetailSheet and test +Seans & reminder
      final nearestCard = find.byKey(
        const Key('plan_deck_card_cue_yt_playlist_1'),
      );
      await tester.ensureVisible(nearestCard);
      await tester.tap(nearestCard);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('watch_plan_detail_sheet')), findsOneWidget);
      await tester.tap(find.textContaining('+Seans').first);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.notifications_active_outlined).first);
      await tester.pumpAndSettle();
      expect(fakeNotifications.shownNotificationCount, greaterThanOrEqualTo(1));
      expect(find.text('TV\'de Aç'), findsWidgets);

      Navigator.of(
        tester.element(find.byKey(const Key('watch_plan_detail_sheet'))),
      ).pop();
      await tester.pumpAndSettle();

      // 5. Open Simplified Settings Screen via Settings (⚙️) button
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(CueDeckSettingsScreen), findsOneWidget);
      expect(find.text('Ayarlar'), findsOneWidget);
      expect(find.text('Ayarlar & İzleme Planı'), findsNothing);
      expect(find.text('GÜNLÜK İZLEME PLANI TAMAMLAMA'), findsNothing);
      expect(find.text('3 Adımda Kolay Eşleştirme & Bağlantı'), findsNothing);
      expect(find.text('TCL Google TV (Salon)'), findsOneWidget);
      expect(
        find.byKey(const Key('scan_network_devices_button')),
        findsOneWidget,
      );
      expect(find.text('Ağdaki Cihazları Ara'), findsOneWidget);
      expect(find.text('Kumanda & Görünüm'), findsOneWidget);
      expect(find.text('CueDeck Pro'), findsOneWidget);
      expect(find.text('Bulut & Yerel Yedekleme'), findsOneWidget);
      expect(find.text('REKLAM'), findsOneWidget);

      // Expand Gelişmiş Bağlantı to verify RSA / PIN / IP actions
      await tester.tap(
        find.byKey(const Key('settings_advanced_connection_toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pair_tv_rsa_button')), findsOneWidget);
      expect(find.byKey(const Key('pair_tv_pin_button')), findsOneWidget);

      // Open Modern TV Discovery Popup via "Ağdaki Cihazları Ara" and select Sony BRAVIA 4K TV
      final scanBtn = find.byKey(const Key('scan_network_devices_button'));
      await tester.ensureVisible(scanBtn);
      await tester.pumpAndSettle();
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tv_discovery_modal_sheet')), findsOneWidget);

      final sonyCard = find.byKey(const Key('discovered_tv_card_192.168.1.145'));
      await tester.ensureVisible(sonyCard);
      await tester.tap(sonyCard);
      await tester.pumpAndSettle();
      expect(find.textContaining('Sony BRAVIA 4K TV'), findsWidgets);

      // Open Interactive RSA Pairing Sheet
      final pairBtn = find.byKey(const Key('pair_tv_rsa_button'));
      await tester.ensureVisible(pairBtn);
      await tester.pumpAndSettle();
      await tester.tap(pairBtn);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('interactive_tv_pairing_sheet')),
        findsOneWidget,
      );
      Navigator.of(
        tester.element(find.byKey(const Key('interactive_tv_pairing_sheet'))),
      ).pop();
      await tester.pumpAndSettle();

      // Customize Remote Shortcut Slot 0 ("1. Sol Tuş") to Prime Video and reset
      final slot0 = find.byKey(const Key('settings_shortcut_slot_0'));
      await tester.ensureVisible(slot0);
      await tester.pumpAndSettle();
      await tester.tap(slot0);
      await tester.pumpAndSettle();
      expect(find.text('1. Kumanda Tuşunu Değiştir'), findsOneWidget);
      await tester.tap(find.text('Prime Video'));
      await tester.pumpAndSettle();
      expect(find.text('Prime Video'), findsWidgets);

      final resetBtn = find.text('Sıfırla');
      await tester.ensureVisible(resetBtn);
      await tester.pumpAndSettle();
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      // Switch between Light and True Black Dark themes
      final lightThemeChip = find.byKey(const Key('theme_light_chip'));
      await tester.ensureVisible(lightThemeChip);
      await tester.tap(lightThemeChip);
      await tester.pumpAndSettle();
      final lightScaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(lightScaffold.backgroundColor, const Color(0xFFF3F6FA));

      final darkThemeChip = find.byKey(const Key('theme_dark_chip'));
      await tester.tap(darkThemeChip);
      await tester.pumpAndSettle();
      final darkScaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(darkScaffold.backgroundColor, Colors.black);

      // Open Backup Management bottom sheet
      final backupTile = find.byKey(const Key('settings_backup_tile'));
      await tester.ensureVisible(backupTile);
      await tester.tap(backupTile);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backup_management_sheet')), findsOneWidget);
      expect(find.text('Google Hesabını Bağla'), findsOneWidget);
      expect(find.text('Dosyaya Yedekle'), findsOneWidget);
      expect(find.text('Dosyadan Yükle'), findsOneWidget);
      Navigator.of(
        tester.element(find.byKey(const Key('backup_management_sheet'))),
      ).pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'CueDeck has zero RenderFlex overflow on narrow 340x680 mobile viewport and executes Assistant Voice Sheet & Release Notes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340, 680);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adbTvServiceProvider.overrideWithValue(_FakeAdbTvService()),
          ],
          child: const CueDeckApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Open Voice Sheet via the center Modern Mic button
      await tester.tap(find.byKey(const Key('remote_voice_button')));
      await tester.pumpAndSettle();

      expect(find.text('Sesli Komut & Akıllı TV Arama'), findsOneWidget);
      expect(
        find.textContaining('Son Algılanan: "YouTube\'da Haberler"'),
        findsOneWidget,
      );

      // Close Voice Sheet and open Simplified Settings on narrow 340x680 screen
      Navigator.of(tester.element(find.text('Telefon Mikrofonuyla Konuş'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final releaseTile = find.byKey(const Key('settings_release_notes_tile'));
      await tester.ensureVisible(releaseTile);
      await tester.tap(releaseTile);
      await tester.pumpAndSettle();
      expect(find.text('📋 CueDeck Sürüm Notları'), findsOneWidget);
      expect(
        find.text('Telefon Klavyesiyle Anında TV\'ye Yazma'),
        findsOneWidget,
      );
      await tester.tap(find.text('Harika, Devam Et'));
      await tester.pumpAndSettle();
    },
  );

  test(
    'WatchCueItem.sortNearestFirst orders upcoming items nearest-to-farthest and relativeScheduleLabel formats accurately',
    () {
      final now = DateTime(2026, 11, 22, 15, 0); // Sunday
      final completedSoon = WatchCueItem(
        id: 'done',
        title: 'Tamamlanan',
        subtitle: '',
        platform: StreamingPlatform.youtube,
        scheduledTime: now.add(const Duration(minutes: 5)),
        totalMinutes: 30,
        watchedMinutes: 30,
        recurrence: WatchRecurrence.once,
      );
      final in15m = WatchCueItem(
        id: 'in_15m',
        title: '15 dk',
        subtitle: '',
        platform: StreamingPlatform.youtube,
        scheduledTime: now.add(const Duration(minutes: 15)),
        totalMinutes: 30,
        recurrence: WatchRecurrence.once,
      );
      final todayEvening = WatchCueItem(
        id: 'today_21',
        title: 'Bugün 21:00',
        subtitle: '',
        platform: StreamingPlatform.netflix,
        scheduledTime: DateTime(2026, 11, 22, 21, 0),
        totalMinutes: 45,
        recurrence: WatchRecurrence.daily,
      );
      final tomorrowMorning = WatchCueItem(
        id: 'tomorrow',
        title: 'Yarın 09:00',
        subtitle: '',
        platform: StreamingPlatform.youtube,
        scheduledTime: DateTime(2026, 11, 23, 9, 0),
        totalMinutes: 45,
        recurrence: WatchRecurrence.once,
      );
      final nextFriday = WatchCueItem(
        id: 'next_fri',
        title: 'Cuma 20:00',
        subtitle: '',
        platform: StreamingPlatform.tabii,
        scheduledTime: DateTime(2026, 11, 27, 20, 0),
        totalMinutes: 60,
        recurrence: WatchRecurrence.once,
      );

      final sorted = WatchCueItem.sortNearestFirst(
        <WatchCueItem>[
          nextFriday,
          completedSoon,
          tomorrowMorning,
          todayEvening,
          in15m,
        ],
        now: now,
      );
      expect(
        sorted.map((e) => e.id).toList(),
        <String>['in_15m', 'today_21', 'tomorrow', 'next_fri', 'done'],
      );
      expect(in15m.relativeScheduleLabel(now: now), '15 dk sonra');
      expect(todayEvening.relativeScheduleLabel(now: now), 'Bugün 21:00');
      expect(tomorrowMorning.relativeScheduleLabel(now: now), 'Yarın 09:00');
      expect(nextFriday.relativeScheduleLabel(now: now), 'Cum 20:00');
      expect(completedSoon.relativeScheduleLabel(now: now), 'Tamamlandı');
    },
  );

  test(
    'CueShareIntentService parses YouTube watch, youtu.be, shorts, live, and playlist links',
    () {
      final watch = CueShareIntentService.parseSharedText(
        'Harika Belgesel: https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(watch, isNotNull);
      expect(watch!.platform, StreamingPlatform.youtube);
      expect(watch.title, 'Harika Belgesel');

      final short = CueShareIntentService.parseSharedText(
        'https://www.youtube.com/shorts/short999',
      );
      expect(short, isNotNull);
      expect(short!.platform, StreamingPlatform.youtube);
      expect(short.title, 'YouTube Shorts');

      final live = CueShareIntentService.parseSharedText(
        'https://www.youtube.com/live/liveStream1',
      );
      expect(live, isNotNull);
      expect(live!.platform, StreamingPlatform.youtube);
      expect(live.title, 'YouTube Videosu');

      final playlist = CueShareIntentService.parseSharedText(
        'https://www.youtube.com/playlist?list=PLplaylist123',
      );
      expect(playlist, isNotNull);
      expect(playlist!.platform, StreamingPlatform.youtube);
      expect(playlist.title, 'YouTube Oynatma Listesi');

      final shortUrl = CueShareIntentService.parseSharedText(
        'https://youtu.be/abc12345678',
      );
      expect(shortUrl, isNotNull);
      expect(shortUrl!.platform, StreamingPlatform.youtube);
    },
  );

  test(
    'CueReleaseNotesService detects first launch of new version and persists seen state',
    () async {
      const service = CueReleaseNotesService();
      expect(
        await service.shouldShowWhatsNewOnStartup(allowInTest: true),
        isTrue,
      );
      await service.markCurrentVersionSeen();
      expect(
        await service.getLastSeenVersion(),
        CueReleaseNotesCatalog.currentVersion,
      );
      expect(
        await service.shouldShowWhatsNewOnStartup(allowInTest: true),
        isFalse,
      );
    },
  );

  test(
    'WatchCueItem computes progressPercent, playlist ID, and recurrence scheduleBadgeText accurately',
    () {
      final now = DateTime(2026, 10, 27, 21, 30);
      final normalized = WatchCueItem.normalizeContentLink(
        StreamingPlatform.youtube,
        'PL998877665544',
      );
      expect(
        normalized,
        'https://www.youtube.com/playlist?list=PL998877665544',
      );

      final item = WatchCueItem(
        id: 'test_1',
        title: 'Test Playlist',
        subtitle: 'Liste',
        platform: StreamingPlatform.youtube,
        scheduledTime: now,
        totalMinutes: 100,
        watchedMinutes: 45,
        sessionMinutes: 30,
        currentEpisode: 2,
        totalEpisodes: 5,
        deepLinkUrl: normalized,
        recurrence: WatchRecurrence.customDays,
        activeWeekdays: const <int>[1, 3, 5],
      );

      expect(item.progressPercent, 45);
      expect(item.remainingMinutes, 55);
      expect(item.isCompleted, isFalse);
      expect(item.isYoutubePlaylist, isTrue);
      expect(item.youtubePlaylistId, 'PL998877665544');
      expect(item.recurrenceSummary, 'Pzt, Çar, Cum');
      expect(item.scheduleBadgeText, contains('21:30 • Pzt, Çar, Cum • 30dk/seans'));
      expect(item.checkpointSummary, contains('Video 2/5'));
    },
  );

  test(
    'AdbRsaAuthenticator generates valid 256-byte RSA-2048 signature and 524-byte Android RSAPublicKey payload',
    () async {
      final auth = AdbRsaAuthenticator();
      await auth.ensureLoaded();
      expect(auth.isReady, isTrue);

      final token = Uint8List.fromList(List<int>.generate(20, (i) => i + 1));
      final signature = auth.signAdbTokenSync(token);
      expect(signature.length, 256);
      expect(signature.any((b) => b != 0), isTrue);

      final pubKeyPayload = auth.encodeAdbPublicKeyPayloadSync();
      final pubKeyText = ascii.decode(pubKeyPayload);
      expect(pubKeyText.endsWith(' cuedeck@akarworks\x00'), isTrue);

      final b64Part = pubKeyText.split(' ').first;
      final structBytes = base64.decode(b64Part);
      expect(structBytes.length, 524);

      final view = ByteData.sublistView(structBytes);
      // modulus_size_words == 64 (2048 bits)
      expect(view.getUint32(0, Endian.little), 64);
      // exponent == 65537
      expect(view.getUint32(520, Endian.little), 65537);
    },
  );

  test(
    'CueNotificationService builds both lead-reminder and exact start-time OS alarm payloads',
    () {
      final now = DateTime(2026, 10, 28, 20, 0);
      final cue = WatchCueItem(
        id: 'notif_test_1',
        title: 'Gece Maratonu',
        subtitle: '1. Sezon',
        platform: StreamingPlatform.netflix,
        scheduledTime: DateTime(2026, 10, 28, 21, 30),
        totalMinutes: 120,
        watchedMinutes: 30,
        sessionMinutes: 45,
        recurrence: WatchRecurrence.daily,
        reminderMinutesBefore: 15,
      );

      final nextRem = cue.nextReminderDateTime(now);
      final nextWatch = cue.nextWatchDateTime(now);
      expect(nextRem, DateTime(2026, 10, 28, 21, 15));
      expect(nextWatch, DateTime(2026, 10, 28, 21, 30));

      final payloads = CueNotificationService.buildAlarmPayloads(
        <WatchCueItem>[cue],
        now: now,
      );
      expect(payloads.length, 2);
      expect(payloads.first['title'], contains('15 dk sonra: Gece Maratonu'));
      expect(payloads.first['isLeadReminder'], isTrue);
      expect(
        payloads.first['watchStartMillis'],
        nextWatch!.millisecondsSinceEpoch,
      );
      expect(payloads.last['title'], contains('İzleme Vakti (21:30) • Netflix'));
      expect(payloads.last['isLeadReminder'], isFalse);
    },
  );

  test(
    'CueMonetizationService enforces 24h Rewarded Pro Pass, AdMob IVT cooldown, 10-day 40% Loyalty Discount, and SHA-256 tamper protection',
    () async {
      final service = CueMonetizationService();
      var state = await service.loadEntitlement();
      expect(state.hasProAccess(), isFalse);
      expect(state.rewardedDaysCount, 0);

      // 1. Grant 24h Pro Pass on Day 1
      final day1 = DateTime(2026, 10, 1, 20, 0);
      final res1 = await service.grantRewardedProPass(
        current: state,
        now: day1,
      );
      expect(res1.success, isTrue);
      state = res1.entitlement;
      expect(state.isProPassActive(day1.add(const Duration(hours: 2))), isTrue);
      expect(
        state.isProPassActive(day1.add(const Duration(hours: 25))),
        isFalse,
      );
      expect(state.rewardedDaysCount, 1);

      // 2. Verify AdMob Invalid Traffic (IVT) cooldown blocks immediate spam
      final spamRes = await service.grantRewardedProPass(
        current: state,
        now: day1.add(const Duration(minutes: 10)),
      );
      expect(spamRes.success, isFalse);

      // 3. Accumulate 10 distinct calendar days to unlock 40% Loyalty Discount
      for (var d = 2; d <= 10; d++) {
        final nextDay = DateTime(2026, 10, d, 20, 0);
        final r = await service.grantRewardedProPass(
          current: state,
          now: nextDay,
        );
        expect(r.success, isTrue);
        state = r.entitlement;
      }
      expect(state.rewardedDaysCount, 10);
      expect(state.isLoyaltyDiscountUnlocked, isTrue);
      expect(
        state.activeProductSku,
        CueProProductCatalog.skuProLoyalty40,
      );

      // 4. Purchase Lifetime Pro and verify persistence & SHA-256 integrity seal
      final purchaseRes = await service.purchaseLifetimePro(
        current: state,
        now: DateTime(2026, 10, 11, 21, 0),
      );
      expect(purchaseRes.success, isTrue);
      expect(purchaseRes.entitlement.isProLifetime, isTrue);
      expect(
        purchaseRes.entitlement.purchasedSku,
        CueProProductCatalog.skuProLoyalty40,
      );

      final reloaded = await service.loadEntitlement();
      expect(reloaded.isProLifetime, isTrue);
      expect(reloaded.hasProAccess(), isTrue);
    },
  );

  test(
    'AdbTvService validates 6-digit/hex PIN and builds Port 6466/6467 Android TV Remote v2 protobuf frames',
    () {
      expect(AdbTvService.isValidSixDigitPin('123456'), isTrue);
      expect(AdbTvService.isValidSixDigitPin('12345'), isFalse);
      expect(AdbTvService.isValidSixDigitPin('12a456'), isFalse);
      expect(AdbTvService.isValidPairingPinCode('123456'), isTrue);
      expect(AdbTvService.isValidPairingPinCode('A1B2C3'), isTrue);

      final initFrames = AdbTvService.buildPin6467InitiationFrames(
        clientName: 'CueDeck',
      );
      expect(initFrames.length, 3);
      for (final f in initFrames) {
        expect(f.isNotEmpty, isTrue);
        expect(f[0], f.length - 1);
      }

      final secretFrame = AdbTvService.buildPin6467SecretFrame('A1B2C3');
      expect(secretFrame.isNotEmpty, isTrue);
      expect(secretFrame[0], secretFrame.length - 1);

      final frame = AdbTvService.buildRemote6466KeyFrame(
        TvKeyCommand.ok.keyCode,
      );
      expect(frame.isNotEmpty, isTrue);
      // First byte is varint message length
      expect(frame[0], frame.length - 1);
      // Second byte is RemoteMessage.remote_key_inject tag (0x52)
      expect(frame[1], 0x52);
    },
  );

  test(
    'Smart TV protocols support Arçelik/Grundig Port 8085, Vestel/Arçelik Port 56789, Samsung Tizen Port 8001, LG webOS Port 3000, Philips 1925, and Roku 8060',
    () {
      expect(
        TvConnectionProtocol.fromNameOrPort('', 8085),
        TvConnectionProtocol.arcelikGrundig8085,
      );
      expect(
        TvConnectionProtocol.fromNameOrPort('', 56789),
        TvConnectionProtocol.vestelSmart56789,
      );
      expect(
        TvConnectionProtocol.fromNameOrPort('', 8001),
        TvConnectionProtocol.samsungTizen8001,
      );
      expect(
        TvConnectionProtocol.fromNameOrPort('', 3000),
        TvConnectionProtocol.lgWebOs3000,
      );
      expect(
        TvConnectionProtocol.fromNameOrPort('', 1925),
        TvConnectionProtocol.philipsJointSpace1925,
      );
      expect(
        TvConnectionProtocol.fromNameOrPort('', 8060),
        TvConnectionProtocol.rokuEcp8060,
      );
      expect(TvConnectionProtocol.arcelikGrundig8085.isNonAndroidSmartTv, isTrue);
      expect(TvConnectionProtocol.vestelSmart56789.isNonAndroidSmartTv, isTrue);
      expect(TvConnectionProtocol.adbPort5555.isNonAndroidSmartTv, isFalse);

      expect(
        AdbTvService.arcelikGrundigQueryForCommand(TvKeyCommand.ok),
        'keyid=-2490&keysymbol=13',
      );
      expect(
        AdbTvService.arcelikGrundigQueryForCommand(TvKeyCommand.volUp),
        'keyid=-2475&keysymbol=-4020',
      );
      expect(
        AdbTvService.vestelXmlForCommand(TvKeyCommand.ok),
        '<remote><key code=1053/></remote>',
      );
      expect(
        AdbTvService.vestelXmlForCommand(TvKeyCommand.home),
        '<remote><key code=1048/></remote>',
      );
      expect(
        AdbTvService.vestelXmlForCommand(TvKeyCommand.channelUp),
        '<remote><key code=1032/></remote>',
      );
      expect(
        AdbTvService.vestelXmlForCommand(TvKeyCommand.channelDown),
        '<remote><key code=1033/></remote>',
      );
      expect(
        AdbTvService.vestelXmlForCommand(TvKeyCommand.volUp),
        '<remote><key code=1016/></remote>',
      );
      expect(
        AdbTvService.vestelXmlForCommand(TvKeyCommand.volDown),
        '<remote><key code=1017/></remote>',
      );
      expect(
        AdbTvService.vestelXmlForCommand(TvKeyCommand.power),
        '<remote><key code=1012/></remote>',
      );
      expect(
        AdbTvService.samsungKeyForCommand(TvKeyCommand.volUp),
        'KEY_VOLUP',
      );
    },
  );

  test(
    'mTLS X.509 certificate DER extraction, Polo PIN secret frame, and Port 6466 session frames work for Arçelik / Google TV',
    () async {
      final auth = AdbRsaAuthenticator();
      await auth.ensureLoaded();
      expect(auth.privateKeyPem, contains('BEGIN PRIVATE KEY'));
      expect(auth.selfSignedCertPem, contains('BEGIN CERTIFICATE'));
      expect(auth.selfSignedCertDer.isNotEmpty, isTrue);

      final extracted = AdbTvService.extractRsaModulusAndExponentFromDer(
        auth.selfSignedCertDer,
      );
      expect(extracted, isNotNull);
      expect(extracted!.modulus, equals(auth.modulusBytes));
      expect(extracted.exponent, equals(auth.publicExponentBytes));

      final poloSecretFrame = AdbTvService.buildPin6467SecretFrame(
        'A1B2C3',
        clientModulus: auth.modulusBytes,
        clientExponent: auth.publicExponentBytes,
        serverCertDer: auth.selfSignedCertDer,
      );
      expect(poloSecretFrame.isNotEmpty, isTrue);
      expect(poloSecretFrame[0], poloSecretFrame.length - 1);

      final cfgFrame = AdbTvService.buildRemote6466ConfigureFrame();
      expect(cfgFrame.isNotEmpty, isTrue);
      expect(cfgFrame[0], cfgFrame.length - 1);

      final activeFrame = AdbTvService.buildRemote6466SetActiveFrame();
      expect(activeFrame.isNotEmpty, isTrue);
      expect(activeFrame[0], activeFrame.length - 1);

      final svc = AdbTvService();
      svc.markPinPairedIp('192.168.1.44');
      expect(
        AdbTvService.buildRemote6466PingResponseFrame(7)[0],
        greaterThan(0),
      );
      expect(
        AdbTvService.buildRemote6466AppLinkFrame('https://www.youtube.com')[0],
        greaterThan(0),
      );
    },
  );

  test('describeDnsRecords decodes PTR / SRV / TXT / A of an Arçelik mDNS answer', () {
    List<int> name(String n) => <int>[
          for (final label in n.split('.')) ...<int>[
            label.length,
            ...utf8.encode(label),
          ],
          0,
        ];
    List<int> rr(String n, int type, List<int> rdata) => <int>[
          ...name(n),
          0, type, 0, 1, 0, 0, 0, 120,
          rdata.length >> 8, rdata.length & 0xFF,
          ...rdata,
        ];
    final packet = Uint8List.fromList(<int>[
      0, 0, 0x84, 0x00, 0, 0, 0, 1, 0, 0, 0, 3,
      ...rr('_arceliktvremote._tcp.local', 12, name('TV._arceliktvremote._tcp.local')),
      ...rr('TV._arceliktvremote._tcp.local', 33, <int>[0, 0, 0, 0, 0x0E, 0x71, ...name('tv.local')]),
      ...rr('TV._arceliktvremote._tcp.local', 16, <int>[7, ...utf8.encode('ver=1.0')]),
      ...rr('tv.local', 1, <int>[192, 168, 1, 106]),
    ]);
    final lines = AdbTvService.describeDnsRecords(packet);
    expect(lines, contains('PTR _arceliktvremote._tcp.local -> TV._arceliktvremote._tcp.local'));
    expect(lines, contains('SRV TV._arceliktvremote._tcp.local port=3697 hedef=tv.local'));
    expect(lines, contains('TXT TV._arceliktvremote._tcp.local -> ver=1.0'));
    expect(lines, contains('A tv.local -> 192.168.1.106'));
  });

  test(
    'AdbTvService normalizes Turkish keyboard input and builds Linux EV_REL / UHID mouse cursor payloads',
    () {
      expect(
        AdbTvService.normalizeForTvInputText('Çukur Şampiyonlar Ligi'),
        'Cukur%sSampiyonlar%sLigi',
      );
      expect(
        AdbTvService.encodeSignedInt32LeHex(15),
        r'\x0f\x00\x00\x00',
      );
      expect(
        AdbTvService.encodeSignedInt32LeHex(-15),
        r'\xf1\xff\xff\xff',
      );

      final moveCmd = AdbTvService.buildLinuxMouseMoveCommand(
        '/dev/input/event2',
        12,
        -8,
        is64BitKernel: false,
      );
      expect(moveCmd, contains('/dev/input/event2'));
      expect(moveCmd, contains(r'\x02\x00\x00\x00\x0c\x00\x00\x00'));
      expect(moveCmd, contains(r'\x02\x00\x01\x00\xf8\xff\xff\xff'));

      final clickCmd = AdbTvService.buildLinuxMouseClickCommand(
        '/dev/input/event2',
      );
      expect(clickCmd, contains(r'\x01\x00\x10\x01\x01\x00\x00\x00'));
      expect(clickCmd, contains(r'\x01\x00\x10\x01\x00\x00\x00\x00'));

      final wheelUpCmd = AdbTvService.buildLinuxMouseWheelCommand(
        '/dev/input/event2',
        2,
      );
      expect(wheelUpCmd, contains('/dev/input/event2'));
      expect(wheelUpCmd, contains(r'\x02\x00\x08\x00\x02\x00\x00\x00'));

      final wheelDownCmd = AdbTvService.buildLinuxMouseWheelCommand(
        '/dev/input/event2',
        -2,
      );
      expect(wheelDownCmd, contains(r'\x02\x00\x08\x00\xfe\xff\xff\xff'));

      final uhidHex = AdbTvService.buildUhidMouseCreateHexEscapes();
      expect(uhidHex.startsWith(r'\x0b\x00\x00\x00'), isTrue);
      // 332 bytes * 4 chars (\xHH) == 1328 chars
      expect(uhidHex.length, 332 * 4);
    },
  );
}
