import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android Keystore / iOS Keychain donanım ve şifreleme hatalarına (BadPaddingException, BAD_DECRYPT vb.)
/// karşı korumalı, güvenli ve dayanıklı SecureStorage sarmalayıcısı.
class SecureStorageHelper {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Anahtara ait değeri güvenli biçimde okur.
  /// Keystore bozulması veya şifre çözme hatasında (BadPaddingException) veriyi temizler ve null döner.
  static Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      // flutter_secure_storage plugin'i resetOnError tetiklendiğinde "Data has been reset" string'i dönebilir
      if (value == null || value.isEmpty || value == 'Data has been reset') {
        return null;
      }
      return value;
    } on PlatformException catch (e) {
      debugPrint('[SecureStorageHelper] PlatformException on read ($key): ${e.message}');
      await delete(key);
      return null;
    } catch (e) {
      debugPrint('[SecureStorageHelper] Unexpected error on read ($key): $e');
      await delete(key);
      return null;
    }
  }

  /// Güvenli yazma işlemi.
  static Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (e) {
      debugPrint('[SecureStorageHelper] PlatformException on write ($key): ${e.message}');
      try {
        await _storage.delete(key: key);
        await _storage.write(key: key, value: value);
      } catch (retryErr) {
        debugPrint('[SecureStorageHelper] Retry write failed for ($key): $retryErr');
      }
    } catch (e) {
      debugPrint('[SecureStorageHelper] Unexpected error on write ($key): $e');
    }
  }

  /// Güvenli silme işlemi.
  static Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[SecureStorageHelper] Error on delete ($key): $e');
    }
  }

  /// Tüm anahtarları güvenli temizleme.
  static Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[SecureStorageHelper] Error on deleteAll: $e');
    }
  }
}
