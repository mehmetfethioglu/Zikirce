import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/tv_driver_contract.dart';
import '../../domain/tv_network_validators.dart';
import '../../models/cue_models.dart';
import '../crypto/tv_secret_vault.dart';

/// Persistent dual-socket LG webOS SSAP driver (`wss://:3001` + `ws://:3000`)
/// with `client-key` persistence in [TvSecretVault], full directional key support
/// via `getPointerInputSocket`, and Magic Remote air-mouse pointer + scroll wheel emulation.
class LgWebOsDriver implements TvRemoteDriver {
  LgWebOsDriver({
    required this._vault,
    TvDiagLogger? logger,
  })  : _log = logger;

  static const Duration _idleTimeout = Duration(minutes: 10);

  final TvSecretVault _vault;
  final TvDiagLogger? _log;

  WebSocket? _ssapWs;
  StreamSubscription<dynamic>? _ssapSub;
  WebSocket? _pointerWs;
  StreamSubscription<dynamic>? _pointerSub;
  String? _connectedIp;
  Timer? _idleTimer;

  int _nextReqId = 1;
  final Map<String, Completer<Map<String, dynamic>?>> _pendingRequests =
      <String, Completer<Map<String, dynamic>?>>{};
  Completer<bool>? _registerCompleter;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.lgWebOs3000;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.pointerCursor,
        TvCapability.scrollWheel,
        TvCapability.liveKeyboard,
        TvCapability.appLaunch,
        TvCapability.youtubePlaylistBeam,
        TvCapability.wakeOnLan,
      };

  static String clientKeyStorageKey(String ip) => 'webos_key_${ip.trim()}';

  /// Builds the LG webOS SSAP `register` handshake payload including optional stored [clientKey].
  static Map<String, Object?> buildRegisterPayload({String? clientKey}) {
    return <String, Object?>{
      'id': 'reg_0',
      'type': 'register',
      'payload': <String, Object?>{
        'pairingType': 'PROMPT',
        if (clientKey != null && clientKey.trim().isNotEmpty)
          'client-key': clientKey.trim(),
        'manifest': <String, Object?>{
          'manifestVersion': 1,
          'appVersion': '2.0.0',
          'signed': <String, Object?>{
            'appId': 'com.akarworks.cuedeck',
            'vendorId': 'com.akarworks',
            'localizedAppNames': <String, String>{'': 'CueDeck Remote'},
            'permissions': const <String>[
              'LAUNCH',
              'LAUNCH_WEBAPP',
              'APP_TO_APP',
              'CLOSE',
              'CONTROL_AUDIO',
              'CONTROL_INPUT_TEXT',
              'CONTROL_MOUSE_AND_KEYBOARD',
              'CONTROL_POWER',
              'CONTROL_TV_CHANNEL',
              'READ_INSTALLED_APPS',
              'READ_CURRENT_CHANNEL',
              'READ_TV_CHANNEL_LIST',
            ],
          },
        },
      },
    };
  }

  /// Maps directional/navigation [TvKeyCommand] to LG PointerInputSocket `button` names.
  static String? pointerButtonNameForKey(TvKeyCommand command) {
    switch (command) {
      case TvKeyCommand.up:
        return 'UP';
      case TvKeyCommand.down:
        return 'DOWN';
      case TvKeyCommand.left:
        return 'LEFT';
      case TvKeyCommand.right:
        return 'RIGHT';
      case TvKeyCommand.ok:
        return 'ENTER';
      case TvKeyCommand.back:
        return 'BACK';
      case TvKeyCommand.home:
        return 'HOME';
      case TvKeyCommand.menu:
        return 'MENU';
      case TvKeyCommand.inputs:
        return 'LIST';
      case TvKeyCommand.channelUp:
        return 'CHANNELUP';
      case TvKeyCommand.channelDown:
        return 'CHANNELDOWN';
      case TvKeyCommand.voiceAssist:
      case TvKeyCommand.search:
        return 'HOME';
      default:
        return null;
    }
  }

  /// Formats a PointerInputSocket `type:move` frame for Magic Remote cursor motion.
  static String buildPointerMoveFrame(double dx, double dy) {
    final sx = (dx * 1.45).round().clamp(-120, 120);
    final sy = (dy * 1.45).round().clamp(-120, 120);
    return 'type:move\ndx:$sx\ndy:$sy\ndrag:0\n\n';
  }

  /// Formats a PointerInputSocket `type:scroll` frame for Magic Remote scroll wheel.
  static String buildPointerScrollFrame(int wheelClicks) {
    final dy = (wheelClicks.clamp(-8, 8)) * 40;
    return 'type:scroll\ndx:0\ndy:$dy\n\n';
  }

  /// Formats a PointerInputSocket `type:button` press frame.
  static String buildPointerButtonFrame(String buttonName) =>
      'type:button\nname:$buttonName\n\n';

  /// Formats a PointerInputSocket `type:click` frame.
  static String buildPointerClickFrame() => 'type:click\n\n';

  void _diag(String msg) => _log?.call(msg);

  void _scheduleIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _closeAllSockets);
  }

  void _closeAllSockets() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _ssapSub?.cancel();
    _ssapSub = null;
    _pointerSub?.cancel();
    _pointerSub = null;

    final ssap = _ssapWs;
    final ptr = _pointerWs;
    _ssapWs = null;
    _pointerWs = null;
    _connectedIp = null;

    if (ssap != null) {
      unawaited(ssap.close().catchError((Object e) {
        _diag('LG SSAP close err: $e');
        return null;
      }));
    }
    if (ptr != null) {
      unawaited(ptr.close().catchError((Object e) {
        _diag('LG Pointer close err: $e');
        return null;
      }));
    }

    if (_registerCompleter != null && !_registerCompleter!.isCompleted) {
      _registerCompleter!.complete(false);
    }
    _registerCompleter = null;

    for (final c in _pendingRequests.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _pendingRequests.clear();
  }

  void _closePointerSocket() {
    _pointerSub?.cancel();
    _pointerSub = null;
    final ptr = _pointerWs;
    _pointerWs = null;
    if (ptr != null) {
      unawaited(ptr.close().catchError((Object e) {
        _diag('LG Pointer close err: $e');
        return null;
      }));
    }
  }

  Future<bool> _ensureRegistered(
    String ip, {
    bool waitForUserPrompt = false,
  }) async {
    final cleanIp = ip.trim();
    if (!TvNetworkValidators.isValidIp(cleanIp)) return false;
    if (_ssapWs != null &&
        _connectedIp == cleanIp &&
        _ssapWs!.readyState == WebSocket.open) {
      _scheduleIdle();
      return true;
    }

    _closeAllSockets();
    final savedClientKey = await _vault.readSecret(clientKeyStorageKey(cleanIp));
    final hasSavedKey =
        savedClientKey != null && savedClientKey.trim().isNotEmpty;
    final isFirstUnpairedPrompt =
        !hasSavedKey && !Platform.environment.containsKey('FLUTTER_TEST');

    for (final useTls in <bool>[true, false]) {
      try {
        final url = useTls ? 'wss://$cleanIp:3001' : 'ws://$cleanIp:3000';
        final client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 2200)
          ..badCertificateCallback = (X509Certificate cert, String host, _) =>
              TvNetworkValidators.isPrivateLanIp(host) && cert.der.isNotEmpty;

        final ws = await WebSocket.connect(url, customClient: client).timeout(
          const Duration(milliseconds: 2600),
        );
        ws.pingInterval = const Duration(seconds: 20);
        _ssapWs = ws;
        _connectedIp = cleanIp;
        final regCompleter = Completer<bool>();
        _registerCompleter = regCompleter;

        _ssapSub = ws.listen(
          (dynamic raw) {
            if (raw is! String) return;
            try {
              final decoded = jsonDecode(raw);
              if (decoded is! Map) return;
              final map = decoded.cast<String, dynamic>();
              final id = map['id']?.toString() ?? '';
              final type = map['type']?.toString() ?? '';

              if (type == 'registered') {
                final payload = map['payload'];
                if (payload is Map) {
                  final key = payload['client-key']?.toString().trim() ?? '';
                  if (key.isNotEmpty) {
                    unawaited(
                      _vault.writeSecret(clientKeyStorageKey(cleanIp), key),
                    );
                  }
                }
                if (!regCompleter.isCompleted) regCompleter.complete(true);
              } else if (type == 'error' && id == 'reg_0') {
                if (!regCompleter.isCompleted) regCompleter.complete(false);
              } else if (id.isNotEmpty && _pendingRequests.containsKey(id)) {
                final pending = _pendingRequests.remove(id);
                if (pending != null && !pending.isCompleted) {
                  pending.complete(map);
                }
              }
            } catch (e) {
              _diag('LG SSAP JSON parse hatası: $e');
            }
          },
          onError: (Object e) {
            _diag('LG SSAP WS hata ($cleanIp): $e');
            _closeAllSockets();
          },
          onDone: _closeAllSockets,
          cancelOnError: false,
        );

        ws.add(jsonEncode(buildRegisterPayload(clientKey: savedClientKey)));

        final registerTimeout = waitForUserPrompt
            ? const Duration(seconds: 20)
            : (isFirstUnpairedPrompt
                ? const Duration(seconds: 18)
                : const Duration(milliseconds: 3800));
        final ok = await regCompleter.future.timeout(
          registerTimeout,
          onTimeout: () => false,
        );
        if (ok) {
          _scheduleIdle();
          _diag('LG webOS bağlandı: $url');
          return true;
        }
        _closeAllSockets();
      } catch (e) {
        _diag('LG ${useTls ? 3001 : 3000} bağlantı hatası ($cleanIp): $e');
        _closeAllSockets();
      }
    }
    return false;
  }

  Future<Map<String, dynamic>?> _sendSsapRequest(
    String ip,
    String uri, {
    Map<String, Object?>? payload,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final ready = await _ensureRegistered(ip);
      if (!ready || _ssapWs == null || _ssapWs!.readyState != WebSocket.open) {
        _closeAllSockets();
        continue;
      }

      final reqId = 'cmd_${_nextReqId++}';
      final completer = Completer<Map<String, dynamic>?>();
      _pendingRequests[reqId] = completer;

      try {
        _ssapWs!.add(
          jsonEncode(<String, Object?>{
            'id': reqId,
            'type': 'request',
            'uri': uri,
            'payload': ?payload,
          }),
        );
        _scheduleIdle();
        final resp = await completer.future.timeout(
          const Duration(milliseconds: 2000),
          onTimeout: () {
            _pendingRequests.remove(reqId);
            return null;
          },
        );
        if (resp != null) {
          if (resp['type'] == 'error') {
            _diag('LG SSAP hata yanıtı ($uri): ${resp['error'] ?? resp}');
            return null;
          }
          return resp;
        }
      } catch (e) {
        _pendingRequests.remove(reqId);
        _diag('LG SSAP request hatası ($uri): $e');
      }
      _closeAllSockets();
    }
    return null;
  }

  Future<WebSocket?> _ensurePointerSocket(String ip) async {
    final cleanIp = ip.trim();
    if (_pointerWs != null &&
        _connectedIp == cleanIp &&
        _pointerWs!.readyState == WebSocket.open) {
      _scheduleIdle();
      return _pointerWs;
    }

    final resp = await _sendSsapRequest(
      cleanIp,
      'ssap://com.webos.service.networkinput/getPointerInputSocket',
    );
    final payload = resp?['payload'];
    final socketPath =
        payload is Map ? payload['socketPath']?.toString().trim() ?? '' : '';
    if (socketPath.isEmpty) return null;

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 2200)
        ..badCertificateCallback = (X509Certificate cert, String host, _) =>
            TvNetworkValidators.isPrivateLanIp(host) && cert.der.isNotEmpty;
      final ptrWs = await WebSocket.connect(socketPath, customClient: client)
          .timeout(const Duration(milliseconds: 2600));
      ptrWs.pingInterval = const Duration(seconds: 20);
      _pointerWs = ptrWs;
      _pointerSub?.cancel();
      _pointerSub = ptrWs.listen(
        (_) {},
        onError: (Object e) {
          _diag('LG Pointer socket hata: $e');
          _closePointerSocket();
        },
        onDone: _closePointerSocket,
        cancelOnError: false,
      );
      _scheduleIdle();
      return ptrWs;
    } catch (e) {
      _diag('LG Pointer socket bağlantı hatası: $e');
      _closePointerSocket();
      return null;
    }
  }

  Future<bool> _sendPointerFrame(String ip, String frame) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final ptrWs = await _ensurePointerSocket(ip);
      if (ptrWs == null || ptrWs.readyState != WebSocket.open) {
        _closePointerSocket();
        continue;
      }
      try {
        ptrWs.add(frame);
        _scheduleIdle();
        return true;
      } catch (e) {
        _diag('LG Pointer frame hatası: $e');
        _closePointerSocket();
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
        boardInfo: 'Geçersiz LG webOS IP adresi',
      );
    }
    final ok = await _ensureRegistered(cleanIp, waitForUserPrompt: true);
    if (ok) {
      await _ensurePointerSocket(cleanIp);
    }
    return device.copyWith(
      port: ok ? 3001 : device.port,
      protocol: TvConnectionProtocol.lgWebOs3000,
      isPaired: ok,
      isOnline: ok,
      boardInfo: ok
          ? 'LG webOS Smart TV • Magic Pointer & SSAP Hazır'
          : 'LG TV ekranında eşleşme onayını kabul edin ve tekrar deneyin',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final cleanIp = device.ip.trim();
    final pointerButton = pointerButtonNameForKey(command);
    if (command == TvKeyCommand.channelUp ||
        command == TvKeyCommand.channelDown) {
      if (pointerButton != null &&
          await _sendPointerFrame(
            cleanIp,
            buildPointerButtonFrame(pointerButton),
          )) {
        return true;
      }
      final uri = command == TvKeyCommand.channelUp
          ? 'ssap://tv/channelUp'
          : 'ssap://tv/channelDown';
      final res = await _sendSsapRequest(cleanIp, uri);
      return res != null;
    }

    if (pointerButton != null) {
      if (await _sendPointerFrame(
        cleanIp,
        buildPointerButtonFrame(pointerButton),
      )) {
        return true;
      }
      if (command == TvKeyCommand.ok) {
        final res = await _sendSsapRequest(
          cleanIp,
          'ssap://com.webos.service.ime/sendEnterKey',
        );
        return res != null;
      }
      return false;
    }

    String uri;
    Map<String, Object?>? payload;
    switch (command) {
      case TvKeyCommand.volUp:
        uri = 'ssap://audio/volumeUp';
      case TvKeyCommand.volDown:
        uri = 'ssap://audio/volumeDown';
      case TvKeyCommand.mute:
        uri = 'ssap://audio/setMute';
        payload = const <String, Object?>{'mute': true};
      case TvKeyCommand.power:
        uri = 'ssap://system/turnOff';
      case TvKeyCommand.playPause:
        uri = 'ssap://media.controls/play';
      case TvKeyCommand.rewind:
        uri = 'ssap://media.controls/rewind';
      case TvKeyCommand.fastForward:
        uri = 'ssap://media.controls/fastForward';
      default:
        uri = 'ssap://com.webos.service.ime/sendEnterKey';
    }

    final res = await _sendSsapRequest(cleanIp, uri, payload: payload);
    if (res == null &&
        command == TvKeyCommand.power &&
        TvNetworkValidators.isValidMacAddress(device.macAddress)) {
      return wakeOnLan(device);
    }
    return res != null;
  }

  @override
  Future<bool> movePointer(TvDevice device, double dx, double dy) =>
      _sendPointerFrame(device.ip.trim(), buildPointerMoveFrame(dx, dy));

  @override
  Future<bool> clickPointer(TvDevice device, {bool rightClick = false}) async {
    if (rightClick) return sendKey(device, TvKeyCommand.back);
    if (await _sendPointerFrame(device.ip.trim(), buildPointerClickFrame())) {
      return true;
    }
    return sendKey(device, TvKeyCommand.ok);
  }

  @override
  Future<bool> scrollWheel(TvDevice device, int wheelClicks) =>
      _sendPointerFrame(
        device.ip.trim(),
        buildPointerScrollFrame(wheelClicks),
      );

  @override
  Future<bool> sendText(
    TvDevice device,
    String text, {
    bool submitEnter = false,
  }) async {
    if (text.isEmpty) return false;
    final cleanIp = device.ip.trim();
    final res = await _sendSsapRequest(
      cleanIp,
      'ssap://com.webos.service.ime/insertText',
      payload: <String, Object?>{'text': text, 'replace': 0},
    );
    if (submitEnter) {
      await sendEnter(device);
    }
    return res != null;
  }

  @override
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) async {
    final res = await _sendSsapRequest(
      device.ip.trim(),
      'ssap://com.webos.service.ime/deleteCharacters',
      payload: <String, Object?>{'count': count.clamp(1, 20)},
    );
    return res != null;
  }

  @override
  Future<bool> sendEnter(TvDevice device) async {
    final res = await _sendSsapRequest(
      device.ip.trim(),
      'ssap://com.webos.service.ime/sendEnterKey',
    );
    return res != null;
  }

  @override
  Future<bool> launchContent(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async {
    String? appId;
    switch (platform) {
      case StreamingPlatform.youtube:
        appId = 'youtube.leanback.v4';
      case StreamingPlatform.netflix:
        appId = 'netflix';
      case StreamingPlatform.primeVideo:
        appId = 'amazon';
      case StreamingPlatform.disneyPlus:
        appId = 'com.disney.disneyplus-prod';
      case StreamingPlatform.spotify:
        appId = 'spotify-beehive';
      case StreamingPlatform.tvBrowser:
        appId = 'com.webos.app.browser';
      default:
        appId = null;
    }
    if (appId == null) return false;

    final payload = <String, Object?>{'id': appId};
    final cleanLink = WatchCueItem.normalizeContentLink(platform, deepLinkUrl);
    if (cleanLink.isNotEmpty) {
      payload['params'] = <String, Object?>{'contentTarget': cleanLink};
    }

    final res = await _sendSsapRequest(
      device.ip.trim(),
      'ssap://system.launcher/launch',
      payload: payload,
    );
    return res != null;
  }

  @override
  Future<bool> wakeOnLan(TvDevice device) =>
      WakeOnLanService.sendMagicPacket(device.macAddress, targetIp: device.ip);

  @override
  void dispose() => _closeAllSockets();
}
