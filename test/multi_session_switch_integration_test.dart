import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/session/session_manager_service.dart';
import 'package:zikirce/core/session/session_providers.dart';
import 'package:zikirce/core/session/user_session.dart';
import 'package:zikirce/features/zikir/providers/zikir_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Session Full Provider Switch Test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Switching session completely switches all provider data from main to secondary profile', () async {
      // 1. Create two in-memory DBs
      final db1 = AppDatabase(NativeDatabase.memory());
      final db2 = AppDatabase(NativeDatabase.memory());

      // Add a custom test zikir into DB1
      await db1.into(db1.zikirs).insert(
        ZikirsCompanion.insert(
          name: 'Main Session Unique Zikir',
          target: const drift.Value(100),
          currentCount: const drift.Value(45),
          totalCount: const drift.Value(500),
        ),
      );

      // Add a custom test zikir into DB2
      await db2.into(db2.zikirs).insert(
        ZikirsCompanion.insert(
          name: 'Second Session Unique Zikir',
          target: const drift.Value(33),
          currentCount: const drift.Value(10),
          totalCount: const drift.Value(20),
        ),
      );

      final initialSession = UserSession.defaultSession();
      final container = ProviderContainer(
        overrides: [
          initialSessionStateProvider.overrideWithValue(
            SessionState(
              sessions: [initialSession],
              activeSessionId: initialSession.id,
              isLoading: false,
            ),
          ),
          databaseProvider.overrideWith((ref) {
            final active = ref.watch(activeSessionProvider);
            if (active.id == 'usr_2') {
              return db2;
            }
            return db1;
          }),
        ],
      );
      addTearDown(container.dispose);

      // 1. Initial State should be Main Profile
      expect(container.read(activeSessionProvider).displayName, contains('Ana Profil'));
      final zikirs1 = await container.read(zikirListStreamProvider.future);
      expect(zikirs1.any((z) => z.name == 'Main Session Unique Zikir'), isTrue);
      expect(zikirs1.any((z) => z.name == 'Second Session Unique Zikir'), isFalse);

      // 2. Create and Switch to Second Session
      final s2 = await container.read(sessionProvider.notifier).createLocalSession(
        id: 'usr_2',
        name: 'Ahmet',
        avatar: 'assets/images/avatar_male_2.png',
      );

      expect(s2.id, equals('usr_2'));
      expect(container.read(activeSessionProvider).displayName, equals('Ahmet'));

      // 3. Verify Zikir List switches to Second Session
      final zikirs2 = await container.read(zikirListStreamProvider.future);
      expect(zikirs2.any((z) => z.name == 'Second Session Unique Zikir'), isTrue);
      expect(zikirs2.any((z) => z.name == 'Main Session Unique Zikir'), isFalse);
    });
  });
}
