import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cuedeck/models/cue_models.dart';
import 'package:cuedeck/providers/cuedeck_providers.dart';
import 'package:cuedeck/services/adb_tv_service.dart';
import 'package:cuedeck/services/crypto/tv_secret_vault.dart';
import 'package:cuedeck/services/cue_monetization_service.dart';
import 'package:cuedeck/services/cue_notification_service.dart';
import 'package:cuedeck/services/discovery/tv_discovery_helpers.dart';
import 'package:cuedeck/services/drivers/arcelik_vestel_upnp_driver.dart';
import 'package:cuedeck/services/drivers/lg_webos_driver.dart';
import 'package:cuedeck/services/drivers/roku_philips_vidaa_driver.dart';
import 'package:cuedeck/services/drivers/samsung_tizen_driver.dart';
import 'package:cuedeck/services/drivers/tv_driver_registry.dart';
import 'package:cuedeck/services/drivers/youtube_dial_beam_service.dart';
import 'package:cuedeck/services/share/cue_share_intent_service.dart';
import 'package:cuedeck/widgets/modals/cue_pro_paywall_sheet.dart';
import 'package:cuedeck/widgets/modals/share_to_tv_beam_sheet.dart';
import 'package:cuedeck/widgets/modals/wake_on_lan_setup_sheet.dart';
import 'package:cuedeck/widgets/remote/g10_remote_chassis.dart';
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

class _HealingTestAdbTvService extends _TestAdbTvService {
  _HealingTestAdbTvService({
    this.upgradeOnVerify = false,
    this.reachableOnVerify = true,
  });

  final bool upgradeOnVerify;
  final bool reachableOnVerify;
  final List<(TvConnectionProtocol, int, TvKeyCommand)> sentKeys =
      <(TvConnectionProtocol, int, TvKeyCommand)>[];
  int verifyCalls = 0;

  @override
  Future<bool> sendKeyCommand(TvDevice device, TvKeyCommand command) async {
    sentKeys.add((device.protocol, device.port, command));
    if (device.protocol == TvConnectionProtocol.rokuEcp8060 &&
        command == TvKeyCommand.channelUp) {
      return false;
    }
    if (device.protocol == TvConnectionProtocol.lgWebOs3000 &&
        command == TvKeyCommand.channelUp) {
      return false;
    }
    return true;
  }

  @override
  Future<String> executeVoiceCommand(
    TvDevice device,
    String rawSpokenText,
  ) async =>
      '⚡ Sesli komut sinyali gönderildi: "$rawSpokenText"';

  @override
  Future<TvDevice> verifyOrReconnectDevice(TvDevice device) async {
    verifyCalls++;
    if (!reachableOnVerify) {
      return device.copyWith(isOnline: false);
    }
    if (upgradeOnVerify) {
      return device.copyWith(
        port: 56789,
        protocol: TvConnectionProtocol.vestelSmart56789,
        isOnline: true,
        isPaired: true,
      );
    }
    return device.copyWith(isOnline: true);
  }
}

class _OfflineNoTvTestAdbTvService extends _TestAdbTvService {
  @override
  Future<bool> pingTv(
    String ip, {
    int port = 5555,
    Duration timeout = const Duration(milliseconds: 220),
    bool warmupRetry = false,
  }) async =>
      false;

  @override
  Future<List<TvDevice>> discoverDevices({
    String preferredIp = '',
    bool forceFullSubnetScan = false,
  }) async =>
      const <TvDevice>[];
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
    'LgWebOsDriver builds SSAP register payload, channel permissions, D-Pad & channel pointer button map, move and scroll frames',
    () {
      final reg = LgWebOsDriver.buildRegisterPayload(clientKey: 'lg-key-1');
      expect(reg['type'], 'register');
      final regPayload = reg['payload']! as Map<String, Object?>;
      expect(regPayload['client-key'], 'lg-key-1');
      final manifest = regPayload['manifest']! as Map<String, Object?>;
      final signed = manifest['signed']! as Map<String, Object?>;
      final perms = signed['permissions']! as List<String>;
      expect(
        perms,
        containsAll(<String>[
          'CONTROL_TV_CHANNEL',
          'READ_CURRENT_CHANNEL',
          'READ_TV_CHANNEL_LIST',
        ]),
      );

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
      expect(
        LgWebOsDriver.pointerButtonNameForKey(TvKeyCommand.channelUp),
        'CHANNELUP',
      );
      expect(
        LgWebOsDriver.pointerButtonNameForKey(TvKeyCommand.channelDown),
        'CHANNELDOWN',
      );

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

  test(
    'AdbTvService ADB fast key uses input keyevent for channel keys and guards event0 against 64-bit kernels',
    () {
      expect(
        AdbTvService.buildFastKeyShellCommand(TvKeyCommand.channelUp),
        'input keyevent 166',
      );
      expect(
        AdbTvService.buildFastKeyShellCommand(TvKeyCommand.channelDown),
        'input keyevent 167',
      );
      final okShell = AdbTvService.buildFastKeyShellCommand(TvKeyCommand.ok);
      expect(okShell, contains('aarch64'));
      expect(okShell, contains('x86_64'));
      expect(okShell, contains('input keyevent 23'));
    },
  );

  test(
    'CueDeckNotifier.sendRemoteKey keeps TV online when single key fails on reachable TV and upgrades DIAL to SmartCenter',
    () async {
      final reachableService = _HealingTestAdbTvService(
        upgradeOnVerify: false,
        reachableOnVerify: true,
      );
      final container1 = ProviderContainer(
        overrides: [
          adbTvServiceProvider.overrideWithValue(reachableService),
          cueNotificationServiceProvider.overrideWithValue(
            _TestCueNotificationService(),
          ),
        ],
      );
      addTearDown(container1.dispose);

      container1.read(cueDeckProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      const lgTv = TvDevice(
        name: 'LG webOS Test',
        ip: '192.168.1.55',
        port: 3001,
        protocol: TvConnectionProtocol.lgWebOs3000,
        isOnline: true,
        isPaired: true,
      );
      final notifier1 = container1.read(cueDeckProvider.notifier);
      notifier1.selectDevice(lgTv);
      await notifier1.sendRemoteKey(TvKeyCommand.channelUp);

      final state1 = container1.read(cueDeckProvider);
      expect(reachableService.verifyCalls, 1);
      expect(state1.selectedDevice.isOnline, isTrue);

      await notifier1.runVoiceTranscript('sessiz');
      expect(container1.read(cueDeckProvider).selectedDevice.isOnline, isTrue);
      expect(reachableService.verifyCalls, 2);

      final upgradingService = _HealingTestAdbTvService(
        upgradeOnVerify: true,
        reachableOnVerify: true,
      );
      final container2 = ProviderContainer(
        overrides: [
          adbTvServiceProvider.overrideWithValue(upgradingService),
          cueNotificationServiceProvider.overrideWithValue(
            _TestCueNotificationService(),
          ),
        ],
      );
      addTearDown(container2.dispose);

      container2.read(cueDeckProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      const misclassifiedTv = TvDevice(
        name: 'Vestel / Smart TV',
        ip: '192.168.1.60',
        port: 8060,
        protocol: TvConnectionProtocol.rokuEcp8060,
        isOnline: true,
        isPaired: true,
      );
      final notifier2 = container2.read(cueDeckProvider.notifier);
      notifier2.selectDevice(misclassifiedTv);
      await notifier2.sendRemoteKey(TvKeyCommand.channelUp);

      final state2 = container2.read(cueDeckProvider);
      expect(state2.selectedDevice.isOnline, isTrue);
      expect(
        state2.selectedDevice.protocol,
        TvConnectionProtocol.vestelSmart56789,
      );
      expect(state2.selectedDevice.port, 56789);
      expect(upgradingService.sentKeys, <(TvConnectionProtocol, int, TvKeyCommand)>[
        (TvConnectionProtocol.rokuEcp8060, 8060, TvKeyCommand.channelUp),
        (TvConnectionProtocol.vestelSmart56789, 56789, TvKeyCommand.channelUp),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 25));
    },
  );

  test(
    'ArcelikGrundigDriver.vestelKeyCodeForCommand returns verified Regal/Vestel codes without 1067 or 1014',
    () {
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.up), 1020);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.down), 1019);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.left), 1021);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.right), 1022);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.ok), 1053);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.back), 1010);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.home), 1048);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.menu), 1048);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.inputs), 1056);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.volUp), 1016);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.volDown), 1017);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.mute), 1013);
      expect(ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.power), 1012);
      expect(
        ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.channelUp),
        1032,
      );
      expect(
        ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.channelDown),
        1033,
      );
      expect(
        ArcelikGrundigDriver.vestelKeyCodeForCommand(TvKeyCommand.search),
        1046,
      );

      for (final cmd in TvKeyCommand.values) {
        final code = ArcelikGrundigDriver.vestelKeyCodeForCommand(cmd);
        expect(code, isNot(1067), reason: '1067 opens System Settings on Vestel');
        expect(code, isNot(1014), reason: '1014 opens Picture Presets on Vestel');
      }
    },
  );

  test(
    'YoutubeDialBeamService uses DIAL before Vestel fallback and never sends 1067 or 1059',
    () async {
      final prevOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevOverrides);

      final requests = <String>[];
      var return404ForDial = false;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        requests.add('${req.method} ${req.uri.path}');
        req.response.statusCode = return404ForDial ? 404 : 201;
        await req.response.close();
      });

      final vault = EncryptedTvSecretVault();
      final ssdpLocs = <String, String>{};
      final dialUrls = <String, String>{
        '127.0.0.1': 'http://127.0.0.1:${server.port}/apps/',
      };
      final registry = TvDriverRegistry(
        vault: vault,
        openLanSocket: (ip, port, {required Duration timeout}) =>
            Socket.connect(ip, port, timeout: timeout),
        ssdpLocationUrls: ssdpLocs,
        dialAppUrls: dialUrls,
      );
      addTearDown(registry.dispose);

      final beam = YoutubeDialBeamService(
        dialAppUrls: dialUrls,
        registry: registry,
      );
      final rawKeys = <int>[];
      const vestelDev = TvDevice(
        name: 'Regal Smart TV',
        ip: '127.0.0.1',
        port: 56789,
        protocol: TvConnectionProtocol.vestelSmart56789,
        isOnline: true,
        isPaired: true,
      );

      final ytDialOk = await beam.launchOnSmartTv(
        vestelDev,
        platform: StreamingPlatform.youtube,
        sendVestelRawKey: (ip, code) async {
          rawKeys.add(code);
          return true;
        },
      );
      expect(ytDialOk, isTrue);
      expect(requests, contains('POST /apps/YouTube'));
      expect(rawKeys, isEmpty);

      return404ForDial = true;
      dialUrls['127.0.0.1'] = 'http://127.0.0.1:${server.port}/apps/';
      final nfFallbackOk = await beam.launchOnSmartTv(
        vestelDev,
        platform: StreamingPlatform.netflix,
        sendVestelRawKey: (ip, code) async {
          rawKeys.add(code);
          return true;
        },
      );
      expect(nfFallbackOk, isTrue);
      expect(rawKeys, contains(1064));
      expect(rawKeys, isNot(contains(1059)));

      rawKeys.clear();
      final ytFallbackOk = await beam.launchOnSmartTv(
        vestelDev,
        platform: StreamingPlatform.youtube,
        sendVestelRawKey: (ip, code) async {
          rawKeys.add(code);
          return true;
        },
      );
      expect(ytFallbackOk, isTrue);
      expect(rawKeys, contains(1046));
      expect(rawKeys, isNot(contains(1067)));
    },
  );

  testWidgets(
    'G10PhysicalRemoteChassis mute icon starts unmuted (volume_up) and toggles cleanly with SES/KNL labels',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adbTvServiceProvider.overrideWithValue(_HealingTestAdbTvService()),
            cueNotificationServiceProvider.overrideWithValue(
              _TestCueNotificationService(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Center(
                  child: G10PhysicalRemoteChassis(isDarkMode: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('SES'), findsOneWidget);
      expect(find.text('KNL'), findsOneWidget);

      final muteBtn = find.byKey(const Key('remote_mute_button'));
      expect(muteBtn, findsOneWidget);
      expect(
        find.descendant(
          of: muteBtn,
          matching: find.byIcon(Icons.volume_up_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(muteBtn);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: muteBtn,
          matching: find.byIcon(Icons.volume_off_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Ses +'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: muteBtn,
          matching: find.byIcon(Icons.volume_up_rounded),
        ),
        findsOneWidget,
      );

      final element = tester.element(muteBtn);
      final container = ProviderScope.containerOf(element);
      await tester.tap(muteBtn);
      await tester.pumpAndSettle();
      expect(container.read(cueDeckProvider).isMuted, isTrue);

      container.read(cueDeckProvider.notifier).selectDevice(
        const TvDevice(
          name: 'Another TV',
          ip: '192.168.1.99',
          port: 5555,
          isOnline: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(cueDeckProvider).isMuted, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  test(
    'TvNetworkValidators normalizes MACs and rejects all-zero, broadcast, and malformed values',
    () {
      expect(
        TvNetworkValidators.normalizeMacAddress('aa:bb:cc:11:22:33'),
        'AA:BB:CC:11:22:33',
      );
      expect(
        TvNetworkValidators.normalizeMacAddress('aa-bb-cc-11-22-33'),
        'AA:BB:CC:11:22:33',
      );
      expect(
        TvNetworkValidators.normalizeMacAddress('aabb.cc11.2233'),
        'AA:BB:CC:11:22:33',
      );
      expect(
        TvNetworkValidators.normalizeMacAddress('aabbcc112233'),
        'AA:BB:CC:11:22:33',
      );
      expect(
        TvNetworkValidators.normalizeMacAddress('00:00:00:00:00:00'),
        isEmpty,
      );
      expect(
        TvNetworkValidators.normalizeMacAddress('ff:ff:ff:ff:ff:ff'),
        isEmpty,
      );
      expect(TvNetworkValidators.normalizeMacAddress('bad-mac'), isEmpty);

      expect(TvNetworkValidators.isValidMacAddress('AA:BB:CC:11:22:33'), isTrue);
      expect(TvNetworkValidators.isValidMacAddress('aa-bb-cc-11-22-33'), isTrue);
      expect(TvNetworkValidators.isValidMacAddress('00:00:00:00:00:00'), isFalse);
      expect(TvNetworkValidators.isValidMacAddress('FF:FF:FF:FF:FF:FF'), isFalse);
      expect(TvNetworkValidators.isValidMacAddress('AABBCC112233'), isFalse);

      const wolOnlyDev = TvDevice(
        name: 'Offline TV',
        ip: '',
        port: 5555,
        macAddress: 'AA:BB:CC:11:22:33',
      );
      expect(wolOnlyDev.hasValidMac, isTrue);
      expect(wolOnlyDev.hasControlTarget, isTrue);
      expect(wolOnlyDev.displayEndpoint, 'WoL • AA:BB:CC:11:22:33');
      expect(
        wolOnlyDev.protocolBadgeLabel,
        'Wake-on-LAN • Kapalı TV Uyandırma',
      );
    },
  );

  test(
    'TvDiscoveryHelpers extracts MAC addresses from SSDP, XML, JSON (excluding bssid), mDNS TXT, and ADB shell output',
    () {
      // 1. SSDP WAKEUP header
      const ssdp = 'HTTP/1.1 200 OK\r\n'
          'ST: urn:dial-multiscreen-org:service:dial:1\r\n'
          'WAKEUP: MAC=aa:bb:cc:11:22:33;Timeout=10\r\n\r\n';
      expect(
        TvDiscoveryHelpers.extractMacFromSsdpResponse(ssdp),
        'AA:BB:CC:11:22:33',
      );

      // 2. Roku XML (ethernet vs wifi preference) & UPnP XML
      const rokuEthXml = '<device-info>'
          '<network-type>ethernet</network-type>'
          '<wifi-mac>11:22:33:44:55:66</wifi-mac>'
          '<ethernet-mac>AA:BB:CC:DD:EE:01</ethernet-mac>'
          '</device-info>';
      expect(
        TvDiscoveryHelpers.extractMacFromXmlMetadata(rokuEthXml),
        'AA:BB:CC:DD:EE:01',
      );
      const rokuWifiXml = '<device-info>'
          '<network-type>wifi</network-type>'
          '<ethernet-mac>AA:BB:CC:DD:EE:01</ethernet-mac>'
          '<wifi-mac>11:22:33:44:55:66</wifi-mac>'
          '</device-info>';
      expect(
        TvDiscoveryHelpers.extractMacFromXmlMetadata(rokuWifiXml),
        '11:22:33:44:55:66',
      );
      const upnpXml = '<root><device><macAddress>de:ad:be:ef:00:01</macAddress></device></root>';
      expect(
        TvDiscoveryHelpers.extractMacFromXmlMetadata(upnpXml),
        'DE:AD:BE:EF:00:01',
      );

      // 3. JSON metadata (Samsung wifiMac, Cast mac_address, ignore bssid)
      expect(
        TvDiscoveryHelpers.extractMacFromJsonMetadata(<String, Object?>{
          'device': <String, Object?>{'wifiMac': '12:34:56:ab:cd:ef'},
        }),
        '12:34:56:AB:CD:EF',
      );
      expect(
        TvDiscoveryHelpers.extractMacFromJsonMetadata(<String, Object?>{
          'bssid': '99:88:77:66:55:44',
          'mac_address': '22:33:44:55:66:77',
        }),
        '22:33:44:55:66:77',
      );
      expect(
        TvDiscoveryHelpers.extractMacFromJsonMetadata(<String, Object?>{
          'bssid': '99:88:77:66:55:44',
          'name': 'Living Room TV',
        }),
        isEmpty,
      );

      // 4. mDNS TXT packet with deviceid=AA:BB:CC:DD:EE:FF
      final txtPayload = ascii.encode('deviceid=aa:bb:cc:dd:ee:ff');
      final mdnsPacket = Uint8List.fromList(<int>[
        0x00, 0x00, 0x84, 0x00,
        0x00, 0x00, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00,
        4, ...ascii.encode('tv01'), 5, ...ascii.encode('local'), 0x00,
        0x00, 0x10, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x78,
        0x00, (txtPayload.length + 1),
        txtPayload.length, ...txtPayload,
      ]);
      expect(
        TvDiscoveryHelpers.extractMacFromMdnsPacket(mdnsPacket),
        'AA:BB:CC:DD:EE:FF',
      );

      // 5. ADB shell output
      expect(
        TvDiscoveryHelpers.extractMacFromShellOutput(
          'Xiaomi\nMiTV\nmtk\n11\nMAC=12:34:56:78:9a:bc\n',
        ),
        '12:34:56:78:9A:BC',
      );
    },
  );

  test(
    'All TV drivers and AdbTvService fall back to Wake-on-LAN on TvKeyCommand.power for offline / MAC-only devices',
    () async {
      final prevOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevOverrides);

      final vault = EncryptedTvSecretVault();
      final upnp = UpnpDlnaDriver(ssdpLocationUrls: <String, String>{});
      final arcelik = ArcelikGrundigDriver(
        openLanSocket: (host, port, {required Duration timeout}) =>
            Socket.connect(host, port, timeout: timeout),
        upnpFallback: upnp,
        dialAppUrls: <String, String>{},
      );
      final vestel = VestelSmartCenterDriver(arcelikDelegate: arcelik);
      final philips = PhilipsJointSpaceDriver(vault: vault);
      final sony = SonyBraviaIrccDriver(vault: vault);
      final vidaa = VidaaSmartDriver(vault: vault, allowWebSocketFallback: false);
      final roku = RokuEcpDriver();
      final samsung = SamsungTizenDriver(vault: vault);
      final lg = LgWebOsDriver(vault: vault);
      final adb = AdbTvService(secretVault: vault);

      addTearDown(() {
        arcelik.dispose();
        vidaa.dispose();
        samsung.dispose();
        lg.dispose();
        adb.dispose();
      });

      const mac = 'AA:BB:CC:11:22:33';
      // Empty-IP (MAC-only) offline devices + unreachable localhost closed port
      for (final driver in [
        philips,
        sony,
        vidaa,
        vestel,
        arcelik,
        upnp,
        roku,
        samsung,
        lg,
      ]) {
        final macOnlyDevice = TvDevice(
          name: 'Offline ${driver.protocol.name}',
          ip: '',
          port: driver.protocol.defaultPort,
          protocol: driver.protocol,
          macAddress: mac,
        );
        expect(
          await driver.sendKey(macOnlyDevice, TvKeyCommand.power),
          isTrue,
          reason: '${driver.protocol.name} should WoL-wake on empty-IP power key',
        );
        expect(
          await driver.sendKey(macOnlyDevice, TvKeyCommand.volUp),
          isFalse,
          reason: '${driver.protocol.name} must not WoL-wake on non-power keys',
        );
      }

      // Also verify closed local port (offline TV with saved IP + MAC) falls back to WoL
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = server.port;
      await server.close();

      final offlineResults = await Future.wait<bool>(<Future<bool>>[
        philips.sendKey(
          TvDevice(
            name: 'Offline Philips',
            ip: '127.0.0.1',
            port: closedPort,
            protocol: TvConnectionProtocol.philipsJointSpace1925,
            macAddress: mac,
          ),
          TvKeyCommand.power,
        ),
        sony.sendKey(
          TvDevice(
            name: 'Offline Sony',
            ip: '127.0.0.1',
            port: closedPort,
            protocol: TvConnectionProtocol.sonyBraviaIrcc,
            macAddress: mac,
          ),
          TvKeyCommand.power,
        ),
        vidaa.sendKey(
          TvDevice(
            name: 'Offline VIDAA',
            ip: '127.0.0.1',
            port: closedPort,
            protocol: TvConnectionProtocol.vidaaSmart36669,
            macAddress: mac,
          ),
          TvKeyCommand.power,
        ),
        vestel.sendKey(
          TvDevice(
            name: 'Offline Vestel',
            ip: '127.0.0.1',
            port: closedPort,
            protocol: TvConnectionProtocol.vestelSmart56789,
            macAddress: mac,
          ),
          TvKeyCommand.power,
        ),
        arcelik.sendKey(
          TvDevice(
            name: 'Offline Arcelik',
            ip: '127.0.0.1',
            port: closedPort,
            protocol: TvConnectionProtocol.arcelikGrundig8085,
            macAddress: mac,
          ),
          TvKeyCommand.power,
        ),
        upnp.sendKey(
          TvDevice(
            name: 'Offline UPnP',
            ip: '127.0.0.1',
            port: closedPort,
            protocol: TvConnectionProtocol.upnpDlnaControl,
            macAddress: mac,
          ),
          TvKeyCommand.power,
        ),
        adb.sendKeyCommand(
          TvDevice(
            name: 'Offline ADB',
            ip: '127.0.0.1',
            port: closedPort,
            protocol: TvConnectionProtocol.adbPort5555,
            macAddress: mac,
          ),
          TvKeyCommand.power,
        ),
        () async {
          final adb6466 = AdbTvService(secretVault: vault);
          try {
            return await adb6466.sendKeyCommand(
              TvDevice(
                name: 'Offline 6466',
                ip: '127.0.0.1',
                port: closedPort,
                protocol: TvConnectionProtocol.remotePort6466,
                macAddress: mac,
              ),
              TvKeyCommand.power,
            );
          } finally {
            adb6466.dispose();
          }
        }(),
      ]);
      expect(offlineResults, everyElement(isTrue));

      const macOnlyAdb = TvDevice(
        name: 'MAC Only TV',
        ip: '',
        port: 5555,
        protocol: TvConnectionProtocol.adbPort5555,
        macAddress: mac,
      );
      expect(
        await adb.sendKeyCommand(macOnlyAdb, TvKeyCommand.power),
        isTrue,
      );
      expect(
        await adb.sendKeyCommand(macOnlyAdb, TvKeyCommand.home),
        isFalse,
      );
    },
  );

  testWidgets(
    'WakeOnLanSetupSheet validates invalid MAC, saves normalized MAC + optional IP, and updates CueDeckNotifier',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adbTvServiceProvider.overrideWithValue(
              _OfflineNoTvTestAdbTvService(),
            ),
            cueNotificationServiceProvider.overrideWithValue(
              _TestCueNotificationService(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    key: const Key('open_wol_sheet_btn'),
                    onPressed: () => showWakeOnLanSetupSheet(context),
                    child: const Text('Open WoL'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('open_wol_sheet_btn'))),
      );
      expect(container.read(cueDeckProvider).selectedDevice.hasValidMac, isFalse);
      expect(
        container.read(cueDeckProvider).selectedDevice.hasControlTarget,
        isFalse,
      );

      await tester.tap(find.byKey(const Key('open_wol_sheet_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wake_on_lan_setup_sheet')), findsOneWidget);

      // Invalid MAC should display inline error without closing or saving
      await tester.enterText(find.byKey(const Key('wol_mac_input')), 'not-a-mac');
      await tester.tap(find.byKey(const Key('wol_save_and_wake_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wol_error_text')), findsOneWidget);
      expect(find.byKey(const Key('wake_on_lan_setup_sheet')), findsOneWidget);
      expect(container.read(cueDeckProvider).selectedDevice.hasValidMac, isFalse);

      // Valid MAC + optional IP should save normalized MAC, wake, and close sheet
      await tester.enterText(
        find.byKey(const Key('wol_mac_input')),
        'aa-bb-cc-11-22-33',
      );
      await tester.enterText(
        find.byKey(const Key('wol_ip_input')),
        '192.168.1.77',
      );
      await tester.tap(find.byKey(const Key('wol_save_and_wake_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wake_on_lan_setup_sheet')), findsNothing);
      final savedDevice = container.read(cueDeckProvider).selectedDevice;
      expect(savedDevice.macAddress, 'AA:BB:CC:11:22:33');
      expect(savedDevice.ip, '192.168.1.77');
      expect(savedDevice.hasValidMac, isTrue);
      expect(savedDevice.hasControlTarget, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  testWidgets(
    'CueDeckNotifier preserves manually saved MAC address across network rescans',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adbTvServiceProvider.overrideWithValue(_TestAdbTvService()),
            cueNotificationServiceProvider.overrideWithValue(
              _TestCueNotificationService(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      final notifier = container.read(cueDeckProvider.notifier);

      await notifier.scanNetworkForTvs();
      await tester.pumpAndSettle();

      expect(container.read(cueDeckProvider).selectedDevice.ip, '192.168.1.40');
      expect(
        container.read(cueDeckProvider).selectedDevice.macAddress,
        isEmpty,
      );

      final saved = await notifier.saveSelectedTvMacAddress('aa:bb:cc:44:55:66');
      expect(saved, isTrue);
      expect(
        container.read(cueDeckProvider).selectedDevice.macAddress,
        'AA:BB:CC:44:55:66',
      );

      await notifier.scanNetworkForTvs();
      await tester.pumpAndSettle();
      expect(
        container.read(cueDeckProvider).selectedDevice.ip,
        '192.168.1.40',
      );
      expect(
        container.read(cueDeckProvider).selectedDevice.macAddress,
        'AA:BB:CC:44:55:66',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
