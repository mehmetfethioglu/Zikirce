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
  static const String currentVersion = '2.2.0+30';
  static const String currentShortVersion = 'v2.2.0';

  /// Ordered list of release note entries (newest first).
  static const List<CueReleaseVersionEntry> versions = <CueReleaseVersionEntry>[
    CueReleaseVersionEntry(
      version: '2.2.0+30',
      versionLabel: 'v2.2.0 (Build 30)',
      releaseDate: '22 Kasım 2026',
      headline:
          'Sadeleştirilmiş Ayarlar, Kumanda Altı Plan Kartları, YouTube Paylaş → Plana Ekle & Hassas Touchpad',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'PLAN KARTLARI',
          title: 'Kumanda Altında Yakından Uzağa Plan Kartları',
          description:
              'İzleme Planı Ayarlar\'dan kumanda üzerindeki yeni Plan tuşuna taşındı; yakından uzağa sıralı, sağa-sola kaydırılabilen sade plan kartları eklendi.',
        ),
        CueReleaseNoteItem(
          badge: 'YOUTUBE PAYLAŞ',
          title: 'YouTube Paylaş Menüsünden CueDeck Planına Ekleme',
          description:
              'YouTube\'dan "Paylaş → CueDeck" ile otomatik başlık çekme ve tek dokunuşla izleme planına ekleme özelliği eklendi.',
        ),
        CueReleaseNoteItem(
          badge: 'TOUCHPAD & İKONLAR',
          title: 'Yenilenen İkonlar, Sade Ayarlar & Alt Bölge Touchpad',
          description:
              'Mouse yüzeyi alt bölgeye taşındı, hassasiyet (Hassas/Normal/Hızlı) iyileştirildi; mikrofon ve mouse oku ikonları yenilendi, Ayarlar sadeleştirildi.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '2.1.0+28',
      versionLabel: 'v2.1.0 (Build 28)',
      releaseDate: '22 Kasım 2026',
      headline:
          'Kapalı TV Uyandırma (Evrensel Wake-on-LAN), Manuel MAC Kurulumu & Çoklu Marka Otomatik MAC Keşfi',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'KAPALI TV AÇMA (WoL)',
          title: 'IR Vericisi Olmadan iPhone & Android ile Kapalı TV Açma',
          description:
              'Kumanda, Ayarlar ve ağ tarama ekranlarına tek dokunuşla manuel MAC girişi («⚡ TV Uyandır») eklendi. Tüm Smart TV ve Android/Google TV protokollerinde Güç tuşu kapalı cihazda otomatik Wake-on-LAN yedeklemesine geçer.',
        ),
        CueReleaseNoteItem(
          badge: 'OTOMATİK MAC KEŞFİ',
          title: 'Çoklu Marka MAC Algılama & Tarama Sonrası Kalıcı Koruma',
          description:
              'Samsung, LG, Roku, Philips, VIDAA, Sony, Arçelik/Vestel ve Android/Google TV\'lerde SSDP, mDNS, XML/JSON ve ADB üzerinden otomatik MAC algılama ve yeniden taramalarda kayıtlı MAC koruma eklendi.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '2.0.0+27',
      versionLabel: 'v2.0.0 (Build 27)',
      releaseDate: '19 Kasım 2026',
      headline:
          'Küresel TV Uyumluluk Motoru: Philips v6 Digest+PIN, Hisense VIDAA MQTT TLS, Alternatif Profil Seçici & Anonim Tanılama',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'PHİLİPS & VIDAA',
          title: 'Philips JointSpace v6 (1926 PIN) & Hisense/Toshiba VIDAA MQTT TLS',
          description:
              'Avrupa Philips TV\'ler için 4 haneli PIN + HTTP Digest doğrulaması; Hisense/Toshiba VIDAA TV\'ler için şifreli MQTT v3.1.1 ve PIN eşleştirmesi eklendi.',
        ),
        CueReleaseNoteItem(
          badge: 'PROFİL SEÇİCİ',
          title: 'Vestel/Regal Düzeltmeleri, Dinamik Sessiz İkonu & Alternatif Profil',
          description:
              'Regal/Vestel YouTube/Kanal tuş haritası yenilendi, sessiz ikonu canlı duruma bağlandı; Ayarlar\'a tek dokunuş «Alternatif Profil» ve IP/MAC gizleyen Anonim Tanılama Raporu eklendi.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '2.0.0+25',
      versionLabel: 'v2.0.0 (Build 25)',
      releaseDate: '17 Kasım 2026',
      headline:
          'Evrensel Smart TV Sürücüleri (Samsung, LG, Roku, Arçelik, IR), Paylaş Menüsünden TV\'ye Işınlama & Magic Mouse',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'EVRENSEL TV',
          title: 'Samsung Tizen, LG webOS Magic Remote, Roku & Kızılötesi (IR) Desteği',
          description:
              'Samsung (Token + Wake-on-LAN), LG webOS (Magic Mouse Oku + Tekerlek), Roku ECP, Hisense VIDAA, Arçelik/Vestel/UPnP ve Wi-Fi gerektirmeyen Kızılötesi (IR) kumanda modları tek çekirdekte birleştirildi.',
        ),
        CueReleaseNoteItem(
          badge: 'PAYLAŞ & IŞINLA',
          title: 'Telefonun Paylaş Menüsünden Tek Tıkla TV\'ye Işınlama',
          description:
              'YouTube, Netflix veya tarayıcıdaki herhangi bir videoyu/listeyi «Paylaş → CueDeck» ile doğrudan TV\'de açabilir veya akşam saatinize planlayabilirsiniz.',
        ),
        CueReleaseNoteItem(
          badge: 'PRO PLANLAR',
          title: '3 Gün Ücretsiz Denemeli Esnek Pro Paketler',
          description:
              'Haftalık, Yıllık (3 Gün Ücretsiz Deneme) ve Ömür Boyu Pro seçeneklerinin yanında 1 ödüllü reklamla 24 saatlik Pro Pass imkânı sunuldu.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.12+24',
      versionLabel: 'v1.9.12 (Build 24)',
      releaseDate: '1 Kasım 2026',
      headline:
          'Telefon Klavyesiyle Yazma, Geniş Mouse Pad, TV Ekranında Mouse Oku ve Akıllı Sesli Komut',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'KLAVYE',
          title: 'Telefon Klavyesiyle Anında TV\'ye Yazma',
          description:
              'Kumandanın sol üst köşesindeki yeni Klavye tuşuna bastığınızda telefonunuzun klavyesi açılır; yazdığınız ve sildiğiniz harfler anında televizyona aktarılır.',
        ),
        CueReleaseNoteItem(
          badge: 'MOUSE OKU & PAD',
          title: 'Daha Geniş Mouse Pad Alanı ve TV Ekranında Mouse Oku',
          description:
              'Mouse moduna geçtiğinizde dokunmatik alan geniş bir dörtgene dönüşür, TV ekranında gerçek mouse oku belirir ve Sol/Sağ Tık tuşlarıyla kolayca seçim yapabilirsiniz.',
        ),
        CueReleaseNoteItem(
          badge: 'SESLİ KOMUT',
          title: 'Bulunduğunuz Ekranda Sesle Yazma ve Arama',
          description:
              'Sesli komut artık her konuşmada YouTube\'a geçmek yerine, yalnızca «YouTube\'da ...» dediğinizde YouTube\'u açar; diğer konuşmaları bulunduğunuz ekrandaki arama kutusuna yazar.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.11+23',
      versionLabel: 'v1.9.11 (Build 23)',
      releaseDate: '31 Ekim 2026',
      headline: 'Arçelik TV\'ler İçin Ek Tanılama',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'TANILAMA',
          title: 'Arçelik Kumanda Servisi Testi',
          description:
              'Tanılama raporu artık Arçelik televizyonların kendi kumanda servisini de test ediyor. Raporu bize göndererek Arçelik TV desteğinin eklenmesine yardımcı olabilirsiniz.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.10+22',
      versionLabel: 'v1.9.10 (Build 22)',
      releaseDate: '31 Ekim 2026',
      headline: 'Daha Ayrıntılı Bağlantı Tanılama Raporu',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'TANILAMA',
          title: 'Bağlantı Tanılama Raporu',
          description:
              'Tanılama raporu artık TV\'nizi çok daha ayrıntılı test ediyor. Raporu kopyalayıp bize göndererek TV modelinize özel destek eklememize yardımcı olabilirsiniz.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.9+21',
      versionLabel: 'v1.9.9 (Build 21)',
      releaseDate: '31 Ekim 2026',
      headline: 'Farklı TV Modellerinde Bağlantı Sorunlarını Bulmak İçin Tanılama Raporu',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'TANILAMA',
          title: 'Bağlantı Tanılama Raporu',
          description:
              'Ayarlar > TV Bağlantısı bölümündeki «Bağlantı Tanılama Raporu» ile TV\'nizin hangi bağlantı yollarına açık olduğunu tek dokunuşla test edip raporu kopyalayarak bize gönderebilirsiniz. Böylece sizin TV modelinize özel destek ekleyebiliriz.',
        ),
        CueReleaseNoteItem(
          badge: 'DÜZELTME',
          title: 'Daha Doğru Bağlantı Durumu',
          description:
              'TV komutu gerçekten kabul etmediğinde bağlantı artık yanlışlıkla «bağlı» görünmüyor.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.8+20',
      versionLabel: 'v1.9.8 (Build 20)',
      releaseDate: '31 Ekim 2026',
      headline:
          'iPhone ve Android Cihazlarda Arçelik & Farklı Smart TV\'leri Otomatik Bulma ve Hızlı Eşleştirme',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'IPHONE & TV',
          title:
              'iPhone\'da Hatalı «Yerel Ağ Kapalı» Uyarısı Giderildi, TV Arama Hızlandırıldı',
          description:
              'iPhone\'da Yerel Ağ izni açık olmasına rağmen çıkan hatalı uyarı düzeltildi. Artık aynı Wi-Fi ağındaki Arçelik, Beko, Grundig, Vestel ve diğer televizyonlar iPhone\'da saniyeler içinde listelenir.',
        ),
        CueReleaseNoteItem(
          badge: 'ARÇELİK & SMART TV',
          title:
              'Arçelik ve Farklı Marka TV\'lerde Kesintisiz Kumanda ve Tuş Kontrolü',
          description:
              'Farklı evlerdeki Arçelik Smart TV ve Google TV\'lere bağlandığınızda kumanda tuşlarının tepki vermemesi veya bağlantının turuncuya dönmesi sorunu giderildi.',
        ),
        CueReleaseNoteItem(
          badge: 'KOLAY EŞLEŞTİRME',
          title: 'Tek Dokunuşla TV PIN Kodu Eşleştirme',
          description:
              'İlk kez bağlandığınız bir televizyonda herhangi bir kumanda tuşuna bastığınızda TV ekranında çıkan 6 haneli kodu girebileceğiniz pencere otomatik olarak açılır.',
        ),
        CueReleaseNoteItem(
          badge: 'TOUCHPAD & SES',
          title: 'Dokunmatik Fare (Touchpad), Sesli Komut ve Zamanında Bildirimler',
          description:
              'Yön tuşlarını dokunmatik fare gibi kullanabilir, mikrofon tuşuna basar basmaz konuşabilir ve izleme planı bildirimlerinizi uygulama kapalıyken bile tam vaktinde alabilirsiniz.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.7+19',
      versionLabel: 'v1.9.7 (Build 19)',
      releaseDate: '30 Ekim 2026',
      headline:
          'Arçelik, Vestel, Samsung ve LG Smart TV Desteği, Kolay TV Seçimi, Dokunmatik Fare & Tek Dokunuşla Sesli Komut',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'SMART TV',
          title:
              'Arçelik, Beko, Grundig, Vestel, Samsung, LG ve Philips Smart TV Desteği',
          description:
              'Sadece Android TV\'leri değil; Arçelik, Beko, Grundig, Vestel, Samsung, LG ve Philips marka akıllı televizyonları da artık doğrudan telefonunuzdan kontrol edebilirsiniz.',
        ),
        CueReleaseNoteItem(
          badge: 'TV SEÇİMİ',
          title: 'Ağdaki TV\'leri Listeden Seçerek Kolay Bağlanma',
          description:
              '«Ağdaki Cihazları Ara» butonuna bastığınızda aynı Wi-Fi ağındaki televizyonlar sade bir pencerede listelenir; istediğiniz TV\'ye dokunarak hemen bağlanabilirsiniz.',
        ),
        CueReleaseNoteItem(
          badge: 'TOUCHPAD',
          title: 'Yön Tuşlarını Dokunmatik Mouse (Touchpad) Gibi Kullanma',
          description:
              'Kumanda üzerindeki küçük fare butonuna dokunarak yön tuşları alanını dokunmatik yüzeye dönüştürebilir, TV uygulamalarında parmağınızı kaydırarak rahatça gezinebilirsiniz.',
        ),
        CueReleaseNoteItem(
          badge: 'SES & ALARM',
          title: 'Tek Dokunuşla Sesli Komut ve Tam Zamanında Hatırlatıcılar',
          description:
              'Kumandadaki sesli komut tuşuna bastığınız anda ikinci bir dokunuşa gerek kalmadan konuşabilirsiniz. İzleme planı bildirimleri uygulama kapalıyken bile tam saatinde gelir.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.6+18',
      versionLabel: 'v1.9.6 (Build 18)',
      releaseDate: '30 Ekim 2026',
      headline:
          'Tam Vaktinde İzleme Bildirimleri, Dokunmatik Fare Modu ve Tek Dokunuşla Sesli Komut',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'BİLDİRİM',
          title: 'Uygulama Kapalıyken Bile Tam Vaktinde Gelen Bildirimler',
          description:
              'Kaydettiğiniz dizi, film ve video planlarının hatırlatma bildirimleri artık uygulamayı açmanıza gerek kalmadan tam belirlediğiniz dakikada telefonunuza ulaşır.',
        ),
        CueReleaseNoteItem(
          badge: 'TOUCHPAD',
          title: 'Kumanda Üzerinde Dokunmatik Fare (Touchpad) Özelliği',
          description:
              'Yön tuşlarının sağ üst köşesindeki fare düğmesiyle orta alanı dokunmatik fare gibi kullanabilir, parmağınızı kaydırıp dokunarak seçim yapabilirsiniz.',
        ),
        CueReleaseNoteItem(
          badge: 'SESLİ KOMUT',
          title: 'Tek Dokunuşla Hemen Konuşma ve iPhone Ses Desteği',
          description:
              'Kumandadaki mikrofon tuşuna dokunduğunuz anda dinleme otomatik başlar; iPhone ve Android telefonlarda sesli komutlar anında televizyona iletilir.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.5+17',
      versionLabel: 'v1.9.5 (Build 17)',
      releaseDate: '29 Ekim 2026',
      headline:
          'Daha Hızlı TV Bulma ve iPhone Wi-Fi Bağlantı İyileştirmeleri',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'BAĞLANTI',
          title: 'iPhone ve Android İçin Güçlendirilmiş TV Bulucu',
          description:
              'Telefonunuzda mobil veri açık olsa bile evinizdeki Wi-Fi ağına bağlı televizyonları çok daha hızlı ve kesintisiz şekilde bulur.',
        ),
        CueReleaseNoteItem(
          badge: 'UYANDIRMA',
          title: 'Bekleme Modundaki Televizyonları Algılama',
          description:
              'Wi-Fi uyku modunda bekleyen televizyonları arama sırasında otomatik uyandırarak listede görünmesini sağlar.',
        ),
        CueReleaseNoteItem(
          badge: 'KOLAY İZİN',
          title: 'iPhone Ağ İzni Kısayolu',
          description:
              'iPhone\'da yerel ağ izni kapalıysa sizi tek dokunuşla ilgili ayar sayfasına yönlendiren yardımcı buton eklendi.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.4+16',
      versionLabel: 'v1.9.4 (Build 16)',
      releaseDate: '29 Ekim 2026',
      headline:
          'Özelleştirilebilir Kumanda Uygulama Tuşları, Aynı Anda Birden Fazla Telefon Desteği & Siyah Tema',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'TUŞLAR',
          title: 'Kumandadaki 6 Uygulama Tuşunu İstediğiniz Gibi Değiştirme',
          description:
              'Kumanda üzerindeki 6 uygulama tuşuna basılı tutarak veya Ayarlar\'dan YouTube, Netflix, beIN, tabii, Prime Video, Disney+, Exxen, Max/BluTV, S Sport+, TOD TV, Spotify gibi 16 popüler uygulamadan istediğinizi atayabilirsiniz.',
        ),
        CueReleaseNoteItem(
          badge: 'ÇOKLU TELEFON',
          title: 'Evdeki Birden Fazla Telefonla Aynı TV\'yi Yönetme',
          description:
              'Evde hem iPhone hem Android telefonlar aynı anda uygulamayı açsa bile birbirinin bağlantısını kesmeden televizyonu rahatça kontrol edebilir.',
        ),
        CueReleaseNoteItem(
          badge: 'TASARIM',
          title: 'Göz Yormayan Tam Siyah Gece Teması',
          description:
              'Karanlık ortamda televizyon izlerken gözünüzü almaması için Ayarlar ve İzleme Planı ekranı tam siyah gece temasıyla uyumlu hale getirildi.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.3+15',
      versionLabel: 'v1.9.3 (Build 15)',
      releaseDate: '28 Ekim 2026',
      headline:
          'Yenilikler Ekranı, 24 Saat Ücretsiz Reklamsız Kullanım & Ömür Boyu Pro',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'YENİ',
          title: 'Uygulama İçi Sürüm Notları ve Yenilikler Penceresi',
          description:
              'Her güncellemede yeni eklenen özellikleri sade bir pencerede görebilir ve Ayarlar\'dan geçmiş yenilikleri inceleyebilirsiniz.',
        ),
        CueReleaseNoteItem(
          badge: '24s PASS',
          title: 'Tek Kısa Reklamla 24 Saat Boyunca Reklamsız Kullanım',
          description:
              'İstediğiniz zaman tek bir kısa ödüllü video izleyerek uygulamayı 24 saat boyunca tamamen reklamsız kullanabilirsiniz.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.9.1+13',
      versionLabel: 'v1.9.1 (Build 13)',
      releaseDate: '28 Ekim 2026',
      headline:
          'Yenilenen Sade Tasarım ve Ekrandaki PIN Koduyla Kolay Eşleştirme',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'TASARIM',
          title: 'Daha Sade ve Okunaklı Ayarlar Ekranı',
          description:
              'Ayarlar ve İzleme Planı ekranı daha ferah, anlaşılır ve gözü dinlendiren renklerle yenilendi.',
        ),
        CueReleaseNoteItem(
          badge: 'EŞLEŞTİRME',
          title: 'TV Ekranında Çıkan 6 Haneli Kod ile Kolay Bağlantı',
          description:
              'Televizyon ekranında beliren 6 haneli kodu telefonunuza girerek hiçbir teknik ayarla uğraşmadan kolayca eşleştirebilirsiniz.',
        ),
      ],
    ),
    CueReleaseVersionEntry(
      version: '1.8.0+11',
      versionLabel: 'v1.8.0 (Build 11)',
      releaseDate: '28 Ekim 2026',
      headline: 'Tam Ekran İzleme Planlayıcı ve Hatırlatma Bildirimleri',
      highlights: <CueReleaseNoteItem>[
        CueReleaseNoteItem(
          badge: 'PLANLAYICI',
          title: 'Kişisel Dizi, Film ve YouTube Listesi Planlayıcı',
          description:
              'İzlemek istediğiniz içerikleri gün ve saat seçerek planlayabilir, vakti geldiğinde bildirim alıp tek dokunuşla televizyonunuzda açabilirsiniz.',
        ),
        CueReleaseNoteItem(
          badge: 'BULUT',
          title: 'Google Hesabı ve Dosya İle Yedekleme',
          description:
              'İzleme listenizi ve kumanda ayarlarınızı Google hesabınıza veya telefonunuza yedekleyip istediğiniz zaman geri yükleyebilirsiniz.',
        ),
      ],
    ),
  ];

  /// Latest version entry (`1.9.7+19`).
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
