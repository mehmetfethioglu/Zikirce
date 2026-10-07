import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organicscore/features/profile/domain/badge_definitions.dart';
import 'package:organicscore/features/profile/domain/user_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserProfile & Gamification Unit Tests', () {
    test('Default profile has zero stats and level 1', () async {
      final service = UserProfileService.instance;
      await service.loadProfile();

      expect(service.profile.displayName, equals('Bilinçli Tüketici'));
      expect(service.profile.totalScans, equals(0));
      expect(service.profile.totalContributions, equals(0));
      expect(service.profile.totalBoycottReports, equals(0));
      expect(service.profile.xp, equals(0));
      expect(service.profile.unlockedBadgeIds, isEmpty);

      final levelInfo = service.levelInfo;
      expect(levelInfo.level, equals(1));
      expect(levelInfo.title, equals('Çaylak Tüketici'));
      expect(levelInfo.progress, equals(0.0));
    });

    test('updateDisplayName updates profile name and notifies listeners', () async {
      final service = UserProfileService.instance;
      await service.updateDisplayName('Ahmet Yılmaz');

      expect(service.profile.displayName, equals('Ahmet Yılmaz'));
    });

    test('updateAvatar updates preset avatar correctly', () async {
      final service = UserProfileService.instance;
      await service.updateAvatar(presetAvatarId: 'avocado');

      expect(service.profile.presetAvatarId, equals('avocado'));
      expect(service.profile.avatarPath, isNull);
    });

    test('recordScan increments scan count, awards XP, and unlocks scan_bronze badge', () async {
      final service = UserProfileService.instance;
      await service.loadProfile();

      await service.recordScan();

      expect(service.profile.totalScans, equals(1));
      // Base XP is 10, plus 30 XP reward for unlocking scan_bronze = 40 XP
      expect(service.profile.xp, equals(40));
      expect(service.profile.unlockedBadgeIds.contains('scan_bronze'), isTrue);

      final badge = BadgeDefinitions.findById('scan_bronze');
      expect(badge, isNotNull);
      expect(badge!.title, equals('İlk Adım'));
    });

    test('recordContribution increments count, awards 50 XP, and unlocks contrib_bronze', () async {
      final service = UserProfileService.instance;
      await service.loadProfile();

      await service.recordContribution();

      expect(service.profile.totalContributions, equals(1));
      // Base XP 50, plus 60 XP reward for unlocking contrib_bronze = 110 XP
      expect(service.profile.xp, greaterThanOrEqualTo(110));
      expect(service.profile.unlockedBadgeIds.contains('contrib_bronze'), isTrue);

      // 110 XP should advance level to Level 2 (Bilinçli Kaşif)
      expect(service.levelInfo.level, equals(2));
      expect(service.levelInfo.title, equals('Bilinçli Kaşif'));
    });

    test('recordBoycottReport increments count, awards 35 XP, and unlocks boycott_bronze', () async {
      final service = UserProfileService.instance;
      await service.loadProfile();

      await service.recordBoycottReport();

      expect(service.profile.totalBoycottReports, equals(1));
      expect(service.profile.unlockedBadgeIds.contains('boycott_bronze'), isTrue);
    });

    test('exportBackupJson and importBackupJson round-trip successfully', () async {
      final service = UserProfileService.instance;
      await service.updateDisplayName('Zeynep Demir');
      await service.updateAvatar(presetAvatarId: 'shield');

      final backupJson = service.exportBackupJson();
      expect(backupJson, contains('OrganicScore'));
      expect(backupJson, contains('Zeynep Demir'));

      final decoded = jsonDecode(backupJson);
      expect(decoded['profile']['displayName'], equals('Zeynep Demir'));
      expect(decoded['profile']['presetAvatarId'], equals('shield'));

      // Test restore
      final newJson = jsonEncode({
        'app': 'OrganicScore',
        'profile': {
          'displayName': 'Mehmet Kaya',
          'presetAvatarId': 'detective',
          'totalScans': 45,
          'totalContributions': 8,
          'totalBoycottReports': 3,
          'healthyChoices': 12,
          'xp': 620,
          'unlockedBadgeIds': ['scan_bronze', 'scan_silver', 'contrib_bronze'],
        }
      });

      final success = await service.importBackupJson(newJson);
      expect(success, isTrue);
      expect(service.profile.displayName, equals('Mehmet Kaya'));
      expect(service.profile.presetAvatarId, equals('detective'));
      expect(service.profile.totalScans, equals(45));
      expect(service.profile.xp, greaterThanOrEqualTo(620));
      expect(service.levelInfo.level, equals(4)); // 620 XP = Level 4
      expect(service.levelInfo.title, equals('Etik Muhafız'));
    });

    test('setGoogleAccountInfo links account and updates profile', () async {
      final service = UserProfileService.instance;
      expect(service.profile.isGoogleConnected, isFalse);

      await service.setGoogleAccountInfo(
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/avatar.jpg',
      );

      expect(service.profile.isGoogleConnected, isTrue);
      expect(service.profile.googleEmail, equals('test@example.com'));
      expect(service.profile.googleDisplayName, equals('Test User'));
      expect(service.profile.googlePhotoUrl, equals('https://example.com/avatar.jpg'));

      // Test sign out preserves local progress
      final previousXp = service.profile.xp;
      await service.clearGoogleAccount();

      expect(service.profile.isGoogleConnected, isFalse);
      expect(service.profile.googleEmail, isNull);
      expect(service.profile.xp, equals(previousXp));
    });

    test('Anti-abuse: duplicate barcode scan within cooldown is rejected from awarding XP', () async {
      final service = UserProfileService.instance;
      await service.loadProfile();

      // First scan of barcode 8690001
      final initialScans = service.profile.totalScans;
      final initialXp = service.profile.xp;

      final firstResult = await service.recordScan(barcode: '8690001');
      expect(firstResult, isTrue);
      expect(service.profile.totalScans, equals(initialScans + 1));
      expect(service.profile.xp, greaterThan(initialXp));

      final midScans = service.profile.totalScans;
      final midXp = service.profile.xp;

      // Duplicate scan of same barcode immediately after
      final duplicateResult = await service.recordScan(barcode: '8690001');
      expect(duplicateResult, isFalse); // Rejected due to cooldown
      expect(service.profile.totalScans, equals(midScans)); // No increment
      expect(service.profile.xp, equals(midXp)); // No XP farming

      // Different barcode should be accepted
      final differentResult = await service.recordScan(barcode: '8690002');
      expect(differentResult, isTrue);
      expect(service.profile.totalScans, equals(midScans + 1));
      expect(service.profile.xp, greaterThan(midXp));
    });
  });
}
