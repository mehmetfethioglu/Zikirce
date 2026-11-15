import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamera_capture/zamera_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sharma 2005 CIEDE2000 reference pairs pass', () {
    final d = ZameraCapture.computeCiede2000(
      const [50.0000, 2.6772, -79.7751],
      const [50.0000, 0.0000, -82.7485],
    );
    expect((d - 2.0425).abs(), lessThan(1e-3));
  });

  test('srgb8ToLabD50 and nearestColorCheckerPatch preserve D50 white & patches', () {
    final whiteLab = ZameraCapture.srgb8ToLabD50(255, 255, 255);
    expect(whiteLab[0], closeTo(100.0, 1e-2));
    expect(whiteLab[1].abs(), lessThan(1e-2));
    expect(whiteLab[2].abs(), lessThan(1e-2));

    final blackLab = ZameraCapture.srgb8ToLabD50(0, 0, 0);
    expect(blackLab[0], closeTo(0.0, 1e-4));
    expect(blackLab[1], closeTo(0.0, 1e-4));
    expect(blackLab[2], closeTo(0.0, 1e-4));

    for (final p in kColorChecker24Patches) {
      final matched = ZameraCapture.nearestColorCheckerPatch(p.labD50);
      expect(matched.index, equals(p.index));
    }
  });

  test('calibrateColorChecker24 enforces exact D50 white point & serialization', () {
    final measured = ZameraCapture.simulateUncalibratedSensor24();
    final cal = ZameraCapture.calibrateColorChecker24(
      measured,
      isMeasuredFromSensor: true,
    );
    expect(cal.isMeasuredFromSensor, isTrue);
    expect(cal.meanDeltaEBefore, greaterThan(6.0));
    expect(cal.meanDeltaEAfter, lessThan(0.5));

    final row0Sum =
        cal.camToXyzD50[0][0] + cal.camToXyzD50[0][1] + cal.camToXyzD50[0][2];
    final row1Sum =
        cal.camToXyzD50[1][0] + cal.camToXyzD50[1][1] + cal.camToXyzD50[1][2];
    final row2Sum =
        cal.camToXyzD50[2][0] + cal.camToXyzD50[2][1] + cal.camToXyzD50[2][2];
    expect(row0Sum, closeTo(0.96422, 1e-6));
    expect(row1Sum, closeTo(1.00000, 1e-6));
    expect(row2Sum, closeTo(0.82521, 1e-6));

    final roundTrip = ColorCheckerCalibrationResult.fromMap(cal.toMap());
    expect(roundTrip.isMeasuredFromSensor, isTrue);
    expect(roundTrip.wbGains[0], closeTo(cal.wbGains[0], 1e-9));
    expect(roundTrip.flattenedCamToXyzD50, equals(cal.flattenedCamToXyzD50));

    final fromFlat = ColorCheckerCalibrationResult.fromMap({
      'wbGains': cal.wbGains,
      'camToXyzD50': cal.flattenedCamToXyzD50,
      'meanDeltaEBefore': cal.meanDeltaEBefore,
      'meanDeltaEAfter': cal.meanDeltaEAfter,
      'maxDeltaEAfter': cal.maxDeltaEAfter,
      'patchDeltaEBefore': cal.patchDeltaEBefore,
      'patchDeltaEAfter': cal.patchDeltaEAfter,
      'isMeasuredFromSensor': true,
    });
    expect(fromFlat.flattenedCamToXyzD50, equals(cal.flattenedCamToXyzD50));
  });

  test('MethodChannel contracts forward artwork 1:1 true-color parameters', () async {
    const channel = MethodChannel('com.akarworks.zamera/capture_probe');
    Map<dynamic, dynamic>? lastArgs;
    String? lastMethod;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      lastMethod = call.method;
      lastArgs = call.arguments as Map<dynamic, dynamic>?;
      if (call.method == 'updateManualControls' ||
          call.method == 'setFocusAndMeteringPoint') {
        return true;
      }
      if (call.method == 'capturePhoto') {
        return {
          'cameraId': '2',
          'jpegPath': '/tmp/truecolor.png',
          'rustIspActive': true,
          'centerLabD50': [50.8, -0.1, -0.2],
          'colorSpaceTag': 'Display P3',
          'liveCalibrationResult': {
            'wbGains': [1.8, 1.0, 1.5],
            'camToXyzD50': [
              0.4360747, 0.3850649, 0.1430804,
              0.2225045, 0.7168786, 0.0606169,
              0.0139322, 0.0971045, 0.7141733,
            ],
            'meanDeltaEBefore': 9.4,
            'meanDeltaEAfter': 1.2,
            'maxDeltaEAfter': 2.5,
            'isMeasuredFromSensor': true,
          },
        };
      }
      return null;
    });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final ok = await ZameraCapture.updateManualControls(
      manualExposure: false,
      iso: 100,
      exposureTimeNs: 8000000,
      manualFocus: false,
      focusDistance: 0.5,
      manualWb: false,
      rggbGains: const [1.5, 1.0, 1.0, 1.4],
      artworkLinearMode: true,
      customWbGains: const [1.8, 1.0, 1.5],
      camToXyzD50: const [
        0.436, 0.385, 0.143,
        0.222, 0.717, 0.061,
        0.014, 0.097, 0.714,
      ],
    );
    expect(ok, isTrue);
    expect(lastMethod, 'updateManualControls');
    expect(lastArgs?['manualIso'], isFalse);
    expect(lastArgs?['manualShutter'], isFalse);
    expect(lastArgs?['aeAfLocked'], isFalse);
    expect(lastArgs?['customWbGains'], equals(const [1.8, 1.0, 1.5]));
    expect((lastArgs?['camToXyzD50'] as List).length, 9);

    final okSplit = await ZameraCapture.updateManualControls(
      manualExposure: false,
      manualIso: true,
      manualShutter: false,
      aeAfLocked: true,
      iso: 400,
      exposureTimeNs: 10000000,
      manualFocus: false,
      focusDistance: 0.0,
      manualWb: false,
      rggbGains: const [1.5, 1.0, 1.0, 1.4],
    );
    expect(okSplit, isTrue);
    expect(lastArgs?['manualExposure'], isFalse);
    expect(lastArgs?['manualIso'], isTrue);
    expect(lastArgs?['manualShutter'], isFalse);
    expect(lastArgs?['aeAfLocked'], isTrue);

    final focusDefault = await ZameraCapture.setFocusAndMeteringPoint(
      x: 0.25,
      y: 0.75,
    );
    expect(focusDefault, isTrue);
    expect(lastMethod, 'setFocusAndMeteringPoint');
    expect(lastArgs, equals({'x': 0.25, 'y': 0.75, 'lockAeAf': false}));

    final focusLocked = await ZameraCapture.setFocusAndMeteringPoint(
      x: 0.5,
      y: 0.5,
      lockAeAf: true,
    );
    expect(focusLocked, isTrue);
    expect(lastArgs, equals({'x': 0.5, 'y': 0.5, 'lockAeAf': true}));

    final res = await ZameraCapture.capturePhoto(
      artworkExposureMode: 2,
      calibrateColorChecker: true,
      losslessPng: true,
      useDisplayP3: true,
    );
    expect(lastMethod, 'capturePhoto');
    expect(lastArgs?['artworkExposureMode'], 2);
    expect(lastArgs?['calibrateColorChecker'], isTrue);
    expect(lastArgs?['losslessPng'], isTrue);
    expect(res.colorSpaceTag, 'Display P3');
    expect(res.centerLabD50, equals(const [50.8, -0.1, -0.2]));
    expect(res.liveCalibrationResult?.isMeasuredFromSensor, isTrue);
    expect(res.liveCalibrationResult?.meanDeltaEAfter, closeTo(1.2, 1e-6));
  });

  test('Sticker cutout, video frame, share, clipboard, and delete MethodChannel contracts', () async {
    const channel = MethodChannel('com.akarworks.zamera/capture_probe');
    final recordedCalls = <String, Map<dynamic, dynamic>?>{};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      recordedCalls[call.method] = call.arguments as Map<dynamic, dynamic>?;
      switch (call.method) {
        case 'extractSubjectCutoutPng':
          return {
            'pngPath': '/data/user/0/app/files/zamera_stickers/st_1.png',
            'cutoutPngPath': '/data/user/0/app/files/zamera_stickers/st_1.png',
            'width': 420,
            'height': 610,
            'copiedToClipboard': true,
            'savedToGallery': false,
          };
        case 'extractVideoFrameJpeg':
          return {
            'jpegPath': '/data/user/0/app/files/zamera_frames/fr_1.jpg',
            'width': 3840,
            'height': 2160,
          };
        case 'shareMediaFiles':
        case 'copyPngToClipboard':
        case 'deleteMediaAsset':
          return true;
      }
      return null;
    });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final cutout = await ZameraCapture.extractSubjectCutoutPng(
      sourceJpegPath: '/tmp/photo.jpg',
      focusX: 0.42,
      focusY: 0.58,
      addWhiteOutline: true,
      copyToClipboard: false,
      saveToGallery: true,
    );
    expect(cutout['cutoutPngPath'], '/data/user/0/app/files/zamera_stickers/st_1.png');
    expect(recordedCalls['extractSubjectCutoutPng']?['addWhiteOutline'], isTrue);
    expect(recordedCalls['extractSubjectCutoutPng']?['copyToClipboard'], isFalse);
    expect(recordedCalls['extractSubjectCutoutPng']?['saveToGallery'], isTrue);
    expect(recordedCalls['extractSubjectCutoutPng']?['focusX'], 0.42);
    expect(recordedCalls['extractSubjectCutoutPng']?['focusY'], 0.58);

    final frame = await ZameraCapture.extractVideoFrameJpeg(
      videoPath: '/tmp/clip.mp4',
      positionMs: 1234,
    );
    expect(frame['jpegPath'], '/data/user/0/app/files/zamera_frames/fr_1.jpg');
    expect(frame['width'], 3840);
    expect(recordedCalls['extractVideoFrameJpeg']?['positionMs'], 1234);

    final shared = await ZameraCapture.shareMediaFiles(
      filePaths: const ['/tmp/a.jpg', '/tmp/a.dng'],
      mimeType: '*/*',
      title: 'JPEG + DNG',
    );
    expect(shared, isTrue);
    expect(
      recordedCalls['shareMediaFiles']?['filePaths'],
      equals(const ['/tmp/a.jpg', '/tmp/a.dng']),
    );

    final copied = await ZameraCapture.copyPngToClipboard(
      pngPath: '/tmp/st_1.png',
    );
    expect(copied, isTrue);
    expect(recordedCalls['copyPngToClipboard']?['pngPath'], '/tmp/st_1.png');

    final deleted = await ZameraCapture.deleteMediaAsset(
      filePath: '/tmp/a.jpg',
      mediaStoreUri: 'content://media/external/images/media/42',
    );
    expect(deleted, isTrue);
    expect(recordedCalls['deleteMediaAsset']?['filePath'], '/tmp/a.jpg');
    expect(
      recordedCalls['deleteMediaAsset']?['mediaStoreUri'],
      'content://media/external/images/media/42',
    );
  });
}
