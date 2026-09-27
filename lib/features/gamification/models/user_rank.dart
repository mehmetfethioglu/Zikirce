import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';

enum UserRankLevel {
  none(0),
  niyet(1),
  istikamet(2),
  mudavemet(3),
  sebat(4),
  azimet(5),
  ihlas(6),
  tevekul(7),
  sukur(8),
  riza(9),
  yakin(10);

  final int value;
  const UserRankLevel(this.value);
}

class UserRank {
  final UserRankLevel level;
  final String name;
  final String badge;
  final String description;
  final String privilege;
  final String birdAnimationFile;
  final int requiredZikir;
  final int nextLevelZikir;
  final Color glowColor;
  final int unlockCost;

  const UserRank({
    required this.level,
    required this.name,
    required this.badge,
    required this.description,
    required this.privilege,
    required this.birdAnimationFile,
    required this.requiredZikir,
    required this.nextLevelZikir,
    required this.glowColor,
    required this.unlockCost,
  });

  String get displayText => '$badge $name';

  String get criteriaDisplay {
    if (requiredZikir == 0) return '0+ Zikir';
    if (requiredZikir >= 1000000) {
      final m = requiredZikir ~/ 1000000;
      return '${m}M+ Zikir';
    }
    final k = requiredZikir ~/ 1000;
    return '${k}K+ Zikir';
  }

  String getLocalizedCriteria(AppLocalizations l10n) {
    final dhikrWord = l10n.isTurkish ? 'Zikir' : 'Dhikr';
    if (requiredZikir == 0) return '0+ $dhikrWord';
    if (requiredZikir >= 1000000) {
      final m = requiredZikir ~/ 1000000;
      return '${m}M+ $dhikrWord';
    }
    final k = requiredZikir ~/ 1000;
    return '${k}K+ $dhikrWord';
  }

  static UserRank calculateRank(int totalZikir) {
    if (totalZikir >= 99000000) {
      return const UserRank(
        level: UserRankLevel.yakin,
        name: 'Yakin',
        badge: '🪽',
        description: 'Keskin bir farkındalık.',
        privilege: 'Yakin Kuşu',
        birdAnimationFile: 'assets/animations/yakin_bird.json',
        requiredZikir: 99000000,
        nextLevelZikir: 999999999,
        glowColor: Color(0xFFE1BEE7),
        unlockCost: 500,
      );
    } else if (totalZikir >= 80000000) {
      return const UserRank(
        level: UserRankLevel.riza,
        name: 'Rıza',
        badge: '🕊️',
        description: 'Kalpte sükûnet.',
        privilege: 'Rıza Kuşu',
        birdAnimationFile: 'assets/animations/riza_bird.json',
        requiredZikir: 80000000,
        nextLevelZikir: 99000000,
        glowColor: Color(0xFFFFF176),
        unlockCost: 450,
      );
    } else if (totalZikir >= 63000000) {
      return const UserRank(
        level: UserRankLevel.sukur,
        name: 'Şükür',
        badge: '🦢',
        description: 'Artana şükür, azalana sabır.',
        privilege: 'Şükür Kuşu',
        birdAnimationFile: 'assets/animations/sukur_bird.json',
        requiredZikir: 63000000,
        nextLevelZikir: 80000000,
        glowColor: Color(0xFFFFD54F),
        unlockCost: 400,
      );
    } else if (totalZikir >= 40000000) {
      return const UserRank(
        level: UserRankLevel.tevekul,
        name: 'Tevekkül',
        badge: '🦚',
        description: 'Gayret + teslimiyet dengesi.',
        privilege: 'Tevekkül Kuşu',
        birdAnimationFile: 'assets/animations/tevekkul_bird.json',
        requiredZikir: 40000000,
        nextLevelZikir: 63000000,
        glowColor: Color(0xFF4DB6AC),
        unlockCost: 350,
      );
    } else if (totalZikir >= 25000000) {
      return const UserRank(
        level: UserRankLevel.ihlas,
        name: 'İhlas',
        badge: '🦅',
        description: 'Gösterişsiz, derin.',
        privilege: 'İhlas Kuşu',
        birdAnimationFile: 'assets/animations/ihlas_bird.json',
        requiredZikir: 25000000,
        nextLevelZikir: 40000000,
        glowColor: Color(0xFFAED581),
        unlockCost: 300,
      );
    } else if (totalZikir >= 15000000) {
      return const UserRank(
        level: UserRankLevel.azimet,
        name: 'Azimet',
        badge: '🦉',
        description: 'Güçlü niyet, güçlü yürüyüş.',
        privilege: 'Azimet Kuşu',
        birdAnimationFile: 'assets/animations/azimet_bird.json',
        requiredZikir: 15000000,
        nextLevelZikir: 25000000,
        glowColor: Color(0xFFFF8A65),
        unlockCost: 250,
      );
    } else if (totalZikir >= 7000000) {
      return const UserRank(
        level: UserRankLevel.sebat,
        name: 'Sebat',
        badge: '🦆',
        description: 'Zamanın imtihanı: süreklilik.',
        privilege: 'Sebat Kuşu',
        birdAnimationFile: 'assets/animations/sebat_bird.json',
        requiredZikir: 7000000,
        nextLevelZikir: 15000000,
        glowColor: Color(0xFFFFB74D),
        unlockCost: 200,
      );
    } else if (totalZikir >= 3000000) {
      return const UserRank(
        level: UserRankLevel.mudavemet,
        name: 'Müdavemet',
        badge: '🐧',
        description: 'Az da olsa devam.',
        privilege: 'Müdavemet Kuşu',
        birdAnimationFile: 'assets/animations/mudavemet_bird.json',
        requiredZikir: 3000000,
        nextLevelZikir: 7000000,
        glowColor: Color(0xFFBA68C8),
        unlockCost: 150,
      );
    } else if (totalZikir >= 1000000) {
      return const UserRank(
        level: UserRankLevel.istikamet,
        name: 'İstikamet',
        badge: '🐦',
        description: 'Düzgün adım, uzun yol.',
        privilege: 'İstikamet Kuşu',
        birdAnimationFile: 'assets/animations/istikamet_bird.json',
        requiredZikir: 1000000,
        nextLevelZikir: 3000000,
        glowColor: Color(0xFF4FC3F7),
        unlockCost: 100,
      );
    } else if (totalZikir >= 500000) {
      return const UserRank(
        level: UserRankLevel.niyet,
        name: 'Niyet',
        badge: '🐥',
        description: 'Başlangıç değil; istikamet.',
        privilege: 'Niyet Kuşu',
        birdAnimationFile: 'assets/animations/niyet_bird.json',
        requiredZikir: 500000,
        nextLevelZikir: 1000000,
        glowColor: Color(0xFF81C784),
        unlockCost: 50,
      );
    } else {
      return const UserRank(
        level: UserRankLevel.none,
        name: 'Yeni Başlayan',
        badge: '🐣',
        description: 'Yolculuk başlıyor.',
        privilege: 'Yeni Başlayan Kuşu',
        birdAnimationFile: 'assets/animations/yeni_bird.json',
        requiredZikir: 0,
        nextLevelZikir: 500000,
        glowColor: Color(0xFFA0A0A0),
        unlockCost: 0,
      );
    }
  }

  static List<UserRank> getAllRanks() {
    return [
      calculateRank(0),
      calculateRank(500000),
      calculateRank(1000000),
      calculateRank(3000000),
      calculateRank(7000000),
      calculateRank(15000000),
      calculateRank(25000000),
      calculateRank(40000000),
      calculateRank(63000000),
      calculateRank(80000000),
      calculateRank(99000000),
    ];
  }

  static UserRank? getNextRank(int totalZikir) {
    final ranks = getAllRanks();
    for (final r in ranks) {
      if (r.requiredZikir > totalZikir) {
        return r;
      }
    }
    return null;
  }
}

class BirdSelectionItem {
  final String name;
  final String fileName;
  final String badge;

  const BirdSelectionItem({
    required this.name,
    required this.fileName,
    required this.badge,
  });

  String get displayName => '$badge $name Kuşu';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BirdSelectionItem &&
          runtimeType == other.runtimeType &&
          fileName == other.fileName;

  @override
  int get hashCode => fileName.hashCode;
}

class RankDisplayItem {
  final UserRank rank;
  final bool isCurrentRank;
  final bool isUnlocked;
  final int totalZikir;

  const RankDisplayItem({
    required this.rank,
    required this.isCurrentRank,
    required this.isUnlocked,
    required this.totalZikir,
  });

  String get badge => rank.badge;
  String get name => rank.name;
  String get description => rank.description;
  String get privilege => rank.privilege;
  String get requiredZikirDisplay => rank.criteriaDisplay;
}

