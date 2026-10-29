import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single highlight item inside a version's release notes entry.
@immutable
class CueReleaseNoteItem {
  const CueReleaseNoteItem({
    required this.badge,
    required this.title,
    required this.description,
  });

  final String badge;
  final String title;
  final String description;
}

/// Complete release notes metadata for a specific CueDeck version.
@immutable
class CueReleaseVersionEntry {
  const CueReleaseVersionEntry({
    required this.version,
    required this.versionLabel,
    required this.releaseDate,
    required this.headline,
    required this.highlights,
  });

  final String version;
  final String versionLabel;
  final String releaseDate;
  final String headline;
  final List<CueReleaseNoteItem> highlights;
}

/// Canonical catalog of CueDeck version history and "What's New" highlights.
class CueReleaseNotesCatalog {
  CueReleaseNotesCatalog._();

  /// Active application version (`pubspec.yaml`).
  static const String currentVersion = '1.9.4+16';
  static const String currentShortVersion = 'v1.9.4';

  /// Ordered list of release note entries (newest first).
  static const List<CueReleaseVersionEntry> versions = <CueReleaseVersionEntry>[
    CueReleaseVersionEntry(
      version: '1.9.4+16',
      versionLabel: 'v1.9.4 (Build 16)',
      releaseDate: '29 Ekim 2026',
      headline:
          'Gerçek Siyah (#000000) Ayarlar, Ağ Cihaz Arama, Özelleştirilebilir Kumanda Tuşları & Çoklu Telefon Desteği',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'TUŞLAR',
          title: 'Kumanda Uygulama Tuşlarını Değiştirme (16 Uygulama)',
          description:
              'Kumanda üzerindeki 6 kısayol tuşuna basılı tutarak veya Ayarlar içinden YouTube, Netflix, beIN, tabii, Prime Video, Disney+, Exxen, Max/BluTV, S Sport+, TOD TV, Spotify, Twitch ve daha fazlasıyla değiştirebilirsiniz.',
        ),
        CueReleaseNoteItem(
          badge: 'AĞ & iOS',
          title: '«🔍 Ağdaki Cihazları Ara» & Çoklu Telefon Desteği',
          description:
              'Tek dokunuşla ağdaki TV cihazlarını arama, 3 adımda kolay eşleştirme rehberi ve birden fazla telefonun (iPhone + Android) aynı TV\'yi birbirini kilitlemeden yönetmesi sağlandı.',
        ),
        CueReleaseNoteItem(
          badge: 'TASARIM',
          title: 'Koyu Temada Gerçek Siyah (#000000) Ayarlar Ekranı',
          description:
              'Ayarlar ve İzleme Planı ekranı koyu temada tam Gerçek Siyah (#000000) zemin ve derin obsidiyen kartlarla G10 kumanda gövdesiyle bütünleştirildi.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.3+15',
      versionLabel: 'v1.9.3 (Build 15)',
      releaseDate: '28 Ekim 2026',
      headline:
          'Uygulama İçi Sürüm Notları, Gerçek AdMob & Resmi Mağaza Ödeme Doğrulaması',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'YENİ',
          title: 'Uygulama İçi Sürüm Notları & Yenilikler Kartı',
          description:
              'Güncelleme sonrasında ilk açılışta bu sürümde neler değiştiğini gösteren yenilikler penceresi ve Ayarlar içinden tüm geçmiş sürümleri inceleme özelliği eklendi.',
        ),
        CueReleaseNoteItem(
          badge: 'PRO',
          title: 'Resmi Mağaza Ödeme Doğrulaması (149,99 ₺) & Pro Sıfırlama',
          description:
              'Tek Seferlik Ömür Boyu Pro (149,99 ₺) ve 10 günlük %40 Sadakat İndirimi (89,99 ₺) doğrudan Google Play Billing ve Apple StoreKit 2 ödeme onayına bağlandı.',
        ),
        CueReleaseNoteItem(
          badge: 'PASS',
          title: 'Kumanda Alt Bar & «🎬 24s Kaldır» Kısayolu',
          description:
              'Fiziksel G10 kumanda gövdesinin dışında, tuşlara müdahale etmeyen alt bar ve 1 ödüllü video izleyerek 24 saat reklamsız Pro Pass açma kısayolu eklendi.',
        ),
        CueReleaseNoteItem(
          badge: 'iOS',
          title: 'iOS TestFlight & Üretim AdMob Entegrasyonu',
          description:
              'Apple App Store Connect TestFlight dağıtımı, iOS üretim AdMob birimleri ve SKAdNetwork gizlilik yapılandırması tamamlandı.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.1+13',
      versionLabel: 'v1.9.1 (Build 13)',
      releaseDate: '28 Ekim 2026',
      headline:
          'Soft Slate & Warm Alabaster Arayüzü ve Port 6466 PIN Eşleştirme',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'TASARIM',
          title: 'Yumuşak Renk Paleti (Soft Slate & Warm Alabaster)',
          description:
              'Ayarlar ve İzleme Planı ekranı gözü dinlendiren #141824 Soft Slate (Koyu Mod) ve #F3F6FA Warm Alabaster (Açık Mod) renk paletiyle yenilendi.',
        ),
        CueReleaseNoteItem(
          badge: 'TV',
          title: 'Port 6466 (6 Haneli PIN) Sıfır Kurulum Modu',
          description:
              'Geliştirici Seçenekleri kapalı olan standart televizyonlar için 6 haneli PIN ile eşleştirme ve adım adım görsel TV kurulum rehberi eklendi.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.8.0+11',
      versionLabel: 'v1.8.0 (Build 11)',
      releaseDate: '28 Ekim 2026',
      headline: 'Tam Ekran Ayarlar & Gerçek İşletim Sistemi Alarmları',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'ALARM',
          title: 'Gerçek OS Bildirimleri & Arka Plan Zamanlayıcısı',
          description:
              'Uygulama kapalıyken dahi izleme planı saatinde ve ön hatırlatma dakikasında yüksek öncelikli durum çubuğu bildirimi gönderimi devreye alındı.',
        ),
        CueReleaseNoteItem(
          badge: 'AYARLAR',
          title: 'Tam Sayfa Ayarlar & İzleme Planı Ekranı',
          description:
              'Ayarlar ve İzleme Planı görünümü yarım ekran çekmece yerine tam sayfa (Scaffold) mimarisine taşındı.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.7.0+10',
      versionLabel: 'v1.7.0 (Build 10)',
      releaseDate: '28 Ekim 2026',
      headline: 'Evrensel Android TV & Google TV RSA-2048 Eşleştirme',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'TV',
          title: 'ADB RSA-2048 Donanım İmzalı Eşleştirme & mDNS Keşfi',
          description:
              'Sony Bravia, TCL, Philips, Xiaomi Mi Box/Stick, Chromecast ve Redline TV cihazlarını yerel ağda otomatik bulma ve RSA onayıyla eşleştirme eklendi.',
        ),
        CueReleaseNoteItem(
          badge: 'BULUT',
          title: 'AES-256-GCM Şifreli Google Drive & Yerel JSON Yedekleme',
          description:
              'İzleme planlarını ve TV profillerini donanım şifreli olarak Google Drive üzerinden tüm cihazlarda eşitleme desteği sağlandı.',
        ),
      ],
    ),
  ];

  /// Latest version entry (`1.9.3+15`).
  static CueReleaseVersionEntry get latest => versions.first;
}

/// Tracks whether the user has seen the release notes for the current version
/// so CueDeck can automatically present the "What's New" sheet on first launch
/// after an app update.
class CueReleaseNotesService {
  const CueReleaseNotesService();

  static const String _kLastSeenVersionKey =
      'cuedeck_last_seen_release_version';

  static bool get _isFlutterTestEnvironment {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Returns `true` if the current app version (`CueReleaseNotesCatalog.currentVersion`)
  /// has not yet been acknowledged by the user on this device.
  Future<bool> shouldShowWhatsNewOnStartup({bool allowInTest = false}) async {
    if (!allowInTest && _isFlutterTestEnvironment) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getString(_kLastSeenVersionKey);
    return lastSeen != CueReleaseNotesCatalog.currentVersion;
  }

  /// Returns the last version string seen by the user, or `null` on fresh install.
  Future<String?> getLastSeenVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastSeenVersionKey);
  }

  /// Marks `CueReleaseNotesCatalog.currentVersion` as seen so the startup modal
  /// won't repeat until the next version update.
  Future<void> markCurrentVersionSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kLastSeenVersionKey,
      CueReleaseNotesCatalog.currentVersion,
    );
  }
}
