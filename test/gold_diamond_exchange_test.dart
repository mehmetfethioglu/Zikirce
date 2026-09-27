import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/localization/translations/app_strings_tr.dart';
import 'package:zikirce/core/localization/translations/app_strings_en.dart';
import 'package:zikirce/features/gamification/providers/gamification_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'GoldCount': 50,
      'DiamondCount': 2,
    });
    db = AppDatabase(NativeDatabase.memory());
    
    // Update seeded initial user streak in DB
    await db.update(db.userStreaks).write(
      const UserStreaksCompanion(
        currentStreak: drift.Value(5),
        bestStreak: drift.Value(10),
        freezeCount: drift.Value(2),
        xp: drift.Value(50),
        rank: drift.Value('Mübtedi'),
      ),
    );

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Gold to Diamond Exchange Tests', () {
    test('Exchange 5 Gold for 1 Diamond succeeds and updates both DB and Prefs', () async {
      final notifier = container.read(gamificationNotifierProvider);

      final success = await notifier.convertGoldToDiamonds(5);
      expect(success, isTrue);

      final gold = await container.read(goldCountProvider.future);
      final diamonds = await container.read(diamondCountProvider.future);

      expect(gold, equals(45));
      expect(diamonds, equals(3));

      // Verify DB row (Gold/XP updated, Shields/freezeCount decoupled)
      final streak = await db.select(db.userStreaks).getSingle();
      expect(streak.xp, equals(45));
      expect(streak.freezeCount, equals(2)); // Shield count remains intact

      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('GoldCount'), equals(45));
      expect(prefs.getInt('DiamondCount'), equals(3));
    });

    test('Buy 1 Shield with 5 Diamonds deducts 5 diamonds and increments freezeCount', () async {
      final notifier = container.read(gamificationNotifierProvider);

      // Set initial diamonds to 10
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('DiamondCount', 10);
      container.read(badgeRefreshTriggerProvider.notifier).state++;

      final success = await notifier.buyShieldWithDiamonds(1);
      expect(success, isTrue);

      final diamonds = await container.read(diamondCountProvider.future);
      expect(diamonds, equals(5)); // 10 - 5 = 5

      final streak = await db.select(db.userStreaks).getSingle();
      expect(streak.freezeCount, equals(3)); // 2 + 1 = 3 shields
    });

    test('Exchange 25 Gold gives 5 Diamonds', () async {
      final notifier = container.read(gamificationNotifierProvider);

      final success = await notifier.convertGoldToDiamonds(25);
      expect(success, isTrue);

      final gold = await container.read(goldCountProvider.future);
      final diamonds = await container.read(diamondCountProvider.future);

      expect(gold, equals(25));
      expect(diamonds, equals(7));
    });

    test('Exchange with insufficient gold fails and retains original balance', () async {
      final notifier = container.read(gamificationNotifierProvider);

      final success = await notifier.convertGoldToDiamonds(100); // Only 50 available
      expect(success, isFalse);

      final gold = await container.read(goldCountProvider.future);
      final diamonds = await container.read(diamondCountProvider.future);

      expect(gold, equals(50));
      expect(diamonds, equals(2));
    });

    test('Exchange with less than 5 gold fails', () async {
      final notifier = container.read(gamificationNotifierProvider);

      final success = await notifier.convertGoldToDiamonds(4);
      expect(success, isFalse);
    });

    test('Localization keys for Exchange exist in TR and EN', () {
      final requiredKeys = [
        'Exchange_Title',
        'Exchange_Subtitle',
        'Exchange_CurrentGold',
        'Exchange_CurrentDiamonds',
        'Exchange_RateNotice',
        'Exchange_QuickPacks',
        'Exchange_Pack1',
        'Exchange_Pack5',
        'Exchange_Pack10',
        'Exchange_PackAll',
        'Exchange_AmountToConvert',
        'Exchange_Cost',
        'Exchange_Reward',
        'Exchange_ConvertBtn',
        'Exchange_InsufficientGold',
        'Exchange_Success',
        'Exchange_ConvertToUnlockBadge',
      ];

      for (final key in requiredKeys) {
        expect(appStringsTr.containsKey(key), isTrue, reason: 'TR missing $key');
        expect(appStringsEn.containsKey(key), isTrue, reason: 'EN missing $key');
      }
    });
  });
}
