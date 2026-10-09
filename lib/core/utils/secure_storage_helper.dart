import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android Keystore / iOS Keychain / Windows Credential Manager için
/// çift katmanlı (SecureStorage + şifreli ikincil kalıcılık) ve kendini onaran (self-healing) sarmalayıcı.
class SecureStorageHelper {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _fallbackSalt = 'Zikirce_Secure_Persistence_2026_Salt';

  /// Obfuscate value for secondary fallback persistence
  static String _obfuscate(String key, String value) {
    final keyBytes = utf8.encode(sha256.convert(utf8.encode('$key$_fallbackSalt')).toString());
    final valBytes = utf8.encode(value);
    final out = List<int>.generate(valBytes.length, (i) => valBytes[i] ^ keyBytes[i % keyBytes.length]);
    return base64UrlEncode(out);
  }

  /// De-obfuscate value from secondary fallback persistence
  static String? _deobfuscate(String key, String encoded) {
    try {
      final out = base64Url.decode(encoded);
      final keyBytes = utf8.encode(sha256.convert(utf8.encode('$key$_fallbackSalt')).toString());
      final valBytes = List<int>.generate(out.length, (i) => out[i] ^ keyBytes[i % keyBytes.length]);
      return utf8.decode(valBytes);
    } catch (_) {
      return null;
    }
  }

  /// Anahtara ait değeri güvenli biçimde okur.
  /// Birincil donanımsal okuma başarısız olursa veya boş dönerse, ikincil kalıcı depodan kurtarır ve birincile geri yazar.
  /// Asla geçici okuma hatalarında veriyi silmez.
  static Future<String?> read(String key) async {
    String? value;
    try {
      value = await _storage.read(key: key);
      if (value != null && value.isNotEmpty && value != 'Data has been reset') {
        // İkincil yedeği güncel tut
        await _saveFallback(key, value);
        return value;
      }
    } on PlatformException catch (e) {
      debugPrint('[SecureStorageHelper] PlatformException on read ($key): ${e.message}');
      if (e.message?.contains('BadPaddingException') == true ||
          e.message?.contains('BAD_DECRYPT') == true ||
          e.message?.contains('Cipher') == true) {
        try {
          await _storage.delete(key: key);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SecureStorageHelper] Unexpected error on read ($key): $e');
    }

    // Birincil depoda bulunamadı veya hata oluştu -> İkincil kalıcı depodan kurtar
    try {
      final fallbackValue = await _readFallback(key);
      if (fallbackValue != null && fallbackValue.isNotEmpty) {
        debugPrint('[SecureStorageHelper] 🛡️ Veri ($key) ikincil kalıcı depodan başarıyla kurtarıldı.');
        try {
          await _storage.write(key: key, value: fallbackValue);
        } catch (_) {}
        return fallbackValue;
      }
    } catch (e) {
      debugPrint('[SecureStorageHelper] Fallback recovery notice for ($key): $e');
    }

    return null;
  }

  /// Güvenli yazma işlemi (Hem birincil SecureStorage hem ikincil kalıcı depoya).
  static Future<void> write(String key, String value) async {
    // 1. İkincil kalıcı yedek (MSIX kaldır-yükle veya donanım resetlerine karşı garantili)
    await _saveFallback(key, value);

    // 2. Birincil SecureStorage
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
    await _deleteFallback(key);
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[SecureStorageHelper] Error on delete ($key): $e');
    }
  }

  /// Tüm anahtarları güvenli temizleme.
  static Future<void> deleteAll() async {
    await _deleteAllFallback();
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[SecureStorageHelper] Error on deleteAll: $e');
    }
  }

  // ===========================================================================
  // İKİNCİL KALICI DEPO (SELF-HEALING SECONDARY PERSISTENCE)
  // ===========================================================================

  static Future<void> _saveFallback(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final obfuscated = _obfuscate(key, value);
      await prefs.setString('_sec_fb_$key', obfuscated);
    } catch (_) {}
  }

  static Future<String?> _readFallback(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final obfuscated = prefs.getString('_sec_fb_$key');
      if (obfuscated == null || obfuscated.isEmpty) return null;
      return _deobfuscate(key, obfuscated);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deleteFallback(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('_sec_fb_$key');
    } catch (_) {}
  }

  static Future<void> _deleteAllFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('_sec_fb_')).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
