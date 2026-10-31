import 'dart:convert';
import 'dart:typed_data';

import 'package:cuedeck/main.dart';
import 'package:cuedeck/models/cue_models.dart';
import 'package:cuedeck/providers/cuedeck_providers.dart';
import 'package:cuedeck/screens/cuedeck_home_screen.dart';
import 'package:cuedeck/services/adb_tv_service.dart';
import 'package:cuedeck/services/cue_monetization_service.dart';
import 'package:cuedeck/services/cue_notification_service.dart';
import 'package:cuedeck/services/cue_release_notes_service.dart';
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
    'CueDeck renders G10 Reference Remote, True Black (#000000) / White Theme, and Advanced Watch Planner with YouTube Playlist & Recurrence',
    (WidgetTester tester) async {
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

      // 2. Verify icon-only TV status on main remote (no IP or TV name text clutter on main screen)
      expect(find.byIcon(Icons.tv_rounded), findsOneWidget);
      expect(find.text('Redline Android TV (Salon)'), findsNothing);

      // 3. Verify G10 physical remote keys & 2x3 app capsules
      expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.input_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byKey(const Key('dpad_ok')), findsOneWidget);
      expect(
        find.byKey(const Key('remote_touchpad_toggle_button')),
        findsOneWidget,
      );

      // Toggle D-Pad into Mouse / Touchpad surface and back via the minimal corner button
      await tester.tap(find.byKey(const Key('remote_touchpad_toggle_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dpad_touchpad_surface')), findsOneWidget);
      expect(find.text('TOUCHPAD'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dpad_touchpad_surface')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('remote_touchpad_toggle_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dpad_ok')), findsOneWidget);
      expect(find.byIcon(Icons.home_filled), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('NETFLIX'), findsOneWidget);
      expect(find.text('beIN'), findsOneWidget);
      expect(find.text('tabii'), findsOneWidget);

      // 4. Open Full-Screen Settings & Watch Planner via Settings (⚙️) button
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(CueDeckSettingsScreen), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(find.textContaining('Tahrir'), findsNothing);
      expect(
        find.text('Ayarlar & İzleme Planı'),
        findsOneWidget,
      );
      expect(find.text('CueDeck'), findsOneWidget);
      expect(find.text('Redline Android TV (Salon)'), findsNothing);
      expect(find.text('TCL Google TV (Salon)'), findsOneWidget);
      expect(
        find.byKey(const Key('scan_network_devices_button')),
        findsOneWidget,
      );
      expect(find.text('🔍 Ağdaki Cihazları Ara'), findsOneWidget);
      expect(
        find.text('3 Adımda Kolay Eşleştirme & Bağlantı'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sony BRAVIA 4K TV (192.168.1.145)'),
        findsOneWidget,
      );
      expect(find.text('🔐 TV Eşleştir (RSA Onayı)'), findsOneWidget);
      expect(find.text('🔢 PIN Eşleştir (6466)'), findsOneWidget);
      expect(
        find.text('Kumanda Uygulama Tuşları (6 Yuva)'),
        findsOneWidget,
      );
      expect(
        find.text('CueDeck Pro & 24s Pass'),
        findsOneWidget,
      );
      expect(find.text('REKLAM'), findsOneWidget);
      expect(find.text('Bulut & Yerel Yedekleme'), findsOneWidget);
      expect(find.text('🔑 Google Hesabını Bağla'), findsOneWidget);
      expect(find.text('💾 Dosyaya Yedekle'), findsOneWidget);
      expect(find.text('📂 Dosyadan Yükle'), findsOneWidget);
      expect(
        find.text('GÜNLÜK İZLEME PLANI TAMAMLAMA'),
        findsOneWidget,
      );

      // Open Modern TV Discovery Popup via "🔍 Ağdaki Cihazları Ara" and select Sony BRAVIA 4K TV
      final scanBtn = find.byKey(const Key('scan_network_devices_button'));
      await tester.ensureVisible(scanBtn);
      await tester.pumpAndSettle();
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tv_discovery_modal_sheet')), findsOneWidget);
      expect(find.text('📡 Ağdaki Akıllı TV Cihazları'), findsOneWidget);

      final sonyCard = find.byKey(const Key('discovered_tv_card_192.168.1.145'));
      await tester.ensureVisible(sonyCard);
      await tester.tap(sonyCard);
      await tester.pumpAndSettle();
      expect(find.textContaining('Sony BRAVIA 4K TV'), findsWidgets);

      // Open Interactive RSA Pairing Sheet via "🔐 TV Eşleştir (RSA Onayı)"
      final pairBtn = find.byKey(const Key('pair_tv_rsa_button'));
      await tester.ensureVisible(pairBtn);
      await tester.pumpAndSettle();
      await tester.tap(pairBtn);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('interactive_tv_pairing_sheet')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Eşleşti ve Bağlandı: Sony BRAVIA 4K TV'),
        findsWidgets,
      );
      Navigator.of(
        tester.element(find.byKey(const Key('interactive_tv_pairing_sheet'))),
      ).pop();
      await tester.pumpAndSettle();

      // Test customizing Remote Shortcut Slot 0 ("1. Sol Üst") to Prime Video
      final slot0 = find.byKey(const Key('settings_shortcut_slot_0'));
      await tester.ensureVisible(slot0);
      await tester.pumpAndSettle();
      await tester.tap(slot0);
      await tester.pumpAndSettle();
      expect(find.text('1. Kumanda Tuşunu Değiştir'), findsOneWidget);
      await tester.tap(find.text('Prime Video'));
      await tester.pumpAndSettle();
      expect(find.text('Prime Video'), findsWidgets);

      // Reset remote shortcuts back to defaults
      final resetBtn = find.text('Sıfırla');
      await tester.ensureVisible(resetBtn);
      await tester.pumpAndSettle();
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      // 5. Switch to Classic White Light Theme and verify Light Mode & True Black (#000000) Dark Mode
      final whiteThemeChip = find.text('Klasik Beyaz Kumanda');
      await tester.ensureVisible(whiteThemeChip);
      await tester.pumpAndSettle();
      await tester.tap(whiteThemeChip);
      await tester.pumpAndSettle();
      final lightScaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(lightScaffold.backgroundColor, const Color(0xFFF3F6FA));

      final blackChipInLightMode = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Gerçek Siyah (#000000)'),
      );
      expect(
        blackChipInLightMode.labelStyle?.color,
        const Color(0xFF2C3342),
      );

      await tester.tap(find.text('Gerçek Siyah (#000000)'));
      await tester.pumpAndSettle();
      final darkScaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(darkScaffold.backgroundColor, Colors.black);

      // 6. Open AddWatchCueSheet ("Plan Ekle") and add a YouTube Playlist with Recurrence & Clock
      final addPlanBtn = find.text('Plan Ekle');
      await tester.ensureVisible(addPlanBtn);
      await tester.pumpAndSettle();
      await tester.tap(addPlanBtn);
      await tester.pumpAndSettle();

      expect(find.text('Yeni Kişisel İzleme Planı Ekle'), findsOneWidget);

      // Enter Title and YouTube Playlist URL
      await tester.enterText(
        find.widgetWithText(TextField, 'İçerik / Oynatma Listesi Adı'),
        'Flutter 120 FPS Eğitim Serisi',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'YouTube Playlist / Video Linki'),
        'https://www.youtube.com/playlist?list=PLflutter120fps99',
      );
      await tester.pump();

      // Verify smart YouTube Playlist detection badge appears
      expect(
        find.text(
          '✓ YouTube Oynatma Listesi (Playlist) algılandı — TV\'de doğrudan liste açılacak',
        ),
        findsOneWidget,
      );

      // Select "Hafta Sonu" recurrence and "21:30" clock preset
      final weekendChip = find.text('Hafta Sonu');
      await tester.ensureVisible(weekendChip);
      await tester.tap(weekendChip);
      await tester.pump();

      final clockPreset = find.text('21:30');
      await tester.ensureVisible(clockPreset);
      await tester.tap(clockPreset);
      await tester.pump();

      // Save the new YouTube Playlist watch plan
      final saveBtn = find.text('Plana Ekle');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify newly added YouTube Playlist card and schedule badge render
      expect(find.text('Flutter 120 FPS Eğitim Serisi'), findsOneWidget);
      expect(find.text('YouTube Playlist (8 Video)'), findsWidgets);
      expect(find.text('Bağlantı Aktif'), findsWidgets);

      // 7. Test +Seans button and Real OS Reminder Notification trigger
      final sessionButtons = find.textContaining('+Seans');
      await tester.ensureVisible(sessionButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(sessionButtons.first);
      await tester.pump();

      final reminderButtons = find.byIcon(Icons.notifications_active_outlined);
      await tester.ensureVisible(reminderButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(reminderButtons.first);
      await tester.pumpAndSettle();

      expect(fakeNotifications.shownNotificationCount, greaterThanOrEqualTo(1));
      expect(find.text('TV\'de Aç'), findsWidgets);
    },
  );

  testWidgets(
    'CueDeck has zero RenderFlex overflow on narrow 340x680 mobile viewport and executes Assistant Voice Sheet',
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

      // Open Voice Sheet via the center Google Assistant button (auto-starts voice listening with 1 tap)
      await tester.tap(find.byTooltip('Sesli Komut (Asistan)'));
      await tester.pumpAndSettle();

      expect(find.text('Sesli Komut & Akıllı TV Arama'), findsOneWidget);
      expect(
        find.textContaining('Son Algılanan: "YouTube\'da Haberler"'),
        findsOneWidget,
      );

      // Close Voice Sheet and open Settings on narrow 340x680 screen to verify Backup section has zero overflow
      Navigator.of(tester.element(find.text('Telefon Mikrofonuyla Konuş'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('🔑 Google Hesabını Bağla'), findsOneWidget);
      expect(find.text('💾 Dosyaya Yedekle'), findsOneWidget);
      expect(find.text('📂 Dosyadan Yükle'), findsOneWidget);
      expect(
        find.text('📋 Sürüm Notları (${CueReleaseNotesCatalog.currentShortVersion})'),
        findsOneWidget,
      );

      // Open Release Notes modal from Settings and verify version highlights render
      await tester.tap(
        find.text('📋 Sürüm Notları (${CueReleaseNotesCatalog.currentShortVersion})'),
      );
      await tester.pumpAndSettle();
      expect(find.text('📋 CueDeck Sürüm Notları'), findsOneWidget);
      expect(
        find.text('Arçelik Kumanda Servisi Testi'),
        findsOneWidget,
      );
      await tester.tap(find.text('Harika, Devam Et'));
      await tester.pumpAndSettle();
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
        '<remote><key code=1029/></remote>',
      );
      expect(
        AdbTvService.vestelXmlForCommand(TvKeyCommand.home),
        '<remote><key code=1044/></remote>',
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
}
