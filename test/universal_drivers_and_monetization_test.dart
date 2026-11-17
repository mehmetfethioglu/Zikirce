import 'dart:convert';

import 'package:cuedeck/models/cue_models.dart';
import 'package:cuedeck/providers/cuedeck_providers.dart';
import 'package:cuedeck/services/adb_tv_service.dart';
import 'package:cuedeck/services/crypto/tv_secret_vault.dart';
import 'package:cuedeck/services/cue_monetization_service.dart';
import 'package:cuedeck/services/cue_notification_service.dart';
import 'package:cuedeck/services/drivers/lg_webos_driver.dart';
import 'package:cuedeck/services/drivers/roku_philips_vidaa_driver.dart';
import 'package:cuedeck/services/drivers/samsung_tizen_driver.dart';
import 'package:cuedeck/services/drivers/youtube_dial_beam_service.dart';
import 'package:cuedeck/services/share/cue_share_intent_service.dart';
import 'package:cuedeck/widgets/modals/cue_pro_paywall_sheet.dart';
import 'package:cuedeck/widgets/modals/share_to_tv_beam_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestCueNotificationService extends CueNotificationService {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> syncScheduledReminders(
    List<WatchCueItem> items, {
    DateTime? now,
  }) async =>
      items.length;
}

class _TestAdbTvService extends AdbTvService {
  int launchedDeepLinkCount = 0;
  String lastLaunchedUrl = '';

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
  }) async =>
      const <TvDevice>[
        TvDevice(
          name: 'Test Samsung Tizen',
          ip: '192.168.1.40',
          port: 8002,
          protocol: TvConnectionProtocol.samsungTizen8001,
          isOnline: true,
          isPaired: true,
        ),
      ];

  @override
  Future<bool> launchPlatformOrDeepLink(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async {
    launchedDeepLinkCount++;
    lastLaunchedUrl = deepLinkUrl;
    return true;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'SamsungTizenDriver formats WSS token URLs, token extraction, key and IME frames',
    () {
      final tlsUrl = SamsungTizenDriver.buildWebSocketUrl(
        '192.168.1.40',
        useTls: true,
        token: 'tok99',
      );
      expect(
        tlsUrl,
        'wss://192.168.1.40:8002/api/v2/channels/samsung.remote.control?name=Q3VlRGVjaw==&token=tok99',
      );
      expect(
        SamsungTizenDriver.buildWebSocketUrl('192.168.1.40', useTls: false),
        'ws://192.168.1.40:8001/api/v2/channels/samsung.remote.control?name=Q3VlRGVjaw==',
      );

      expect(
        SamsungTizenDriver.extractConnectToken(
          '{"event":"ms.channel.connect","data":{"token":"xyz123"}}',
        ),
        'xyz123',
      );
      expect(
        SamsungTizenDriver.extractConnectToken('{"event":"other"}'),
        isNull,
      );

      final keyPayload = jsonDecode(
        SamsungTizenDriver.buildControlPayload(TvKeyCommand.ok),
      ) as Map<String, dynamic>;
      expect(keyPayload['method'], 'ms.remote.control');
      expect((keyPayload['params'] as Map)['DataOfCmd'], 'KEY_ENTER');

      final imePayload = jsonDecode(
        SamsungTizenDriver.buildImeTextPayload('CueDeck'),
      ) as Map<String, dynamic>;
      expect(
        (imePayload['params'] as Map)['Cmd'],
        base64.encode(utf8.encode('CueDeck')),
      );
      expect(
        (imePayload['params'] as Map)['TypeOfRemote'],
        'SendInputString',
      );
    },
  );

  test(
    'LgWebOsDriver builds SSAP register payload, D-Pad pointer button map, move and scroll frames',
    () {
      final reg = LgWebOsDriver.buildRegisterPayload(clientKey: 'lg-key-1');
      expect(reg['type'], 'register');
      final regPayload = reg['payload']! as Map<String, Object?>;
      expect(regPayload['client-key'], 'lg-key-1');

      expect(LgWebOsDriver.pointerButtonNameForKey(TvKeyCommand.up), 'UP');
      expect(LgWebOsDriver.pointerButtonNameForKey(TvKeyCommand.down), 'DOWN');
      expect(LgWebOsDriver.pointerButtonNameForKey(TvKeyCommand.left), 'LEFT');
      expect(
        LgWebOsDriver.pointerButtonNameForKey(TvKeyCommand.right),
        'RIGHT',
      );
      expect(LgWebOsDriver.pointerButtonNameForKey(TvKeyCommand.ok), 'ENTER');
      expect(LgWebOsDriver.pointerButtonNameForKey(TvKeyCommand.back), 'BACK');
      expect(LgWebOsDriver.pointerButtonNameForKey(TvKeyCommand.home), 'HOME');

      final moveFrame = LgWebOsDriver.buildPointerMoveFrame(10, -20);
      expect(moveFrame, startsWith('type:move\n'));
      expect(moveFrame, contains('drag:0\n\n'));

      expect(
        LgWebOsDriver.buildPointerScrollFrame(3),
        'type:scroll\ndx:0\ndy:120\n\n',
      );
      expect(LgWebOsDriver.buildPointerClickFrame(), 'type:click\n\n');
    },
  );

  test(
    'RokuEcpDriver maps remote keys and YouTube deep-link / playlist launch paths',
    () {
      expect(RokuEcpDriver.mapKey(TvKeyCommand.ok), 'Select');
      expect(RokuEcpDriver.mapKey(TvKeyCommand.back), 'Back');
      expect(RokuEcpDriver.mapKey(TvKeyCommand.home), 'Home');

      expect(
        RokuEcpDriver.buildLaunchPath(
          StreamingPlatform.youtube,
          deepLinkUrl: 'https://www.youtube.com/watch?v=abc123&list=PL999',
        ),
        '/launch/837?contentId=abc123&playlistId=PL999',
      );
      expect(
        RokuEcpDriver.buildLaunchPath(
          StreamingPlatform.youtube,
          deepLinkUrl: 'https://www.youtube.com/playlist?list=PLonly99',
        ),
        '/launch/837?playlistId=PLonly99',
      );
    },
  );

  test(
    'IrBlasterDriver encodes NEC, Samsung32, RC5, and Sony12 pulses across 7 brand profiles',
    () {
      expect(IrBlasterDriver.brandProfiles.length, 7);

      final nec = IrBlasterDriver.buildNecFrame(0x04, 0x08);
      expect(nec.take(2), <int>[9000, 4500]);
      expect(nec.length, 67);

      final s32 = IrBlasterDriver.buildSamsung32Frame(0x0707, 0x02);
      expect(s32.take(2), <int>[4500, 4500]);
      expect(s32.length, 67);

      final rc5 = IrBlasterDriver.buildRc5Frame(0x00, 0x0C);
      expect(rc5, isNotEmpty);

      final sony = IrBlasterDriver.buildSony12Frame(0x01, 0x15);
      expect(sony.first, 2400);

      for (final brand in IrBlasterDriver.brandProfiles.keys) {
        final dev = TvDevice(
          name: brand,
          ip: '',
          port: 0,
          protocol: TvConnectionProtocol.irBlasterHardware,
          irBrandCode: brand,
        );
        final generated =
            IrBlasterDriver.buildPatternForDevice(dev, TvKeyCommand.power);
        expect(generated, isNotNull);
        expect(generated!.carrierHz, greaterThanOrEqualTo(36000));
        expect(generated.pattern, isNotEmpty);
      }
    },
  );

  test(
    'WakeOnLanService builds exact 102-byte Magic Packet and rejects invalid MACs',
    () {
      final packet = WakeOnLanService.buildMagicPacket('AA:BB:CC:11:22:33');
      expect(packet.length, 102);
      expect(packet.sublist(0, 6), List<int>.filled(6, 0xFF));
      expect(
        packet.sublist(6, 12),
        const <int>[0xAA, 0xBB, 0xCC, 0x11, 0x22, 0x33],
      );
      expect(
        packet.sublist(96, 102),
        const <int>[0xAA, 0xBB, 0xCC, 0x11, 0x22, 0x33],
      );

      expect(WakeOnLanService.buildMagicPacket('invalid-mac'), isEmpty);
    },
  );

  test(
    'YoutubeDialBeamService builds DIAL payloads for youtu.be, shorts, playlist and watch URLs',
    () {
      expect(
        YoutubeDialBeamService.buildYoutubeDialPayload(
          deepLinkUrl: 'https://youtu.be/xyz12345678',
        ),
        'v=xyz12345678',
      );
      expect(
        YoutubeDialBeamService.buildYoutubeDialPayload(
          deepLinkUrl: 'https://www.youtube.com/shorts/short999',
        ),
        'v=short999',
      );
      expect(
        YoutubeDialBeamService.buildYoutubeDialPayload(
          deepLinkUrl: 'https://www.youtube.com/playlist?list=PL888999',
        ),
        'list=PL888999',
      );
      expect(
        YoutubeDialBeamService.buildYoutubeDialPayload(
          deepLinkUrl: 'https://www.youtube.com/watch?v=vid1&list=PL888999',
        ),
        'v=vid1&list=PL888999',
      );
    },
  );

  test(
    'CueShareIntentService extracts URLs & platforms from raw share text and custom URIs',
    () {
      final sharedYt = CueShareIntentService.parseSharedText(
        'Harika video: https://youtu.be/vid999',
      );
      expect(sharedYt, isNotNull);
      expect(sharedYt!.platform, StreamingPlatform.youtube);
      expect(sharedYt.url, 'https://youtu.be/vid999');
      expect(sharedYt.title, 'Harika video');

      final sharedCustom = CueShareIntentService.parseSharedText(
        'cuedeck://share?url=https%3A%2F%2Fwww.youtube.com%2Fplaylist%3Flist%3DPLshare123',
      );
      expect(sharedCustom, isNotNull);
      expect(sharedCustom!.platform, StreamingPlatform.youtube);
      expect(
        sharedCustom.url,
        'https://www.youtube.com/playlist?list=PLshare123',
      );
    },
  );

  test(
    'CueMonetizationService enforces 3-tier Pro upgrades and 3/day free Share-to-TV beam quota',
    () async {
      final service = CueMonetizationService();
      final day1 = DateTime(2026, 11, 17, 20, 0);
      var state = const CueEntitlementState();

      // 1. Consuming 3 free daily beams succeeds, 4th triggers paywall gate
      for (var i = 0; i < CueProProductCatalog.maxFreeDailyBeams; i++) {
        final r = await service.consumeDailyBeamQuota(current: state, now: day1);
        expect(r.success, isTrue);
        state = r.entitlement;
      }
      final blocked4th = await service.consumeDailyBeamQuota(
        current: state,
        now: day1,
      );
      expect(blocked4th.success, isFalse);

      // Next calendar day resets daily free quota
      final day2 = DateTime(2026, 11, 18, 9, 0);
      final day2Beam = await service.consumeDailyBeamQuota(
        current: state,
        now: day2,
      );
      expect(day2Beam.success, isTrue);

      // 2. Purchasing Annual 3-Day Trial, Weekly, Lifetime, and Loyalty40 works
      final weekly = await service.purchasePlanTier(
        CuePlanTier.weekly,
        current: state,
        now: day2,
      );
      expect(weekly.success, isTrue);
      expect(weekly.entitlement.isSubscriptionActive(day2), isTrue);
      expect(weekly.entitlement.hasProAccess(day2), isTrue);

      final annual = await service.purchasePlanTier(
        CuePlanTier.annualTrial,
        current: weekly.entitlement,
        now: day2,
      );
      expect(annual.success, isTrue);
      expect(annual.entitlement.purchasedSku, CueProProductCatalog.skuProAnnual);

      final life = await service.purchasePlanTier(
        CuePlanTier.lifetime,
        current: const CueEntitlementState(),
        now: day2,
      );
      expect(life.success, isTrue);
      expect(life.entitlement.isProLifetime, isTrue);

      // Pro bypasses beam quota indefinitely
      final unlimited = await service.consumeDailyBeamQuota(
        current: life.entitlement,
        now: day1,
      );
      expect(unlimited.success, isTrue);
      expect(unlimited.entitlement.remainingDailyFreeBeams(day1), 9999);
    },
  );

  testWidgets(
    'ShareToTvBeamSheet beams links immediately via YouTube DIAL / ADB and closes cleanly',
    (WidgetTester tester) async {
      final fakeAdb = _TestAdbTvService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adbTvServiceProvider.overrideWithValue(fakeAdb),
            cueNotificationServiceProvider.overrideWithValue(
              _TestCueNotificationService(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showShareToTvBeamSheet(
                          context,
                          SharedCuePayload(
                            url: 'https://www.youtube.com/playlist?list=PLwidget1',
                            title: 'Flutter Playlist',
                            platform: StreamingPlatform.youtube,
                            receivedAtEpochMs: 1700000000000,
                          ),
                        );
                      },
                      child: const Text('Open Share Sheet'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Share Sheet'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('share_to_tv_beam_sheet')), findsOneWidget);
      expect(
        find.text(
          'Bugün kalan ücretsiz ışınlama: 3 / ${CueProProductCatalog.maxFreeDailyBeams}',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('share_sheet_launch_now_button')));
      await tester.pumpAndSettle();

      expect(fakeAdb.launchedDeepLinkCount, 1);
      expect(
        fakeAdb.lastLaunchedUrl,
        'https://www.youtube.com/playlist?list=PLwidget1',
      );
    },
  );

  testWidgets(
    'CueProPaywallSheet renders with zero RenderFlex overflow on 340x680 viewport and switches plans',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340, 680);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adbTvServiceProvider.overrideWithValue(_TestAdbTvService()),
            cueNotificationServiceProvider.overrideWithValue(
              _TestCueNotificationService(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CueProPaywallSheet(
                reasonMessage: 'Günlük ücretsiz hak doldu.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('cue_pro_paywall_sheet')), findsOneWidget);
      expect(find.text('3 Gün Ücretsiz Dene'), findsOneWidget);

      await tester.tap(find.byKey(const Key('paywall_tier_weekly')));
      await tester.pumpAndSettle();
      expect(find.text('Seçili Planı Başlat'), findsOneWidget);

      await tester.tap(find.byKey(const Key('paywall_tier_lifetime')));
      await tester.pumpAndSettle();
      expect(find.text('Seçili Planı Başlat'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
}
