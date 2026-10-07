import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organicscore/features/monetization/domain/subscription_service.dart';
import 'package:organicscore/features/profile/domain/user_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await UserProfileService.instance.loadProfile();
  });

  group('SubscriptionService & 5-Contribution Milestone Tests', () {
    test('Initial contributions is 0 and cycle progress is 0', () async {
      final service = SubscriptionService.instance;
      final total = await service.getTotalContributions();
      final progress = await service.getContributionCycleProgress();

      expect(total, equals(0));
      expect(progress, equals(0));
    });

    test('Contributions 1 to 4 record progress but do NOT unlock 24h ad-free', () async {
      final service = SubscriptionService.instance;

      for (int i = 1; i <= 4; i++) {
        final result = await service.rewardContribution();
        expect(result.success, isTrue);
        expect(result.reachedMilestone, isFalse);
        expect(result.currentPoints, equals(i));
        expect(result.message, contains('$i/5 Ürün'));
      }

      final isAdFree = await service.isAdFree();
      expect(isAdFree, isFalse);
    });

    test('5th contribution activates 24h ad-free and awards milestone message', () async {
      final service = SubscriptionService.instance;

      // 1st to 4th
      for (int i = 1; i <= 4; i++) {
        await service.rewardContribution();
      }

      // 5th contribution
      final fifthResult = await service.rewardContribution();
      expect(fifthResult.success, isTrue);
      expect(fifthResult.reachedMilestone, isTrue);
      expect(fifthResult.currentPoints, equals(5));
      expect(fifthResult.message, contains('+24 Saat Reklamsız Kullanım aktifleşti'));

      // Verify ad-free is now active
      final isAdFree = await service.isAdFree();
      expect(isAdFree, isTrue);

      final remaining = await service.getRemainingAdFreeDuration();
      expect(remaining.inHours, greaterThanOrEqualTo(23));

      // UserProfileService contributions and XP should also be synchronized
      expect(UserProfileService.instance.profile.totalContributions, equals(5));
      expect(UserProfileService.instance.profile.xp, greaterThan(0));
    });
  });
}
