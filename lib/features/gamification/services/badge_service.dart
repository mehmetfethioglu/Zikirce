import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../models/badge_models.dart';
import '../models/user_rank.dart';

class BadgeService {
  final AppDatabase _db;

  BadgeService(this._db);

  Future<List<Badge>> getBadges() async {
    final badges = <Badge>[];

    // 1. Zikir Rozetleri (Manevi Mertebeler)
    final allRanks = UserRank.getAllRanks();
    for (final rank in allRanks) {
      final rankId = 'rank_${rank.level.value}';

      badges.add(Badge(
        id: rankId,
        category: 'Zikir',
        name: rank.name,
        description: rank.description,
        iconPath: rank.birdAnimationFile,
        emoji: rank.badge,
        glowColor: rank.glowColor,
        criteria: rank.criteriaDisplay,
        unlockCost: rank.unlockCost,
      ));
    }

    // 2. Kuran Okuma Rozetleri
    final kuranBadges = <Badge>[
      Badge(
        id: 'quran_first_step',
        category: 'Kuran',
        name: 'Nurlu Başlangıç',
        description: 'Kuran\'dan ilk sayfanızı başarıyla okuyun.',
        iconPath: 'assets/images/badge_quran_first.png',
        emoji: '📖',
        glowColor: const Color(0xFF4CAF50),
        criteria: 'İlk Kuran Sayfası',
      ),
      Badge(
        id: 'quran_10_pages',
        category: 'Kuran',
        name: 'Kuran Dostu',
        description: 'Toplamda 10 sayfa Kuran okuyarak bu mertebeye ulaşın.',
        iconPath: 'assets/images/badge_quran_10.png',
        emoji: '📜',
        glowColor: const Color(0xFF03A9F4),
        criteria: '10 Sayfa Oku',
      ),
      Badge(
        id: 'quran_100_pages',
        category: 'Kuran',
        name: 'Kuran Okuyucusu',
        description: 'Toplamda 100 sayfa Kuran okuyarak nurunuzu artırın.',
        iconPath: 'assets/images/badge_quran_100.png',
        emoji: '📚',
        glowColor: const Color(0xFFE91E63),
        criteria: '100 Sayfa Oku',
      ),
      Badge(
        id: 'waqiah_40',
        category: 'Kuran',
        name: 'Vakıa Muhafızı',
        description: '40 gün boyunca yatsıdan sonra kesintisiz Vakıa Sûresi okuyarak rızık bereketine erişin.',
        iconPath: 'assets/images/badge_waqiah.png',
        emoji: '💎',
        glowColor: const Color(0xFF2E7D32),
        criteria: '40 Gün Yatsıdan Sonra',
        targetDays: 40,
      ),
      Badge(
        id: 'mulk_40',
        category: 'Kuran',
        name: 'Mülk Muhafızı',
        description: '40 gün boyunca yatsıdan sonra kesintisiz Mülk Sûresi okuyarak kabir nuruna vesile olun.',
        iconPath: 'assets/images/badge_mulk.png',
        emoji: '🌙',
        glowColor: const Color(0xFF1565C0),
        criteria: '40 Gün Yatsıdan Sonra',
        targetDays: 40,
      ),
      Badge(
        id: 'naba_40',
        category: 'Kuran',
        name: 'Nebe Muhafızı',
        description: '40 gün boyunca ikindiden sonra kesintisiz Nebe Sûresi okuyarak müjdelere nail olun.',
        iconPath: 'assets/images/badge_naba.png',
        emoji: '☀️',
        glowColor: const Color(0xFFEF6C00),
        criteria: '40 Gün İkindiden Sonra',
        targetDays: 40,
      ),
      Badge(
        id: 'sleep_protection',
        category: 'Kuran',
        name: 'Gece Sığınağı',
        description: 'Her gün uyumadan önce Felak, Nâs ve İhlas sûrelerini okuyarak manevi koruma kalkanına sığının.',
        iconPath: 'assets/images/badge_sleep.png',
        emoji: '🛡️',
        glowColor: const Color(0xFF4A148C),
        criteria: 'Her Gün Uyumadan Önce',
        targetDays: 40,
      ),
      Badge(
        id: 'hatim_completed',
        category: 'Kuran',
        name: 'Hatim Tamamlayıcı',
        description: 'En az 1 hatmi tamamen bitirin.',
        iconPath: 'assets/images/badge_hatim.png',
        emoji: '🕌',
        glowColor: const Color(0xFF9C27B0),
        criteria: '1 Tam Hatim',
      ),
      Badge(
        id: 'hatim_3_completed',
        category: 'Kuran',
        name: 'Hatim Muhafızı',
        description: '3 tam hatmi başarıyla tamamlayıp muhafız olun.',
        iconPath: 'assets/images/badge_hatim_3.png',
        emoji: '👑',
        glowColor: const Color(0xFFFFD700),
        criteria: '3 Tam Hatim',
      ),
      Badge(
        id: 'hatim_1_month',
        category: 'Kuran',
        name: 'Hızlı Hatim',
        description: 'Herhangi bir hatmi 30 gün veya daha kısa sürede tamamlayarak bu taç rozete hak kazanın.',
        iconPath: 'assets/images/badge_hatim_fast.png',
        emoji: '⚡',
        glowColor: const Color(0xFFFFD700),
        criteria: '1 Ayda Tam Hatim',
      ),
    ];
    badges.addAll(kuranBadges);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Total Dhikr Count
      final allZikirs = await _db.select(_db.zikirs).get();
      int totalZikir = 0;
      for (final z in allZikirs) {
        totalZikir += z.totalCount;
      }
      final allLogs = await _db.select(_db.zikirLogs).get();
      int logsSum = 0;
      for (final l in allLogs) {
        logsSum += l.count;
      }
      final prefsTotal = prefs.getInt('TotalZikir') ?? prefs.getInt('TotalZikirCount') ?? 0;
      totalZikir = max(max(totalZikir, logsSum), prefsTotal);

      // Unlocked badges in DB
      final dbUnlockedList = await _db.select(_db.unlockedBadges).get();
      final Map<String, DateTime> dbUnlockedMap = {
        for (final u in dbUnlockedList) u.badgeId: u.unlockedAt
      };
      final dbUnlockedSet = dbUnlockedMap.keys.toSet();

      // Unlocked birds from prefs
      final unlockedBirdsPref = prefs.getString('UnlockedBirds') ?? '';
      final unlockedBirdsSet = unlockedBirdsPref
          .split(',')
          .where((s) => s.isNotEmpty)
          .toSet();

      // Calculate baseline earliest activity date from historical records
      DateTime earliestDate = DateTime.now();
      if (allLogs.isNotEmpty) {
        final sortedLogs = List<ZikirLog>.from(allLogs)
          ..sort((a, b) => a.dateStr.compareTo(b.dateStr));
        final parsed = DateTime.tryParse(sortedLogs.first.dateStr);
        if (parsed != null) earliestDate = parsed;
      } else if (allZikirs.isNotEmpty) {
        final sortedZikirs = List<Zikir>.from(allZikirs)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        earliestDate = sortedZikirs.first.createdAt;
      }

      // Helper to determine exact date when cumulative zikir count crossed threshold
      DateTime findRankDate(int requiredZikir) {
        if (allLogs.isEmpty) return earliestDate;
        final sortedLogs = List<ZikirLog>.from(allLogs)
          ..sort((a, b) => a.dateStr.compareTo(b.dateStr));
        int runningSum = 0;
        for (final log in sortedLogs) {
          runningSum += log.count;
          if (runningSum >= requiredZikir) {
            final d = DateTime.tryParse(log.dateStr);
            if (d != null) return d;
          }
        }
        return earliestDate;
      }

      // Persist unlock date to DB permanently so it never shifts to DateTime.now()
      Future<void> markUnlocked(Badge badge, DateTime recoveredDate, String category) async {
        badge.isUnlocked = true;
        if (dbUnlockedMap.containsKey(badge.id)) {
          badge.unlockedDate = dbUnlockedMap[badge.id];
        } else {
          badge.unlockedDate = recoveredDate;
          dbUnlockedMap[badge.id] = recoveredDate;
          try {
            await _db.into(_db.unlockedBadges).insertOnConflictUpdate(
              UnlockedBadgesCompanion.insert(
                badgeId: badge.id,
                unlockedAt: Value(recoveredDate),
                category: Value(category),
              ),
            );
          } catch (_) {}
        }
      }

      // 1. Zikir Ranks Unlock Check
      for (final rank in allRanks) {
        final rankId = 'rank_${rank.level.value}';
        final badge = badges.firstWhere((b) => b.id == rankId);
        final birdKey = rank.birdAnimationFile.split('/').last;

        if (totalZikir >= rank.requiredZikir ||
            dbUnlockedSet.contains(rankId) ||
            dbUnlockedSet.contains('bird_${rank.birdAnimationFile}') ||
            unlockedBirdsSet.contains(rank.birdAnimationFile) ||
            unlockedBirdsSet.contains(birdKey)) {
          final date = findRankDate(rank.requiredZikir);
          await markUnlocked(badge, date, 'Zikir');
        }
      }

      // 2. Kuran Pages Unlock Check
      final totalQuranPages = prefs.getInt('TotalReadPages_All') ??
          prefs.getInt('total_read_pages') ??
          0;

      final firstStepBadge = badges.firstWhere((b) => b.id == 'quran_first_step');
      if (totalQuranPages >= 1 || dbUnlockedSet.contains('quran_first_step')) {
        await markUnlocked(firstStepBadge, earliestDate, 'Kuran');
      }

      final tenPageBadge = badges.firstWhere((b) => b.id == 'quran_10_pages');
      if (totalQuranPages >= 10 || dbUnlockedSet.contains('quran_10_pages')) {
        await markUnlocked(tenPageBadge, earliestDate, 'Kuran');
      }

      final hundredPageBadge = badges.firstWhere((b) => b.id == 'quran_100_pages');
      if (totalQuranPages >= 100 || dbUnlockedSet.contains('quran_100_pages')) {
        await markUnlocked(hundredPageBadge, earliestDate, 'Kuran');
      }

      // 3. Special Surah Streaks Unlock Check
      final waqiahStreak = max(
        prefs.getInt('Streak_Waqiah') ?? 0,
        prefs.getInt('BestStreak_Waqiah') ?? 0,
      );
      final waqiahBadge = badges.firstWhere((b) => b.id == 'waqiah_40');
      waqiahBadge.targetDays = 40;
      waqiahBadge.currentStreak = waqiahStreak;
      if (waqiahStreak >= 40 || dbUnlockedSet.contains('waqiah_40')) {
        await markUnlocked(waqiahBadge, earliestDate, 'Kuran');
      }

      final mulkStreak = max(
        prefs.getInt('Streak_Mulk') ?? 0,
        prefs.getInt('BestStreak_Mulk') ?? 0,
      );
      final mulkBadge = badges.firstWhere((b) => b.id == 'mulk_40');
      mulkBadge.targetDays = 40;
      mulkBadge.currentStreak = mulkStreak;
      if (mulkStreak >= 40 || dbUnlockedSet.contains('mulk_40')) {
        await markUnlocked(mulkBadge, earliestDate, 'Kuran');
      }

      final nabaStreak = max(
        prefs.getInt('Streak_Naba') ?? 0,
        prefs.getInt('BestStreak_Naba') ?? 0,
      );
      final nabaBadge = badges.firstWhere((b) => b.id == 'naba_40');
      nabaBadge.targetDays = 40;
      nabaBadge.currentStreak = nabaStreak;
      if (nabaStreak >= 40 || dbUnlockedSet.contains('naba_40')) {
        await markUnlocked(nabaBadge, earliestDate, 'Kuran');
      }

      final sleepStreak = max(
        prefs.getInt('Streak_Sleep') ?? 0,
        prefs.getInt('BestStreak_Sleep') ?? 0,
      );
      final sleepBadge = badges.firstWhere((b) => b.id == 'sleep_protection');
      sleepBadge.targetDays = 40;
      sleepBadge.currentStreak = sleepStreak;
      if (sleepStreak >= 40 || dbUnlockedSet.contains('sleep_protection')) {
        await markUnlocked(sleepBadge, earliestDate, 'Kuran');
      }

      // 4. Hatim Unlocks Check
      final completedHatims = await (_db.select(_db.hatims)
            ..where((t) => t.isCompleted.equals(true))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
          .get();

      final hatimDate = completedHatims.isNotEmpty
          ? (completedHatims.first.targetDate ?? completedHatims.first.createdAt)
          : earliestDate;

      final hatimBadge = badges.firstWhere((b) => b.id == 'hatim_completed');
      if (completedHatims.isNotEmpty || dbUnlockedSet.contains('hatim_completed')) {
        await markUnlocked(hatimBadge, hatimDate, 'Hatim');
      }

      final hatim3Badge = badges.firstWhere((b) => b.id == 'hatim_3_completed');
      final hatim3Date = completedHatims.length >= 3
          ? (completedHatims[2].targetDate ?? completedHatims[2].createdAt)
          : hatimDate;
      if (completedHatims.length >= 3 || dbUnlockedSet.contains('hatim_3_completed')) {
        await markUnlocked(hatim3Badge, hatim3Date, 'Hatim');
      }

      final hatimFastBadge = badges.firstWhere((b) => b.id == 'hatim_1_month');
      final fastHatim = completedHatims.where((h) {
        if (h.targetDate != null) {
          final diff = h.targetDate!.difference(h.createdAt).inDays;
          return diff <= 30;
        }
        return false;
      }).firstOrNull;
      final fastHatimDate = fastHatim != null
          ? (fastHatim.targetDate ?? fastHatim.createdAt)
          : hatimDate;
      if (fastHatim != null || dbUnlockedSet.contains('hatim_1_month')) {
        await markUnlocked(hatimFastBadge, fastHatimDate, 'Hatim');
      }
    } catch (e) {
      debugPrint('[BadgeService] Error calculating badges: $e');
    }

    return badges;
  }
}
