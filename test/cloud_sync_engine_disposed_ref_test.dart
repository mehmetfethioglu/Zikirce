import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/services/cloud_sync_engine.dart';

class _FakeDisposedRef {
  dynamic read(dynamic provider) {
    throw StateError('Cannot use "ref" after the widget was disposed.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory(), 'test_cloud_sync.sqlite');
  });

  tearDown(() async {
    await db.close();
  });

  group('CloudSyncEngine Disposed Ref & Container Tests', () {
    test('triggerDebouncedSync handles null ref gracefully without throwing', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      CloudSyncEngine.instance.setContainer(container);

      expect(
        () => CloudSyncEngine.instance.triggerDebouncedSync(null, delay: const Duration(milliseconds: 50)),
        returnsNormally,
      );

      await Future.delayed(const Duration(milliseconds: 100));
      container.dispose();
    });

    test('triggerDebouncedSync and _safeRead gracefully handle disposed widget ref without throwing StateError', () async {
      final fakeDisposed = _FakeDisposedRef();

      // Ensure that even if passed a disposed widget ref throwing StateError, it is caught safely
      expect(
        () => CloudSyncEngine.instance.triggerDebouncedSync(fakeDisposed, delay: const Duration(milliseconds: 50)),
        returnsNormally,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('CloudSyncEngine.instance.read reads state safely via root container', () {
      final testStateProvider = StateProvider<int>((ref) => 42);
      final container = ProviderContainer();
      CloudSyncEngine.instance.setContainer(container);

      final val = CloudSyncEngine.instance.read(testStateProvider);
      expect(val, equals(42));

      container.dispose();
    });
  });
}
