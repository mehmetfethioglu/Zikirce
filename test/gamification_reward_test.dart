import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/constants/surah_data_provider.dart';
import 'package:zikirce/features/gamification/providers/gamification_providers.dart';
import 'package:zikirce/features/zikir/providers/zikir_providers.dart';

final testZikirNotifierProvider = StateNotifierProvider<ZikirCounterNotifier, ZikirCounterState>((ref) {
  final db = ref.watch(databaseProvider);
  final zikir = Zikir(
    id: 1,
    name: 'Sübhanallâh',
    target: 33,
    currentCount: 32,
    totalCount: 32,
    lap: 0,
    isFavorite: false,
    category: 'genel',
    soundEffect: 'bulbul',
    vibrationEnabled: false,
    createdAt: DateTime.now(),
  );
  return ZikirCounterNotifier(ref, db, zikir);
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'GoldCount': 0,
      'DiamondCount': 0,
    });
    db = AppDatabase(NativeDatabase.memory());

    // Update seeded user streak row with 0 xp
    await db.update(db.userStreaks).write(
      const UserStreaksCompanion(
        currentStreak: drift.Value(1),
        bestStreak: drift.Value(1),
        totalDays: drift.Value(1),
        freezeCount: drift.Value(3),
        xp: drift.Value(0),
      ),
    );

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  group('Gamification Reward Mechanics Tests', () {
    test('Completing a zikir target awards 50 Gold and syncs DB and Prefs', () async {
      final initialGold = await container.read(goldCountProvider.future);
      expect(initialGold, equals(0));

      final notifier = container.read(testZikirNotifierProvider.notifier);

      // Increment 1 more to reach target (33 / 33)
      notifier.increment(isSoundEnabled: false, isVibrationEnabled: false);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify that 50 Gold is awarded
      final goldAfter = await container.read(goldCountProvider.future);
      expect(goldAfter, equals(50));

      // Verify DB row
      final streak = await (db.select(db.userStreaks)..limit(1)).getSingle();
      expect(streak.xp, equals(50));

      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('GoldCount'), equals(50));
    });

    test('Completing a Surah awards 50 Gold (+25 streak XP) and syncs DB and Prefs', () async {
      final notifier = container.read(gamificationNotifierProvider);

      final testSurah = SurahDataProvider.surahs.first;

      final result = await notifier.recordSurahReadingCompleted(surah: testSurah);
      expect(result.xpGained, equals(50));

      // 50 XP from Surah + 25 XP from advancing daily streak = 75
      final gold = await container.read(goldCountProvider.future);
      expect(gold, equals(75));

      final streak = await (db.select(db.userStreaks)..limit(1)).getSingle();
      expect(streak.xp, equals(75));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('GoldCount'), equals(75));
    });

    test('goldCountProvider self-heals when DB and SharedPreferences diverge', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('GoldCount', 25);

      // DB has 150 xp
      await (db.update(db.userStreaks)).write(
        const UserStreaksCompanion(xp: drift.Value(150)),
      );

      container.read(badgeRefreshTriggerProvider.notifier).state++;
      final effectiveGold = await container.read(goldCountProvider.future);

      // Must take the authoritative maximum (150)
      expect(effectiveGold, equals(150));

      // Prefs must be self-healed to 150
      expect(prefs.getInt('GoldCount'), equals(150));
    });

    test('addDiamonds updates both prefs and Riverpod provider', () async {
      final notifier = container.read(gamificationNotifierProvider);

      await notifier.addDiamonds(3);

      final diamonds = await container.read(diamondCountProvider.future);
      expect(diamonds, equals(3));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('DiamondCount'), equals(3));
    });
  });
}
