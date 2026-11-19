import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/tv_driver_contract.dart';
import '../../domain/tv_network_validators.dart';
import '../../models/cue_models.dart';
import '../crypto/tv_secret_vault.dart';

typedef LanSocketFactory = Future<Socket> Function(
  String ip,
  int port, {
  required Duration timeout,
});

/// Universal UPnP / DLNA MediaRenderer (`RenderingControl:1` + `AVTransport:1`) SOAP driver.
/// Discovers `controlURL` endpoints from SSDP `LOCATION` XMLs so volume, mute, and
/// play/pause/stop work even on closed Smart TV chassis.
class UpnpDlnaDriver implements TvRemoteDriver {
  UpnpDlnaDriver({
    required this._ssdpLocationUrls,
    TvDiagLogger? logger,
  })  : _log = logger;

  final Map<String, String> _ssdpLocationUrls;
  final TvDiagLogger? _log;
  final Map<String, String> _renderingUrls = <String, String>{};
  final Map<String, String> _avTransportUrls = <String, String>{};
  int _cachedVolume = 25;
  bool _cachedMute = false;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.upnpDlnaControl;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.wakeOnLan,
      };

  static String? extractControlUrlFromXml(String xml, String serviceKeyword) {
    final serviceBlock = RegExp(
      '<service>([\\s\\S]*?$serviceKeyword[\\s\\S]*?)</service>',
      caseSensitive: false,
    ).firstMatch(xml);
    if (serviceBlock == null) return null;
    final ctrlMatch = RegExp(
      r'<controlURL>([^<]+)</controlURL>',
      caseSensitive: false,
    ).firstMatch(serviceBlock.group(1) ?? '');
    return ctrlMatch?.group(1)?.trim();
  }

  static String resolveControlUri(String baseLocationUrl, String controlPath) {
    if (controlPath.startsWith('http://') ||
        controlPath.startsWith('https://')) {
      return controlPath;
    }
    final base = Uri.tryParse(baseLocationUrl);
    if (base == null) return controlPath;
    return base.resolve(controlPath).toString();
  }

  Future<void> _ensureControlUrls(String ip) async {
    if (_renderingUrls.containsKey(ip) || _avTransportUrls.containsKey(ip)) {
      return;
    }
    final locUrl = _ssdpLocationUrls[ip];
    if (locUrl == null || locUrl.isEmpty) return;

    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 520);
    try {
      final req = await client
          .getUrl(Uri.parse(locUrl))
          .timeout(const Duration(milliseconds: 580));
      final resp = await req.close().timeout(const Duration(milliseconds: 580));
      if (resp.statusCode != 200) return;
      final xml = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(milliseconds: 580));
      final renderPath = extractControlUrlFromXml(xml, 'RenderingControl');
      if (renderPath != null && renderPath.isNotEmpty) {
        _renderingUrls[ip] = resolveControlUri(locUrl, renderPath);
      }
      final avPath = extractControlUrlFromXml(xml, 'AVTransport');
      if (avPath != null && avPath.isNotEmpty) {
        _avTransportUrls[ip] = resolveControlUri(locUrl, avPath);
      }
    } catch (e) {
      _log?.call('UPnP XML çözümleme hatası ($ip): $e');
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _postUpnpSoap(
    String url,
    String serviceType,
    String action,
    String innerXml,
  ) async {
    final envelope = '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:$action xmlns:u="$serviceType">$innerXml</u:$action></s:Body>'
        '</s:Envelope>';
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 550);
    try {
      final req = await client
          .postUrl(Uri.parse(url))
          .timeout(const Duration(milliseconds: 620));
      req.headers.set(HttpHeaders.contentTypeHeader, 'text/xml; charset=utf-8');
      req.headers.set('SOAPACTION', '"$serviceType#$action"');
      final bytes = utf8.encode(envelope);
      req.contentLength = bytes.length;
      req.add(bytes);
      final resp = await req.close().timeout(const Duration(milliseconds: 620));
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (e) {
      _log?.call('UPnP SOAP hatası ($action): $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return device;
    await _ensureControlUrls(ip);
    final hasUpnp =
        _renderingUrls.containsKey(ip) || _avTransportUrls.containsKey(ip);
    return device.copyWith(
      isPaired: hasUpnp,
      isOnline: hasUpnp,
      boardInfo: hasUpnp
          ? 'Evrensel UPnP/DLNA • Ses & Medya Kontrolü Hazır'
          : device.boardInfo,
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return false;
    await _ensureControlUrls(ip);

    final renderUrl = _renderingUrls[ip];
    final avUrl = _avTransportUrls[ip];

    switch (command) {
      case TvKeyCommand.volUp:
        if (renderUrl == null) return false;
        _cachedVolume = (_cachedVolume + 4).clamp(0, 100);
        return _postUpnpSoap(
          renderUrl,
          'urn:schemas-upnp-org:service:RenderingControl:1',
          'SetVolume',
          '<InstanceID>0</InstanceID><Channel>Master</Channel>'
              '<DesiredVolume>$_cachedVolume</DesiredVolume>',
        );
      case TvKeyCommand.volDown:
        if (renderUrl == null) return false;
        _cachedVolume = (_cachedVolume - 4).clamp(0, 100);
        return _postUpnpSoap(
          renderUrl,
          'urn:schemas-upnp-org:service:RenderingControl:1',
          'SetVolume',
          '<InstanceID>0</InstanceID><Channel>Master</Channel>'
              '<DesiredVolume>$_cachedVolume</DesiredVolume>',
        );
      case TvKeyCommand.mute:
        if (renderUrl == null) return false;
        _cachedMute = !_cachedMute;
        return _postUpnpSoap(
          renderUrl,
          'urn:schemas-upnp-org:service:RenderingControl:1',
          'SetMute',
          '<InstanceID>0</InstanceID><Channel>Master</Channel>'
              '<DesiredMute>${_cachedMute ? 1 : 0}</DesiredMute>',
        );
      case TvKeyCommand.playPause:
        if (avUrl == null) return false;
        return _postUpnpSoap(
          avUrl,
          'urn:schemas-upnp-org:service:AVTransport:1',
          'Play',
          '<InstanceID>0</InstanceID><Speed>1</Speed>',
        );
      default:
        return false;
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
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) async => false;

  @override
  Future<bool> sendEnter(TvDevice device) async => false;

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

/// Arçelik / Beko / Grundig Smart Inter@ctive (`Port 8085`, `Port 8080`,
/// `_arceliktvremote` `Port 7681` WebSocket, and `Port 56789` SmartCenter fallback)
/// plus UPnP fallback for closed chassis TVs.
class ArcelikGrundigDriver implements TvRemoteDriver {
  ArcelikGrundigDriver({
    required this._openLanSocket,
    required this._upnpFallback,
    required this._dialAppUrls,
    TvDiagLogger? logger,
  })  : _log = logger;

  final LanSocketFactory _openLanSocket;
  final UpnpDlnaDriver _upnpFallback;
  final Map<String, String> _dialAppUrls;
  final TvDiagLogger? _log;

  WebSocket? _ws7681;
  String? _ws7681Ip;
  Timer? _idleTimer;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.arcelikGrundig8085;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.youtubePlaylistBeam,
        TvCapability.wakeOnLan,
      };

  static String arcelikGrundigQueryForCommand(TvKeyCommand command) {
    switch (command) {
      case TvKeyCommand.up:
        return 'keyid=-2493&keysymbol=-4094';
      case TvKeyCommand.down:
        return 'keyid=-2492&keysymbol=-4093';
      case TvKeyCommand.left:
        return 'keyid=-2495&keysymbol=-4096';
      case TvKeyCommand.right:
        return 'keyid=-2494&keysymbol=-4095';
      case TvKeyCommand.ok:
        return 'keyid=-2490&keysymbol=13';
      case TvKeyCommand.back:
        return 'keyid=-2542&keysymbol=-3979';
      case TvKeyCommand.home:
        return 'keyid=-2547&keysymbol=-4078';
      case TvKeyCommand.menu:
        return 'keyid=-2506&keysymbol=-4079';
      case TvKeyCommand.inputs:
        return 'keyid=-2541&keysymbol=-3992';
      case TvKeyCommand.volUp:
        return 'keyid=-2475&keysymbol=-4020';
      case TvKeyCommand.volDown:
        return 'keyid=-2476&keysymbol=-4019';
      case TvKeyCommand.mute:
        return 'keyid=-2539&keysymbol=-4018';
      case TvKeyCommand.power:
        return 'keyid=-2544&keysymbol=-4081';
      case TvKeyCommand.playPause:
        return 'keyid=-2548&keysymbol=-4015';
      case TvKeyCommand.rewind:
        return 'keyid=-2558&keysymbol=-3977';
      case TvKeyCommand.fastForward:
        return 'keyid=-2555&keysymbol=-4023';
      case TvKeyCommand.channelUp:
        return 'keyid=-2464&keysymbol=-4026';
      case TvKeyCommand.channelDown:
        return 'keyid=-2465&keysymbol=-4025';
      case TvKeyCommand.voiceAssist:
        return 'keyid=-2536&keysymbol=-4069';
      case TvKeyCommand.search:
        return 'keyid=-2547&keysymbol=-4078';
    }
  }

  /// Official Vestel / Regal / Toshiba / JVC SmartCenter integer keycodes.
  static int vestelKeyCodeForCommand(TvKeyCommand command) {
    switch (command) {
      case TvKeyCommand.up:
        return 1020;
      case TvKeyCommand.down:
        return 1019;
      case TvKeyCommand.left:
        return 1021;
      case TvKeyCommand.right:
        return 1022;
      case TvKeyCommand.ok:
        return 1053;
      case TvKeyCommand.back:
        return 1010;
      case TvKeyCommand.home:
        return 1048;
      case TvKeyCommand.menu:
        return 1048;
      case TvKeyCommand.inputs:
        return 1056;
      case TvKeyCommand.volUp:
        return 1016;
      case TvKeyCommand.volDown:
        return 1017;
      case TvKeyCommand.mute:
        return 1013;
      case TvKeyCommand.power:
        return 1012;
      case TvKeyCommand.playPause:
        return 1025;
      case TvKeyCommand.rewind:
        return 1027;
      case TvKeyCommand.fastForward:
        return 1028;
      case TvKeyCommand.channelUp:
        return 1032;
      case TvKeyCommand.channelDown:
        return 1033;
      case TvKeyCommand.voiceAssist:
        return 1046;
      case TvKeyCommand.search:
        return 1046;
    }
  }

  static String vestelXmlForCommand(TvKeyCommand command) {
    final code = vestelKeyCodeForCommand(command);
    return '<remote><key code=$code/></remote>';
  }

  Future<bool> sendRawHttpGetOverTcp(
    String ip,
    int port,
    String pathAndQuery,
  ) async {
    Socket? sock;
    try {
      sock = await _openLanSocket(
        ip,
        port,
        timeout: const Duration(milliseconds: 520),
      );
      final reqText =
          'GET $pathAndQuery HTTP/1.1\r\n'
          'Host: $ip:$port\r\n'
          'User-Agent: Grundig-Android-App\r\n'
          'Accept: */*\r\n'
          'Connection: close\r\n\r\n';
      final rx = <int>[];
      final done = Completer<void>();
      final sub = sock.listen(
        (chunk) {
          rx.addAll(chunk);
          if (rx.length >= 16 && !done.isCompleted) done.complete();
        },
        onError: (_) {
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      sock.add(ascii.encode(reqText));
      await sock.flush();
      await done.future.timeout(
        const Duration(milliseconds: 650),
        onTimeout: () {},
      );
      await sub.cancel();

      if (rx.isEmpty) {
        _log?.call('HTTP $ip:$port$pathAndQuery -> bağlandı, yanıt yok');
        return true;
      }
      final head = utf8
          .decode(rx.take(64).toList(), allowMalformed: true)
          .split('\r\n')
          .first;
      final statusMatch = RegExp(r'^HTTP/\d\.\d\s+(\d{3})').firstMatch(head);
      _log?.call('HTTP $ip:$port$pathAndQuery -> "$head"');
      if (statusMatch == null) return true;
      final status = int.tryParse(statusMatch.group(1) ?? '') ?? 0;
      return status >= 200 && status < 400;
    } catch (e) {
      _log?.call('HTTP $ip:$port$pathAndQuery -> HATA: $e');
      return false;
    } finally {
      try {
        sock?.destroy();
      } catch (e) {
        sock = null;
      }
    }
  }

  Future<bool> sendVestelSmartCenterKey(
    String ip,
    TvKeyCommand command,
  ) async {
    final code = vestelKeyCodeForCommand(command);
    final unquotedXml = '<remote><key code=$code/></remote>';
    final quotedXml =
        '<?xml version="1.0" ?><remote><key code="$code"/></remote>';
    final payloads = <(String, String)>[
      (unquotedXml, 'text/plain; charset=ISO-8859-1'),
      (unquotedXml, 'application/xml'),
      (quotedXml, 'text/xml; charset=utf-8'),
    ];
    final dialBase = _dialAppUrls[ip];
    final targetUrls = <String>[
      'http://$ip:56789/apps/SmartCenter',
      'http://$ip:56789/apps/vr/remote',
      'http://$ip:56791/apps/vr/remote',
      if (dialBase != null && dialBase.isNotEmpty)
        '${dialBase.endsWith('/') ? dialBase : '$dialBase/'}SmartCenter',
    ];

    for (final url in targetUrls) {
      for (final (payload, contentType) in payloads) {
        final client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 520);
        try {
          final req = await client
              .postUrl(Uri.parse(url))
              .timeout(const Duration(milliseconds: 560));
          req.headers.set(HttpHeaders.contentTypeHeader, contentType);
          req.headers.set(HttpHeaders.connectionHeader, 'close');
          final bytes = utf8.encode(payload);
          req.contentLength = bytes.length;
          req.add(bytes);
          final resp = await req.close().timeout(
            const Duration(milliseconds: 560),
          );
          await resp.drain<void>();
          if (resp.statusCode >= 200 && resp.statusCode < 400) {
            return true;
          }
        } catch (e) {
          _log?.call('SmartCenter POST $url -> HATA: $e');
        } finally {
          client.close(force: true);
        }
      }
    }
    return false;
  }

  void _close7681Socket() {
    _idleTimer?.cancel();
    _idleTimer = null;
    final ws = _ws7681;
    _ws7681 = null;
    _ws7681Ip = null;
    if (ws != null) {
      unawaited(ws.close().catchError((Object e) {
        _log?.call('Arçelik 7681 WS close err: $e');
        return null;
      }));
    }
  }

  Future<bool> _tryArcelik7681WebSocket(
    String ip,
    TvKeyCommand command,
  ) async {
    final query = arcelikGrundigQueryForCommand(command);
    if (_ws7681 != null &&
        _ws7681Ip == ip &&
        _ws7681!.readyState == WebSocket.open) {
      try {
        _ws7681!.add(jsonEncode(<String, Object?>{'command': query}));
        _idleTimer?.cancel();
        _idleTimer = Timer(const Duration(minutes: 10), _close7681Socket);
        return true;
      } catch (e) {
        _log?.call('Arçelik 7681 WS send hatası: $e');
        _close7681Socket();
      }
    }

    for (final proto in const <List<String>>[
      <String>['arceliktvremote'],
      <String>['tvremote'],
      <String>['lws-minimal'],
    ]) {
      try {
        final ws = await WebSocket.connect(
          'ws://$ip:7681/',
          protocols: proto,
          headers: <String, Object>{'Origin': 'http://$ip:7681'},
        ).timeout(const Duration(milliseconds: 850));
        ws.pingInterval = const Duration(seconds: 20);
        _ws7681 = ws;
        _ws7681Ip = ip;
        ws.add(jsonEncode(<String, Object?>{'command': query}));
        _idleTimer?.cancel();
        _idleTimer = Timer(const Duration(minutes: 10), _close7681Socket);
        return true;
      } catch (e) {
        _log?.call('Arçelik 7681 handshake ($proto): $e');
      }
    }
    return false;
  }

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    return device.copyWith(
      protocol: TvConnectionProtocol.arcelikGrundig8085,
      isPaired: true,
      isOnline: true,
      boardInfo: 'Arçelik / Beko / Grundig Smart TV',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return false;

    final query = arcelikGrundigQueryForCommand(command);
    if (await sendRawHttpGetOverTcp(ip, 8085, '/sendrcpackage?$query')) {
      return true;
    }
    if (await sendVestelSmartCenterKey(ip, command)) {
      return true;
    }
    if (await sendRawHttpGetOverTcp(ip, 8080, '/sendrcpackage?$query')) {
      return true;
    }
    if (await _tryArcelik7681WebSocket(ip, command)) {
      return true;
    }
    return _upnpFallback.sendKey(device, command);
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
  void dispose() => _close7681Socket();
}

/// Vestel / Regal / Toshiba / Arçelik SmartCenter (`Port 56789`) driver.
class VestelSmartCenterDriver implements TvRemoteDriver {
  VestelSmartCenterDriver({required this._arcelikDelegate});

  final ArcelikGrundigDriver _arcelikDelegate;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.vestelSmart56789;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.youtubePlaylistBeam,
        TvCapability.wakeOnLan,
      };

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    return device.copyWith(
      port: 56789,
      protocol: TvConnectionProtocol.vestelSmart56789,
      isPaired: true,
      isOnline: true,
      boardInfo: 'Vestel / Regal / Arçelik SmartCenter (Port 56789)',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final ip = device.ip.trim();
    if (await _arcelikDelegate.sendVestelSmartCenterKey(ip, command)) {
      return true;
    }
    final query = ArcelikGrundigDriver.arcelikGrundigQueryForCommand(command);
    return _arcelikDelegate.sendRawHttpGetOverTcp(
      ip,
      8085,
      '/sendrcpackage?$query',
    );
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
