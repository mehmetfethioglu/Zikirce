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

  Future<List<Badge>> getBadges([String? sessionId]) async {
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
        description: '40 defa Vâkıa Sûresi okuyarak rızık ve bereket kapılarına erişin.',
        iconPath: 'assets/images/badge_waqiah.png',
        emoji: '💎',
        glowColor: const Color(0xFF2E7D32),
        criteria: '40 Okuma Hedefi',
        targetReadCount: 40,
        targetDays: 40,
      ),
      Badge(
        id: 'mulk_40',
        category: 'Kuran',
        name: 'Mülk Muhafızı',
        description: '40 defa Mülk Sûresi okuyarak kabir nuruna ve manevi şefaate vesile olun.',
        iconPath: 'assets/images/badge_mulk.png',
        emoji: '🌙',
        glowColor: const Color(0xFF1565C0),
        criteria: '40 Okuma Hedefi',
        targetReadCount: 40,
        targetDays: 40,
      ),
      Badge(
        id: 'naba_40',
        category: 'Kuran',
        name: 'Nebe Muhafızı',
        description: '40 defa Nebe Sûresi okuyarak büyük müjdelere ve hakikate nail olun.',
        iconPath: 'assets/images/badge_naba.png',
        emoji: '☀️',
        glowColor: const Color(0xFFEF6C00),
        criteria: '40 Okuma Hedefi',
        targetReadCount: 40,
        targetDays: 40,
      ),
      Badge(
        id: 'yasin_40',
        category: 'Kuran',
        name: 'Yâsîn Muhafızı',
        description: '40 defa Yâsîn-i Şerîf okuyarak kalplerin nuruna ve hacetlerin kabulüne erişin.',
        iconPath: 'assets/images/badge_quran_first.png',
        emoji: '💚',
        glowColor: const Color(0xFF00897B),
        criteria: '40 Okuma Hedefi',
        targetReadCount: 40,
        targetDays: 40,
      ),
      Badge(
        id: 'fetih_40',
        category: 'Kuran',
        name: 'Fetih Muhafızı',
        description: '40 defa Fetih Sûresi okuyarak manevi zafer ve hayırlı kapıların açılmasına vesile olun.',
        iconPath: 'assets/images/badge_quran_10.png',
        emoji: '🗡️',
        glowColor: const Color(0xFFD81B60),
        criteria: '40 Okuma Hedefi',
        targetReadCount: 40,
        targetDays: 40,
      ),
      Badge(
        id: 'rahman_40',
        category: 'Kuran',
        name: 'Rahmân Muhafızı',
        description: '40 defa Rahmân Sûresi okuyarak sonsuz nimetlerin şükrüne nail olun.',
        iconPath: 'assets/images/badge_quran_100.png',
        emoji: '🌸',
        glowColor: const Color(0xFF8E24AA),
        criteria: '40 Okuma Hedefi',
        targetReadCount: 40,
        targetDays: 40,
      ),
      Badge(
        id: 'kehf_40',
        category: 'Kuran',
        name: 'Kehf Muhafızı',
        description: '40 defa Kehf Sûresi okuyarak Cuma günlerinin nuruna ve fitnelerden korunma kalkanına sığının.',
        iconPath: 'assets/images/badge_quran_first.png',
        emoji: '⛰️',
        glowColor: const Color(0xFF5D4037),
        criteria: '40 Okuma Hedefi',
        targetReadCount: 40,
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
        criteria: '40 Günlük Vird',
        targetReadCount: 40,
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
      final logsSumRow = await _db.customSelect(
        'SELECT COALESCE(SUM(count), 0) as total FROM zikir_logs',
        readsFrom: {_db.zikirLogs},
      ).getSingleOrNull();
      final logsSum = logsSumRow?.read<int>('total') ?? 0;
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
      final minDateRow = await _db.customSelect(
        'SELECT MIN(date_str) as min_date FROM zikir_logs',
        readsFrom: {_db.zikirLogs},
      ).getSingleOrNull();
      final minDateStr = minDateRow?.read<String?>('min_date');
      if (minDateStr != null) {
        final parsed = DateTime.tryParse(minDateStr);
        if (parsed != null) earliestDate = parsed;
      } else if (allZikirs.isNotEmpty) {
        final sortedZikirs = List<Zikir>.from(allZikirs)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        earliestDate = sortedZikirs.first.createdAt;
      }

      // Query daily sums chronologically once without loading raw log objects
      final dailySumsRows = await _db.customSelect(
        'SELECT date_str, SUM(count) as day_sum FROM zikir_logs GROUP BY date_str ORDER BY date_str ASC',
        readsFrom: {_db.zikirLogs},
      ).get();

      final dailySums = dailySumsRows.map((r) => (
        dateStr: r.read<String>('date_str'),
        sum: r.read<int>('day_sum'),
      )).toList();

      // Helper to determine exact date when cumulative zikir count crossed threshold
      DateTime findRankDate(int requiredZikir) {
        if (dailySums.isEmpty) return earliestDate;
        int runningSum = 0;
        for (final entry in dailySums) {
          runningSum += entry.sum;
          if (runningSum >= requiredZikir) {
            final d = DateTime.tryParse(entry.dateStr);
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

      // 3. Special Surah Streaks & Read Counts Unlock Check
      int getSessionInt(String baseKey) {
        final isDefault = sessionId == null || sessionId.isEmpty || sessionId == 'default_user';
        final sfx = isDefault ? '' : '_$sessionId';
        return prefs.getInt('$baseKey$sfx') ?? (isDefault ? prefs.getInt(baseKey) ?? 0 : 0);
      }

      final surahBadgeConfigs = [
        (badgeId: 'waqiah_40', key: 'Waqiah'),
        (badgeId: 'mulk_40', key: 'Mulk'),
        (badgeId: 'naba_40', key: 'Naba'),
        (badgeId: 'yasin_40', key: 'Yasin'),
        (badgeId: 'fetih_40', key: 'Fetih'),
        (badgeId: 'rahman_40', key: 'Rahman'),
        (badgeId: 'kehf_40', key: 'Kehf'),
        (badgeId: 'sleep_protection', key: 'Sleep'),
      ];

      for (final cfg in surahBadgeConfigs) {
        final streak = max(
          getSessionInt('Streak_${cfg.key}'),
          getSessionInt('BestStreak_${cfg.key}'),
        );
        final readCountRaw = getSessionInt('ReadCount_${cfg.key}');
        // Migration: If readCount is 0 but streak exists, use streak as readCount
        final readCount = max(readCountRaw, streak);

        final badge = badges.firstWhere((b) => b.id == cfg.badgeId);
        badge.targetReadCount = 40;
        badge.targetDays = 40;
        badge.totalReadCount = readCount;
        badge.currentStreak = streak;

        if (readCount >= 40 || streak >= 40 || dbUnlockedSet.contains(cfg.badgeId)) {
          await markUnlocked(badge, earliestDate, 'Kuran');
        }
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
