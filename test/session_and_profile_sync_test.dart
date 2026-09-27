import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/services/google_drive_backup_service.dart';
import 'package:zikirce/core/session/session_manager_service.dart';
import 'package:zikirce/core/session/user_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionManagerService & PIN Verification Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial migration creates default session correctly', () async {
      final sessions = await SessionManagerService.loadSessions();
      expect(sessions.isNotEmpty, isTrue);
      final defaultSession = sessions.first;
      expect(defaultSession.id, equals(UserSession.defaultSessionId));
      expect(defaultSession.hasPin, isFalse);
    });

    test('PIN hashing and verification works accurately', () {
      const pin = '1234';
      final hash = SessionManagerService.hashPin(pin);
      final sessionWithPin = UserSession(
        id: 'usr_test_1',
        displayName: 'Test User',
        avatar: 'assets/images/avatar_male_1.png',
        dbFileName: 'zikirce_user_usr_test_1.sqlite',
        hasPin: true,
        pinHash: hash,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      // Correct PIN should succeed
      expect(SessionManagerService.verifyPin(sessionWithPin, '1234'), isTrue);

      // Wrong PIN should fail
      expect(SessionManagerService.verifyPin(sessionWithPin, '0000'), isFalse);
      expect(SessionManagerService.verifyPin(sessionWithPin, '4321'), isFalse);

      // Passing hash instead of raw pin should fail verification
      expect(SessionManagerService.verifyPin(sessionWithPin, hash), isFalse);
    });

    test('Set and remove PIN on user session', () async {
      final session = await SessionManagerService.createLocalSession(
        name: 'Ahmet',
        avatar: 'assets/images/avatar_male_2.png',
      );
      expect(session.hasPin, isFalse);

      final sessionWithPin = await SessionManagerService.setSessionPin(session, '9876');
      expect(sessionWithPin.hasPin, isTrue);
      expect(SessionManagerService.verifyPin(sessionWithPin, '9876'), isTrue);

      final sessionWithoutPin = await SessionManagerService.removeSessionPin(sessionWithPin);
      expect(sessionWithoutPin.hasPin, isFalse);
      expect(sessionWithoutPin.pinHash, isNull);
    });

    test('Create multiple local sessions with unique DB files', () async {
      final s1 = await SessionManagerService.createLocalSession(
        name: 'Profile A',
        avatar: 'assets/images/avatar_male_1.png',
      );
      final s2 = await SessionManagerService.createLocalSession(
        name: 'Profile B',
        avatar: 'assets/images/avatar_female_1.png',
      );

      expect(s1.id, isNot(equals(s2.id)));
      expect(s1.dbFileName, isNot(equals(s2.dbFileName)));

      final all = await SessionManagerService.loadSessions();
      expect(all.any((s) => s.id == s1.id), isTrue);
      expect(all.any((s) => s.id == s2.id), isTrue);
    });

    test('restoreFromJson stably updates UserSession in SessionManagerService', () async {
      // 1. Create a cloud session with placeholder name and avatar
      final cloudSession = await SessionManagerService.createCloudSession(
        id: 'usr_cloud_test_1',
        name: 'Google Kullanıcısı',
        avatar: 'assets/images/avatar_male_1.png',
        email: 'testuser@example.com',
      );

      expect(cloudSession.displayName, equals('Google Kullanıcısı'));
      expect(cloudSession.avatar, equals('assets/images/avatar_male_1.png'));

      // 2. Prepare mock backup JSON containing actual user profile data
      const backupJson = '''
      {
        "UserProfile": {
          "DisplayName": "Hasan Basri",
          "AvatarPath": "assets/images/avatar_female_3.png"
        },
        "AppSettings": {
          "UserDisplayName": "Hasan Basri"
        }
      }
      ''';

      // 3. Perform restore using GoogleDriveBackupService
      final db = AppDatabase(NativeDatabase.memory());
      final service = GoogleDriveBackupService(db: db, sessionId: cloudSession.id);
      await service.restoreFromJson(backupJson);

      // 4. Verify UserSession is updated in SessionManagerService
      final sessions = await SessionManagerService.loadSessions();
      final updated = sessions.firstWhere((s) => s.id == cloudSession.id);

      expect(updated.displayName, equals('Hasan Basri'));
      expect(updated.avatar, equals('assets/images/avatar_female_3.png'));
    });
  });
}

