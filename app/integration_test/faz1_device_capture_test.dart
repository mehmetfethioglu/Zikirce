// Faz 2.0 + Faz 2A/2B kapsamlı cihaz kabul testi (Xiaomi 14 / gerçek donanım).
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
    bool applyPerspectiveWarp = false,
    List<double>? perspectiveCornersNorm,
    List<double>? flatFieldGrid8x6,
  }) async {
    final sw = Stopwatch()..start();
    final res = await ZameraCapture.capturePhoto(
      isArtworkMode: artwork,
      fullResolution: fullResolution,
      normalizeExposure: normalizeExposure,
      applyPerspectiveWarp: applyPerspectiveWarp,
      perspectiveCornersNorm: perspectiveCornersNorm,
      flatFieldGrid8x6: flatFieldGrid8x6,
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
      'flatFieldLen': res.measuredFlatField8x6?.length ?? 0,
      'measuredFlatField8x6': res.measuredFlatField8x6,
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
      'Faz 2.0 + Faz 2A/2B tam kabul: 12.6MP TrueColor, 8x6 Flat-Field, Perspektif Warp, 3x AEB ve Canlı Telemetri',
      (tester) async {
    final results = <Map<String, Object?>>[];
    await Future<void>.delayed(const Duration(seconds: 2));

    final probe = await ZameraCapture.probeDeviceCapabilities();
    expect(probe.rustCoreVersion, contains('0.4.0'));
    expect(probe.rustCoreVersion, contains('JNI/FFI Active'));

    final cam2 = probe.cameras.firstWhere((c) => c.cameraId == '2');
    final cam3 = probe.cameras.firstWhere((c) => c.cameraId == '3');
    expect(cam2.supportsVariableFocus, isTrue);
    expect(cam3.supportsVariableFocus, isFalse);

    // 1. Lens #2: Sanat Modu 12.6MP Tam Çözünürlük + 8x6 Flat-Field Kalibrasyonu
    final session2 = await ZameraCapture.startPreviewSession(cameraId: '2');
    expect(session2.textureId, greaterThanOrEqualTo(0));
    expect(session2.supportsRawSensor, isTrue);
    await Future<void>.delayed(const Duration(seconds: 2));

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
    expect(art2['flatFieldLen'], equals(48));
    expect((art2['solvedCctKelvin'] as double), inInclusiveRange(2000.0, 10000.0));

    // Ölçülen 8x6 Flat-Field + 4-Köşe Perspektif Warp ile ikinci Sanat çekimi
    final ffGrid = (art2['measuredFlatField8x6'] as List<double>?)!;
    final art2Warped = await captureOnce(
      lens: '2',
      artwork: true,
      fullResolution: true,
      normalizeExposure: true,
      applyPerspectiveWarp: true,
      perspectiveCornersNorm: const [0.08, 0.08, 0.92, 0.08, 0.92, 0.92, 0.08, 0.92],
      flatFieldGrid8x6: ffGrid,
    );
    results.add(art2Warped);
    expect(art2Warped['rustIspActive'], isTrue);
    expect(art2Warped['outputWidth'], equals(3072));
    expect(art2Warped['outputHeight'], equals(4096));

    // Dokunmatik AF/AE (90 derece sensör rotasyonlu) + Gerçek YUV Canlı Telemetri (32-bin Histogram, Zebra, Focus Peaking) + 3x AEB Braketleme testi
    final focusOk = await ZameraCapture.setFocusAndMeteringPoint(x: 0.35, y: 0.65);
    expect(focusOk, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 500));
    final liveTel = await ZameraCapture.getLiveTelemetry();
    expect(liveTel['iso'], isNotNull);
    expect(liveTel['solvedCctKelvin'], isNotNull);
    final liveHist = liveTel['liveHistogram32'] as List<dynamic>?;
    final liveZebraGrid = liveTel['liveZebraGrid16x12'] as List<dynamic>?;
    final livePeakingGrid = liveTel['livePeakingGrid16x12'] as List<dynamic>?;
    expect(liveHist, isNotNull);
    expect(liveHist!.length, equals(32));
    expect(liveZebraGrid?.length, equals(192));
    expect(livePeakingGrid?.length, equals(192));

    // Portre Modu (Arka Kamera #2): Doğal Işık (lighting: 0) ve Panjur Gölgesi (lighting: 6) + Panjur Mono Refocus (lighting: 7) + Özne Kopyalama testi
    final swPortrait = Stopwatch()..start();
    final portraitRes = await ZameraCapture.capturePhoto(
      isArtworkMode: false,
      isPortraitMode: true,
      captureRaw: false,
      portraitAperture: 2.0,
      portraitLighting: 0, // DOĞAL IŞIK
      portraitLightIntensity: 0.80,
      portraitSubjectRadius: 0.36,
      focusPointX: 0.50,
      focusPointY: 0.45,
    );
    swPortrait.stop();
    expect(portraitRes.jpegPath, isNotNull);
    expect(File(portraitRes.jpegPath!).existsSync(), isTrue);
    expect(File(portraitRes.jpegPath!).lengthSync(), greaterThan(50000));

    final swRefocus = Stopwatch()..start();
    final refocused = await ZameraCapture.reprocessPortraitPhoto(
      sourceJpegPath: portraitRes.oemJpegPath ?? portraitRes.jpegPath!,
      aperture: 2.0,
      lightingMode: 6, // PANJUR GÖLGESİ
      lightIntensity: 0.82,
      subjectRadiusRatio: 0.36,
      focusX: 0.50,
      focusY: 0.45,
      isFrontCamera: false,
      saveToGallery: true,
    );
    swRefocus.stop();
    final refocusPath = refocused['jpegPath']?.toString();
    expect(refocusPath, isNotNull);
    expect(File(refocusPath!).existsSync(), isTrue);

    final swCutout = Stopwatch()..start();
    final cutout = await ZameraCapture.extractSubjectCutoutPng(
      sourceJpegPath: portraitRes.oemJpegPath ?? portraitRes.jpegPath!,
      focusX: 0.50,
      focusY: 0.45,
      subjectRadiusRatio: 0.36,
      isFrontCamera: false,
      shareNow: false,
    );
    swCutout.stop();
    final pngPath = cutout['pngPath']?.toString();
    expect(pngPath, isNotNull);
    expect(File(pngPath!).existsSync(), isTrue);

    final brackets = await ZameraCapture.captureBracketedPhotos(
      evOffsets: const [-1.5, 0.0, 1.5],
    );
    expect(brackets.length, equals(3));
    expect(brackets[0].exposureTimeNs!, lessThan(brackets[2].exposureTimeNs!));

    // Ön Kamera (#1 Selfie) Portre Modu Testi
    final sessionFront = await ZameraCapture.startPreviewSession(cameraId: '1');
    expect(sessionFront.textureId, greaterThanOrEqualTo(0));
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final frontPortraitRes = await ZameraCapture.capturePhoto(
      isArtworkMode: false,
      isPortraitMode: true,
      captureRaw: false,
      portraitAperture: 2.0,
      portraitLighting: 0,
      portraitLightIntensity: 0.80,
      portraitSubjectRadius: 0.36,
      focusPointX: 0.50,
      focusPointY: 0.45,
    );
    expect(frontPortraitRes.jpegPath, isNotNull);
    expect(File(frontPortraitRes.jpegPath!).existsSync(), isTrue);

    await ZameraCapture.stopPreviewSession();

    // ignore: avoid_print
    print('ZAMERA_FAZ2_FULL_IT ${jsonEncode({
          'rust': probe.rustCoreVersion,
          'liveTelemetryHistLen': liveHist.length,
          'liveZebraRatio': liveTel['liveZebraRatio'],
          'liveFocusPeakingScore': liveTel['liveFocusPeakingScore'],
          'sanatRoundTripMs': art2['roundTripMs'],
          'sanatWarpedRoundTripMs': art2Warped['roundTripMs'],
          'portraitBlindsRoundTripMs': swPortrait.elapsedMilliseconds,
          'portraitMonoRefocusMs': swRefocus.elapsedMilliseconds,
          'subjectCutoutMs': swCutout.elapsedMilliseconds,
          'bracketExpNs': brackets.map((b) => b.exposureTimeNs).toList(),
          'capturesCount': results.length + 1,
        })}');
  });
}
