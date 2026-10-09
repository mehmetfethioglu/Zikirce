import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/features/settings/providers/settings_provider.dart';
import 'package:zikirce/features/zikir/presentation/screens/zikir_counter_screen.dart';
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

  group('Arabic Font Weight Setting & Zikir Counter Tests', () {
    late AppDatabase db;
    late Zikir sampleZikir;

    setUp(() async {
      JustAudioPlatform.instance = MockJustAudioPlatform();
      SharedPreferences.setMockInitialValues({'IsBoldArabic': false});
      db = AppDatabase(NativeDatabase.memory());
      sampleZikir = await db.into(db.zikirs).insertReturning(
        ZikirsCompanion.insert(
          name: 'Sübhanallah',
          arabic: const Value('سُبْحَانَ اللَّهِ'),
          target: const Value(33),
          currentCount: const Value(0),
          lap: const Value(0),
          totalCount: const Value(0),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('isBoldArabicProvider tracks settings state correctly', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );

      expect(container.read(isBoldArabicProvider), isFalse);

      await container.read(userSettingsProvider.notifier).toggleBoldArabic(true);
      expect(container.read(isBoldArabicProvider), isTrue);

      await container.read(userSettingsProvider.notifier).toggleBoldArabic(false);
      expect(container.read(isBoldArabicProvider), isFalse);

      await Future.delayed(const Duration(milliseconds: 50));
      container.dispose();
    });

    testWidgets('ZikirCounterScreen renders Arabic text with FontWeight.normal when isBoldArabic is false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            theme: ThemeData(
              extensions: const [AppThemeColors.greenLight],
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ZikirCounterScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final arabicFinder = find.text('سُبْحَانَ اللَّهِ');
      expect(arabicFinder, findsOneWidget);

      final Text arabicWidget = tester.widget(arabicFinder);
      expect(arabicWidget.style?.fontWeight, equals(FontWeight.normal));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('ZikirCounterScreen renders Arabic text with FontWeight.bold when isBoldArabic is true', (tester) async {
      SharedPreferences.setMockInitialValues({'IsBoldArabic': true});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            theme: ThemeData(
              extensions: const [AppThemeColors.greenLight],
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ZikirCounterScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final element = tester.element(find.byType(ZikirCounterScreen));
      final container = ProviderScope.containerOf(element);
      await container.read(userSettingsProvider.notifier).toggleBoldArabic(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final arabicFinder = find.text('سُبْحَانَ اللَّهِ');
      expect(arabicFinder, findsOneWidget);

      final Text arabicWidget = tester.widget(arabicFinder);
      expect(arabicWidget.style?.fontWeight, equals(FontWeight.bold));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1000));
    });
  });
}
