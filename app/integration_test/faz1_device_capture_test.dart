// Faz 1 cihaz kabul testi (Xiaomi 14 / gerçek donanım).
// Çalıştırma: flutter test integration_test/faz1_device_capture_test.dart -d <serial>
// Uygulama içinden çalıştığı için HyperOS'un `input tap` (INJECT_EVENTS) engeline takılmaz.
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
  }) async {
    final sw = Stopwatch()..start();
    final res = await ZameraCapture.capturePhoto(isArtworkMode: artwork);
    sw.stop();
    final dng = res.dngPath != null ? File(res.dngPath!) : null;
    final jpg = res.jpegPath != null ? File(res.jpegPath!) : null;
    return {
      'lens': lens,
      'artwork': artwork,
      'roundTripMs': sw.elapsedMilliseconds,
      'rustIspActive': res.rustIspActive,
      'dngBytes': dng != null && dng.existsSync() ? dng.lengthSync() : 0,
      'jpegBytes': jpg != null && jpg.existsSync() ? jpg.lengthSync() : 0,
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

  testWidgets('Faz 1 kabul: Rust JNI + RAW→TrueColor + MediaStore (lens #2 ve #3)',
      (tester) async {
    final results = <Map<String, Object?>>[];

    final probe = await ZameraCapture.probeDeviceCapabilities();
    expect(probe.rustCoreVersion, contains('JNI/FFI Active'));

    for (final lens in ['2', '3']) {
      final session = await ZameraCapture.startPreviewSession(cameraId: lens);
      expect(session.textureId, greaterThanOrEqualTo(0));
      expect(session.supportsRawSensor, isTrue);
      // AE/AWB yakınsaması
      await Future<void>.delayed(const Duration(seconds: 2));
      results.add(await captureOnce(lens: lens, artwork: true));
      results.add(await captureOnce(lens: lens, artwork: true));
      if (lens == '2') {
        results.add(await captureOnce(lens: lens, artwork: false));
      }
      await ZameraCapture.stopPreviewSession();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    // ignore: avoid_print
    print('ZAMERA_IT_RESULT ${jsonEncode({
          'rust': probe.rustCoreVersion,
          'captures': results
        })}');

    for (final r in results) {
      expect(r['dngBytes'] as int, greaterThan(1000000));
      expect(r['mediaStoreJpeg'], isNotNull);
      if (r['artwork'] == true) expect(r['rustIspActive'], isTrue);
    }
  });
}
