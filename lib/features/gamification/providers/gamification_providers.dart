import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import '../models/badge_models.dart';
import '../models/user_rank.dart';
import '../models/surprise_chest_reward.dart';
import '../services/badge_service.dart';
import '../services/custom_badge_service.dart';
import '../services/daily_streak_service.dart';
import '../services/golden_day_service.dart';

final userStreakStreamProvider = StreamProvider<UserStreak?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.userStreaks).watchSingleOrNull();
});

final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.userProfiles).watchSingleOrNull();
});

final unlockedBadgesStreamProvider = StreamProvider<List<UnlockedBadge>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.unlockedBadges).watch();
});

final badgeServiceProvider = Provider<BadgeService>((ref) {
  final db = ref.watch(databaseProvider);
  return BadgeService(db);
});

// Trigger counter to refresh badges and balances whenever needed
final badgeRefreshTriggerProvider = StateProvider<int>((ref) => 0);

final diamondCountProvider = FutureProvider<int>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  final prefs = await SharedPreferences.getInstance();
  final activeSession = ref.watch(activeSessionProvider);
  final isDefault = activeSession.id == UserSession.defaultSessionId;
  final dKey = isDefault ? 'DiamondCount' : 'DiamondCount_${activeSession.id}';

  final streak = (await (db.select(db.userStreaks)..limit(1)).get()).firstOrNull;

  // Auto-migration: If freezeCount was previously used to store diamonds (> 10, e.g. 172)
  if (streak != null && streak.freezeCount > 10) {
    final oldDiamondVal = streak.freezeCount;
    final curPrefDiamonds = prefs.getInt(dKey) ?? 0;
    final effectiveDiamonds = max(oldDiamondVal, curPrefDiamonds);
    await prefs.setInt(dKey, effectiveDiamonds);
    if (isDefault) {
      await prefs.setInt('DiamondCount', effectiveDiamonds);
    }

    // Set starter shields into freezeCount (3 shields)
    await (db.update(db.userStreaks)..where((t) => t.id.equals(streak.id))).write(
      const UserStreaksCompanion(freezeCount: Value(3)),
    );
    return effectiveDiamonds;
  }

  return prefs.getInt(dKey) ?? (isDefault ? (prefs.getInt('DiamondCount') ?? 0) : 0);
});

final goldCountProvider = FutureProvider<int>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  final prefs = await SharedPreferences.getInstance();
  final activeSession = ref.watch(activeSessionProvider);
  final isDefault = activeSession.id == UserSession.defaultSessionId;
  final gKey = isDefault ? 'GoldCount' : 'GoldCount_${activeSession.id}';

  final streak = (await (db.select(db.userStreaks)..limit(1)).get()).firstOrNull;
  final prefGold = prefs.getInt(gKey) ?? (isDefault ? prefs.getInt('GoldCount') : null);
  final dbXp = streak?.xp ?? 0;

  final effectiveGold = max(prefGold ?? 0, dbXp);

  // Self-heal both stores so they never diverge
  if (prefGold != effectiveGold) {
    await prefs.setInt(gKey, effectiveGold);
    if (isDefault) await prefs.setInt('GoldCount', effectiveGold);
  }
  if (streak != null && streak.xp != effectiveGold) {
    await (db.update(db.userStreaks)..where((t) => t.id.equals(streak.id))).write(
      UserStreaksCompanion(xp: Value(effectiveGold)),
    );
  }

  return effectiveGold;
});

final shieldCountProvider = StreamProvider<int>((ref) {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  return db.select(db.userStreaks).watchSingleOrNull().map((streak) => streak?.freezeCount ?? 3);
});

final unrepairedGapDaysProvider = FutureProvider<List<StreakGapDay>>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  return DailyStreakService.getUnrepairedGapDays(db);
});

final hasRepairableStreakProvider = FutureProvider<bool>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  return DailyStreakService.hasRepairableHistoricalStreak(db);
});

final shieldedDatesStreamProvider = StreamProvider<Set<String>>((ref) {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  return db.select(db.streakGapDays).watch().asyncMap((_) async {
    return DailyStreakService.getShieldedDates(db);
  }).handleError((error, stackTrace) {
    debugPrint('[shieldedDatesStreamProvider] Error loading shielded dates: $error');
    return <String>{};
  });
});

class StreakRecoveryPower {
  final int availableShields;
  final int availableDiamonds;
  final int availableGold;
  final int totalAffordableDays;
  final int totalUnrepairedDays;

  const StreakRecoveryPower({
    required this.availableShields,
    required this.availableDiamonds,
    required this.availableGold,
    required this.totalAffordableDays,
    required this.totalUnrepairedDays,
  });

  bool get canAffordAll => totalAffordableDays >= totalUnrepairedDays && totalUnrepairedDays > 0;
  bool get canAffordSome => totalAffordableDays > 0;
}

final streakRecoveryPowerProvider = FutureProvider<StreakRecoveryPower>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  final streak = (await (db.select(db.userStreaks)..limit(1)).get()).firstOrNull;
  final unrepaired = await DailyStreakService.getUnrepairedGapDays(db);
  final diamonds = await ref.watch(diamondCountProvider.future);
  final gold = await ref.watch(goldCountProvider.future);

  final shields = streak?.freezeCount ?? 0;
  final diamondsInShields = diamonds ~/ 5;
  final remainingDiamonds = diamonds % 5;
  final goldInShields = (remainingDiamonds * 5 + gold) ~/ 25;
  final totalShieldPower = shields + diamondsInShields + goldInShields;

  final totalGaps = unrepaired.isNotEmpty
      ? unrepaired.length
      : ((streak != null && streak.bestStreak > streak.currentStreak) ? 1 : 0);

  return StreakRecoveryPower(
    availableShields: shields,
    availableDiamonds: diamonds,
    availableGold: gold,
    totalAffordableDays: min(totalGaps, totalShieldPower),
    totalUnrepairedDays: totalGaps,
  );
});

final dailyGoalsStatusProvider = FutureProvider<DailyGoalsStatus>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  final activeSession = ref.watch(activeSessionProvider);
  return GoldenDayService.checkGoldenDayStatus(db, null, activeSession.id);
});

final allBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  ref.watch(unlockedBadgesStreamProvider);
  final activeSession = ref.watch(activeSessionProvider);
  final service = ref.watch(badgeServiceProvider);
  return service.getBadges(activeSession.id);
});

final customBadgesProvider = FutureProvider<List<CustomQuranBadge>>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  final activeSession = ref.watch(activeSessionProvider);
  return CustomBadgeService.getCustomBadges(activeSession.id);
});

final totalZikirCountProvider = StreamProvider<int>((ref) {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  final activeSession = ref.watch(activeSessionProvider);

  return db.select(db.zikirs).watch().asyncMap((zikirs) async {
    final logsSumRow = await db.customSelect(
      'SELECT COALESCE(SUM(count), 0) as total FROM zikir_logs',
      readsFrom: {db.zikirLogs},
    ).getSingleOrNull();
    final logsSum = logsSumRow?.read<int>('total') ?? 0;
    final zikirsSum = zikirs.fold<int>(0, (sum, z) => sum + z.totalCount);

    final prefs = await SharedPreferences.getInstance();
    final isDefault = activeSession.id == UserSession.defaultSessionId;
    final key = isDefault ? 'TotalZikir' : 'TotalZikir_${activeSession.id}';
    final prefsTotal = prefs.getInt(key) ?? (isDefault ? prefs.getInt('TotalZikirCount') ?? 0 : 0);
    return max(max(zikirsSum, logsSum), prefsTotal);
  });
});

final currentUserRankProvider = Provider<UserRank>((ref) {
  final totalAsync = ref.watch(totalZikirCountProvider);
  final total = totalAsync.valueOrNull ?? 0;
  return UserRank.calculateRank(total);
});

final unlockedBirdsProvider = FutureProvider<List<BirdSelectionItem>>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  final activeSession = ref.watch(activeSessionProvider);
  final prefs = await SharedPreferences.getInstance();

  final totalZikirAsync = ref.watch(totalZikirCountProvider);
  final totalZikir = totalZikirAsync.valueOrNull ?? 0;
  final dbUnlockedList = await db.select(db.unlockedBadges).get();
  final dbUnlockedSet = dbUnlockedList.map((u) => u.badgeId).toSet();

  final allRanks = UserRank.getAllRanks();
  final unlockedRanks = allRanks.where((r) {
    final rankId = 'rank_${r.level.value}';
    final birdKey = r.birdAnimationFile.split('/').last;
    return r.level == UserRankLevel.none ||
        r.requiredZikir <= totalZikir ||
        dbUnlockedSet.contains(rankId) ||
        dbUnlockedSet.contains('bird_${r.birdAnimationFile}') ||
        dbUnlockedSet.contains('bird_$birdKey');
  }).toList();

  final List<BirdSelectionItem> result = [];
  final Set<String> addedFiles = {};

  for (final r in unlockedRanks) {
    if (!addedFiles.contains(r.birdAnimationFile)) {
      addedFiles.add(r.birdAnimationFile);
      result.add(BirdSelectionItem(
        name: r.name,
        fileName: r.birdAnimationFile,
        badge: r.badge,
      ));
    }
  }

  // Add gifted birds if stored in prefs
  final giftKey = activeSession.id == UserSession.defaultSessionId ? 'UnlockedBirds' : 'UnlockedBirds_${activeSession.id}';
  final giftedStr = prefs.getString(giftKey) ?? (activeSession.id == UserSession.defaultSessionId ? prefs.getString('UnlockedBirds') ?? '' : '');
  if (giftedStr.isNotEmpty) {
    final giftList = giftedStr.split(',').where((s) => s.isNotEmpty);
    for (final giftFile in giftList) {
      if (!addedFiles.contains(giftFile)) {
        addedFiles.add(giftFile);
        final matchedRank = allRanks.firstWhere(
          (r) => r.birdAnimationFile.contains(giftFile) || giftFile.contains(r.birdAnimationFile.split('/').last),
          orElse: () => allRanks.first,
        );
        result.add(BirdSelectionItem(
          name: matchedRank.name,
          fileName: matchedRank.birdAnimationFile,
          badge: '🕊️ Hediye',
        ));
      }
    }
  }

  return result;
});

final selectedBirdItemProvider = StateNotifierProvider<SelectedBirdNotifier, BirdSelectionItem>((ref) {
  return SelectedBirdNotifier(ref);
});

class SelectedBirdNotifier extends StateNotifier<BirdSelectionItem> {
  final Ref ref;

  SelectedBirdNotifier(this.ref)
      : super(const BirdSelectionItem(
          name: 'Yeni Başlayan',
          fileName: 'assets/animations/yeni_bird.json',
          badge: '🐣',
        )) {
    _loadSelectedBird();
  }

  String _key(String base, [String? customSessionId]) {
    final sid = customSessionId ?? ref.read(activeSessionProvider).id;
    if (sid != UserSession.defaultSessionId) {
      return '${base}_$sid';
    }
    return base;
  }

  Future<void> reloadForSession([String? targetSessionId]) async {
    await _loadSelectedBird(targetSessionId);
  }

  Future<void> _loadSelectedBird([String? targetSessionId]) async {
    final sid = targetSessionId ?? ref.read(activeSessionProvider).id;
    final isDefault = sid == UserSession.defaultSessionId;
    final prefs = await SharedPreferences.getInstance();
    final savedFile = prefs.getString(_key('SelectedBird', sid)) ??
        (isDefault ? prefs.getString('SelectedBird') : null) ??
        'assets/animations/yeni_bird.json';

    final allRanks = UserRank.getAllRanks();
    final match = allRanks.firstWhere(
      (r) => r.birdAnimationFile == savedFile || savedFile.contains(r.birdAnimationFile.split('/').last) || savedFile.contains(r.name),
      orElse: () => allRanks.first,
    );

    state = BirdSelectionItem(
      name: match.name,
      fileName: match.birdAnimationFile,
      badge: match.badge,
    );
  }

  Future<void> selectBird(BirdSelectionItem bird) async {
    state = bird;
    final prefs = await SharedPreferences.getInstance();
    final sid = ref.read(activeSessionProvider).id;
    final isDefault = sid == UserSession.defaultSessionId;

    await prefs.setString(_key('SelectedBird', sid), bird.fileName);
    await prefs.setString(_key('SelectedBirdAvatar', sid), bird.displayName);
    if (isDefault) {
      await prefs.setString('SelectedBird', bird.fileName);
      await prefs.setString('SelectedBirdAvatar', bird.displayName);
    }
  }
}

class GamificationNotifier extends StateNotifier<void> {
  final Ref ref;

  GamificationNotifier(this.ref) : super(null);

  String _sKey(String base) {
    final activeSession = ref.read(activeSessionProvider);
    if (activeSession.id != UserSession.defaultSessionId) {
      return '${base}_${activeSession.id}';
    }
    return base;
  }

  Future<bool> unlockBadgeWithDiamonds(Badge badge) async {
    if (badge.isUnlocked || badge.unlockCost <= 0) return false;

    final db = ref.read(databaseProvider);
    final prefs = await SharedPreferences.getInstance();

    final curDiamonds = prefs.getInt(_sKey('DiamondCount')) ?? (prefs.getInt('DiamondCount') ?? 0);
    if (curDiamonds < badge.unlockCost) {
      return false;
    }

    // Deduct diamonds in Prefs (Diamonds are independent from Kalkan/freezeCount)
    final newDiamonds = curDiamonds - badge.unlockCost;
    await prefs.setInt(_sKey('DiamondCount'), newDiamonds);
    if (ref.read(activeSessionProvider).id == UserSession.defaultSessionId) {
      await prefs.setInt('DiamondCount', newDiamonds);
    }

    // Insert into unlockedBadges
    await db.into(db.unlockedBadges).insertOnConflictUpdate(
      UnlockedBadgesCompanion(
        badgeId: Value(badge.id),
        unlockedAt: Value(DateTime.now()),
        category: Value(badge.category),
      ),
    );

    // Also add to unlocked birds if it is a rank badge
    final rankLevelStr = badge.id.replaceAll('rank_', '');
    final levelVal = int.tryParse(rankLevelStr);
    if (levelVal != null) {
      final allRanks = UserRank.getAllRanks();
      final rank = allRanks.firstWhere((r) => r.level.value == levelVal, orElse: () => allRanks.first);
      final curUnlockedBirds = prefs.getString(_sKey('UnlockedBirds')) ?? (prefs.getString('UnlockedBirds') ?? '');
      final set = curUnlockedBirds.split(',').where((s) => s.isNotEmpty).toSet();
      set.add(rank.birdAnimationFile);
      await prefs.setString(_sKey('UnlockedBirds'), set.join(','));
      if (ref.read(activeSessionProvider).id == UserSession.defaultSessionId) {
        await prefs.setString('UnlockedBirds', set.join(','));
      }

      // Automatically switch to this bird
      await ref.read(selectedBirdItemProvider.notifier).selectBird(
        BirdSelectionItem(name: rank.name, fileName: rank.birdAnimationFile, badge: rank.badge),
      );
    }

    // Trigger refresh
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
    return true;
  }

  /// Converts Gold to Diamonds (5 Gold = 1 Diamond)
  Future<bool> convertGoldToDiamonds(int goldToSpend) async {
    if (goldToSpend < 5) return false;
    final diamondsToGet = goldToSpend ~/ 5;
    final exactGoldCost = diamondsToGet * 5;

    final db = ref.read(databaseProvider);
    final prefs = await SharedPreferences.getInstance();

    final curGold = prefs.getInt(_sKey('GoldCount')) ?? (prefs.getInt('GoldCount') ?? 0);
    final curDiamonds = prefs.getInt(_sKey('DiamondCount')) ?? (prefs.getInt('DiamondCount') ?? 0);

    if (curGold < exactGoldCost) {
      return false;
    }

    final newGold = curGold - exactGoldCost;
    final newDiamonds = curDiamonds + diamondsToGet;

    await prefs.setInt(_sKey('GoldCount'), newGold);
    await prefs.setInt(_sKey('DiamondCount'), newDiamonds);
    if (ref.read(activeSessionProvider).id == UserSession.defaultSessionId) {
      await prefs.setInt('GoldCount', newGold);
      await prefs.setInt('DiamondCount', newDiamonds);
    }

    final streak = (await (db.select(db.userStreaks)..limit(1)).get()).firstOrNull;
    if (streak != null) {
      await (db.update(db.userStreaks)..where((t) => t.id.equals(streak.id))).write(
        UserStreaksCompanion(xp: Value(newGold)),
      );
    }

    ref.read(badgeRefreshTriggerProvider.notifier).state++;
    return true;
  }

  /// Buys Streak Shields using Diamonds (5 Diamonds = 1 Shield)
  Future<bool> buyShieldWithDiamonds(int shieldCount) async {
    if (shieldCount <= 0) return false;
    final diamondCost = shieldCount * 5;

    final db = ref.read(databaseProvider);
    final prefs = await SharedPreferences.getInstance();

    final curDiamonds = prefs.getInt(_sKey('DiamondCount')) ?? (prefs.getInt('DiamondCount') ?? 0);
    if (curDiamonds < diamondCost) {
      return false;
    }

    final newDiamonds = curDiamonds - diamondCost;
    await prefs.setInt(_sKey('DiamondCount'), newDiamonds);
    if (ref.read(activeSessionProvider).id == UserSession.defaultSessionId) {
      await prefs.setInt('DiamondCount', newDiamonds);
    }

    final streak = (await (db.select(db.userStreaks)..limit(1)).get()).firstOrNull;
    if (streak != null) {
      await (db.update(db.userStreaks)..where((t) => t.id.equals(streak.id))).write(
        UserStreaksCompanion(freezeCount: Value(streak.freezeCount + shieldCount)),
      );
    }

    ref.read(badgeRefreshTriggerProvider.notifier).state++;
    return true;
  }

  Future<StreakRepairResult> repairNextGapDay() async {
    final db = ref.read(databaseProvider);
    final result = await DailyStreakService.repairNextGapDay(db);
    if (result.success) {
      ref.read(badgeRefreshTriggerProvider.notifier).state++;
    }
    return result;
  }

  Future<StreakRepairResult> repairGapDaysBatch(int countToRepair) async {
    final db = ref.read(databaseProvider);
    final result = await DailyStreakService.repairGapDaysBatch(db, countToRepair: countToRepair);
    if (result.success) {
      ref.read(badgeRefreshTriggerProvider.notifier).state++;
    }
    return result;
  }

  /// Flexibly repairs up to [countToRepair] gap days using available shields,
  /// and optionally auto-converting diamonds (5 💎 = 1 🛡️) and gold (25 🪙 = 1 🛡️)
  /// as needed to maximize recovered days.
  Future<StreakRepairResult> repairGapDaysFlexible({
    required int countToRepair,
    bool useDiamonds = true,
    bool useGold = true,
  }) async {
    final db = ref.read(databaseProvider);
    final prefs = await SharedPreferences.getInstance();

    final streak = (await (db.select(db.userStreaks)..limit(1)).get()).firstOrNull;
    final int curShields = streak?.freezeCount ?? 0;

    int totalAvailableShields = curShields;

    if (totalAvailableShields < countToRepair) {
      int neededShields = countToRepair - totalAvailableShields;
      int curDiamonds = prefs.getInt(_sKey('DiamondCount')) ?? (prefs.getInt('DiamondCount') ?? 0);
      int curGold = prefs.getInt(_sKey('GoldCount')) ?? (prefs.getInt('GoldCount') ?? 0);

      // 1. If diamonds aren't enough, see if we can convert gold to diamonds
      final neededDiamonds = neededShields * 5;
      if (useGold && curDiamonds < neededDiamonds && curGold >= 5) {
        final missingDiamonds = neededDiamonds - curDiamonds;
        final goldNeeded = missingDiamonds * 5;
        final goldToSpend = min(curGold, goldNeeded);
        final diamondsFromGold = goldToSpend ~/ 5;
        final exactGoldCost = diamondsFromGold * 5;

        if (exactGoldCost > 0) {
          curGold -= exactGoldCost;
          curDiamonds += diamondsFromGold;
          await prefs.setInt(_sKey('GoldCount'), curGold);
          await prefs.setInt(_sKey('DiamondCount'), curDiamonds);
          if (ref.read(activeSessionProvider).id == UserSession.defaultSessionId) {
            await prefs.setInt('GoldCount', curGold);
            await prefs.setInt('DiamondCount', curDiamonds);
          }
          if (streak != null) {
            await (db.update(db.userStreaks)..where((t) => t.id.equals(streak.id))).write(
              UserStreaksCompanion(xp: Value(curGold)),
            );
          }
        }
      }

      // 2. Buy shields with diamonds
      if (useDiamonds && curDiamonds >= 5) {
        final shieldsCanBuy = min(neededShields, curDiamonds ~/ 5);
        if (shieldsCanBuy > 0) {
          final diamondCost = shieldsCanBuy * 5;
          curDiamonds -= diamondCost;
          await prefs.setInt(_sKey('DiamondCount'), curDiamonds);
          if (ref.read(activeSessionProvider).id == UserSession.defaultSessionId) {
            await prefs.setInt('DiamondCount', curDiamonds);
          }
          if (streak != null) {
            await (db.update(db.userStreaks)..where((t) => t.id.equals(streak.id))).write(
              UserStreaksCompanion(freezeCount: Value(streak.freezeCount + shieldsCanBuy)),
            );
          }
          totalAvailableShields += shieldsCanBuy;
        }
      }
    }

    final actualToRepair = min(countToRepair, totalAvailableShields);
    if (actualToRepair <= 0) {
      return const StreakRepairResult(
        success: false,
        message: 'Yetersiz kalkan, elmas veya altın!',
      );
    }

    final result = await DailyStreakService.repairGapDaysBatch(db, countToRepair: actualToRepair);
    if (result.success) {
      ref.read(badgeRefreshTriggerProvider.notifier).state++;
    }
    return result;
  }

  Future<bool> useStreakShield() async {
    final db = ref.read(databaseProvider);
    final streak = (await (db.select(db.userStreaks)..limit(1)).get()).firstOrNull;
    if (streak != null && streak.freezeCount > 0) {
      await (db.update(db.userStreaks)..where((t) => t.id.equals(streak.id))).write(
        UserStreaksCompanion(
          freezeCount: Value(streak.freezeCount - 1),
          lastFreezeDate: Value(DateTime.now().toIso8601String().split('T').first),
        ),
      );
      ref.read(badgeRefreshTriggerProvider.notifier).state++;
      return true;
    }
    return false;
  }

  Future<void> addDiamonds(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final cur = prefs.getInt(_sKey('DiamondCount')) ?? (prefs.getInt('DiamondCount') ?? 0);
    final newCount = cur + amount;
    await prefs.setInt(_sKey('DiamondCount'), newCount);
    if (ref.read(activeSessionProvider).id == UserSession.defaultSessionId) {
      await prefs.setInt('DiamondCount', newCount);
    }
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  Future<void> addGold(int amount) async {
    final db = ref.read(databaseProvider);
    final prefs = await SharedPreferences.getInstance();
    final streak = (await (db.select(db.userStreaks)..limit(1)).get()).firstOrNull;
    final cur = prefs.getInt(_sKey('GoldCount')) ?? (prefs.getInt('GoldCount') ?? 0);
    final currentBase = max(cur, streak?.xp ?? 0);
    final newCount = currentBase + amount;

    await prefs.setInt(_sKey('GoldCount'), newCount);
    if (ref.read(activeSessionProvider).id == UserSession.defaultSessionId) {
      await prefs.setInt('GoldCount', newCount);
    }
    if (streak != null) {
      await (db.update(db.userStreaks)..where((t) => t.id.equals(streak.id))).write(
        UserStreaksCompanion(xp: Value(newCount)),
      );
    }
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  Future<SurpriseChestReward?> openSurpriseChest({required bool isTurkish}) async {
    final db = ref.read(databaseProvider);
    final activeSession = ref.read(activeSessionProvider);
    final reward = await GoldenDayService.openDailySurpriseChest(
      db: db,
      isTurkish: isTurkish,
      sessionId: activeSession.id,
    );
    if (reward != null) {
      ref.read(badgeRefreshTriggerProvider.notifier).state++;
    }
    return reward;
  }

  Future<SurahCompletionResult> recordSurahReadingCompleted({
    required SureItem surah,
    String? streakKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final db = ref.read(databaseProvider);
    final todayStr = GoldenDayService.getTodayStr();

    // Determine streak key if applicable
    String? effectiveStreakKey = streakKey;
    String? targetBadgeId;
    String? badgeTitle;
    String? baseKey;

    if (surah.id == 56 || effectiveStreakKey == 'Streak_Waqiah' || effectiveStreakKey == 'waqiah') {
      effectiveStreakKey = 'Streak_Waqiah';
      targetBadgeId = 'waqiah_40';
      badgeTitle = 'Vakıa Muhafızı';
      baseKey = 'Waqiah';
    } else if (surah.id == 67 || effectiveStreakKey == 'Streak_Mulk' || effectiveStreakKey == 'mulk') {
      effectiveStreakKey = 'Streak_Mulk';
      targetBadgeId = 'mulk_40';
      badgeTitle = 'Mülk Muhafızı';
      baseKey = 'Mulk';
    } else if (surah.id == 78 || effectiveStreakKey == 'Streak_Naba' || effectiveStreakKey == 'naba') {
      effectiveStreakKey = 'Streak_Naba';
      targetBadgeId = 'naba_40';
      badgeTitle = 'Nebe Muhafızı';
      baseKey = 'Naba';
    } else if (surah.id == 36 || effectiveStreakKey == 'Streak_Yasin' || effectiveStreakKey == 'yasin') {
      effectiveStreakKey = 'Streak_Yasin';
      targetBadgeId = 'yasin_40';
      badgeTitle = 'Yâsîn Muhafızı';
      baseKey = 'Yasin';
    } else if (surah.id == 48 || effectiveStreakKey == 'Streak_Fetih' || effectiveStreakKey == 'fetih') {
      effectiveStreakKey = 'Streak_Fetih';
      targetBadgeId = 'fetih_40';
      badgeTitle = 'Fetih Muhafızı';
      baseKey = 'Fetih';
    } else if (surah.id == 55 || effectiveStreakKey == 'Streak_Rahman' || effectiveStreakKey == 'rahman') {
      effectiveStreakKey = 'Streak_Rahman';
      targetBadgeId = 'rahman_40';
      badgeTitle = 'Rahmân Muhafızı';
      baseKey = 'Rahman';
    } else if (surah.id == 18 || effectiveStreakKey == 'Streak_Kehf' || effectiveStreakKey == 'kehf') {
      effectiveStreakKey = 'Streak_Kehf';
      targetBadgeId = 'kehf_40';
      badgeTitle = 'Kehf Muhafızı';
      baseKey = 'Kehf';
    } else if (surah.id >= 112 || effectiveStreakKey == 'Streak_Sleep' || effectiveStreakKey == 'sleep') {
      effectiveStreakKey = 'Streak_Sleep';
      targetBadgeId = 'sleep_protection';
      badgeTitle = 'Gece Sığınağı';
      baseKey = 'Sleep';
    }

    int newStreak = 0;
    int newReadCount = 0;
    bool isBadgeUnlocked = false;

    final activeSession = ref.read(activeSessionProvider);
    final isDefault = activeSession.id == UserSession.defaultSessionId;
    final sfx = isDefault ? '' : '_${activeSession.id}';

    if (baseKey != null) {
      // 1. Kümülatif Toplam Okuma Sayısı (HER OKUMADA +1 artar)
      final readCountKey = 'ReadCount_$baseKey$sfx';
      final curReadCount = prefs.getInt(readCountKey) ?? (isDefault ? prefs.getInt('ReadCount_$baseKey') ?? 0 : 0);
      newReadCount = curReadCount + 1;
      await prefs.setInt(readCountKey, newReadCount);
      if (isDefault) {
        await prefs.setInt('ReadCount_$baseKey', newReadCount);
      }

      // 2. Günlük Seri Takibi (Günde en fazla 1 gün ilerler)
      final lastDateKey = 'LastDate_Streak_$baseKey$sfx';
      final lastDate = prefs.getString(lastDateKey) ?? (isDefault ? prefs.getString('LastDate_Streak_$baseKey') : null);
      final curStreak = prefs.getInt('Streak_$baseKey$sfx') ?? (isDefault ? prefs.getInt('Streak_$baseKey') ?? 0 : 0);

      if (lastDate != todayStr) {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

        if (lastDate == yesterdayStr) {
          newStreak = curStreak + 1;
        } else if (curStreak == 0 || lastDate == null) {
          newStreak = 1;
        } else {
          newStreak = 1; // reset streak if gap > 1
        }

        await prefs.setInt('Streak_$baseKey$sfx', newStreak);
        await prefs.setString(lastDateKey, todayStr);
        if (isDefault) {
          await prefs.setInt('Streak_$baseKey', newStreak);
          await prefs.setString('LastDate_Streak_$baseKey', todayStr);
        }

        final bestKey = 'BestStreak_$baseKey$sfx';
        final best = prefs.getInt(bestKey) ?? (isDefault ? prefs.getInt('BestStreak_$baseKey') ?? 0 : 0);
        if (newStreak > best) {
          await prefs.setInt(bestKey, newStreak);
          if (isDefault) {
            await prefs.setInt('BestStreak_$baseKey', newStreak);
          }
        }
      } else {
        newStreak = curStreak;
      }

      // 3. 40 Okuma veya 40 Günlük Seri Tamamlama Kontrolü
      if (targetBadgeId != null && (newReadCount >= 40 || newStreak >= 40)) {
        final existing = await (db.select(db.unlockedBadges)..where((t) => t.badgeId.equals(targetBadgeId!))).getSingleOrNull();
        if (existing == null) {
          await db.into(db.unlockedBadges).insert(
            UnlockedBadgesCompanion.insert(
              badgeId: targetBadgeId,
              unlockedAt: Value(DateTime.now()),
              category: const Value('Kuran'),
            ),
          );
          isBadgeUnlocked = true;
        }
      }
    }

    // 4. Kullanıcının oluşturduğu özel rozetleri de güncelle
    await CustomBadgeService.onSurahRead(surah.id, activeSession.id);

    // Add XP (+50 Gold) to user balance & user streak table
    const xpGained = 50;
    await addGold(xpGained);
    await db.into(db.userStreakHistories).insert(
      UserStreakHistoriesCompanion.insert(
        dateStr: todayStr,
        actionType: 'Kuran: ${surah.name} Sûresi',
        xpGained: xpGained,
      ),
    );

    // Record pages read into today's goal
    final readPagesKey = 'TodayReadPages_$todayStr$sfx';
    final curPages = prefs.getInt(readPagesKey) ?? (isDefault ? prefs.getInt('TodayReadPages_$todayStr') ?? 0 : 0);
    final int surahPageSpan = (SurahDataProvider.getSurahEndPage(surah.id) - surah.startPage + 1).clamp(1, 604).toInt();
    await prefs.setInt(readPagesKey, curPages + surahPageSpan);
    if (isDefault) {
      await prefs.setInt('TodayReadPages_$todayStr', curPages + surahPageSpan);
    }

    // Check total Quran pages for 1 / 10 / 100 pages badges
    final int totalReadPages = (prefs.getInt('TotalReadQuranPages$sfx') ?? (isDefault ? prefs.getInt('TotalReadQuranPages') ?? 0 : 0)) + surahPageSpan;
    await prefs.setInt('TotalReadQuranPages$sfx', totalReadPages);
    if (isDefault) {
      await prefs.setInt('TotalReadQuranPages', totalReadPages);
    }
    if (totalReadPages >= 1) {
      await _unlockBadgeIfNotExists(db, 'quran_first_step', 'Kuran');
    }
    if (totalReadPages >= 10) {
      await _unlockBadgeIfNotExists(db, 'quran_10_pages', 'Kuran');
    }
    if (totalReadPages >= 100) {
      await _unlockBadgeIfNotExists(db, 'quran_100_pages', 'Kuran');
    }

    // Advance daily streak
    await DailyStreakService.recordDailyActivity(db);

    // Trigger refresh
    ref.read(badgeRefreshTriggerProvider.notifier).state++;

    return SurahCompletionResult(
      surah: surah,
      xpGained: xpGained,
      currentStreak: newStreak,
      readCount: newReadCount,
      isStreakSurah: effectiveStreakKey != null,
      isBadgeUnlocked: isBadgeUnlocked,
      unlockedBadgeName: badgeTitle,
    );
  }

  Future<void> _unlockBadgeIfNotExists(AppDatabase db, String badgeId, String category) async {
    final existing = await (db.select(db.unlockedBadges)..where((t) => t.badgeId.equals(badgeId))).getSingleOrNull();
    if (existing == null) {
      await db.into(db.unlockedBadges).insert(
        UnlockedBadgesCompanion.insert(
          badgeId: badgeId,
          unlockedAt: Value(DateTime.now()),
          category: Value(category),
        ),
      );
    }
  }

  Future<void> refreshBadges() async {
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }
}

class SurahCompletionResult {
  final SureItem surah;
  final int xpGained;
  final int currentStreak;
  final int readCount;
  final bool isStreakSurah;
  final bool isBadgeUnlocked;
  final String? unlockedBadgeName;

  const SurahCompletionResult({
    required this.surah,
    this.xpGained = 50,
    this.currentStreak = 1,
    this.readCount = 1,
    this.isStreakSurah = false,
    this.isBadgeUnlocked = false,
    this.unlockedBadgeName,
  });
}

class SurahStreaksData {
  final int waqiahStreak;
  final int mulkStreak;
  final int nabaStreak;
  final int yasinStreak;
  final int fetihStreak;
  final int rahmanStreak;
  final int kehfStreak;
  final int sleepStreak;

  final int waqiahReadCount;
  final int mulkReadCount;
  final int nabaReadCount;
  final int yasinReadCount;
  final int fetihReadCount;
  final int rahmanReadCount;
  final int kehfReadCount;
  final int sleepReadCount;

  const SurahStreaksData({
    this.waqiahStreak = 0,
    this.mulkStreak = 0,
    this.nabaStreak = 0,
    this.yasinStreak = 0,
    this.fetihStreak = 0,
    this.rahmanStreak = 0,
    this.kehfStreak = 0,
    this.sleepStreak = 0,
    this.waqiahReadCount = 0,
    this.mulkReadCount = 0,
    this.nabaReadCount = 0,
    this.yasinReadCount = 0,
    this.fetihReadCount = 0,
    this.rahmanReadCount = 0,
    this.kehfReadCount = 0,
    this.sleepReadCount = 0,
  });
}

final surahStreaksProvider = FutureProvider<SurahStreaksData>((ref) async {
  ref.watch(badgeRefreshTriggerProvider);
  final activeSession = ref.watch(activeSessionProvider);
  final isDefault = activeSession.id == UserSession.defaultSessionId;
  final sfx = isDefault ? '' : '_${activeSession.id}';
  final prefs = await SharedPreferences.getInstance();

  int getVal(String key) => prefs.getInt('$key$sfx') ?? (isDefault ? prefs.getInt(key) ?? 0 : 0);

  final wStreak = getVal('Streak_Waqiah');
  final mStreak = getVal('Streak_Mulk');
  final nStreak = getVal('Streak_Naba');
  final yStreak = getVal('Streak_Yasin');
  final fStreak = getVal('Streak_Fetih');
  final rStreak = getVal('Streak_Rahman');
  final kStreak = getVal('Streak_Kehf');
  final sStreak = getVal('Streak_Sleep');

  return SurahStreaksData(
    waqiahStreak: wStreak,
    mulkStreak: mStreak,
    nabaStreak: nStreak,
    yasinStreak: yStreak,
    fetihStreak: fStreak,
    rahmanStreak: rStreak,
    kehfStreak: kStreak,
    sleepStreak: sStreak,
    waqiahReadCount: max(getVal('ReadCount_Waqiah'), wStreak),
    mulkReadCount: max(getVal('ReadCount_Mulk'), mStreak),
    nabaReadCount: max(getVal('ReadCount_Naba'), nStreak),
    yasinReadCount: max(getVal('ReadCount_Yasin'), yStreak),
    fetihReadCount: max(getVal('ReadCount_Fetih'), fStreak),
    rahmanReadCount: max(getVal('ReadCount_Rahman'), rStreak),
    kehfReadCount: max(getVal('ReadCount_Kehf'), kStreak),
    sleepReadCount: max(getVal('ReadCount_Sleep'), sStreak),
  );
});

final gamificationNotifierProvider = Provider<GamificationNotifier>((ref) {
  return GamificationNotifier(ref);
});

class BadgeCatalogItem {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int requiredXp;

  const BadgeCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.requiredXp,
  });
}

const List<BadgeCatalogItem> allBadgesCatalog = [
  BadgeCatalogItem(
    id: 'first_zikir',
    title: 'İlk Adım',
    description: 'İlk zikrinizi başarıyla çektiniz.',
    icon: '🌱',
    requiredXp: 10,
  ),
  BadgeCatalogItem(
    id: 'streak_3',
    title: '3 Gün İstikrar',
    description: '3 gün boyunca aralıksız zikir çekildi.',
    icon: '🔥',
    requiredXp: 50,
  ),
  BadgeCatalogItem(
    id: 'streak_7',
    title: 'Haftalık Muhafız',
    description: '7 günlük kesintisiz ibadet serisi.',
    icon: '🛡️',
    requiredXp: 150,
  ),
  BadgeCatalogItem(
    id: 'streak_30',
    title: 'Aylık Sadakat',
    description: '30 günlük istikrarlı zikir ve vird.',
    icon: '👑',
    requiredXp: 500,
  ),
  BadgeCatalogItem(
    id: 'zikir_1000',
    title: '1.000 Zikir',
    description: 'Toplamda 1.000 adet zikir tamamlandı.',
    icon: '📿',
    requiredXp: 200,
  ),
  BadgeCatalogItem(
    id: 'zikir_10000',
    title: '10.000 Zikir',
    description: 'Toplamda 10.000 adet zikir ve salavat.',
    icon: '💎',
    requiredXp: 1000,
  ),
];

