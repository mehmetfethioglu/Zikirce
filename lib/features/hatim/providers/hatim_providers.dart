import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import '../../gamification/providers/gamification_providers.dart';
import '../../gamification/services/daily_streak_service.dart';

final hatimListStreamProvider = StreamProvider<List<Hatim>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.hatims).watch();
});

/// Watches the most recently created active Mukabele Hatim
final activeMukabeleHatimProvider = StreamProvider<Hatim?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.hatims)
        ..where((t) =>
            (t.id.like('mukabele_%') | t.title.like('%Mukabele%') | t.title.like('%mukabele%')) &
            t.isCompleted.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
        ..limit(1))
      .watchSingleOrNull();
});

final hatimJuzProgressProvider =
    StreamProvider.family<List<HatimCuzProgressesData>, String>((ref, hatimId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.hatimCuzProgresses)
        ..where((t) => t.hatimId.equals(hatimId))
        ..orderBy([(t) => OrderingTerm(expression: t.juzNo, mode: OrderingMode.asc)]))
      .watch();
});

class HatimStats {
  final Map<String, int> todayPagesByHatim;
  final Map<String, DateTime?> lastReadByHatim;
  final int overallTodayPages;

  const HatimStats({
    this.todayPagesByHatim = const {},
    this.lastReadByHatim = const {},
    this.overallTodayPages = 0,
  });
}

final hatimStatsProvider = FutureProvider<HatimStats>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final db = ref.watch(databaseProvider);
  final hatims = await db.select(db.hatims).get();

  final todayPagesMap = <String, int>{};
  final lastReadMap = <String, DateTime?>{};

  for (final h in hatims) {
    final hatimToday = prefs.getInt('HatimTodayPages_${h.id}_$todayStr') ?? 0;
    todayPagesMap[h.id] = hatimToday;

    final lastReadStr = prefs.getString('HatimLastReadDate_${h.id}');
    if (lastReadStr != null) {
      lastReadMap[h.id] = DateTime.tryParse(lastReadStr);
    } else {
      lastReadMap[h.id] = h.createdAt;
    }
  }

  final overallToday = prefs.getInt('TodayReadPages_$todayStr') ?? 0;

  return HatimStats(
    todayPagesByHatim: todayPagesMap,
    lastReadByHatim: lastReadMap,
    overallTodayPages: overallToday,
  );
});

class HatimNotifier extends StateNotifier<void> {
  final Ref ref;

  HatimNotifier(this.ref) : super(null);

  Future<void> createHatim({
    required String title,
    required bool isGroup,
    DateTime? targetDate,
  }) async {
    final db = ref.read(databaseProvider);
    final id = 'hatim_${DateTime.now().millisecondsSinceEpoch}';

    try {
      await db.transaction(() async {
        await db.into(db.hatims).insert(
          HatimsCompanion.insert(
            id: id,
            title: title,
            isGroup: Value(isGroup),
            targetDate: Value(targetDate),
          ),
        );

        // Create 30 Juz progress items
        for (int j = 1; j <= 30; j++) {
          await db.into(db.hatimCuzProgresses).insert(
            HatimCuzProgressesCompanion.insert(
              hatimId: id,
              juzNo: j,
              isCompleted: const Value(false),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('[HatimNotifier] createHatim DB error: $e');
    }
  }

  Future<void> toggleJuzCompletion(String hatimId, int juzNo, bool isCompleted) async {
    final db = ref.read(databaseProvider);
    final prefs = await SharedPreferences.getInstance();
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    try {
      await db.transaction(() async {
        await (db.update(db.hatimCuzProgresses)
              ..where((t) => t.hatimId.equals(hatimId) & t.juzNo.equals(juzNo)))
            .write(
          HatimCuzProgressesCompanion(
            isCompleted: Value(isCompleted),
            completedAt: Value(isCompleted ? DateTime.now() : null),
          ),
        );

        // Update total completed pages
        final allJuz = await (db.select(db.hatimCuzProgresses)..where((t) => t.hatimId.equals(hatimId))).get();
        final completedCount = allJuz.where((j) => j.isCompleted).length;
        final compPages = completedCount * 20;

        await (db.update(db.hatims)..where((t) => t.id.equals(hatimId))).write(
          HatimsCompanion(
            completedPages: Value(compPages),
            isCompleted: Value(completedCount >= 30),
          ),
        );
      });
    } catch (e) {
      debugPrint('[HatimNotifier] toggleJuzCompletion DB error: $e');
    }

    if (isCompleted) {
      final activeSession = ref.read(activeSessionProvider);
      final isDefault = activeSession.id == UserSession.defaultSessionId;
      final sessionTodayKey = isDefault ? 'TodayReadPages_$todayStr' : 'TodayReadPages_${todayStr}_${activeSession.id}';
      final sessionTotalKey = isDefault ? 'TotalReadQuranPages' : 'TotalReadQuranPages_${activeSession.id}';

      final curToday = prefs.getInt(sessionTodayKey) ?? prefs.getInt('TodayReadPages_$todayStr') ?? 0;
      await prefs.setInt(sessionTodayKey, curToday + 20);
      if (!isDefault) {
        await prefs.setInt('TodayReadPages_$todayStr', curToday + 20);
      }

      final curHatimToday = prefs.getInt('HatimTodayPages_${hatimId}_$todayStr') ?? 0;
      await prefs.setInt('HatimTodayPages_${hatimId}_$todayStr', curHatimToday + 20);
      await prefs.setString('HatimLastReadDate_$hatimId', DateTime.now().toIso8601String());

      final totalReadPages = (prefs.getInt(sessionTotalKey) ?? prefs.getInt('TotalReadQuranPages') ?? 0) + 20;
      await prefs.setInt(sessionTotalKey, totalReadPages);
      if (!isDefault) {
        await prefs.setInt('TotalReadQuranPages', totalReadPages);
      }

      await DailyStreakService.recordDailyActivity(db);
      ref.read(badgeRefreshTriggerProvider.notifier).state++;
    }
  }

  Future<void> updateHatimPageProgress({
    required String hatimId,
    required int targetPage,
  }) async {
    final db = ref.read(databaseProvider);
    final prefs = await SharedPreferences.getInstance();
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    Hatim? hatim;
    try {
      hatim = await (db.select(db.hatims)..where((t) => t.id.equals(hatimId))).getSingleOrNull();
    } catch (e) {
      debugPrint('[HatimNotifier] updateHatimPageProgress select error: $e');
    }
    if (hatim == null) return;

    final oldPages = hatim.completedPages;
    final newPages = targetPage > oldPages ? targetPage : oldPages;
    final isDone = newPages >= 604;

    try {
      await db.transaction(() async {
        // Update Hatim table
        await (db.update(db.hatims)..where((t) => t.id.equals(hatimId))).write(
          HatimsCompanion(
            completedPages: Value(newPages),
            isCompleted: Value(isDone),
          ),
        );

        // Update 30 Juz progress
        final completedJuzCount = (newPages / 20).floor().clamp(0, 30);
        for (int j = 1; j <= 30; j++) {
          if (j <= completedJuzCount) {
            await (db.update(db.hatimCuzProgresses)
                  ..where((t) => t.hatimId.equals(hatimId) & t.juzNo.equals(j)))
                .write(
              HatimCuzProgressesCompanion(
                isCompleted: const Value(true),
                completedAt: Value(DateTime.now()),
              ),
            );
          }
        }
      });
    } catch (e) {
      debugPrint('[HatimNotifier] updateHatimPageProgress DB transaction error: $e');
    }

    // Award XP & Track Reading Pages (Only when advancing forward)
    final pagesDelta = (targetPage - oldPages).clamp(0, 604);
    if (pagesDelta > 0) {
      final xpGained = pagesDelta * 20;
      await ref.read(gamificationNotifierProvider).addGold(xpGained);

      // Record today's read pages (overall & per hatim & per session)
      final activeSession = ref.read(activeSessionProvider);
      final isDefault = activeSession.id == UserSession.defaultSessionId;
      final sessionTodayKey = isDefault ? 'TodayReadPages_$todayStr' : 'TodayReadPages_${todayStr}_${activeSession.id}';
      final sessionTotalKey = isDefault ? 'TotalReadQuranPages' : 'TotalReadQuranPages_${activeSession.id}';

      final curToday = prefs.getInt(sessionTodayKey) ?? prefs.getInt('TodayReadPages_$todayStr') ?? 0;
      await prefs.setInt(sessionTodayKey, curToday + pagesDelta);
      if (!isDefault) {
        await prefs.setInt('TodayReadPages_$todayStr', curToday + pagesDelta);
      }

      final curHatimToday = prefs.getInt('HatimTodayPages_${hatimId}_$todayStr') ?? 0;
      await prefs.setInt('HatimTodayPages_${hatimId}_$todayStr', curHatimToday + pagesDelta);

      final totalReadPages = (prefs.getInt(sessionTotalKey) ?? prefs.getInt('TotalReadQuranPages') ?? 0) + pagesDelta;
      await prefs.setInt(sessionTotalKey, totalReadPages);
      if (!isDefault) {
        await prefs.setInt('TotalReadQuranPages', totalReadPages);
      }

      // Advance daily streak
      await DailyStreakService.recordDailyActivity(db);
    }

    await prefs.setString('HatimLastReadDate_$hatimId', DateTime.now().toIso8601String());

    // Check Hatim Badges
    if (isDone) {
      try {
        final existing = await (db.select(db.unlockedBadges)..where((t) => t.badgeId.equals('hatim_completed'))).getSingleOrNull();
        if (existing == null) {
          await db.into(db.unlockedBadges).insert(
            UnlockedBadgesCompanion.insert(
              badgeId: 'hatim_completed',
              unlockedAt: Value(DateTime.now()),
              category: const Value('Kuran'),
            ),
          );
        }
      } catch (e) {
        debugPrint('[HatimNotifier] updateHatimPageProgress badge insert error: $e');
      }
    }

    // Trigger badge and streak refresh
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  /// Creates a new Mukabele Hatim with custom start page and optional 30-day target
  Future<String> createMukabeleHatim({
    required String title,
    int startPage = 1,
    bool isGroup = false,
    DateTime? targetDate,
  }) async {
    final db = ref.read(databaseProvider);
    final id = 'mukabele_${DateTime.now().millisecondsSinceEpoch}';
    final initialCompletedPages = (startPage > 1 ? startPage - 1 : 0).clamp(0, 604);

    try {
      await db.transaction(() async {
        await db.into(db.hatims).insert(
          HatimsCompanion.insert(
            id: id,
            title: title,
            isGroup: Value(isGroup),
            targetDate: Value(targetDate),
            completedPages: Value(initialCompletedPages),
          ),
        );

        // Create 30 Juz progress items
        for (int j = 1; j <= 30; j++) {
          final isDone = initialCompletedPages >= j * 20;
          await db.into(db.hatimCuzProgresses).insert(
            HatimCuzProgressesCompanion.insert(
              hatimId: id,
              juzNo: j,
              isCompleted: Value(isDone),
              completedAt: Value(isDone ? DateTime.now() : null),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('[HatimNotifier] createMukabeleHatim DB error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('MukabeleLastPage_$id', startPage.clamp(1, 604));
    await prefs.setString('MukabeleLastActiveHatimId', id);
    await prefs.setString('HatimLastReadDate_$id', DateTime.now().toIso8601String());

    return id;
  }

  /// Saves the last read page position for Mukabele
  Future<void> saveMukabeleLastPage(String hatimId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('MukabeleLastPage_$hatimId', page.clamp(1, 604));
    await prefs.setString('MukabeleLastActiveHatimId', hatimId);
    await prefs.setString('HatimLastReadDate_$hatimId', DateTime.now().toIso8601String());
  }

  /// Gets the last read page for Mukabele (fallback to completedPages + 1 or 1)
  static Future<int> getMukabeleLastPage(String hatimId, {int defaultPage = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('MukabeleLastPage_$hatimId') ?? defaultPage;
  }

  /// Deletes a Hatim and its Juz progress from database and cleans up cached preferences
  Future<void> deleteHatim(String hatimId) async {
    final db = ref.read(databaseProvider);

    try {
      await db.transaction(() async {
        // Delete juz progresses
        await (db.delete(db.hatimCuzProgresses)..where((t) => t.hatimId.equals(hatimId))).go();

        // Delete hatim
        await (db.delete(db.hatims)..where((t) => t.id.equals(hatimId))).go();
      });
    } catch (e) {
      debugPrint('[HatimNotifier] deleteHatim DB error: $e');
    }

    // Clean up preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('HatimLastReadDate_$hatimId');
    await prefs.remove('MukabeleLastPage_$hatimId');
    if (prefs.getString('MukabeleLastActiveHatimId') == hatimId) {
      await prefs.remove('MukabeleLastActiveHatimId');
    }

    // Refresh UI
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }
}

final hatimNotifierProvider = Provider<HatimNotifier>((ref) {
  return HatimNotifier(ref);
});
