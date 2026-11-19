import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/tv_driver_contract.dart';
import '../../domain/tv_network_validators.dart';
import '../../models/cue_models.dart';
import '../crypto/tv_secret_vault.dart';

/// Roku External Control Protocol (ECP — Port 8060) driver with zero-pairing keys,
/// per-character `Lit_` keyboard streaming, and direct channel deep-linking (`837` YouTube, `12` Netflix).
class RokuEcpDriver implements TvRemoteDriver {
  RokuEcpDriver({TvDiagLogger? logger}) : _log = logger;

  final TvDiagLogger? _log;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.rokuEcp8060;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.liveKeyboard,
        TvCapability.appLaunch,
        TvCapability.youtubePlaylistBeam,
        TvCapability.wakeOnLan,
      };

  static String mapKey(TvKeyCommand command) {
    switch (command) {
      case TvKeyCommand.up:
        return 'Up';
      case TvKeyCommand.down:
        return 'Down';
      case TvKeyCommand.left:
        return 'Left';
      case TvKeyCommand.right:
        return 'Right';
      case TvKeyCommand.ok:
        return 'Select';
      case TvKeyCommand.back:
        return 'Back';
      case TvKeyCommand.home:
        return 'Home';
      case TvKeyCommand.menu:
        return 'Info';
      case TvKeyCommand.inputs:
        return 'InputTuner';
      case TvKeyCommand.volUp:
        return 'VolumeUp';
      case TvKeyCommand.volDown:
        return 'VolumeDown';
      case TvKeyCommand.mute:
        return 'VolumeMute';
      case TvKeyCommand.power:
        return 'Power';
      case TvKeyCommand.playPause:
        return 'Play';
      case TvKeyCommand.rewind:
        return 'Rev';
      case TvKeyCommand.fastForward:
        return 'Fwd';
      case TvKeyCommand.channelUp:
        return 'ChannelUp';
      case TvKeyCommand.channelDown:
        return 'ChannelDown';
      case TvKeyCommand.voiceAssist:
      case TvKeyCommand.search:
        return 'Search';
    }
  }

  /// Builds the Roku ECP `/launch/...` path for [platform] and optional YouTube deep-link.
  static String? buildLaunchPath(
    StreamingPlatform platform, {
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) {
    if (platform == StreamingPlatform.youtube) {
      final clean = WatchCueItem.normalizeContentLink(platform, deepLinkUrl);
      if (clean.isNotEmpty) {
        final uri = Uri.tryParse(clean);
        final vid = uri?.queryParameters['v'] ?? '';
        final list = uri?.queryParameters['list'] ?? '';
        if (vid.isNotEmpty && list.isNotEmpty) {
          return '/launch/837?contentId=${Uri.encodeQueryComponent(vid)}&playlistId=${Uri.encodeQueryComponent(list)}';
        }
        if (vid.isNotEmpty) {
          return '/launch/837?contentId=${Uri.encodeQueryComponent(vid)}';
        }
        if (list.isNotEmpty) {
          return '/launch/837?playlistId=${Uri.encodeQueryComponent(list)}';
        }
      }
      if (fallbackSearchQuery.trim().isNotEmpty) {
        return '/launch/837?search=${Uri.encodeQueryComponent(fallbackSearchQuery.trim())}';
      }
      return '/launch/837';
    }
    switch (platform) {
      case StreamingPlatform.netflix:
        return '/launch/12';
      case StreamingPlatform.primeVideo:
        return '/launch/13';
      case StreamingPlatform.disneyPlus:
        return '/launch/291097';
      case StreamingPlatform.spotify:
        return '/launch/22297';
      case StreamingPlatform.twitch:
        return '/launch/50539';
      default:
        return null;
    }
  }

  Future<bool> _postPath(String ip, String path) async {
    if (!TvNetworkValidators.isValidIp(ip)) return false;
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 520);
    try {
      final req = await client
          .postUrl(Uri.parse('http://$ip:8060$path'))
          .timeout(const Duration(milliseconds: 600));
      req.contentLength = 0;
      final resp = await req.close().timeout(const Duration(milliseconds: 600));
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (e) {
      _log?.call('Roku ECP hatası ($path): $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    final ok = await sendKey(device, TvKeyCommand.home);
    return device.copyWith(
      port: 8060,
      protocol: TvConnectionProtocol.rokuEcp8060,
      isPaired: true,
      isOnline: ok,
      boardInfo: 'Roku OS • ECP/DIAL Doğrudan Kontrol Hazır (Port 8060)',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final ok = await _postPath(device.ip.trim(), '/keypress/${mapKey(command)}');
    if (!ok &&
        command == TvKeyCommand.power &&
        TvNetworkValidators.isValidMacAddress(device.macAddress)) {
      return wakeOnLan(device);
    }
    return ok;
  }

  @override
  Future<bool> sendText(
    TvDevice device,
    String text, {
    bool submitEnter = false,
  }) async {
    final cleanIp = device.ip.trim();
    if (text.isEmpty || !TvNetworkValidators.isValidIp(cleanIp)) return false;
    var anyOk = false;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final ok = await _postPath(
        cleanIp,
        '/keypress/Lit_${Uri.encodeComponent(ch)}',
      );
      if (ok) anyOk = true;
    }
    if (submitEnter) {
      await sendEnter(device);
    }
    return anyOk;
  }

  @override
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) async {
    var ok = false;
    for (var i = 0; i < count.clamp(1, 20); i++) {
      ok = await _postPath(device.ip.trim(), '/keypress/Backspace') || ok;
    }
    return ok;
  }

  @override
  Future<bool> sendEnter(TvDevice device) =>
      _postPath(device.ip.trim(), '/keypress/Enter');

  @override
  Future<bool> launchContent(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async {
    final path = buildLaunchPath(
      platform,
      deepLinkUrl: deepLinkUrl,
      fallbackSearchQuery: fallbackSearchQuery,
    );
    if (path == null) return false;
    return _postPath(device.ip.trim(), path);
  }

  @override
  Future<bool> wakeOnLan(TvDevice device) =>
      WakeOnLanService.sendMagicPacket(device.macAddress, targetIp: device.ip);

  @override
  Future<bool> movePointer(TvDevice device, double dx, double dy) async =>
      false;

  @override
  Future<bool> clickPointer(
    TvDevice device, {
    bool rightClick = false,
  }) async =>
      false;

  @override
  Future<bool> scrollWheel(TvDevice device, int wheelClicks) async => false;

  @override
  void dispose() {}
}

/// Philips JointSpace REST JSON driver (HTTPS Port 1926 v6 + HTTP Port 1925 v1 fallback).
class PhilipsJointSpaceDriver implements TvRemoteDriver {
  PhilipsJointSpaceDriver({TvDiagLogger? logger}) : _log = logger;

  final TvDiagLogger? _log;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.philipsJointSpace1925;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.appLaunch,
        TvCapability.wakeOnLan,
      };

  static String mapKey(TvKeyCommand command) {
    switch (command) {
      case TvKeyCommand.up:
        return 'CursorUp';
      case TvKeyCommand.down:
        return 'CursorDown';
      case TvKeyCommand.left:
        return 'CursorLeft';
      case TvKeyCommand.right:
        return 'CursorRight';
      case TvKeyCommand.ok:
        return 'Confirm';
      case TvKeyCommand.back:
        return 'Back';
      case TvKeyCommand.home:
        return 'Home';
      case TvKeyCommand.menu:
        return 'Options';
      case TvKeyCommand.inputs:
        return 'Source';
      case TvKeyCommand.volUp:
        return 'VolumeUp';
      case TvKeyCommand.volDown:
        return 'VolumeDown';
      case TvKeyCommand.mute:
        return 'Mute';
      case TvKeyCommand.power:
        return 'Standby';
      case TvKeyCommand.playPause:
        return 'PlayPause';
      case TvKeyCommand.rewind:
        return 'Rewind';
      case TvKeyCommand.fastForward:
        return 'FastForward';
      case TvKeyCommand.channelUp:
        return 'ChannelStepUp';
      case TvKeyCommand.channelDown:
        return 'ChannelStepDown';
      case TvKeyCommand.voiceAssist:
      case TvKeyCommand.search:
        return 'Find';
    }
  }

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    final ok = await sendKey(device, TvKeyCommand.home);
    return device.copyWith(
      protocol: TvConnectionProtocol.philipsJointSpace1925,
      isPaired: true,
      isOnline: ok,
      boardInfo: 'Philips JointSpace Smart TV • REST API Hazır',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return false;

    final bodyBytes = utf8.encode(
      jsonEncode(<String, String>{'key': mapKey(command)}),
    );
    final endpoints = <String>[
      'https://$ip:1926/6/input/key',
      'http://$ip:1925/1/input/key',
      'http://$ip:1925/6/input/key',
    ];

    for (final endpoint in endpoints) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 520)
        ..badCertificateCallback = (X509Certificate cert, String host, _) =>
            TvNetworkValidators.isPrivateLanIp(host) && cert.der.isNotEmpty;
      try {
        final req = await client
            .postUrl(Uri.parse(endpoint))
            .timeout(const Duration(milliseconds: 580));
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.contentLength = bodyBytes.length;
        req.add(bodyBytes);
        final resp = await req.close().timeout(const Duration(milliseconds: 580));
        await resp.drain<void>();
        if (resp.statusCode >= 200 && resp.statusCode < 400) return true;
      } catch (e) {
        _log?.call('Philips JointSpace hatası ($endpoint): $e');
      } finally {
        client.close(force: true);
      }
    }
    return false;
  }

  @override
  Future<bool> launchContent(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return false;
    final bodyBytes = utf8.encode(
      jsonEncode(<String, Object?>{
        'intent': <String, Object?>{
          'component': <String, String>{'packageName': platform.packageName},
          'action': 'Intent.ACTION_MAIN',
        },
      }),
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 550)
      ..badCertificateCallback = (X509Certificate cert, String host, _) =>
          TvNetworkValidators.isPrivateLanIp(host) && cert.der.isNotEmpty;
    try {
      final req = await client
          .postUrl(Uri.parse('https://$ip:1926/6/activities/launch'))
          .timeout(const Duration(milliseconds: 620));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.contentLength = bodyBytes.length;
      req.add(bodyBytes);
      final resp = await req.close().timeout(const Duration(milliseconds: 620));
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (e) {
      _log?.call('Philips launch hatası: $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<bool> wakeOnLan(TvDevice device) =>
      WakeOnLanService.sendMagicPacket(device.macAddress, targetIp: device.ip);

  @override
  Future<bool> movePointer(TvDevice device, double dx, double dy) async =>
      false;

  @override
  Future<bool> clickPointer(
    TvDevice device, {
    bool rightClick = false,
  }) async =>
      false;

  @override
  Future<bool> scrollWheel(TvDevice device, int wheelClicks) async => false;

  @override
  Future<bool> sendText(
    TvDevice device,
    String text, {
    bool submitEnter = false,
  }) async =>
      false;

  @override
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) =>
      sendKey(device, TvKeyCommand.back);

  @override
  Future<bool> sendEnter(TvDevice device) => sendKey(device, TvKeyCommand.ok);

  @override
  void dispose() {}
}

/// Hisense / Toshiba VIDAA OS (Port 36669) WebSocket remote driver.
class VidaaSmartDriver implements TvRemoteDriver {
  VidaaSmartDriver({TvDiagLogger? logger}) : _log = logger;

  static const Duration _idleTimeout = Duration(minutes: 10);

  final TvDiagLogger? _log;
  WebSocket? _ws;
  StreamSubscription<dynamic>? _wsSub;
  String? _wsIp;
  Timer? _idleTimer;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.vidaaSmart36669;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.wakeOnLan,
      };

  static String mapKey(TvKeyCommand command) {
    switch (command) {
      case TvKeyCommand.up:
        return 'KEY_UP';
      case TvKeyCommand.down:
        return 'KEY_DOWN';
      case TvKeyCommand.left:
        return 'KEY_LEFT';
      case TvKeyCommand.right:
        return 'KEY_RIGHT';
      case TvKeyCommand.ok:
        return 'KEY_OK';
      case TvKeyCommand.back:
        return 'KEY_RETURNS';
      case TvKeyCommand.home:
        return 'KEY_HOME';
      case TvKeyCommand.menu:
        return 'KEY_MENU';
      case TvKeyCommand.inputs:
        return 'KEY_SOURCE';
      case TvKeyCommand.volUp:
        return 'KEY_VOLUMEUP';
      case TvKeyCommand.volDown:
        return 'KEY_VOLUMEDOWN';
      case TvKeyCommand.mute:
        return 'KEY_MUTE';
      case TvKeyCommand.power:
        return 'KEY_POWER';
      case TvKeyCommand.playPause:
        return 'KEY_PLAY';
      case TvKeyCommand.rewind:
        return 'KEY_BACKWARDS';
      case TvKeyCommand.fastForward:
        return 'KEY_FORWARDS';
      case TvKeyCommand.channelUp:
        return 'KEY_CHANNELUP';
      case TvKeyCommand.channelDown:
        return 'KEY_CHANNELDOWN';
      case TvKeyCommand.voiceAssist:
      case TvKeyCommand.search:
        return 'KEY_HOME';
    }
  }

  static String buildJsonPayload(TvKeyCommand command) => jsonEncode(<String, String>{
        'action': 'sendkey',
        'key': mapKey(command),
      });

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    return device.copyWith(
      port: 36669,
      protocol: TvConnectionProtocol.vidaaSmart36669,
      isPaired: true,
      isOnline: true,
      boardInfo: 'Hisense / Toshiba VIDAA Smart TV (Port 36669)',
    );
  }

  void _scheduleIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _closeSocket);
  }

  void _closeSocket() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    final ws = _ws;
    _ws = null;
    _wsIp = null;
    if (ws != null) {
      unawaited(ws.close().catchError((Object e) {
        _log?.call('VIDAA WS close err: $e');
        return null;
      }));
    }
  }

  Future<bool> _ensureConnected(String ip) async {
    if (_ws != null && _wsIp == ip && _ws!.readyState == WebSocket.open) {
      _scheduleIdle();
      return true;
    }
    _closeSocket();
    for (final scheme in const <String>['wss', 'ws']) {
      WebSocket? ws;
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 1400)
          ..badCertificateCallback = (X509Certificate cert, String host, _) =>
              TvNetworkValidators.isPrivateLanIp(host) && cert.der.isNotEmpty;
        ws = await WebSocket.connect(
          '$scheme://$ip:36669',
          customClient: client,
        ).timeout(const Duration(milliseconds: 1800));
        ws.pingInterval = const Duration(seconds: 20);
        _ws = ws;
        _wsIp = ip;
        _wsSub = ws.listen(
          (_) {},
          onError: (Object e) {
            _log?.call('VIDAA WS stream hata ($ip): $e');
            _closeSocket();
          },
          onDone: _closeSocket,
          cancelOnError: false,
        );
        _scheduleIdle();
        return true;
      } catch (e) {
        _log?.call('VIDAA $scheme://:36669 hatası: $e');
        if (ws != null) {
          await ws.close().catchError((Object closeErr) {
            _log?.call('VIDAA WS close err: $closeErr');
            return null;
          });
        }
      }
    }
    return false;
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return false;

    final payload = buildJsonPayload(command);
    for (var attempt = 0; attempt < 2; attempt++) {
      final ready = await _ensureConnected(ip);
      if (!ready || _ws == null || _ws!.readyState != WebSocket.open) {
        _closeSocket();
        continue;
      }
      try {
        _ws!.add(payload);
        _scheduleIdle();
        return true;
      } catch (e) {
        _log?.call('VIDAA tuş gönderim hatası ($ip): $e');
        _closeSocket();
      }
    }
    return false;
  }

  @override
  Future<bool> wakeOnLan(TvDevice device) =>
      WakeOnLanService.sendMagicPacket(device.macAddress, targetIp: device.ip);

  @override
  Future<bool> movePointer(TvDevice device, double dx, double dy) async =>
      false;

  @override
  Future<bool> clickPointer(
    TvDevice device, {
    bool rightClick = false,
  }) async =>
      false;

  @override
  Future<bool> scrollWheel(TvDevice device, int wheelClicks) async => false;

  @override
  Future<bool> sendText(
    TvDevice device,
    String text, {
    bool submitEnter = false,
  }) async =>
      false;

  @override
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) =>
      sendKey(device, TvKeyCommand.back);

  @override
  Future<bool> sendEnter(TvDevice device) => sendKey(device, TvKeyCommand.ok);

  @override
  Future<bool> launchContent(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async =>
      false;

  @override
  void dispose() => _closeSocket();
}

/// Sony BRAVIA IRCC-IP SOAP (`POST /sony/IRCC`) driver with `TvSecretVault` PSK persistence.
class SonyBraviaIrccDriver implements TvRemoteDriver {
  SonyBraviaIrccDriver({
    required this._vault,
    TvDiagLogger? logger,
  })  : _log = logger;

  final TvSecretVault _vault;
  final TvDiagLogger? _log;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.sonyBraviaIrcc;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.appLaunch,
        TvCapability.wakeOnLan,
      };

  static String pskStorageKey(String ip) => 'sony_psk_${ip.trim()}';

  static String mapIrccCode(TvKeyCommand command) {
    switch (command) {
      case TvKeyCommand.up:
        return 'AAAAAQAAAAEAAAB0Aw==';
      case TvKeyCommand.down:
        return 'AAAAAQAAAAEAAAB1Aw==';
      case TvKeyCommand.left:
        return 'AAAAAQAAAAEAAAA0Aw==';
      case TvKeyCommand.right:
        return 'AAAAAQAAAAEAAAAzAw==';
      case TvKeyCommand.ok:
        return 'AAAAAQAAAAEAAABlAw==';
      case TvKeyCommand.back:
        return 'AAAAAgAAAJcAAAAjAw==';
      case TvKeyCommand.home:
        return 'AAAAAQAAAAEAAABgAw==';
      case TvKeyCommand.menu:
        return 'AAAAAgAAAJcAAAA2Aw==';
      case TvKeyCommand.inputs:
        return 'AAAAAQAAAAEAAAAlAw==';
      case TvKeyCommand.volUp:
        return 'AAAAAQAAAAEAAAASAw==';
      case TvKeyCommand.volDown:
        return 'AAAAAQAAAAEAAAATAw==';
      case TvKeyCommand.mute:
        return 'AAAAAQAAAAEAAAAUAw==';
      case TvKeyCommand.power:
        return 'AAAAAQAAAAEAAAAVAw==';
      case TvKeyCommand.playPause:
        return 'AAAAAgAAAJcAAAAaAw==';
      case TvKeyCommand.rewind:
        return 'AAAAAgAAAJcAAAAbAw==';
      case TvKeyCommand.fastForward:
        return 'AAAAAgAAAJcAAAAcAw==';
      case TvKeyCommand.channelUp:
        return 'AAAAAQAAAAEAAAAQAw==';
      case TvKeyCommand.channelDown:
        return 'AAAAAQAAAAEAAAARAw==';
      case TvKeyCommand.voiceAssist:
      case TvKeyCommand.search:
        return 'AAAAAgAAAJcAAAB2Aw==';
    }
  }

  static String buildSoapEnvelope(TvKeyCommand command) {
    final code = mapIrccCode(command);
    return '<?xml version="1.0"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">'
        '<IRCCCode>$code</IRCCCode>'
        '</u:X_SendIRCC></s:Body></s:Envelope>';
  }

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    final cleanIp = device.ip.trim();
    if (pinCode != null && pinCode.trim().isNotEmpty) {
      await _vault.writeSecret(pskStorageKey(cleanIp), pinCode.trim());
    }
    final ok = await sendKey(device, TvKeyCommand.home);
    return device.copyWith(
      port: 80,
      protocol: TvConnectionProtocol.sonyBraviaIrcc,
      isPaired: ok,
      isOnline: ok,
      boardInfo: 'Sony BRAVIA IRCC-IP • SOAP Kontrol',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return false;
    final psk = await _vault.readSecret(pskStorageKey(ip));
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 520);
    try {
      final req = await client
          .postUrl(Uri.parse('http://$ip/sony/IRCC'))
          .timeout(const Duration(milliseconds: 600));
      req.headers.set(HttpHeaders.contentTypeHeader, 'text/xml; charset=utf-8');
      req.headers.set(
        'SOAPACTION',
        '"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC"',
      );
      if (psk != null && psk.isNotEmpty) {
        req.headers.set('X-Auth-PSK', psk);
      }
      final bytes = utf8.encode(buildSoapEnvelope(command));
      req.contentLength = bytes.length;
      req.add(bytes);
      final resp = await req.close().timeout(const Duration(milliseconds: 600));
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (e) {
      _log?.call('Sony IRCC hatası: $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<bool> wakeOnLan(TvDevice device) =>
      WakeOnLanService.sendMagicPacket(device.macAddress, targetIp: device.ip);

  @override
  Future<bool> movePointer(TvDevice device, double dx, double dy) async =>
      false;

  @override
  Future<bool> clickPointer(
    TvDevice device, {
    bool rightClick = false,
  }) async =>
      false;

  @override
  Future<bool> scrollWheel(TvDevice device, int wheelClicks) async => false;

  @override
  Future<bool> sendText(
    TvDevice device,
    String text, {
    bool submitEnter = false,
  }) async =>
      false;

  @override
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) =>
      sendKey(device, TvKeyCommand.back);

  @override
  Future<bool> sendEnter(TvDevice device) => sendKey(device, TvKeyCommand.ok);

  @override
  Future<bool> launchContent(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async =>
      false;

  @override
  void dispose() {}
}
