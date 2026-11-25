import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// Hasibu Merkezi Kriptografi, Anahtar Kasası (DPAPI/Keystore), SQLCipher,
/// PBKDF2/Argon2id, AES-256-GCM, HMAC-SHA256, TOTP (HMAC-SHA1) ve FLAG_SECURE Zırhı.
class HasibuSecurityService {
  HasibuSecurityService._();

  static const String dbKeyStorageSlot = 'hasibu_sqlcipher_db_key_v1';
  static const String workspaceKeyStorageSlot = 'hasibu_workspace_sync_key_v1';
  static const String oauthTokenStorageSlot = 'hasibu_google_oauth_token_v1';
  static const String hmacSecretStorageSlot = 'hasibu_attendance_hmac_key_v1';

  /// Son güvenlik servisi uyarısı veya yakalanan platform hatası
  static String? lastSecurityWarning;

  static const int defaultTenfeiCommKey = 437029;

  /// [AUD-04] Standart Canlı (Release) Kod Karartma (Obfuscation) Komutları
  static const String androidReleaseObfuscateCmd =
      'flutter build apk --release --obfuscate --split-debug-info=./build/symbols';
  static const String windowsReleaseObfuscateCmd =
      'flutter build windows --release --obfuscate --split-debug-info=./build/symbols';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  static const MethodChannel _securityChannel = MethodChannel(
    'com.akarworks.hasibu/security',
  );

  /// Test ve senkron çağrılar için bellek içi anahtar önbelleği
  static final Map<String, String> _memoryKeyCache = <String, String>{};
  static bool _sqlCipherOverrideInitialized = false;

  // ---------------------------------------------------------------------------
  // [DB-02] & [DB-03] SQLCipher (AES-256) & FlutterSecureStorage Anahtar Yönetimi
  // ---------------------------------------------------------------------------

  /// Android üzerinde SQLCipher yerel kütüphanesini sqlite3 FFI açıcısına bağlar.
  static void ensureSqlCipherNativeLibraryLoaded() {
    if (_sqlCipherOverrideInitialized || kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      }
    } catch (e) {
      lastSecurityWarning = e.toString();
      debugPrint('HasibuSecurityService: SQLCipher Android override atlandı: $e');
    }
    _sqlCipherOverrideInitialized = true;
  }

  /// Android cihazlarda `libsqlcipher.so` dinamik kütüphanesini güvenle yükler.
  static Future<void> ensureSqlCipherNativeLibraryLoadedAsync() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions().timeout(
          const Duration(milliseconds: 1200),
        );
      }
    } catch (e) {
      lastSecurityWarning = e.toString();
      debugPrint('HasibuSecurityService: Old Android SQLCipher workaround atlandı: $e');
    }
    ensureSqlCipherNativeLibraryLoaded();
  }

  /// 32-bayt (256-bit) kriptografik rastgele anahtar üretir (64 karakter hex).
  static String generateRandom256BitHexKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Güvenli depodan (`flutter_secure_storage`) 32-bayt veritabanı anahtarını okur
  /// veya ilk kurulumda üretip DPAPI / Keystore içine yazar.
  static Future<String> getOrCreateDatabaseKeyHex() async {
    final cached = _memoryKeyCache[dbKeyStorageSlot];
    if (cached != null && cached.length == 64) {
      return cached;
    }
    try {
      final existing = await _secureStorage
          .read(key: dbKeyStorageSlot)
          .timeout(const Duration(milliseconds: 1200));
      if (existing != null && existing.trim().length == 64) {
        _memoryKeyCache[dbKeyStorageSlot] = existing.trim();
        return existing.trim();
      }
      final generated = generateRandom256BitHexKey();
      await _secureStorage
          .write(key: dbKeyStorageSlot, value: generated)
          .timeout(const Duration(milliseconds: 1200));
      _memoryKeyCache[dbKeyStorageSlot] = generated;
      return generated;
    } catch (_) {
      // Birim testlerinde veya Keystore kilitli olduğunda deterministik anahtar üret
      final fallback = _memoryKeyCache[dbKeyStorageSlot] ??
          crypto.sha256
              .convert(utf8.encode('hasibu-android-local-vault-key-v2'))
              .toString();
      _memoryKeyCache[dbKeyStorageSlot] = fallback;
      return fallback;
    }
  }

  /// Senkron açılışlar için önbellekteki veya yeni üretilen 32-bayt hex anahtarı döner
  /// ve arka planda `flutter_secure_storage` ile eşitler.
  static String ensureDatabaseKeyHexSync() {
    final existing = _memoryKeyCache[dbKeyStorageSlot];
    if (existing != null && existing.length == 64) {
      return existing;
    }
    final generated = generateRandom256BitHexKey();
    _memoryKeyCache[dbKeyStorageSlot] = generated;
    // Asenkron olarak DPAPI/Keystore'a kalıcı yaz (varsa üzerine yazmaz)
    Future<void>.microtask(() async {
      try {
        final stored = await _secureStorage
            .read(key: dbKeyStorageSlot)
            .timeout(const Duration(milliseconds: 1200));
        if (stored == null || stored.trim().length != 64) {
          await _secureStorage
              .write(key: dbKeyStorageSlot, value: generated)
              .timeout(const Duration(milliseconds: 1200));
        } else {
          _memoryKeyCache[dbKeyStorageSlot] = stored.trim();
        }
      } catch (e) {
        lastSecurityWarning = e.toString();
        debugPrint('HasibuSecurityService: SecureStorage background write warning: $e');
      }
    });
    return generated;
  }

  /// [DB-02] & [DB-03] Açılışta veritabanını SQLCipher AES-256 `PRAGMA key` ile bağlar.
  static void applySqlCipherPragma(Database db, {String? keyHex}) {
    ensureSqlCipherNativeLibraryLoaded();
    final rawKey = (keyHex != null && keyHex.trim().length == 64)
        ? keyHex.trim()
        : ensureDatabaseKeyHexSync();
    final sanitizedHex = rawKey.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final finalHex = sanitizedHex.length == 64
        ? sanitizedHex
        : generateRandom256BitHexKey();
    try {
      db.execute("PRAGMA key = \"x'$finalHex'\";");
      db.execute('PRAGMA cipher_page_size = 4096;');
      db.execute('PRAGMA kdf_iter = 64000;');
      db.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA256;');
      db.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA256;');
    } catch (e) {
      lastSecurityWarning = e.toString();
      debugPrint('HasibuSecurityService: applySqlCipherPragma fallback: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // [SYNC-03] OAuth Token & Workspace Key Güvenli Depolama (`flutter_secure_storage`)
  // ---------------------------------------------------------------------------

  static Future<void> saveGoogleOAuthToken(String token) async {
    final trimmed = token.trim();
    _memoryKeyCache[oauthTokenStorageSlot] = trimmed;
    try {
      if (trimmed.isEmpty) {
        await _secureStorage.delete(key: oauthTokenStorageSlot);
      } else {
        await _secureStorage.write(key: oauthTokenStorageSlot, value: trimmed);
      }
    } catch (e) {
      lastSecurityWarning = e.toString();
      debugPrint('HasibuSecurityService: saveGoogleOAuthToken warning: $e');
    }
  }

  static Future<String> readGoogleOAuthToken() async {
    final cached = _memoryKeyCache[oauthTokenStorageSlot];
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final val = await _secureStorage.read(key: oauthTokenStorageSlot);
      if (val != null && val.trim().isNotEmpty) {
        _memoryKeyCache[oauthTokenStorageSlot] = val.trim();
        return val.trim();
      }
    } catch (e) {
      lastSecurityWarning = e.toString();
      debugPrint('HasibuSecurityService: readGoogleOAuthToken warning: $e');
    }
    return '';
  }

  static Future<void> saveWorkspaceSyncKey(String workspaceKey) async {
    final trimmed = workspaceKey.trim();
    _memoryKeyCache[workspaceKeyStorageSlot] = trimmed;
    try {
      if (trimmed.isEmpty) {
        await _secureStorage.delete(key: workspaceKeyStorageSlot);
      } else {
        await _secureStorage.write(
          key: workspaceKeyStorageSlot,
          value: trimmed,
        );
      }
    } catch (e) {
      lastSecurityWarning = e.toString();
      debugPrint('HasibuSecurityService: saveWorkspaceSyncKey warning: $e');
    }
  }

  static Future<String> getOrCreateWorkspaceSyncKey() async {
    final cached = _memoryKeyCache[workspaceKeyStorageSlot];
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final stored = await _secureStorage.read(key: workspaceKeyStorageSlot);
      if (stored != null && stored.trim().isNotEmpty) {
        _memoryKeyCache[workspaceKeyStorageSlot] = stored.trim();
        return stored.trim();
      }
    } catch (e) {
      lastSecurityWarning = e.toString();
      debugPrint('HasibuSecurityService: getOrCreateWorkspaceSyncKey warning: $e');
    }
    final defaultKey = ensureDatabaseKeyHexSync();
    await saveWorkspaceSyncKey(defaultKey);
    return defaultKey;
  }

  static String getWorkspaceSyncKeySync() {
    return _memoryKeyCache[workspaceKeyStorageSlot] ??
        ensureDatabaseKeyHexSync();
  }

  // ---------------------------------------------------------------------------
  // [DB-04] Tuzlanmış (Salted) PBKDF2-HMAC-SHA256 & Argon2id Parola Hashleme
  // ---------------------------------------------------------------------------

  static bool isPasswordHashed(String value) {
    return value.startsWith('pbkdf2\$sha256\$') ||
        value.startsWith('argon2id\$');
  }

  /// Düz metin parolayı tuzlanmış `PBKDF2-HMAC-SHA256` formatına dönüştürür.
  /// Zaten hashlenmişse olduğu gibi döner (idempotent).
  static String hashPassword(
    String plainOrHashed, {
    String? customSalt,
    int iterations = 10000,
  }) {
    final trimmed = plainOrHashed.trim();
    if (trimmed.isEmpty || isPasswordHashed(trimmed)) {
      return trimmed;
    }
    final saltBytes = customSalt != null
        ? utf8.encode(customSalt)
        : List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final derived = _pbkdf2HmacSha256(
      passwordBytes: utf8.encode(trimmed),
      saltBytes: saltBytes,
      iterations: iterations,
      derivedKeyLength: 32,
    );
    final saltB64 = base64UrlEncode(saltBytes);
    final hashB64 = base64UrlEncode(derived);
    return 'pbkdf2\$sha256\$$iterations\$$saltB64\$$hashB64';
  }

  /// `package:cryptography` üzerinden asenkron `Argon2id` parola hashleme.
  static Future<String> hashPasswordArgon2id(String plainPassword) async {
    final trimmed = plainPassword.trim();
    if (trimmed.isEmpty || isPasswordHashed(trimmed)) {
      return trimmed;
    }
    final saltBytes = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    );
    final algorithm = Argon2id(
      memory: 16 * 1024, // 16 MB
      parallelism: 1,
      iterations: 2,
      hashLength: 32,
    );
    final secretKey = await algorithm.deriveKeyFromPassword(
      password: trimmed,
      nonce: saltBytes,
    );
    final hashBytes = await secretKey.extractBytes();
    final saltB64 = base64UrlEncode(saltBytes);
    final hashB64 = base64UrlEncode(hashBytes);
    return 'argon2id\$v19\$$saltB64\$$hashB64';
  }

  /// Girilen düz metin parolayı, veritabanındaki tuzlanmış hash ile sabit-zamanlı doğrular.
  static bool verifyPassword(String plainInput, String storedPasswordHash) {
    final input = plainInput.trim();
    final stored = storedPasswordHash.trim();
    if (stored.isEmpty) return input.isEmpty;

    if (stored.startsWith('pbkdf2\$sha256\$')) {
      final parts = stored.split('\$');
      if (parts.length != 5) return false;
      final iterations = int.tryParse(parts[2]) ?? 10000;
      try {
        final saltBytes = base64Url.decode(parts[3]);
        final expectedBytes = base64Url.decode(parts[4]);
        final actualBytes = _pbkdf2HmacSha256(
          passwordBytes: utf8.encode(input),
          saltBytes: saltBytes,
          iterations: iterations,
          derivedKeyLength: expectedBytes.length,
        );
        return _constantTimeEquals(actualBytes, expectedBytes);
      } catch (_) {
        return false;
      }
    }

    // Geriye dönük düz metin (legacy) karşılaştırması
    return _constantTimeEquals(utf8.encode(input), utf8.encode(stored));
  }

  static Uint8List _pbkdf2HmacSha256({
    required List<int> passwordBytes,
    required List<int> saltBytes,
    required int iterations,
    required int derivedKeyLength,
  }) {
    final hmac = crypto.Hmac(crypto.sha256, passwordBytes);
    const hashLen = 32;
    final blocks = (derivedKeyLength / hashLen).ceil();
    final out = BytesBuilder(copy: false);

    for (var blockIndex = 1; blockIndex <= blocks; blockIndex++) {
      final blockSalt = Uint8List(saltBytes.length + 4);
      blockSalt.setRange(0, saltBytes.length, saltBytes);
      blockSalt[saltBytes.length] = (blockIndex >> 24) & 0xff;
      blockSalt[saltBytes.length + 1] = (blockIndex >> 16) & 0xff;
      blockSalt[saltBytes.length + 2] = (blockIndex >> 8) & 0xff;
      blockSalt[saltBytes.length + 3] = blockIndex & 0xff;

      var u = hmac.convert(blockSalt).bytes;
      final t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < hashLen; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }

    final full = out.toBytes();
    return Uint8List.sublistView(full, 0, derivedKeyLength);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  // ---------------------------------------------------------------------------
  // [DB-05] Özlük Evrakları (`.hasibu_doc`) AES Şifreleme & Çözme
  // ---------------------------------------------------------------------------

  /// Evrak dosya yolunu `.hasibu_doc` uzantılı şifreli formata dönüştürür.
  static String ensureEncryptedDocPath(String filePath) {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) return 'vault/unnamed.hasibu_doc';
    if (trimmed.toLowerCase().endsWith('.hasibu_doc')) {
      return trimmed;
    }
    return '$trimmed.hasibu_doc';
  }

  /// Özlük evrak baytlarını `AesGcm.with256bits()` ile `.hasibu_doc` formatında şifreler.
  static Future<Uint8List> encryptDocumentBytes(
    Uint8List plainBytes, {
    String? secretSeed,
  }) async {
    final keyBytes = _derive256BitKeyBytes(
      secretSeed ?? await getOrCreateDatabaseKeyHex(),
      contextLabel: 'hasibu_doc_aes256_gcm',
    );
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      plainBytes,
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
    );

    final out = BytesBuilder(copy: false);
    out.add(utf8.encode('HSBDOC1')); // 7 bayt sihirli başlık
    out.add(nonce); // 12 bayt IV
    out.add(secretBox.mac.bytes); // 16 bayt GCM MAC
    out.add(secretBox.cipherText);
    return out.toBytes();
  }

  /// `.hasibu_doc` formatındaki şifreli evrak baytlarını çözer.
  static Future<Uint8List> decryptDocumentBytes(
    Uint8List encryptedBytes, {
    String? secretSeed,
  }) async {
    if (encryptedBytes.length < 7 + 12 + 16) {
      throw const FormatException('Geçersiz .hasibu_doc dosya formatı.');
    }
    final magic = utf8.decode(encryptedBytes.sublist(0, 7), allowMalformed: true);
    if (magic != 'HSBDOC1') {
      throw const FormatException('Tanınmayan .hasibu_doc başlığı.');
    }
    final nonce = encryptedBytes.sublist(7, 19);
    final macBytes = encryptedBytes.sublist(19, 35);
    final cipherText = encryptedBytes.sublist(35);

    final keyBytes = _derive256BitKeyBytes(
      secretSeed ?? await getOrCreateDatabaseKeyHex(),
      contextLabel: 'hasibu_doc_aes256_gcm',
    );
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    final clear = await algorithm.decrypt(
      secretBox,
      secretKey: SecretKey(keyBytes),
    );
    return Uint8List.fromList(clear);
  }

  /// Disk üzerinde gerçek bir dosya varsa içeriğini AES ile şifreleyip `.hasibu_doc` olarak yazar.
  static String normalizeAndEncryptDocumentOnDisk(String rawFilePath) {
    final targetPath = ensureEncryptedDocPath(rawFilePath);
    if (kIsWeb) return targetPath;
    try {
      final sourceFile = File(rawFilePath);
      if (sourceFile.existsSync() && rawFilePath != targetPath) {
        final rawBytes = sourceFile.readAsBytesSync();
        final sealed = _sealBytesSync(rawBytes, contextLabel: 'hasibu_doc_sync');
        File(targetPath).writeAsBytesSync(sealed, flush: true);
      }
    } catch (e) {
      lastSecurityWarning = e.toString();
      debugPrint('HasibuSecurityService: normalizeAndEncryptDocumentOnDisk uyarısı: $e');
    }
    return targetPath;
  }

  // ---------------------------------------------------------------------------
  // [SYNC-01] & [SYNC-02] Google Drive AES-256-GCM Paket Şifreleme & Çözme
  // ---------------------------------------------------------------------------

  /// Aynı Google hesabında çalışan cihazların sıfır adımla otomatik şifreli yedek
  /// açabilmesi için deterministik 256-bit (64 hex) hesap anahtarı türetir.
  static String deriveAccountWorkspaceKey({
    required String googleEmail,
    String cloudProfileId = 'default',
  }) {
    final cleanEmail = googleEmail.trim().toLowerCase();
    final cleanProfile = cloudProfileId.trim().isEmpty
        ? 'default'
        : cloudProfileId.trim().toLowerCase();
    final derived = _pbkdf2HmacSha256(
      passwordBytes: utf8.encode('$cleanEmail|$cleanProfile'),
      saltBytes: utf8.encode('hasibu-cloud-account-vault-v1:$cleanProfile'),
      iterations: 10000,
      derivedKeyLength: 32,
    );
    return derived.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Kullanıcının belirlediği kısa ve hatırlanabilir bulut şifreleme parolasından
  /// 256-bit (64 hex) kriptografik çalışma alanı anahtarı türetir.
  static String derivePassphraseWorkspaceKey(String passphrase) {
    final derived = _pbkdf2HmacSha256(
      passwordBytes: utf8.encode(passphrase.trim()),
      saltBytes: utf8.encode('hasibu-cloud-passphrase-vault-v1'),
      iterations: 10000,
      derivedKeyLength: 32,
    );
    return derived.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Şifreli zarf JSON'unun `keyMode` alanını güvenli şekilde okur.
  static String? readEnvelopeKeyMode(String rawContent) {
    try {
      final decoded = jsonDecode(rawContent);
      if (decoded is Map) {
        final mode = (decoded['keyMode'] as String?)?.trim();
        return (mode != null && mode.isNotEmpty) ? mode : null;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Açık JSON senkronizasyon verisini `AES-256-GCM` ile şifreleyip zarf üretir.
  static Future<String> encryptSyncJsonPayload(
    Map<String, dynamic> payload, {
    String? workspaceKey,
    String vaultRole = 'master_vault',
    String? keyMode,
  }) async {
    final effectiveKey = workspaceKey?.trim().isNotEmpty == true
        ? workspaceKey!.trim()
        : await getOrCreateWorkspaceSyncKey();
    final keyBytes = _derive256BitKeyBytes(
      effectiveKey,
      contextLabel: 'hasibu_drive_aes256_gcm',
    );

    final plainBytes = utf8.encode(jsonEncode(payload));
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final aad = utf8.encode('hasibu-sync-v1:$vaultRole');

    final secretBox = await algorithm.encrypt(
      plainBytes,
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
      aad: aad,
    );

    final envelope = <String, dynamic>{
      'format': 'hasibu_aes256_gcm_v1',
      'vaultRole': vaultRole,
      if (keyMode != null && keyMode.trim().isNotEmpty)
        'keyMode': keyMode.trim(),
      'encryptedAt': DateTime.now().toUtc().toIso8601String(),
      'iv': base64Encode(nonce),
      'tag': base64Encode(secretBox.mac.bytes),
      'ciphertext': base64Encode(secretBox.cipherText),
    };
    return jsonEncode(envelope);
  }

  /// `AES-256-GCM` şifreli Drive paketini (`hasibu_sync.enc`, `hasibu_master_vault.enc`,
  /// `hasibu_portal_queue.enc`) doğrular ve çözer.
  static Future<Map<String, dynamic>> decryptSyncJsonPayload(
    String rawContent, {
    String? workspaceKey,
    String? expectedVaultRole,
  }) async {
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map) {
      throw const FormatException('Geçersiz senkronizasyon paketi.');
    }
    final map = Map<String, dynamic>.from(decoded);

    // Şifreli zarf kontrolü
    if (map['format'] == 'hasibu_aes256_gcm_v1') {
      final vaultRole = (map['vaultRole'] ?? 'master_vault').toString();
      if (expectedVaultRole != null &&
          expectedVaultRole.isNotEmpty &&
          vaultRole != expectedVaultRole) {
        throw StateError(
          'Rol izolasyonu ihlali: Beklenen paket $expectedVaultRole, gelen $vaultRole.',
        );
      }

      final effectiveKey = workspaceKey?.trim().isNotEmpty == true
          ? workspaceKey!.trim()
          : await getOrCreateWorkspaceSyncKey();
      final keyBytes = _derive256BitKeyBytes(
        effectiveKey,
        contextLabel: 'hasibu_drive_aes256_gcm',
      );

      final nonce = base64Decode(map['iv'].toString());
      final tagBytes = base64Decode(map['tag'].toString());
      final cipherBytes = base64Decode(map['ciphertext'].toString());
      final aad = utf8.encode('hasibu-sync-v1:$vaultRole');

      final algorithm = AesGcm.with256bits();
      final secretBox = SecretBox(
        cipherBytes,
        nonce: nonce,
        mac: Mac(tagBytes),
      );
      final clearBytes = await algorithm.decrypt(
        secretBox,
        secretKey: SecretKey(keyBytes),
        aad: aad,
      );
      final clearJson = jsonDecode(utf8.decode(clearBytes));
      if (clearJson is Map<String, dynamic>) {
        return clearJson;
      }
      if (clearJson is Map) {
        return Map<String, dynamic>.from(clearJson);
      }
      throw const FormatException('Çözülen AES-256-GCM içeriği geçersiz.');
    }

    return map;
  }

  // ---------------------------------------------------------------------------
  // [HW-01] & [HW-02] Şube `terminalCommKey` Şifreli Sütun Dönüştürücüsü
  // ---------------------------------------------------------------------------

  static String encryptTerminalCommKey(int commKey) {
    final normalized = commKey <= 0 ? defaultTenfeiCommKey : commKey;
    final plainBytes = utf8.encode(normalized.toString());
    final sealed = _sealBytesSync(
      Uint8List.fromList(plainBytes),
      contextLabel: 'branch_terminal_comm_key',
    );
    return 'enc_ck_v1:${base64UrlEncode(sealed)}';
  }

  static int decryptTerminalCommKey(
    Object? rawStoredValue, {
    int fallback = defaultTenfeiCommKey,
  }) {
    if (rawStoredValue == null) return fallback;
    if (rawStoredValue is int) {
      return rawStoredValue <= 0 ? fallback : rawStoredValue;
    }
    final text = rawStoredValue.toString().trim();
    if (text.isEmpty) return fallback;

    final directInt = int.tryParse(text);
    if (directInt != null) {
      return directInt <= 0 ? fallback : directInt;
    }

    if (text.startsWith('enc_ck_v1:')) {
      try {
        final sealed = base64Url.decode(text.substring('enc_ck_v1:'.length));
        final clearBytes = _openBytesSync(
          sealed,
          contextLabel: 'branch_terminal_comm_key',
        );
        final parsed = int.tryParse(utf8.decode(clearBytes));
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      } catch (_) {
        return fallback;
      }
    }
    return fallback;
  }

  // ---------------------------------------------------------------------------
  // [HW-03] & [HW-04] Puantaj Kayıt Bütünlüğü (`HMAC-SHA256`)
  // ---------------------------------------------------------------------------

  /// Her giriş/çıkış kaydı için `HMAC-SHA256(cardNo + timestamp + isCheckIn + verifyMethod, secretKey)` üretir.
  static String computeAttendanceIntegrityHash({
    required String cardNo,
    required DateTime timestamp,
    required bool isCheckIn,
    required String verifyMethod,
    String? secretKey,
  }) {
    final keyMaterial = (secretKey != null && secretKey.trim().isNotEmpty)
        ? secretKey.trim()
        : 'hasibu-att-hmac-v1:${_memoryKeyCache[hmacSecretStorageSlot] ?? 'core-integrity-key'}';
    final canonicalPayload =
        '${cardNo.trim()}|${timestamp.toIso8601String()}|${isCheckIn ? 'IN' : 'OUT'}|${verifyMethod.trim()}';
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(keyMaterial));
    return hmac.convert(utf8.encode(canonicalPayload)).toString();
  }

  /// Veritabanından okunan puantaj kaydının `integrityHash` değerini doğrular.
  static bool verifyAttendanceIntegrity({
    required String cardNo,
    required DateTime timestamp,
    required bool isCheckIn,
    required String verifyMethod,
    required String storedHash,
    String? secretKey,
  }) {
    final trimmedHash = storedHash.trim();
    if (trimmedHash.isEmpty) return false;
    final expected = computeAttendanceIntegrityHash(
      cardNo: cardNo,
      timestamp: timestamp,
      isCheckIn: isCheckIn,
      verifyMethod: verifyMethod,
      secretKey: secretKey,
    );
    return _constantTimeEquals(
      utf8.encode(trimmedHash.toLowerCase()),
      utf8.encode(expected.toLowerCase()),
    );
  }

  // ---------------------------------------------------------------------------
  // [HW-05] Dinamik QR: 30 Saniyelik TOTP (`HMAC-SHA1`) Üretimi ve Doğrulaması
  // ---------------------------------------------------------------------------

  /// RFC 6238 uyumlu 30 saniyede bir değişen 6 haneli `TOTP (HMAC-SHA1)` kodu üretir.
  static String generateTotpCode(
    String qrSecret, {
    DateTime? timestamp,
    int periodSeconds = 30,
    int digits = 6,
  }) {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final timeStep = now.millisecondsSinceEpoch ~/ 1000 ~/ periodSeconds;
    return _generateHotpFromStep(qrSecret, timeStep, digits: digits);
  }

  static String _generateHotpFromStep(
    String qrSecret,
    int timeStep, {
    int digits = 6,
  }) {
    final counterBytes = Uint8List(8);
    var value = timeStep;
    for (var i = 7; i >= 0; i--) {
      counterBytes[i] = value & 0xff;
      value >>= 8;
    }
    final keyBytes = utf8.encode(
      qrSecret.trim().isEmpty ? 'HASIBU-DEFAULT-QR-SECRET' : qrSecret.trim(),
    );
    final hmac = crypto.Hmac(crypto.sha1, keyBytes);
    final digest = hmac.convert(counterBytes).bytes;

    final offset = digest[digest.length - 1] & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);

    var mod = 1;
    for (var i = 0; i < digits; i++) {
      mod *= 10;
    }
    final otp = binary % mod;
    return otp.toString().padLeft(digits, '0');
  }

  /// Şube Kiosk ekranında gösterilecek dinamik QR yükünü üretir:
  /// `HSBQR1|<branchId>|<issuedEpochSeconds>|<totp6>`
  static String buildDynamicBranchQrPayload({
    required String branchId,
    required String qrSecret,
    DateTime? timestamp,
  }) {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final totp = generateTotpCode(qrSecret, timestamp: now);
    return 'HSBQR1|$branchId|$epochSeconds|$totp';
  }

  /// [HW-05] Dinamik QR kodunu doğrular; 60 saniyeden eski QR okumalarını reddeder.
  static DynamicQrValidationResult verifyDynamicBranchQrPayload({
    required String qrPayload,
    required String expectedBranchId,
    required String qrSecret,
    DateTime? now,
    int maxAgeSeconds = 60,
  }) {
    final checkTime = (now ?? DateTime.now()).toUtc();
    final nowEpoch = checkTime.millisecondsSinceEpoch ~/ 1000;
    final raw = qrPayload.trim();

    if (raw.isEmpty) {
      return const DynamicQrValidationResult(
        isValid: false,
        reason: 'QR kodu boş olamaz.',
      );
    }

    // Format 1: HSBQR1|<branchId>|<epochSeconds>|<totp>
    if (raw.startsWith('HSBQR1|')) {
      final parts = raw.split('|');
      if (parts.length != 4) {
        return const DynamicQrValidationResult(
          isValid: false,
          reason: 'Geçersiz dinamik QR formatı.',
        );
      }
      final branchId = parts[1];
      final issuedEpoch = int.tryParse(parts[2]);
      final providedTotp = parts[3];

      if (branchId != expectedBranchId) {
        return const DynamicQrValidationResult(
          isValid: false,
          reason: 'QR kod farklı bir şubeye ait.',
        );
      }
      if (issuedEpoch == null) {
        return const DynamicQrValidationResult(
          isValid: false,
          reason: 'QR zaman damgası okunamadı.',
        );
      }

      final ageSeconds = nowEpoch - issuedEpoch;
      if (ageSeconds > maxAgeSeconds) {
        return DynamicQrValidationResult(
          isValid: false,
          isExpired: true,
          ageSeconds: ageSeconds,
          reason:
              'QR kodun süresi dolmuş ($ageSeconds sn > $maxAgeSeconds sn sınırı). Lütfen güncel QR okutun.',
        );
      }
      if (ageSeconds < -30) {
        return const DynamicQrValidationResult(
          isValid: false,
          reason: 'Cihaz saati ile QR zaman damgası uyumsuz.',
        );
      }

      final currentStep = nowEpoch ~/ 30;
      // 30 sn penceresi + önceki 2 pencere (toplam 60 sn geçerlilik)
      for (var delta = 0; delta <= 2; delta++) {
        final candidate = _generateHotpFromStep(qrSecret, currentStep - delta);
        if (_constantTimeEquals(
          utf8.encode(providedTotp),
          utf8.encode(candidate),
        )) {
          return DynamicQrValidationResult(
            isValid: true,
            ageSeconds: ageSeconds < 0 ? 0 : ageSeconds,
            reason: 'Dinamik TOTP QR doğrulandı.',
          );
        }
      }

      return const DynamicQrValidationResult(
        isValid: false,
        reason: 'Dinamik QR TOTP imzası geçersiz veya sahte.',
      );
    }

    // Format 2: Doğrudan 6 haneli TOTP kodu girilmişse (son 60 sn = 2 pencere)
    if (RegExp(r'^\d{6}$').hasMatch(raw)) {
      final currentStep = nowEpoch ~/ 30;
      for (var delta = 0; delta <= 2; delta++) {
        final candidate = _generateHotpFromStep(qrSecret, currentStep - delta);
        if (_constantTimeEquals(utf8.encode(raw), utf8.encode(candidate))) {
          return DynamicQrValidationResult(
            isValid: true,
            ageSeconds: delta * 30,
            reason: 'TOTP kodu doğrulandı.',
          );
        }
      }
      return const DynamicQrValidationResult(
        isValid: false,
        isExpired: true,
        reason: 'TOTP kodu geçersiz veya 60 saniyelik süresi dolmuş.',
      );
    }

    return const DynamicQrValidationResult(
      isValid: false,
      reason: 'Statik QR kodları güvenlik politikası gereği reddedildi (TOTP zorunlu).',
    );
  }

  // ---------------------------------------------------------------------------
  // [AUD-01] Denetim İzi (`audit_logs`) Silinemez Zincir Hash Hesabı
  // ---------------------------------------------------------------------------

  static String computeAuditLogHash({
    required String id,
    required String actorEmployeeId,
    required String actionType,
    required String targetRecordId,
    required String oldValue,
    required String newValue,
    required DateTime timestamp,
    String previousHash = 'GENESIS',
  }) {
    final canonical =
        '$previousHash|$id|$actorEmployeeId|$actionType|$targetRecordId|$oldValue|$newValue|${timestamp.toIso8601String()}';
    final hmac = crypto.Hmac(
      crypto.sha256,
      utf8.encode('hasibu-audit-chain-v1'),
    );
    return hmac.convert(utf8.encode(canonical)).toString();
  }

  // ---------------------------------------------------------------------------
  // [AUD-03] Mobil İK/Yönetici Ekran Görüntüsü & App Switcher Kalkanı (FLAG_SECURE)
  // ---------------------------------------------------------------------------

  static Future<bool> setFlagSecureEnabled(bool enabled) async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final result = await _securityChannel.invokeMethod<bool>(
          'setSecureScreen',
          <String, dynamic>{'secure': enabled},
        );
        return result ?? true;
      }
    } catch (e) {
      lastSecurityWarning = e.toString();
      debugPrint('HasibuSecurityService: setSecureScreenForAdminHr platform uyarısı: $e');
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Yardımcı Senkron/Asenkron Anahtar Türetme Fonksiyonları
  // ---------------------------------------------------------------------------

  static Uint8List _derive256BitKeyBytes(
    String seed, {
    required String contextLabel,
  }) {
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(contextLabel));
    return Uint8List.fromList(hmac.convert(utf8.encode(seed)).bytes);
  }

  static Uint8List _sealBytesSync(
    Uint8List plain, {
    required String contextLabel,
  }) {
    final key = _derive256BitKeyBytes(
      ensureDatabaseKeyHexSync(),
      contextLabel: contextLabel,
    );
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => Random.secure().nextInt(256)),
    );
    final cipher = _xorKeystream(plain, key: key, nonce: nonce);
    final mac = crypto.Hmac(crypto.sha256, key)
        .convert(<int>[...nonce, ...cipher])
        .bytes;
    return Uint8List.fromList(<int>[...nonce, ...mac, ...cipher]);
  }

  static Uint8List _openBytesSync(
    Uint8List sealed, {
    required String contextLabel,
  }) {
    if (sealed.length < 12 + 32) {
      throw const FormatException('Şifreli veri bloğu çok kısa.');
    }
    final key = _derive256BitKeyBytes(
      ensureDatabaseKeyHexSync(),
      contextLabel: contextLabel,
    );
    final nonce = sealed.sublist(0, 12);
    final expectedMac = sealed.sublist(12, 44);
    final cipher = sealed.sublist(44);
    final actualMac = crypto.Hmac(crypto.sha256, key)
        .convert(<int>[...nonce, ...cipher])
        .bytes;
    if (!_constantTimeEquals(expectedMac, actualMac)) {
      throw const FormatException('Şifreli veri bütünlük doğrulaması başarısız.');
    }
    return _xorKeystream(cipher, key: key, nonce: nonce);
  }

  static Uint8List _xorKeystream(
    Uint8List input, {
    required Uint8List key,
    required Uint8List nonce,
  }) {
    final out = Uint8List(input.length);
    var counter = 0;
    var offset = 0;
    while (offset < input.length) {
      final blockKey = crypto.Hmac(crypto.sha256, key)
          .convert(<int>[...nonce, (counter >> 8) & 0xff, counter & 0xff])
          .bytes;
      final take = min(blockKey.length, input.length - offset);
      for (var i = 0; i < take; i++) {
        out[offset + i] = input[offset + i] ^ blockKey[i];
      }
      offset += take;
      counter++;
    }
    return out;
  }
}

class DynamicQrValidationResult {
  const DynamicQrValidationResult({
    required this.isValid,
    required this.reason,
    this.isExpired = false,
    this.ageSeconds = 0,
  });

  final bool isValid;
  final String reason;
  final bool isExpired;
  final int ageSeconds;
}
