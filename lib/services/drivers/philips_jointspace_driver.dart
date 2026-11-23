import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../domain/tv_driver_contract.dart';
import '../../domain/tv_network_validators.dart';
import '../../models/cue_models.dart';
import '../crypto/tv_secret_vault.dart';

/// Parsed RFC 2617 HTTP Digest authentication challenge from `WWW-Authenticate`.
class HttpDigestChallenge {
  const HttpDigestChallenge({
    required this.realm,
    required this.nonce,
    this.qop = '',
    this.opaque = '',
    this.algorithm = 'MD5',
  });

  final String realm;
  final String nonce;
  final String qop;
  final String opaque;
  final String algorithm;

  static HttpDigestChallenge? parse(String? header) {
    if (header == null || header.trim().isEmpty) return null;
    final trimmed = header.trim();
    if (!trimmed.toLowerCase().startsWith('digest ')) return null;
    final body = trimmed.substring(7);

    final params = <String, String>{};
    final reg = RegExp(r'([a-zA-Z0-9_-]+)\s*=\s*(?:"([^"]*)"|([^,\s]+))');
    for (final m in reg.allMatches(body)) {
      final key = (m.group(1) ?? '').toLowerCase();
      final val = m.group(2) ?? m.group(3) ?? '';
      if (key.isNotEmpty) {
        params[key] = val;
      }
    }
    final realm = params['realm'] ?? '';
    final nonce = params['nonce'] ?? '';
    if (realm.isEmpty || nonce.isEmpty) return null;

    return HttpDigestChallenge(
      realm: realm,
      nonce: nonce,
      qop: params['qop'] ?? '',
      opaque: params['opaque'] ?? '',
      algorithm: (params['algorithm'] ?? 'MD5').toUpperCase(),
    );
  }
}

/// Pure-Dart RFC 2617 / 7616 HTTP Digest authenticator backed by `package:crypto`.
class HttpDigestAuthHelper {
  HttpDigestAuthHelper({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  int _nonceCount = 0;

  String _hashHex(String input, String algorithm) {
    final bytes = utf8.encode(input);
    if (algorithm.startsWith('SHA-256')) {
      return sha256.convert(bytes).toString();
    }
    if (algorithm.startsWith('SHA')) {
      return sha1.convert(bytes).toString();
    }
    return md5.convert(bytes).toString();
  }

  String _nextCnonce() {
    final buf = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buf.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  /// Computes the `Authorization: Digest ...` header value for [challenge].
  String buildAuthorizationHeader({
    required HttpDigestChallenge challenge,
    required String username,
    required String password,
    required String method,
    required String uriPath,
  }) {
    _nonceCount += 1;
    final nc = _nonceCount.toRadixString(16).padLeft(8, '0');
    final cnonce = _nextCnonce();

    var ha1 = _hashHex(
      '$username:${challenge.realm}:$password',
      challenge.algorithm,
    );
    if (challenge.algorithm.endsWith('-SESS')) {
      ha1 = _hashHex(
        '$ha1:${challenge.nonce}:$cnonce',
        challenge.algorithm,
      );
    }

    final ha2 = _hashHex(
      '${method.toUpperCase()}:$uriPath',
      challenge.algorithm,
    );

    final qopTokens = challenge.qop
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    final hasAuthQop = qopTokens.contains('auth');

    final responseDigest = hasAuthQop
        ? _hashHex(
            '$ha1:${challenge.nonce}:$nc:$cnonce:auth:$ha2',
            challenge.algorithm,
          )
        : _hashHex('$ha1:${challenge.nonce}:$ha2', challenge.algorithm);

    final parts = <String>[
      'username="${_escapeQuoted(username)}"',
      'realm="${_escapeQuoted(challenge.realm)}"',
      'nonce="${_escapeQuoted(challenge.nonce)}"',
      'uri="${_escapeQuoted(uriPath)}"',
      'response="$responseDigest"',
    ];
    if (challenge.algorithm.isNotEmpty) {
      parts.add('algorithm=${challenge.algorithm}');
    }
    if (hasAuthQop) {
      parts.add('qop=auth');
      parts.add('nc=$nc');
      parts.add('cnonce="$cnonce"');
    }
    if (challenge.opaque.isNotEmpty) {
      parts.add('opaque="${_escapeQuoted(challenge.opaque)}"');
    }
    return 'Digest ${parts.join(', ')}';
  }

  static String _escapeQuoted(String v) =>
      v.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

class _PendingPhilipsPairing {
  const _PendingPhilipsPairing({
    required this.deviceMap,
    required this.timestamp,
    required this.authKey,
    required this.port,
  });

  final Map<String, String> deviceMap;
  final String timestamp;
  final String authKey;
  final int port;
}

/// Philips JointSpace REST JSON driver:
/// - JointSpace v6 (`https://<ip>:1926/6/...`) with `/6/pair/request` -> `/6/pair/grant`
///   HMAC-SHA1 + RFC 2617 Digest Authentication persisted in [TvSecretVault].
/// - Classic JointSpace v1 fallback (`http://<ip>:1925/1/input/key`).
class PhilipsJointSpaceDriver implements TvRemoteDriver {
  PhilipsJointSpaceDriver({
    this._vault,
    TvDiagLogger? logger,
    this.allowPlainHttpForV6 = false,
  }) : _log = logger;

  /// Official Philips JointSpace shared HMAC-SHA1 key used during `/6/pair/grant`.
  static final Uint8List authSharedKey = base64Decode(
    'ZmVay1EQVFOaZhwQ4Kv81ypLAZNczV9sG4KkseXWn1NEk6cXmPKO/MCa9sryslvLCFMnNe4Z4CPXzToowvhHvA==',
  );

  final TvSecretVault? _vault;
  final TvDiagLogger? _log;
  final bool allowPlainHttpForV6;
  final HttpDigestAuthHelper _digestHelper = HttpDigestAuthHelper();
  final Map<String, HttpDigestChallenge> _cachedChallenges =
      <String, HttpDigestChallenge>{};
  final Map<String, _PendingPhilipsPairing> _pendingPairings =
      <String, _PendingPhilipsPairing>{};

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.philipsJointSpace1925;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.liveKeyboard,
        TvCapability.appLaunch,
        TvCapability.pinPairing,
        TvCapability.wakeOnLan,
      };

  static String deviceIdStorageKey(String ip) => 'philips_id_${ip.trim()}';

  static String authKeyStorageKey(String ip) => 'philips_key_${ip.trim()}';

  /// Computes Base64(HMAC-SHA1(authSharedKey, "$timestamp$pin")).
  static String computeHmacSignature(String timestamp, String pin) {
    final mac = Hmac(sha1, authSharedKey);
    final digest = mac.convert(utf8.encode('$timestamp$pin'));
    return base64Encode(digest.bytes);
  }

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

  String get _v6Scheme => allowPlainHttpForV6 ? 'http' : 'https';

  int _resolveV6Port(TvDevice device) {
    if (device.port > 0 && device.port != 1925) return device.port;
    return 1926;
  }

  HttpClient _createClient({Duration timeout = const Duration(milliseconds: 900)}) {
    return HttpClient()
      ..connectionTimeout = timeout
      ..badCertificateCallback = (X509Certificate cert, String host, _) =>
          (TvNetworkValidators.isPrivateLanIp(host) || host == '127.0.0.1') &&
          cert.der.isNotEmpty;
  }

  String _generateRandomHexId(int byteLength) {
    final rng = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < byteLength; i++) {
      buf.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  Future<({int statusCode, String body, HttpDigestChallenge? challenge})>
      _postJson({
    required String ip,
    required Uri uri,
    required String jsonBody,
    String? digestUsername,
    String? digestPassword,
    Duration timeout = const Duration(milliseconds: 1400),
  }) async {
    final hasCreds = digestUsername != null &&
        digestUsername.isNotEmpty &&
        digestPassword != null &&
        digestPassword.isNotEmpty;

    Future<({int statusCode, String body, String? wwwAuth})> attempt(
      HttpDigestChallenge? challenge,
    ) async {
      final client = _createClient(timeout: timeout);
      try {
        final req = await client.postUrl(uri).timeout(timeout);
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.headers.set(HttpHeaders.connectionHeader, 'close');
        if (hasCreds && challenge != null) {
          final authHeader = _digestHelper.buildAuthorizationHeader(
            challenge: challenge,
            username: digestUsername,
            password: digestPassword,
            method: 'POST',
            uriPath: uri.path,
          );
          req.headers.set(HttpHeaders.authorizationHeader, authHeader);
        }
        final bytes = utf8.encode(jsonBody);
        req.contentLength = bytes.length;
        req.add(bytes);
        final resp = await req.close().timeout(timeout);
        final rawBody = await resp
            .transform(utf8.decoder)
            .join()
            .timeout(timeout);
        final wwwAuth = resp.headers.value(HttpHeaders.wwwAuthenticateHeader);
        return (statusCode: resp.statusCode, body: rawBody, wwwAuth: wwwAuth);
      } finally {
        client.close(force: true);
      }
    }

    var res = await attempt(hasCreds ? _cachedChallenges[ip] : null);
    HttpDigestChallenge? parsedChallenge =
        HttpDigestChallenge.parse(res.wwwAuth);

    if (res.statusCode == 401 && hasCreds && parsedChallenge != null) {
      _cachedChallenges[ip] = parsedChallenge;
      res = await attempt(parsedChallenge);
      parsedChallenge =
          HttpDigestChallenge.parse(res.wwwAuth) ?? parsedChallenge;
    }

    return (
      statusCode: res.statusCode,
      body: res.body,
      challenge: parsedChallenge,
    );
  }

  /// Initiates JointSpace v6 PIN display via `POST /6/pair/request`.
  Future<Map<String, dynamic>> startPinPairing(TvDevice device) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) {
      return const <String, dynamic>{
        'pinDisplayed': false,
        'pinLength': 4,
        'message': 'Lütfen geçerli bir Philips TV IP adresi girin.',
      };
    }

    final v6Port = _resolveV6Port(device);
    final deviceId = _generateRandomHexId(16);
    final deviceMap = <String, String>{
      'device_name': 'CueDeck',
      'device_os': 'Android',
      'type': 'native',
      'id': deviceId,
      'app_id': 'com.akarworks.cuedeck',
      'app_name': 'CueDeck',
    };

    final requestBody = jsonEncode(<String, Object?>{
      'access': <String, Object?>{
        'scope': const <String>['read', 'write', 'control'],
      },
      'device': deviceMap,
    });

    try {
      final uri = Uri.parse('$_v6Scheme://$ip:$v6Port/6/pair/request');
      final res = await _postJson(
        ip: ip,
        uri: uri,
        jsonBody: requestBody,
        timeout: const Duration(milliseconds: 2200),
      );

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return const <String, dynamic>{
          'pinDisplayed': false,
          'pinLength': 4,
          'message': 'Philips TV eşleştirme yanıtı anlaşılamadı.',
        };
      }

      if (decoded['error_id']?.toString() != 'SUCCESS') {
        return <String, dynamic>{
          'pinDisplayed': false,
          'pinLength': 4,
          'message':
              'Philips TV PIN isteği reddedildi: ${decoded['error_text'] ?? decoded['error_id'] ?? res.statusCode}',
        };
      }

      final timestamp = decoded['timestamp']?.toString() ?? '';
      final authKey = decoded['auth_key']?.toString() ?? '';
      if (timestamp.isEmpty || authKey.isEmpty) {
        return const <String, dynamic>{
          'pinDisplayed': false,
          'pinLength': 4,
          'message': 'Philips TV auth_key veya timestamp döndürmedi.',
        };
      }

      _pendingPairings[ip] = _PendingPhilipsPairing(
        deviceMap: deviceMap,
        timestamp: timestamp,
        authKey: authKey,
        port: v6Port,
      );

      return const <String, dynamic>{
        'pinDisplayed': true,
        'pinLength': 4,
        'message':
            'TV ekranında görünen 4 haneli Philips JointSpace PIN kodunu aşağıya girin.',
      };
    } catch (e) {
      _log?.call('Philips pair/request hatası ($ip:$v6Port): $e');
      return <String, dynamic>{
        'pinDisplayed': false,
        'pinLength': 4,
        'message':
            'Philips v6 (:$v6Port) PIN isteği başarısız. Eski model ise PIN olmadan v1 (1925) ile doğrudan deneyin.',
      };
    }
  }

  /// Completes JointSpace v6 pairing via HMAC-SHA1 signed `POST /6/pair/grant`
  /// with HTTP Digest Auth and stores credentials in [TvSecretVault].
  Future<TvDevice> completePinPairing(TvDevice device, String pin) async {
    final ip = device.ip.trim();
    final cleanPin = pin.trim();
    if (!TvNetworkValidators.isValidIp(ip) ||
        !RegExp(r'^\d{4}$').hasMatch(cleanPin)) {
      return device.copyWith(
        isOnline: false,
        isPaired: false,
        boardInfo: 'Philips PIN kodu 4 rakamlı olmalıdır (Örn: 4829)',
      );
    }

    var pending = _pendingPairings[ip];
    if (pending == null) {
      await startPinPairing(device);
      pending = _pendingPairings[ip];
      if (pending == null) {
        return device.copyWith(
          isOnline: false,
          isPaired: false,
          boardInfo: 'Philips PIN oturumu başlatılamadı',
        );
      }
    }

    final signature = computeHmacSignature(pending.timestamp, cleanPin);
    final payload = jsonEncode(<String, Object?>{
      'auth': <String, String>{
        'auth_appId': '1',
        'auth_timestamp': pending.timestamp,
        'auth_signature': signature,
        'pin': cleanPin,
      },
      'device': pending.deviceMap,
    });

    try {
      final uri = Uri.parse('$_v6Scheme://$ip:${pending.port}/6/pair/grant');
      final res = await _postJson(
        ip: ip,
        uri: uri,
        jsonBody: payload,
        digestUsername: pending.deviceMap['id'],
        digestPassword: pending.authKey,
        timeout: const Duration(milliseconds: 2200),
      );
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          decoded is Map<String, dynamic> &&
          decoded['error_id']?.toString() == 'SUCCESS') {
        final devId = pending.deviceMap['id'] ?? '';
        await _vault?.writeSecret(deviceIdStorageKey(ip), devId);
        await _vault?.writeSecret(authKeyStorageKey(ip), pending.authKey);
        final matchedPort = pending.port;
        _pendingPairings.remove(ip);
        return device.copyWith(
          port: matchedPort,
          protocol: TvConnectionProtocol.philipsJointSpace1925,
          isPaired: true,
          isOnline: true,
          boardInfo: 'Philips JointSpace v6 • PIN Eşleşti ✓',
        );
      }
      return device.copyWith(
        isPaired: false,
        boardInfo:
            'Philips PIN doğrulanamadı (HTTP ${res.statusCode}): hatalı kod olabilir',
      );
    } catch (e) {
      _log?.call('Philips pair/grant hatası ($ip): $e');
      return device.copyWith(
        isPaired: false,
        boardInfo: 'Philips eşleştirme hatası: $e',
      );
    }
  }

  Future<({String? username, String? password})> _readStoredCreds(
    String ip,
  ) async {
    final vault = _vault;
    if (vault == null) return (username: null, password: null);
    final u = await vault.readSecret(deviceIdStorageKey(ip));
    final p = await vault.readSecret(authKeyStorageKey(ip));
    if (u != null && u.isNotEmpty && p != null && p.isNotEmpty) {
      return (username: u, password: p);
    }
    return (username: null, password: null);
  }

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return device;
    if (pinCode != null && pinCode.trim().isNotEmpty) {
      return completePinPairing(device, pinCode);
    }

    final creds = await _readStoredCreds(ip);
    final v6Ok = await _sendPostWithFallback(
      device,
      path: '/6/input/key',
      jsonBody: jsonEncode(<String, String>{'key': 'Home'}),
      creds: creds,
      tryV1Fallback: false,
    );
    if (v6Ok) {
      return device.copyWith(
        port: _resolveV6Port(device),
        protocol: TvConnectionProtocol.philipsJointSpace1925,
        isPaired: true,
        isOnline: true,
        boardInfo: creds.username != null
            ? 'Philips JointSpace v6 • Digest Eşleşti ✓'
            : 'Philips JointSpace Smart TV • v6 Aktif',
      );
    }

    final v1Ok = await _sendRawHttpJson(
      Uri.parse('http://$ip:1925/1/input/key'),
      jsonEncode(<String, String>{'key': 'Home'}),
    );
    return device.copyWith(
      port: v1Ok ? 1925 : _resolveV6Port(device),
      protocol: TvConnectionProtocol.philipsJointSpace1925,
      isPaired: v1Ok,
      isOnline: v1Ok,
      boardInfo: v1Ok
          ? 'Philips JointSpace v1 • REST API Hazır (Port 1925)'
          : 'Philips JointSpace v6 • 4 Haneli PIN Eşleştirmesi Gerekli',
    );
  }

  Future<bool> _sendRawHttpJson(Uri uri, String jsonBody) async {
    final client = _createClient(timeout: const Duration(milliseconds: 580));
    try {
      final req = await client.postUrl(uri).timeout(
            const Duration(milliseconds: 580),
          );
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(HttpHeaders.connectionHeader, 'close');
      final bytes = utf8.encode(jsonBody);
      req.contentLength = bytes.length;
      req.add(bytes);
      final resp = await req.close().timeout(const Duration(milliseconds: 580));
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (e) {
      _log?.call('Philips HTTP hatası ($uri): $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _sendPostWithFallback(
    TvDevice device, {
    required String path,
    required String jsonBody,
    required ({String? username, String? password}) creds,
    bool tryV1Fallback = true,
  }) async {
    final ip = device.ip.trim();
    final v6Port = _resolveV6Port(device);

    try {
      final res = await _postJson(
        ip: ip,
        uri: Uri.parse('$_v6Scheme://$ip:$v6Port$path'),
        jsonBody: jsonBody,
        digestUsername: creds.username,
        digestPassword: creds.password,
        timeout: const Duration(milliseconds: 680),
      );
      if (res.statusCode >= 200 && res.statusCode < 400) return true;
    } catch (e) {
      _log?.call('Philips v6 ($ip:$v6Port$path) hatası: $e');
    }

    if (!tryV1Fallback) return false;

    final v1Path = path.startsWith('/6/') ? '/1/${path.substring(3)}' : path;
    final legacyEndpoints = <String>[
      'http://$ip:1925$v1Path',
      'http://$ip:1925$path',
    ];
    for (final endpoint in legacyEndpoints) {
      if (await _sendRawHttpJson(Uri.parse(endpoint), jsonBody)) {
        return true;
      }
    }
    return false;
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

    final creds = await _readStoredCreds(ip);
    final body = jsonEncode(<String, String>{'key': mapKey(command)});
    final ok = await _sendPostWithFallback(
      device,
      path: '/6/input/key',
      jsonBody: body,
      creds: creds,
      tryV1Fallback: true,
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
    final ip = device.ip.trim();
    if (text.isEmpty || !TvNetworkValidators.isValidIp(ip)) return false;
    final creds = await _readStoredCreds(ip);
    var anyOk = false;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final ok = await _sendPostWithFallback(
        device,
        path: '/6/input/key',
        jsonBody: jsonEncode(<String, String>{'unicode': ch}),
        creds: creds,
        tryV1Fallback: true,
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
  Future<bool> launchContent(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async {
    final ip = device.ip.trim();
    if (!TvNetworkValidators.isValidIp(ip)) return false;
    final creds = await _readStoredCreds(ip);
    final jsonBody = jsonEncode(<String, Object?>{
      'intent': <String, Object?>{
        'component': <String, String>{'packageName': platform.packageName},
        'action': 'Intent.ACTION_MAIN',
      },
    });
    return _sendPostWithFallback(
      device,
      path: '/6/activities/launch',
      jsonBody: jsonBody,
      creds: creds,
      tryV1Fallback: false,
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
  void dispose() {
    _pendingPairings.clear();
    _cachedChallenges.clear();
  }
}
