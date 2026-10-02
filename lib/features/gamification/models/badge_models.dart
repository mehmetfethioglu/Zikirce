import 'package:flutter/material.dart' hide Badge;

class Badge {
  final String id;
  final String category; // "Zikir" or "Kuran"
  final String name;
  final String description;
  final String iconPath;
  final String emoji;
  bool isUnlocked;
  DateTime? unlockedDate;
  final Color glowColor;
  final String criteria;
  final int unlockCost;

  // Read count and streak progress
  int totalReadCount;
  int targetReadCount;
  int currentStreak;
  int targetDays;

  Badge({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.emoji,
    this.isUnlocked = false,
    this.unlockedDate,
    required this.glowColor,
    required this.criteria,
    this.unlockCost = 0,
    this.totalReadCount = 0,
    this.targetReadCount = 0,
    this.currentStreak = 0,
    this.targetDays = 0,
  });

  double get progressRatio {
    if (targetReadCount > 0) {
      return (totalReadCount / targetReadCount).clamp(0.0, 1.0);
    }
    if (targetDays > 0) {
      return (currentStreak / targetDays).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  String get progressText {
    if (targetReadCount > 0) {
      final streakSuffix = currentStreak > 1 ? ' • 🔥 $currentStreak Gün' : '';
      return '$totalReadCount/$targetReadCount Okuma$streakSuffix';
    }
    if (targetDays > 0) {
      return '$currentStreak/$targetDays Gün';
    }
    return '';
  }

  bool get hasStreakProgress => targetReadCount > 0 || targetDays > 0;
}

class CustomQuranBadge {
  final String id;
  final String title;
  final String scope; // "Surah", "Juz", "Page", "Hatim"
  final String scopeValue; // Surah Number ("56"), Juz ("29"), Page count ("5"), or "Hatim"
  final String scopeDisplayName;
  final int targetDays;
  int totalReadCount;
  int currentStreak;
  int bestStreak;
  bool isUnlocked;
  DateTime? unlockedDate;
  String lastReadDate;
  final String iconEmoji;
  final String glowColorHex;
  final DateTime createdDate;

  CustomQuranBadge({
    required this.id,
    required this.title,
    this.scope = 'Surah',
    this.scopeValue = '56',
    this.scopeDisplayName = 'Vakıa Sûresi',
    this.targetDays = 40,
    this.totalReadCount = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.isUnlocked = false,
    this.unlockedDate,
    this.lastReadDate = '',
    this.iconEmoji = '📖',
    this.glowColorHex = '#FF5252',
    DateTime? createdDate,
  }) : createdDate = createdDate ?? DateTime.now();

  Color get glowColor {
    try {
      final hex = glowColorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFFFF5252);
    }
  }

  double get progressRatio => targetDays > 0
      ? ((totalReadCount > 0 ? totalReadCount : currentStreak) / targetDays).clamp(0.0, 1.0)
      : 0.0;

  String get progressText {
    if (targetDays <= 0) return '';
    final count = totalReadCount > 0 ? totalReadCount : currentStreak;
    final streakSuffix = currentStreak > 1 ? ' • 🔥 $currentStreak Gün' : '';
    return '$count/$targetDays Okuma$streakSuffix';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'scope': scope,
      'scopeValue': scopeValue,
      'scopeDisplayName': scopeDisplayName,
      'targetDays': targetDays,
      'totalReadCount': totalReadCount,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'isUnlocked': isUnlocked,
      'unlockedDate': unlockedDate?.toIso8601String(),
      'lastReadDate': lastReadDate,
      'iconEmoji': iconEmoji,
      'glowColorHex': glowColorHex,
      'createdDate': createdDate.toIso8601String(),
    };
  }

  factory CustomQuranBadge.fromJson(Map<String, dynamic> json) {
    final curStreak = json['currentStreak'] as int? ?? 0;
    return CustomQuranBadge(
      id: json['id'] as String? ?? UniqueKey().toString(),
      title: json['title'] as String? ?? 'Özel Rozet',
      scope: json['scope'] as String? ?? 'Surah',
      scopeValue: json['scopeValue'] as String? ?? '56',
      scopeDisplayName: json['scopeDisplayName'] as String? ?? 'Vakıa Sûresi',
      targetDays: json['targetDays'] as int? ?? 40,
      totalReadCount: json['totalReadCount'] as int? ?? curStreak,
      currentStreak: curStreak,
      bestStreak: json['bestStreak'] as int? ?? 0,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedDate: json['unlockedDate'] != null ? DateTime.tryParse(json['unlockedDate'] as String) : null,
      lastReadDate: json['lastReadDate'] as String? ?? '',
      iconEmoji: json['iconEmoji'] as String? ?? '📖',
      glowColorHex: json['glowColorHex'] as String? ?? '#FF5252',
      createdDate: json['createdDate'] != null ? DateTime.tryParse(json['createdDate'] as String) : null,
    );
  }
}
