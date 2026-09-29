import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/session/session_providers.dart';
import 'package:zikirce/core/session/user_session.dart';
import 'package:zikirce/features/namaz_vakitleri/providers/prayer_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('CityNotifier: Default city is İstanbul when no city is saved', () async {
    final city = await CityNotifier.loadSavedCity('default_user');
    expect(city, equals('İstanbul'));
  });

  test('CityNotifier: Saved city persists and survives cold start reload', () async {
    final container = ProviderContainer(
      overrides: [
        initialCityProvider.overrideWithValue('Bursa'),
      ],
    );

    // Initial state must synchronously be 'Bursa', not 'Şanlıurfa'
    final initial = container.read(selectedCityProvider);
    expect(initial, equals('Bursa'));

    // Changing city to Ankara
    await container.read(selectedCityProvider.notifier).setCity('Ankara');
    expect(container.read(selectedCityProvider), equals('Ankara'));

    // Verify written to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('SelectedCity'), equals('Ankara'));
    expect(prefs.getString('AppCity'), equals('Ankara'));

    // Simulate complete app restart / process kill:
    // Read directly from disk with loadSavedCity
    final reloadedCity = await CityNotifier.loadSavedCity('default_user');
    expect(reloadedCity, equals('Ankara'));

    // Recreate a new container with the reloaded city as main.dart does
    final restartedContainer = ProviderContainer(
      overrides: [
        initialCityProvider.overrideWithValue(reloadedCity),
      ],
    );
    expect(restartedContainer.read(selectedCityProvider), equals('Ankara'));
  });

  test('CityNotifier: Multi-session support isolates city per session', () async {
    const session1Id = 'default_user';
    const session2Id = 'session_family_member';

    final session1 = UserSession.defaultSession();
    final session2 = UserSession(
      id: session2Id,
      displayName: 'Kardeş',
      dbFileName: 'kardes.sqlite',
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSessionStateProvider.overrideWithValue(
          SessionState(
            sessions: [session1, session2],
            activeSessionId: session1Id,
            isLoading: false,
          ),
        ),
        initialCityProvider.overrideWithValue('İzmir'),
      ],
    );

    // Set city for session 1
    await container.read(selectedCityProvider.notifier).setCity('İzmir');

    // Switch to session 2 and set different city
    await container.read(sessionProvider.notifier).switchSession(session2Id);
    await container.read(selectedCityProvider.notifier).setCity('Trabzon');

    // Verify session 2 city
    expect(container.read(selectedCityProvider), equals('Trabzon'));

    // Switch back to session 1
    await container.read(sessionProvider.notifier).switchSession(session1Id);
    expect(container.read(selectedCityProvider), equals('İzmir'));
  });
}
