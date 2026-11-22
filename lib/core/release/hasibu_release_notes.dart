import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulamanın güncel sürüm sabitleri (`pubspec.yaml` ile eşgüdümlü).
const String hasibuAppVersion = '1.0.11';
const int hasibuAppBuildNumber = 12;
const String hasibuFullVersionLabel = 'v1.0.11 (Build 12)';

/// Tekil sürüm notu kaydı.
@immutable
class HasibuReleaseNoteEntry {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String title;
  final String categoryTag;
  final List<String> highlights;

  const HasibuReleaseNoteEntry({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.title,
    required this.categoryTag,
    required this.highlights,
  });

  String get versionLabel => 'v$version (Build $buildNumber)';
}

/// Kronolojik olarak güncelden eskiye Hasibu sürüm notları listesi.
const List<HasibuReleaseNoteEntry> hasibuReleaseNotesRegistry = [
  HasibuReleaseNoteEntry(
    version: '1.0.11',
    buildNumber: 12,
    releaseDate: '22.11.2026',
    title: 'Bulut Yedekleme, Çoklu Kullanıcı & Sürüm Notları',
    categoryTag: 'Büyük Güncelleme',
    highlights: [
      'Buluta Yedekle ve Buluttan Yükle: İki farklı yükleme modu ile ister mevcut yerel kayıtlarla güvenli birleştirme, ister şirket veritabanını tek adımda tam geri yükleme.',
      'Otomatik Bulut Yedekleme: Değişiklik anında ve belirlenen dakikalık periyotlarda Google Drive üzerine arka plan yedeği.',
      'Çalışma Alanı Anahtarı Paylaşımı: Farklı cihazlarda ve aynı Gmail/Google Drive hesabında birden fazla kasa profili (izole şirket veritabanı) oluşturma.',
      'Aynı Şirket İçinde Çoklu Kullanıcı Yönetimi: Yönetici, Vardiya Sorumlusu ve Salt-Okunur İzleyici rolleriyle şube kapsamlı erişim kontrolü.',
      'Uygulama İçi Sürüm Notları & Resmi İkonlar: Güncelleme özetlerini anında inceleme ve iOS/Android mağazaları için resmi Hasibu uygulama ikonu.',
    ],
  ),
  HasibuReleaseNoteEntry(
    version: '1.0.10',
    buildNumber: 11,
    releaseDate: '15.11.2026',
    title: 'Temiz Kurulum, Google OAuth 2.0 & Şifreli Bulut Altyapısı',
    categoryTag: 'Güvenlik & Altyapı',
    highlights: [
      'Sıfır Kurulum Temiz Veritabanı: Üretim sürümünde örnek/şahsi veri olmadan temiz Merkez Şube iskeleti ile güvenli başlangıç.',
      'Doğrudan Google OAuth 2.0 Oturumu: iOS, Android ve Windows üzerinden Google hesabı ile hızlı kimlik doğrulama.',
      'AES-GCM Uçtan Uca Şifreli Drive Yedeği: Tüm yerel SQLCipher verilerinin buluta şifrelenerek aktarılması.',
      'Yüksek Güvenlikli Oturum Kalkanı: Hassas İK/yönetici ekranlarında uygulama değiştirici gizleme koruması.',
    ],
  ),
  HasibuReleaseNoteEntry(
    version: '1.0.7',
    buildNumber: 8,
    releaseDate: '01.11.2026',
    title: 'Çok Şubeli PDKS, Vardiya, İK & Dijital Özlük Kokpiti',
    categoryTag: 'Temel Platform',
    highlights: [
      'Tenfei D35 Yüz Okutma Terminali: TCP/IP protokolü üzerinden çoklu şube cihaz senkronizasyonu ve anlık hareket takibi.',
      'Şube QR / GPS Yoklama: Mobil saha personeli için konum ve QR doğrulamalı giriş/çıkış kaydı.',
      'Vardiya & Geç Kalma Toleransları: Esnek mesai planları, günlük puantaj, devam/devamsızlık ve izin raporlaması.',
      'Personel Self-Servis Portalı: Personelin kendi izin taleplerini, vardiya bilgisini ve dijital özlük evraklarını görüntülemesi.',
    ],
  ),
];

/// Kullanıcının güncel sürüm notlarını görüp görmediğini takip eder.
class HasibuReleaseNotesTracker {
  static const String lastSeenVersionPrefKey =
      'hasibu_last_seen_release_version';

  const HasibuReleaseNotesTracker._();

  /// Güncel [hasibuAppVersion] henüz kullanıcı tarafından görüntülenmediyse `true` döner.
  static Future<bool> hasUnseenReleaseNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenVersion = prefs.getString(lastSeenVersionPrefKey);
      return seenVersion != hasibuAppVersion;
    } catch (error) {
      debugPrint('HasibuReleaseNotesTracker okuma hatası: $error');
      return false;
    }
  }

  /// Güncel [hasibuAppVersion] sürümünü görüldü olarak işaretler.
  static Future<bool> markCurrentVersionSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(lastSeenVersionPrefKey, hasibuAppVersion);
    } catch (error) {
      debugPrint('HasibuReleaseNotesTracker yazma hatası: $error');
      return false;
    }
  }
}
