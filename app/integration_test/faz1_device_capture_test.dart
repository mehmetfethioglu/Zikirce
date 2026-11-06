// Faz 2.0 + Faz 2A/2B cihaz kabul testi (Xiaomi 14 / gerçek donanım).
// Çalıştırma: flutter test integration_test/faz1_device_capture_test.dart -d <serial>
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zamera_capture/zamera_capture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, Object?>> captureOnce({
    required String lens,
    required bool artwork,
    bool fullResolution = true,
    bool normalizeExposure = true,
  }) async {
    final sw = Stopwatch()..start();
    final res = await ZameraCapture.capturePhoto(
      isArtworkMode: artwork,
      fullResolution: fullResolution,
      normalizeExposure: normalizeExposure,
    );
    sw.stop();
    final dng = res.dngPath != null ? File(res.dngPath!) : null;
    final jpg = res.jpegPath != null ? File(res.jpegPath!) : null;
    return {
      'lens': lens,
      'artwork': artwork,
      'roundTripMs': sw.elapsedMilliseconds,
      'rustIspActive': res.rustIspActive,
      'outputWidth': res.outputWidth,
      'outputHeight': res.outputHeight,
      'exposureNormGain': res.exposureNormGain,
      'solvedCctKelvin': res.solvedCctKelvin,
      'zebraRatio': res.zebraRatio,
      'focusPeakingScore': res.focusPeakingScore,
      'histBins': res.rawHistogram32?.length ?? 0,
      'dngBytes': dng != null && dng.existsSync() ? dng.lengthSync() : 0,
      'jpegBytes': jpg != null && jpg.existsSync() ? jpg.lengthSync() : 0,
      'dngPath': res.dngPath,
      'jpegPath': res.jpegPath,
      'mediaStoreJpeg': res.mediaStoreJpegUri,
      'mediaStoreDng': res.mediaStoreDngUri,
      'whiteLevel': res.whiteLevel,
      'blackLevel': res.blackLevel,
      'lensShadingApplied': res.lensShadingApplied,
      'wbGainsUsed': res.wbGainsUsed,
      'centerLinearCamRgb': res.centerLinearCamRgb,
      'highlightClippedRatio': res.highlightClippedRatio,
      'gamutClippedRatio': res.gamutClippedRatio,
      'iso': res.iso,
      'exposureTimeNs': res.exposureTimeNs,
    };
  }

  testWidgets(
      'Faz 2.0 + Faz 2A/2B kabul: 12.6MP Tam Çözünürlük, DNG CCT WB, Pozlama Normalizasyonu ve Pro Kontroller (lens #2 ve #3)',
      (tester) async {
    final results = <Map<String, Object?>>[];
    await Future<void>.delayed(const Duration(seconds: 2));

    final probe = await ZameraCapture.probeDeviceCapabilities();
    expect(probe.rustCoreVersion, contains('0.4.0'));
    expect(probe.rustCoreVersion, contains('JNI/FFI Active'));

    // Lens #2 (23mm f/1.6 14-bit) variable focus & Lens #3 (14mm f/2.2) fixed focus kontrolü
    final cam2 = probe.cameras.firstWhere((c) => c.cameraId == '2');
    final cam3 = probe.cameras.firstWhere((c) => c.cameraId == '3');
    // ignore: avoid_print
    print('ZAMERA_CAM2_PROBE minFocus=${cam2.minimumFocusDistanceDiopters} isoRange=${cam2.isoRange} err=${cam2.error}');
    expect(cam2.supportsVariableFocus, isTrue);
    expect(cam3.supportsVariableFocus, isFalse);

    // 1. Lens #2: Sanat Modu 12.6MP Tam Çözünürlük + Pro Mod + Dokunmatik AF/AE + Manuel Kelvin WB
    final session2 = await ZameraCapture.startPreviewSession(cameraId: '2');
    expect(session2.textureId, greaterThanOrEqualTo(0));
    expect(session2.supportsRawSensor, isTrue);
    await Future<void>.delayed(const Duration(seconds: 2));

    // Sanat Modu 12.6MP (3072x4096) çekim
    final art2 = await captureOnce(
      lens: '2',
      artwork: true,
      fullResolution: true,
      normalizeExposure: true,
    );
    results.add(art2);
    expect(art2['rustIspActive'], isTrue);
    expect(art2['outputWidth'], equals(3072));
    expect(art2['outputHeight'], equals(4096));
    expect(art2['histBins'], equals(32));
    expect((art2['solvedCctKelvin'] as double), inInclusiveRange(2000.0, 10000.0));

    // Dokunmatik AF/AE + Manuel Kelvin WB + EV Telafisi testi
    final focusOk = await ZameraCapture.setFocusAndMeteringPoint(x: 0.5, y: 0.5);
    expect(focusOk, isTrue);

    await ZameraCapture.updateManualControls(
      manualExposure: false,
      iso: 100,
      exposureTimeNs: 8000000,
      evCompensation: -0.5,
      manualFocus: false,
      focusDistance: 0.0,
      manualWb: true,
      kelvin: 4200.0,
      tint: 5.0,
      rggbGains: ZameraCapture.kelvinAndTintToRggbGains(4200.0, 5.0),
      artworkLinearMode: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Pro Mod çekim (B7 doğrulaması: gereksiz TrueColor Bitmap kodlaması yapılmaz, hızlı telemetri döner)
    final pro2 = await captureOnce(lens: '2', artwork: false);
    results.add(pro2);
    expect(pro2['rustIspActive'], isFalse);
    expect(pro2['histBins'], equals(32));

    // Canlı telemetri sorgusu
    final liveTel = await ZameraCapture.getLiveTelemetry();
    expect(liveTel['iso'], isNotNull);

    await ZameraCapture.stopPreviewSession();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // 2. Lens #3 (14mm Ultra-Wide): Sanat Modu 12.2MP Tam Çözünürlük çekim
    final session3 = await ZameraCapture.startPreviewSession(cameraId: '3');
    expect(session3.textureId, greaterThanOrEqualTo(0));
    await Future<void>.delayed(const Duration(seconds: 2));
    final art3 = await captureOnce(
      lens: '3',
      artwork: true,
      fullResolution: true,
      normalizeExposure: true,
    );
    results.add(art3);
    expect(art3['rustIspActive'], isTrue);
    expect(art3['outputWidth'], equals(3072));
    expect(art3['outputHeight'], equals(4080));

    await ZameraCapture.stopPreviewSession();

    // ignore: avoid_print
    print('ZAMERA_FAZ2_IT_RESULT ${jsonEncode({
          'rust': probe.rustCoreVersion,
          'captures': results,
        })}');

    for (final r in results) {
      expect(r['dngBytes'] as int, greaterThan(1000000));
      expect(r['mediaStoreJpeg'], isNotNull);
    }
  });
}
