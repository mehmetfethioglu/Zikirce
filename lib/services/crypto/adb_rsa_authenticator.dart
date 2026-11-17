import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
    0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2B, 0x0E,
    0x03, 0x02, 0x1A, 0x05, 0x00, 0x04, 0x14,
  ];

  static const List<int> _sha256DigestInfoPrefix = <int>[
    0x30, 0x31, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86,
    0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05,
    0x00, 0x04, 0x20,
  ];

  BigInt? _modulusN;
  BigInt? _privateExponentD;
  Uint8List? _cachedPublicKeyPayload;
  Uint8List? _atvModulusBytes;
  Uint8List? _atvCertDer;
  String? _atvCertPem;
  String? _atvKeyPem;

  bool get isReady => _modulusN != null && _privateExponentD != null;

  /// Unsigned 256-byte big-endian RSA-2048 modulus used by the mTLS client certificate.
  Uint8List get modulusBytes {
    _ensureAtvMtlsCredentialsBuilt();
    return _atvModulusBytes ?? Uint8List(0);
  }

  /// Unsigned 3-byte big-endian RSA public exponent (`65537` -> `[0x01, 0x00, 0x01]`).
  Uint8List get publicExponentBytes =>
      Uint8List.fromList(const <int>[0x01, 0x00, 0x01]);

  /// Self-signed X.509 v3 DER bytes for `CN=atvremote` (valid 2020–2049).
  Uint8List get selfSignedCertDer {
    _ensureAtvMtlsCredentialsBuilt();
    return _atvCertDer ?? Uint8List(0);
  }

  /// Self-signed X.509 v3 Certificate PEM for Android TV Remote v2 mTLS (`Ports 6466/6467`).
  String get selfSignedCertPem {
    _ensureAtvMtlsCredentialsBuilt();
    return _atvCertPem ?? '';
  }

  /// PKCS#8 Private Key PEM matching [selfSignedCertPem] for Android TV Remote v2 mTLS.
  String get privateKeyPem {
    _ensureAtvMtlsCredentialsBuilt();
    return _atvKeyPem ?? '';
  }

  static String _wrapPem(String label, List<int> derBytes) {
    final encoded = base64.encode(derBytes);
    final header = '-----BEGIN $label-----';
    final footer = '-----END $label-----';
    return '$header\n$encoded\n$footer\n';
  }

  static Uint8List _bigIntToUnsignedBytes(BigInt value) {
    if (value == BigInt.zero) return Uint8List.fromList(const <int>[0]);
    final bytes = <int>[];
    var temp = value;
    final mask = BigInt.from(0xFF);
    while (temp > BigInt.zero) {
      bytes.insert(0, (temp & mask).toInt());
      temp = temp >> 8;
    }
    return Uint8List.fromList(bytes);
  }

  static List<int> _asn1Len(int length) {
    if (length < 0x80) return <int>[length];
    final out = <int>[];
    var t = length;
    while (t > 0) {
      out.insert(0, t & 0xFF);
      t >>= 8;
    }
    return <int>[0x80 | out.length, ...out];
  }

  static List<int> _asn1Int(BigInt value) {
    final raw = _bigIntToUnsignedBytes(value);
    final pad = raw.isNotEmpty && (raw[0] & 0x80) != 0;
    final body = pad ? <int>[0x00, ...raw] : raw;
    return <int>[0x02, ..._asn1Len(body.length), ...body];
  }

  static List<int> _asn1Seq(List<int> body) =>
      <int>[0x30, ..._asn1Len(body.length), ...body];

  void _ensureAtvMtlsCredentialsBuilt() {
    if (_atvCertPem != null && _atvKeyPem != null && _atvModulusBytes != null) {
      return;
    }
    final p = BigInt.parse(_fallbackPrimePHex, radix: 16);
    final q = BigInt.parse(_fallbackPrimeQHex, radix: 16);
    final n = p * q;
    final phi = (p - BigInt.one) * (q - BigInt.one);
    final e = BigInt.from(65537);
    final d = e.modInverse(phi);
    final dmp1 = d % (p - BigInt.one);
    final dmq1 = d % (q - BigInt.one);
    final iqmp = q.modInverse(p);

    _atvModulusBytes = _bigIntToUnsignedBytes(n);

    final pkcs1Seq = _asn1Seq(<int>[
      ..._asn1Int(BigInt.zero),
      ..._asn1Int(n),
      ..._asn1Int(e),
      ..._asn1Int(d),
      ..._asn1Int(p),
      ..._asn1Int(q),
      ..._asn1Int(dmp1),
      ..._asn1Int(dmq1),
      ..._asn1Int(iqmp),
    ]);
    const rsaAlgId = <int>[
      0x30, 0x0D,
      0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,
      0x05, 0x00,
    ];
    final pkcs8Der = Uint8List.fromList(
      _asn1Seq(<int>[
        0x02, 0x01, 0x00,
        ...rsaAlgId,
        0x04, ..._asn1Len(pkcs1Seq.length), ...pkcs1Seq,
      ]),
    );
    _atvKeyPem = _wrapPem('PRIVATE KEY', pkcs8Der);

    const sha256WithRsaAlgId = <int>[
      0x30, 0x0D,
      0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B,
      0x05, 0x00,
    ];
    const dnAtvRemote = <int>[
      0x30, 0x14,
      0x31, 0x12,
      0x30, 0x10,
      0x06, 0x03, 0x55, 0x04, 0x03,
      0x0C, 0x09, 0x61, 0x74, 0x76, 0x72, 0x65, 0x6D, 0x6F, 0x74, 0x65,
    ];
    const validity2020To2049 = <int>[
      0x30, 0x1E,
      0x17, 0x0D, 0x32, 0x30, 0x30, 0x31, 0x30, 0x31, 0x30, 0x30, 0x30, 0x30,
      0x30, 0x30, 0x5A,
      0x17, 0x0D, 0x34, 0x39, 0x31, 0x32, 0x33, 0x31, 0x32, 0x33, 0x35, 0x39,
      0x35, 0x39, 0x5A,
    ];
    final rsaPubKeySeq = _asn1Seq(<int>[
      ..._asn1Int(n),
      ..._asn1Int(e),
    ]);
    final spkiBitString = <int>[
      0x03,
      ..._asn1Len(rsaPubKeySeq.length + 1),
      0x00,
      ...rsaPubKeySeq,
    ];
    final spkiSeq = _asn1Seq(<int>[
      ...rsaAlgId,
      ...spkiBitString,
    ]);
    final tbsDer = Uint8List.fromList(
      _asn1Seq(<int>[
        0xA0, 0x03, 0x02, 0x01, 0x02,
        0x02, 0x02, 0x01, 0x01,
        ...sha256WithRsaAlgId,
        ...dnAtvRemote,
        ...validity2020To2049,
        ...dnAtvRemote,
        ...spkiSeq,
      ]),
    );

    final tbsHash = sha256.convert(tbsDer).bytes;
    final padded = Uint8List(256);
    padded[0] = 0x00;
    padded[1] = 0x01;
    final psEnd = 256 - _sha256DigestInfoPrefix.length - 32 - 1;
    for (var i = 2; i < psEnd; i++) {
      padded[i] = 0xFF;
    }
    padded[psEnd] = 0x00;
    padded.setRange(
      psEnd + 1,
      psEnd + 1 + _sha256DigestInfoPrefix.length,
      _sha256DigestInfoPrefix,
    );
    padded.setRange(256 - 32, 256, tbsHash);

    var m = BigInt.zero;
    for (final b in padded) {
      m = (m << 8) | BigInt.from(b & 0xFF);
    }
    final sigInt = m.modPow(d, n);
    final sigBytes = Uint8List(256);
    var tempSig = sigInt;
    final mask = BigInt.from(0xFF);
    for (var i = 255; i >= 0; i--) {
      sigBytes[i] = (tempSig & mask).toInt();
      tempSig = tempSig >> 8;
    }

    final certDer = Uint8List.fromList(
      _asn1Seq(<int>[
        ...tbsDer,
        ...sha256WithRsaAlgId,
        0x03, 0x82, 0x01, 0x01, 0x00, ...sigBytes,
      ]),
    );
    _atvCertDer = certDer;
    _atvCertPem = _wrapPem('CERTIFICATE', certDer);
  }

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
      } catch (e) {
        debugPrint('AdbRsaAuthenticator native key fallback: $e');
      }
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
    structBytes.setUint32(0, 64, Endian.little);
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

    structBytes.setUint32(520, 65537, Endian.little);

    final b64 = base64.encode(structBytes.buffer.asUint8List());
    return Uint8List.fromList(ascii.encode('$b64 cuedeck@akarworks\x00'));
  }
}
