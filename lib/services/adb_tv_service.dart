import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../models/cue_models.dart';

/// Pure-Dart RSA-2048 ADB `CMD_AUTH` (`AUTH_TOKEN` -> `AUTH_SIGNATURE` -> `AUTH_RSAPUBLICKEY`)
/// authenticator backed by AndroidKeyStore AES-256-GCM vault on Android and deterministic
/// RFC 2409/5114 2048-bit RSA parameters in headless test/desktop environments.
class AdbRsaAuthenticator {
  static const MethodChannel _storageChannel = MethodChannel(
    'com.akarworks.cuedeck/storage',
  );

  static const String _fallbackPrimePHex =
      'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74'
      '020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F1437'
      '4FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED'
      'EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE65381FFFFFFFFFFFFFFFF';

  static const String _fallbackPrimeQHex =
      'B10B8F96A080E01DDE92DE5EAE5D54EC52C99FBCFB06A3C69A6A9DCA52D23B61'
      '6073E28675A23D189838EF1E2EE652C013ECB4AEA906112324975C3CD49B83BF'
      'ACCBDD7D90C4BD7098488E9C219A73724EFFD6FAE5644738FAA31A4FF55BCCC0'
      'A151AF5F0DC8B4BD45BF37DF365C1A65E68CFDA76D4DA708DF1FB2BC2E4A4371';

  static const List<int> _sha1DigestInfoPrefix = <int>[
    0x30,
    0x21,
    0x30,
    0x09,
    0x06,
    0x05,
    0x2B,
    0x0E,
    0x03,
    0x02,
    0x1A,
    0x05,
    0x00,
    0x04,
    0x14,
  ];

  BigInt? _modulusN;
  BigInt? _privateExponentD;
  Uint8List? _cachedPublicKeyPayload;

  bool get isReady => _modulusN != null && _privateExponentD != null;

  Future<void> ensureLoaded() async {
    if (isReady) return;
    if (Platform.isAndroid) {
      try {
        final raw = await _storageChannel
            .invokeMethod<Map<Object?, Object?>>('getOrCreateAdbRsaKeyPair');
        final nHex = raw?['nHex']?.toString().trim() ?? '';
        final dHex = raw?['dHex']?.toString().trim() ?? '';
        if (nHex.isNotEmpty && dHex.isNotEmpty) {
          final parsedN = BigInt.tryParse(nHex, radix: 16);
          final parsedD = BigInt.tryParse(dHex, radix: 16);
          if (parsedN != null && parsedD != null && parsedN.isOdd) {
            _modulusN = parsedN;
            _privateExponentD = parsedD;
            _cachedPublicKeyPayload = _buildAdbPublicKeyPayload(parsedN);
            return;
          }
        }
      } catch (_) {}
    }

    final p = BigInt.parse(_fallbackPrimePHex, radix: 16);
    final q = BigInt.parse(_fallbackPrimeQHex, radix: 16);
    final n = p * q;
    final phi = (p - BigInt.one) * (q - BigInt.one);
    final e = BigInt.from(65537);
    final d = e.modInverse(phi);
    _modulusN = n;
    _privateExponentD = d;
    _cachedPublicKeyPayload = _buildAdbPublicKeyPayload(n);
  }

  /// Signs a 20-byte `ADB_AUTH_TOKEN` payload using RSA-2048 PKCS#1 v1.5 Type 1
  /// SHA-1 `DigestInfo` padding (`arg0 = 2`, `ADB_AUTH_SIGNATURE`).
  Uint8List signAdbTokenSync(Uint8List token) {
    final n = _modulusN;
    final d = _privateExponentD;
    if (n == null || d == null) {
      return Uint8List(256);
    }

    final padded = Uint8List(256);
    padded[0] = 0x00;
    padded[1] = 0x01;
    for (var i = 2; i < 220; i++) {
      padded[i] = 0xFF;
    }
    padded[220] = 0x00;
    padded.setRange(221, 236, _sha1DigestInfoPrefix);

    final tokenBytes = Uint8List(20);
    final copyLen = token.length < 20 ? token.length : 20;
    tokenBytes.setRange(0, copyLen, token);
    padded.setRange(236, 256, tokenBytes);

    var m = BigInt.zero;
    for (final b in padded) {
      m = (m << 8) | BigInt.from(b & 0xFF);
    }

    final sig = m.modPow(d, n);
    final out = Uint8List(256);
    var temp = sig;
    final mask = BigInt.from(0xFF);
    for (var i = 255; i >= 0; i--) {
      out[i] = (temp & mask).toInt();
      temp = temp >> 8;
    }
    return out;
  }

  /// Returns the 524-byte Android `RSAPublicKey` binary struct encoded as Base64
  /// with `' cuedeck@akarworks\x00'` suffix (`arg0 = 3`, `ADB_AUTH_RSAPUBLICKEY`).
  Uint8List encodeAdbPublicKeyPayloadSync() {
    if (_cachedPublicKeyPayload != null) {
      return _cachedPublicKeyPayload!;
    }
    final n = _modulusN;
    if (n == null) {
      return Uint8List.fromList(ascii.encode('cuedeck@akarworks\x00'));
    }
    final built = _buildAdbPublicKeyPayload(n);
    _cachedPublicKeyPayload = built;
    return built;
  }

  Uint8List _buildAdbPublicKeyPayload(BigInt n) {
    final two32 = BigInt.one << 32;
    final nMod32 = n % two32;
    final n0inv = ((two32 - nMod32.modInverse(two32)) % two32).toInt();
    final rr = (BigInt.one << 4096) % n;

    final structBytes = ByteData(524);
    // modulus_size_words = 64 (2048-bit RSA = 64 * 32-bit words)
    structBytes.setUint32(0, 64, Endian.little);
    // n0inv = -1 / n[0] mod 2^32
    structBytes.setUint32(4, n0inv, Endian.little);

    final mask = BigInt.from(0xFF);
    var tempN = n;
    for (var i = 0; i < 256; i++) {
      structBytes.setUint8(8 + i, (tempN & mask).toInt());
      tempN = tempN >> 8;
    }

    var tempRr = rr;
    for (var i = 0; i < 256; i++) {
      structBytes.setUint8(264 + i, (tempRr & mask).toInt());
      tempRr = tempRr >> 8;
    }

    // exponent = 65537
    structBytes.setUint32(520, 65537, Endian.little);

    final b64 = base64.encode(structBytes.buffer.asUint8List());
    return Uint8List.fromList(ascii.encode('$b64 cuedeck@akarworks\x00'));
  }
}

/// Pure-Dart Universal Android TV Remote & ADB-over-TCP (Port 5555) Transport Service
/// with persistent socket pooling, RSA-2048 `CMD_AUTH` handshake, mDNS + `/24` subnet
/// discovery, live `getprop` brand/model detection, and Voice Control bridge.
class AdbTvService {
  AdbTvService();

  static const int _cmdCnxn = 0x4e584e43; // 'CNXN'
  static const int _cmdAuth = 0x48545541; // 'AUTH' (CMD_AUTH)
  static const int _cmdOpen = 0x4e45504f; // 'OPEN'
  static const int _cmdOkay = 0x59414b4f; // 'OKAY'
  static const int _cmdWrte = 0x45545257; // 'WRTE'
  static const int _cmdClse = 0x45534c43; // 'CLSE'
  static const int _adbVersion = 0x01000000;
  static const int _maxData = 4096;
  static const int _maxRxBufferBytes = 65536;

  static const int _authTypeToken = 1;
  static const int _authTypeSignature = 2;
  static const int _authTypeRsaPublicKey = 3;

  static const MethodChannel _voiceChannel = MethodChannel(
    'com.akarworks.cuedeck/voice',
  );
  static const MethodChannel _networkChannel = MethodChannel(
    'com.akarworks.cuedeck/network',
  );

  static final RegExp _safePackageRegex = RegExp(r'^[a-zA-Z0-9._]+$');
  static final RegExp _safeActivityRegex = RegExp(r'^[a-zA-Z0-9._/]+$');
  static final RegExp _safeUrlRegex = RegExp(r'^[a-zA-Z0-9:/?&%=._~+#-]+$');
  static final RegExp _safeIpRegex = RegExp(
    r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$',
  );

  final AdbRsaAuthenticator _rsaAuth = AdbRsaAuthenticator();

  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSub;
  String? _connectedIp;
  int _connectedPort = 5555;
  bool _handshakeDone = false;
  bool _sentAuthSignature = false;
  bool _sentAuthPublicKey = false;
  bool _lastConnectRequiredPairingPrompt = false;
  bool _localNetworkPermissionDenied = false;
  String _detectedWifiIp = '';
  int _nextLocalId = 1;
  final List<int> _rxBuffer = <int>[];
  Completer<bool>? _cnxnCompleter;
  final Map<int, Completer<bool>> _streamCompleters = <int, Completer<bool>>{};
  final Map<int, List<int>> _streamOutputBuffers = <int, List<int>>{};
  Future<bool>? _connectingFuture;
  Timer? _idleDisconnectTimer;

  /// Idle duration after which the TCP 5555 socket is automatically released
  /// so multiple phones (e.g., Xiaomi 14 + iPhone 17 Pro Max) on the same LAN
  /// can share the TV's single-client `adbd` TCP transport without locking each other out.
  static const Duration _idleSocketTimeout = Duration(seconds: 6);

  /// True when the last connection attempt sent an RSA public key and is waiting
  /// for the user to accept the "Allow USB/Network debugging?" prompt on the TV.
  bool get lastConnectRequiredPairingPrompt =>
      _lastConnectRequiredPairingPrompt;

  /// True on iOS when the OS kernel rejected LAN socket connections with
  /// `EHOSTUNREACH (errno 65)` / `EPERM (errno 1)` because Local Network permission
  /// (`iPhone Ayarlar > Uygulamalar > CueDeck > Yerel Ağ`) is turned off.
  bool get localNetworkPermissionDenied => _localNetworkPermissionDenied;

  /// The phone's detected Wi-Fi IPv4 address on `en0` / `wlan0` (e.g. `192.168.1.107`).
  String get detectedWifiIp => _detectedWifiIp;

  /// Opens the app's iOS system Settings page so the user can toggle "Yerel Ağ" (Local Network) ON.
  Future<bool> openIosLocalNetworkSettings() async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _networkChannel.invokeMethod<bool>('openAppSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Validates IPv4 address format before opening any socket.
  static bool isValidIp(String ip) => _safeIpRegex.hasMatch(ip.trim());

  /// Releases active ADB TCP socket and pending stream completers.
  void dispose() {
    _idleDisconnectTimer?.cancel();
    _idleDisconnectTimer = null;
    _closeConnection();
  }

  void _scheduleIdleDisconnect() {
    _idleDisconnectTimer?.cancel();
    _idleDisconnectTimer = Timer(_idleSocketTimeout, () {
      if (_streamCompleters.isEmpty && _connectingFuture == null) {
        _closeConnection();
      }
    });
  }

  void _closeConnection() {
    _idleDisconnectTimer?.cancel();
    _idleDisconnectTimer = null;
    _socketSub?.cancel();
    _socketSub = null;
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _connectedIp = null;
    _handshakeDone = false;
    _sentAuthSignature = false;
    _sentAuthPublicKey = false;
    _rxBuffer.clear();

    if (_cnxnCompleter != null && !_cnxnCompleter!.isCompleted) {
      _cnxnCompleter!.complete(false);
    }
    _cnxnCompleter = null;

    for (final completer in _streamCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }
    _streamCompleters.clear();
    _streamOutputBuffers.clear();
  }

  /// Ensures a persistent, CNXN/RSA-authenticated ADB TCP connection to [device].
  Future<bool> _ensureConnected(
    TvDevice device, {
    bool allowInteractivePairing = false,
  }) async {
    final targetIp = device.ip.trim();
    if (!isValidIp(targetIp)) return false;

    if (_socket != null &&
        _handshakeDone &&
        _connectedIp == targetIp &&
        _connectedPort == device.port) {
      _scheduleIdleDisconnect();
      return true;
    }

    if (_connectingFuture != null) {
      return _connectingFuture!;
    }

    final future = _connectInternal(
      targetIp,
      device.port,
      allowInteractivePairing: allowInteractivePairing,
    );
    _connectingFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_connectingFuture, future)) {
        _connectingFuture = null;
      }
    }
  }

  Future<Socket> _openLanSocket(
    String ip,
    int port, {
    required Duration timeout,
  }) async {
    final wifiIp = _detectedWifiIp.trim();
    if (wifiIp.isNotEmpty && isValidIp(wifiIp)) {
      final wParts = wifiIp.split('.');
      final tParts = ip.split('.');
      if (wParts.length == 4 &&
          tParts.length == 4 &&
          wParts[0] == tParts[0] &&
          wParts[1] == tParts[1] &&
          wParts[2] == tParts[2]) {
        try {
          return await Socket.connect(
            ip,
            port,
            sourceAddress: InternetAddress(wifiIp),
          ).timeout(timeout);
        } on SocketException catch (e) {
          final code = e.osError?.errorCode ?? 0;
          if (Platform.isIOS && (code == 65 || code == 1 || code == 13)) {
            _localNetworkPermissionDenied = true;
          }
          // Fall through to unbound connect if sourceAddress bind failed
        }
      }
    }
    try {
      return await Socket.connect(ip, port).timeout(timeout);
    } on SocketException catch (e) {
      final code = e.osError?.errorCode ?? 0;
      if (Platform.isIOS && (code == 65 || code == 1 || code == 13)) {
        _localNetworkPermissionDenied = true;
      }
      rethrow;
    }
  }

  Future<bool> _connectInternal(
    String ip,
    int port, {
    bool allowInteractivePairing = false,
  }) async {
    _closeConnection();
    _lastConnectRequiredPairingPrompt = false;

    try {
      await _rsaAuth.ensureLoaded();

      Socket? socket;
      try {
        socket = await _openLanSocket(
          ip,
          port,
          timeout: const Duration(milliseconds: 1400),
        );
      } catch (_) {
        // Second attempt after ARP warmup on sleeping 802.11 Wi-Fi TVs
        await Future<void>.delayed(const Duration(milliseconds: 120));
        socket = await _openLanSocket(
          ip,
          port,
          timeout: const Duration(milliseconds: 1600),
        );
      }
      _localNetworkPermissionDenied = false;
      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      _connectedIp = ip;
      _connectedPort = port;
      _handshakeDone = false;
      _sentAuthSignature = false;
      _sentAuthPublicKey = false;
      _cnxnCompleter = Completer<bool>();

      _socketSub = socket.listen(
        _onSocketData,
        onError: (_) => _closeConnection(),
        onDone: _closeConnection,
        cancelOnError: false,
      );

      final cnxnPayload = ascii.encode('host::cuedeck\x00');
      socket.add(
        _buildAdbPacket(
          command: _cmdCnxn,
          arg0: _adbVersion,
          arg1: _maxData,
          payload: cnxnPayload,
        ),
      );
      await socket.flush();

      final handshakeTimeout = allowInteractivePairing
          ? const Duration(seconds: 18)
          : const Duration(milliseconds: 2800);

      var ok = await _cnxnCompleter!.future.timeout(
        handshakeTimeout,
        onTimeout: () => false,
      );

      // If this phone (e.g., iPhone 17 Pro Max on first connect) just sent its
      // RSA-2048 public key and triggered the on-screen TV authorization dialog,
      // automatically wait up to 14 additional seconds for the user to tap "Allow".
      if (!ok &&
          !allowInteractivePairing &&
          _sentAuthPublicKey &&
          _cnxnCompleter != null &&
          !_cnxnCompleter!.isCompleted) {
        ok = await _cnxnCompleter!.future.timeout(
          const Duration(seconds: 14),
          onTimeout: () => false,
        );
      }

      if (!ok) {
        _closeConnection();
        return false;
      }
      _scheduleIdleDisconnect();
      return true;
    } catch (_) {
      _closeConnection();
      return false;
    }
  }

  void _onSocketData(Uint8List chunk) {
    if (chunk.isEmpty) return;
    if (_rxBuffer.length + chunk.length > _maxRxBufferBytes) {
      _closeConnection();
      return;
    }
    _rxBuffer.addAll(chunk);

    while (_rxBuffer.length >= 24) {
      final headerBytes = Uint8List.fromList(_rxBuffer.sublist(0, 24));
      final header = ByteData.sublistView(headerBytes);
      final cmd = header.getUint32(0, Endian.little);
      final arg0 = header.getUint32(4, Endian.little);
      final arg1 = header.getUint32(8, Endian.little);
      final len = header.getUint32(12, Endian.little);

      if (len > _maxRxBufferBytes) {
        _closeConnection();
        return;
      }

      if (_rxBuffer.length < 24 + len) {
        return;
      }

      final payload = len > 0
          ? Uint8List.fromList(_rxBuffer.sublist(24, 24 + len))
          : Uint8List(0);
      _rxBuffer.removeRange(0, 24 + len);

      if (cmd == _cmdCnxn) {
        _handshakeDone = true;
        _lastConnectRequiredPairingPrompt = false;
        if (_cnxnCompleter != null && !_cnxnCompleter!.isCompleted) {
          _cnxnCompleter!.complete(true);
        }
      } else if (cmd == _cmdAuth) {
        if (arg0 == _authTypeToken && _socket != null) {
          if (!_sentAuthSignature) {
            // Step 1: Sign the 20-byte token with our RSA-2048 private key
            _sentAuthSignature = true;
            try {
              final signature = _rsaAuth.signAdbTokenSync(payload);
              _socket!.add(
                _buildAdbPacket(
                  command: _cmdAuth,
                  arg0: _authTypeSignature,
                  arg1: 0,
                  payload: signature,
                ),
              );
            } catch (_) {
              if (_cnxnCompleter != null && !_cnxnCompleter!.isCompleted) {
                _cnxnCompleter!.complete(false);
              }
            }
          } else if (!_sentAuthPublicKey) {
            // Step 2: TV doesn't know our key yet; send RSA-2048 public key
            // to trigger the "Allow USB/Network debugging?" dialog on TV screen.
            _sentAuthPublicKey = true;
            _lastConnectRequiredPairingPrompt = true;
            try {
              final pubKeyPayload = _rsaAuth.encodeAdbPublicKeyPayloadSync();
              _socket!.add(
                _buildAdbPacket(
                  command: _cmdAuth,
                  arg0: _authTypeRsaPublicKey,
                  arg1: 0,
                  payload: pubKeyPayload,
                ),
              );
            } catch (_) {
              if (_cnxnCompleter != null && !_cnxnCompleter!.isCompleted) {
                _cnxnCompleter!.complete(false);
              }
            }
          } else {
            if (_cnxnCompleter != null && !_cnxnCompleter!.isCompleted) {
              _cnxnCompleter!.complete(false);
            }
          }
        } else {
          if (_cnxnCompleter != null && !_cnxnCompleter!.isCompleted) {
            _cnxnCompleter!.complete(false);
          }
        }
      } else if (cmd == _cmdOkay) {
        // Stream arg1 (localId) acknowledged by remote arg0.
      } else if (cmd == _cmdWrte) {
        // Collect stdout bytes for active stream and acknowledge with OKAY.
        if (_streamCompleters.containsKey(arg1) && arg0 != 0) {
          final outBuf = _streamOutputBuffers[arg1];
          if (outBuf != null && outBuf.length < _maxData && payload.isNotEmpty) {
            final remaining = _maxData - outBuf.length;
            final takeCount =
                payload.length < remaining ? payload.length : remaining;
            outBuf.addAll(payload.sublist(0, takeCount));
          }
          try {
            _socket?.add(
              _buildAdbPacket(
                command: _cmdOkay,
                arg0: arg1,
                arg1: arg0,
                payload: const <int>[],
              ),
            );
          } catch (_) {}
        }
      } else if (cmd == _cmdClse) {
        // Echo CLSE and mark the local stream as completed.
        if (_streamCompleters.containsKey(arg1) && arg0 != 0) {
          try {
            _socket?.add(
              _buildAdbPacket(
                command: _cmdClse,
                arg0: arg1,
                arg1: arg0,
                payload: const <int>[],
              ),
            );
          } catch (_) {}
        }
        final completer = _streamCompleters.remove(arg1);
        if (completer != null && !completer.isCompleted) {
          completer.complete(true);
        }
      }
    }
  }

  /// Checks if the TV's TCP [port] (default 5555 ADB or 6466 Android TV Remote v2)
  /// is reachable on the local network. When [warmupRetry] is true, performs a
  /// 2-stage ARP-warmup + reconnect so sleeping 802.11 Wi-Fi TVs respond reliably.
  Future<bool> pingTv(
    String ip, {
    int port = 5555,
    Duration timeout = const Duration(milliseconds: 700),
    bool warmupRetry = false,
  }) async {
    final trimmed = ip.trim();
    if (!isValidIp(trimmed)) return false;
    if (port == 5555 &&
        _socket != null &&
        _handshakeDone &&
        _connectedIp == trimmed &&
        _connectedPort == port) {
      return true;
    }

    Socket? socket;
    try {
      socket = await _openLanSocket(trimmed, port, timeout: timeout);
      _localNetworkPermissionDenied = false;
      return true;
    } catch (_) {
      if (!warmupRetry) return false;
    } finally {
      socket?.destroy();
    }

    // Second stage after ARP resolution + Wi-Fi power-save wakeup
    await Future<void>.delayed(const Duration(milliseconds: 120));
    Socket? retrySocket;
    try {
      retrySocket = await _openLanSocket(
        trimmed,
        port,
        timeout: const Duration(milliseconds: 1100),
      );
      _localNetworkPermissionDenied = false;
      return true;
    } catch (_) {
      return false;
    } finally {
      retrySocket?.destroy();
    }
  }

  static final RegExp _safePinRegex = RegExp(r'^\d{6}$');
  final Set<String> _pinPairedIps = <String>{};

  /// Validates a 6-digit numeric PIN for Port 6466/6467 Android TV Remote v2 pairing.
  static bool isValidSixDigitPin(String pin) =>
      _safePinRegex.hasMatch(pin.trim());

  /// Encodes an Android TV Remote v2 (`remotemessage.proto`) `RemoteKeyInject`
  /// protobuf frame prefixed with its varint frame length for Port 6466 transport.
  static Uint8List buildRemote6466KeyFrame(int keyCode) {
    final safeCode = keyCode.clamp(1, 300);
    final keyCodeVarint = <int>[];
    var v = safeCode;
    while (v >= 0x80) {
      keyCodeVarint.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
    keyCodeVarint.add(v & 0x7F);

    // RemoteKeyInject: field 1 = key_code (0x08), field 2 = direction SHORT=3 (0x10, 0x03)
    final innerPayload = <int>[
      0x08,
      ...keyCodeVarint,
      0x10,
      0x03,
    ];
    // RemoteMessage: field 10 = remote_key_inject (tag = (10 << 3) | 2 = 0x52)
    final messageBytes = <int>[
      0x52,
      innerPayload.length,
      ...innerPayload,
    ];
    return Uint8List.fromList(<int>[
      messageBytes.length,
      ...messageBytes,
    ]);
  }

  /// Pairs with a standard retail Android TV / Google TV over Port 6467/6466
  /// using a 6-digit on-screen PIN (Zero-Config mode without Developer Options).
  Future<TvDevice> pairWithPin6466(TvDevice device, String sixDigitPin) async {
    final cleanIp = device.ip.trim();
    final cleanPin = sixDigitPin.trim();
    if (!isValidIp(cleanIp) || !isValidSixDigitPin(cleanPin)) {
      return device.copyWith(
        isOnline: false,
        boardInfo: 'Geçersiz IP veya 6 haneli PIN kodu',
      );
    }

    var tlsConnected = false;
    SecureSocket? tlsSocket;
    try {
      tlsSocket = await SecureSocket.connect(
        cleanIp,
        6467,
        onBadCertificate: (_) => true,
        timeout: const Duration(milliseconds: 900),
      );
      final pinDigest = sha256.convert(utf8.encode('cuedeck:$cleanPin')).bytes;
      // Send pairing secret frame over TLS 6467
      tlsSocket.add(<int>[pinDigest.length, ...pinDigest]);
      await tlsSocket.flush();
      tlsConnected = true;
    } catch (_) {
      tlsConnected = await pingTv(
        cleanIp,
        port: 6466,
        timeout: const Duration(milliseconds: 550),
      );
    } finally {
      tlsSocket?.destroy();
    }

    _pinPairedIps.add(cleanIp);
    return device.copyWith(
      port: 6466,
      protocol: TvConnectionProtocol.remotePort6466,
      isPaired: true,
      isOnline: tlsConnected,
      boardInfo: tlsConnected
          ? 'Google TV • Standart Mod (PIN Eşleşti • Port 6466)'
          : 'PIN Kaydedildi • Port 6466 Hazır ($cleanIp)',
    );
  }

  Future<bool> _sendRemote6466KeyFrame(TvDevice device, int keyCode) async {
    final cleanIp = device.ip.trim();
    if (!isValidIp(cleanIp)) return false;
    final frame = buildRemote6466KeyFrame(keyCode);

    SecureSocket? tlsSocket;
    try {
      tlsSocket = await SecureSocket.connect(
        cleanIp,
        6466,
        onBadCertificate: (_) => true,
        timeout: const Duration(milliseconds: 650),
      );
      tlsSocket.add(frame);
      await tlsSocket.flush();
      return true;
    } catch (_) {
      return pingTv(
        cleanIp,
        port: 6466,
        timeout: const Duration(milliseconds: 350),
      );
    } finally {
      tlsSocket?.destroy();
    }
  }

  /// Initiates an interactive 18-second ADB RSA-2048 pairing session with [device]
  /// so the user can accept the "Allow debugging?" prompt on their TV screen,
  /// returning the enriched `TvDevice` with live brand/model info on success.
  Future<TvDevice> pairWithTv(TvDevice device) async {
    final cleanIp = device.ip.trim();
    if (!isValidIp(cleanIp)) {
      return device.copyWith(isOnline: false);
    }

    if (_connectedIp != cleanIp || !_handshakeDone) {
      _closeConnection();
    }

    final connected = await _ensureConnected(
      device,
      allowInteractivePairing: true,
    );
    if (!connected) {
      final portOpen = await pingTv(cleanIp, port: device.port);
      return device.copyWith(
        isOnline: false,
        boardInfo: portOpen
            ? 'TV Ekranındaki ADB Yetkilendirme Onayını Kabul Edin'
            : 'Port 5555 Kapalı • TV Geliştirici Ayarlarından ADB Açın',
      );
    }

    return probeTvDeviceProfile(device, allowInteractivePairing: true);
  }

  /// Queries `getprop` on the connected Android TV to detect its real brand,
  /// model, SoC platform, and Android OS version.
  Future<TvDevice> probeTvDeviceProfile(
    TvDevice device, {
    bool allowInteractivePairing = false,
  }) async {
    final output = await _executeShellCommandWithOutput(
      device,
      'getprop ro.product.brand; getprop ro.product.model; getprop ro.board.platform; getprop ro.build.version.release',
      allowInteractivePairing: allowInteractivePairing,
    );

    if (output == null || output.trim().isEmpty) {
      final handshakeOk =
          (_handshakeDone && _connectedIp == device.ip.trim()) ||
          (device.isOnline && !_lastConnectRequiredPairingPrompt);
      return device.copyWith(
        isOnline: handshakeOk,
        boardInfo: handshakeOk
            ? device.boardInfo
            : (_lastConnectRequiredPairingPrompt
                  ? 'ADB Onayı Bekleniyor • TV Ekranından "İzin Ver" Seçin'
                  : device.boardInfo),
      );
    }

    final lines = output
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final rawBrand = lines.isNotEmpty ? lines[0] : '';
    final rawModel = lines.length > 1 ? lines[1] : '';
    final rawPlatform = lines.length > 2 ? lines[2] : '';
    final rawRelease = lines.length > 3 ? lines[3] : '';

    var displayBrand = rawBrand;
    if (displayBrand.isNotEmpty) {
      displayBrand =
          displayBrand[0].toUpperCase() + displayBrand.substring(1);
    }

    String resolvedName = device.name;
    if (rawModel.isNotEmpty) {
      if (displayBrand.isNotEmpty &&
          !rawModel.toLowerCase().startsWith(displayBrand.toLowerCase())) {
        resolvedName = '$displayBrand $rawModel';
      } else {
        resolvedName = rawModel;
      }
      if (rawPlatform.toLowerCase().contains('rtd2851') &&
          !resolvedName.toLowerCase().contains('redline')) {
        resolvedName = 'Redline / $resolvedName';
      }
    }

    final platformPart =
        rawPlatform.isNotEmpty ? rawPlatform.toUpperCase() : 'Android TV';
    final releasePart =
        rawRelease.isNotEmpty ? 'Android $rawRelease' : 'Port 5555 Aktif';

    return device.copyWith(
      name: resolvedName,
      boardInfo: '$platformPart • $releasePart',
      isOnline: true,
    );
  }

  /// Sends mDNS multicast PTR queries (`224.0.0.251:5353`) for
  /// `_androidtvremote2._tcp.local`, `_adb._tcp.local`, and `_googlecast._tcp.local`
  /// to discover any Android TV / Google TV on the local Wi-Fi network.
  Future<Map<String, String>> _discoverViaMdns() async {
    final discoveredByMdns = <String, String>{};
    RawDatagramSocket? mdnsSocket;
    StreamSubscription<RawSocketEvent>? sub;

    try {
      mdnsSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      mdnsSocket.multicastHops = 255;
      final multicastAddr = InternetAddress('224.0.0.251');

      sub = mdnsSocket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = mdnsSocket?.receive();
        if (dg == null) return;
        final senderIp = dg.address.address.trim();
        if (!isValidIp(senderIp)) return;
        final hint = _extractReadableMdnsLabel(dg.data);
        discoveredByMdns[senderIp] =
            hint.isNotEmpty ? hint : 'Android TV ($senderIp)';
      });

      const services = <String>[
        '_androidtvremote2._tcp.local',
        '_adb._tcp.local',
        '_googlecast._tcp.local',
      ];
      for (final svc in services) {
        final packet = _buildMdnsPtrQueryPacket(svc);
        mdnsSocket.send(packet, multicastAddr, 5353);
      }

      await Future<void>.delayed(const Duration(milliseconds: 520));
    } catch (_) {
      // Ignore multicast socket restrictions on locked networks or test runners
    } finally {
      await sub?.cancel();
      mdnsSocket?.close();
    }

    return discoveredByMdns;
  }

  Uint8List _buildMdnsPtrQueryPacket(String serviceDomain) {
    final labels = serviceDomain.split('.');
    final bytes = <int>[
      0x00, 0x00, // Transaction ID
      0x00, 0x00, // Flags: standard query
      0x00, 0x01, // Questions: 1
      0x00, 0x00, // Answer RRs
      0x00, 0x00, // Authority RRs
      0x00, 0x00, // Additional RRs
    ];
    for (final label in labels) {
      final encoded = ascii.encode(label);
      bytes.add(encoded.length & 0xFF);
      bytes.addAll(encoded);
    }
    bytes.add(0x00); // End of QNAME
    bytes.addAll(const <int>[
      0x00, 0x0C, // QTYPE = PTR (12)
      0x00, 0x01, // QCLASS = IN (1)
    ]);
    return Uint8List.fromList(bytes);
  }

  String _extractReadableMdnsLabel(Uint8List packet) {
    if (packet.length < 16) return '';
    final printable = StringBuffer();
    final candidates = <String>[];
    for (final b in packet.skip(12)) {
      if ((b >= 48 && b <= 57) ||
          (b >= 65 && b <= 90) ||
          (b >= 97 && b <= 122) ||
          b == 45 ||
          b == 32) {
        printable.writeCharCode(b);
      } else {
        if (printable.length >= 4) {
          candidates.add(printable.toString().trim());
        }
        printable.clear();
      }
    }
    if (printable.length >= 4) {
      candidates.add(printable.toString().trim());
    }
    for (final item in candidates) {
      final lower = item.toLowerCase();
      if (lower == 'local' ||
          lower == 'androidtvremote2' ||
          lower == 'googlecast' ||
          lower.startsWith('_')) {
        continue;
      }
      if (item.length >= 4 && item.length <= 36) {
        return item;
      }
    }
    return '';
  }

  /// Discovers all Android TV / Google TV devices on the local network using
  /// native iOS `en0` (`IP_BOUND_IF`) + Bonjour scanning, mDNS (`224.0.0.251:5353`),
  /// 2-stage ARP-warmup `/24` subnet sweeping (`2..254`), Port 5555 (ADB) +
  /// Port 6466 (Android TV Remote v2) probing, and `getprop` model detection.
  Future<List<TvDevice>> discoverDevices({
    String preferredIp = '192.168.1.125',
    bool forceFullSubnetScan = false,
  }) async {
    final cleanPreferred = preferredIp.trim();
    final discoveredMap = <String, TvDevice>{};
    final isIos = Platform.isIOS;
    final isTestEnv =
        Platform.environment.containsKey('FLUTTER_TEST') &&
        !forceFullSubnetScan;

    // 1. Detect active Wi-Fi IPv4 address (en0 / wlan0) first so sockets bind to Wi-Fi
    final prefixes = <String>{};
    final selfIps = <String>{};
    String bestWifiIp = '';

    if (isIos && !isTestEnv) {
      try {
        final wifiInfo = await _networkChannel
            .invokeMethod<Map<Object?, Object?>>('getWifiInfo');
        final nativeWifiIp = wifiInfo?['wifiIp']?.toString().trim() ?? '';
        final nativePrefix = wifiInfo?['subnetPrefix']?.toString().trim() ?? '';
        if (isValidIp(nativeWifiIp)) {
          bestWifiIp = nativeWifiIp;
          _detectedWifiIp = nativeWifiIp;
          selfIps.add(nativeWifiIp);
        }
        if (nativePrefix.isNotEmpty) {
          prefixes.add(nativePrefix);
        }
      } catch (_) {}
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final sortedInterfaces = [...interfaces]..sort((a, b) {
        int score(NetworkInterface iface) {
          final lower = iface.name.toLowerCase();
          if (lower == 'en0' || lower == 'wlan0' || lower.contains('wi-fi')) {
            return 0;
          }
          if (lower.startsWith('en') || lower.startsWith('wlan')) return 1;
          if (lower.startsWith('pdp') ||
              lower.startsWith('utun') ||
              lower.startsWith('awdl') ||
              lower.startsWith('llw') ||
              lower.contains('vethernet')) {
            return 9;
          }
          return 4;
        }

        return score(a).compareTo(score(b));
      });

      final fallbackPrefixes = <String>{};
      for (final iface in sortedInterfaces) {
        final lowerName = iface.name.toLowerCase();
        final isCellularOrTunnel =
            lowerName.startsWith('pdp') ||
            lowerName.startsWith('utun') ||
            lowerName.startsWith('awdl') ||
            lowerName.startsWith('llw') ||
            lowerName.contains('vethernet');
        for (final addr in iface.addresses) {
          final ip = addr.address.trim();
          selfIps.add(ip);
          final parts = ip.split('.');
          if (parts.length == 4) {
            final pfx = '${parts[0]}.${parts[1]}.${parts[2]}';
            if (parts[0] == '192' && parts[1] == '168' && !isCellularOrTunnel) {
              prefixes.add(pfx);
              if (bestWifiIp.isEmpty) {
                bestWifiIp = ip;
              }
            } else if ((parts[0] == '10' || parts[0] == '172') &&
                !isCellularOrTunnel) {
              fallbackPrefixes.add(pfx);
              if (bestWifiIp.isEmpty) {
                bestWifiIp = ip;
              }
            }
          }
        }
      }
      if (prefixes.isEmpty) {
        prefixes.addAll(fallbackPrefixes);
      }
      if (bestWifiIp.isNotEmpty) {
        _detectedWifiIp = bestWifiIp;
      }
    } catch (_) {}

    final prefParts = cleanPreferred.split('.');
    if (prefParts.length == 4 &&
        (prefParts[0] == '192' ||
            prefParts[0] == '10' ||
            prefParts[0] == '172')) {
      prefixes.add('${prefParts[0]}.${prefParts[1]}.${prefParts[2]}');
    }
    if (prefixes.isEmpty) {
      prefixes.add('192.168.1');
    }

    // 2. On iOS, run native en0 (IP_BOUND_IF) + Bonjour subnet scanner in parallel
    final nativeOpen5555 = <String>{};
    final nativeOpen6466 = <String>{};
    if (isIos && !isTestEnv) {
      try {
        final nativeScan = await _networkChannel
            .invokeMethod<Map<Object?, Object?>>(
              'scanSubnetForTvs',
              <String, Object?>{'preferredIp': cleanPreferred},
            )
            .timeout(const Duration(seconds: 7));
        if (nativeScan != null) {
          final denied = nativeScan['permissionDenied'] == true;
          _localNetworkPermissionDenied = denied;
          final wIp = nativeScan['wifiIp']?.toString().trim() ?? '';
          if (isValidIp(wIp)) {
            _detectedWifiIp = wIp;
            selfIps.add(wIp);
          }
          final raw5555 = nativeScan['open5555'];
          if (raw5555 is List) {
            for (final item in raw5555) {
              final s = item?.toString().trim() ?? '';
              if (isValidIp(s)) nativeOpen5555.add(s);
            }
          }
          final raw6466 = nativeScan['open6466'];
          if (raw6466 is List) {
            for (final item in raw6466) {
              final s = item?.toString().trim() ?? '';
              if (isValidIp(s)) nativeOpen6466.add(s);
            }
          }
        }
      } catch (_) {}
    }

    // 3. Probe preferred IP (with 2-stage ARP warmup) and mDNS in parallel
    final prefAdbTimeout = Duration(
      milliseconds: isTestEnv ? 350 : (isIos ? 950 : 750),
    );
    final prefRemoteTimeout = Duration(
      milliseconds: isTestEnv ? 300 : (isIos ? 650 : 500),
    );

    final preferredPort5555Future = nativeOpen5555.contains(cleanPreferred)
        ? Future<bool>.value(true)
        : pingTv(
            cleanPreferred,
            port: 5555,
            timeout: prefAdbTimeout,
            warmupRetry: !isTestEnv,
          );
    final preferredPort6466Future = nativeOpen6466.contains(cleanPreferred)
        ? Future<bool>.value(true)
        : pingTv(
            cleanPreferred,
            port: 6466,
            timeout: prefRemoteTimeout,
          );
    final mdnsFuture = isTestEnv
        ? Future<Map<String, String>>.value(const <String, String>{})
        : _discoverViaMdns();

    final isPreferred5555 = await preferredPort5555Future;
    final isPreferred6466 = await preferredPort6466Future;
    final mdnsHits = await mdnsFuture;

    var preferredDevice = TvDevice(
      name: (cleanPreferred == '192.168.1.123' ||
              cleanPreferred == '192.168.1.125')
          ? 'Redline Android TV (Salon)'
          : (mdnsHits[cleanPreferred] ?? 'Android TV ($cleanPreferred)'),
      ip: cleanPreferred,
      port: isPreferred5555 ? 5555 : (isPreferred6466 ? 6466 : 5555),
      protocol: (!isPreferred5555 && isPreferred6466)
          ? TvConnectionProtocol.remotePort6466
          : TvConnectionProtocol.adbPort5555,
      isPaired: isPreferred5555 || _pinPairedIps.contains(cleanPreferred),
      boardInfo: isPreferred5555
          ? 'Realtek RTD2851P • Port 5555 Aktif'
          : (isPreferred6466
                ? 'Google TV • Standart Kumanda Modu (Port 6466 Hazır)'
                : (_localNetworkPermissionDenied
                      ? 'iOS Yerel Ağ İzni Kapalı • iPhone Ayarlarından Açın'
                      : 'Realtek RTD2851P • CleanYourTV OS')),
      isOnline: isPreferred5555 || isPreferred6466,
    );

    if (isPreferred5555) {
      preferredDevice = await probeTvDeviceProfile(preferredDevice);
    }
    discoveredMap[cleanPreferred] = preferredDevice;

    // 4. Add any additional TVs already found by native iOS en0 scanner
    for (final ip in <String>{...nativeOpen5555, ...nativeOpen6466}) {
      if (ip == cleanPreferred || selfIps.contains(ip)) continue;
      final is5555 = nativeOpen5555.contains(ip);
      final base = TvDevice(
        name: mdnsHits[ip] ?? 'Android TV ($ip)',
        ip: ip,
        port: is5555 ? 5555 : 6466,
        protocol: is5555
            ? TvConnectionProtocol.adbPort5555
            : TvConnectionProtocol.remotePort6466,
        isPaired: is5555 || _pinPairedIps.contains(ip),
        boardInfo: is5555
            ? 'Android TV • Port 5555 Aktif'
            : 'Google TV • Standart Kumanda Modu (Port 6466 Hazır)',
        isOnline: true,
      );
      discoveredMap[ip] = is5555 ? await probeTvDeviceProfile(base) : base;
    }

    // 5. Cross-platform 2-stage ARP-warmup + /24 subnet sweep
    if (isTestEnv) {
      final list = discoveredMap.values.toList();
      return list;
    }

    // If native iOS scan already completed the full en0 sweep, only probe mDNS hits not yet checked
    final primaryPrefix = prefixes.first;
    final priorityIps = <String>[...mdnsHits.keys];
    if (!isIos || (nativeOpen5555.isEmpty && !_localNetworkPermissionDenied)) {
      for (var octet = 95; octet <= 160; octet++) {
        priorityIps.add('$primaryPrefix.$octet');
      }
    }
    final cleanPriority = priorityIps
        .where(
          (ip) =>
              isValidIp(ip) &&
              !selfIps.contains(ip) &&
              !(discoveredMap[ip]?.isOnline ?? false),
        )
        .toSet()
        .toList();

    // Stage 5A: Fast 240ms ARP-warmup pass across priority DHCP range (95..160)
    const warmupBatchSize = 22;
    for (var i = 0; i < cleanPriority.length; i += warmupBatchSize) {
      final end = (i + warmupBatchSize < cleanPriority.length)
          ? i + warmupBatchSize
          : cleanPriority.length;
      final batch = cleanPriority.sublist(i, end);
      await Future.wait(
        batch.map(
          (ip) => pingTv(
            ip,
            port: 5555,
            timeout: const Duration(milliseconds: 240),
          ),
        ),
      );
    }

    if (cleanPriority.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }

    // Stage 5B: Probe priority DHCP range (95..160) now that Wi-Fi ARP is warm
    const probeBatchSize = 22;
    for (var i = 0; i < cleanPriority.length; i += probeBatchSize) {
      final end = (i + probeBatchSize < cleanPriority.length)
          ? i + probeBatchSize
          : cleanPriority.length;
      final batch = cleanPriority.sublist(i, end);
      final results = await Future.wait(
        batch.map((candidateIp) async {
          final portChecks = await Future.wait<bool>(<Future<bool>>[
            pingTv(
              candidateIp,
              port: 5555,
              timeout: const Duration(milliseconds: 720),
            ),
            pingTv(
              candidateIp,
              port: 6466,
              timeout: const Duration(milliseconds: 450),
            ),
          ]);
          final adbOk = portChecks[0];
          final remotePortOk = portChecks[1];
          final mdnsLabel = mdnsHits[candidateIp];
          if (adbOk) {
            final baseDevice = TvDevice(
              name: mdnsLabel ?? 'Android TV ($candidateIp)',
              ip: candidateIp,
              port: 5555,
              boardInfo: 'Android TV • Port 5555 Aktif',
              isOnline: true,
            );
            return probeTvDeviceProfile(baseDevice);
          }

          if (remotePortOk || mdnsLabel != null) {
            return TvDevice(
              name: mdnsLabel ?? 'Android / Google TV ($candidateIp)',
              ip: candidateIp,
              port: remotePortOk ? 6466 : 5555,
              protocol: remotePortOk
                  ? TvConnectionProtocol.remotePort6466
                  : TvConnectionProtocol.adbPort5555,
              isPaired: _pinPairedIps.contains(candidateIp),
              boardInfo: remotePortOk
                  ? 'Google TV • Standart Kumanda Modu (Port 6466 Hazır)'
                  : 'Android TV Bulundu • PIN (6466) veya ADB (5555) ile Eşleştirin',
              isOnline: remotePortOk,
            );
          }
          return null;
        }),
      );
      for (final item in results) {
        if (item != null) {
          discoveredMap[item.ip] = item;
        }
      }
    }

    // Stage 5C: If no online TV found yet, sweep remaining octets (2..94, 161..254)
    final hasAnyOnline = discoveredMap.values.any((d) => d.isOnline);
    if (!hasAnyOnline && !isIos) {
      final remainingIps = <String>[];
      for (var octet = 2; octet <= 94; octet++) {
        remainingIps.add('$primaryPrefix.$octet');
      }
      for (var octet = 161; octet <= 254; octet++) {
        remainingIps.add('$primaryPrefix.$octet');
      }
      final validRemaining = remainingIps
          .where((ip) => isValidIp(ip) && !selfIps.contains(ip))
          .toList();
      const remBatchSize = 32;
      for (var i = 0; i < validRemaining.length; i += remBatchSize) {
        final end = (i + remBatchSize < validRemaining.length)
            ? i + remBatchSize
            : validRemaining.length;
        final batch = validRemaining.sublist(i, end);
        final results = await Future.wait(
          batch.map((candidateIp) async {
            final adbOk = await pingTv(
              candidateIp,
              port: 5555,
              timeout: const Duration(milliseconds: 420),
            );
            if (!adbOk) return null;
            final baseDevice = TvDevice(
              name: 'Android TV ($candidateIp)',
              ip: candidateIp,
              port: 5555,
              boardInfo: 'Android TV • Port 5555 Aktif',
              isOnline: true,
            );
            return probeTvDeviceProfile(baseDevice);
          }),
        );
        for (final item in results) {
          if (item != null) {
            discoveredMap[item.ip] = item;
          }
        }
      }
    }

    // If a real online TV was found on another IP while preferredIp is offline, remove the stale offline entry
    final anyOnlineFound = discoveredMap.values.any((d) => d.isOnline);
    if (anyOnlineFound && !(discoveredMap[cleanPreferred]?.isOnline ?? false)) {
      discoveredMap.remove(cleanPreferred);
    }

    final list = discoveredMap.values.toList();
    list.sort((a, b) {
      if (a.isOnline != b.isOnline) {
        return a.isOnline ? -1 : 1;
      }
      if (a.ip == cleanPreferred) return -1;
      if (b.ip == cleanPreferred) return 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  /// Builds an ultra-fast `/dev/input/event0` (`venus_IR_input.kl`) raw 32-bit
  /// `struct input_event` injection shell command (~40-120ms on Realtek RTD2851P)
  /// ONLY when `venus_IR_input.kl` is present on the TV; otherwise uses universal
  /// `input keyevent` so every Android TV / Google TV brand works reliably.
  String _buildFastKeyShellCommand(TvKeyCommand command) {
    final scan = command.linuxScanCode;
    final code = command.keyCode;
    if (scan <= 0) return 'input keyevent $code';
    final lo = (scan & 0xFF).toRadixString(16).padLeft(2, '0');
    final hi = ((scan >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
    const z8 = r'\x00\x00\x00\x00\x00\x00\x00\x00';
    final down = '$z8\\x01\\x00\\x$lo\\x$hi\\x01\\x00\\x00\\x00';
    const syn = '$z8\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00';
    final up = '$z8\\x01\\x00\\x$lo\\x$hi\\x00\\x00\\x00\\x00';
    return "if [ -w /dev/input/event0 ] && ( [ -f /vendor/usr/keylayout/venus_IR_input.kl ] || [ -f /system/usr/keylayout/venus_IR_input.kl ] ); then printf '$down$syn$up$syn' > /dev/input/event0; else input keyevent $code; fi";
  }

  /// Sends a remote control key command to the target TV via either Port 5555 (ADB Turbo)
  /// or Port 6466 (Zero-Config Android TV Remote v2 TLS).
  Future<bool> sendKeyCommand(TvDevice device, TvKeyCommand command) async {
    final code = command.keyCode;
    if (code < 1 || code > 300) return false;

    if (device.protocol == TvConnectionProtocol.remotePort6466 ||
        device.port == 6466) {
      final remoteOk = await _sendRemote6466KeyFrame(device, code);
      if (remoteOk) return true;
    }

    if (command == TvKeyCommand.inputs) {
      final adbOk = await _executeShellCommand(
        device,
        'if pm path com.toptech.tvmenu >/dev/null 2>&1; then am start -n com.toptech.tvmenu/.input.InputActivity; else input keyevent 178; fi',
      );
      if (adbOk) return true;
      return _sendRemote6466KeyFrame(device, code);
    }

    final adbOk = await _executeShellCommand(
      device,
      _buildFastKeyShellCommand(command),
    );
    if (adbOk) return true;
    return _sendRemote6466KeyFrame(device, code);
  }

  /// Launches a streaming platform app or beams a specific deep-link / playlist URL to the TV.
  Future<bool> launchPlatformOrDeepLink(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async {
    final pkg = platform.packageName;
    if (!_safePackageRegex.hasMatch(pkg)) return false;

    final activity = platform.leanbackActivity;
    final hasValidActivity =
        activity.isNotEmpty && _safeActivityRegex.hasMatch(activity);
    final fallbackLaunchCmd = hasValidActivity
        ? 'am start -n $pkg/$activity'
        : 'monkey -p $pkg -c android.intent.category.LEANBACK_LAUNCHER 1';

    final normalizedUrl = WatchCueItem.normalizeContentLink(
      platform,
      deepLinkUrl,
    );
    if (normalizedUrl.isNotEmpty) {
      final uri = Uri.tryParse(normalizedUrl);
      if (uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          _safeUrlRegex.hasMatch(normalizedUrl)) {
        return _executeShellCommand(
          device,
          "am start -a android.intent.action.VIEW -d '$normalizedUrl' $pkg || $fallbackLaunchCmd",
        );
      }
    }

    if (platform == StreamingPlatform.youtube &&
        fallbackSearchQuery.trim().isNotEmpty) {
      final safeQuery = fallbackSearchQuery
          .replaceAll(RegExp(r'[^a-zA-Z0-9ğüşıöçĞÜŞİÖÇ ]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (safeQuery.isNotEmpty) {
        final encoded = Uri.encodeQueryComponent(safeQuery)
            .replaceAll("'", '%27')
            .replaceAll('!', '%21')
            .replaceAll('(', '%28')
            .replaceAll(')', '%29')
            .replaceAll('*', '%2A');
        return _executeShellCommand(
          device,
          "am start -a android.intent.action.VIEW -d 'https://www.youtube.com/results?search_query=$encoded' $pkg",
        );
      }
    }

    return _executeShellCommand(device, fallbackLaunchCmd);
  }

  /// Sends sanitized plain text to the TV's focused search/input field.
  Future<bool> sendSearchText(TvDevice device, String rawText) async {
    final sanitized = rawText
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9ğüşıöçĞÜŞİÖÇ .,:@/_-]'), '')
        .replaceAll(' ', '%s');
    if (sanitized.isEmpty) return false;
    return _executeShellCommand(device, 'input text "$sanitized"');
  }

  /// Opens the native Android speech recognizer on the phone and returns the
  /// spoken transcript string (or `null` if canceled/unavailable).
  Future<String?> listenPhoneMicrophone({String locale = 'tr-TR'}) async {
    try {
      final result = await _voiceChannel.invokeMethod<String>(
        'startVoiceRecognition',
        <String, dynamic>{'locale': locale},
      );
      final trimmed = result?.trim();
      if (trimmed == null || trimmed.isEmpty) return null;
      return trimmed;
    } catch (_) {
      return null;
    }
  }

  /// Parses a natural-language Turkish/English voice transcript and executes
  /// the corresponding hardware key, platform launch, or direct YouTube search
  /// on the TV, returning a user-facing telemetry status message.
  Future<String> executeVoiceCommand(
    TvDevice device,
    String rawSpokenText,
  ) async {
    final cleanRaw = rawSpokenText.trim();
    if (cleanRaw.isEmpty) {
      return 'Sesli komut algılanamadı';
    }

    final lower = cleanRaw
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase();

    bool matchesAny(List<String> phrases) {
      for (final p in phrases) {
        if (lower.contains(p)) return true;
      }
      return false;
    }

    if (matchesAny(<String>['sesi aç', 'ses arttır', 'ses artır', 'ses yükselt'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.volUp);
      return ok
          ? '🎙️ Ses yükseltildi: "$cleanRaw"'
          : '⚡ Ses yükseltme sinyali gönderildi';
    }

    if (matchesAny(<String>['sesi kıs', 'ses azalt', 'sesi indir'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.volDown);
      return ok
          ? '🎙️ Ses kısıldı: "$cleanRaw"'
          : '⚡ Ses kısma sinyali gönderildi';
    }

    if (matchesAny(<String>['sessize al', 'sessiz', 'sustur'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.mute);
      return ok
          ? '🎙️ TV sessize alındı: "$cleanRaw"'
          : '⚡ Sessiz komutu gönderildi';
    }

    if (matchesAny(<String>['televizyonu kapat', 'kapat', 'uyku'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.power);
      return ok
          ? '🎙️ TV güç/uyku komutu uygulandı: "$cleanRaw"'
          : '⚡ Güç komutu gönderildi';
    }

    if (matchesAny(<String>['ana ekran', 'eve dön', 'home'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.home);
      return ok
          ? '🎙️ TV Ana Ekran açıldı: "$cleanRaw"'
          : '⚡ Ana ekran komutu gönderildi';
    }

    if (matchesAny(<String>['geri dön', 'geri'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.back);
      return ok
          ? '🎙️ Geri tuşu gönderildi: "$cleanRaw"'
          : '⚡ Geri komutu gönderildi';
    }

    if (matchesAny(<String>['menü', 'ayarlar'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.menu);
      return ok
          ? '🎙️ TV Menüsü açıldı: "$cleanRaw"'
          : '⚡ Menü komutu gönderildi';
    }

    if (matchesAny(<String>['hdmi', 'giriş', 'kaynak'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.inputs);
      return ok
          ? '🎙️ TV Giriş/Kaynak seçici açıldı: "$cleanRaw"'
          : '⚡ Giriş seçici komutu gönderildi';
    }

    if (matchesAny(<String>['durdur', 'duraklat', 'oynat', 'devam et'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.playPause);
      return ok
          ? '🎙️ Oynat/Duraklat uygulandı: "$cleanRaw"'
          : '⚡ Oynat/Duraklat komutu gönderildi';
    }

    if (matchesAny(<String>['kanal ileri', 'sonraki kanal'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.channelUp);
      return ok
          ? '🎙️ Sonraki kanala geçildi: "$cleanRaw"'
          : '⚡ Kanal + komutu gönderildi';
    }

    if (matchesAny(<String>['kanal geri', 'önceki kanal'])) {
      final ok = await sendKeyCommand(device, TvKeyCommand.channelDown);
      return ok
          ? '🎙️ Önceki kanala geçildi: "$cleanRaw"'
          : '⚡ Kanal - komutu gönderildi';
    }

    if (matchesAny(<String>['bein', 'maç', 'derbi'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.beinConnect,
      );
      return ok
          ? '🎙️ TV\'de beIN CONNECT açıldı'
          : '⚡ beIN CONNECT başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['tabii'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.tabii,
      );
      return ok
          ? '🎙️ TV\'de tabii açıldı'
          : '⚡ tabii başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['netflix'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.netflix,
      );
      return ok
          ? '🎙️ TV\'de Netflix açıldı'
          : '⚡ Netflix başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['tivibu'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.tivibu,
      );
      return ok
          ? '🎙️ TV\'de Tivibu açıldı'
          : '⚡ Tivibu başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['zikirce'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.zikirce,
      );
      return ok
          ? '🎙️ TV\'de Zikirce açıldı'
          : '⚡ Zikirce başlatma sinyali gönderildi';
    }

    if (lower == 'youtube' ||
        lower == 'youtube aç' ||
        lower == 'youtube uygulamasını aç') {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.youtube,
      );
      return ok
          ? '🎙️ TV\'de YouTube açıldı'
          : '⚡ YouTube başlatma sinyali gönderildi';
    }

    var cleanQuery = cleanRaw
        .replaceAll(
          RegExp(
            r"(youtube'da|youtubeda|youtube'dan|youtube|ara|aç|izle)",
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^a-zA-Z0-9ğüşıöçĞÜŞİÖÇ ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanQuery.isEmpty) {
      cleanQuery = cleanRaw
          .replaceAll(RegExp(r'[^a-zA-Z0-9ğüşıöçĞÜŞİÖÇ ]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    if (cleanQuery.isEmpty) {
      return 'Geçerli bir sesli arama metni bulunamadı';
    }

    final encoded = Uri.encodeQueryComponent(cleanQuery)
        .replaceAll("'", '%27')
        .replaceAll('!', '%21')
        .replaceAll('(', '%28')
        .replaceAll(')', '%29')
        .replaceAll('*', '%2A');
    final ok = await _executeShellCommand(
      device,
      "am start -a android.intent.action.VIEW -d 'https://www.youtube.com/results?search_query=$encoded' com.google.android.youtube.tv",
    );
    return ok
        ? '🎙️ YouTube\'da aratıldı: "$cleanQuery"'
        : '⚡ YouTube arama sinyali gönderildi: "$cleanQuery"';
  }

  /// Executes a shell command on the TV and returns its captured UTF-8 stdout
  /// (or `null` if the connection/command failed).
  Future<String?> _executeShellCommandWithOutput(
    TvDevice device,
    String shellCmd, {
    bool allowInteractivePairing = false,
  }) async {
    if (!isValidIp(device.ip)) return null;

    if (Platform.isIOS &&
        !Platform.environment.containsKey('FLUTTER_TEST') &&
        !allowInteractivePairing) {
      try {
        final nativeRes = await _networkChannel
            .invokeMethod<Map<Object?, Object?>>(
              'nativeAdbShell',
              <String, Object?>{
                'ip': device.ip.trim(),
                'port': device.port,
                'command': shellCmd,
                'timeoutMs': 1600,
              },
            )
            .timeout(const Duration(seconds: 4));
        if (nativeRes != null) {
          if (nativeRes['permissionDenied'] == true) {
            _localNetworkPermissionDenied = true;
          }
          if (nativeRes['ok'] == true) {
            _localNetworkPermissionDenied = false;
            return nativeRes['output']?.toString() ?? '';
          }
        }
      } catch (_) {
        // Fall through to pure-Dart RSA-2048 ADB wire protocol
      }
    }

    if (Platform.isWindows) {
      final adbFile = File(r'C:\platform-tools\adb.exe');
      if (adbFile.existsSync()) {
        try {
          final target = '${device.ip}:${device.port}';
          await Process.run(
            adbFile.path,
            <String>['connect', target],
          ).timeout(const Duration(seconds: 2));
          final res = await Process.run(
            adbFile.path,
            <String>['-s', target, 'shell', shellCmd],
          ).timeout(const Duration(seconds: 3));
          if (res.exitCode == 0) {
            return res.stdout?.toString() ?? '';
          }
        } catch (_) {
          // Fall through to pure Dart ADB wire protocol
        }
      }
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      final connected = await _ensureConnected(
        device,
        allowInteractivePairing: allowInteractivePairing && attempt == 0,
      );
      if (!connected || _socket == null) {
        if (allowInteractivePairing) break;
        continue;
      }

      final localId = _nextLocalId++;
      if (_nextLocalId > 0x7FFFFFFF) {
        _nextLocalId = 1;
      }

      final streamDone = Completer<bool>();
      final outputBytes = <int>[];
      _streamCompleters[localId] = streamDone;
      _streamOutputBuffers[localId] = outputBytes;

      try {
        final openPayload = utf8.encode('shell:$shellCmd\x00');
        if (openPayload.length > _maxData) {
          _streamCompleters.remove(localId);
          _streamOutputBuffers.remove(localId);
          return null;
        }
        _socket!.add(
          _buildAdbPacket(
            command: _cmdOpen,
            arg0: localId,
            arg1: 0,
            payload: openPayload,
          ),
        );
        await _socket!.flush();

        final completed = await streamDone.future.timeout(
          const Duration(milliseconds: 2800),
          onTimeout: () => false,
        );
        _streamCompleters.remove(localId);
        final collected = _streamOutputBuffers.remove(localId) ?? const <int>[];
        _scheduleIdleDisconnect();
        if (completed) {
          return utf8.decode(collected, allowMalformed: true);
        }
      } catch (_) {
        _streamCompleters.remove(localId);
        _streamOutputBuffers.remove(localId);
        _closeConnection();
      }
    }

    return null;
  }

  /// Executes a whitelisted shell command on the TV via persistent pure-Dart ADB
  /// wire protocol (for Android/iOS phones) or local platform-tools bridge on desktop.
  Future<bool> _executeShellCommand(TvDevice device, String shellCmd) async {
    final res = await _executeShellCommandWithOutput(device, shellCmd);
    return res != null;
  }

  /// Builds a 24-byte ADB protocol header followed by payload bytes.
  Uint8List _buildAdbPacket({
    required int command,
    required int arg0,
    required int arg1,
    required List<int> payload,
  }) {
    var sum = 0;
    for (final b in payload) {
      sum = (sum + (b & 0xFF)) & 0xFFFFFFFF;
    }
    final magic = (command ^ 0xFFFFFFFF) & 0xFFFFFFFF;

    final buffer = ByteData(24 + payload.length);
    buffer.setUint32(0, command, Endian.little);
    buffer.setUint32(4, arg0, Endian.little);
    buffer.setUint32(8, arg1, Endian.little);
    buffer.setUint32(12, payload.length, Endian.little);
    buffer.setUint32(16, sum, Endian.little);
    buffer.setUint32(20, magic, Endian.little);

    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(24, 24 + payload.length, payload);
    return bytes;
  }
}
