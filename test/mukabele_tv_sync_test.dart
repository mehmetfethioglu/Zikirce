import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/utils/quran_word_highlighter.dart';
import 'package:zikirce/features/hatim/domain/mukabele_tv_sync_helper.dart';
import 'package:zikirce/features/tv/providers/tv_cast_provider.dart';

void main() {
  group('MukabeleTvSyncHelper birim testleri', () {
    test('Telefon modunda (!isTvMode) ofset daima 0 ms döner', () {
      const wirelessCast = TvCastState(
        isSupported: true,
        isConnected: true,
        connectionType: TvCastConnectionType.wireless,
      );
      expect(
        MukabeleTvSyncHelper.resolveEffectiveOffsetMs(
          isTvMode: false,
          isHardwareTv: false,
          castState: wirelessCast,
          savedTvOffsetMs: -240,
        ),
        equals(0),
      );
    });

    test('TV modunda bağlantıya göre akıllı varsayılan ve kayıtlı ofset döner',
        () {
      const noCast = TvCastState();
      const wiredCast = TvCastState(
        isSupported: true,
        isConnected: true,
        connectionType: TvCastConnectionType.wired,
      );
      const wirelessCast = TvCastState(
        isSupported: true,
        isConnected: true,
        connectionType: TvCastConnectionType.wireless,
      );

      expect(
        MukabeleTvSyncHelper.resolveEffectiveOffsetMs(
          isTvMode: true,
          isHardwareTv: false,
          castState: noCast,
        ),
        equals(MukabeleTvSyncHelper.defaultLocalTvModeOffsetMs),
      );
      expect(
        MukabeleTvSyncHelper.resolveEffectiveOffsetMs(
          isTvMode: true,
          isHardwareTv: true,
          castState: noCast,
        ),
        equals(MukabeleTvSyncHelper.defaultTvOrWiredOffsetMs),
      );
      expect(
        MukabeleTvSyncHelper.resolveEffectiveOffsetMs(
          isTvMode: true,
          isHardwareTv: false,
          castState: wiredCast,
        ),
        equals(MukabeleTvSyncHelper.defaultTvOrWiredOffsetMs),
      );
      expect(
        MukabeleTvSyncHelper.resolveEffectiveOffsetMs(
          isTvMode: true,
          isHardwareTv: false,
          castState: wirelessCast,
        ),
        equals(MukabeleTvSyncHelper.defaultWirelessCastOffsetMs),
      );

      // Kullanıcı kaydı clamp sınırları içinde önceliklidir
      expect(
        MukabeleTvSyncHelper.resolveEffectiveOffsetMs(
          isTvMode: true,
          isHardwareTv: true,
          castState: wirelessCast,
          savedTvOffsetMs: -320,
        ),
        equals(-320),
      );
      expect(
        MukabeleTvSyncHelper.resolveEffectiveOffsetMs(
          isTvMode: true,
          isHardwareTv: true,
          castState: noCast,
          savedTvOffsetMs: -999,
        ),
        equals(MukabeleTvSyncHelper.minOffsetMs),
      );
    });

    test('TV modunda ileri ekstrapolasyon yapmaz ve negatif ofseti uygular', () {
      expect(
        MukabeleTvSyncHelper.computeSyncedPositionMs(
          playerMs: 0.0,
          microInterpMs: 35.0,
          playbackSpeed: 1.0,
          isPlayingReady: true,
          isTvMode: true,
          offsetMs: -180,
        ),
        equals(0.0),
      );

      // TV modunda 1000ms + (-180ms) = tam 820ms (0ms ekstrapolasyon)
      expect(
        MukabeleTvSyncHelper.computeSyncedPositionMs(
          playerMs: 1000.0,
          microInterpMs: 35.0,
          playbackSpeed: 1.25,
          isPlayingReady: true,
          isTvMode: true,
          offsetMs: -180,
        ),
        equals(820.0),
      );

      // Negatif taşmada 0.0'a sabitlenir
      expect(
        MukabeleTvSyncHelper.computeSyncedPositionMs(
          playerMs: 100.0,
          microInterpMs: 25.0,
          playbackSpeed: 1.0,
          isPlayingReady: true,
          isTvMode: true,
          offsetMs: -280,
        ),
        equals(0.0),
      );

      // Telefon modunda mikro enterpolasyon en fazla 16ms ile sınırlıdır
      expect(
        MukabeleTvSyncHelper.computeSyncedPositionMs(
          playerMs: 1000.0,
          microInterpMs: 40.0,
          playbackSpeed: 1.0,
          isPlayingReady: true,
          isTvMode: false,
          offsetMs: 0,
        ),
        equals(1016.0),
      );
    });
  });

  group('QuranWordTrackingPointer senkron başlangıç testi', () {
    testWidgets('isPlaying false iken ok kaymaz, true olunca akıcı ilerler',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 80,
                child: QuranWordTrackingPointer(
                  isDark: false,
                  height: 12.5,
                  durationMs: 500,
                  playbackSpeed: 1.0,
                  isPlaying: false,
                  wordIdentity: '1_1_1',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      var painter = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(QuranWordTrackingPointer),
          matching: find.byType(CustomPaint),
        ),
      ).painter! as QuranTrackingArrowPainter;
      expect(painter.progress, equals(0.0));

      // Gerçek ses başlayınca isPlaying: true olur ve ok ilerler
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 80,
                child: QuranWordTrackingPointer(
                  isDark: false,
                  height: 12.5,
                  durationMs: 500,
                  playbackSpeed: 1.0,
                  isPlaying: true,
                  wordIdentity: '1_1_1',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 250));
      painter = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(QuranWordTrackingPointer),
          matching: find.byType(CustomPaint),
        ),
      ).painter! as QuranTrackingArrowPainter;
      expect(painter.progress, greaterThan(0.35));
    });
  });
}
