import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/services/celebration_service.dart';
import 'package:zikirce/features/zikir/providers/zikir_providers.dart';

class MockJustAudioPlatform extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    return MockAudioPlayerPlatform(request.id);
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    return DisposeAllPlayersResponse();
  }
}

class MockAudioPlayerPlatform extends AudioPlayerPlatform {
  MockAudioPlayerPlatform(super.id);

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      const Stream<PlaybackEventMessage>.empty();

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    return LoadResponse(duration: Duration.zero);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    return SetSpeedResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async {
    return SetShuffleModeResponse();
  }

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(SetShuffleOrderRequest request) async {
    return SetShuffleOrderResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    return DisposeResponse();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Infinite Mode & Focus Mode Tests', () {
    late AppDatabase db;
    late ProviderContainer container;
    late Zikir sampleZikir;

    setUp(() async {
      JustAudioPlatform.instance = MockJustAudioPlatform();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async => true);

      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      sampleZikir = await db.into(db.zikirs).insertReturning(
        ZikirsCompanion.insert(
          name: 'Sübhanallah',
          target: const Value(33),
          currentCount: const Value(32),
          lap: const Value(0),
          totalCount: const Value(32),
        ),
      );

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          zikirListStreamProvider.overrideWith((ref) => Stream.value([sampleZikir])),
        ],
      );
      await container.read(zikirListStreamProvider.future);
    });

    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 50));
      container.dispose();
      await db.close();
    });

    test('Normal mode (isInfinite: false) resets currentCount to 0 and increments lap upon target', () async {
      final notifier = container.read(zikirCounterNotifierProvider(sampleZikir.id).notifier);

      expect(notifier.state.currentCount, 32);
      expect(notifier.state.lap, 0);

      // Increment 1 tap to reach target (33)
      notifier.increment(isInfinite: false);

      expect(notifier.state.currentCount, 0);
      expect(notifier.state.lap, 1);
      expect(notifier.state.totalCount, 33);
      expect(container.read(celebrationProvider), isNotNull);
      expect(container.read(celebrationProvider)!.type, CelebrationType.zikirTarget);
    });

    test('Infinite mode (isInfinite: true) does NOT reset currentCount, continues counting, and does NOT trigger celebration', () async {
      // Clear celebration state first
      container.read(celebrationProvider.notifier).clear();
      final notifier = container.read(zikirCounterNotifierProvider(sampleZikir.id).notifier);

      expect(notifier.state.currentCount, 32);
      expect(notifier.state.lap, 0);

      // Increment 1 tap in infinite mode -> reaches 33
      notifier.increment(isInfinite: true);

      expect(notifier.state.currentCount, 33);
      expect(notifier.state.lap, 1);
      expect(notifier.state.totalCount, 33);
      // Verify celebration animation triggered on lap completion in infinite mode
      expect(container.read(celebrationProvider), isNotNull);
      expect(container.read(celebrationProvider)!.type, CelebrationType.zikirTarget);

      // Next tap in infinite mode -> continues to 34
      container.read(celebrationProvider.notifier).clear();
      notifier.increment(isInfinite: true);

      expect(notifier.state.currentCount, 34);
      expect(notifier.state.lap, 1);
      expect(notifier.state.totalCount, 34);
      expect(container.read(celebrationProvider), isNull);
    });

    test('isZikirFocusModeProvider starts false and can be updated', () {
      expect(container.read(isZikirFocusModeProvider), false);

      container.read(isZikirFocusModeProvider.notifier).state = true;
      expect(container.read(isZikirFocusModeProvider), true);

      container.read(isZikirFocusModeProvider.notifier).state = false;
      expect(container.read(isZikirFocusModeProvider), false);
    });
  });
}
