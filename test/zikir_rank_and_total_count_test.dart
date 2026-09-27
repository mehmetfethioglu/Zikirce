import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/features/gamification/models/user_rank.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserRank and Spiritual Rank Calculation Tests', () {
    test('UserRank levels and criteria thresholds work correctly', () {
      final r0 = UserRank.calculateRank(0);
      expect(r0.level, UserRankLevel.none);
      expect(r0.name, 'Yeni Başlayan');
      expect(r0.badge, '🐣');
      expect(r0.requiredZikir, 0);
      expect(r0.nextLevelZikir, 500000);

      // User with 197,143 zikrs
      final r197k = UserRank.calculateRank(197143);
      expect(r197k.level, UserRankLevel.none);
      expect(r197k.name, 'Yeni Başlayan');

      // User with 497,143 zikrs (497.1K)
      final r497k = UserRank.calculateRank(497143);
      expect(r497k.level, UserRankLevel.none);
      expect(r497k.name, 'Yeni Başlayan');

      final nextRankFor497k = UserRank.getNextRank(497143);
      expect(nextRankFor497k, isNotNull);
      expect(nextRankFor497k!.level, UserRankLevel.niyet);
      expect(nextRankFor497k.name, 'Niyet');
      expect(nextRankFor497k.requiredZikir, 500000);
      expect(nextRankFor497k.requiredZikir - 497143, 2857);

      // Threshold tests
      final r500k = UserRank.calculateRank(500000);
      expect(r500k.level, UserRankLevel.niyet);
      expect(r500k.name, 'Niyet');
      expect(r500k.badge, '🐥');

      final r1m = UserRank.calculateRank(1000000);
      expect(r1m.level, UserRankLevel.istikamet);
      expect(r1m.name, 'İstikamet');
      expect(r1m.badge, '🐦');

      final r3m = UserRank.calculateRank(3000000);
      expect(r3m.level, UserRankLevel.mudavemet);
      expect(r3m.name, 'Müdavemet');

      final r7m = UserRank.calculateRank(7000000);
      expect(r7m.level, UserRankLevel.sebat);
      expect(r7m.name, 'Sebat');

      final r15m = UserRank.calculateRank(15000000);
      expect(r15m.level, UserRankLevel.azimet);
      expect(r15m.name, 'Azimet');

      final r25m = UserRank.calculateRank(25000000);
      expect(r25m.level, UserRankLevel.ihlas);
      expect(r25m.name, 'İhlas');

      final r40m = UserRank.calculateRank(40000000);
      expect(r40m.level, UserRankLevel.tevekul);
      expect(r40m.name, 'Tevekkül');

      final r63m = UserRank.calculateRank(63000000);
      expect(r63m.level, UserRankLevel.sukur);
      expect(r63m.name, 'Şükür');

      final r80m = UserRank.calculateRank(80000000);
      expect(r80m.level, UserRankLevel.riza);
      expect(r80m.name, 'Rıza');

      final r99m = UserRank.calculateRank(99000000);
      expect(r99m.level, UserRankLevel.yakin);
      expect(r99m.name, 'Yakin');
    });

    test('getAllRanks contains all 11 ranks in ascending order', () {
      final ranks = UserRank.getAllRanks();
      expect(ranks.length, 11);
      expect(ranks.first.level, UserRankLevel.none);
      expect(ranks.last.level, UserRankLevel.yakin);

      for (int i = 0; i < ranks.length - 1; i++) {
        expect(ranks[i].requiredZikir <= ranks[i + 1].requiredZikir, isTrue);
      }
    });
  });

  group('Database & Transferred Dhikr Total Integration Tests', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Database Zikirs and ZikirLogs correctly sum and incorporate transfers', () async {
      final prefs = await SharedPreferences.getInstance();

      // Insert base zikirs
      final zikir1 = await db.into(db.zikirs).insertReturning(
        ZikirsCompanion.insert(
          name: 'Sübhanallah',
          target: const Value(33),
          totalCount: const Value(100000),
        ),
      );

      await db.into(db.zikirs).insertReturning(
        ZikirsCompanion.insert(
          name: 'Elhamdülillah',
          target: const Value(33),
          totalCount: const Value(97143),
        ),
      );

      // Total from Zikirs table is 197,143
      var allZikirs = await db.select(db.zikirs).get();
      var zikirsSum = allZikirs.fold<int>(0, (sum, z) => sum + z.totalCount);
      expect(zikirsSum, 197143);

      // Now simulate Zikirmatik transfer of 300,000
      final transferAmount = 300000;
      final newTotal = zikir1.totalCount + transferAmount;
      await (db.update(db.zikirs)..where((t) => t.id.equals(zikir1.id))).write(
        ZikirsCompanion(
          totalCount: Value(newTotal),
        ),
      );

      await db.into(db.zikirLogs).insert(
        ZikirLogsCompanion.insert(
          zikirId: zikir1.id,
          count: transferAmount,
          dateStr: '2026-08-24',
        ),
      );

      await prefs.setInt('TotalZikir', 497143);

      allZikirs = await db.select(db.zikirs).get();
      zikirsSum = allZikirs.fold<int>(0, (sum, z) => sum + z.totalCount);
      expect(zikirsSum, 497143);

      final allLogs = await db.select(db.zikirLogs).get();
      final logsSum = allLogs.fold<int>(0, (sum, l) => sum + l.count);
      expect(logsSum, 300000);

      final prefsTotal = prefs.getInt('TotalZikir') ?? 0;
      expect(prefsTotal, 497143);

      final effectiveTotal = zikirsSum > logsSum ? (zikirsSum > prefsTotal ? zikirsSum : prefsTotal) : (logsSum > prefsTotal ? logsSum : prefsTotal);
      expect(effectiveTotal, 497143);

      final rank = UserRank.calculateRank(effectiveTotal);
      expect(rank.name, 'Yeni Başlayan');

      final nextRank = UserRank.getNextRank(effectiveTotal);
      expect(nextRank!.name, 'Niyet');
      expect(nextRank.requiredZikir - effectiveTotal, 2857);
    });
  });
}
