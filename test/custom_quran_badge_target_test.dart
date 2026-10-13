import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/features/gamification/models/badge_models.dart';
import 'package:zikirce/features/gamification/services/custom_badge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('CustomQuranBadge Target & Daily Goal Tests', () {
    test('100 Target badge accurately reports progress without hardcoded 40', () {
      final badge = CustomQuranBadge(
        id: 'test_100',
        title: 'İhlas Virdi',
        targetDays: 100,
        totalReadCount: 4,
        currentStreak: 2,
      );

      expect(badge.targetDays, 100);
      expect(badge.isInfinite, false);
      expect(badge.progressRatio, 0.04);
      expect(badge.progressText, contains('4/100 Okuma'));
      expect(badge.progressText, isNot(contains('/40')));
    });

    test('Infinite goal (Sonsuz Vird) badge initializes as unlocked and formats correctly', () {
      final badge = CustomQuranBadge(
        id: 'test_inf',
        title: 'Sonsuz İhlas',
        targetDays: 0,
        totalReadCount: 15,
        currentStreak: 5,
        isUnlocked: true,
      );

      expect(badge.isInfinite, true);
      expect(badge.targetDays, 0);
      expect(badge.progressText, contains('15 Okuma (Sonsuz)'));
      expect(badge.isUnlocked, true);
    });

    test('Daily target requires meeting todayReadCount before advancing streak', () async {
      final badge = CustomQuranBadge(
        id: 'test_daily',
        title: 'Günde 3 İhlas',
        scope: 'Surah',
        scopeValue: '112',
        targetDays: 100,
        dailyTarget: 3,
        todayReadCount: 0,
        currentStreak: 0,
        totalReadCount: 0,
      );

      await CustomBadgeService.saveCustomBadge(badge);

      // Read 1st time
      await CustomBadgeService.onSurahRead(112);
      var badges = await CustomBadgeService.getCustomBadges();
      expect(badges.first.totalReadCount, 1);
      expect(badges.first.todayReadCount, 1);
      // Daily target (3) not reached yet, streak remains 0
      expect(badges.first.currentStreak, 0);

      // Read 2nd time
      await CustomBadgeService.onSurahRead(112);
      badges = await CustomBadgeService.getCustomBadges();
      expect(badges.first.totalReadCount, 2);
      expect(badges.first.todayReadCount, 2);
      expect(badges.first.currentStreak, 0);

      // Read 3rd time -> Reaches daily target (3) -> Streak advances to 1!
      await CustomBadgeService.onSurahRead(112);
      badges = await CustomBadgeService.getCustomBadges();
      expect(badges.first.totalReadCount, 3);
      expect(badges.first.todayReadCount, 3);
      expect(badges.first.currentStreak, 1);
    });

    test('JSON serialization preserves dailyTarget, todayReadCount, and todayDate', () {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final badge = CustomQuranBadge(
        id: 'test_json',
        title: 'Virdim',
        targetDays: 313,
        dailyTarget: 5,
        todayReadCount: 4,
        todayDate: todayStr,
      );

      final json = badge.toJson();
      expect(json['targetDays'], 313);
      expect(json['dailyTarget'], 5);
      expect(json['todayReadCount'], 4);
      expect(json['todayDate'], todayStr);

      final revived = CustomQuranBadge.fromJson(json);
      expect(revived.targetDays, 313);
      expect(revived.dailyTarget, 5);
      expect(revived.todayReadCount, 4);
    });
  });
}
