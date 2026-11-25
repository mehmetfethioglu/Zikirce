import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulamanın güncel sürüm sabitleri (`pubspec.yaml` ile eşgüdümlü).
const String hasibuAppVersion = '1.0.17';
const int hasibuAppBuildNumber = 18;
const String hasibuFullVersionLabel = 'v1.0.17 (Build 18)';

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
    version: '1.0.17',
    buildNumber: 18,
    releaseDate: '25.11.2026',
    title: 'A4 Yazdırma, Canlı Arama Düzeltmesi, Şirket Logosu & İlk Kurulum',
    categoryTag: 'Kullanılabilirlik & Çıktı',
    highlights: [
      'A4 Yazdırma ve Önizleme: Personel kartları, personel listeleri, canlı yoklama, devam/devamsızlık ve izin raporları için çapraz platform çıktı alma desteği eklendi.',
      'Canlı Yoklama Arama Düzeltmesi: Arama kutusundaki metin silindiğinde listenin anında yenilenmesi, temizle butonu ve Türkçe karakter (İ/I/ı/i/ğ/ü/ş/ö/ç) uyumu sağlandı.',
      'Dosyadan Şirket Logosu Düzeltmesi: Türkçe ve boşluklu dosya yolu desteği, PNG/JPG/WEBP/GIF/BMP doğrulama, anlık önizleme, kalıcı kopyalama ve mobil yerel görsel seçici eklendi.',
      'İlk Oturumda İşletme Adı & Logo Kurulumu: İlk yönetici parolası güncelleme ekranında işletme adı ve şirket logosunu doğrudan tanımlama özelliği sunuldu.',
    ],
  ),
  HasibuReleaseNoteEntry(
    version: '1.0.16',
    buildNumber: 17,
    releaseDate: '25.11.2026',
    title: 'Google Drive Listeleme Düzeltmesi, Şeffaf Bulut Kaynağı & Köprü Güncellemesi',
    categoryTag: 'Bulut & Köprü',
    highlights: [
      'Google Drive Şube Kutusu Listeleme Düzeltmesi: Drive API sorgularında alt-çizgi (_) içeren dosya adlarının boş dönmesine yol açan filtre kaldırılarak telefon ve masaüstünde şube kutularının (hasibu_branch_inbox_*.enc) eksiksiz bulunması sağlandı.',
      'Mobil Buluttan Yükle & OAuth 401 Şeffaflığı: Mobilde buluttan yükleme varsayılan olarak doğrudan bulut öncelikli hale getirildi; süresi dolmuş 401 oturumunda sessizce boş yerel önbelleğe düşmek yerine açık uyarı ve veri kaynağı bilgisi gösteriliyor.',
      'Şube Köprüsü Güncelleme Kilidi Çözümü: 3_Baslangica_Ekle.bat (--install-startup) çalıştırıldığında eski arka plan süreci otomatik durdurularak yeni HasibuBranchBridge.exe kopyalanıp anında başlatılıyor.',
    ],
  ),
  HasibuReleaseNoteEntry(
    version: '1.0.15',
    buildNumber: 16,
    releaseDate: '25.11.2026',
    title: 'Doğrula & Kaydet, Hesap İzolasyonu, Şube Köprüsü & Mobil Bulut Aktarımı',
    categoryTag: 'Bulut & Köprü',
    highlights: [
      'Doğrula & Kaydet İyileştirmesi: Hafif bulut bağlantı doğrulaması eklendi; işlem sürerken yanlış "Doğrulanmadı" uyarısı yerine mavi doğrulama/eşitleme durum göstergesi sunuluyor.',
      'Google Hesap Değişimi İzolasyonu: Farklı bir Google hesabına geçildiğinde önceki hesaba ait yerel veritabanı, yönetici parolası ve şifreleme anahtarı izole edilerek yeni hesap verilerinin üzerine yazılması engellendi.',
      'Şube Yüz Okutma Köprüsü Güncellemesi: Kurulum ve başlangıca ekleme sonrası köprü arka planda anında başlatılıyor ve bilinmeyen kart/yüz kaydında personel adları otomatik senkronize ediliyor.',
      'Mobil Bulut Geri Yükleme: Buluttan yükleme sırasında şube kutusu (branch inbox) kayıtları birleştirme ve değiştirme modlarının ikisinde de eksiksiz aktarılıyor.',
    ],
  ),
  HasibuReleaseNoteEntry(
    version: '1.0.14',
    buildNumber: 15,
    releaseDate: '23.11.2026',
    title: 'Tekil Giriş, Şifre Kurtarma, Dijital Özlük & Kapalı Test Hazırlığı',
    categoryTag: 'Güvenlik & Deneyim',
    highlights: [
      'Tekil Otomatik Giriş Ekranı: Rol sekmesi seçmeden yönetici, şube sorumlusu ve personel hesapları otomatik algılanır; üst çubuğa minimalist Google Bulut oturum ikonu ve ilk kurulumda zorunlu yönetici şifre kalkanı eklendi.',
      'Birleşik Şifre Kurtarma: Unutulan parolalar şirket Gmail hesabı üzerinden gönderilen 6 haneli tek kullanımlık doğrulama kodu (10 dakika geçerli) veya Google kimlik doğrulama yedeğiyle güvenle sıfırlanır.',
      'Sadeleştirilmiş İzin & Devam Raporları: Aramalı, şube ve çalışma durumu filtreli ortak personel rehberi (masaüstü yan rehber + mobil seçici) ile hızlı izin gün kısayolları eklendi.',
      'Dijital Özlük Kontrol Paneli: Zorunlu ve opsiyonel özlük evrakları için eksik/yüklü filtreleme, durum göstergesi ve sadeleştirilmiş evrak yükleme deneyimi sunuldu.',
      'Kapalı Test & ASO/GEO Uyumluluğu: Google Play Kapalı Test (Alpha), Apple TestFlight Türkçe/İngilizce mağaza kimliği ve resmi gizlilik/destek web portalı hazırlandı.',
    ],
  ),
  HasibuReleaseNoteEntry(
    version: '1.0.13',
    buildNumber: 14,
    releaseDate: '23.11.2026',
    title: 'Çoklu Şube Kapsamı & Katı Şube Sorumlusu İzolasyonu',
    categoryTag: 'Güvenlik & Yetki',
    highlights: [
      'Çoklu Şube Kapsamı Seçimi: Kullanıcı yönetiminde birden fazla şube seçimi ve "Merkez Hariç Tümü" kısayolu eklendi.',
      'Katı Şube Sorumlusu İzolasyonu: Şube sorumlularının Merkez ve yetkisiz şube verilerini görüntülemesi ve değiştirmesi tamamen engellendi.',
      'Yetkili Şubeler Arası Geçiş: AppBar rozeti, canlı PDKS filtreleri, devam/devamsızlık raporları, CSV dışa aktarım, personel portalı ve QR/GPS ekranları çoklu şube yetkisine uyarlandı.',
      'iOS 27 SDK / Xcode 27 Uyumluluğu: App Store Connect ITMS-90725 uyumluluğu ve iOS 15+ minimum dağıtım hedefi güncellendi.',
    ],
  ),
  HasibuReleaseNoteEntry(
    version: '1.0.12',
    buildNumber: 13,
    releaseDate: '23.11.2026',
    title: 'Kalıcı Google Oturumu, Çoklu Kullanıcı Girişi & Sıfır-Adımlı Bulut Şifreleme',
    categoryTag: 'Güncelleme',
    highlights: [
      'Kalıcı Google Bulut Oturumu & Çoklu Kullanıcı Girişi: Google hesabıyla bir kez bağlandıktan sonra bulut oturumu açık kalır; uygulama açılışında kullanıcı adı/parola girişi ve kullanıcı adını hatırla özelliği sunulur.',
      'Otomatik Google Hesabı Şifrelemesi & Kısa Parola: Aynı Google hesabındaki cihazlar uzun Workspace Key kopyalamadan yedekleri otomatik açar; ek olarak kısa ortak bulut parolası ve QR eşleştirme eklendi.',
      'Bulut Yedeği Ezme Koruması: Çözülemeyen veya anahtarı uyuşmayan uzak yedeklerin üzerine yerel veritabanının yanlışlıkla yazılması engellendi.',
      'Şube Köprüsü Uyarısız Başlangıç: Windows Görev Zamanlayıcı entegrasyonu ve Mark-of-the-Web (Zone.Identifier) temizliğiyle oturum açılışında güvenlik uyarısı engellendi.',
    ],
  ),
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
