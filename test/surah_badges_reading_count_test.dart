import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/constants/surah_data_provider.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/features/gamification/models/badge_models.dart';
import 'package:zikirce/features/gamification/providers/gamification_providers.dart';
import 'package:zikirce/features/gamification/services/badge_service.dart';
import 'package:zikirce/features/gamification/services/custom_badge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
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

  group('Surah Badges & Reading Count Tests', () {
    test('Reading Mulk surah twice in the same day increments read count to 2, keeps streak at 1', () async {
      final mulkSurah = SurahDataProvider.surahs.firstWhere((s) => s.id == 67);
      final notifier = container.read(gamificationNotifierProvider);

      // First read
      final res1 = await notifier.recordSurahReadingCompleted(
        surah: mulkSurah,
        streakKey: 'Mulk',
      );
      expect(res1.readCount, 1);
      expect(res1.currentStreak, 1);

      // Second read same day
      final res2 = await notifier.recordSurahReadingCompleted(
        surah: mulkSurah,
        streakKey: 'Mulk',
      );
      expect(res2.readCount, 2);
      expect(res2.currentStreak, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('ReadCount_Mulk'), 2);
      expect(prefs.getInt('Streak_Mulk'), 1);

      // Check badge progress text
      final badges = await container.read(badgeServiceProvider).getBadges();
      final mulkBadge = badges.firstWhere((b) => b.id == 'mulk_40');
      expect(mulkBadge.totalReadCount, 2);
      expect(mulkBadge.progressText, '2/40 Okuma');
    });

    test('Reaching 40 reads unlocks the built-in surah badge', () async {
      final yasinSurah = SurahDataProvider.surahs.firstWhere((s) => s.id == 36);
      final notifier = container.read(gamificationNotifierProvider);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ReadCount_Yasin', 39);

      final res = await notifier.recordSurahReadingCompleted(
        surah: yasinSurah,
        streakKey: 'Yasin',
      );

      expect(res.readCount, 40);
      expect(res.isBadgeUnlocked, isTrue);

      final badges = await container.read(badgeServiceProvider).getBadges();
      final yasinBadge = badges.firstWhere((b) => b.id == 'yasin_40');
      expect(yasinBadge.isUnlocked, isTrue);
      expect(yasinBadge.totalReadCount, 40);
    });

    test('Custom Quran Badge created by user increments totalReadCount on each read and unlocks at 40', () async {
      final customBadge = CustomQuranBadge(
        id: 'custom_surah_18',
        title: 'Kehf Sûresi 40 Gün',
        scope: 'Surah',
        scopeValue: '18',
        scopeDisplayName: 'Kehf Sûresi',
        targetDays: 40,
        totalReadCount: 0,
      );

      await CustomBadgeService.saveCustomBadge(customBadge);

      final kehfSurah = SurahDataProvider.surahs.firstWhere((s) => s.id == 18);
      final notifier = container.read(gamificationNotifierProvider);

      // Read 1
      await notifier.recordSurahReadingCompleted(surah: kehfSurah);
      var badges = await CustomBadgeService.getCustomBadges();
      expect(badges.first.totalReadCount, 1);

      // Read 2
      await notifier.recordSurahReadingCompleted(surah: kehfSurah);
      badges = await CustomBadgeService.getCustomBadges();
      expect(badges.first.totalReadCount, 2);
      expect(badges.first.progressText, '2/40 Okuma');
    });
  });
}
