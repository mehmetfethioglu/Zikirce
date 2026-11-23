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
    if (!TvNetworkValidators.isValidIp(ip) ||
        (command == TvKeyCommand.power && device.hasValidMac)) {
      if (command == TvKeyCommand.power && device.hasValidMac) {
        return wakeOnLan(device);
      }
      return false;
    }
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
    bool clearExisting = false,
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

enum _ArcelikTransport { arWebsocket, http8085, vestel56789, ws7681 }

/// Arçelik / Beko / Grundig Smart Inter@ctive (`Port 8085`, `Port 8080` `ArWebsocket`,
/// `_arceliktvremote` `Port 7681` WebSocket, and `Port 56789` SmartCenter fallback)
/// plus UPnP fallback for closed chassis TVs.
class ArcelikGrundigDriver implements TvRemoteDriver {
  ArcelikGrundigDriver({
    required this._openLanSocket,
    required this._upnpFallback,
    required this._dialAppUrls,
    TvDiagLogger? logger,
  })  : _log = logger;

  static const Duration _wsIdleTimeout = Duration(minutes: 10);

  final LanSocketFactory _openLanSocket;
  final UpnpDlnaDriver _upnpFallback;
  final Map<String, String> _dialAppUrls;
  final TvDiagLogger? _log;

  WebSocket? _ws7681;
  String? _ws7681Ip;
  Timer? _idleTimer;

  WebSocket? _arWs;
  HttpClient? _arWsClient;
  StreamSubscription<dynamic>? _arWsSub;
  String? _arWsIp;
  int? _arWsPort;
  int _arWsCommandId = 1;
  Timer? _arWsIdleTimer;
  final Map<String, _ArcelikTransport> _transportByIp =
      <String, _ArcelikTransport>{};

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.arcelikGrundig8085;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.liveKeyboard,
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

  /// Maps [TvKeyCommand] to Arçelik/Beko/Grundig `ArWebsocket` `on-rc-input` key names.
  static String arcelikArWebsocketKeyForCommand(TvKeyCommand command) {
    switch (command) {
      case TvKeyCommand.up:
        return 'RC_NAV_UP';
      case TvKeyCommand.down:
        return 'RC_NAV_DOWN';
      case TvKeyCommand.left:
        return 'RC_NAV_LEFT';
      case TvKeyCommand.right:
        return 'RC_NAV_RIGHT';
      case TvKeyCommand.ok:
        return 'RC_OK';
      case TvKeyCommand.back:
        return 'RC_BACK';
      case TvKeyCommand.home:
        return 'RC_INTERNET';
      case TvKeyCommand.menu:
        return 'RC_MENU';
      case TvKeyCommand.inputs:
        return 'RC_SOURCE';
      case TvKeyCommand.volUp:
        return 'RC_VOLUME_UP';
      case TvKeyCommand.volDown:
        return 'RC_VOLUME_DOWN';
      case TvKeyCommand.mute:
        return 'RC_MUTE';
      case TvKeyCommand.power:
        return 'RC_POWER';
      case TvKeyCommand.playPause:
        return 'RC_PLAYER_PLAY';
      case TvKeyCommand.rewind:
        return 'RC_PLAYER_FR';
      case TvKeyCommand.fastForward:
        return 'RC_PLAYER_FF';
      case TvKeyCommand.channelUp:
        return 'RC_CHANNEL_UP';
      case TvKeyCommand.channelDown:
        return 'RC_CHANNEL_DOWN';
      case TvKeyCommand.voiceAssist:
      case TvKeyCommand.search:
        return 'RC_INTERNET';
    }
  }

  /// Builds a JSON command frame for the Arçelik/Beko/Grundig `ArWebsocket` protocol.
  static String buildArWebsocketCommandPayload({
    required int commandId,
    required String command,
    Map<String, Object?> arguments = const <String, Object?>{},
  }) {
    return jsonEncode(<String, Object?>{
      'commandId': commandId,
      'command': command,
      'arguments': arguments,
    });
  }

  /// Builds an `on-rc-input` JSON command frame for [command].
  static String buildArWebsocketRcKeyPayload(
    TvKeyCommand command, {
    int commandId = 1,
  }) {
    return buildArWebsocketCommandPayload(
      commandId: commandId,
      command: 'on-rc-input',
      arguments: <String, Object?>{
        'key': arcelikArWebsocketKeyForCommand(command),
      },
    );
  }

  /// Builds an `on-keyboard-input` JSON command frame for a single key/character.
  static String buildArWebsocketKeyboardPayload(
    String key, {
    int commandId = 1,
  }) {
    return buildArWebsocketCommandPayload(
      commandId: commandId,
      command: 'on-keyboard-input',
      arguments: <String, Object?>{'key': key},
    );
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
        return false;
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
    TvKeyCommand command, {
    int? preferredPort,
  }) async {
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
      if (preferredPort != null &&
          preferredPort > 0 &&
          preferredPort != 56789) ...<String>[
        'http://$ip:$preferredPort/apps/SmartCenter',
        'http://$ip:$preferredPort/apps/vr/remote',
      ],
      'http://$ip:56789/apps/SmartCenter',
      'http://$ip:56789/apps/vr/remote',
      if (preferredPort != 56791) 'http://$ip:56791/apps/vr/remote',
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

  void _scheduleArWsIdle() {
    _arWsIdleTimer?.cancel();
    _arWsIdleTimer = Timer(_wsIdleTimeout, _closeArWsSocket);
  }

  void _closeArWsSocket() {
    _arWsIdleTimer?.cancel();
    _arWsIdleTimer = null;
    _arWsSub?.cancel();
    _arWsSub = null;
    final ws = _arWs;
    final client = _arWsClient;
    _arWs = null;
    _arWsClient = null;
    _arWsIp = null;
    _arWsPort = null;
    if (ws != null) {
      unawaited(ws.close().catchError((Object e) {
        _log?.call('ArWebsocket close err: $e');
        return null;
      }));
    }
    client?.close(force: true);
  }

  int _arWsPortForDevice(TvDevice device) {
    if (device.port == 7681 ||
        (device.port > 0 &&
            device.port != 8085 &&
            device.port != 8080 &&
            device.port != 56789)) {
      return device.port;
    }
    return 8080;
  }

  List<(int port, bool useTls)> _arWsCandidates(int? preferredPort) {
    final isTestEnv = Platform.environment.containsKey('FLUTTER_TEST');
    if (preferredPort != null &&
        preferredPort > 0 &&
        preferredPort != 8080 &&
        preferredPort != 8085 &&
        preferredPort != 7681 &&
        preferredPort != 56789) {
      return isTestEnv
          ? <(int, bool)>[(preferredPort, false), (preferredPort, true)]
          : <(int, bool)>[(preferredPort, true), (preferredPort, false)];
    }
    if (preferredPort == 7681) {
      return const <(int, bool)>[
        (7681, true),
        (7681, false),
        (8080, true),
        (8080, false),
      ];
    }
    return const <(int, bool)>[
      (8080, true),
      (8080, false),
      (7681, true),
      (7681, false),
    ];
  }

  Future<({WebSocket ws, HttpClient client})?> _connectArWebsocket(
    String ip,
    int port, {
    required bool useTls,
    required Duration timeout,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = 'okhttp/3.12.1'
      ..badCertificateCallback = (X509Certificate cert, String host, _) =>
          TvNetworkValidators.isPrivateLanIp(host) && cert.der.isNotEmpty;
    try {
      final scheme = useTls ? 'wss' : 'ws';
      final originScheme = useTls ? 'https' : 'http';
      final ws = await WebSocket.connect(
        '$scheme://$ip:$port/',
        protocols: const <String>['ArWebsocket'],
        headers: <String, Object>{
          'Origin': '$originScheme://$ip:$port',
        },
        customClient: client,
      ).timeout(timeout + const Duration(milliseconds: 300));
      return (ws: ws, client: client);
    } catch (e) {
      client.close(force: true);
      _log?.call('ArWebsocket ($ip:$port tls=$useTls) hata: $e');
      return null;
    }
  }

  Future<bool> _ensureArWebsocketConnected(
    String ip, {
    int? preferredPort,
    Duration connectTimeout = const Duration(milliseconds: 1400),
  }) async {
    final cleanIp = ip.trim();
    if (!TvNetworkValidators.isValidIp(cleanIp)) return false;
    if (_arWs != null &&
        _arWsIp == cleanIp &&
        _arWs!.readyState == WebSocket.open &&
        (preferredPort == null || _arWsPort == preferredPort)) {
      _scheduleArWsIdle();
      return true;
    }

    _closeArWsSocket();
    for (final (port, useTls) in _arWsCandidates(preferredPort)) {
      final conn = await _connectArWebsocket(
        cleanIp,
        port,
        useTls: useTls,
        timeout: connectTimeout,
      );
      if (conn == null) continue;
      final ws = conn.ws;
      ws.pingInterval = const Duration(seconds: 20);
      _arWs = ws;
      _arWsClient = conn.client;
      _arWsIp = cleanIp;
      _arWsPort = port;
      _arWsSub = ws.listen(
        (_) {},
        onError: (Object e) {
          _log?.call('ArWebsocket stream err ($cleanIp:$port): $e');
          _closeArWsSocket();
        },
        onDone: _closeArWsSocket,
        cancelOnError: false,
      );
      _scheduleArWsIdle();
      _log?.call('ArWebsocket bağlandı: $cleanIp:$port (tls=$useTls)');
      return true;
    }
    return false;
  }

  /// Probes whether [ip]:[port] accepts an `ArWebsocket` upgrade without leaving open sockets.
  Future<bool> probeArWebsocket(
    String ip, {
    int port = 8080,
    Duration timeout = const Duration(milliseconds: 650),
  }) async {
    final cleanIp = ip.trim();
    if (!TvNetworkValidators.isValidIp(cleanIp) || port <= 0) return false;
    for (final useTls in const <bool>[true, false]) {
      final conn = await _connectArWebsocket(
        cleanIp,
        port,
        useTls: useTls,
        timeout: timeout,
      );
      if (conn == null) continue;
      try {
        await conn.ws.close().catchError((Object e) {
          _log?.call('ArWebsocket probe close err: $e');
          return null;
        });
      } finally {
        conn.client.close();
      }
      return true;
    }
    return false;
  }

  Future<bool> _sendArWebsocketCommand(
    String ip,
    String command,
    Map<String, Object?> arguments, {
    int? preferredPort,
  }) async {
    final cleanIp = ip.trim();
    if (!TvNetworkValidators.isValidIp(cleanIp)) return false;
    for (var attempt = 0; attempt < 2; attempt++) {
      final connected = await _ensureArWebsocketConnected(
        cleanIp,
        preferredPort: preferredPort,
      );
      if (!connected || _arWs == null || _arWs!.readyState != WebSocket.open) {
        _closeArWsSocket();
        continue;
      }
      try {
        final payload = buildArWebsocketCommandPayload(
          commandId: _arWsCommandId++,
          command: command,
          arguments: arguments,
        );
        _arWs!.add(payload);
        _scheduleArWsIdle();
        return true;
      } catch (e) {
        _log?.call('ArWebsocket send ($command) hatası: $e');
        _closeArWsSocket();
      }
    }
    return false;
  }

  Future<bool> sendArcelikArWebsocketKey(
    String ip,
    TvKeyCommand command, {
    int? preferredPort,
  }) {
    return _sendArWebsocketCommand(
      ip,
      'on-rc-input',
      <String, Object?>{'key': arcelikArWebsocketKeyForCommand(command)},
      preferredPort: preferredPort,
    );
  }

  /// Sends keyboard backspace (`\b`) events over `ArWebsocket` to clear active search input
  /// without ever sending `RC_BACK`.
  Future<bool> clearArWebsocketText(
    String ip, {
    int count = 16,
    int? preferredPort,
  }) async {
    final cleanIp = ip.trim();
    if (!await _ensureArWebsocketConnected(
      cleanIp,
      preferredPort: preferredPort,
    )) {
      return false;
    }
    final safeCount = count.clamp(1, 28);
    final isTestEnv = Platform.environment.containsKey('FLUTTER_TEST');
    var anyOk = false;
    for (var i = 0; i < safeCount; i++) {
      final ok = await _sendArWebsocketCommand(
        cleanIp,
        'on-keyboard-input',
        const <String, Object?>{'key': '\b'},
        preferredPort: preferredPort,
      );
      if (ok) anyOk = true;
      if (!isTestEnv) {
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
    }
    return anyOk;
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
        _idleTimer = Timer(_wsIdleTimeout, _close7681Socket);
        return true;
      } catch (e) {
        _log?.call('Arçelik 7681 WS send hatası: $e');
        _close7681Socket();
      }
    }

    for (final proto in const <List<String>>[
      <String>['ArWebsocket'],
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
        _idleTimer = Timer(_wsIdleTimeout, _close7681Socket);
        return true;
      } catch (e) {
        _log?.call('Arçelik 7681 handshake ($proto): $e');
      }
    }
    return false;
  }

  Future<bool> _sendViaTransport(
    _ArcelikTransport transport,
    TvDevice device,
    String ip,
    TvKeyCommand command,
  ) async {
    switch (transport) {
      case _ArcelikTransport.arWebsocket:
        return sendArcelikArWebsocketKey(
          ip,
          command,
          preferredPort: _arWsPortForDevice(device),
        );
      case _ArcelikTransport.http8085:
        final query = arcelikGrundigQueryForCommand(command);
        final targetPort = (device.port > 0 &&
                device.port != 8080 &&
                device.port != 7681 &&
                device.port != 56789)
            ? device.port
            : 8085;
        return sendRawHttpGetOverTcp(ip, targetPort, '/sendrcpackage?$query');
      case _ArcelikTransport.vestel56789:
        return sendVestelSmartCenterKey(
          ip,
          command,
          preferredPort: device.port,
        );
      case _ArcelikTransport.ws7681:
        return _tryArcelik7681WebSocket(ip, command);
    }
  }

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    final ip = device.ip.trim();
    if (TvNetworkValidators.isValidIp(ip)) {
      final probePort = _arWsPortForDevice(device);
      if (await probeArWebsocket(ip, port: probePort)) {
        return device.copyWith(
          port: probePort,
          protocol: TvConnectionProtocol.arcelikGrundig8085,
          isPaired: true,
          isOnline: true,
          boardInfo: 'Arçelik / Beko / Grundig Smart TV • ArWebsocket',
        );
      }
    }
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
    if (!TvNetworkValidators.isValidIp(ip)) {
      if (command == TvKeyCommand.power && device.hasValidMac) {
        return wakeOnLan(device);
      }
      return false;
    }

    final cached = _transportByIp[ip];
    if (cached != null) {
      if (await _sendViaTransport(cached, device, ip, command)) {
        return true;
      }
      _transportByIp.remove(ip);
    }

    final hasCustomPort = device.port > 0 &&
        device.port != 8085 &&
        device.port != 8080 &&
        device.port != 7681 &&
        device.port != 56789;

    final order = <_ArcelikTransport>[
      if (hasCustomPort) _ArcelikTransport.http8085,
      _ArcelikTransport.arWebsocket,
      if (!hasCustomPort) _ArcelikTransport.http8085,
      _ArcelikTransport.vestel56789,
      _ArcelikTransport.ws7681,
    ];

    for (final transport in order) {
      if (await _sendViaTransport(transport, device, ip, command)) {
        _transportByIp[ip] = transport;
        return true;
      }
    }
    if (await _upnpFallback.sendKey(device, command)) {
      return true;
    }
    if (command == TvKeyCommand.power && device.hasValidMac) {
      return wakeOnLan(device);
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
    bool clearExisting = false,
  }) async {
    final ip = device.ip.trim();
    if (text.isEmpty || !TvNetworkValidators.isValidIp(ip)) return false;
    final preferred = _arWsPortForDevice(device);
    if (!await _ensureArWebsocketConnected(ip, preferredPort: preferred)) {
      return false;
    }
    if (clearExisting) {
      await clearArWebsocketText(ip, count: 20, preferredPort: preferred);
    }
    final isTestEnv = Platform.environment.containsKey('FLUTTER_TEST');
    var anyOk = false;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final ok = await _sendArWebsocketCommand(
        ip,
        'on-keyboard-input',
        <String, Object?>{'key': ch},
        preferredPort: preferred,
      );
      if (ok) anyOk = true;
      if (!isTestEnv) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
    if (anyOk && submitEnter) {
      if (!isTestEnv) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await sendArcelikArWebsocketKey(
        ip,
        TvKeyCommand.ok,
        preferredPort: preferred,
      );
    }
    return anyOk;
  }

  @override
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) async {
    final ip = device.ip.trim();
    if (await clearArWebsocketText(
      ip,
      count: count,
      preferredPort: _arWsPortForDevice(device),
    )) {
      return true;
    }
    return sendKey(device, TvKeyCommand.back);
  }

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
  void dispose() {
    _close7681Socket();
    _closeArWsSocket();
    _transportByIp.clear();
  }
}

/// Vestel / Regal / Toshiba / Arçelik SmartCenter (`Port 56789`) driver.
class VestelSmartCenterDriver implements TvRemoteDriver {
  VestelSmartCenterDriver({
    required this._arcelikDelegate,
    this.arcelikFallbackPort = 8080,
  });

  final ArcelikGrundigDriver _arcelikDelegate;
  final int arcelikFallbackPort;
  final Set<String> _arcelikFallbackIps = <String>{};

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
    if (!TvNetworkValidators.isValidIp(ip)) {
      if (command == TvKeyCommand.power && device.hasValidMac) {
        return wakeOnLan(device);
      }
      return false;
    }
    if (_arcelikFallbackIps.contains(ip)) {
      if (await _arcelikDelegate.sendArcelikArWebsocketKey(
        ip,
        command,
        preferredPort: arcelikFallbackPort,
      )) {
        return true;
      }
      _arcelikFallbackIps.remove(ip);
    }
    if (await _arcelikDelegate.sendVestelSmartCenterKey(
      ip,
      command,
      preferredPort: device.port,
    )) {
      return true;
    }
    if (await _arcelikDelegate.sendArcelikArWebsocketKey(
      ip,
      command,
      preferredPort: arcelikFallbackPort,
    )) {
      _arcelikFallbackIps.add(ip);
      return true;
    }
    final query = ArcelikGrundigDriver.arcelikGrundigQueryForCommand(command);
    if (await _arcelikDelegate.sendRawHttpGetOverTcp(
      ip,
      8085,
      '/sendrcpackage?$query',
    )) {
      return true;
    }
    if (command == TvKeyCommand.power && device.hasValidMac) {
      return wakeOnLan(device);
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
  void dispose() {
    _arcelikFallbackIps.clear();
  }
}
