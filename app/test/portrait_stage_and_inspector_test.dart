import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamera/dialogs/capture_inspector_modal.dart';
import 'package:zamera/painters/portrait_studio_painter.dart';
import 'package:zamera_capture/zamera_capture.dart';

const MethodChannel _kCaptureChannel = MethodChannel(
  'com.akarworks.zamera/capture_probe',
);

/// Valid 1x1 transparent PNG bytes for inspector cutout banner verification.
final Uint8List _kTinyTransparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

PortraitStudioFramePainter _makePainter({
  Offset focusNorm = const Offset(0.5, 0.45),
  double aperture = 2.8,
  int lightingIndex = 0,
  double lightIntensity = 0.80,
  double subjectRadiusRatio = 0.36,
  double zoomFactor = 1.0,
  String subjectDetectionLabel = 'YÜZ ALGILANDI',
  String? distanceWarning,
}) {
  return PortraitStudioFramePainter(
    focusNorm: focusNorm,
    aperture: aperture,
    lightingIndex: lightingIndex,
    lightIntensity: lightIntensity,
    subjectRadiusRatio: subjectRadiusRatio,
    zoomFactor: zoomFactor,
    subjectDetectionLabel: subjectDetectionLabel,
    distanceWarning: distanceWarning,
  );
}

Future<ByteData> _rasterizePainter(
  PortraitStudioFramePainter painter, {
  int width = 390,
  int height = 844,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  addTearDown(image.dispose);
  addTearDown(picture.dispose);
  final bytes = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  return bytes!;
}

Color _readPixelRgba(ByteData rgba, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  return Color.fromARGB(
    rgba.getUint8(offset + 3),
    rgba.getUint8(offset),
    rgba.getUint8(offset + 1),
    rgba.getUint8(offset + 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kCaptureChannel, null);
  });

  group('PortraitStudioFramePainter stage mask & shouldRepaint', () {
    test('handles Size.zero safely without throwing across lighting modes', () {
      for (final mode in <int>[0, 3, 4, 5]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => _makePainter(lightingIndex: mode).paint(canvas, Size.zero),
          returnsNormally,
        );
        recorder.endRecording().dispose();
      }
    });

    test('renders stable stage masks for lightingIndex 0, 3, 4, 5', () async {
      const w = 390;
      const h = 844;
      // Outside stage circle (x=24, y=220) and inside subject center (x=195, y=380).
      const outsideX = 24;
      const outsideY = 220;
      const centerX = 195;
      const centerY = 380;

      final naturalRgba = await _rasterizePainter(
        _makePainter(lightingIndex: 0, lightIntensity: 0.80),
      );
      expect(_readPixelRgba(naturalRgba, w, outsideX, outsideY).a, 0.0);
      expect(_readPixelRgba(naturalRgba, w, centerX, centerY).a, 0.0);

      for (final stageMode in <int>[3, 4]) {
        final stageRgba = await _rasterizePainter(
          _makePainter(lightingIndex: stageMode, lightIntensity: 0.80),
          width: w,
          height: h,
        );
        final outside = _readPixelRgba(stageRgba, w, outsideX, outsideY);
        final center = _readPixelRgba(stageRgba, w, centerX, centerY);

        // Inside stageRadius remains optically clear; outside is darkened black.
        expect(center.a, 0.0);
        expect(outside.a, closeTo(0.42 + 0.30 * 0.80, 0.02));
        expect(outside.r, 0.0);
        expect(outside.g, 0.0);
        expect(outside.b, 0.0);
      }

      final highKeyRgba = await _rasterizePainter(
        _makePainter(lightingIndex: 5, lightIntensity: 0.75),
        width: w,
        height: h,
      );
      final outsideHighKey = _readPixelRgba(highKeyRgba, w, outsideX, outsideY);
      final centerHighKey = _readPixelRgba(highKeyRgba, w, centerX, centerY);

      expect(centerHighKey.a, 0.0);
      expect(outsideHighKey.a, closeTo(0.40 + 0.28 * 0.75, 0.02));
      expect(outsideHighKey.r, greaterThan(0.90));
      expect(outsideHighKey.g, greaterThan(0.90));
      expect(outsideHighKey.b, greaterThan(0.90));
    });

    test('shouldRepaint contract reflects exact delegate changes', () {
      final base = _makePainter();
      expect(base.shouldRepaint(_makePainter()), isFalse);

      expect(
        base.shouldRepaint(_makePainter(focusNorm: const Offset(0.3, 0.6))),
        isTrue,
      );
      expect(base.shouldRepaint(_makePainter(aperture: 1.4)), isTrue);
      expect(base.shouldRepaint(_makePainter(lightingIndex: 3)), isTrue);
      expect(base.shouldRepaint(_makePainter(lightIntensity: 0.35)), isTrue);
      expect(
        base.shouldRepaint(_makePainter(subjectRadiusRatio: 0.48)),
        isTrue,
      );
      expect(base.shouldRepaint(_makePainter(zoomFactor: 2.0)), isTrue);
      expect(
        base.shouldRepaint(_makePainter(subjectDetectionLabel: '')),
        isTrue,
      );
      expect(
        base.shouldRepaint(_makePainter(distanceWarning: 'Daha uzağa gidin')),
        isTrue,
      );
    });
  });

  group('ZameraCapture.extractSubjectCutoutPng channel contract', () {
    test(
      'forwards saveToGallery == false by default and respects shareNow',
      () async {
        final recordedCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_kCaptureChannel, (call) async {
              recordedCalls.add(call);
              return <String, dynamic>{
                'cutoutPngPath': '/tmp/ZAM_TEST_CUTOUT.png',
              };
            });

        final defaultOut = await ZameraCapture.extractSubjectCutoutPng(
          sourceJpegPath: '/tmp/source_portrait.jpg',
        );
        expect(defaultOut['cutoutPngPath'], '/tmp/ZAM_TEST_CUTOUT.png');
        expect(recordedCalls, hasLength(1));
        expect(recordedCalls.single.method, 'extractSubjectCutoutPng');
        final defaultArgs = Map<String, dynamic>.from(
          recordedCalls.single.arguments as Map<dynamic, dynamic>,
        );
        expect(defaultArgs['sourceJpegPath'], '/tmp/source_portrait.jpg');
        expect(defaultArgs['saveToGallery'], isFalse);
        expect(defaultArgs['shareNow'], isFalse);
        expect(defaultArgs['focusX'], 0.5);
        expect(defaultArgs['focusY'], 0.45);
        expect(defaultArgs['subjectRadiusRatio'], 0.36);
        expect(defaultArgs['isFrontCamera'], isFalse);

        final shareOut = await ZameraCapture.extractSubjectCutoutPng(
          sourceJpegPath: '/tmp/source_portrait.jpg',
          focusX: 0.25,
          focusY: 0.70,
          subjectRadiusRatio: 0.42,
          isFrontCamera: true,
          shareNow: true,
        );
        expect(shareOut['cutoutPngPath'], '/tmp/ZAM_TEST_CUTOUT.png');
        expect(recordedCalls, hasLength(2));
        final shareArgs = Map<String, dynamic>.from(
          recordedCalls.last.arguments as Map<dynamic, dynamic>,
        );
        expect(shareArgs['saveToGallery'], isFalse);
        expect(shareArgs['shareNow'], isTrue);
        expect(shareArgs['focusX'], 0.25);
        expect(shareArgs['focusY'], 0.70);
        expect(shareArgs['subjectRadiusRatio'], 0.42);
        expect(shareArgs['isFrontCamera'], isTrue);
      },
    );
  });

  group('CaptureInspectorModal long-press & cutout actions', () {
    testWidgets(
      'long-press updates focus/measurement without triggering cutout; buttons forward shareNow and saveToGallery == false',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final tempDir = Directory.systemTemp.createTempSync('zamera_cutout_');
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });
        final cutoutFile = File('${tempDir.path}/cutout.png')
          ..writeAsBytesSync(_kTinyTransparentPng);

        final recordedCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_kCaptureChannel, (call) async {
              recordedCalls.add(call);
              if (call.method == 'extractSubjectCutoutPng') {
                return <String, dynamic>{'cutoutPngPath': cutoutFile.path};
              }
              return <String, dynamic>{};
            });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CaptureInspectorModal(
                captureResult: const CapturePhotoResult(
                  cameraId: '0',
                  jpegPath: '/tmp/nonexistent_source.jpg',
                  outputWidth: 3000,
                  outputHeight: 4000,
                  meanRgb: <double>[0.5, 0.4, 0.3],
                ),
                isPortraitCapture: false,
              ),
            ),
          ),
        );
        await tester.pump();

        final canvasFinder = find.byKey(const ValueKey('inspector_photo_canvas'));
        expect(canvasFinder, findsOneWidget);

        // Long-press on the photo canvas must NOT invoke extractSubjectCutoutPng.
        final canvasTopLeft = tester.getTopLeft(canvasFinder);
        await tester.longPressAt(canvasTopLeft + const Offset(120, 90));
        await tester.pump();
        expect(
          recordedCalls.where((c) => c.method == 'extractSubjectCutoutPng'),
          isEmpty,
        );

        // Explicit copy button invokes cutout with shareNow: false, saveToGallery: false.
        final copyBtn = find.text('Özneyi Seç & Kopyala');
        await tester.ensureVisible(copyBtn);
        await tester.tap(copyBtn);
        await tester.pumpAndSettle();

        expect(recordedCalls, hasLength(1));
        final copyArgs = Map<String, dynamic>.from(
          recordedCalls.single.arguments as Map<dynamic, dynamic>,
        );
        expect(copyArgs['shareNow'], isFalse);
        expect(copyArgs['saveToGallery'], isFalse);
        expect(
          find.text('Özne ayrıldı ve şeffaf çıkartma olarak panoya kopyalandı'),
          findsOneWidget,
        );

        // Explicit share button invokes cutout with shareNow: true, saveToGallery: false.
        final shareBtn = find.text('Çıkartma Paylaş (PNG)');
        await tester.ensureVisible(shareBtn);
        await tester.tap(shareBtn);
        await tester.pumpAndSettle();

        expect(recordedCalls, hasLength(2));
        final shareArgs = Map<String, dynamic>.from(
          recordedCalls.last.arguments as Map<dynamic, dynamic>,
        );
        expect(shareArgs['shareNow'], isTrue);
        expect(shareArgs['saveToGallery'], isFalse);
        expect(
          find.text('Özne ayrıldı, panoya kopyalandı ve paylaşım açıldı'),
          findsOneWidget,
        );
      },
    );
  });
}
