import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../domain/tv_driver_contract.dart';
import '../../domain/tv_network_validators.dart';
import '../../models/cue_models.dart';
import '../crypto/tv_secret_vault.dart';

/// Parsed MQTT v3.1.1 wire packet frame.
class MqttParsedPacket {
  const MqttParsedPacket({
    required this.type,
    required this.flags,
    required this.payload,
    required this.totalLength,
  });

  final int type;
  final int flags;
  final Uint8List payload;
  final int totalLength;
}

/// Zero-dependency pure-Dart MQTT v3.1.1 packet encoder & decoder tailored for
/// Hisense / Toshiba VIDAA Smart TVs on port `36669`.
class MqttV311Codec {
  MqttV311Codec._();

  static const int packetTypeConnect = 1;
  static const int packetTypeConnAck = 2;
  static const int packetTypePublish = 3;
  static const int packetTypeSubscribe = 8;
  static const int packetTypeSubAck = 9;
  static const int packetTypePingReq = 12;
  static const int packetTypePingResp = 13;
  static const int packetTypeDisconnect = 14;

  static List<int> encodeRemainingLength(int value) {
    final out = <int>[];
    var x = value;
    do {
      var encoded = x % 128;
      x = x ~/ 128;
      if (x > 0) encoded |= 128;
      out.add(encoded);
    } while (x > 0);
    return out;
  }

  static ({int value, int bytesRead})? decodeRemainingLength(
    List<int> bytes,
    int offset,
  ) {
    var multiplier = 1;
    var value = 0;
    var idx = offset;
    for (var i = 0; i < 4; i++) {
      if (idx >= bytes.length) return null;
      final encodedByte = bytes[idx++] & 0xFF;
      value += (encodedByte & 127) * multiplier;
      if ((encodedByte & 128) == 0) {
        return (value: value, bytesRead: idx - offset);
      }
      multiplier *= 128;
    }
    throw const FormatException('Malformed MQTT remaining length');
  }

  static void _writeUtf8String(BytesBuilder builder, String value) {
    final utf = utf8.encode(value);
    builder.addByte((utf.length >> 8) & 0xFF);
    builder.addByte(utf.length & 0xFF);
    builder.add(utf);
  }

  static Uint8List _wrapPacket(int headerByte, Uint8List body) {
    final rem = encodeRemainingLength(body.length);
    final builder = BytesBuilder(copy: false)
      ..addByte(headerByte)
      ..add(rem)
      ..add(body);
    return builder.takeBytes();
  }

  static Uint8List encodeConnect({
    required String clientId,
    String? username,
    String? password,
    int keepAliveSeconds = 30,
  }) {
    final body = BytesBuilder(copy: false);
    // Protocol Name "MQTT" + Protocol Level 4 (v3.1.1)
    _writeUtf8String(body, 'MQTT');
    body.addByte(0x04);

    var flags = 0x02; // Clean session
    if (username != null && username.isNotEmpty) flags |= 0x80;
    if (password != null && password.isNotEmpty) flags |= 0x40;
    body.addByte(flags);

    body.addByte((keepAliveSeconds >> 8) & 0xFF);
    body.addByte(keepAliveSeconds & 0xFF);

    _writeUtf8String(body, clientId);
    if (username != null && username.isNotEmpty) {
      _writeUtf8String(body, username);
    }
    if (password != null && password.isNotEmpty) {
      _writeUtf8String(body, password);
    }

    return _wrapPacket(0x10, body.takeBytes());
  }

  static Uint8List encodeConnAck(int returnCode) =>
      Uint8List.fromList(<int>[0x20, 0x02, 0x00, returnCode & 0xFF]);

  static Uint8List encodeSubscribe({
    required int packetId,
    required String topicFilter,
  }) {
    final body = BytesBuilder(copy: false)
      ..addByte((packetId >> 8) & 0xFF)
      ..addByte(packetId & 0xFF);
    _writeUtf8String(body, topicFilter);
    body.addByte(0x00); // QoS 0
    return _wrapPacket(0x82, body.takeBytes());
  }

  static Uint8List encodePublish({
    required String topic,
    required String payload,
  }) {
    final body = BytesBuilder(copy: false);
    _writeUtf8String(body, topic);
    if (payload.isNotEmpty) {
      body.add(utf8.encode(payload));
    }
    return _wrapPacket(0x30, body.takeBytes());
  }

  static Uint8List encodePingReq() => Uint8List.fromList(const <int>[0xC0, 0x00]);

  static Uint8List encodeDisconnect() =>
      Uint8List.fromList(const <int>[0xE0, 0x00]);

  static MqttParsedPacket? tryParsePacket(List<int> buffer) {
    if (buffer.length < 2) return null;
    final header = buffer[0] & 0xFF;
    final type = (header >> 4) & 0x0F;
    final flags = header & 0x0F;
    final rem = decodeRemainingLength(buffer, 1);
    if (rem == null) return null;
    final headerLen = 1 + rem.bytesRead;
    final totalLen = headerLen + rem.value;
    if (buffer.length < totalLen) return null;
    final payload = Uint8List.fromList(buffer.sublist(headerLen, totalLen));
    return MqttParsedPacket(
      type: type,
      flags: flags,
      payload: payload,
      totalLength: totalLen,
    );
  }

  /// Decodes a QoS-0 PUBLISH packet payload into `(topic, message)`.
  static ({String topic, String payload})? decodePublishPayload(
    Uint8List payload,
  ) {
    if (payload.length < 2) return null;
    final topicLen = ((payload[0] & 0xFF) << 8) | (payload[1] & 0xFF);
    if (2 + topicLen > payload.length) return null;
    final topic = utf8.decode(
      payload.sublist(2, 2 + topicLen),
      allowMalformed: true,
    );
    final body = utf8.decode(
      payload.sublist(2 + topicLen),
      allowMalformed: true,
    );
    return (topic: topic, payload: body);
  }
}

/// Hisense / Toshiba VIDAA OS (Port 36669) pure-Dart MQTT v3.1.1 over TLS driver
/// (following verified `newAM/hisensetv` credentials, topics, 4-digit PIN auth, and app launches),
/// with legacy WebSocket fallback when a chassis exposes WS JSON instead of MQTT.
class VidaaSmartDriver implements TvRemoteDriver {
  VidaaSmartDriver({
    this._vault,
    TvDiagLogger? logger,
    this.preferPlainTcpFirst = false,
    this.allowWebSocketFallback = true,
  }) : _log = logger;

  static const Duration _idleTimeout = Duration(minutes: 10);
  static const Duration _pingPeriod = Duration(seconds: 25);
  static const String _mqttUsername = 'hisenseservice';
  static const String _mqttPassword = 'multimqttservice';

  final TvSecretVault? _vault;
  final TvDiagLogger? _log;
  final bool preferPlainTcpFirst;
  final bool allowWebSocketFallback;

  Socket? _mqttSocket;
  StreamSubscription<Uint8List>? _mqttSub;
  String? _mqttIp;
  int _mqttPort = 36669;
  bool _mqttReady = false;
  final List<int> _mqttRxBuffer = <int>[];
  Completer<bool>? _connAckCompleter;
  Completer<bool>? _authResultCompleter;
  Timer? _idleTimer;
  Timer? _pingTimer;
  String? _cachedClientMac;
  int _nextPacketId = 1;

  WebSocket? _ws;
  StreamSubscription<dynamic>? _wsSub;
  String? _wsIp;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.vidaaSmart36669;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.liveKeyboard,
        TvCapability.appLaunch,
        TvCapability.pinPairing,
        TvCapability.wakeOnLan,
      };

  static String pairedStorageKey(String ip) => 'vidaa_paired_${ip.trim()}';

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
        return 'KEY_BACK';
      case TvKeyCommand.fastForward:
        return 'KEY_FORWARDS';
      case TvKeyCommand.channelUp:
        return 'KEY_CHANNELUP';
      case TvKeyCommand.channelDown:
        return 'KEY_CHANNELDOWN';
      case TvKeyCommand.voiceAssist:
      case TvKeyCommand.search:
        return 'KEY_SEARCH';
    }
  }

  static String buildJsonPayload(TvKeyCommand command) => jsonEncode(
        <String, String>{'action': 'sendkey', 'key': mapKey(command)},
      );

  Future<String> _getOrCreateClientMac() async {
    if (_cachedClientMac != null && _cachedClientMac!.isNotEmpty) {
      return _cachedClientMac!;
    }
    final stored = await _vault?.readSecret('vidaa_client_mac');
    if (stored != null && TvNetworkValidators.isValidMacAddress(stored)) {
      _cachedClientMac = stored.toUpperCase();
      return _cachedClientMac!;
    }
    final rng = Random.secure();
    final octets = <String>[
      '02',
      for (var i = 0; i < 5; i++)
        rng.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase(),
    ];
    final mac = octets.join(':');
    _cachedClientMac = mac;
    await _vault?.writeSecret('vidaa_client_mac', mac);
    return mac;
  }

  String _deviceTopicForMac(String mac) => '${mac.toUpperCase()}\$normal';

  void _scheduleIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _closeSockets);
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingPeriod, (_) {
      final sock = _mqttSocket;
      if (sock != null && _mqttReady) {
        try {
          sock.add(MqttV311Codec.encodePingReq());
        } catch (e) {
          _log?.call('VIDAA MQTT ping err: $e');
          _closeMqttSocket();
        }
      }
    });
  }

  void _closeMqttSocket() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _mqttSub?.cancel();
    _mqttSub = null;
    final sock = _mqttSocket;
    _mqttSocket = null;
    _mqttIp = null;
    _mqttReady = false;
    _mqttRxBuffer.clear();
    if (_connAckCompleter != null && !_connAckCompleter!.isCompleted) {
      _connAckCompleter!.complete(false);
    }
    _connAckCompleter = null;
    if (_authResultCompleter != null && !_authResultCompleter!.isCompleted) {
      _authResultCompleter!.complete(false);
    }
    _authResultCompleter = null;
    if (sock != null) {
      try {
        sock.destroy();
      } catch (e) {
        _log?.call('VIDAA MQTT socket destroy: $e');
      }
    }
  }

  void _closeWsSocket() {
    _wsSub?.cancel();
    _wsSub = null;
    final ws = _ws;
    _ws = null;
    _wsIp = null;
    if (ws != null) {
      unawaited(
        ws.close().catchError((Object e) {
          _log?.call('VIDAA WS close err: $e');
          return null;
        }),
      );
    }
  }

  void _closeSockets() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _closeMqttSocket();
    _closeWsSocket();
  }

  void _onMqttData(Uint8List chunk) {
    _mqttRxBuffer.addAll(chunk);
    while (true) {
      MqttParsedPacket? pkt;
      try {
        pkt = MqttV311Codec.tryParsePacket(_mqttRxBuffer);
      } catch (e) {
        _log?.call('VIDAA MQTT frame parse err: $e');
        _closeMqttSocket();
        return;
      }
      if (pkt == null) return;
      _mqttRxBuffer.removeRange(0, pkt.totalLength);

      if (pkt.type == MqttV311Codec.packetTypeConnAck) {
        final returnCode = pkt.payload.length >= 2 ? pkt.payload[1] : 1;
        _mqttReady = returnCode == 0;
        if (_connAckCompleter != null && !_connAckCompleter!.isCompleted) {
          _connAckCompleter!.complete(_mqttReady);
        }
      } else if (pkt.type == MqttV311Codec.packetTypePublish) {
        final decoded = MqttV311Codec.decodePublishPayload(pkt.payload);
        if (decoded != null &&
            decoded.topic.contains('authenticationcoderesult')) {
          var ok = false;
          try {
            final map = jsonDecode(decoded.payload);
            if (map is Map<String, dynamic>) {
              ok = int.tryParse('${map['result']}') == 1;
            }
          } catch (e) {
            _log?.call('VIDAA auth result parse err: $e');
            ok = false;
          }
          if (_authResultCompleter != null &&
              !_authResultCompleter!.isCompleted) {
            _authResultCompleter!.complete(ok);
          }
        }
      }
    }
  }

  Future<Socket?> _openRawMqttTransport(String ip, int port) async {
    Future<Socket?> tryTls() async {
      try {
        return await SecureSocket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 1400),
          onBadCertificate: (_) =>
              TvNetworkValidators.isPrivateLanIp(ip) || ip == '127.0.0.1',
        );
      } catch (e) {
        _log?.call('VIDAA TLS :$port hatası: $e');
        return null;
      }
    }

    Future<Socket?> tryPlain() async {
      try {
        final s = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 1400),
        );
        s.setOption(SocketOption.tcpNoDelay, true);
        return s;
      } catch (e) {
        _log?.call('VIDAA TCP :$port hatası: $e');
        return null;
      }
    }

    if (preferPlainTcpFirst) {
      return await tryPlain() ?? await tryTls();
    }
    return await tryTls() ?? await tryPlain();
  }

  Future<({bool ok, String deviceTopic})> _ensureMqttConnected(
    TvDevice device,
  ) async {
    final ip = device.ip.trim();
    final port = device.port > 0 ? device.port : 36669;
    final mac = await _getOrCreateClientMac();
    final deviceTopic = _deviceTopicForMac(mac);

    if (_mqttSocket != null &&
        _mqttReady &&
        _mqttIp == ip &&
        _mqttPort == port) {
      _scheduleIdle();
      return (ok: true, deviceTopic: deviceTopic);
    }

    _closeMqttSocket();
    final sock = await _openRawMqttTransport(ip, port);
    if (sock == null) return (ok: false, deviceTopic: deviceTopic);

    _mqttSocket = sock;
    _mqttIp = ip;
    _mqttPort = port;
    _mqttReady = false;
    _connAckCompleter = Completer<bool>();
    _mqttSub = sock.listen(
      _onMqttData,
      onError: (Object e) {
        _log?.call('VIDAA MQTT stream err ($ip): $e');
        _closeMqttSocket();
      },
      onDone: _closeMqttSocket,
      cancelOnError: false,
    );

    try {
      final clientId = 'CueDeck/$mac';
      sock.add(
        MqttV311Codec.encodeConnect(
          clientId: clientId,
          username: _mqttUsername,
          password: _mqttPassword,
          keepAliveSeconds: 30,
        ),
      );
      await sock.flush();

      final ackOk = await _connAckCompleter!.future.timeout(
        const Duration(milliseconds: 1800),
        onTimeout: () => false,
      );
      if (!ackOk || _mqttSocket == null) {
        _closeMqttSocket();
        return (ok: false, deviceTopic: deviceTopic);
      }

      final pid = _nextPacketId++;
      if (_nextPacketId > 0xFFFF) _nextPacketId = 1;
      sock.add(
        MqttV311Codec.encodeSubscribe(
          packetId: pid,
          topicFilter: '/remoteapp/mobile/$deviceTopic/#',
        ),
      );
      await sock.flush();

      _startPingTimer();
      _scheduleIdle();
      return (ok: true, deviceTopic: deviceTopic);
    } catch (e) {
      _log?.call('VIDAA MQTT handshake hatası ($ip): $e');
      _closeMqttSocket();
      return (ok: false, deviceTopic: deviceTopic);
    }
  }

  Future<bool> _publishMqtt({
    required TvDevice device,
    required String service,
    required String action,
    String payload = '',
  }) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return false;

    for (var attempt = 0; attempt < 2; attempt++) {
      final conn = await _ensureMqttConnected(device);
      if (!conn.ok || _mqttSocket == null) continue;
      final topic = '/remoteapp/tv/$service/${conn.deviceTopic}/actions/$action';
      try {
        _mqttSocket!.add(
          MqttV311Codec.encodePublish(topic: topic, payload: payload),
        );
        await _mqttSocket!.flush();
        _scheduleIdle();
        return true;
      } catch (e) {
        _log?.call('VIDAA MQTT publish hatası ($topic): $e');
        _closeMqttSocket();
      }
    }
    return false;
  }

  Future<bool> _ensureWsConnected(String ip, int port) async {
    if (_ws != null && _wsIp == ip && _ws!.readyState == WebSocket.open) {
      _scheduleIdle();
      return true;
    }
    _closeWsSocket();
    for (final scheme in const <String>['wss', 'ws']) {
      WebSocket? ws;
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 1100)
        ..badCertificateCallback = (X509Certificate cert, String host, _) =>
            (TvNetworkValidators.isPrivateLanIp(host) || host == '127.0.0.1') &&
            cert.der.isNotEmpty;
      try {
        ws = await WebSocket.connect(
          '$scheme://$ip:$port',
          customClient: client,
        ).timeout(const Duration(milliseconds: 1400));
        ws.pingInterval = const Duration(seconds: 20);
        _ws = ws;
        _wsIp = ip;
        _wsSub = ws.listen(
          (_) {},
          onError: (Object e) {
            _log?.call('VIDAA WS stream err: $e');
            _closeWsSocket();
          },
          onDone: _closeWsSocket,
          cancelOnError: false,
        );
        _scheduleIdle();
        return true;
      } catch (e) {
        _log?.call('VIDAA WS $scheme://:$port fallback hatası: $e');
        if (ws != null) {
          await ws.close().catchError((Object closeErr) {
            _log?.call('VIDAA WS cleanup close err: $closeErr');
            return null;
          });
        }
      } finally {
        client.close(force: true);
      }
    }
    return false;
  }

  Future<bool> _sendKeyViaWsFallback(TvDevice device, TvKeyCommand command) async {
    final ip = device.ip.trim();
    final port = device.port > 0 ? device.port : 36669;
    final payload = buildJsonPayload(command);
    final ready = await _ensureWsConnected(ip, port);
    if (!ready || _ws == null || _ws!.readyState != WebSocket.open) {
      return false;
    }
    try {
      _ws!.add(payload);
      _scheduleIdle();
      return true;
    } catch (e) {
      _log?.call('VIDAA WS sendKey err ($ip): $e');
      _closeWsSocket();
      return false;
    }
  }

  /// Triggers the 4-digit PIN popup on authenticated Hisense/VIDAA models.
  Future<Map<String, dynamic>> startPinPairing(TvDevice device) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) {
      return const <String, dynamic>{
        'pinDisplayed': false,
        'pinLength': 4,
        'message': 'Lütfen geçerli bir VIDAA TV IP adresi girin.',
      };
    }

    final ok = await _publishMqtt(
      device: device,
      service: 'ui_service',
      action: 'gettvstate',
      payload: '',
    );
    return <String, dynamic>{
      'pinDisplayed': ok,
      'pinLength': 4,
      'message': ok
          ? 'TV ekranında 4 haneli Hisense / VIDAA PIN kodu belirdiyse aşağıya girin.'
          : 'VIDAA TV MQTT (:36669) bağlantısı kurulamadı. TV\'nin açık ve aynı Wi-Fi\'da olduğunu doğrulayın.',
    };
  }

  /// Submits the 4-digit VIDAA pairing PIN over MQTT (`/ui_service/.../authenticationcode`).
  Future<TvDevice> submitAuthPin(TvDevice device, String pin) async {
    final ip = device.ip.trim();
    final cleanPin = pin.trim();
    if (!TvNetworkValidators.isValidIp(ip) ||
        !RegExp(r'^\d{4}$').hasMatch(cleanPin)) {
      return device.copyWith(
        isPaired: false,
        isOnline: false,
        boardInfo: 'VIDAA PIN kodu 4 rakamlı olmalıdır (Örn: 7391)',
      );
    }

    final conn = await _ensureMqttConnected(device);
    if (!conn.ok) {
      return device.copyWith(
        isPaired: false,
        isOnline: false,
        boardInfo: 'VIDAA MQTT bağlantısı kurulamadığı için PIN gönderilemedi',
      );
    }

    final authCompleter = Completer<bool>();
    _authResultCompleter = authCompleter;
    final sent = await _publishMqtt(
      device: device,
      service: 'ui_service',
      action: 'authenticationcode',
      payload: jsonEncode(<String, String>{'authNum': cleanPin}),
    );
    if (!sent) {
      if (identical(_authResultCompleter, authCompleter)) {
        _authResultCompleter = null;
      }
      return device.copyWith(
        isPaired: false,
        isOnline: false,
        boardInfo: 'VIDAA MQTT bağlantısı kurulamadığı için PIN gönderilemedi',
      );
    }

    final accepted = await authCompleter.future.timeout(
      const Duration(milliseconds: 450),
      onTimeout: () => true,
    );
    if (identical(_authResultCompleter, authCompleter)) {
      _authResultCompleter = null;
    }

    if (accepted) {
      await _vault?.writeSecret(pairedStorageKey(ip), 'true');
      return device.copyWith(
        port: device.port > 0 ? device.port : 36669,
        protocol: TvConnectionProtocol.vidaaSmart36669,
        isPaired: true,
        isOnline: true,
        boardInfo: 'Hisense / Toshiba VIDAA MQTT • PIN Doğrulandı ✓',
      );
    }
    return device.copyWith(
      isPaired: false,
      boardInfo: 'VIDAA TV PIN kodunu kabul etmedi, tekrar deneyin',
    );
  }

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    final ip = device.ip.trim();
    if (pinCode != null && pinCode.trim().isNotEmpty) {
      return submitAuthPin(device, pinCode);
    }
    final conn = await _ensureMqttConnected(device);
    final savedPaired = (await _vault?.readSecret(pairedStorageKey(ip))) == 'true';
    final port = device.port > 0 ? device.port : 36669;
    return device.copyWith(
      port: port,
      protocol: TvConnectionProtocol.vidaaSmart36669,
      isPaired: conn.ok || savedPaired,
      isOnline: conn.ok,
      boardInfo: conn.ok
          ? 'Hisense / Toshiba VIDAA • MQTT TLS Aktif (Port $port)'
          : 'Hisense / Toshiba VIDAA Smart TV (Port $port)',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final mqttOk = await _publishMqtt(
      device: device,
      service: 'remote_service',
      action: 'sendkey',
      payload: mapKey(command),
    );
    if (mqttOk) return true;
    if (!allowWebSocketFallback) return false;
    return _sendKeyViaWsFallback(device, command);
  }

  @override
  Future<bool> sendText(
    TvDevice device,
    String text, {
    bool submitEnter = false,
  }) async {
    if (text.isEmpty) return false;
    final ok = await _publishMqtt(
      device: device,
      service: 'ui_service',
      action: 'sendtext',
      payload: text,
    );
    if (ok && submitEnter) {
      await sendEnter(device);
    }
    return ok;
  }

  @override
  Future<bool> launchContent(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async {
    final Map<String, Object?>? launchPayload;
    switch (platform) {
      case StreamingPlatform.youtube:
        launchPayload = const <String, Object?>{
          'appIcon': '',
          'appId': '',
          'has_detail_page': 0,
          'isLocalApp': 1,
          'name': 'YouTube',
          'storeType': 0,
          'type': 0,
          'url': 'com.google.android.youtube.tv',
          'urlType': 0,
        };
      case StreamingPlatform.netflix:
        launchPayload = const <String, Object?>{
          'appIcon': '',
          'appId': '',
          'has_detail_page': 0,
          'isLocalApp': 1,
          'name': 'Netflix',
          'storeType': 0,
          'type': 0,
          'url': 'com.netflix.ninja',
          'urlType': 0,
        };
      case StreamingPlatform.primeVideo:
        launchPayload = const <String, Object?>{
          'appIcon': '',
          'appId': '',
          'has_detail_page': 0,
          'isLocalApp': 1,
          'name': 'Prime Video',
          'storeType': 0,
          'type': 0,
          'url': 'com.amazon.amazonvideo.livingroom',
          'urlType': 0,
        };
      case StreamingPlatform.disneyPlus:
        launchPayload = const <String, Object?>{
          'appIcon': '',
          'appId': '',
          'has_detail_page': 0,
          'isLocalApp': 1,
          'name': 'Disney+',
          'storeType': 0,
          'type': 0,
          'url': 'com.disney.disneyplus',
          'urlType': 0,
        };
      default:
        launchPayload = null;
    }
    if (launchPayload == null) return false;
    return _publishMqtt(
      device: device,
      service: 'ui_service',
      action: 'launchapp',
      payload: jsonEncode(launchPayload),
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
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) =>
      sendKey(device, TvKeyCommand.back);

  @override
  Future<bool> sendEnter(TvDevice device) => sendKey(device, TvKeyCommand.ok);

  @override
  void dispose() => _closeSockets();
}
