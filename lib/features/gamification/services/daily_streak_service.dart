import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/widget_sync_service.dart';

class DailyStreakService {
  static String getTodayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String getYesterdayStr() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  /// Records daily activity (zikir recitation, Quran reading, etc.) and updates UserStreak accordingly.
  static Future<UserStreak?> recordDailyActivity(AppDatabase db) async {
    try {
      final todayStr = getTodayStr();
      final yesterdayStr = getYesterdayStr();

      var streak = await (db.select(db.userStreaks)..limit(1)).getSingleOrNull();

      // If no UserStreaks row exists, create initial row
      if (streak == null) {
        await db.into(db.userStreaks).insert(
          UserStreaksCompanion.insert(
            currentStreak: const Value(1),
            bestStreak: const Value(1),
            totalDays: const Value(1),
            lastDate: Value(todayStr),
          ),
        );
        streak = await (db.select(db.userStreaks)..limit(1)).getSingleOrNull();
        if (streak != null) {
          await _unlockStreakBadges(db, streak.currentStreak);
          await WidgetSyncService.syncAll(db);
        }
        return streak;
      }

      final lastDate = streak.lastDate;

      // 1. If already updated for today, nothing to change
      if (lastDate == todayStr) {
        return streak;
      }

      int newStreak = streak.currentStreak;
      int newBest = streak.bestStreak;
      int newTotalDays = streak.totalDays;
      int newFreezeCount = streak.freezeCount;
      String? newLastFreezeDate = streak.lastFreezeDate;
      int xpGained = 25;

      if (lastDate == yesterdayStr) {
        // Consecutive day: Advance streak
        newStreak = streak.currentStreak + 1;
        newBest = max(newBest, newStreak);
        newTotalDays = streak.totalDays + 1;
      } else if (lastDate == null) {
        // Migrated from MAUI (with previous streak, e.g. 243) or fresh install
        if (streak.currentStreak > 0) {
          // Continuous from MAUI yesterday
          newStreak = streak.currentStreak + 1;
          newBest = max(newBest, newStreak);
          newTotalDays = max(streak.totalDays + 1, newStreak);
        } else {
          newStreak = 1;
          newBest = max(newBest, 1);
          newTotalDays = 1;
        }
      } else {
        // Gap check: Date is earlier than yesterday
        try {
          final parts = lastDate.split('-');
          final lastDateTime = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          final now = DateTime.now();
          final todayDateTime = DateTime(now.year, now.month, now.day);
          final diffDays = todayDateTime.difference(lastDateTime).inDays;

          final missedDays = diffDays - 1;

          if (missedDays >= 1 && streak.freezeCount >= missedDays) {
            // Missed N days and has enough streak shields to protect all of them!
            newFreezeCount = streak.freezeCount - missedDays;
            newLastFreezeDate = yesterdayStr;
            newStreak = streak.currentStreak + 1;
            newBest = max(newBest, newStreak);
            newTotalDays = streak.totalDays + 1;

            for (int i = 1; i <= missedDays; i++) {
              final coveredDate = lastDateTime.add(Duration(days: i));
              final coveredDateStr =
                  '${coveredDate.year}-${coveredDate.month.toString().padLeft(2, '0')}-${coveredDate.day.toString().padLeft(2, '0')}';
              await db.into(db.userStreakHistories).insert(
                UserStreakHistoriesCompanion.insert(
                  dateStr: coveredDateStr,
                  actionType: '🛡️ Kalkan Kullanıldı ($i/$missedDays)',
                  xpGained: 0,
                ),
              );
              await db.into(db.streakGapDays).insertOnConflictUpdate(
                StreakGapDaysCompanion.insert(
                  dateStr: coveredDateStr,
                  isRepaired: const Value(true),
                ),
              );
            }
          } else {
            // Broken streak: Not enough shields to bridge all missed days.
            // Consume available shields as partial recovery and register remaining in StreakGapDays.
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('BrokenStreakPreGapValue', streak.currentStreak);

            final canCover = streak.freezeCount;
            newFreezeCount = 0;
            newStreak = 1;
            newTotalDays = streak.totalDays + 1;

            for (int i = 1; i <= missedDays; i++) {
              final coveredDate = lastDateTime.add(Duration(days: i));
              final coveredDateStr =
                  '${coveredDate.year}-${coveredDate.month.toString().padLeft(2, '0')}-${coveredDate.day.toString().padLeft(2, '0')}';
              final isCovered = i <= canCover;

              await db.into(db.streakGapDays).insertOnConflictUpdate(
                StreakGapDaysCompanion.insert(
                  dateStr: coveredDateStr,
                  isRepaired: Value(isCovered),
                ),
              );

              if (isCovered) {
                await db.into(db.userStreakHistories).insert(
                  UserStreakHistoriesCompanion.insert(
                    dateStr: coveredDateStr,
                    actionType: '🛡️ Kalkan Kullanıldı (Kısmi Kurtarma)',
                    xpGained: 0,
                  ),
                );
              }
            }
          }
        } catch (_) {
          newStreak = streak.currentStreak > 0 ? streak.currentStreak + 1 : 1;
          newBest = max(newBest, newStreak);
          newTotalDays = streak.totalDays + 1;
        }
      }

      final newXp = streak.xp + xpGained;

      await (db.update(db.userStreaks)..where((t) => t.id.equals(streak!.id))).write(
        UserStreaksCompanion(
          currentStreak: Value(newStreak),
          bestStreak: Value(newBest),
          totalDays: Value(newTotalDays),
          lastDate: Value(todayStr),
          freezeCount: Value(newFreezeCount),
          lastFreezeDate: Value(newLastFreezeDate),
          xp: Value(newXp),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final curGold = prefs.getInt('GoldCount') ?? 0;
      await prefs.setInt('GoldCount', max(curGold, newXp));

      await db.into(db.userStreakHistories).insert(
        UserStreakHistoriesCompanion.insert(
          dateStr: todayStr,
          actionType: '🔥 Günlük Seri Devamı',
          xpGained: xpGained,
        ),
      );

      await _unlockStreakBadges(db, newStreak);
      await WidgetSyncService.syncAll(db);

      return await (db.select(db.userStreaks)..limit(1)).getSingleOrNull();
    } catch (e) {
      debugPrint('[DailyStreakService] Error recording daily activity: $e');
      return null;
    }
  }

  /// On app launch, check if the user already has logged activity today (e.g. zikrs/kaza)
  /// and update the streak immediately if needed.
  static Future<void> checkDailyStreakOnStartup(AppDatabase db) async {
    try {
      final todayStr = getTodayStr();
      final streak = await (db.select(db.userStreaks)..limit(1)).getSingleOrNull();
      if (streak == null) return;

      // If already recorded today, no action needed
      if (streak.lastDate == todayStr) return;

      // Check if user has performed any zikir today
      final todayLogs = await (db.select(db.zikirLogs)..where((t) => t.dateStr.equals(todayStr))).get();
      final hasTodayZikir = todayLogs.any((l) => l.count > 0);

      // Check if user has read Quran or performed prayers today
      final prefs = await SharedPreferences.getInstance();
      final todayReadPages = prefs.getInt('TodayReadPages_$todayStr') ?? 0;

      if (hasTodayZikir || todayReadPages > 0) {
        await recordDailyActivity(db);
      }
    } catch (e) {
      debugPrint('[DailyStreakService] checkDailyStreakOnStartup notice: $e');
    }
  }

  /// Returns all gap days that have not been repaired yet
  static Future<List<StreakGapDay>> getUnrepairedGapDays(AppDatabase db) async {
    try {
      return await (db.select(db.streakGapDays)
            ..where((t) => t.isRepaired.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.dateStr)]))
          .get();
    } catch (e) {
      debugPrint('[DailyStreakService] getUnrepairedGapDays error: $e');
      return [];
    }
  }

  /// Checks if the user has an active repairable gap or a historical broken streak
  static Future<bool> hasRepairableHistoricalStreak(AppDatabase db) async {
    try {
      final gaps = await getUnrepairedGapDays(db);
      if (gaps.isNotEmpty) return true;
      final streak =
          await (db.select(db.userStreaks)..limit(1)).getSingleOrNull();
      return streak != null && streak.bestStreak > streak.currentStreak;
    } catch (_) {
      return false;
    }
  }

  /// Returns all dates that were protected or repaired by shields
  static Future<Set<String>> getShieldedDates(AppDatabase db) async {
    try {
      final repairedGaps = await (db.select(db.streakGapDays)
            ..where((t) => t.isRepaired.equals(true)))
          .get();
      final historyShields = await (db.select(db.userStreakHistories)
            ..where((t) => t.actionType.like('%Kalkan%')))
          .get();

      final dates = <String>{};
      for (final gap in repairedGaps) {
        dates.add(gap.dateStr);
      }
      for (final h in historyShields) {
        dates.add(h.dateStr);
      }
      return dates;
    } catch (e) {
      debugPrint('[DailyStreakService] getShieldedDates error: $e');
      return {};
    }
  }

  /// Consumes 1 shield to repair the next unrepaired gap day, or to recover a broken streak.
  static Future<StreakRepairResult> repairNextGapDay(AppDatabase db) async {
    return repairGapDaysBatch(db, countToRepair: 1);
  }

  /// Consumes up to [countToRepair] shields to repair unrepaired gap days.
  /// If all gaps are closed, automatically reconnects and restores the streak to its record level!
  static Future<StreakRepairResult> repairGapDaysBatch(
    AppDatabase db, {
    int countToRepair = 1,
  }) async {
    try {
      final streak =
          await (db.select(db.userStreaks)..limit(1)).getSingleOrNull();
      if (streak == null || streak.freezeCount < 1) {
        return const StreakRepairResult(
          success: false,
          message: 'Yetersiz kalkan! Lütfen önce elmaslarınızla kalkan edinin.',
        );
      }

      final unrepaired = await (db.select(db.streakGapDays)
            ..where((t) => t.isRepaired.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.dateStr)]))
          .get();

      final prefs = await SharedPreferences.getInstance();

      // Case 1: StreakGapDays has unrepaired gap days
      if (unrepaired.isNotEmpty) {
        final actualRepairCount = min(countToRepair, min(streak.freezeCount, unrepaired.length));
        if (actualRepairCount <= 0) {
          return const StreakRepairResult(
            success: false,
            message: 'Onarılacak gün veya yeterli kalkan bulunamadı.',
          );
        }

        final repairedDates = <String>[];
        for (int i = 0; i < actualRepairCount; i++) {
          final gap = unrepaired[i];
          await (db.update(db.streakGapDays)
                ..where((t) => t.dateStr.equals(gap.dateStr)))
              .write(
            const StreakGapDaysCompanion(isRepaired: Value(true)),
          );

          await db.into(db.userStreakHistories).insert(
                UserStreakHistoriesCompanion.insert(
                  dateStr: gap.dateStr,
                  actionType: '🛡️ Eksik Gün Kurtarıldı (${gap.dateStr})',
                  xpGained: 0,
                ),
              );
          repairedDates.add(gap.dateStr);
        }

        final newFreezeCount = streak.freezeCount - actualRepairCount;
        final remainingCount = unrepaired.length - actualRepairCount;

        if (remainingCount == 0) {
          final preGapVal =
              prefs.getInt('BrokenStreakPreGapValue') ?? streak.bestStreak;
          final newStreak = preGapVal + streak.currentStreak;

          await (db.update(db.userStreaks)
                ..where((t) => t.id.equals(streak.id)))
              .write(
            UserStreaksCompanion(
              currentStreak: Value(newStreak),
              bestStreak: Value(max(streak.bestStreak, newStreak)),
              freezeCount: Value(newFreezeCount),
            ),
          );

          await prefs.remove('BrokenStreakPreGapValue');
          await _unlockStreakBadges(db, newStreak);
          await WidgetSyncService.syncAll(db);

          return StreakRepairResult(
            success: true,
            repairedDate: repairedDates.join(', '),
            repairedCount: actualRepairCount,
            isFullyRestored: true,
            restoredStreak: newStreak,
            remainingGaps: 0,
            message:
                'Tebrikler! Bütün eksik günler kapatıldı ve seriniz $newStreak güne yeniden birleşti! 🎉',
          );
        } else {
          await (db.update(db.userStreaks)
                ..where((t) => t.id.equals(streak.id)))
              .write(
            UserStreaksCompanion(freezeCount: Value(newFreezeCount)),
          );

          await WidgetSyncService.syncAll(db);
          return StreakRepairResult(
            success: true,
            repairedDate: repairedDates.join(', '),
            repairedCount: actualRepairCount,
            isFullyRestored: false,
            remainingGaps: remainingCount,
            message:
                '$actualRepairCount gün kalkanla kurtarıldı! Serinizin birleşmesi için kalan $remainingCount günü daha sonra kalkan/elmas ile kurtarabilirsiniz.',
          );
        }
      }

      // Case 2: Historical fallback (streak broke before StreakGapDays was logged)
      if (streak.bestStreak > streak.currentStreak) {
        final restoredStreak = streak.bestStreak;
        final newFreezeCount = streak.freezeCount - 1;

        await (db.update(db.userStreaks)..where((t) => t.id.equals(streak.id)))
            .write(
          UserStreaksCompanion(
            freezeCount: Value(newFreezeCount),
            currentStreak: Value(restoredStreak),
          ),
        );

        final yesterdayStr = getYesterdayStr();
        await db.into(db.userStreakHistories).insert(
              UserStreakHistoriesCompanion.insert(
                dateStr: yesterdayStr,
                actionType:
                    '🛡️ Kırılan Seri Kalkanla Kurtarıldı ($restoredStreak Gün)',
                xpGained: 0,
              ),
            );

        await WidgetSyncService.syncAll(db);

        return StreakRepairResult(
          success: true,
          repairedDate: yesterdayStr,
          repairedCount: 1,
          isFullyRestored: true,
          restoredStreak: restoredStreak,
          remainingGaps: 0,
          message:
              'Eski rekor seriniz ($restoredStreak gün) 1 kalkan kullanılarak başarıyla kurtarıldı! 🎉',
        );
      }

      return const StreakRepairResult(
        success: false,
        message: 'Kurtarılacak eksik gün veya kırık seri bulunamadı.',
      );
    } catch (e) {
      debugPrint('[DailyStreakService] repairGapDaysBatch error: $e');
      return StreakRepairResult(
        success: false,
        message: 'Onarım sırasında hata oluştu: $e',
      );
    }
  }

  static Future<void> _unlockStreakBadges(AppDatabase db, int streakCount) async {
    final streakBadges = <String, int>{
      'streak_3': 3,
      'streak_7': 7,
      'streak_30': 30,
    };

    for (final entry in streakBadges.entries) {
      if (streakCount >= entry.value) {
        final existing = await (db.select(db.unlockedBadges)..where((t) => t.badgeId.equals(entry.key))).getSingleOrNull();
        if (existing == null) {
          await db.into(db.unlockedBadges).insert(
            UnlockedBadgesCompanion.insert(
              badgeId: entry.key,
              unlockedAt: Value(DateTime.now()),
              category: const Value('Zikir'),
            ),
          );
        }
      }
    }
  }
}

class StreakRepairResult {
  final bool success;
  final String? repairedDate;
  final int repairedCount;
  final bool isFullyRestored;
  final int restoredStreak;
  final int remainingGaps;
  final String message;

  const StreakRepairResult({
    required this.success,
    this.repairedDate,
    this.repairedCount = 1,
    this.isFullyRestored = false,
    this.restoredStreak = 0,
    this.remainingGaps = 0,
    required this.message,
  });
}

