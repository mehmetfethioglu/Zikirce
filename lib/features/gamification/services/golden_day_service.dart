import 'dart:math';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/prayer_tracking_service.dart';
import '../../../../core/services/widget_sync_service.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/utils/pref_utils.dart';
import '../models/surprise_chest_reward.dart';
import '../models/user_rank.dart';

class DailyGoalItemState {
  final String id; // 'prayers', 'zikir', 'kuran', 'ezber', 'kaza'
  final String title;
  final String icon;
  final bool isEnabled;
  final bool isCompleted;
  final bool isExcused;
  final String progressText;

  const DailyGoalItemState({
    required this.id,
    required this.title,
    required this.icon,
    required this.isEnabled,
    required this.isCompleted,
    this.isExcused = false,
    required this.progressText,
  });
}

class DailyGoalsStatus {
  final bool isPrayersGoalEnabled;
  final bool isPrayersMet;
  final int completedPrayersCount; // 0 to 5

  final bool isZikirGoalEnabled;
  final bool isZikirMet;
  final int todayZikirCount;
  final int zikirGoal;

  final bool isKuranGoalEnabled;
  final bool isKuranMet;
  final int todayKuranPages;
  final int kuranGoal;

  final bool isEzberGoalEnabled;
  final bool isEzberMet;
  final int todayEzberCount;
  final int ezberGoal;

  final bool isKazaGoalEnabled;
  final bool isKazaMet;
  final int todayKazaCount;
  final int kazaGoal;

  final bool isExcusedMode;
  final bool isGoldCompleted;
  final bool isChestClaimed;

  const DailyGoalsStatus({
    this.isPrayersGoalEnabled = true,
    this.isPrayersMet = false,
    this.completedPrayersCount = 0,
    this.isZikirGoalEnabled = true,
    this.isZikirMet = false,
    this.todayZikirCount = 0,
    this.zikirGoal = 100,
    this.isKuranGoalEnabled = true,
    this.isKuranMet = false,
    this.todayKuranPages = 0,
    this.kuranGoal = 5,
    this.isEzberGoalEnabled = false,
    this.isEzberMet = false,
    this.todayEzberCount = 0,
    this.ezberGoal = 1,
    this.isKazaGoalEnabled = false,
    this.isKazaMet = false,
    this.todayKazaCount = 0,
    this.kazaGoal = 1,
    this.isExcusedMode = false,
    this.isGoldCompleted = false,
    this.isChestClaimed = false,
  });

  /// Ordered 5 goals for 5 hearts: 1. Namaz, 2. Zikir, 3. Kur'an, 4. Ezber, 5. Kaza
  List<DailyGoalItemState> get orderedGoals => [
        DailyGoalItemState(
          id: 'prayers',
          title: '5 Vakit Namaz',
          icon: '🕌',
          isEnabled: isPrayersGoalEnabled,
          isCompleted: isExcusedMode || isPrayersMet,
          isExcused: isExcusedMode,
          progressText: isExcusedMode
              ? 'Muaf (Zaruri Hal)'
              : '$completedPrayersCount / 5 vakit',
        ),
        DailyGoalItemState(
          id: 'zikir',
          title: 'Günlük Zikir',
          icon: '📿',
          isEnabled: isZikirGoalEnabled,
          isCompleted: isZikirMet,
          progressText: '$todayZikirCount / $zikirGoal zikir',
        ),
        DailyGoalItemState(
          id: 'kuran',
          title: 'Kur\'an-ı Kerim',
          icon: '📖',
          isEnabled: isKuranGoalEnabled,
          isCompleted: isExcusedMode || isKuranMet,
          isExcused: isExcusedMode,
          progressText: isExcusedMode
              ? 'Muaf (Zaruri Hal)'
              : '$todayKuranPages / $kuranGoal sayfa',
        ),
        DailyGoalItemState(
          id: 'ezber',
          title: 'Ezber / Hafızlık',
          icon: '🧠',
          isEnabled: isEzberGoalEnabled,
          isCompleted: isEzberMet,
          progressText: '$todayEzberCount / $ezberGoal tekrar',
        ),
        DailyGoalItemState(
          id: 'kaza',
          title: 'Kaza Namazı',
          icon: '⚖️',
          isEnabled: isKazaGoalEnabled,
          isCompleted: isKazaMet,
          progressText: '$todayKazaCount / $kazaGoal kaza',
        ),
      ];

  /// Total number of active goals
  int get totalActiveGoals => orderedGoals.where((g) => g.isEnabled).length;

  /// Number of completed active goals
  int get completedGoalsCount =>
      orderedGoals.where((g) => g.isEnabled && g.isCompleted).length;
}

class GoldenDayService {
  static const String prefClaimedDate = 'GoldenDay_LastClaimedDate';
  static const String prefGoldCount = 'GoldCount';
  static const String prefDiamondCount = 'DiamondCount';

  static String getTodayStr([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Calculates real-time progress for each enabled goal and determines if Golden Day is reached
  static Future<DailyGoalsStatus> checkGoldenDayStatus(AppDatabase db, [DateTime? date, String? sessionId]) async {
    final prefs = await SharedPreferences.getInstance();
    final now = date ?? DateTime.now();
    final todayStr = getTodayStr(now);
    final isDefault = sessionId == null || sessionId == UserSession.defaultSessionId;
    final sfx = isDefault ? '' : '_$sessionId';

    final isExcusedMode = PrefUtils.getBoolFromKeys(
      prefs,
      ['IsExcusedModeEnabled$sfx', 'IsSpecialDaysModeEnabled$sfx', 'IsZaruriHalEnabled$sfx', 'IsExcusedModeEnabled', 'IsSpecialDaysModeEnabled', 'IsZaruriHalEnabled'],
      false,
    );

    // 1. 5 Vakit Namaz Goal (Mandatory for Golden Day - Completed if all due prayers so far are prayed)
    const isPrayersEnabled = true;
    final prayerLogs = await (db.select(db.prayerAnswerLogs)..where((t) => t.dateStr.equals(todayStr))).get();
    final fardNames = {'Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'};
    final completedPrayers = prayerLogs
        .where((p) => fardNames.contains(p.prayerType) && p.isPerformed)
        .map((p) => p.prayerType)
        .toSet();
    final missedPrayers = prayerLogs
        .where((p) => fardNames.contains(p.prayerType) && !p.isPerformed)
        .map((p) => p.prayerType)
        .toSet();
    final completedPrayersCount = completedPrayers.length;

    // Determine due prayers for today up to current time
    final duePrayers = await PrayerTrackingService.getDuePrayersForToday(now);
    final bool isPrayersMet;
    if (isExcusedMode) {
      isPrayersMet = true;
    } else if (duePrayers.isEmpty) {
      isPrayersMet = missedPrayers.isEmpty;
    } else {
      final allDueCompleted = duePrayers.every((p) => completedPrayers.contains(p));
      final noDueMissed = !duePrayers.any((p) => missedPrayers.contains(p));
      isPrayersMet = allDueCompleted && noDueMissed;
    }

    // 2. Zikir Goal
    final isZikirEnabled = PrefUtils.getBoolFromKeys(prefs, ['IsDailyZikirGoalEnabled$sfx', 'IsZikirGoalEnabled$sfx', 'IsDailyZikirGoalEnabled', 'IsZikirGoalEnabled'], true);
    final zikirGoal = PrefUtils.getIntFromKeys(prefs, ['DailyZikirGoal$sfx', 'ZikirDailyGoal$sfx', 'DailyZikirGoal', 'ZikirDailyGoal', 'zikir_daily_goal'], 100);
    final todayLogs = await (db.select(db.zikirLogs)..where((t) => t.dateStr.equals(todayStr))).get();
    final todayZikirCount = todayLogs.fold<int>(0, (sum, item) => sum + item.count);
    final isZikirMet = !isZikirEnabled || (todayZikirCount >= zikirGoal);

    // 3. Quran Goal (Strictly checks today's reading date key to prevent carrying over previous day pages)
    final isKuranEnabled = PrefUtils.getBoolFromKeys(prefs, ['IsDailyQuranGoalEnabled$sfx', 'IsKuranGoalEnabled$sfx', 'IsDailyQuranGoalEnabled', 'IsKuranGoalEnabled'], true);
    final kuranGoal = PrefUtils.getIntFromKeys(prefs, ['DailyQuranGoal$sfx', 'KuranDailyGoal$sfx', 'DailyQuranGoal', 'KuranDailyGoal', 'kuran_daily_goal'], 5);
    final todayReadPagesKey = isDefault ? 'TodayReadPages_$todayStr' : 'TodayReadPages_${todayStr}_$sessionId';
    final todayReadPages = prefs.getInt(todayReadPagesKey) ?? 0;
    final isKuranMet = !isKuranEnabled || isExcusedMode || (todayReadPages >= kuranGoal);

    // 4. Kaza Prayers Goal (Default enabled true, robust local date matching)
    final isKazaEnabled = PrefUtils.getBoolFromKeys(prefs, ['IsDailyKazaGoalEnabled$sfx', 'IsKazaGoalEnabled$sfx', 'IsDailyKazaGoalEnabled', 'IsKazaGoalEnabled'], true);
    final kazaGoal = PrefUtils.getIntFromKeys(prefs, ['DailyKazaGoal$sfx', 'KazaDailyGoal$sfx', 'DailyKazaGoal', 'KazaDailyGoal', 'kaza_daily_goal'], 1);
    final allMelts = await db.select(db.kazaMeltLogs).get();
    final todayMelts = allMelts.where((m) {
      final loc = m.timestamp.toLocal();
      return loc.year == now.year && loc.month == now.month && loc.day == now.day;
    });
    final dbKazaCount = todayMelts.fold<int>(0, (sum, m) => sum + m.meltAmount);
    final todayKazaCount = max(dbKazaCount, PrefUtils.getInt(prefs, 'TodayKazaCount_$todayStr$sfx', PrefUtils.getInt(prefs, 'TodayKazaCount_$todayStr', 0)));
    final isKazaMet = !isKazaEnabled || (todayKazaCount >= kazaGoal);

    // 5. Memorization (Ezber / Hafızlık) Goal
    final isEzberEnabled = PrefUtils.getBoolFromKeys(prefs, ['IsHafizlikRepeatGoalEnabled$sfx', 'IsEzberGoalEnabled$sfx', 'IsHafizlikRepeatGoalEnabled', 'IsEzberGoalEnabled'], false);
    final ezberGoal = PrefUtils.getIntFromKeys(prefs, ['DailyEzberGoal$sfx', 'EzberDailyGoal$sfx', 'DailyEzberGoal', 'EzberDailyGoal', 'ezber_daily_goal'], 1);
    final todayCompletedEzber = PrefUtils.getInt(prefs, 'TodayCompletedMemorizations_$todayStr$sfx', PrefUtils.getInt(prefs, 'TodayCompletedMemorizations_$todayStr', 0));
    final hafizLog = await (db.select(db.hafizlikDailyLogs)..where((t) => t.dateStr.equals(todayStr))).getSingleOrNull();
    int hafizDoneCount = 0;
    if (hafizLog != null) {
      if (hafizLog.isHamDone) hafizDoneCount++;
      if (hafizLog.isPismisDone) hafizDoneCount++;
      if (hafizLog.isHasDone) hafizDoneCount++;
      if (hafizLog.isAsgariVirdDone) hafizDoneCount++;
    }
    final effectiveEzberDone = max(todayCompletedEzber, hafizDoneCount);
    final isEzberMet = !isEzberEnabled || (effectiveEzberDone >= ezberGoal);

    // Altın Gün criteria: ALL enabled goals must be met
    final isGoldCompleted = isPrayersMet &&
        isZikirMet &&
        isKuranMet &&
        isKazaMet &&
        isEzberMet;

    await prefs.setBool('IsTodayGoldCompleted', isGoldCompleted);
    if (isGoldCompleted) {
      await prefs.setBool('SurpriseChestAvailable_$todayStr', true);
    }

    final isChestClaimed = prefs.getBool('DailyGoldRewardClaimed_$todayStr') ?? false;

    return DailyGoalsStatus(
      isPrayersGoalEnabled: isPrayersEnabled,
      isPrayersMet: isPrayersMet,
      completedPrayersCount: completedPrayersCount,
      isZikirGoalEnabled: isZikirEnabled,
      isZikirMet: isZikirMet,
      todayZikirCount: todayZikirCount,
      zikirGoal: zikirGoal,
      isKuranGoalEnabled: isKuranEnabled,
      isKuranMet: isKuranMet,
      todayKuranPages: todayReadPages,
      kuranGoal: kuranGoal,
      isEzberGoalEnabled: isEzberEnabled,
      isEzberMet: isEzberMet,
      todayEzberCount: effectiveEzberDone,
      ezberGoal: ezberGoal,
      isKazaGoalEnabled: isKazaEnabled,
      isKazaMet: isKazaMet,
      todayKazaCount: todayKazaCount,
      kazaGoal: kazaGoal,
      isExcusedMode: isExcusedMode,
      isGoldCompleted: isGoldCompleted,
      isChestClaimed: isChestClaimed,
    );
  }

  /// Checks whether today's surprise chest has already been claimed
  static Future<bool> isTodayChestClaimed() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = getTodayStr();
    return prefs.getBool('DailyGoldRewardClaimed_$todayStr') ?? false;
  }

  static String _sKey(String base, String? sessionId) {
    if (sessionId != null && sessionId != UserSession.defaultSessionId) {
      return '${base}_$sessionId';
    }
    return base;
  }

  static Future<void> _addGoldPref(SharedPreferences prefs, int amount, String? sessionId) async {
    final key = _sKey('GoldCount', sessionId);
    final cur = prefs.getInt(key) ?? (prefs.getInt('GoldCount') ?? 0);
    final newCount = cur + amount;
    await prefs.setInt(key, newCount);
    if (sessionId == null || sessionId == UserSession.defaultSessionId) {
      await prefs.setInt('GoldCount', newCount);
    }
  }

  static Future<void> _addDiamondPref(SharedPreferences prefs, int amount, String? sessionId) async {
    final key = _sKey('DiamondCount', sessionId);
    final cur = prefs.getInt(key) ?? (prefs.getInt('DiamondCount') ?? 0);
    final newCount = cur + amount;
    await prefs.setInt(key, newCount);
    if (sessionId == null || sessionId == UserSession.defaultSessionId) {
      await prefs.setInt('DiamondCount', newCount);
    }
  }

  /// Claims pending rewards (e.g. gold won before Yatsi prayer) when Yatsi is prayed
  static Future<int> claimPendingRewardsIfAny(String todayStr, [String? sessionId]) async {
    final prefs = await SharedPreferences.getInstance();
    final isDefault = sessionId == null || sessionId == UserSession.defaultSessionId;
    final sfx = isDefault ? '' : '_$sessionId';
    final pendingGold = prefs.getInt('PendingGoldReward_$todayStr$sfx') ?? (prefs.getInt('PendingGoldReward_$todayStr') ?? 0);
    final pendingDiamond = prefs.getInt('PendingDiamondReward_$todayStr$sfx') ?? (prefs.getInt('PendingDiamondReward_$todayStr') ?? 0);

    if (pendingGold > 0 || pendingDiamond > 0) {
      if (pendingGold > 0) {
        await _addGoldPref(prefs, pendingGold, sessionId);
        await prefs.setInt('PendingGoldReward_$todayStr$sfx', 0);
        if (isDefault) await prefs.setInt('PendingGoldReward_$todayStr', 0);
      }
      if (pendingDiamond > 0) {
        await _addDiamondPref(prefs, pendingDiamond, sessionId);
        await prefs.setInt('PendingDiamondReward_$todayStr$sfx', 0);
        if (isDefault) await prefs.setInt('PendingDiamondReward_$todayStr', 0);
      }
      await prefs.setBool('PendingRewardsClaimedAtYatsi_$todayStr$sfx', true);
      return pendingGold;
    }
    return 0;
  }

  /// Opens the daily surprise chest and rolls for rewards (15% Bird, 40% Diamond, 45% Gold)
  /// Gold is held pending until Yatsı prayer if Yatsı is not yet prayed today.
  static Future<SurpriseChestReward?> openDailySurpriseChest({
    required AppDatabase db,
    required bool isTurkish,
    String? sessionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = getTodayStr();
    final isDefault = sessionId == null || sessionId == UserSession.defaultSessionId;
    final sfx = isDefault ? '' : '_$sessionId';
    final chestOpenedKey = 'DailyGoldRewardClaimed_$todayStr$sfx';

    if (prefs.getBool(chestOpenedKey) ?? (prefs.getBool('DailyGoldRewardClaimed_$todayStr') ?? false)) {
      return null;
    }

    // Check if Yatsi prayer is already completed or excused
    final isExcusedMode = PrefUtils.getBoolFromKeys(
      prefs,
      ['IsExcusedModeEnabled$sfx', 'IsSpecialDaysModeEnabled$sfx', 'IsZaruriHalEnabled$sfx', 'IsExcusedModeEnabled', 'IsSpecialDaysModeEnabled', 'IsZaruriHalEnabled'],
      false,
    );
    final prayerLogs = await (db.select(db.prayerAnswerLogs)..where((t) => t.dateStr.equals(todayStr))).get();
    final isYatsiCompleted = isExcusedMode || prayerLogs.any((p) => p.prayerType == 'Yatsı' && p.isPerformed);

    final random = Random();
    final roll = random.nextInt(100) + 1; // 1 to 100
    SurpriseChestReward reward;

    if (roll <= 15) {
      // 15% Chance: Mertebe Kuşu (Rank Bird)
      final allRanks = UserRank.getAllRanks();
      final birdsKey = isDefault ? 'UnlockedBirds' : 'UnlockedBirds_$sessionId';
      final unlockedBirdsStr = prefs.getString(birdsKey) ?? (prefs.getString('UnlockedBirds') ?? '');
      final unlockedSet = unlockedBirdsStr.split(',').where((s) => s.isNotEmpty).toSet();

      final lockedBirds = allRanks
          .where((r) => r.birdAnimationFile.isNotEmpty && !unlockedSet.contains(r.birdAnimationFile))
          .toList();

      if (lockedBirds.isNotEmpty) {
        final chosenRank = lockedBirds[random.nextInt(lockedBirds.length)];
        unlockedSet.add(chosenRank.birdAnimationFile);
        final joinedBirds = unlockedSet.join(',');
        await prefs.setString(birdsKey, joinedBirds);
        if (isDefault) await prefs.setString('UnlockedBirds', joinedBirds);

        // Save badge unlock to DB
        await db.into(db.unlockedBadges).insertOnConflictUpdate(
          UnlockedBadgesCompanion(
            badgeId: Value('bird_${chosenRank.birdAnimationFile}'),
            unlockedAt: Value(DateTime.now()),
            category: const Value('RankBird'),
          ),
        );

        reward = SurpriseChestReward(
          type: ChestRewardType.bird,
          birdFileName: chosenRank.birdAnimationFile,
          birdName: chosenRank.name,
          birdBadge: chosenRank.badge,
          message: isTurkish
              ? '🎉 Harika! Sürpriz sandıktan ${chosenRank.badge} ${chosenRank.name} Mertebe Kuşu çıktı! Kuş profilinize eklendi.'
              : '🎉 Awesome! You unlocked ${chosenRank.badge} ${chosenRank.name} Bird from the chest!',
        );
      } else {
        // All birds already unlocked -> Legendary Master Bonus (100 Gold + 15 Diamonds)
        const earnedGold = 100;
        const earnedDiamonds = 15;

        if (isYatsiCompleted) {
          await _addGoldPref(prefs, earnedGold, sessionId);
          await _addDiamondPref(prefs, earnedDiamonds, sessionId);
        } else {
          await prefs.setInt('PendingGoldReward_$todayStr$sfx', earnedGold);
          await prefs.setInt('PendingDiamondReward_$todayStr$sfx', earnedDiamonds);
        }

        reward = SurpriseChestReward(
          type: ChestRewardType.legendaryBonus,
          goldAmount: earnedGold,
          diamondAmount: earnedDiamonds,
          isPendingYatsi: !isYatsiCompleted,
          message: isTurkish
              ? (isYatsiCompleted
                  ? '👑 Efsanevi Başarı! Bütün mertebe kuşlarına sahipsiniz. Sandıktan $earnedGold Altın ve $earnedDiamonds Elmas çıktı!'
                  : '👑 Efsanevi Başarı! Bütün mertebe kuşlarına sahipsiniz. Sandıktan $earnedGold Altın ve $earnedDiamonds Elmas çıktı!\n\n(Ödülleriniz günün son namazı olan Yatsı namazını kıldığınızda hesabınıza aktarılacaktır.)')
              : '👑 Legendary! You have all birds. You received $earnedGold Gold and $earnedDiamonds Diamonds!',
        );
      }
    } else if (roll <= 55) {
      // 40% Chance: Diamonds (5 to 15 💎)
      final earnedDiamonds = random.nextInt(11) + 5;
      await _addDiamondPref(prefs, earnedDiamonds, sessionId);

      reward = SurpriseChestReward(
        type: ChestRewardType.diamond,
        diamondAmount: earnedDiamonds,
        message: isTurkish
            ? '💎 Şanslı Gün! Sürpriz sandıktan +$earnedDiamonds Elmas kazandınız!'
            : '💎 Lucky Day! You received +$earnedDiamonds Diamonds from the chest!',
      );
    } else {
      // 45% Chance: Gold (30 to 75 🪙)
      final earnedGold = random.nextInt(46) + 30;

      if (isYatsiCompleted) {
        await _addGoldPref(prefs, earnedGold, sessionId);
      } else {
        await prefs.setInt('PendingGoldReward_$todayStr$sfx', earnedGold);
      }

      reward = SurpriseChestReward(
        type: ChestRewardType.gold,
        goldAmount: earnedGold,
        isPendingYatsi: !isYatsiCompleted,
        message: isTurkish
            ? (isYatsiCompleted
                ? '🪙 Bereketli Gün! Sürpriz sandıktan +$earnedGold Altın kazandınız! Hesabınıza eklendi.'
                : '🪙 Bereketli Gün! Sürpriz sandıktan +$earnedGold Altın çıktı! 🎉\n\n(Altınlarınız günün son namazı olan Yatsı namazını kıldığınızda hesabınıza aktarılacaktır.)')
            : '🪙 Prosperous Day! You received +$earnedGold Gold from the chest!',
      );
    }

    await prefs.setBool(chestOpenedKey, true);
    if (isDefault) await prefs.setBool('DailyGoldRewardClaimed_$todayStr', true);
    await WidgetSyncService.syncAll(db);

    return reward;
  }
}
