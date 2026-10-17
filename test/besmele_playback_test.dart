import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/services/ios_now_playing_service.dart';
import 'package:zikirce/features/settings/providers/settings_provider.dart';

/// Helper reflecting the exact business logic used in MukabeleHatimScreen and KelimeTakipliDinlemeScreen
bool shouldPlayBesmeleForVerse({
  required int sureId,
  required int ayetId,
  required bool isSessionStart,
  required bool isBesmeleSettingEnabled,
}) {
  if (!isBesmeleSettingEnabled) return false;

  // Surah 1 (Fatihah) 1st ayah is already Besmele
  if (sureId == 1 && ayetId == 1) return false;

  // Surah 9 (Tawbah) 1st ayah does NOT have Besmele
  if (sureId == 9 && ayetId == 1) return false;

  if (isSessionStart) return true;

  // In-session surah transition (new surah starts at verse 1, except Fatihah & Tawbah)
  if (ayetId == 1 && sureId != 1 && sureId != 9) return true;

  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('SettingsState - Dinlemeye Besmele ile Başla', () {
    test('isPlayBesmeleOnStartEnabled defaults to true and copyWith works', () {
      const state = SettingsState();
      expect(state.isPlayBesmeleOnStartEnabled, isTrue);

      final disabledState = state.copyWith(isPlayBesmeleOnStartEnabled: false);
      expect(disabledState.isPlayBesmeleOnStartEnabled, isFalse);

      final enabledState = disabledState.copyWith(isPlayBesmeleOnStartEnabled: true);
      expect(enabledState.isPlayBesmeleOnStartEnabled, isTrue);
    });

    test('SharedPreferences persistence key IsPlayBesmeleOnStartEnabled', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('IsPlayBesmeleOnStartEnabled', false);
      expect(prefs.getBool('IsPlayBesmeleOnStartEnabled'), isFalse);

      await prefs.setBool('IsPlayBesmeleOnStartEnabled', true);
      expect(prefs.getBool('IsPlayBesmeleOnStartEnabled'), isTrue);
    });
  });

  group('Besmele Playback Decision Logic', () {
    test('Fatihah 1:1 skips redundant Besmele at session start', () {
      final playBesmele = shouldPlayBesmeleForVerse(
        sureId: 1,
        ayetId: 1,
        isSessionStart: true,
        isBesmeleSettingEnabled: true,
      );
      expect(playBesmele, isFalse, reason: 'Fatiha 1. ayet zaten Besmele olduğu için mükerrer olmamalı');
    });

    test('Tawbah 9:1 skips Besmele completely', () {
      final playBesmele = shouldPlayBesmeleForVerse(
        sureId: 9,
        ayetId: 1,
        isSessionStart: true,
        isBesmeleSettingEnabled: true,
      );
      expect(playBesmele, isFalse, reason: 'Tevbe suresinin başlangıcında Besmele okunmaz');
    });

    test('Mid-Tawbah (e.g. 9:40) plays Besmele when starting a new session', () {
      final playBesmele = shouldPlayBesmeleForVerse(
        sureId: 9,
        ayetId: 40,
        isSessionStart: true,
        isBesmeleSettingEnabled: true,
      );
      expect(playBesmele, isTrue, reason: 'Tevbe suresinin ara ayetinde yeni oturum başlatıldığında Besmele çekilir');
    });

    test('Resuming Mukabele on Page 6 (Surah 2 Ayah 25) plays Besmele at session start', () {
      final playBesmele = shouldPlayBesmeleForVerse(
        sureId: 2,
        ayetId: 25,
        isSessionStart: true,
        isBesmeleSettingEnabled: true,
      );
      expect(playBesmele, isTrue, reason: 'Mukabeleye 6. sayfadan devam ederken Besmele ile başlanmalı');
    });

    test('Page transition in the middle of a surah does not repeat Besmele', () {
      final playBesmele = shouldPlayBesmeleForVerse(
        sureId: 2,
        ayetId: 26,
        isSessionStart: false,
        isBesmeleSettingEnabled: true,
      );
      expect(playBesmele, isFalse, reason: 'Aynı sure içinde sayfa/ayet ilerlerken Besmele tekrarlanmamalı');
    });

    test('In-session Surah transition plays Besmele at Ayah 1 of the new surah (except Tawbah & Fatihah)', () {
      // Transition from Surah 113 to Surah 114 (An-Nas)
      final playNasBesmele = shouldPlayBesmeleForVerse(
        sureId: 114,
        ayetId: 1,
        isSessionStart: false,
        isBesmeleSettingEnabled: true,
      );
      expect(playNasBesmele, isTrue, reason: 'Yeni bir sureye geçildiğinde Besmele okunmalı');

      // Transition to Surah 9 (Tawbah) Ayah 1
      final playTawbahBesmele = shouldPlayBesmeleForVerse(
        sureId: 9,
        ayetId: 1,
        isSessionStart: false,
        isBesmeleSettingEnabled: true,
      );
      expect(playTawbahBesmele, isFalse, reason: 'Tevbe suresi başına geçildiğinde Besmele okunmamalı');
    });

    test('When setting is disabled, Besmele is never played', () {
      final playBesmele = shouldPlayBesmeleForVerse(
        sureId: 2,
        ayetId: 1,
        isSessionStart: true,
        isBesmeleSettingEnabled: false,
      );
      expect(playBesmele, isFalse, reason: 'Kullanıcı ayarı kapattığında Besmele çalınmamalı');
    });
  });

  group('IosNowPlayingService - Remote Command & Lifecycle Safety', () {
    test('Safe no-op on non-iOS host and remote command registration', () async {
      String? lastCommand;
      IosNowPlayingService.setRemoteCommandCallback((cmd) {
        lastCommand = cmd;
      });
      expect(lastCommand, isNull);

      // Should safely no-op on Windows/Android test host without throwing MissingPluginException
      await IosNowPlayingService.activateSession();
      await IosNowPlayingService.beginTransitionTask();
      await IosNowPlayingService.updateNowPlaying(
        title: 'Bakara Suresi • 255. Ayet',
        subtitle: 'Maher Al-Muaiqly • Sayfa 42',
        album: 'Zikirce Kur\'an-ı Kerim',
        isPlaying: true,
      );
      await IosNowPlayingService.clearNowPlaying();
      IosNowPlayingService.setRemoteCommandCallback(null);
    });
  });
}
