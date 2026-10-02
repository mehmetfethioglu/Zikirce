import 'package:flutter/material.dart';
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
  static const int currentVersionCode = 56;
  static const String currentVersionName = '2.1.1';

  /// Sürüm geçmişi (En yeni sürüm en başta yer alır)
  static const List<ChangelogRelease> releases = [
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
    if (!prefs.containsKey(_prefKeyLastSeenVersionCode)) {
      // Eğer anahtar hiç yoksa:
      // Kullanıcı eski bir sürümden geliyorsa (örneğin onboarding tamamlanmışsa) yenilikleri göster.
      // Sıfırdan temiz kurulum yapmışsa gösterme.
      final isOnboardingCompleted = prefs.getBool('IsOnboardingCompleted') ?? false;
      if (isOnboardingCompleted) {
        return true;
      } else {
        // Yeni kurulum: Mevcut sürümü görüldü işaretle, onboarding sonrası rahatsız etme.
        await prefs.setInt(_prefKeyLastSeenVersionCode, currentVersionCode);
        return false;
      }
    }

    final lastSeen = prefs.getInt(_prefKeyLastSeenVersionCode) ?? 0;
    return lastSeen < currentVersionCode;
  }

  /// Mevcut sürümü görüldü olarak kaydet
  static Future<void> markCurrentVersionAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyLastSeenVersionCode, currentVersionCode);
  }

  /// En güncel sürüm kaydı
  static ChangelogRelease get latestRelease => releases.first;
}
