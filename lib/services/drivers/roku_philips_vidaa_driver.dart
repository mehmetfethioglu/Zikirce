import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/tv_driver_contract.dart';
import '../../domain/tv_network_validators.dart';
import '../../models/cue_models.dart';
import '../crypto/tv_secret_vault.dart';

export 'philips_jointspace_driver.dart';
export 'vidaa_mqtt_driver.dart';

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

  Future<bool> _postPath(String ip, int port, String path) async {
    if (!TvNetworkValidators.isValidIp(ip)) return false;
    final targetPort = port > 0 ? port : 8060;
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 520);
    try {
      final req = await client
          .postUrl(Uri.parse('http://$ip:$targetPort$path'))
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
    final port = device.port > 0 ? device.port : 8060;
    return device.copyWith(
      port: port,
      protocol: TvConnectionProtocol.rokuEcp8060,
      isPaired: true,
      isOnline: ok,
      boardInfo: 'Roku OS • ECP/DIAL Doğrudan Kontrol Hazır (Port $port)',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final cleanIp = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(cleanIp)) {
      if (command == TvKeyCommand.power && device.hasValidMac) {
        return wakeOnLan(device);
      }
      return false;
    }
    final ok = await _postPath(
      cleanIp,
      device.port,
      '/keypress/${mapKey(command)}',
    );
    if (!ok && command == TvKeyCommand.power && device.hasValidMac) {
      return wakeOnLan(device);
    }
    return ok;
  }

  @override
  Future<bool> sendText(
    TvDevice device,
    String text, {
    bool submitEnter = false,
    bool clearExisting = false,
  }) async {
    final cleanIp = device.ip.trim();
    if (text.isEmpty || !TvNetworkValidators.isValidIp(cleanIp)) return false;
    if (clearExisting) {
      await sendBackspace(device, count: 20);
    }
    var anyOk = false;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final ok = await _postPath(
        cleanIp,
        device.port,
        '/keypress/Lit_${Uri.encodeComponent(ch)}',
      );
      if (ok) anyOk = true;
    }
    if (submitEnter) {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      await sendEnter(device);
    }
    return anyOk;
  }

  @override
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) async {
    var ok = false;
    for (var i = 0; i < count.clamp(1, 20); i++) {
      ok = await _postPath(device.ip.trim(), device.port, '/keypress/Backspace') || ok;
    }
    return ok;
  }

  @override
  Future<bool> sendEnter(TvDevice device) =>
      _postPath(device.ip.trim(), device.port, '/keypress/Enter');

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
    return _postPath(device.ip.trim(), device.port, path);
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
    final port = device.port > 0 ? device.port : 80;
    return device.copyWith(
      port: port,
      protocol: TvConnectionProtocol.sonyBraviaIrcc,
      isPaired: ok,
      isOnline: ok,
      boardInfo: 'Sony BRAVIA IRCC-IP • SOAP Kontrol',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) {
      if (command == TvKeyCommand.power && device.hasValidMac) {
        return wakeOnLan(device);
      }
      return false;
    }
    final port = device.port > 0 ? device.port : 80;
    final psk = await _vault.readSecret(pskStorageKey(ip));
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 520);
    var ok = false;
    try {
      final req = await client
          .postUrl(Uri.parse('http://$ip:$port/sony/IRCC'))
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
      ok = resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (e) {
      _log?.call('Sony IRCC hatası: $e');
      ok = false;
    } finally {
      client.close(force: true);
    }
    if (!ok && command == TvKeyCommand.power && device.hasValidMac) {
      return wakeOnLan(device);
    }
    return ok;
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
    bool clearExisting = false,
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
