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
  static const int currentVersionCode = 11;
  static const String currentVersionName = '2.0.0';

  /// Sürüm geçmişi (En yeni sürüm en başta yer alır)
  static const List<ChangelogRelease> releases = [
    ChangelogRelease(
      versionCode: 11,
      versionName: '2.0.0',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: '⚔️ Bio-Guardians RPG & 3D Pixar Düello Arenası',
          titleEn: '⚔️ Bio-Guardians RPG & 3D Pixar Duel Arena',
          descTr: 'Barkodu taranan ürünlerdeki katkı maddeleri, emülgatörler ve yasaklı içerikler artık 3D Toksik Boss\'a dönüşüyor! Kendi 3D Pixar Muhafızlarınla düelloya gir.',
          descEn: 'Additives, emulsifiers, and restricted ingredients in scanned barcodes now spawn 3D Toxic Bosses! Battle them with your 3D Pixar Bio-Guardians.',
          icon: Icons.sports_mma_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: '🧬 3D Pixar Animoji Stüdyosu & Kişisel OrganicScore',
          titleEn: '🧬 3D Pixar Animoji Studio & Personal OrganicScore',
          descTr: 'Taranan ürünlerde "Aldım / Rafa Bıraktım" seçimiyle kendi Yaşayan Kişisel OrganicScore\'unu yükselt ve Boy/Kilo verine göre şekillenen 3D karakterini özelleştir.',
          descEn: 'Boost your Living Personal OrganicScore with "Bought / Left on Shelf" feedback and customize your 3D Pixar avatar synced with your height and weight.',
          icon: Icons.face_retouching_natural_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: '🏃‍♂️ Adımsayar, Detoks Görevleri & Akıllı Saat Köprüsü',
          titleEn: '🏃‍♂️ Step Counter, Detox Quests & Smartwatch Bridge',
          descTr: 'Health Connect, Apple Watch ve cihaz adımsayarınla attığın her 1.000 adımı Biyo-Enerjiye dönüştür ve Detoks görevlerini tamamla!',
          descEn: 'Convert every 1,000 steps into Bio-Energy via Health Connect, Apple Watch, and device pedometer to complete metabolic Detox Quests!',
          icon: Icons.directions_walk_rounded,
        ),
      ],
    ),
    ChangelogRelease(
      versionCode: 10,
      versionName: '1.0.5',
      releaseDateTr: 'October 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'Otonom yiletirme: lgili grev mimari stan',
          titleEn: 'Autonomous Improvement: Task verified an',
          descTr: 'Otonom yiletirme: lgili grev mimari standartlara uygun olarak tamamland ve doruland.',
          descEn: 'Autonomous Improvement: Task verified and implemented adhering to architecture standards.',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    ),

    ChangelogRelease(
      versionCode: 9,
      versionName: '1.0.4',
      releaseDateTr: 'Ekim 2026',
      releaseDateEn: 'October 2026',
      items: [
        ChangelogItem(
          type: ChangelogType.newFeature,
          titleTr: 'Otonom Fabrika Entegrasyonu & Sürüm Notları',
          titleEn: 'Autonomous Factory Integration & What\'s New',
          descTr: 'Akarworks otonom yazılım fabrikası entegrasyonu tamamlandı. Artık her güncellemede yenilikler anında telefonunuzda!',
          descEn: 'Akarworks autonomous software factory integration completed. Release notes now appear automatically on update!',
          icon: Icons.auto_awesome_rounded,
        ),
        ChangelogItem(
          type: ChangelogType.improvement,
          titleTr: 'Taklit & Tağşiş Listesi Doğrulaması',
          titleEn: 'Food Authenticity & Adulteration Checks',
          descTr: 'Bakanlık taklit ve tağşiş veri setleri doğrulamaları optimize edildi, arama hızı artırıldı.',
          descEn: 'Ministry adulteration datasets and brand matching algorithms have been optimized.',
          icon: Icons.verified_user_rounded,
        ),
      ],
    ),
  ];

  /// Uygulama ilk açıldığında sürüm kontrolü yapar ve gerekiyorsa pop-up gösterir
  static Future<void> checkAndShowOnStartup(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt(_prefKeyLastSeenVersionCode) ?? 0;

      if (currentVersionCode > lastSeen) {
        if (!context.mounted) return;
        await showChangelogModal(context, release: releases.first);
        await prefs.setInt(_prefKeyLastSeenVersionCode, currentVersionCode);
      }
    } catch (e) {
      debugPrint('[ChangelogService] Kontrol hatası: $e');
    }
  }

  /// Ayarlar veya Profil ekranından geçmiş sürümleri görüntüleme modalı
  static Future<void> showHistory(BuildContext context) async {
    await showChangelogModal(context, release: releases.first, isHistory: true);
  }

  /// Sürüm notları BottomSheet penceresi
  static Future<void> showChangelogModal(
    BuildContext context, {
    required ChangelogRelease release,
    bool isHistory = false,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.new_releases_rounded,
                      color: Color(0xFF4CAF50),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale == 'tr' ? 'Neler Yeni?' : 'What\'s New?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'v${release.versionName} (${release.getReleaseDate(locale)})',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: release.items.map((item) {
                      Color badgeColor;
                      String badgeText;
                      switch (item.type) {
                        case ChangelogType.newFeature:
                          badgeColor = const Color(0xFF4CAF50);
                          badgeText = locale == 'tr' ? 'YENİ' : 'NEW';
                          break;
                        case ChangelogType.improvement:
                          badgeColor = const Color(0xFF2196F3);
                          badgeText = locale == 'tr' ? 'GELİŞTİRME' : 'IMPROVE';
                          break;
                        case ChangelogType.bugFix:
                          badgeColor = const Color(0xFFFF9800);
                          badgeText = locale == 'tr' ? 'DÜZELTME' : 'FIX';
                          break;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF27273A) : const Color(0xFFF7F9FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item.icon, color: badgeColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          badgeText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.getTitle(locale),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.getDescription(locale),
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  locale == 'tr' ? 'Anladım, Devam Et' : 'Got it, Continue',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
