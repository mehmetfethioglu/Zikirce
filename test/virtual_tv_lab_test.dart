import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cuedeck/domain/tv_driver_contract.dart';
import 'package:cuedeck/models/cue_models.dart';
import 'package:cuedeck/services/diagnostics/tv_diagnostic_reporter.dart';
import 'package:cuedeck/services/drivers/arcelik_vestel_upnp_driver.dart';
import 'package:cuedeck/services/drivers/lg_webos_driver.dart';
import 'package:cuedeck/services/drivers/roku_philips_vidaa_driver.dart';
import 'package:cuedeck/services/drivers/samsung_tizen_driver.dart';
import 'package:cuedeck/services/drivers/tv_driver_registry.dart';
import 'package:cuedeck/services/drivers/tv_quirks_registry.dart';
import 'package:cuedeck/services/drivers/youtube_dial_beam_service.dart';

class _MemoryVault implements TvSecretVault {
  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> readSecret(String key) async => store[key];

  @override
  Future<void> writeSecret(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> deleteSecret(String key) async {
    store.remove(key);
  }
}

void main() {
  HttpOverrides? previousHttpOverrides;

  setUp(() {
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
  });

  tearDown(() {
    HttpOverrides.global = previousHttpOverrides;
  });

  group('Virtual TV Lab — Automated Multi-Brand Contract Tests', () {
    test('Samsung Tizen Virtual TV persists token, sends keys, and streams IME Base64', () async {
      final receivedFrames = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final sub = server.listen((HttpRequest req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.add(
          jsonEncode(<String, Object?>{
            'event': 'ms.channel.connect',
            'data': <String, Object?>{'token': 'tizen-tok-99'},
          }),
        );
        ws.listen((dynamic raw) {
          if (raw is String) {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              receivedFrames.add(decoded);
            }
          }
        });
      });
      addTearDown(sub.cancel);

      final vault = _MemoryVault();
      final driver = SamsungTizenDriver(vault: vault);
      addTearDown(driver.dispose);

      final tv = TvDevice(
        name: 'Virtual Samsung QLED',
        ip: '127.0.0.1',
        port: server.port,
        protocol: TvConnectionProtocol.samsungTizen8001,
      );

      final paired = await driver.pair(tv);
      expect(paired.isOnline, isTrue);
      expect(paired.isPaired, isTrue);
      expect(await vault.readSecret('tizen_token_127.0.0.1'), 'tizen-tok-99');

      expect(await driver.sendKey(paired, TvKeyCommand.channelUp), isTrue);
      expect(await driver.sendText(paired, 'test', submitEnter: true), isTrue);
      expect(await driver.sendBackspace(paired, count: 2), isTrue);
      expect(await driver.clearInputField(paired), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(receivedFrames.length, greaterThanOrEqualTo(7));
      expect(receivedFrames[0]['params']['DataOfCmd'], 'KEY_CHUP');
      expect(receivedFrames[1]['params']['TypeOfRemote'], 'SendInputString');
      expect(receivedFrames[1]['params']['Cmd'], 'dGVzdA==');
      expect(receivedFrames[2]['params']['TypeOfRemote'], 'SendInputEnd');
      expect(receivedFrames[3]['params']['DataOfCmd'], 'KEY_ENTER');
      expect(receivedFrames[4]['params']['DataOfCmd'], 'KEY_BACKSPACE');
      expect(receivedFrames[5]['params']['DataOfCmd'], 'KEY_BACKSPACE');
      expect(receivedFrames[6]['params']['TypeOfRemote'], 'SendInputString');
      expect(receivedFrames[6]['params']['Cmd'], '');
    });

    test('LG webOS Virtual TV persists client-key and uses PointerInputSocket for keys & mouse', () async {
      final ssapRequests = <String>[];
      final pointerFrames = <String>[];

      final ptrServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => ptrServer.close(force: true));
      final ptrSub = ptrServer.listen((HttpRequest req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.listen((dynamic raw) {
          if (raw is String) pointerFrames.add(raw);
        });
      });
      addTearDown(ptrSub.cancel);

      final ssapServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => ssapServer.close(force: true));
      final ssapSub = ssapServer.listen((HttpRequest req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.listen((dynamic raw) {
          if (raw is! String) return;
          final msg = jsonDecode(raw) as Map<String, dynamic>;
          final type = msg['type']?.toString() ?? '';
          final id = msg['id']?.toString() ?? '';
          if (type == 'register') {
            ws.add(
              jsonEncode(<String, Object?>{
                'id': id,
                'type': 'registered',
                'payload': <String, Object?>{'client-key': 'lg-key-42'},
              }),
            );
          } else if (type == 'request') {
            final uri = msg['uri']?.toString() ?? '';
            ssapRequests.add(uri);
            if (uri ==
                'ssap://com.webos.service.networkinput/getPointerInputSocket') {
              ws.add(
                jsonEncode(<String, Object?>{
                  'id': id,
                  'type': 'response',
                  'payload': <String, Object?>{
                    'socketPath': 'ws://127.0.0.1:${ptrServer.port}',
                  },
                }),
              );
            } else {
              ws.add(
                jsonEncode(<String, Object?>{
                  'id': id,
                  'type': 'response',
                  'payload': <String, Object?>{'returnValue': true},
                }),
              );
            }
          }
        });
      });
      addTearDown(ssapSub.cancel);

      final vault = _MemoryVault();
      final driver = LgWebOsDriver(vault: vault);
      addTearDown(driver.dispose);

      final tv = TvDevice(
        name: 'Virtual LG OLED',
        ip: '127.0.0.1',
        port: ssapServer.port,
        protocol: TvConnectionProtocol.lgWebOs3000,
      );

      final paired = await driver.pair(tv);
      expect(paired.isOnline, isTrue);
      expect(paired.isPaired, isTrue);
      expect(await vault.readSecret('webos_key_127.0.0.1'), 'lg-key-42');

      expect(await driver.sendKey(paired, TvKeyCommand.channelUp), isTrue);
      expect(await driver.movePointer(paired, 12, -8), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        ssapRequests,
        contains('ssap://com.webos.service.networkinput/getPointerInputSocket'),
      );
      expect(
        pointerFrames.any((f) => f.contains('type:button\nname:CHANNELUP')),
        isTrue,
      );
      expect(pointerFrames.any((f) => f.contains('type:move')), isTrue);
    });

    test('Roku ECP Virtual TV handles channel keypresses, YouTube playlist launch, and Lit keyboard', () async {
      final hitPaths = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final sub = server.listen((HttpRequest req) async {
        hitPaths.add('${req.method} ${req.uri}');
        req.response.statusCode = HttpStatus.ok;
        await req.response.close();
      });
      addTearDown(sub.cancel);

      final driver = RokuEcpDriver();
      addTearDown(driver.dispose);

      final tv = TvDevice(
        name: 'Virtual Roku TV',
        ip: '127.0.0.1',
        port: server.port,
        protocol: TvConnectionProtocol.rokuEcp8060,
      );

      expect(await driver.sendKey(tv, TvKeyCommand.channelUp), isTrue);
      expect(
        await driver.launchContent(
          tv,
          platform: StreamingPlatform.youtube,
          deepLinkUrl: 'https://www.youtube.com/watch?v=abc123&list=PL99',
        ),
        isTrue,
      );
      expect(await driver.sendText(tv, 'ab'), isTrue);

      expect(hitPaths, contains('POST /keypress/ChannelUp'));
      expect(
        hitPaths.any(
          (p) => p.startsWith('POST /launch/837?contentId=abc123&playlistId=PL99'),
        ),
        isTrue,
      );
      expect(hitPaths, contains('POST /keypress/Lit_a'));
      expect(hitPaths, contains('POST /keypress/Lit_b'));
    });

    test('Vestel/Regal SmartCenter Virtual TV enforces Connection:close XML & DIAL precedence (never 1067/1059)', () async {
      final xmlBodies = <String>[];
      final dialHits = <String>[];
      var connectionCloseSeen = false;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final sub = server.listen((HttpRequest req) async {
        final body = await utf8.decoder.bind(req).join();
        final connHeader =
            req.headers.value(HttpHeaders.connectionHeader)?.toLowerCase() ?? '';
        if (connHeader.contains('close')) {
          connectionCloseSeen = true;
        }
        if (req.uri.path == '/apps/SmartCenter') {
          xmlBodies.add(body);
          req.response.statusCode = HttpStatus.ok;
        } else if (req.uri.path == '/apps/YouTube') {
          dialHits.add(body);
          req.response.statusCode = HttpStatus.created;
        } else {
          req.response.statusCode = HttpStatus.notFound;
        }
        await req.response.close();
      });
      addTearDown(sub.cancel);

      final vault = _MemoryVault();
      final dialUrls = <String, String>{
        '127.0.0.1': 'http://127.0.0.1:${server.port}/apps',
      };
      final registry = TvDriverRegistry(
        vault: vault,
        openLanSocket: (ip, port, {required Duration timeout}) =>
            Socket.connect(ip, port, timeout: timeout),
        ssdpLocationUrls: <String, String>{},
        dialAppUrls: dialUrls,
      );
      addTearDown(registry.dispose);

      final vestelDriver = registry.driverFor(
        TvConnectionProtocol.vestelSmart56789,
      )!;
      final tv = TvDevice(
        name: 'Virtual Regal TV',
        ip: '127.0.0.1',
        port: server.port,
        protocol: TvConnectionProtocol.vestelSmart56789,
      );

      expect(await vestelDriver.sendKey(tv, TvKeyCommand.channelUp), isTrue);
      expect(connectionCloseSeen, isTrue);
      expect(xmlBodies, contains('<remote><key code=1032/></remote>'));

      final beamer = YoutubeDialBeamService(
        dialAppUrls: dialUrls,
        registry: registry,
      );
      final beamed = await beamer.launchOnSmartTv(
        tv,
        platform: StreamingPlatform.youtube,
        deepLinkUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLtest',
        sendVestelRawKey: (_, code) async {
          xmlBodies.add('RAW_$code');
          return true;
        },
      );
      expect(beamed, isTrue);
      expect(dialHits, contains('v=dQw4w9WgXcQ&list=PLtest'));
      expect(xmlBodies.any((b) => b.contains('1067') || b.contains('1059')), isFalse);
    });

    test('Arcelik/Grundig HTTP & UPnP RenderingControl SOAP Virtual TV work deterministically', () async {
      final rcRequests = <String>[];
      final arcelikServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => arcelikServer.close(force: true));

      final aSub = arcelikServer.listen((HttpRequest req) async {
        rcRequests.add('${req.method} ${req.uri}');
        req.response.statusCode = HttpStatus.ok;
        await req.response.close();
      });
      addTearDown(aSub.cancel);

      final upnpActions = <String>[];
      final upnpBodies = <String>[];
      final upnpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => upnpServer.close(force: true));

      final uSub = upnpServer.listen((HttpRequest req) async {
        final body = await utf8.decoder.bind(req).join();
        if (req.uri.path == '/dd.xml') {
          req.response.statusCode = HttpStatus.ok;
          req.response.write(
            '<root><device><serviceList>'
            '<service><serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>'
            '<controlURL>/upnp/control/render</controlURL></service>'
            '</serviceList></device></root>',
          );
        } else if (req.uri.path == '/upnp/control/render') {
          upnpActions.add(req.headers.value('soapaction') ?? '');
          upnpBodies.add(body);
          req.response.statusCode = HttpStatus.ok;
        } else {
          req.response.statusCode = HttpStatus.notFound;
        }
        await req.response.close();
      });
      addTearDown(uSub.cancel);

      final ssdpUrls = <String, String>{
        '127.0.0.1': 'http://127.0.0.1:${upnpServer.port}/dd.xml',
      };
      final upnpDriver = UpnpDlnaDriver(ssdpLocationUrls: ssdpUrls);
      addTearDown(upnpDriver.dispose);

      final arcelikDriver = ArcelikGrundigDriver(
        openLanSocket: (ip, port, {required Duration timeout}) =>
            Socket.connect(ip, port, timeout: timeout),
        upnpFallback: upnpDriver,
        dialAppUrls: <String, String>{},
      );
      addTearDown(arcelikDriver.dispose);

      final arcelikTv = TvDevice(
        name: 'Virtual Grundig TV',
        ip: '127.0.0.1',
        port: arcelikServer.port,
        protocol: TvConnectionProtocol.arcelikGrundig8085,
      );
      expect(await arcelikDriver.sendKey(arcelikTv, TvKeyCommand.volUp), isTrue);
      expect(
        rcRequests,
        contains('GET /sendrcpackage?keyid=-2475&keysymbol=-4020'),
      );

      final upnpTv = TvDevice(
        name: 'Virtual UPnP TV',
        ip: '127.0.0.1',
        port: upnpServer.port,
        protocol: TvConnectionProtocol.upnpDlnaControl,
      );
      expect(await upnpDriver.sendKey(upnpTv, TvKeyCommand.mute), isTrue);
      expect(upnpActions.first, contains('RenderingControl:1#SetMute'));
      expect(upnpBodies.first, contains('<DesiredMute>1</DesiredMute>'));
    });

    test('Philips JointSpace v6 Virtual TV enforces 4-digit HMAC pairing, Digest challenge, and vault keys', () async {
      const expectedPin = '4829';
      const serverTimestamp = '1700000000';
      const issuedAuthKey = 'philips-auth-secret-77';
      const nonce = 'nonce9988';
      var granted = false;
      var challengeIssued = false;
      final verifiedKeys = <String>[];

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final sub = server.listen((HttpRequest req) async {
        final bodyStr = await utf8.decoder.bind(req).join();
        req.response.headers.contentType = ContentType.json;

        if (req.uri.path == '/6/pair/request') {
          req.response.statusCode = HttpStatus.ok;
          req.response.write(
            jsonEncode(<String, Object?>{
              'error_id': 'SUCCESS',
              'timestamp': serverTimestamp,
              'auth_key': issuedAuthKey,
            }),
          );
          await req.response.close();
          return;
        }

        final authHeader =
            req.headers.value(HttpHeaders.authorizationHeader) ?? '';
        if (!authHeader.startsWith('Digest ') ||
            !authHeader.contains('nonce="$nonce"')) {
          challengeIssued = true;
          req.response.statusCode = HttpStatus.unauthorized;
          req.response.headers.set(
            HttpHeaders.wwwAuthenticateHeader,
            'Digest realm="Philips TV", nonce="$nonce", qop="auth", algorithm="MD5"',
          );
          req.response.write(jsonEncode(<String, String>{'error_id': 'UNAUTHORIZED'}));
          await req.response.close();
          return;
        }

        if (req.uri.path == '/6/pair/grant') {
          final parsed = jsonDecode(bodyStr) as Map<String, dynamic>;
          final authMap = parsed['auth'] as Map<String, dynamic>;
          final sig = authMap['auth_signature']?.toString() ?? '';
          final expectedSig = PhilipsJointSpaceDriver.computeHmacSignature(
            serverTimestamp,
            expectedPin,
          );
          expect(sig, expectedSig);
          expect(authMap['pin'], expectedPin);
          expect(authHeader, contains('uri="/6/pair/grant"'));
          granted = true;
          req.response.statusCode = HttpStatus.ok;
          req.response.write(jsonEncode(<String, String>{'error_id': 'SUCCESS'}));
          await req.response.close();
          return;
        }

        if (req.uri.path == '/6/input/key') {
          expect(authHeader, contains('uri="/6/input/key"'));
          final parsed = jsonDecode(bodyStr) as Map<String, dynamic>;
          verifiedKeys.add(parsed['key']?.toString() ?? '');
          req.response.statusCode = HttpStatus.ok;
          req.response.write(jsonEncode(<String, String>{'error_id': 'SUCCESS'}));
          await req.response.close();
          return;
        }

        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      });
      addTearDown(sub.cancel);

      final vault = _MemoryVault();
      final driver = PhilipsJointSpaceDriver(
        vault: vault,
        allowPlainHttpForV6: true,
      );
      addTearDown(driver.dispose);

      final tv = TvDevice(
        name: 'Virtual Philips Ambilight',
        ip: '127.0.0.1',
        port: server.port,
        protocol: TvConnectionProtocol.philipsJointSpace1925,
      );

      final pairInit = await driver.startPinPairing(tv);
      expect(pairInit['pinDisplayed'], isTrue);
      expect(pairInit['pinLength'], 4);

      final paired = await driver.completePinPairing(tv, expectedPin);
      expect(challengeIssued, isTrue);
      expect(granted, isTrue);
      expect(paired.isPaired, isTrue);
      expect(paired.isOnline, isTrue);
      expect(await vault.readSecret('philips_key_127.0.0.1'), issuedAuthKey);
      expect(
        (await vault.readSecret('philips_id_127.0.0.1'))?.isNotEmpty,
        isTrue,
      );

      expect(await driver.sendKey(paired, TvKeyCommand.channelUp), isTrue);
      expect(verifiedKeys, contains('ChannelStepUp'));
    });

    test('Hisense/Toshiba VIDAA MQTT Virtual TV validates v3.1.1 CONNECT, SUBSCRIBE, sendkey, PIN auth, and app launch', () async {
      var sawValidConnect = false;
      var sawSubscribe = false;
      final published = <({String topic, String payload})>[];

      final broker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(broker.close);

      final brokerSub = broker.listen((Socket client) {
        final rx = <int>[];
        client.listen((List<int> data) {
          rx.addAll(data);
          while (true) {
            final pkt = MqttV311Codec.tryParsePacket(rx);
            if (pkt == null) break;
            rx.removeRange(0, pkt.totalLength);
            if (pkt.type == MqttV311Codec.packetTypeConnect) {
              final rawStr = utf8.decode(pkt.payload, allowMalformed: true);
              if (rawStr.contains('MQTT') &&
                  rawStr.contains('hisenseservice') &&
                  rawStr.contains('multimqttservice')) {
                sawValidConnect = true;
              }
              client.add(MqttV311Codec.encodeConnAck(0));
            } else if (pkt.type == MqttV311Codec.packetTypeSubscribe) {
              final rawStr = utf8.decode(pkt.payload, allowMalformed: true);
              if (rawStr.contains('/remoteapp/mobile/')) {
                sawSubscribe = true;
              }
            } else if (pkt.type == MqttV311Codec.packetTypePublish) {
              final msg = MqttV311Codec.decodePublishPayload(pkt.payload);
              if (msg != null) published.add(msg);
            }
          }
        });
      });
      addTearDown(brokerSub.cancel);

      final vault = _MemoryVault();
      final driver = VidaaSmartDriver(
        vault: vault,
        preferPlainTcpFirst: true,
        allowWebSocketFallback: false,
      );
      addTearDown(driver.dispose);

      final tv = TvDevice(
        name: 'Virtual Hisense VIDAA U7',
        ip: '127.0.0.1',
        port: broker.port,
        protocol: TvConnectionProtocol.vidaaSmart36669,
      );

      final paired = await driver.submitAuthPin(tv, '7391');
      expect(paired.isPaired, isTrue);
      expect(paired.isOnline, isTrue);

      expect(await driver.sendKey(paired, TvKeyCommand.channelUp), isTrue);
      expect(
        await driver.launchContent(paired, platform: StreamingPlatform.youtube),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(sawValidConnect, isTrue);
      expect(sawSubscribe, isTrue);
      expect(
        published.any(
          (p) =>
              p.topic.endsWith('/actions/authenticationcode') &&
              p.payload == '{"authNum":"7391"}',
        ),
        isTrue,
      );
      expect(
        published.any(
          (p) =>
              p.topic.endsWith('/actions/sendkey') && p.payload == 'KEY_CHANNELUP',
        ),
        isTrue,
      );
      expect(
        published.any(
          (p) =>
              p.topic.endsWith('/actions/launchapp') &&
              p.payload.contains('com.google.android.youtube.tv'),
        ),
        isTrue,
      );
    });

    test('Sony BRAVIA IRCC Virtual TV receives X-Auth-PSK, SOAPACTION, and IRCCCode body', () async {
      String? capturedPsk;
      String? capturedAction;
      String capturedBody = '';

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final sub = server.listen((HttpRequest req) async {
        capturedPsk = req.headers.value('x-auth-psk');
        capturedAction = req.headers.value('soapaction');
        capturedBody = await utf8.decoder.bind(req).join();
        req.response.statusCode = HttpStatus.ok;
        await req.response.close();
      });
      addTearDown(sub.cancel);

      final vault = _MemoryVault();
      final driver = SonyBraviaIrccDriver(vault: vault);
      addTearDown(driver.dispose);

      final tv = TvDevice(
        name: 'Virtual Sony BRAVIA',
        ip: '127.0.0.1',
        port: server.port,
        protocol: TvConnectionProtocol.sonyBraviaIrcc,
      );

      final paired = await driver.pair(tv, pinCode: '9090');
      expect(paired.isOnline, isTrue);
      expect(paired.isPaired, isTrue);

      expect(await driver.sendKey(paired, TvKeyCommand.channelUp), isTrue);
      expect(capturedPsk, '9090');
      expect(
        capturedAction,
        '"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC"',
      );
      expect(capturedBody, contains('<IRCCCode>AAAAAQAAAAEAAAAQAw==</IRCCCode>'));
    });

    test('OTA TvQuirksRegistry merges validated overrides, rejects malformed JSON, and ranks OEM alternatives', () {
      final registry = TvQuirksRegistry();
      final initialCount = registry.activeProfiles.length;
      expect(initialCount, greaterThanOrEqualTo(12));

      expect(registry.applyOtaJson('not-valid-json'), isFalse);
      expect(registry.applyOtaJson('{"schemaVersion":2,"profiles":[]}'), isFalse);
      expect(registry.activeProfiles.length, initialCount);

      final otaJson = jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'profiles': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'vestel_alt_56791',
            'label': 'Vestel / Regal OTA Profili',
            'subtitle': 'OTA yamalı Regal şasi portu',
            'protocol': 'vestelSmart56789',
            'port': 56792,
            'brandKeywords': <String>['regal', 'vestel'],
          },
        ],
      });
      expect(registry.applyOtaJson(otaJson), isTrue);
      expect(registry.schemaVersion, 2);

      final regalTv = const TvDevice(
        name: 'Regal Smart 55',
        ip: '192.168.1.40',
        port: 56789,
        protocol: TvConnectionProtocol.vestelSmart56789,
      );
      final suggestions = registry.suggestedAlternativeProfiles(regalTv);
      expect(suggestions.isNotEmpty, isTrue);
      expect(suggestions.first.id, 'vestel_alt_56791');
      expect(suggestions.first.port, 56792);
    });

    test('Zero-PII Diagnostic Report strips IPv4, IPv6, MAC, and personal TV names while keeping brand & DIAL codes', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final sub = server.listen((HttpRequest req) async {
        req.response.statusCode = req.uri.path == '/apps/YouTube'
            ? HttpStatus.ok
            : HttpStatus.notFound;
        await req.response.close();
      });
      addTearDown(sub.cancel);

      final reporter = TvDiagnosticReporter(
        openLanSocket: (ip, port, {required Duration timeout}) =>
            Socket.connect(ip, port, timeout: timeout),
        loadMtlsContext: () async => null,
      );

      final redactedLine = TvDiagnosticReporter.redactPii(
        '17:58:15 TUŞ -> ip=192.168.1.44 ipv6=fe80::1a2b:3c4d:5e6f mac=AA:BB:CC:DD:EE:FF',
      );
      expect(redactedLine, contains('17:58:15'));
      expect(redactedLine, contains('<LAN_IP>'));
      expect(redactedLine, contains('<IPV6>'));
      expect(redactedLine, contains('<MAC>'));
      expect(redactedLine.contains('192.168.1.44'), isFalse);
      expect(redactedLine.contains('AA:BB:CC:DD:EE:FF'), isFalse);

      final device = TvDevice(
        name: "Celal'in Oturma Odasi Regal 55",
        ip: '127.0.0.1',
        port: server.port,
        boardInfo: 'Vestel SmartCenter',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        protocol: TvConnectionProtocol.vestelSmart56789,
        isPaired: true,
        isOnline: true,
      );

      final anonReport = await reporter.buildAnonymizedCompatibilityReport(
        device,
        appVersion: '2.0.0+27',
        recentDiagLog: <String>[
          '17:58:15 Bağlandı 127.0.0.1 MAC 11:22:33:44:55:66',
        ],
        scanPortsOverride: <int>[server.port],
      );

      expect(anonReport.contains('127.0.0.1'), isFalse);
      expect(anonReport.contains('AA:BB:CC:DD:EE:FF'), isFalse);
      expect(anonReport.contains('11:22:33:44:55:66'), isFalse);
      expect(anonReport.contains('Celal'), isFalse);
      expect(anonReport.contains('Oturma'), isFalse);

      final parsed = jsonDecode(anonReport) as Map<String, dynamic>;
      expect(parsed['privacy'], 'zero-pii-redacted');
      expect(parsed['brandFingerprint'], 'Regal / Vestel');
      expect(parsed['openPorts'], <int>[server.port]);
      final dialProbes = parsed['dialProbes'] as Map<String, dynamic>;
      expect(dialProbes['port_${server.port}_YouTube'], 'HTTP 200');
      expect(dialProbes['port_${server.port}_Netflix'], 'HTTP 404');
    });

    test('ArcelikGrundigDriver ArWebsocket Virtual TV handles probe, RC keys, live keyboard, and clearExisting', () async {
      final receivedFrames = <Map<String, dynamic>>[];
      final seenHeaders = <String, String>{};
      final wsServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => wsServer.close(force: true));

      final wsSub = wsServer.listen((HttpRequest req) async {
        final protoHeader = req.headers.value('sec-websocket-protocol') ?? '';
        if (!WebSocketTransformer.isUpgradeRequest(req) ||
            !protoHeader.split(',').map((e) => e.trim()).contains('ArWebsocket')) {
          req.response.statusCode = HttpStatus.badRequest;
          await req.response.close();
          return;
        }
        seenHeaders['origin'] = req.headers.value('origin') ?? '';
        seenHeaders['user-agent'] = req.headers.value('user-agent') ?? '';
        final ws = await WebSocketTransformer.upgrade(
          req,
          protocolSelector: (List<String> protos) =>
              protos.contains('ArWebsocket') ? 'ArWebsocket' : protos.first,
        );
        ws.listen((dynamic raw) {
          if (raw is String) {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              receivedFrames.add(decoded);
            }
          }
        });
      });
      addTearDown(wsSub.cancel);

      final plainHttpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => plainHttpServer.close(force: true));
      final pSub = plainHttpServer.listen((HttpRequest req) async {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      });
      addTearDown(pSub.cancel);

      final upnpDriver = UpnpDlnaDriver(ssdpLocationUrls: <String, String>{});
      addTearDown(upnpDriver.dispose);

      final arcelikDriver = ArcelikGrundigDriver(
        openLanSocket: (ip, port, {required Duration timeout}) =>
            Socket.connect(ip, port, timeout: timeout),
        upnpFallback: upnpDriver,
        dialAppUrls: <String, String>{},
      );
      addTearDown(arcelikDriver.dispose);

      expect(
        await arcelikDriver.probeArWebsocket('127.0.0.1', port: wsServer.port),
        isTrue,
      );
      expect(
        await arcelikDriver.probeArWebsocket(
          '127.0.0.1',
          port: plainHttpServer.port,
          timeout: const Duration(milliseconds: 220),
        ),
        isFalse,
      );

      final tv = TvDevice(
        name: 'Virtual Arçelik 4K',
        ip: '127.0.0.1',
        port: wsServer.port,
        protocol: TvConnectionProtocol.arcelikGrundig8085,
      );
      final paired = await arcelikDriver.pair(tv);
      expect(paired.isOnline, isTrue);
      expect(paired.isPaired, isTrue);
      expect(paired.boardInfo, contains('ArWebsocket'));

      expect(await arcelikDriver.sendKey(paired, TvKeyCommand.volUp), isTrue);
      expect(await arcelikDriver.sendKey(paired, TvKeyCommand.ok), isTrue);
      expect(await arcelikDriver.sendKey(paired, TvKeyCommand.home), isTrue);
      expect(await arcelikDriver.sendKey(paired, TvKeyCommand.inputs), isTrue);
      expect(await arcelikDriver.sendKey(paired, TvKeyCommand.channelUp), isTrue);

      receivedFrames.clear();
      expect(
        await arcelikDriver.sendText(
          paired,
          'ab',
          submitEnter: true,
          clearExisting: true,
        ),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(seenHeaders['origin'], contains('127.0.0.1:${wsServer.port}'));
      expect(seenHeaders['user-agent'], 'okhttp/3.12.1');
      final keyboardArgs = receivedFrames
          .where((f) => f['command'] == 'on-keyboard-input')
          .map((f) => (f['arguments'] as Map)['key'] as String)
          .toList();
      expect(keyboardArgs.take(20), everyElement('\b'));
      expect(keyboardArgs.skip(20).toList(), <String>['a', 'b']);
      expect(receivedFrames.last['command'], 'on-rc-input');
      expect((receivedFrames.last['arguments'] as Map)['key'], 'RC_OK');
    });

    test('VestelSmartCenterDriver falls back to ArWebsocket when SmartCenter 56789 returns 404', () async {
      final wsFrames = <Map<String, dynamic>>[];
      final wsServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => wsServer.close(force: true));
      final wsSub = wsServer.listen((HttpRequest req) async {
        final ws = await WebSocketTransformer.upgrade(
          req,
          protocolSelector: (List<String> protos) =>
              protos.contains('ArWebsocket') ? 'ArWebsocket' : protos.first,
        );
        ws.listen((dynamic raw) {
          if (raw is String) {
            wsFrames.add(jsonDecode(raw) as Map<String, dynamic>);
          }
        });
      });
      addTearDown(wsSub.cancel);

      var smartCenterStatus = HttpStatus.notFound;
      final dial404Server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => dial404Server.close(force: true));
      final dSub = dial404Server.listen((HttpRequest req) async {
        req.response.statusCode = smartCenterStatus;
        await req.response.close();
      });
      addTearDown(dSub.cancel);

      final upnpDriver = UpnpDlnaDriver(ssdpLocationUrls: <String, String>{});
      addTearDown(upnpDriver.dispose);
      final arcelikDriver = ArcelikGrundigDriver(
        openLanSocket: (ip, port, {required Duration timeout}) =>
            Socket.connect(ip, port, timeout: timeout),
        upnpFallback: upnpDriver,
        dialAppUrls: <String, String>{},
      );
      addTearDown(arcelikDriver.dispose);
      final vestelDriver = VestelSmartCenterDriver(
        arcelikDelegate: arcelikDriver,
        arcelikFallbackPort: wsServer.port,
      );
      addTearDown(vestelDriver.dispose);

      final misclassifiedArcelik = TvDevice(
        name: 'Arçelik DIAL',
        ip: '127.0.0.1',
        port: dial404Server.port,
        protocol: TvConnectionProtocol.vestelSmart56789,
      );

      expect(
        await vestelDriver.sendKey(misclassifiedArcelik, TvKeyCommand.volUp),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(wsFrames.length, 1);
      expect((wsFrames.first['arguments'] as Map)['key'], 'RC_VOLUME_UP');

      smartCenterStatus = HttpStatus.ok;
      final regalServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => regalServer.close(force: true));
      final regalHits = <String>[];
      final rSub = regalServer.listen((HttpRequest req) async {
        regalHits.add('${req.method} ${req.uri.path}');
        req.response.statusCode = HttpStatus.ok;
        await req.response.close();
      });
      addTearDown(rSub.cancel);

      final regalTv = TvDevice(
        name: 'Regal Smart TV',
        ip: '127.0.0.1',
        port: regalServer.port,
        protocol: TvConnectionProtocol.vestelSmart56789,
      );
      final vestelRegal = VestelSmartCenterDriver(
        arcelikDelegate: arcelikDriver,
        arcelikFallbackPort: wsServer.port,
      );
      addTearDown(vestelRegal.dispose);
      expect(await vestelRegal.sendKey(regalTv, TvKeyCommand.mute), isTrue);
      expect(regalHits, contains('POST /apps/SmartCenter'));
    });

    test('ArcelikGrundigDriver.sendRawHttpGetOverTcp returns false when TCP server returns zero bytes', () async {
      final silentServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(silentServer.close);
      final sSub = silentServer.listen((Socket client) {
        client.destroy();
      });
      addTearDown(sSub.cancel);

      final upnpDriver = UpnpDlnaDriver(ssdpLocationUrls: <String, String>{});
      addTearDown(upnpDriver.dispose);
      final arcelikDriver = ArcelikGrundigDriver(
        openLanSocket: (ip, port, {required Duration timeout}) =>
            Socket.connect(ip, port, timeout: timeout),
        upnpFallback: upnpDriver,
        dialAppUrls: <String, String>{},
      );
      addTearDown(arcelikDriver.dispose);

      expect(
        await arcelikDriver.sendRawHttpGetOverTcp(
          '127.0.0.1',
          silentServer.port,
          '/sendrcpackage?keyid=-2490&keysymbol=13',
        ),
        isFalse,
      );
    });
  });
}
