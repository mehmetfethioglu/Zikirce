import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/features/zikir/providers/zikir_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Zikir Quick Settings Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('SelectedZikirIdNotifier saves and restores last selected zikir id', () async {
      SharedPreferences.setMockInitialValues({'LastSelectedZikirId': 42});

      final notifier = SelectedZikirIdNotifier();
      // Allow async load to complete
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, 42);

      await notifier.select(99);
      expect(notifier.state, 99);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('LastSelectedZikirId'), 99);
    });

    test('ZikirQuickSettingsNotifier loads defaults and persists toggles', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      final notifier = container.read(zikirQuickSettingsProvider.notifier);

      await Future.delayed(const Duration(milliseconds: 50));
      final initialState = container.read(zikirQuickSettingsProvider);
      expect(initialState.isSoundEnabled, true);
      expect(initialState.isVibrationEnabled, true);
      expect(initialState.isInfiniteMode, false);

      // Toggle sound off
      await notifier.toggleSound();
      expect(container.read(zikirQuickSettingsProvider).isSoundEnabled, false);

      // Toggle vibration off
      await notifier.toggleVibration();
      expect(container.read(zikirQuickSettingsProvider).isVibrationEnabled, false);

      // Toggle infinite mode on
      await notifier.toggleInfiniteMode();
      expect(container.read(zikirQuickSettingsProvider).isInfiniteMode, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('zikir_quick_sound_enabled'), false);
      expect(prefs.getBool('zikir_quick_vibration_enabled'), false);
      expect(prefs.getBool('zikir_quick_infinite_mode'), true);

      // Verify a new notifier loads these persisted values
      final restoredNotifier = ZikirQuickSettingsNotifier();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(restoredNotifier.state.isSoundEnabled, false);
      expect(restoredNotifier.state.isVibrationEnabled, false);
      expect(restoredNotifier.state.isInfiniteMode, true);
    });
  });
}
