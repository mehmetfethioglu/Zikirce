import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/features/kuran/providers/kuran_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KuranAudioNotifier & AudioSyncPlayerBar Isolation Tests', () {
    test('Initial audio state has isBarVisible=false', () {
      final state = KuranAudioState();
      expect(state.isBarVisible, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.playbackProgress, 0.0);
    });

    test('syncExternalState always forces isBarVisible=false to prevent Mukabele leak', () {
      final notifier = KuranAudioNotifier();
      
      // Simulate Mukabele playing Surah 9, Ayah 33 with non-zero progress
      final mukabeleState = KuranAudioState(
        isPlaying: true,
        isLoading: false,
        currentSurahId: 9,
        currentAyahId: 33,
        currentWordOrder: 4,
        playbackProgress: 0.45,
        isBarVisible: true, // Even if external caller requested visibility
      );

      notifier.syncExternalState(mukabeleState);

      expect(notifier.state.isPlaying, isTrue);
      expect(notifier.state.currentSurahId, 9);
      expect(notifier.state.currentAyahId, 33);
      expect(notifier.state.currentWordOrder, 4);
      expect(notifier.state.playbackProgress, 0.45);
      // Poka-Yoke: isBarVisible must be strictly false!
      expect(notifier.state.isBarVisible, isFalse,
          reason: 'Mukabele state sync must never activate floating Mushaf player bar');

      notifier.dispose();
    });

    test('stop() resets isBarVisible to false and zeroes playbackProgress', () async {
      final notifier = KuranAudioNotifier();

      // Simulate an active state
      notifier.syncExternalState(KuranAudioState(
        isPlaying: true,
        currentSurahId: 2,
        currentAyahId: 255,
        playbackProgress: 0.8,
      ));

      await notifier.stop();

      expect(notifier.state.isPlaying, isFalse);
      expect(notifier.state.isBarVisible, isFalse);
      expect(notifier.state.playbackProgress, 0.0);
      expect(notifier.state.currentWordOrder, 0);

      notifier.dispose();
    });

    test('reset() restores clean pristine initial state', () {
      final notifier = KuranAudioNotifier();

      notifier.syncExternalState(KuranAudioState(
        isPlaying: true,
        currentSurahId: 36,
        currentAyahId: 12,
        playbackProgress: 0.6,
      ));

      notifier.reset();

      expect(notifier.state.isPlaying, isFalse);
      expect(notifier.state.isBarVisible, isFalse);
      expect(notifier.state.currentSurahId, 1);
      expect(notifier.state.currentAyahId, 1);
      expect(notifier.state.playbackProgress, 0.0);
      expect(notifier.state.currentWordOrder, 0);

      notifier.dispose();
    });
  });
}
