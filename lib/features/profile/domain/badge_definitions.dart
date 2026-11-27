import 'package:flutter/material.dart';

enum BadgeCategory {
  scanner,
  crowdsource,
  boycott,
  health,
}

enum BadgeTier {
  bronze,
  silver,
  gold,
}

class BadgeItem {
  final String id;
  final String title;
  final String description;
  final String iconEmoji;
  final IconData iconData;
  final BadgeCategory category;
  final BadgeTier tier;
  final int targetCount;
  final int xpReward;

  const BadgeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.iconEmoji,
    required this.iconData,
    required this.category,
    required this.tier,
    required this.targetCount,
    required this.xpReward,
  });

  Color get tierColor {
    switch (tier) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFFC0C0C0);
      case BadgeTier.gold:
        return const Color(0xFFFFD700);
    }
  }

  String get tierName {
    switch (tier) {
      case BadgeTier.bronze:
        return 'Bronz';
      case BadgeTier.silver:
        return 'Gümüş';
      case BadgeTier.gold:
        return 'Altın';
    }
  }
}

class BadgeDefinitions {
  static const List<BadgeItem> allBadges = [
    // 1. Tarama & Keşif Rozetleri
    BadgeItem(
      id: 'scan_bronze',
      title: 'İlk Adım',
      description: 'İlk gıda barkodu veya etiketini tara.',
      iconEmoji: '🔍',
      iconData: Icons.search_rounded,
      category: BadgeCategory.scanner,
      tier: BadgeTier.bronze,
      targetCount: 1,
      xpReward: 30,
    ),
    BadgeItem(
      id: 'scan_silver',
      title: 'Market Dedektifi',
      description: 'Toplam 20 farklı ürün incelemesi tamamla.',
      iconEmoji: '🕵️',
      iconData: Icons.manage_search_rounded,
      category: BadgeCategory.scanner,
      tier: BadgeTier.silver,
      targetCount: 20,
      xpReward: 120,
    ),
    BadgeItem(
      id: 'scan_gold',
      title: 'Etiket Uzmanı',
      description: 'Toplam 100 ürünün E-kodlarını ve analizini tara.',
      iconEmoji: '🥇',
      iconData: Icons.military_tech_rounded,
      category: BadgeCategory.scanner,
      tier: BadgeTier.gold,
      targetCount: 100,
      xpReward: 350,
    ),

    // 2. Topluluk & Açık Veri Katkısı Rozetleri
    BadgeItem(
      id: 'contrib_bronze',
      title: 'Gönüllü Katkıcı',
      description: 'Veritabanında bulunmayan ilk yeni ürünü veya etiket fotoğrafını yükle.',
      iconEmoji: '🤝',
      iconData: Icons.volunteer_activism_rounded,
      category: BadgeCategory.crowdsource,
      tier: BadgeTier.bronze,
      targetCount: 1,
      xpReward: 60,
    ),
    BadgeItem(
      id: 'contrib_silver',
      title: 'Topluluk Kahramanı',
      description: 'Açık gıda arşivine 5 yeni ürün veya içerik düzeltmesi ekle.',
      iconEmoji: '🌟',
      iconData: Icons.auto_awesome_rounded,
      category: BadgeCategory.crowdsource,
      tier: BadgeTier.silver,
      targetCount: 5,
      xpReward: 200,
    ),
    BadgeItem(
      id: 'contrib_gold',
      title: 'Açık Veri Öncüsü',
      description: '20 topluluk ürünüyle binlerce tüketiciye rehberlik et.',
      iconEmoji: '👑',
      iconData: Icons.workspace_premium_rounded,
      category: BadgeCategory.crowdsource,
      tier: BadgeTier.gold,
      targetCount: 20,
      xpReward: 600,
    ),

    // 3. Gazze & Etik Muhafızı Rozetleri
    BadgeItem(
      id: 'boycott_bronze',
      title: 'Bilinçli Tüketici',
      description: 'İlk boykot incelemesini yap veya hatalı etiket bildirimi gönder.',
      iconEmoji: '🛡️',
      iconData: Icons.shield_outlined,
      category: BadgeCategory.boycott,
      tier: BadgeTier.bronze,
      targetCount: 1,
      xpReward: 50,
    ),
    BadgeItem(
      id: 'boycott_silver',
      title: 'Etik Muhafız',
      description: '5 boykot doğrulama veya yerli alternatif katkısında bulun.',
      iconEmoji: '⚔️',
      iconData: Icons.shield_rounded,
      category: BadgeCategory.boycott,
      tier: BadgeTier.silver,
      targetCount: 5,
      xpReward: 180,
    ),
    BadgeItem(
      id: 'boycott_gold',
      title: 'Gazze & Adalet Savunucusu',
      description: '15 boykot ve etik kaynak incelemesiyle boykot zincirini güçlendir.',
      iconEmoji: '🕊️',
      iconData: Icons.verified_user_rounded,
      category: BadgeCategory.boycott,
      tier: BadgeTier.gold,
      targetCount: 15,
      xpReward: 500,
    ),

    // 4. Sağlık & Temiz İçerik Tercihleri
    BadgeItem(
      id: 'health_bronze',
      title: 'Yeşil Tercih',
      description: '5 adet 80+ puanlı temiz/organik gıda tara.',
      iconEmoji: '🌿',
      iconData: Icons.eco_outlined,
      category: BadgeCategory.health,
      tier: BadgeTier.bronze,
      targetCount: 5,
      xpReward: 50,
    ),
    BadgeItem(
      id: 'health_silver',
      title: 'Organik Öncüsü',
      description: '25 adet katkısız ve temiz etiketli gıda keşfet.',
      iconEmoji: '🌱',
      iconData: Icons.spa_rounded,
      category: BadgeCategory.health,
      tier: BadgeTier.silver,
      targetCount: 25,
      xpReward: 220,
    ),
  ];

  static BadgeItem? findById(String id) {
    for (final b in allBadges) {
      if (b.id == id) return b;
    }
    return null;
  }
}
