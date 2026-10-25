import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChangelogType {
  newFeature,
  improvement,
  bugFix,
}

class ChangelogItem {
  final ChangelogType type;
  final String titleTr;
  final String titleEn;
  final String descTr;
  final String descEn;
  final IconData icon;

  const ChangelogItem({
    required this.type,
    required this.titleTr,
    required this.titleEn,
    required this.descTr,
    required this.descEn,
    required this.icon,
  });

  String getTitle(String languageCode) => languageCode == 'tr' ? titleTr : titleEn;
  String getDescription(String languageCode) => languageCode == 'tr' ? descTr : descEn;
}

class ChangelogRelease {
  final int versionCode;
  final String versionName;
  final String releaseDateTr;
  final String releaseDateEn;
  final List<ChangelogItem> items;

  const ChangelogRelease({
    required this.versionCode,
    required this.versionName,
    required this.releaseDateTr,
    required this.releaseDateEn,
    required this.items,
  });

  String getReleaseDate(String languageCode) => languageCode == 'tr' ? releaseDateTr : releaseDateEn;
}

class ChangelogService {
  static const String _prefKeyLastSeenVersionCode = 'Changelog_LastSeenVersionCode';
  static const int currentVersionCode = 64;
  static const String currentVersionName = '2.1.9';

  /// Sürüm geçmişi (En yeni sürüm en başta yer alır)
  static const List<ChangelogRelease> releases = [
    ChangelogRelease(
      versionCode: 64,
      versionName: '2.1.9',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'Matbû Kur’ân-ı Kerîm Hatim Duası & Mushaf Sahife Görünümü',
          titleEn: 'Printed Mushaf Khatm Prayer & Illuminated Page Layout',
          descTr: 'Mushafların sonunda yer alan tam metin Hatim ve Bağışlama Duası (Duâü Hatmi’l-Kur’âni’l-Azîm), varsayılan Matbû Arapça sahife görünümü, Kur’ân okuma sayfasıyla birebir aynı Diyanet hattı, Lafzatullah vurgusu ve Selçuklu durak gülleriyle eklendi.',
          descEn: 'Added the complete traditional Khatm al-Quran Prayer with default Printed Mushaf Arabic layout, authentic Diyanet calligraphy, Divine Name highlighting, and Seljuk rosette verse markers.',
          icon: Icons.menu_book_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: '4 Modlu Kur’ân Okuma, 7 Meâl Kıyaslama & 5 Klasik Tefsir',
          titleEn: '4-Mode Quran Reader, 7 Translations & 5 Classical Tafseers',
          descTr: 'Mushaf, Âyet+Meâl, Akıcı Kitap Meâli ve Sayfa İçi Tefsir modları; 7 Türkçe meâl karşılaştırması ve Kur’ân Yolu, Beyzâvî, Mâtürîdî, Keşşâf ve Râzî tam metin tefsir kütüphanesi entegre edildi.',
          descEn: 'Introduced 4 reading modes (Mushaf, Verse+Translation, Flowing Book, In-Page Tafseer), 7 comparative Turkish translations, and 5 full-text classical Tafseer works.',
          icon: Icons.auto_stories_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: '23 Eserlik İslami Külliyat & Ok ile Kelime Takibi',
          titleEn: '23-Volume Islamic Library & Arrow Word Tracking',
          descTr: 'Kütüb-i Sitte, Riyâzü’s-Sâlihîn ve Risale-i Nur Külliyatı tek raflı Külliyat kütüphanesine eklendi; sesli tilâvette "Ok ile Takip" işaretçisi ve 6.236 âyetlik hassas akustik senkronizasyon sunuldu.',
          descEn: 'Added a 23-volume Islamic Library (Kutub al-Sittah, Riyad as-Salihin, Risale-i Nur) and introduced the "Arrow Pointer" word-tracking mode with acoustic sync across all 6,236 verses.',
          icon: Icons.collections_bookmark_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'İnteraktif Kullanım Kılavuzu & 146 Zikir Sahih Hadis Kaynakları',
          titleEn: 'Interactive User Guide & Authentic Hadith References',
          descTr: 'Ayarlar’a anlık aramalı kapsamlı Kullanım Kılavuzu eklendi; 99 Esmâü’l-Hüsnâ ve tüm zikirler Kütüb-i Sitte sahih hadis kaynaklarıyla zenginleştirildi.',
          descEn: 'Added an interactive searchable User Guide in Settings and enriched all 146 default dhikrs and 99 Names of Allah with authentic Hadith citations.',
          icon: Icons.help_center_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 63,
      versionName: '2.1.8',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'Manevi Paylaşım Stüdyosu & Ayet-Hadis Kartları',
          titleEn: 'Spiritual Sharing Studio & Verse-Hadith Cards',
          descTr: 'Zikir, seri (streak) ve hızlı istatistik kartlarına zengin ayet ve hadis-i şerif entegrasyonu, İslami özel gün & Cuma tebrik rozetleri ve Selçuklu yaldız detayları eklendi.',
          descEn: 'Dynamic Quran verses, Hadiths, Islamic special day/Friday greeting badges, and refined Seljuk golden geometry added to dhikr, streak, and statistics share cards.',
          icon: Icons.share_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'Hedef Tamamlama & Paylaşım Bildirimi',
          titleEn: 'Goal Completion & Sharing Celebration',
          descTr: 'Namaz, Kur\'an, zikir ve ezber hedeflerine ulaşıldığında doğrudan manevi tebrik kartı oluşturma ve Ayarlar\'dan yönetilebilir paylaşım hatırlatıcısı sunuldu.',
          descEn: 'Celebration prompts and instant sharing card studio upon completing prayer, Quran, dhikr, or memorization goals, with toggleable settings.',
          icon: Icons.emoji_events_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'iOS Kilit Ekranı (Lock Screen) Araçları İyileştirmeleri',
          titleEn: 'iOS Lock Screen Widget Optimizations',
          descTr: 'Namaz vakti sayacı, zikir zinciri ve hicri takvim kilit ekranı araçlarının senkronizasyon hassasiyeti ve görsel uyumu artırıldı.',
          descEn: 'Enhanced synchronization precision and visual alignment for Prayer Times, Dhikr streak, and Hijri Calendar Lock Screen widgets.',
          icon: Icons.lock_clock_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 62,
      versionName: '2.1.7',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'iOS Kilit Ekranı (Lock Screen) Araçları Desteği',
          titleEn: 'iOS Lock Screen Widgets Support',
          descTr: 'Namaz vakitleri, sıradaki vakit geri sayımı, günlük zikir sayısı, zikir zinciri (seri), manevi kalp ve hicri takvim kilit ekranına eklenebilir araçlar (dairesel, dikdörtgen ve satır içi) olarak entegre edildi.',
          descEn: 'Prayer times, live countdowns, daily dhikr counters, streak chains, spiritual heart metrics, and Hijri calendar are now available as native iOS Lock Screen widgets (circular, rectangular, and inline).',
          icon: Icons.lock_clock_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 61,
      versionName: '2.1.6',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'iOS Arka Planda Kesintisiz Kur\'an & Talim Dinleme',
          titleEn: 'Seamless iOS Background Quran & Talim Playback',
          descTr: 'Kelime Takipli Dinleme Talimi, Mukabele ve Mushaf ekranlarında uygulama arka plana alındığında veya ekran kapatıldığında (kilit ekranında) ayetler arası kesintisiz geçiş ve tilavet devamlılığı sağlandı.',
          descEn: 'Continuous gapless verse-to-verse recitation in Word-by-Word Talim, Mukabele, and Mushaf when the app is in the background or the screen is locked.',
          icon: Icons.headphones_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'iOS Kilit Ekranı, Denetim Merkezi & Dynamic Island Medya Kontrolleri',
          titleEn: 'iOS Lock Screen, Control Center & Dynamic Island Media Controls',
          descTr: 'Okunan sûre ve âyet bilgisi ile oynat/duraklat ve önceki/sonraki âyet geçiş kontrolleri iOS Kilit Ekranı ve Dynamic Island\'a entegre edildi.',
          descEn: 'Integrated active Surah & Ayah metadata and play/pause/skip controls directly into iOS Lock Screen, Control Center, and Dynamic Island.',
          icon: Icons.queue_music_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'App Store Gizlilik Manifestosu & İzin Uyumluluğu',
          titleEn: 'App Store Privacy Manifest & Permission Compliance',
          descTr: 'iOS PrivacyInfo.xcprivacy manifestosu, arka plan çalışma modları ve uygulama içi gizlilik açıklamaları Apple standartlarına tam uyumlu hale getirildi.',
          descEn: 'Added native iOS PrivacyInfo.xcprivacy manifest and aligned background capability declarations with Apple App Store guidelines.',
          icon: Icons.verified_user_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 60,
      versionName: '2.1.5',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'iOS WidgetKit Selçuklu Analog Saati & Kilit Ekranı',
          titleEn: 'iOS WidgetKit Seljuk Analog Clock & Lock Screen',
          descTr: 'iOS Ana Ekran ve Kilit Ekranı için 8 köşeli Selçuklu motifli estetik analog namaz saati ve zenginleştirilmiş vakit takip widget\'ları eklendi.',
          descEn: 'Introduced an exquisite 8-pointed Seljuk star analog prayer clock and enriched prayer widgets for iOS Home Screen & Lock Screen.',
          icon: Icons.access_time_filled_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'Canlı Vakit Dilimli Analog Saat Kadranı',
          titleEn: 'Live Sector-Highlighted Analog Clock Dial',
          descTr: 'Uygulama içi vakit kartlarına dinamik akrep/yelkovan ve namaz vakit dilimlerini görselleştiren zarif Selçuklu analog saat kadranı entegre edildi.',
          descEn: 'Integrated an elegant Seljuk analog clock dial with real-time hands and dynamic prayer sector highlights in daily prayer cards.',
          icon: Icons.watch_later_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Zarif Açılış Ekranı & Tema Uyumu',
          titleEn: 'Refined Native Splash & Theme Cohesion',
          descTr: 'Açılış logosu ve native splash mimarisi baştan sona yenilenerek açık ve koyu temalara kusursuz uyum sağlandı.',
          descEn: 'Native splash architecture and brand identity updated for zero-flicker transitions and perfect dark/light harmony.',
          icon: Icons.palette_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'WidgetKit Arka Plan Senkronizasyonu & Kararlılık',
          titleEn: 'WidgetKit Background Sync & Performance Polish',
          descTr: 'App Group veri aktarım kanalı güçlendirildi; pil tüketimi optimize edilirken vakit ve seri güncellemeleri anlık hale getirildi.',
          descEn: 'Reinforced native App Group data bridge for near-instant prayer and streak widget synchronization with minimal battery impact.',
          icon: Icons.sync_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 59,
      versionName: '2.1.4',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Namaz Bildirimleri & Saat Dilimi Hassasiyeti',
          titleEn: 'Prayer Notifications & Timezone Precision',
          descTr: 'iOS için namaz vakit bildirimleri ve kaza takip ("Namazınızı Kıldınız mı? 🕌") soru hatırlatmalarının yerel saat dilimi çizelgelemesi güçlendirildi; tüm bildirimlerin tam vaktinde ulaşması sağlandı.',
          descEn: 'Enhanced local timezone scheduling for prayer entry notifications and missed prayer reminders on iOS, guaranteeing pinpoint accuracy across time zones.',
          icon: Icons.notifications_active_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Kelimeli Mushaf & Arapça Harf Bütünlüğü',
          titleEn: 'Word-by-Word Mushaf & Arabic Typography Precision',
          descTr: 'Kelimeli Mushaf, İnteraktif Talim ve Mukabele ekranlarında Arapça metin akışı, harf bitişikliği ve kelime odaklı ses takibi daha pürüzsüz ve hatasız hale getirildi.',
          descEn: 'Refined Arabic typography ligature continuity and word-by-word audio synchronicity across Mushaf reader, Interactive Talim, and Mukabele hatim screens.',
          icon: Icons.menu_book_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Kararlılık & Sistem İyileştirmeleri',
          titleEn: 'Stability & System Polish',
          descTr: 'App Store Connect ve TestFlight dağıtım altyapısı güncellendi, genel bellek yönetimi ve kullanıcı arayüzü akıcılığı artırıldı.',
          descEn: 'Updated App Store Connect and TestFlight delivery pipeline, along with general memory management and UI responsiveness enhancements.',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 58,
      versionName: '2.1.3',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Akıcı ve Hızlı Açılış Deneyimi',
          titleEn: 'Smoother & Faster Launch Experience',
          descTr: 'Uygulamanın açılış performansı baştan sona optimize edildi. Bekleme süreleri en aza indirilerek zikir ve ibadetlerinize çok daha hızlı ve akıcı şekilde ulaşmanız sağlandı.',
          descEn: 'App startup performance has been thoroughly optimized to minimize waiting time, welcoming you to your daily dhikrs and prayers faster and smoother than ever.',
          icon: Icons.flash_on_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Zarif Tema Uyumu',
          titleEn: 'Refined Theme Harmony',
          descTr: 'Açılış ekranı, cihazınızın açık ve koyu görünüm tercihlerine kusursuz uyum sağlayacak şekilde yenilendi.',
          descEn: 'The launch presentation now seamlessly harmonizes with your device light and dark appearance settings.',
          icon: Icons.palette_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Kararlılık ve Kullanım Kolaylığı',
          titleEn: 'Performance & Usability Polish',
          descTr: 'Zikir sayacı, Kur\'an okuma hedefleri ve namaz vakitleri genelinde kullanıcı deneyimini daha pürüzsüz hale getiren iyileştirmeler yapıldı.',
          descEn: 'Subtle usability refinements and stability enhancements across the dhikr counter, Quran reading goals, and prayer companion.',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 57,
      versionName: '2.1.2',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Namaz Bildirimleri & Ayarlar Konsolidasyonu',
          titleEn: 'Prayer Notifications & Settings Consolidation',
          descTr: 'Namaz vakit bildirim ayarları yenilendi! Ana aç/kapa şalteri ile tüm vakitler tek tıkla durdurulabilir; vakit bildirimleri, kaza hatırlatması ve ses tercihleri merkezi olarak yönetilir.',
          descEn: 'Prayer time notification settings have been unified! Easily toggle all reminders with a master switch, customize individual prayers, question reminders, and sound preferences centrally.',
          icon: Icons.notifications_active_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Android Namaz Vakit Widget\'ları & Canlı Senkronizasyon',
          titleEn: 'Android Prayer Widgets & Live Sync',
          descTr: 'Dijital, analog saat ve geri sayım widget\'ları arka plan alarm entegrasyonu ile daha hassas ve kesintisiz çalışacak şekilde optimize edildi.',
          descEn: 'Digital and analog prayer clock widgets and countdowns now operate with precision background alarm scheduling.',
          icon: Icons.widgets_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Kaza Takibi & Vakit Öncesi Soru Bildirimi',
          titleEn: 'Missed Prayer Tracking & Question Reminder',
          descTr: 'Vakit çıkmadan önce kaza takip hatırlatması ("Namazınızı Kıldınız mı?") ve arka plan çizelgeleme mimarisi güçlendirildi.',
          descEn: 'Pre-prayer expiry reminders and missed prayer tracking have been refined for deterministic notifications.',
          icon: Icons.mosque_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.bugFix,
          titleTr: 'Kararlılık & İzin Kontrol Rehberi',
          titleEn: 'Stability & System Permission Guidance',
          descTr: 'Xiaomi HyperOS ve Android 14 exact alarm izinleri için rehber bağlantısı eklendi, bildirim çizelgeleme döngüleri iyileştirildi.',
          descEn: 'Exact alarm permission checks for Xiaomi HyperOS / Android 14 integrated, and scheduling loops strengthened.',
          icon: Icons.verified_user_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 56,
      versionName: '2.1.1',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'Sure Rozetleri & Kümülatif Okuma Takibi',
          titleEn: 'Surah Badges & Cumulative Reading Tracker',
          descTr: 'Mülk, Vâkıa, Yâsîn, Fetih, Rahmân, Kehf ve tüm özel sureleriniz için kümülatif okuma sayaçları aktif! Her okumanız rozet kartına anında işlenir ve 40 okumada kilit açılır.',
          descEn: 'Cumulative reading counters are now active for Mulk, Waqiah, Yasin, Al-Fath, Ar-Rahman, Al-Kahf and all custom surahs! Reads advance your badge progress towards 40 reads.',
          icon: Icons.military_tech_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Kelime Takipli Dinleme & Talim Entegrasyonu',
          titleEn: 'Word-by-Word Listening & Talim Integration',
          descTr: 'Kelime takipli dinlemede sureyi tamamladığınızda okuma kaydı ve rozet ilerlemesi otomatik olarak hesabınıza işlenir.',
          descEn: 'Completing a surah in Word-by-Word listening automatically logs your reading progress and contributes to badge achievements.',
          icon: Icons.headphones_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Mushaf Son Sayfa & Anında Rozet Teklifi',
          titleEn: 'Mushaf Completion & Instant Badge Creation',
          descTr: 'Mushafta bir surenin son sayfasına geldiğinizde tek dokunuşla sûreyi okundu işaretleyebilir; henüz rozeti yoksa tek tıkla özel rozet kartı oluşturabilirsiniz.',
          descEn: 'Easily mark surahs as completed on their final page in the Mushaf, or create a new custom badge card with a single tap.',
          icon: Icons.auto_stories_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.bugFix,
          titleTr: 'Oturum & Sayaç Senkronizasyon İyileştirmesi',
          titleEn: 'Session & Counter Synchronization Fix',
          descTr: 'Sure sayaçlarının oturumlar arasında eksiksiz ve bağımsız senkronize olması sağlandı, gün atlamalarında sayaç sıfırlanma sorunu giderildi.',
          descEn: 'Fixed surah reading counters across multi-user sessions and prevented reset of cumulative reading counts on missed days.',
          icon: Icons.sync_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 55,
      versionName: '2.1.0',
      releaseDateTr: 'Eylül 2026',
      releaseDateEn: 'September 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'iOS WidgetKit & Kilit Ekranı Desteği',
          titleEn: 'iOS WidgetKit & Lock Screen Support',
          descTr: 'Ezan Vakitleri ve Günün Serisi (Streak) widget\'ları artık Ana Ekranınızda ve Kilit Ekranınızda! Namaz vakitlerini ve zikir zincirinizi anlık takip edin.',
          descEn: 'Prayer Times and Daily Streak widgets are now available on your iOS Home Screen and Lock Screen with live updates.',
          icon: Icons.widgets_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Sistem Uyumlu Akıllı Renkler',
          titleEn: 'Adaptive System Theme Support',
          descTr: 'Widget\'lar cihazınızın açık ve koyu mod dinamiklerine göre otomatik olarak adapte olur.',
          descEn: 'Widgets adapt dynamically to light and dark system color modes.',
          icon: Icons.palette_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Arka Plan Senkronizasyon İyileştirmesi',
          titleEn: 'Background Sync Engine Upgrade',
          descTr: 'Vakit değişiklikleri ve zikir istatistikleri yerel App Group köprüsü ile anlık ve verimli senkronize edilir.',
          descEn: 'Prayer calculations and dhikr progress sync seamlessly via native App Groups.',
          icon: Icons.sync_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 54,
      versionName: '2.0.10',
      releaseDateTr: 'Eylül 2026',
      releaseDateEn: 'September 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Genişletilmiş Cihaz & Ekran Desteği',
          titleEn: 'Expanded Device & Screen Support',
          descTr: 'Jiroskop ve donanım gereksinimleri optimize edilerek binlerce yeni cihaz, tablet ve katlanabilir ekran için kusursuz uyum sağlandı.',
          descEn: 'Hardware requirements were optimized to ensure full compatibility across thousands of phones, tablets, and foldables.',
          icon: Icons.devices_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'Akıllı Bulut Senkronizasyonu',
          titleEn: 'Smart Cloud Sync Engine',
          descTr: 'Zikir, hatim ve ayarlarınız cihazlar arasında otomatik ve akıllı veri uzlaştırma motoru ile güvenle senkronize edilir.',
          descEn: 'Seamlessly sync your dhikr, hatim, and settings across devices with automated reconciliation.',
          icon: Icons.cloud_sync_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Gizlilik ve İzin Hijyeni',
          titleEn: 'Privacy & Permission Hygiene',
          descTr: 'Gereksiz arka plan izinleri kaldırıldı, pil tüketimi ve sistem kaynak kullanımı minimize edildi.',
          descEn: 'Background permissions were streamlined to minimize battery drain and system footprint.',
          icon: Icons.security_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.bugFix,
          titleTr: 'Mushaf & Arayüz İyileştirmeleri',
          titleEn: 'Mushaf & UI Enhancements',
          descTr: 'Masaüstü ve geniş ekran navigasyonu ile Mushaf okuma deneyimi daha akıcı hale getirildi.',
          descEn: 'Refined Mushaf reading flow and navigation buttons on wide and desktop screens.',
          icon: Icons.menu_book_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 52,
      versionName: '2.0.9',
      releaseDateTr: 'Eylül 2026',
      releaseDateEn: 'September 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Android 15 & Google Play Optimizasyonu',
          titleEn: 'Android 15 & Google Play Optimization',
          descTr: 'Google Play en son kararlı güvenlik ve sistem politikalarına (Target SDK 35) tam uyum sağlandı.',
          descEn: 'Fully adapted to the latest Google Play security & platform standards (Target SDK 35).',
          icon: Icons.verified_user_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Hafifletilmiş ve Optimize İzinler',
          titleEn: 'Streamlined Permissions',
          descTr: 'Kullanılmayan sistem izinleri temizlendi. Uygulama artık daha az kaynak tüketiyor ve çok daha hızlı açılıyor.',
          descEn: 'Unused permissions were removed. The app consumes fewer background resources and launches faster.',
          icon: Icons.speed_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.bugFix,
          titleTr: 'Ezan & Bildirim Kararlılığı',
          titleEn: 'Prayer & Notification Stability',
          descTr: 'Arka plan vakit alarmları ve bildirim zamanlayıcıları cihaz kilitliyken dahi kusursuz çalışacak şekilde güçlendirildi.',
          descEn: 'Background prayer alarms and notification triggers were reinforced for seamless delivery while device is locked.',
          icon: Icons.notifications_active_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'Yenilikler ve Sürüm Notları Ekranı',
          titleEn: 'What\'s New & Release Notes Screen',
          descTr: 'Zikirce güncellendiğinde nelerin değiştiğini artık ilk açılışta ve Ayarlar menüsünden dilediğiniz an inceleyebilirsiniz.',
          descEn: 'Discover what is new upon updating and review release history anytime in Settings.',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 50,
      versionName: '2.0.7',
      releaseDateTr: 'Ağustos 2026',
      releaseDateEn: 'August 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'Google Drive Bulut Yedekleme & Profil Senkronizasyonu',
          titleEn: 'Google Drive Cloud Backup & Profile Sync',
          descTr: 'Zikirlerinizi, hatimlerinizi ve ayarlarınızı güvenle Google Drive hesabınıza yedekleme ve birden çok profille senkronize etme imkanı.',
          descEn: 'Safely backup dhikr, hatim, and settings to your Google Drive account with seamless multi-profile synchronization.',
          icon: Icons.cloud_done_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Widget Performans İyileştirmeleri',
          titleEn: 'Widget Performance Upgrades',
          descTr: 'Ana ekran namaz ve zikir sayaç widget\'larının pil tüketimi düşürüldü, anlık güncellemeleri hızlandırıldı.',
          descEn: 'Reduced battery impact and improved real-time updates for home screen prayer and dhikr widgets.',
          icon: Icons.widgets_rounded,
        ),
      ],
    ),
  ];

  /// Mevcut sürüm için yenilikler çekmecesinin açılması gerekiyor mu?
  /// Sadece daha önce uygulamayı kullanmış ve yeni sürüme geçmiş kullanıcılarda `true` döner.
  static Future<bool> shouldShowWhatsNew() async {
    final prefs = await SharedPreferences.getInstance();
    final targetCode = effectiveVersionCode;
    if (!prefs.containsKey(_prefKeyLastSeenVersionCode)) {
      // Eğer anahtar hiç yoksa:
      // Kullanıcı eski bir sürümden geliyorsa (örneğin onboarding tamamlanmışsa) yenilikleri göster.
      // Sıfırdan temiz kurulum yapmışsa gösterme.
      final isOnboardingCompleted = prefs.getBool('IsOnboardingCompleted') ?? false;
      if (isOnboardingCompleted) {
        return true;
      } else {
        // Yeni kurulum: Mevcut sürümü görüldü işaretle, onboarding sonrası rahatsız etme.
        await prefs.setInt(_prefKeyLastSeenVersionCode, targetCode);
        return false;
      }
    }

    final lastSeen = prefs.getInt(_prefKeyLastSeenVersionCode) ?? 0;
    return lastSeen < targetCode;
  }

  /// Mevcut sürümü görüldü olarak kaydet
  static Future<void> markCurrentVersionAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyLastSeenVersionCode, effectiveVersionCode);
  }

  /// En güncel sürüm kaydı
  static ChangelogRelease get latestRelease => releases.first;

  /// Derleme zamanı (--dart-define) veya ChangelogService üzerindeki en güncel sürüm adı
  static String get effectiveVersionName {
    const envName = String.fromEnvironment('FLUTTER_BUILD_NAME');
    if (envName.isNotEmpty) return envName;
    if (releases.isNotEmpty && releases.first.versionCode >= currentVersionCode) {
      return releases.first.versionName;
    }
    return currentVersionName;
  }

  /// Derleme zamanı (--dart-define) veya ChangelogService üzerindeki en güncel yapı numarası
  static int get effectiveVersionCode {
    const envNumber = String.fromEnvironment('FLUTTER_BUILD_NUMBER');
    final parsedEnv = int.tryParse(envNumber);
    if (parsedEnv != null && parsedEnv > 0) return parsedEnv;
    if (releases.isNotEmpty && releases.first.versionCode > currentVersionCode) {
      return releases.first.versionCode;
    }
    return currentVersionCode;
  }

  static ({String versionName, int versionCode})? _cachedRuntimeVersion;

  /// Platform (Android PackageInfo / iOS Info.plist / Masaüstü pubspec.yaml) ve
  /// ChangelogService sürümlerini karşılaştırarak en güncel (versionName, versionCode) çiftini döner.
  /// Böylece pubspec.yaml veya ChangelogService güncellendiğinde Ayarlar ekranı otomatik güncellenir.
  static Future<({String versionName, int versionCode})> getRuntimeVersion() async {
    if (_cachedRuntimeVersion != null) return _cachedRuntimeVersion!;

    String bestName = effectiveVersionName;
    int bestCode = effectiveVersionCode;

    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          const channel = MethodChannel('com.akarworks.zikirce/battery_optimization');
          final res = await channel.invokeMapMethod<String, dynamic>('getAppVersion');
          if (res != null) {
            final nativeName = (res['versionName'] as String?)?.trim() ?? '';
            final nativeCode = (res['versionCode'] as num?)?.toInt() ?? 0;
            if (nativeCode > bestCode ||
                (nativeCode == bestCode &&
                    nativeName.isNotEmpty &&
                    _compareSemVer(nativeName, bestName) > 0)) {
              bestCode = nativeCode;
              bestName = nativeName;
            }
          }
        } else if (Platform.isIOS) {
          const channel = MethodChannel('com.akarworks.zikirce/audio_background');
          final res = await channel.invokeMapMethod<String, dynamic>('getAppVersion');
          if (res != null) {
            final nativeName = (res['versionName'] as String?)?.trim() ?? '';
            final nativeCode = (res['versionCode'] as num?)?.toInt() ?? 0;
            if (nativeCode > bestCode ||
                (nativeCode == bestCode &&
                    nativeName.isNotEmpty &&
                    _compareSemVer(nativeName, bestName) > 0)) {
              bestCode = nativeCode;
              bestName = nativeName;
            }
          }
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          final pubspecFile = File('pubspec.yaml');
          if (await pubspecFile.exists()) {
            final content = await pubspecFile.readAsString();
            final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?', multiLine: true)
                .firstMatch(content);
            if (match != null) {
              final pubName = match.group(1) ?? '';
              final pubCode = int.tryParse(match.group(2) ?? '') ?? bestCode;
              if (pubCode > bestCode ||
                  (pubCode == bestCode &&
                      pubName.isNotEmpty &&
                      _compareSemVer(pubName, bestName) > 0)) {
                bestCode = pubCode;
                bestName = pubName;
              }
            }
          }
        }
      } catch (_) {
        // Fallback to effectiveVersionName / effectiveVersionCode
      }
    }

    final resolved = (versionName: bestName, versionCode: bestCode);
    _cachedRuntimeVersion = resolved;
    return resolved;
  }

  /// Dil tercihine göre standart sürüm etiketi üretir: "Versiyon 2.1.8 (Build 63)"
  static String formatVersionLabel({
    required bool isTurkish,
    String? versionName,
    int? versionCode,
  }) {
    final vName = (versionName != null && versionName.isNotEmpty) ? versionName : effectiveVersionName;
    final vCode = (versionCode != null && versionCode > 0) ? versionCode : effectiveVersionCode;
    return isTurkish ? 'Versiyon $vName (Build $vCode)' : 'Version $vName (Build $vCode)';
  }

  static int _compareSemVer(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}
