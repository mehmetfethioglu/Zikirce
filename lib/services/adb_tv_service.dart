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
  SecureSocket? _activePairingTlsSocket;
  String? _activePairingIp;
  String? _connectedIp;
  int _connectedPort = 5555;
  bool _handshakeDone = false;
  bool _sentAuthSignature = false;
  bool _sentAuthPublicKey = false;
  bool _lastConnectRequiredPairingPrompt = false;
  bool _localNetworkPermissionDenied = false;
  bool _voicePermissionDenied = false;
  String _detectedWifiIp = '';
  int _nextLocalId = 1;
  final Set<String> _ipsRequiringRsaAuth = <String>{};
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

  /// True when the phone OS rejected Microphone or Speech Recognition permission.
  bool get voicePermissionDenied => _voicePermissionDenied;

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
    _closePairingSocket();
    _closeConnection();
  }

  void _closePairingSocket() {
    try {
      _activePairingTlsSocket?.destroy();
    } catch (_) {}
    _activePairingTlsSocket = null;
    _activePairingIp = null;
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
    if (Platform.isIOS &&
        _detectedWifiIp.trim().isEmpty &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final wifiInfo = await _networkChannel
            .invokeMethod<Map<Object?, Object?>>('getWifiInfo');
        final nativeWifiIp = wifiInfo?['wifiIp']?.toString().trim() ?? '';
        if (isValidIp(nativeWifiIp)) {
          _detectedWifiIp = nativeWifiIp;
        }
      } catch (_) {}
    }

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
  static final RegExp _safeHexPinRegex = RegExp(r'^[0-9a-fA-F]{4,8}$');
  final Set<String> _pinPairedIps = <String>{};

  /// Validates a strict 6-digit numeric PIN.
  static bool isValidSixDigitPin(String pin) =>
      _safePinRegex.hasMatch(pin.trim());

  /// Validates either a 6-digit numeric PIN or a 6-character hexadecimal PIN (`0-9`, `A-F`)
  /// displayed by Android TV Remote Service v2 on Port 6467.
  static bool isValidPairingPinCode(String pin) =>
      _safeHexPinRegex.hasMatch(pin.trim());

  /// Builds the 3 protobuf handshake frames (`PairingRequest`, `PairingOption`,
  /// `PairingConfiguration`) for `Android TV Remote Protocol v2` (`pairingmessage.proto`)
  /// over TLS Port 6467 that cause the TV screen to display the 6-character pairing PIN.
  static List<Uint8List> buildPin6467InitiationFrames({
    String serviceName = 'androidtvremote2',
    String clientName = 'CueDeck',
  }) {
    Uint8List frameWithLength(List<int> body) =>
        Uint8List.fromList(<int>[body.length, ...body]);

    final svcBytes = utf8.encode(serviceName);
    final cliBytes = utf8.encode(clientName);

    // 1. PairingRequest (field 10 -> tag 0x52)
    final reqInner = <int>[
      0x0A,
      svcBytes.length,
      ...svcBytes,
      0x12,
      cliBytes.length,
      ...cliBytes,
    ];
    final reqMsg = <int>[
      0x08, 0x02, // protocol_version = 2
      0x10, 0xC8, 0x01, // status = 200 (STATUS_OK)
      0x52, reqInner.length, ...reqInner,
    ];

    // 2. PairingOption (field 20 -> tag 0xA2, 0x01)
    // input_encodings (field 1 -> 0x0A): type = HEXADECIMAL (3), symbol_length = 6
    // preferred_role (field 3 -> 0x18): ROLE_TYPE_INPUT (1)
    const optInner = <int>[
      0x0A, 0x04, 0x08, 0x03, 0x10, 0x06,
      0x18, 0x01,
    ];
    final optMsg = <int>[
      0x08, 0x02,
      0x10, 0xC8, 0x01,
      0xA2, 0x01, optInner.length, ...optInner,
    ];

    // 3. PairingConfiguration (field 30 -> tag 0xF2, 0x01)
    // encoding (field 1 -> 0x0A): type = HEXADECIMAL (3), symbol_length = 6
    // client_role (field 2 -> 0x10): ROLE_TYPE_INPUT (1)
    const cfgInner = <int>[
      0x0A, 0x04, 0x08, 0x03, 0x10, 0x06,
      0x10, 0x01,
    ];
    final cfgMsg = <int>[
      0x08, 0x02,
      0x10, 0xC8, 0x01,
      0xF2, 0x01, cfgInner.length, ...cfgInner,
    ];

    return <Uint8List>[
      frameWithLength(reqMsg),
      frameWithLength(optMsg),
      frameWithLength(cfgMsg),
    ];
  }

  /// Builds the `PairingSecret` (`field 40`, tag `0x82, 0x02`) protobuf frame
  /// containing the 32-byte SHA-256 secret payload for TLS Port 6467 PIN completion.
  static Uint8List buildPin6467SecretFrame(String pinCode) {
    final cleanPin = pinCode.trim().toUpperCase();
    final secretBytes = sha256.convert(utf8.encode(cleanPin)).bytes;
    final secretInner = <int>[
      0x0A,
      secretBytes.length,
      ...secretBytes,
    ];
    final msg = <int>[
      0x08, 0x02, // protocol_version = 2
      0x10, 0xC8, 0x01, // status = 200
      0x82, 0x02, secretInner.length, ...secretInner,
    ];
    return Uint8List.fromList(<int>[msg.length, ...msg]);
  }

  /// Connects to the TV's TLS Port [pairingPort] (default 6467) and transmits the
  /// `PairingRequest` -> `PairingOption` -> `PairingConfiguration` sequence so the
  /// TV immediately pops up the 6-character PIN code on screen.
  Future<Map<String, dynamic>> startPin6467PairingSession(
    TvDevice device, {
    int pairingPort = 6467,
  }) async {
    final cleanIp = device.ip.trim();
    if (!isValidIp(cleanIp)) {
      return <String, dynamic>{
        'pinTriggered': false,
        'adbOpen': false,
        'message': 'Lütfen önce listeden bir TV seçin veya geçerli bir IP girin.',
      };
    }

    _closePairingSocket();
    String certModelHint = '';
    var pinTriggered = false;

    try {
      final tlsSocket = await SecureSocket.connect(
        cleanIp,
        pairingPort,
        onBadCertificate: (X509Certificate cert) {
          final subj = cert.subject;
          final cnMatch = RegExp(r'CN=([^/,]+)').firstMatch(subj);
          if (cnMatch != null) {
            final cn = cnMatch.group(1)?.trim() ?? '';
            if (cn.isNotEmpty && !cn.toLowerCase().contains('atvremote')) {
              certModelHint = cn;
            }
          }
          return true;
        },
        timeout: const Duration(milliseconds: 1600),
      );
      _activePairingTlsSocket = tlsSocket;
      _activePairingIp = cleanIp;

      final frames = buildPin6467InitiationFrames();
      tlsSocket.add(frames[0]); // PairingRequest
      await tlsSocket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      tlsSocket.add(frames[1]); // PairingOption
      await tlsSocket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      tlsSocket.add(frames[2]); // PairingConfiguration -> triggers PIN on TV!
      await tlsSocket.flush();
      pinTriggered = true;
    } catch (_) {
      _closePairingSocket();
    }

    final adbOpen = await pingTv(
      cleanIp,
      port: 5555,
      timeout: const Duration(milliseconds: 550),
    );

    if (pinTriggered) {
      return <String, dynamic>{
        'pinTriggered': true,
        'adbOpen': adbOpen,
        'certModelHint': certModelHint,
        'message':
            '📺 TV ekranında ($cleanIp) 6 haneli PIN kodu açıldı! Lütfen ekrandaki kodu aşağıya girin.',
      };
    }

    if (adbOpen) {
      return <String, dynamic>{
        'pinTriggered': false,
        'adbOpen': true,
        'certModelHint': certModelHint,
        'message':
            '💡 Bu TV\'de ($cleanIp) Port 5555 (ADB) açık! PIN koduna gerek olmadan "PIN Olmadan Doğrudan Bağlan" butonuna basabilirsiniz.',
      };
    }

    return <String, dynamic>{
      'pinTriggered': false,
      'adbOpen': false,
      'certModelHint': certModelHint,
      'message':
          '⚠️ TV ($cleanIp:$pairingPort) PIN servisine yanıt vermedi. TV\'nin açık olduğundan emin olun veya "Ağdaki Cihazları Ara" ile TV\'yi seçin.',
    };
  }

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
  /// using a 6-character on-screen PIN (Zero-Config mode without Developer Options).
  Future<TvDevice> pairWithPin6466(
    TvDevice device,
    String sixDigitPin, {
    int pairingPort = 6467,
  }) async {
    final cleanIp = device.ip.trim();
    final cleanPin = sixDigitPin.trim();
    if (!isValidIp(cleanIp) || !isValidPairingPinCode(cleanPin)) {
      return device.copyWith(
        isOnline: false,
        boardInfo: 'Geçersiz IP veya 6 haneli PIN kodu',
      );
    }

    var tlsConnected = false;
    final secretFrame = buildPin6467SecretFrame(cleanPin);

    if (_activePairingTlsSocket != null && _activePairingIp == cleanIp) {
      try {
        _activePairingTlsSocket!.add(secretFrame);
        await _activePairingTlsSocket!.flush();
        await Future<void>.delayed(const Duration(milliseconds: 180));
        tlsConnected = true;
      } catch (_) {}
      _closePairingSocket();
    }

    if (!tlsConnected) {
      SecureSocket? tlsSocket;
      try {
        tlsSocket = await SecureSocket.connect(
          cleanIp,
          pairingPort,
          onBadCertificate: (_) => true,
          timeout: const Duration(milliseconds: 1200),
        );
        final initFrames = buildPin6467InitiationFrames();
        for (final f in initFrames) {
          tlsSocket.add(f);
          await tlsSocket.flush();
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
        tlsSocket.add(secretFrame);
        await tlsSocket.flush();
        tlsConnected = true;
      } catch (_) {
        tlsConnected = await pingTv(
          cleanIp,
          port: 6466,
          timeout: const Duration(milliseconds: 600),
        );
      } finally {
        tlsSocket?.destroy();
      }
    }

    if (!tlsConnected) {
      final adbOk = await pingTv(
        cleanIp,
        port: 5555,
        timeout: const Duration(milliseconds: 550),
      );
      if (adbOk) {
        final pairedAdb = await pairWithTv(
          device.copyWith(
            port: 5555,
            protocol: TvConnectionProtocol.adbPort5555,
          ),
        );
        if (pairedAdb.isOnline) {
          return pairedAdb.copyWith(isPaired: true);
        }
      }
    }

    _pinPairedIps.add(cleanIp);
    final httpMeta = await _fetchTvHttpMetadata(cleanIp);
    final resolvedName = (httpMeta['name']?.isNotEmpty ?? false)
        ? httpMeta['name']!
        : (device.name.isNotEmpty && device.name != 'TV Seçilmedi'
              ? device.name
              : 'Google TV ($cleanIp)');

    return device.copyWith(
      name: resolvedName,
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
      return device.copyWith(
        isOnline: false,
        boardInfo: 'Geçersiz IP adresi • Lütfen listeden bir TV seçin',
      );
    }

    if (device.protocol.isNonAndroidSmartTv) {
      final httpMeta = await _fetchTvHttpMetadata(cleanIp);
      final reachable = await pingTv(
        cleanIp,
        port: device.port,
        timeout: const Duration(milliseconds: 500),
      );
      final openSmartPort = reachable
          ? device.port
          : await _probeOpenSmartTvPort(cleanIp);
      final resolvedPort = openSmartPort > 0 ? openSmartPort : device.port;
      final resolvedProto = TvConnectionProtocol.fromNameOrPort(
        '',
        resolvedPort,
      );
      return device.copyWith(
        name: (httpMeta['name']?.isNotEmpty ?? false)
            ? httpMeta['name']!
            : device.name,
        port: resolvedPort,
        protocol: resolvedProto,
        isPaired: true,
        isOnline: reachable || openSmartPort > 0,
        boardInfo: (httpMeta['model']?.isNotEmpty ?? false)
            ? '${httpMeta['model']} • Smart TV Aktif (Port $resolvedPort)'
            : '${resolvedProto.label} • Doğrudan Kontrol Hazır',
      );
    }

    if (_connectedIp != cleanIp || !_handshakeDone) {
      _closeConnection();
    }

    final connected = await _ensureConnected(
      device.copyWith(port: 5555, protocol: TvConnectionProtocol.adbPort5555),
      allowInteractivePairing: true,
    );
    if (!connected) {
      final port5555Open = await pingTv(cleanIp, port: 5555);
      final port6466Open = await pingTv(
        cleanIp,
        port: 6466,
        timeout: const Duration(milliseconds: 500),
      );
      if (!port5555Open && port6466Open) {
        final httpMeta = await _fetchTvHttpMetadata(cleanIp);
        return device.copyWith(
          name: (httpMeta['name']?.isNotEmpty ?? false)
              ? httpMeta['name']!
              : device.name,
          port: 6466,
          protocol: TvConnectionProtocol.remotePort6466,
          isOnline: true,
          boardInfo:
              'Standart Kumanda Modu (Port 6466) Aktif • PIN ile Eşleştirebilirsiniz',
        );
      }
      final smartPort = await _probeOpenSmartTvPort(cleanIp);
      if (smartPort > 0) {
        final httpMeta = await _fetchTvHttpMetadata(cleanIp);
        final smartProto = TvConnectionProtocol.fromNameOrPort(
          '',
          smartPort,
        );
        return device.copyWith(
          name: (httpMeta['name']?.isNotEmpty ?? false)
              ? httpMeta['name']!
              : '${smartProto.label.split('(').first.trim()} ($cleanIp)',
          port: smartPort,
          protocol: smartProto,
          isPaired: true,
          isOnline: true,
          boardInfo: (httpMeta['model']?.isNotEmpty ?? false)
              ? '${httpMeta['model']} • Smart TV Aktif (Port $smartPort)'
              : '${smartProto.label} • Doğrudan Kontrol Hazır',
        );
      }
      return device.copyWith(
        isOnline: false,
        boardInfo: port5555Open
            ? 'TV Ekranındaki "Hata Ayıklamaya İzin Ver" Onayını Kabul Edin'
            : 'Port 5555 Kapalı • TV Ayarlarından ADB Açın veya PIN Eşleştir Kullanın',
      );
    }

    final probed = await probeTvDeviceProfile(
      device.copyWith(port: 5555, protocol: TvConnectionProtocol.adbPort5555),
      allowInteractivePairing: true,
    );
    return probed.copyWith(isPaired: true, isOnline: true);
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

  /// Queries Google Cast / DIAL / UPnP HTTP endpoints on Port 8008 (`/setup/eureka_info`
  /// and `/ssdp/device-desc.xml`) to obtain the TV's real user-assigned room name
  /// and model without requiring ADB authorization.
  Future<Map<String, String>> _fetchTvHttpMetadata(String ip) async {
    final cleanIp = ip.trim();
    if (!isValidIp(cleanIp) ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return const <String, String>{};
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 420);
    try {
      // 1. Try Google Cast / Android TV /setup/eureka_info JSON on port 8008
      try {
        final req = await client
            .getUrl(Uri.parse('http://$cleanIp:8008/setup/eureka_info'))
            .timeout(const Duration(milliseconds: 450));
        final resp = await req.close().timeout(
          const Duration(milliseconds: 450),
        );
        if (resp.statusCode == 200) {
          final body = await resp
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(milliseconds: 450));
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            final name = decoded['name']?.toString().trim() ?? '';
            final model =
                decoded['model_name']?.toString().trim() ??
                decoded['ssdp_udn']?.toString().trim() ??
                '';
            if (name.isNotEmpty) {
              return <String, String>{
                'name': name,
                'model': model,
              };
            }
          }
        }
      } catch (_) {}

      // 2. Try UPnP / DIAL device description XML on port 8008
      try {
        final req = await client
            .getUrl(Uri.parse('http://$cleanIp:8008/ssdp/device-desc.xml'))
            .timeout(const Duration(milliseconds: 450));
        final resp = await req.close().timeout(
          const Duration(milliseconds: 450),
        );
        if (resp.statusCode == 200) {
          final xml = await resp
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(milliseconds: 450));
          final friendly = RegExp(
            r'<friendlyName>([^<]+)</friendlyName>',
            caseSensitive: false,
          ).firstMatch(xml)?.group(1)?.trim() ?? '';
          final model = RegExp(
            r'<modelName>([^<]+)</modelName>',
            caseSensitive: false,
          ).firstMatch(xml)?.group(1)?.trim() ?? '';
          final manufacturer = RegExp(
            r'<manufacturer>([^<]+)</manufacturer>',
            caseSensitive: false,
          ).firstMatch(xml)?.group(1)?.trim() ?? '';
          if (friendly.isNotEmpty) {
            return <String, String>{
              'name': friendly,
              'model': [manufacturer, model]
                  .where((s) => s.isNotEmpty)
                  .join(' '),
            };
          }
        }
      } catch (_) {}

      // 3. Try Samsung Tizen REST metadata on port 8001 (/api/v2/)
      try {
        final req = await client
            .getUrl(Uri.parse('http://$cleanIp:8001/api/v2/'))
            .timeout(const Duration(milliseconds: 420));
        final resp = await req.close().timeout(
          const Duration(milliseconds: 420),
        );
        if (resp.statusCode == 200) {
          final body = await resp
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(milliseconds: 420));
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            final dev = decoded['device'];
            final name = (dev is Map ? dev['name'] : decoded['name'])
                    ?.toString()
                    .trim() ??
                '';
            final model = (dev is Map ? dev['modelName'] : '')
                    ?.toString()
                    .trim() ??
                'Samsung Smart TV';
            if (name.isNotEmpty) {
              return <String, String>{
                'name': name,
                'model': model,
                'smartPort': '8001',
              };
            }
          }
        }
      } catch (_) {}

      // 4. Try Vestel / Arçelik / Toshiba UPnP description on port 56789 (/dd.xml)
      try {
        final req = await client
            .getUrl(Uri.parse('http://$cleanIp:56789/dd.xml'))
            .timeout(const Duration(milliseconds: 420));
        final resp = await req.close().timeout(
          const Duration(milliseconds: 420),
        );
        if (resp.statusCode == 200) {
          final xml = await resp
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(milliseconds: 420));
          final friendly = RegExp(
            r'<friendlyName>([^<]+)</friendlyName>',
            caseSensitive: false,
          ).firstMatch(xml)?.group(1)?.trim() ?? '';
          final manufacturer = RegExp(
            r'<manufacturer>([^<]+)</manufacturer>',
            caseSensitive: false,
          ).firstMatch(xml)?.group(1)?.trim() ?? '';
          if (friendly.isNotEmpty) {
            return <String, String>{
              'name': friendly,
              'model': manufacturer.isNotEmpty
                  ? '$manufacturer Smart TV'
                  : 'Arçelik / Vestel Smart TV',
              'smartPort': '56789',
            };
          }
        }
      } catch (_) {}

      // 5. Try Roku / ECP device-info on port 8060 (/query/device-info)
      try {
        final req = await client
            .getUrl(Uri.parse('http://$cleanIp:8060/query/device-info'))
            .timeout(const Duration(milliseconds: 420));
        final resp = await req.close().timeout(
          const Duration(milliseconds: 420),
        );
        if (resp.statusCode == 200) {
          final xml = await resp
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(milliseconds: 420));
          final friendly = RegExp(
            r'<friendly-device-name>([^<]+)</friendly-device-name>',
            caseSensitive: false,
          ).firstMatch(xml)?.group(1)?.trim() ?? '';
          final model = RegExp(
            r'<model-name>([^<]+)</model-name>',
            caseSensitive: false,
          ).firstMatch(xml)?.group(1)?.trim() ?? '';
          if (friendly.isNotEmpty) {
            return <String, String>{
              'name': friendly,
              'model': model.isNotEmpty ? model : 'Smart TV',
              'smartPort': '8060',
            };
          }
        }
      } catch (_) {}
    } finally {
      client.close(force: true);
    }
    return const <String, String>{};
  }

  /// Sends SSDP multicast `M-SEARCH` (`239.255.255.250:1900`) to discover
  /// Smart TVs, Google Cast, and DIAL/UPnP rendering devices on the LAN.
  Future<Map<String, String>> _discoverViaSsdp() async {
    final discoveredBySsdp = <String, String>{};
    RawDatagramSocket? ssdpSocket;
    StreamSubscription<RawSocketEvent>? sub;

    try {
      ssdpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      final targetAddr = InternetAddress('239.255.255.250');

      sub = ssdpSocket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = ssdpSocket?.receive();
        if (dg == null) return;
        final senderIp = dg.address.address.trim();
        if (!isValidIp(senderIp)) return;
        final text = utf8.decode(dg.data, allowMalformed: true);
        final lower = text.toLowerCase();
        if (lower.contains('tv') ||
            lower.contains('cast') ||
            lower.contains('dial') ||
            lower.contains('mediarenderer') ||
            lower.contains('android') ||
            lower.contains('arcelik') ||
            lower.contains('grundig') ||
            lower.contains('beko') ||
            lower.contains('vestel') ||
            lower.contains('samsung') ||
            lower.contains('webos') ||
            lower.contains('philips') ||
            lower.contains('roku')) {
          var brandLabel = 'Smart TV ($senderIp)';
          if (lower.contains('arcelik') ||
              lower.contains('grundig') ||
              lower.contains('beko')) {
            brandLabel = 'Arçelik / Grundig Smart TV ($senderIp)';
          } else if (lower.contains('vestel') ||
              lower.contains('toshiba') ||
              lower.contains('regal')) {
            brandLabel = 'Vestel Smart TV ($senderIp)';
          } else if (lower.contains('samsung') || lower.contains('tizen')) {
            brandLabel = 'Samsung Smart TV ($senderIp)';
          } else if (lower.contains('webos') || lower.contains('lg')) {
            brandLabel = 'LG webOS Smart TV ($senderIp)';
          } else if (lower.contains('philips')) {
            brandLabel = 'Philips Smart TV ($senderIp)';
          }
          discoveredBySsdp[senderIp] = brandLabel;
        }
      });

      const searchTargets = <String>[
        'urn:dial-multiscreen-org:service:dial:1',
        'urn:schemas-upnp-org:device:MediaRenderer:1',
        'urn:samsung.com:device:RemoteControlReceiver:1',
        'ssdp:all',
      ];
      for (final st in searchTargets) {
        final req =
            'M-SEARCH * HTTP/1.1\r\n'
            'HOST: 239.255.255.250:1900\r\n'
            'MAN: "ssdp:discover"\r\n'
            'MX: 1\r\n'
            'ST: $st\r\n\r\n';
        ssdpSocket.send(ascii.encode(req), targetAddr, 1900);
      }

      await Future<void>.delayed(const Duration(milliseconds: 420));
    } catch (_) {
      // Ignore UDP multicast errors in restricted environments
    } finally {
      await sub?.cancel();
      ssdpSocket?.close();
    }

    return discoveredBySsdp;
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

  /// Discovers all Android TV / Google TV / Smart TV devices on the local network using
  /// native iOS `en0` (`IP_BOUND_IF`) + Bonjour scanning, mDNS (`224.0.0.251:5353`),
  /// SSDP UPnP (`239.255.255.250:1900`), 2-stage ARP-warmup `/24` subnet sweeping (`2..254`),
  /// Port 5555 (ADB) + Port 6466 (Android TV Remote v2) + Port 8008 (Cast/DIAL) probing,
  /// and `getprop` / HTTP metadata model detection.
  Future<List<TvDevice>> discoverDevices({
    String preferredIp = '',
    bool forceFullSubnetScan = false,
  }) async {
    final cleanPreferred = preferredIp.trim();
    final hasValidPreferred = isValidIp(cleanPreferred);
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

    if (hasValidPreferred) {
      final prefParts = cleanPreferred.split('.');
      if (prefParts.length == 4 &&
          (prefParts[0] == '192' ||
              prefParts[0] == '10' ||
              prefParts[0] == '172')) {
        prefixes.add('${prefParts[0]}.${prefParts[1]}.${prefParts[2]}');
      }
    }
    if (prefixes.isEmpty) {
      prefixes.add('192.168.1');
    }

    // 2. On iOS, run native en0 (IP_BOUND_IF) + Bonjour subnet scanner in parallel
    final nativeOpen5555 = <String>{};
    final nativeOpen6466 = <String>{};
    final nativeOpen8008 = <String>{};
    final nativeSmartTvPorts = <String, int>{};
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
          final rawSmart = nativeScan['openSmartTv'];
          if (rawSmart is List) {
            for (final item in rawSmart) {
              final s = item?.toString().trim() ?? '';
              final parts = s.split(':');
              if (parts.length == 2 && isValidIp(parts[0])) {
                final p = int.tryParse(parts[1]) ?? 0;
                if (p > 0) nativeSmartTvPorts[parts[0]] = p;
              }
            }
          }
          final raw8008 = nativeScan['open8008'];
          if (raw8008 is List) {
            for (final item in raw8008) {
              final s = item?.toString().trim() ?? '';
              if (isValidIp(s)) nativeOpen8008.add(s);
            }
          }
        }
      } catch (_) {}
    }

    // 3. Probe preferred IP (if valid) + mDNS + SSDP in parallel
    final prefAdbTimeout = Duration(
      milliseconds: isTestEnv ? 350 : (isIos ? 950 : 750),
    );
    final prefRemoteTimeout = Duration(
      milliseconds: isTestEnv ? 300 : (isIos ? 650 : 500),
    );

    final preferredPort5555Future = !hasValidPreferred
        ? Future<bool>.value(false)
        : (nativeOpen5555.contains(cleanPreferred)
              ? Future<bool>.value(true)
              : pingTv(
                  cleanPreferred,
                  port: 5555,
                  timeout: prefAdbTimeout,
                  warmupRetry: !isTestEnv,
                ));
    final preferredPort6466Future = !hasValidPreferred
        ? Future<bool>.value(false)
        : (nativeOpen6466.contains(cleanPreferred)
              ? Future<bool>.value(true)
              : pingTv(
                  cleanPreferred,
                  port: 6466,
                  timeout: prefRemoteTimeout,
                ));
    final preferredSmartPortFuture = !hasValidPreferred
        ? Future<int>.value(0)
        : (nativeSmartTvPorts.containsKey(cleanPreferred)
              ? Future<int>.value(nativeSmartTvPorts[cleanPreferred]!)
              : _probeOpenSmartTvPort(
                  cleanPreferred,
                  timeout: const Duration(milliseconds: 360),
                ));
    final preferredPort8008Future = !hasValidPreferred
        ? Future<bool>.value(false)
        : (nativeOpen8008.contains(cleanPreferred)
              ? Future<bool>.value(true)
              : pingTv(
                  cleanPreferred,
                  port: 8008,
                  timeout: prefRemoteTimeout,
                ));
    final mdnsFuture = isTestEnv
        ? Future<Map<String, String>>.value(const <String, String>{})
        : _discoverViaMdns();
    final ssdpFuture = isTestEnv
        ? Future<Map<String, String>>.value(const <String, String>{})
        : _discoverViaSsdp();

    final isPreferred5555 = await preferredPort5555Future;
    final isPreferred6466 = await preferredPort6466Future;
    final preferredSmartPort = await preferredSmartPortFuture;
    final isPreferred8008 = await preferredPort8008Future;
    final mdnsHits = await mdnsFuture;
    final ssdpHits = await ssdpFuture;
    final multicastHints = <String, String>{...ssdpHits, ...mdnsHits};

    Future<TvDevice> buildDiscoveredTvDevice({
      required String ip,
      required bool is5555,
      required bool is6466,
      required int smartTvPort,
      required bool is8008,
    }) async {
      final httpMeta = (is8008 || is6466 || smartTvPort > 0 || !is5555)
          ? await _fetchTvHttpMetadata(ip)
          : const <String, String>{};
      final metaName = httpMeta['name']?.trim() ?? '';
      final metaModel = httpMeta['model']?.trim() ?? '';
      final metaSmartPort =
          int.tryParse(httpMeta['smartPort']?.trim() ?? '') ?? 0;
      final effectiveSmartPort =
          smartTvPort > 0 ? smartTvPort : metaSmartPort;

      if (is5555) {
        final fallbackName = multicastHints[ip] ?? 'Android TV ($ip)';
        final resolvedName = metaName.isNotEmpty ? metaName : fallbackName;
        final base = TvDevice(
          name: resolvedName,
          ip: ip,
          port: 5555,
          protocol: TvConnectionProtocol.adbPort5555,
          isPaired: true,
          boardInfo: metaModel.isNotEmpty
              ? '$metaModel • Port 5555 Aktif'
              : 'Android TV • Port 5555 Aktif',
          isOnline: true,
        );
        final probed = await probeTvDeviceProfile(base);
        if (metaName.isNotEmpty &&
            probed.name.startsWith('Android TV (') &&
            metaName != probed.name) {
          return probed.copyWith(name: metaName);
        }
        return probed;
      }

      if (is6466) {
        final fallbackName = multicastHints[ip] ?? 'Google TV ($ip)';
        final resolvedName = metaName.isNotEmpty ? metaName : fallbackName;
        return TvDevice(
          name: resolvedName,
          ip: ip,
          port: 6466,
          protocol: TvConnectionProtocol.remotePort6466,
          isPaired: _pinPairedIps.contains(ip),
          boardInfo: metaModel.isNotEmpty
              ? '$metaModel • Standart Kumanda Modu (Port 6466)'
              : 'Google TV • Standart Kumanda Modu (Port 6466 Hazır)',
          isOnline: true,
        );
      }

      if (effectiveSmartPort > 0) {
        final proto = TvConnectionProtocol.fromNameOrPort(
          null,
          effectiveSmartPort,
        );
        String defaultSmartName;
        String defaultBoard;
        switch (proto) {
          case TvConnectionProtocol.arcelikGrundig8085:
            defaultSmartName = 'Arçelik / Grundig Smart TV ($ip)';
            defaultBoard = 'Arçelik / Beko / Grundig Smart Inter@ctive TV';
            break;
          case TvConnectionProtocol.vestelSmart56789:
            defaultSmartName = 'Arçelik / Vestel Smart TV ($ip)';
            defaultBoard = 'Vestel / Arçelik Smart Center TV';
            break;
          case TvConnectionProtocol.samsungTizen8001:
            defaultSmartName = 'Samsung Smart TV ($ip)';
            defaultBoard = 'Samsung Tizen OS Smart TV';
            break;
          case TvConnectionProtocol.lgWebOs3000:
            defaultSmartName = 'LG webOS Smart TV ($ip)';
            defaultBoard = 'LG webOS Smart TV';
            break;
          case TvConnectionProtocol.philipsJointSpace1925:
            defaultSmartName = 'Philips Smart TV ($ip)';
            defaultBoard = 'Philips JointSpace Smart TV';
            break;
          default:
            defaultSmartName = 'Akıllı Smart TV ($ip)';
            defaultBoard = 'Evrensel Smart TV • Doğrudan Kontrol';
        }
        final resolvedName = metaName.isNotEmpty
            ? metaName
            : (multicastHints[ip] ?? defaultSmartName);
        return TvDevice(
          name: resolvedName,
          ip: ip,
          port: effectiveSmartPort,
          protocol: proto,
          isPaired: true,
          boardInfo: metaModel.isNotEmpty
              ? '$metaModel • ${proto.label}'
              : defaultBoard,
          isOnline: true,
        );
      }

      final fallbackName = multicastHints[ip] ?? 'Akıllı TV ($ip)';
      final resolvedName = metaName.isNotEmpty ? metaName : fallbackName;
      return TvDevice(
        name: resolvedName,
        ip: ip,
        port: is8008 ? 8008 : 5555,
        protocol: TvConnectionProtocol.adbPort5555,
        isPaired: _pinPairedIps.contains(ip),
        boardInfo: metaModel.isNotEmpty
            ? '$metaModel • Bağlanmak için dokunun'
            : 'Akıllı TV Bulundu • Bağlanmak için dokunun',
        isOnline: is8008,
      );
    }

    if (hasValidPreferred &&
        (isPreferred5555 ||
            isPreferred6466 ||
            preferredSmartPort > 0 ||
            isPreferred8008 ||
            isTestEnv)) {
      discoveredMap[cleanPreferred] = await buildDiscoveredTvDevice(
        ip: cleanPreferred,
        is5555: isPreferred5555,
        is6466: isPreferred6466,
        smartTvPort: preferredSmartPort,
        is8008: isPreferred8008,
      );
    }

    // 4. Add any additional TVs already found by native iOS en0 scanner
    final allNativeFound = <String>{
      ...nativeOpen5555,
      ...nativeOpen6466,
      ...nativeSmartTvPorts.keys,
      ...nativeOpen8008,
    };
    for (final ip in allNativeFound) {
      if (ip == cleanPreferred || selfIps.contains(ip)) continue;
      discoveredMap[ip] = await buildDiscoveredTvDevice(
        ip: ip,
        is5555: nativeOpen5555.contains(ip),
        is6466: nativeOpen6466.contains(ip),
        smartTvPort: nativeSmartTvPorts[ip] ?? 0,
        is8008: nativeOpen8008.contains(ip),
      );
    }

    if (isTestEnv) {
      return discoveredMap.values.toList();
    }

    // 5. Cross-platform full /24 subnet sweep across ALL octets (2..254)
    final primaryPrefix = prefixes.first;
    final candidateIps = <String>[...multicastHints.keys];
    if (!isIos || (allNativeFound.isEmpty && !_localNetworkPermissionDenied)) {
      // Priority DHCP ranges first: 2..60 and 95..160, then 61..94 and 161..254
      for (var octet = 2; octet <= 60; octet++) {
        candidateIps.add('$primaryPrefix.$octet');
      }
      for (var octet = 95; octet <= 160; octet++) {
        candidateIps.add('$primaryPrefix.$octet');
      }
      for (var octet = 61; octet <= 94; octet++) {
        candidateIps.add('$primaryPrefix.$octet');
      }
      for (var octet = 161; octet <= 254; octet++) {
        candidateIps.add('$primaryPrefix.$octet');
      }
    }

    final cleanCandidates = candidateIps
        .where(
          (ip) =>
              isValidIp(ip) &&
              !selfIps.contains(ip) &&
              !discoveredMap.containsKey(ip),
        )
        .toSet()
        .toList();

    // Stage 5A: Fast ARP-warmup across common DHCP octets
    final warmupSlice = cleanCandidates.take(125).toList();
    const warmupBatchSize = 28;
    for (var i = 0; i < warmupSlice.length; i += warmupBatchSize) {
      final end = (i + warmupBatchSize < warmupSlice.length)
          ? i + warmupBatchSize
          : warmupSlice.length;
      final batch = warmupSlice.sublist(i, end);
      await Future.wait(
        batch.map(
          (ip) => pingTv(
            ip,
            port: 5555,
            timeout: const Duration(milliseconds: 200),
          ),
        ),
      );
    }

    if (warmupSlice.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 110));
    }

    // Stage 5B: Probe all candidate IPs across the entire /24 subnet for Android TV & Non-Android Smart TV ports
    const probeBatchSize = 28;
    for (var i = 0; i < cleanCandidates.length; i += probeBatchSize) {
      final end = (i + probeBatchSize < cleanCandidates.length)
          ? i + probeBatchSize
          : cleanCandidates.length;
      final batch = cleanCandidates.sublist(i, end);
      final isPriorityBatch = i < 125;
      final adbTimeout = Duration(milliseconds: isPriorityBatch ? 520 : 320);
      final otherTimeout = Duration(milliseconds: isPriorityBatch ? 320 : 210);

      final results = await Future.wait(
        batch.map((candidateIp) async {
          final portChecks = await Future.wait<bool>(<Future<bool>>[
            pingTv(candidateIp, port: 5555, timeout: adbTimeout),
            pingTv(candidateIp, port: 6466, timeout: otherTimeout),
            pingTv(candidateIp, port: 8085, timeout: otherTimeout),
            pingTv(candidateIp, port: 56789, timeout: otherTimeout),
            pingTv(candidateIp, port: 8001, timeout: otherTimeout),
            pingTv(candidateIp, port: 3000, timeout: otherTimeout),
            pingTv(candidateIp, port: 8008, timeout: otherTimeout),
          ]);
          final adbOk = portChecks[0];
          final remotePortOk = portChecks[1];
          int openSmartPort = 0;
          if (portChecks[2]) {
            openSmartPort = 8085;
          } else if (portChecks[3]) {
            openSmartPort = 56789;
          } else if (portChecks[4]) {
            openSmartPort = 8001;
          } else if (portChecks[5]) {
            openSmartPort = 3000;
          }
          final castPortOk = portChecks[6];
          final hasMulticastHint = multicastHints.containsKey(candidateIp);

          if (!adbOk &&
              !remotePortOk &&
              openSmartPort == 0 &&
              !castPortOk &&
              !hasMulticastHint) {
            return null;
          }
          if (openSmartPort == 0 && (castPortOk || hasMulticastHint)) {
            openSmartPort = await _probeOpenSmartTvPort(
              candidateIp,
              timeout: const Duration(milliseconds: 240),
            );
          }
          return buildDiscoveredTvDevice(
            ip: candidateIp,
            is5555: adbOk,
            is6466: remotePortOk,
            smartTvPort: openSmartPort,
            is8008: castPortOk,
          );
        }),
      );
      for (final item in results) {
        if (item != null) {
          discoveredMap[item.ip] = item;
        }
      }
    }

    final list = discoveredMap.values.toList();
    list.sort((a, b) {
      if (a.isOnline != b.isOnline) {
        return a.isOnline ? -1 : 1;
      }
      if (hasValidPreferred) {
        if (a.ip == cleanPreferred) return -1;
        if (b.ip == cleanPreferred) return 1;
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }

  /// Probes all supported Non-Android Smart TV ports (`8085` Arçelik/Beko/Grundig,
  /// `56789` Vestel/Arçelik/Regal/Toshiba, `8001` Samsung Tizen, `3000` LG webOS,
  /// `1925` Philips JointSpace, `8060` Roku/ECP) in parallel and returns the first open port.
  Future<int> _probeOpenSmartTvPort(
    String ip, {
    Duration timeout = const Duration(milliseconds: 300),
  }) async {
    const ports = <int>[8085, 56789, 8001, 3000, 1925, 8060];
    final checks = await Future.wait<bool>(
      ports.map((p) => pingTv(ip, port: p, timeout: timeout)),
    );
    for (var i = 0; i < ports.length; i++) {
      if (checks[i]) return ports[i];
    }
    return 0;
  }

  /// Maps [TvKeyCommand] to Arçelik / Beko / Grundig Smart Inter@ctive TV Port 8085
  /// `/sendrcpackage?keyid=<id>&keysymbol=<sym>` query parameters.
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

  /// Maps [TvKeyCommand] to Vestel / Arçelik / Regal / Toshiba / JVC Smart Center
  /// Port 56789 XML payload (`<remote><key code=XXXX/></remote>`).
  static String vestelXmlForCommand(TvKeyCommand command) {
    int code;
    switch (command) {
      case TvKeyCommand.up:
        code = 1030;
        break;
      case TvKeyCommand.down:
        code = 1031;
        break;
      case TvKeyCommand.left:
        code = 1032;
        break;
      case TvKeyCommand.right:
        code = 1033;
        break;
      case TvKeyCommand.ok:
        code = 1029;
        break;
      case TvKeyCommand.back:
        code = 1010;
        break;
      case TvKeyCommand.home:
        code = 1044;
        break;
      case TvKeyCommand.menu:
        code = 1018;
        break;
      case TvKeyCommand.inputs:
        code = 1023;
        break;
      case TvKeyCommand.volUp:
        code = 1014;
        break;
      case TvKeyCommand.volDown:
        code = 1015;
        break;
      case TvKeyCommand.mute:
        code = 1013;
        break;
      case TvKeyCommand.power:
        code = 1024;
        break;
      case TvKeyCommand.playPause:
        code = 1025;
        break;
      case TvKeyCommand.rewind:
        code = 1027;
        break;
      case TvKeyCommand.fastForward:
        code = 1028;
        break;
      case TvKeyCommand.channelUp:
        code = 1016;
        break;
      case TvKeyCommand.channelDown:
        code = 1017;
        break;
      case TvKeyCommand.voiceAssist:
        code = 1044;
        break;
      case TvKeyCommand.search:
        code = 1067;
        break;
    }
    return '<remote><key code=$code/></remote>';
  }

  /// Maps [TvKeyCommand] to Samsung Tizen Smart TV WebSocket key identifiers.
  static String samsungKeyForCommand(TvKeyCommand command) {
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

  Future<bool> _sendArcelikGrundig8085Key(
    String ip,
    TvKeyCommand command,
  ) async {
    final query = arcelikGrundigQueryForCommand(command);
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 550);
    try {
      final uri = Uri.parse('http://$ip:8085/sendrcpackage?$query');
      final req = await client
          .getUrl(uri)
          .timeout(const Duration(milliseconds: 600));
      final resp = await req.close().timeout(
        const Duration(milliseconds: 600),
      );
      await resp.drain<void>();
      if (resp.statusCode >= 200 && resp.statusCode < 400) {
        return true;
      }
    } catch (_) {
    } finally {
      client.close(force: true);
    }
    // Fallback: some Arçelik/Beko/Grundig 43" sets use Vestel SmartCenter on 56789
    return _sendVestel56789Key(ip, command, allowFallbackTo8085: false);
  }

  Future<bool> _sendVestel56789Key(
    String ip,
    TvKeyCommand command, {
    bool allowFallbackTo8085 = true,
  }) async {
    final xmlPayload = vestelXmlForCommand(command);
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 550);
    try {
      final uri = Uri.parse('http://$ip:56789/apps/SmartCenter');
      final req = await client
          .postUrl(uri)
          .timeout(const Duration(milliseconds: 600));
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'text/xml; charset=utf-8',
      );
      final bytes = utf8.encode(xmlPayload);
      req.contentLength = bytes.length;
      req.add(bytes);
      final resp = await req.close().timeout(
        const Duration(milliseconds: 600),
      );
      await resp.drain<void>();
      if (resp.statusCode >= 200 && resp.statusCode < 400) {
        return true;
      }
    } catch (_) {
    } finally {
      client.close(force: true);
    }
    if (allowFallbackTo8085) {
      final query = arcelikGrundigQueryForCommand(command);
      final fallbackClient = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 500);
      try {
        final req = await fallbackClient
            .getUrl(Uri.parse('http://$ip:8085/sendrcpackage?$query'))
            .timeout(const Duration(milliseconds: 550));
        final resp = await req.close().timeout(
          const Duration(milliseconds: 550),
        );
        await resp.drain<void>();
        return resp.statusCode >= 200 && resp.statusCode < 400;
      } catch (_) {
      } finally {
        fallbackClient.close(force: true);
      }
    }
    return false;
  }

  Future<bool> _sendSamsungTizenKey(String ip, TvKeyCommand command) async {
    final keyName = samsungKeyForCommand(command);
    final payload = jsonEncode(<String, Object?>{
      'method': 'ms.remote.control',
      'params': <String, Object?>{
        'Cmd': 'Click',
        'DataOfCmd': keyName,
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    });

    // Try Port 8001 WS first, then Port 8002 WSS (self-signed TLS)
    for (final useTls in <bool>[false, true]) {
      WebSocket? ws;
      try {
        final url = useTls
            ? 'wss://$ip:8002/api/v2/channels/samsung.remote.control?name=Q3VlRGVjaw=='
            : 'ws://$ip:8001/api/v2/channels/samsung.remote.control?name=Q3VlRGVjaw==';
        final customClient = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 700)
          ..badCertificateCallback = (_, _, _) => true;
        ws = await WebSocket.connect(
          url,
          customClient: customClient,
        ).timeout(const Duration(milliseconds: 850));
        ws.add(payload);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await ws.close();
        return true;
      } catch (_) {
        try {
          await ws?.close();
        } catch (_) {}
      }
    }
    return false;
  }

  Future<bool> _sendLgWebOsKey(String ip, TvKeyCommand command) async {
    String? ssapUri;
    switch (command) {
      case TvKeyCommand.volUp:
        ssapUri = 'ssap://audio/volumeUp';
        break;
      case TvKeyCommand.volDown:
        ssapUri = 'ssap://audio/volumeDown';
        break;
      case TvKeyCommand.mute:
        ssapUri = 'ssap://audio/setMute';
        break;
      case TvKeyCommand.power:
        ssapUri = 'ssap://system/turnOff';
        break;
      case TvKeyCommand.channelUp:
        ssapUri = 'ssap://tv/channelUp';
        break;
      case TvKeyCommand.channelDown:
        ssapUri = 'ssap://tv/channelDown';
        break;
      case TvKeyCommand.playPause:
        ssapUri = 'ssap://media.controls/play';
        break;
      case TvKeyCommand.rewind:
        ssapUri = 'ssap://media.controls/rewind';
        break;
      case TvKeyCommand.fastForward:
        ssapUri = 'ssap://media.controls/fastForward';
        break;
      default:
        ssapUri = 'ssap://com.webos.service.ime/sendEnterKey';
    }

    WebSocket? ws;
    try {
      final customClient = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 750)
        ..badCertificateCallback = (_, _, _) => true;
      ws = await WebSocket.connect(
        'ws://$ip:3000',
        customClient: customClient,
      ).timeout(const Duration(milliseconds: 900));
      ws.add(
        jsonEncode(<String, Object?>{
          'id': 'reg_1',
          'type': 'register',
          'payload': <String, Object?>{'pairingType': 'PROMPT'},
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 70));
      ws.add(
        jsonEncode(<String, Object?>{
          'id': 'cmd_1',
          'type': 'request',
          'uri': ssapUri,
          if (command == TvKeyCommand.mute)
            'payload': const <String, Object?>{'mute': true},
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await ws.close();
      return true;
    } catch (_) {
      try {
        await ws?.close();
      } catch (_) {}
      return false;
    }
  }

  Future<bool> _sendPhilipsJointSpaceKey(
    String ip,
    TvKeyCommand command,
  ) async {
    String key;
    switch (command) {
      case TvKeyCommand.up:
        key = 'CursorUp';
        break;
      case TvKeyCommand.down:
        key = 'CursorDown';
        break;
      case TvKeyCommand.left:
        key = 'CursorLeft';
        break;
      case TvKeyCommand.right:
        key = 'CursorRight';
        break;
      case TvKeyCommand.ok:
        key = 'Confirm';
        break;
      case TvKeyCommand.back:
        key = 'Back';
        break;
      case TvKeyCommand.home:
        key = 'Home';
        break;
      case TvKeyCommand.menu:
        key = 'Options';
        break;
      case TvKeyCommand.inputs:
        key = 'Source';
        break;
      case TvKeyCommand.volUp:
        key = 'VolumeUp';
        break;
      case TvKeyCommand.volDown:
        key = 'VolumeDown';
        break;
      case TvKeyCommand.mute:
        key = 'Mute';
        break;
      case TvKeyCommand.power:
        key = 'Standby';
        break;
      case TvKeyCommand.playPause:
        key = 'PlayPause';
        break;
      case TvKeyCommand.rewind:
        key = 'Rewind';
        break;
      case TvKeyCommand.fastForward:
        key = 'FastForward';
        break;
      case TvKeyCommand.channelUp:
        key = 'ChannelStepUp';
        break;
      case TvKeyCommand.channelDown:
        key = 'ChannelStepDown';
        break;
      case TvKeyCommand.voiceAssist:
      case TvKeyCommand.search:
        key = 'Find';
        break;
    }

    final bodyBytes = utf8.encode(jsonEncode(<String, String>{'key': key}));
    for (final path in <String>['/1/input/key', '/6/input/key']) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 500);
      try {
        final req = await client
            .postUrl(Uri.parse('http://$ip:1925$path'))
            .timeout(const Duration(milliseconds: 550));
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.contentLength = bodyBytes.length;
        req.add(bodyBytes);
        final resp = await req.close().timeout(
          const Duration(milliseconds: 550),
        );
        await resp.drain<void>();
        if (resp.statusCode >= 200 && resp.statusCode < 400) {
          return true;
        }
      } catch (_) {
      } finally {
        client.close(force: true);
      }
    }
    return false;
  }

  Future<bool> _sendRokuEcpKey(String ip, TvKeyCommand command) async {
    String key;
    switch (command) {
      case TvKeyCommand.up:
        key = 'Up';
        break;
      case TvKeyCommand.down:
        key = 'Down';
        break;
      case TvKeyCommand.left:
        key = 'Left';
        break;
      case TvKeyCommand.right:
        key = 'Right';
        break;
      case TvKeyCommand.ok:
        key = 'Select';
        break;
      case TvKeyCommand.back:
        key = 'Back';
        break;
      case TvKeyCommand.home:
        key = 'Home';
        break;
      case TvKeyCommand.menu:
        key = 'Info';
        break;
      case TvKeyCommand.inputs:
        key = 'InputTuner';
        break;
      case TvKeyCommand.volUp:
        key = 'VolumeUp';
        break;
      case TvKeyCommand.volDown:
        key = 'VolumeDown';
        break;
      case TvKeyCommand.mute:
        key = 'VolumeMute';
        break;
      case TvKeyCommand.power:
        key = 'Power';
        break;
      case TvKeyCommand.playPause:
        key = 'Play';
        break;
      case TvKeyCommand.rewind:
        key = 'Rev';
        break;
      case TvKeyCommand.fastForward:
        key = 'Fwd';
        break;
      case TvKeyCommand.channelUp:
        key = 'ChannelUp';
        break;
      case TvKeyCommand.channelDown:
        key = 'ChannelDown';
        break;
      case TvKeyCommand.voiceAssist:
      case TvKeyCommand.search:
        key = 'Search';
        break;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 500);
    try {
      final req = await client
          .postUrl(Uri.parse('http://$ip:8060/keypress/$key'))
          .timeout(const Duration(milliseconds: 550));
      req.contentLength = 0;
      final resp = await req.close().timeout(
        const Duration(milliseconds: 550),
      );
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Launches streaming apps & YouTube playlists on Non-Android Smart TVs
  /// (Arçelik, Beko, Grundig, Vestel, Samsung Tizen, LG webOS, Roku) using
  /// DIAL (`POST /apps/YouTube`, `/apps/Netflix`), Vestel keycodes (`1067`/`1059`),
  /// Samsung REST (`/api/v2/applications/...`), and LG SSAP (`ssap://system.launcher/launch`).
  Future<bool> _launchSmartTvAppOrDial(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async {
    final ip = device.ip.trim();
    if (!isValidIp(ip)) return false;

    // 1. Vestel / Arçelik Smart Center (Port 56789) dedicated app keycodes
    if (device.protocol == TvConnectionProtocol.vestelSmart56789 ||
        device.port == 56789) {
      if (platform == StreamingPlatform.youtube && deepLinkUrl.trim().isEmpty) {
        final ok = await _sendVestelRawKeyCode(ip, 1067);
        if (ok) return true;
      } else if (platform == StreamingPlatform.netflix) {
        final ok = await _sendVestelRawKeyCode(ip, 1059);
        if (ok) return true;
      }
    }

    // 2. Samsung Tizen REST App Launch (/api/v2/applications/<appId>)
    if (device.protocol == TvConnectionProtocol.samsungTizen8001 ||
        device.port == 8001 ||
        device.port == 8002) {
      String? samsungAppId;
      switch (platform) {
        case StreamingPlatform.youtube:
          samsungAppId = '111299001912';
          break;
        case StreamingPlatform.netflix:
          samsungAppId = '3201907018807';
          break;
        case StreamingPlatform.primeVideo:
          samsungAppId = '3201910019365';
          break;
        case StreamingPlatform.disneyPlus:
          samsungAppId = '3201901017640';
          break;
        case StreamingPlatform.spotify:
          samsungAppId = '3201606009684';
          break;
        default:
          samsungAppId = null;
      }
      if (samsungAppId != null) {
        final client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 600);
        try {
          final req = await client
              .postUrl(
                Uri.parse('http://$ip:8001/api/v2/applications/$samsungAppId'),
              )
              .timeout(const Duration(milliseconds: 650));
          req.contentLength = 0;
          final resp = await req.close().timeout(
            const Duration(milliseconds: 650),
          );
          await resp.drain<void>();
          if (resp.statusCode >= 200 && resp.statusCode < 400) return true;
        } catch (_) {
        } finally {
          client.close(force: true);
        }
      }
    }

    // 3. Universal DIAL Protocol (YouTube / Netflix) across Smart TV ports (56789, 8085, 8008, 8060)
    String? dialAppName;
    String dialPayload = '';
    if (platform == StreamingPlatform.youtube) {
      dialAppName = 'YouTube';
      final normalized = WatchCueItem.normalizeContentLink(
        platform,
        deepLinkUrl,
      );
      if (normalized.isNotEmpty) {
        final uri = Uri.tryParse(normalized);
        final v = uri?.queryParameters['v'] ?? '';
        final list = uri?.queryParameters['list'] ?? '';
        if (v.isNotEmpty && list.isNotEmpty) {
          dialPayload = 'v=$v&list=$list';
        } else if (list.isNotEmpty) {
          dialPayload = 'list=$list';
        } else if (v.isNotEmpty) {
          dialPayload = 'v=$v';
        }
      } else if (fallbackSearchQuery.trim().isNotEmpty) {
        dialPayload =
            'vq=${Uri.encodeQueryComponent(fallbackSearchQuery.trim())}';
      }
    } else if (platform == StreamingPlatform.netflix) {
      dialAppName = 'Netflix';
    }

    if (dialAppName != null) {
      final dialPorts = <int>{
        device.port,
        56789,
        8085,
        8008,
        8060,
      };
      for (final dPort in dialPorts) {
        if (dPort <= 0) continue;
        final client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 500);
        try {
          final req = await client
              .postUrl(Uri.parse('http://$ip:$dPort/apps/$dialAppName'))
              .timeout(const Duration(milliseconds: 550));
          req.headers.set(
            HttpHeaders.contentTypeHeader,
            'text/plain; charset=utf-8',
          );
          final bodyBytes = utf8.encode(dialPayload);
          req.contentLength = bodyBytes.length;
          if (bodyBytes.isNotEmpty) req.add(bodyBytes);
          final resp = await req.close().timeout(
            const Duration(milliseconds: 550),
          );
          await resp.drain<void>();
          if (resp.statusCode >= 200 && resp.statusCode < 400) {
            return true;
          }
        } catch (_) {
        } finally {
          client.close(force: true);
        }
      }
    }

    return false;
  }

  Future<bool> _sendVestelRawKeyCode(String ip, int keyCode) async {
    final xmlPayload = '<remote><key code=$keyCode/></remote>';
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 500);
    try {
      final req = await client
          .postUrl(Uri.parse('http://$ip:56789/apps/SmartCenter'))
          .timeout(const Duration(milliseconds: 550));
      req.headers.set(HttpHeaders.contentTypeHeader, 'text/xml; charset=utf-8');
      final bytes = utf8.encode(xmlPayload);
      req.contentLength = bytes.length;
      req.add(bytes);
      final resp = await req.close().timeout(
        const Duration(milliseconds: 550),
      );
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
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

  /// Sends a remote control key command to the target TV via:
  /// - Arçelik / Beko / Grundig Smart TV (`Port 8085` `/sendrcpackage`)
  /// - Vestel / Arçelik / Regal / Toshiba Smart Center (`Port 56789` XML)
  /// - Samsung Tizen Smart TV (`Port 8001/8002` WebSocket)
  /// - LG webOS Smart TV (`Port 3000/3001` SSAP WebSocket)
  /// - Philips JointSpace (`Port 1925` REST) & Roku ECP (`Port 8060`)
  /// - Android TV / Google TV Port 5555 (ADB Turbo) & Port 6466 (Remote v2 TLS).
  Future<bool> sendKeyCommand(TvDevice device, TvKeyCommand command) async {
    final code = command.keyCode;
    if (code < 1 || code > 300) return false;
    final ip = device.ip.trim();

    switch (device.protocol) {
      case TvConnectionProtocol.arcelikGrundig8085:
        return _sendArcelikGrundig8085Key(ip, command);
      case TvConnectionProtocol.vestelSmart56789:
        return _sendVestel56789Key(ip, command);
      case TvConnectionProtocol.samsungTizen8001:
        return _sendSamsungTizenKey(ip, command);
      case TvConnectionProtocol.lgWebOs3000:
        return _sendLgWebOsKey(ip, command);
      case TvConnectionProtocol.philipsJointSpace1925:
        return _sendPhilipsJointSpaceKey(ip, command);
      case TvConnectionProtocol.rokuEcp8060:
        return _sendRokuEcpKey(ip, command);
      case TvConnectionProtocol.remotePort6466:
        final remoteOk = await _sendRemote6466KeyFrame(device, code);
        if (remoteOk) return true;
        break;
      case TvConnectionProtocol.adbPort5555:
        if (device.port == 8085) {
          return _sendArcelikGrundig8085Key(ip, command);
        }
        if (device.port == 56789) {
          return _sendVestel56789Key(ip, command);
        }
        break;
    }

    if (device.port == 6466) {
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
    final remote6466Ok = await _sendRemote6466KeyFrame(device, code);
    if (remote6466Ok) return true;

    // Automatic fallback for Arçelik / Vestel Smart TVs added by manual IP
    if (isValidIp(ip) && !Platform.environment.containsKey('FLUTTER_TEST')) {
      final arcelikOk = await _sendArcelikGrundig8085Key(ip, command);
      if (arcelikOk) return true;
    }
    return false;
  }

  /// Launches a streaming platform app or beams a specific deep-link / playlist URL to the TV.
  Future<bool> launchPlatformOrDeepLink(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async {
    if (device.protocol.isNonAndroidSmartTv ||
        device.port == 8085 ||
        device.port == 56789 ||
        device.port == 8001 ||
        device.port == 3000 ||
        device.port == 1925 ||
        device.port == 8060 ||
        device.port == 8008) {
      final smartOk = await _launchSmartTvAppOrDial(
        device,
        platform: platform,
        deepLinkUrl: deepLinkUrl,
        fallbackSearchQuery: fallbackSearchQuery,
      );
      if (smartOk) return true;
      if (device.protocol.isNonAndroidSmartTv) return false;
    }

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
        final adbOk = await _executeShellCommand(
          device,
          "am start -a android.intent.action.VIEW -d '$normalizedUrl' $pkg || $fallbackLaunchCmd",
        );
        if (adbOk) return true;
        return _launchSmartTvAppOrDial(
          device,
          platform: platform,
          deepLinkUrl: deepLinkUrl,
          fallbackSearchQuery: fallbackSearchQuery,
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
        final adbOk = await _executeShellCommand(
          device,
          "am start -a android.intent.action.VIEW -d 'https://www.youtube.com/results?search_query=$encoded' $pkg",
        );
        if (adbOk) return true;
        return _launchSmartTvAppOrDial(
          device,
          platform: platform,
          deepLinkUrl: deepLinkUrl,
          fallbackSearchQuery: fallbackSearchQuery,
        );
      }
    }

    final adbOk = await _executeShellCommand(device, fallbackLaunchCmd);
    if (adbOk) return true;
    return _launchSmartTvAppOrDial(
      device,
      platform: platform,
      deepLinkUrl: deepLinkUrl,
      fallbackSearchQuery: fallbackSearchQuery,
    );
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

  /// Opens the native Android/iOS speech recognizer on the phone and returns the
  /// spoken transcript string (or `null` if canceled/unavailable).
  Future<String?> listenPhoneMicrophone({String locale = 'tr-TR'}) async {
    _voicePermissionDenied = false;
    try {
      final result = await _voiceChannel.invokeMethod<String>(
        'startVoiceRecognition',
        <String, dynamic>{'locale': locale},
      );
      final trimmed = result?.trim();
      if (trimmed == '__PERMISSION_DENIED__') {
        _voicePermissionDenied = true;
        return null;
      }
      if (trimmed == null || trimmed.isEmpty) return null;
      return trimmed;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        _voicePermissionDenied = true;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Finalizes an active speech recognition session on the phone and processes
  /// any partial words spoken so far.
  Future<void> stopPhoneMicrophone() async {
    try {
      await _voiceChannel.invokeMethod<void>('stopVoiceRecognition');
    } catch (_) {}
  }

  /// Cancels an active speech recognition session on the phone immediately.
  Future<void> cancelPhoneMicrophone() async {
    try {
      await _voiceChannel.invokeMethod<void>('cancelVoiceRecognition');
    } catch (_) {}
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

    if (matchesAny(<String>['prime video', 'amazon prime', 'prime aç'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.primeVideo,
      );
      return ok
          ? '🎙️ TV\'de Prime Video açıldı'
          : '⚡ Prime Video başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['disney'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.disneyPlus,
      );
      return ok
          ? '🎙️ TV\'de Disney+ açıldı'
          : '⚡ Disney+ başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['exxen'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.exxen,
      );
      return ok
          ? '🎙️ TV\'de Exxen açıldı'
          : '⚡ Exxen başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['blutv', 'blu tv', 'max aç', 'hbo'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.blutv,
      );
      return ok
          ? '🎙️ TV\'de Max / BluTV açıldı'
          : '⚡ Max / BluTV başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['s sport', 'ssport'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.ssportPlus,
      );
      return ok
          ? '🎙️ TV\'de S Sport+ açıldı'
          : '⚡ S Sport+ başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['tod tv', 'tod aç'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.todTv,
      );
      return ok
          ? '🎙️ TV\'de TOD TV açıldı'
          : '⚡ TOD TV başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['spotify'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.spotify,
      );
      return ok
          ? '🎙️ TV\'de Spotify açıldı'
          : '⚡ Spotify başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['twitch'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.twitch,
      );
      return ok
          ? '🎙️ TV\'de Twitch açıldı'
          : '⚡ Twitch başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['kodi', 'iptv'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.kodi,
      );
      return ok
          ? '🎙️ TV\'de Kodi / IPTV açıldı'
          : '⚡ Kodi / IPTV başlatma sinyali gönderildi';
    }

    if (matchesAny(<String>['vlc'])) {
      final ok = await launchPlatformOrDeepLink(
        device,
        platform: StreamingPlatform.vlc,
      );
      return ok
          ? '🎙️ TV\'de VLC Player açıldı'
          : '⚡ VLC Player başlatma sinyali gönderildi';
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
    final cleanIp = device.ip.trim();
    if (!isValidIp(cleanIp)) return null;

    final alreadyAuthenticatedDartSocket =
        _socket != null && _handshakeDone && _connectedIp == cleanIp;

    if (Platform.isIOS &&
        !Platform.environment.containsKey('FLUTTER_TEST') &&
        !allowInteractivePairing &&
        !alreadyAuthenticatedDartSocket &&
        !_ipsRequiringRsaAuth.contains(cleanIp)) {
      try {
        final nativeRes = await _networkChannel
            .invokeMethod<Map<Object?, Object?>>(
              'nativeAdbShell',
              <String, Object?>{
                'ip': cleanIp,
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
          if (nativeRes['requiresRsaAuth'] == true) {
            _ipsRequiringRsaAuth.add(cleanIp);
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
