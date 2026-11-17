import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/tv_driver_contract.dart';
import '../../domain/tv_network_validators.dart';
import '../../models/cue_models.dart';
import '../crypto/tv_secret_vault.dart';

/// Persistent WebSocket (`wss://:8002` + `ws://:8001` fallback) & Wake-on-LAN driver
/// for Samsung Tizen Smart TVs (2016–2026). Captures and stores the `ms.channel.connect`
/// authorization `token` inside [TvSecretVault] so users are only prompted once.
class SamsungTizenDriver implements TvRemoteDriver {
  SamsungTizenDriver({
    required this._vault,
    TvDiagLogger? logger,
  })  : _log = logger;

  static const String _encodedAppName = 'Q3VlRGVjaw=='; // Base64("CueDeck")
  static const Duration _idleTimeout = Duration(seconds: 45);

  final TvSecretVault _vault;
  final TvDiagLogger? _log;

  WebSocket? _ws;
  StreamSubscription<dynamic>? _wsSub;
  String? _connectedIp;
  Timer? _idleTimer;
  Completer<bool>? _connectCompleter;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.samsungTizen8001;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.liveKeyboard,
        TvCapability.appLaunch,
        TvCapability.youtubePlaylistBeam,
        TvCapability.wakeOnLan,
      };

  static String tokenStorageKey(String ip) => 'tizen_token_${ip.trim()}';

  /// Maps [TvKeyCommand] to Samsung Tizen `KEY_*` codes.
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
        return 'KEY_ENTER';
      case TvKeyCommand.back:
        return 'KEY_RETURN';
      case TvKeyCommand.home:
        return 'KEY_HOME';
      case TvKeyCommand.menu:
        return 'KEY_MENU';
      case TvKeyCommand.inputs:
        return 'KEY_SOURCE';
      case TvKeyCommand.volUp:
        return 'KEY_VOLUP';
      case TvKeyCommand.volDown:
        return 'KEY_VOLDOWN';
      case TvKeyCommand.mute:
        return 'KEY_MUTE';
      case TvKeyCommand.power:
        return 'KEY_POWER';
      case TvKeyCommand.playPause:
        return 'KEY_PLAY';
      case TvKeyCommand.rewind:
        return 'KEY_REWIND';
      case TvKeyCommand.fastForward:
        return 'KEY_FF';
      case TvKeyCommand.channelUp:
        return 'KEY_CHUP';
      case TvKeyCommand.channelDown:
        return 'KEY_CHDOWN';
      case TvKeyCommand.voiceAssist:
      case TvKeyCommand.search:
        return 'KEY_HOME';
    }
  }

  /// Builds the WebSocket URL for Samsung Tizen (`wss://:8002` with optional stored token or `ws://:8001`).
  static String buildWebSocketUrl(
    String ip, {
    required bool useTls,
    String? token,
  }) {
    final cleanIp = ip.trim();
    final tokenPart = (token != null && token.trim().isNotEmpty)
        ? '&token=${Uri.encodeQueryComponent(token.trim())}'
        : '';
    return useTls
        ? 'wss://$cleanIp:8002/api/v2/channels/samsung.remote.control?name=$_encodedAppName$tokenPart'
        : 'ws://$cleanIp:8001/api/v2/channels/samsung.remote.control?name=$_encodedAppName$tokenPart';
  }

  /// Builds a Samsung Tizen `ms.remote.control` JSON key command frame.
  static String buildControlPayload(TvKeyCommand command) {
    return jsonEncode(<String, Object?>{
      'method': 'ms.remote.control',
      'params': <String, Object?>{
        'Cmd': 'Click',
        'DataOfCmd': mapKey(command),
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    });
  }

  /// Builds a Samsung Tizen `ms.remote.ime` (`sendInputString`) Base64 text injection payload.
  static String buildImeTextPayload(String rawText) {
    final b64 = base64.encode(utf8.encode(rawText));
    return jsonEncode(<String, Object?>{
      'method': 'ms.remote.control',
      'params': <String, Object?>{
        'Cmd': b64,
        'DataOfCmd': 'base64',
        'TypeOfRemote': 'SendInputString',
      },
    });
  }

  /// Extracts a paired authorization token from a Samsung `ms.channel.connect` JSON message.
  static String? extractConnectToken(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) return null;
      if (decoded['event'] != 'ms.channel.connect') return null;
      final data = decoded['data'];
      if (data is Map) {
        final token = data['token']?.toString().trim() ?? '';
        if (token.isNotEmpty) return token;
      }
      return '';
    } catch (e) {
      return null;
    }
  }

  void _diag(String msg) => _log?.call(msg);

  void _scheduleIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _closeSocket);
  }

  void _closeSocket() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    final oldWs = _ws;
    _ws = null;
    _connectedIp = null;
    if (oldWs != null) {
      unawaited(oldWs.close().catchError((Object e) {
        _diag('Samsung WS close err: $e');
        return null;
      }));
    }
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(false);
    }
    _connectCompleter = null;
  }

  Future<bool> _ensureConnected(
    String ip, {
    bool waitForInteractiveAllow = false,
  }) async {
    final cleanIp = ip.trim();
    if (!TvNetworkValidators.isValidIp(cleanIp)) return false;
    if (_ws != null &&
        _connectedIp == cleanIp &&
        _ws!.readyState == WebSocket.open) {
      _scheduleIdle();
      return true;
    }

    _closeSocket();
    final savedToken = await _vault.readSecret(tokenStorageKey(cleanIp));
    final tryTlsOrder = <bool>[true, false];

    for (final useTls in tryTlsOrder) {
      try {
        final url = buildWebSocketUrl(
          cleanIp,
          useTls: useTls,
          token: savedToken,
        );
        final client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 1400)
          ..badCertificateCallback = (X509Certificate cert, String host, _) =>
              TvNetworkValidators.isPrivateLanIp(host) && cert.der.isNotEmpty;

        final ws = await WebSocket.connect(url, customClient: client).timeout(
          const Duration(milliseconds: 2200),
        );

        _ws = ws;
        _connectedIp = cleanIp;
        final completer = Completer<bool>();
        _connectCompleter = completer;

        _wsSub = ws.listen(
          (dynamic message) {
            if (message is! String) return;
            final token = extractConnectToken(message);
            if (token != null) {
              if (token.isNotEmpty) {
                unawaited(_vault.writeSecret(tokenStorageKey(cleanIp), token));
                _diag('Samsung Tizen token kaydedildi ($cleanIp)');
              }
              if (!completer.isCompleted) completer.complete(true);
            } else if (message.contains('ms.channel.unauthorized')) {
              if (!completer.isCompleted) completer.complete(false);
            }
          },
          onError: (Object e) {
            _diag('Samsung WS hata ($cleanIp): $e');
            _closeSocket();
          },
          onDone: _closeSocket,
          cancelOnError: false,
        );

        final waitDuration = waitForInteractiveAllow
            ? const Duration(seconds: 18)
            : const Duration(milliseconds: 1400);
        final authorized = await completer.future.timeout(
          waitDuration,
          onTimeout: () => _ws != null && _ws!.readyState == WebSocket.open,
        );
        if (authorized) {
          _scheduleIdle();
          _diag('Samsung WS bağlandı: $cleanIp:${useTls ? 8002 : 8001}');
          return true;
        }
        _closeSocket();
      } catch (e) {
        _diag('Samsung ${useTls ? 8002 : 8001} bağlantı hatası ($cleanIp): $e');
        _closeSocket();
      }
    }
    return false;
  }

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    final cleanIp = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(cleanIp)) {
      return device.copyWith(
        isOnline: false,
        boardInfo: 'Geçersiz Samsung TV IP adresi',
      );
    }
    final ok = await _ensureConnected(cleanIp, waitForInteractiveAllow: true);
    return device.copyWith(
      port: ok ? 8002 : device.port,
      protocol: TvConnectionProtocol.samsungTizen8001,
      isPaired: ok,
      isOnline: ok,
      boardInfo: ok
          ? 'Samsung Tizen Smart TV • Yetkili Oturum Hazır'
          : 'TV ekranında "CueDeck İzin Ver" uyarısını onaylayın ve tekrar deneyin',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final cleanIp = device.ip.trim();
    final connected = await _ensureConnected(cleanIp);
    if (!connected || _ws == null) {
      if (command == TvKeyCommand.power &&
          TvNetworkValidators.isValidMacAddress(device.macAddress)) {
        return wakeOnLan(device);
      }
      return false;
    }

    try {
      _ws!.add(buildControlPayload(command));
      _scheduleIdle();
      return true;
    } catch (e) {
      _diag('Samsung tuş gönderim hatası: $e');
      _closeSocket();
      return false;
    }
  }

  @override
  Future<bool> sendText(
    TvDevice device,
    String text, {
    bool submitEnter = false,
  }) async {
    final cleanIp = device.ip.trim();
    if (text.isEmpty) return false;
    final connected = await _ensureConnected(cleanIp);
    if (!connected || _ws == null) return false;
    try {
      _ws!.add(buildImeTextPayload(text));
      if (submitEnter) {
        _ws!.add(buildControlPayload(TvKeyCommand.ok));
      }
      _scheduleIdle();
      return true;
    } catch (e) {
      _diag('Samsung metin gönderim hatası: $e');
      _closeSocket();
      return false;
    }
  }

  @override
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) async {
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
  }) async {
    final cleanIp = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(cleanIp)) return false;

    String? samsungAppId;
    switch (platform) {
      case StreamingPlatform.youtube:
        samsungAppId = '111299001912';
      case StreamingPlatform.netflix:
        samsungAppId = '3201907018807';
      case StreamingPlatform.primeVideo:
        samsungAppId = '3201910019365';
      case StreamingPlatform.disneyPlus:
        samsungAppId = '3201901017640';
      case StreamingPlatform.spotify:
        samsungAppId = '3201606009684';
      default:
        samsungAppId = null;
    }

    // If launching YouTube with a specific video/playlist URL, try WebSocket deep-link first
    if (platform == StreamingPlatform.youtube &&
        deepLinkUrl.trim().isNotEmpty &&
        await _ensureConnected(cleanIp)) {
      try {
        _ws!.add(
          jsonEncode(<String, Object?>{
            'method': 'ms.channel.emit',
            'params': <String, Object?>{
              'event': 'ed.apps.launch',
              'to': 'host',
              'data': <String, Object?>{
                'appId': '111299001912',
                'action_type': 'DEEP_LINK',
                'metaTag': deepLinkUrl.trim(),
              },
            },
          }),
        );
        _scheduleIdle();
        return true;
      } catch (e) {
        _diag('Samsung WS deep-link hatası: $e');
      }
    }

    if (samsungAppId == null) return false;
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 650);
    try {
      final req = await client
          .postUrl(
            Uri.parse('http://$cleanIp:8001/api/v2/applications/$samsungAppId'),
          )
          .timeout(const Duration(milliseconds: 700));
      req.contentLength = 0;
      final resp = await req.close().timeout(const Duration(milliseconds: 700));
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (e) {
      _diag('Samsung REST app launch hatası: $e');
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
  void dispose() => _closeSocket();
}
