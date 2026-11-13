import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zamera_capture/zamera_capture.dart';
import 'package:zamera_video/zamera_video.dart';
import 'package:zamera/main.dart';
import 'package:zamera/dialogs/calibration_probe_sheet.dart';
import 'package:zamera/dialogs/capture_inspector_modal.dart';
import 'package:zamera/dialogs/release_notes_dialog.dart';
import 'package:zamera/dialogs/settings_sheet.dart';
import 'package:zamera/models/app_version_info.dart';
import 'package:zamera/painters/portrait_studio_painter.dart';
import 'package:zamera/painters/radial_wheel_painter.dart';
import 'package:zamera/services/color_calibration_store.dart';
import 'package:zamera/services/version_tracking_service.dart';
import 'package:zamera/widgets/truecolor_spot_meter_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sharma 2005 CIEDE2000 canonical pairs match within 1e-3', () {
    final pair1 = ZameraCapture.computeCiede2000(
      const [50.0000, 2.6772, -79.7751],
      const [50.0000, 0.0000, -82.7485],
    );
    expect((pair1 - 2.0425).abs(), lessThan(1e-3));

    final pair2 = ZameraCapture.computeCiede2000(
      const [50.0000, 3.1571, -77.2803],
      const [50.0000, 0.0000, -82.7485],
    );
    expect((pair2 - 2.8615).abs(), lessThan(1e-3));
  });

  test('24-Patch ColorChecker 3x3 calibration reduces sensor color cast below DeltaE 0.5', () {
    final measured = ZameraCapture.simulateUncalibratedSensor24(
      redShift: 1.55,
      greenShift: 1.20,
      blueShift: 0.78,
    );
    final res = ZameraCapture.calibrateColorChecker24(measured);
    expect(res.meanDeltaEBefore, greaterThan(8.0));
    expect(res.meanDeltaEAfter, lessThan(0.5));
    expect(res.patchDeltaEAfter.length, equals(24));
  });

  test('Pro Video module is enabled and exposes Phase 3 Cinema profiles', () {
    const info = ZameraVideoIsolationInfo();
    expect(info.isEnabledByFlag, isTrue);
    expect(info.plannedProfiles, isNotEmpty);
  });

  test('VersionTrackingService detects first launch and version updates accurately', () async {
    // 1. Initial State (Clean install)
    SharedPreferences.setMockInitialValues({});
    final service = await VersionTrackingService.initialize();
    expect(service.isFirstLaunch, isTrue);
    expect(service.isVersionUpdate, isFalse);

    // 2. Mark seen
    await service.markCurrentVersionSeen();
    expect(service.isFirstLaunch, isFalse);
    expect(service.isVersionUpdate, isFalse);

    // 3. Simulated Older version (e.g. build 1)
    SharedPreferences.setMockInitialValues({
      'zamera_last_seen_version': '0.1.0',
      'zamera_last_seen_build': 1,
      'zamera_has_completed_onboarding': true,
    });
    final updatedService = await VersionTrackingService.initialize();
    expect(updatedService.isFirstLaunch, isFalse);
    expect(updatedService.isVersionUpdate, isTrue);
  });

  testWidgets('ReleaseNotesDialog renders general features and changelog tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReleaseNotesDialog(initialShowFeatures: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zamera'), findsOneWidget);
    expect(find.text('ZAMERA PROFESYONEL ÖZELLİKLERİ'), findsOneWidget);
    expect(find.text('Gerçek Renk & Sanat Modu (ΔE₀₀ ≤ 1.0)'), findsOneWidget);
    expect(find.text('Sinema Seviyesi Pro Video (180° Kilit)'), findsOneWidget);

    // Switch to changelog tab
    await tester.tap(find.text('Sürüm ${AppVersionInfo.currentVersion}'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Faz 0-3 iOS Eşliği'), findsOneWidget);
  });

  testWidgets('SettingsSheet displays all configuration and compliance tiles', (WidgetTester tester) async {
    bool probeOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsSheet(
            onOpenProbe: () => probeOpened = true,
            onOpenCalibration: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zamera Ayarları'), findsOneWidget);
    expect(find.text('Sürüm Notları & Yenilikler'), findsOneWidget);
    expect(find.text('Zamera Genel Özellikleri'), findsOneWidget);
    expect(find.text('Cihaz Yetenek Probe (Faz 0)'), findsOneWidget);
    expect(find.text('Gizlilik Politikası (GitHub Pages)', skipOffstage: false), findsOneWidget);
    expect(find.text('Telif & Açık Kaynak Lisansları', skipOffstage: false), findsOneWidget);

    expect(find.text('ColorChecker Kalibrasyonu (Faz 1)'), findsOneWidget);
    await tester.tap(find.text('Cihaz Yetenek Probe (Faz 0)'));
    await tester.pumpAndSettle();
    expect(probeOpened, isTrue);
  });

  testWidgets('Zamera shortened categories, radial shutter swipe menu, Portrait and Pro Video modes work cleanly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'zamera_last_seen_version': AppVersionInfo.currentVersion,
      'zamera_last_seen_build': AppVersionInfo.currentBuildNumber,
      'zamera_has_completed_onboarding': true,
    });
    final vs = await VersionTrackingService.initialize();

    await tester.pumpWidget(ZameraApp(versionService: vs));
    expect(find.text('ZAMERA'), findsNothing);
    expect(find.text('Faz 0: Probe'), findsNothing);
    expect(find.text('SANAT'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('PORTRE'), findsOneWidget);
    expect(find.text('VİDEO'), findsOneWidget);

    // Verify Settings button exists on top right
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // Open Settings Sheet from Top Bar
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Zamera Ayarları'), findsOneWidget);
    // Dismiss sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Radial setting buttons (.5, 1x, 2x, ISO, WB...) are hidden by default when category opens
    expect(find.text('ISO'), findsNothing);
    expect(find.text('WB'), findsNothing);

    // Swipe up on the shutter button in the direction of the arrow to open radial setting buttons
    await tester.drag(find.byKey(const ValueKey('shutter_button_gesture')), const Offset(0, -45));
    await tester.pumpAndSettle();
    expect(find.text('ISO'), findsOneWidget);
    expect(find.text('WB'), findsOneWidget);

    // Select a radial setting button (e.g. ISO) and verify radial adjustment dial opens WITHOUT 4mm outer secondary ring
    await tester.tap(find.text('ISO'));
    await tester.pumpAndSettle();
    IosCameraRadialWheelPainter findWheelPainter() {
      final cpFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is IosCameraRadialWheelPainter,
      );
      expect(cpFinder, findsOneWidget);
      return (tester.widget<CustomPaint>(cpFinder).painter
          as IosCameraRadialWheelPainter);
    }
    expect(findWheelPainter().secondaryItems, isEmpty);

    // Switch to PORTRE mode and verify ideal iPhone default settings (f/2.8 + 1x/2x/3x optical lens bar)
    await tester.tap(find.text('PORTRE'));
    await tester.pumpAndSettle();
    expect(find.text('ƒ 2.8'), findsOneWidget);
    expect(find.text('1×'), findsOneWidget);
    expect(find.text('24mm'), findsOneWidget);
    expect(find.text('2×'), findsOneWidget);
    expect(find.text('48mm'), findsOneWidget);
    expect(find.text('3×'), findsOneWidget);
    expect(find.text('77mm'), findsOneWidget);
    expect(find.text('ISO'), findsNothing);

    await tester.tap(find.text('3×'));
    await tester.pumpAndSettle();

    // Swipe up on shutter in PORTRE mode, tap IŞIK and verify 4mm concentric outer ring has Studio, Panjur & Monochrome effects
    await tester.drag(find.byKey(const ValueKey('shutter_button_gesture')), const Offset(0, -45));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IŞIK'));
    await tester.pumpAndSettle();
    final lightRingItems = findWheelPainter().secondaryItems;
    expect(lightRingItems, contains('STÜDYO IŞIĞI'));
    expect(lightRingItems, contains('PANJUR GÖLGESİ'));
    expect(lightRingItems, contains('PANJUR MONO'));
    expect(lightRingItems, contains('SAHNE MONO'));

    // Switch to VİDEO mode and verify Cinema HUD + swipe-up radial Cinema buttons (FPS, AÇI, PROFİL, LUT, SES)
    await tester.tap(find.text('VİDEO'));
    await tester.pumpAndSettle();
    expect(find.textContaining('STBY 00:00:00:00'), findsOneWidget);

    await tester.drag(find.byKey(const ValueKey('shutter_button_gesture')), const Offset(0, -45));
    await tester.pumpAndSettle();
    expect(find.text('FPS'), findsOneWidget);
    expect(find.text('AÇI'), findsOneWidget);
    expect(find.text('PROFİL'), findsOneWidget);
    expect(find.text('LUT'), findsOneWidget);
    expect(find.text('SES'), findsOneWidget);
    expect(find.text('2× DİJ'), findsOneWidget);

    // Open LUT radial dial and verify 4mm concentric outer ring includes .CUBE YÜKLE and LUT presets
    await tester.tap(find.text('LUT'));
    await tester.pumpAndSettle();
    expect(findWheelPainter().secondaryItems, contains('.CUBE YÜKLE'));

    // Verify radial setting buttons are hidden from wheel while a dial is active (anti-clutter)
    expect(find.text('SES'), findsNothing);

    // Verify Active Dial Return Pill is visible directly above mode strip
    expect(find.byIcon(Icons.undo_rounded), findsOneWidget);

    // Tap return pill and verify radial settings menu re-opens cleanly
    await tester.tap(find.byIcon(Icons.undo_rounded));
    await tester.pumpAndSettle();
    expect(find.text('FPS'), findsOneWidget);
    expect(find.text('AÇI'), findsOneWidget);
    expect(find.text('SES'), findsOneWidget);

    // Tap MF in Video mode and verify 4mm concentric outer ring options (AF OTO, SONSUZ, PEAKING, A<->B)
    await tester.tap(find.text('MF'));
    await tester.pumpAndSettle();
    final mfRingItems = findWheelPainter().secondaryItems;
    expect(mfRingItems, contains('AF (OTOMATİK)'));
    expect(mfRingItems, contains('∞ SONSUZ'));
    expect(mfRingItems, contains('PEAKING'));

    // Return to radial menu via return pill again
    await tester.tap(find.byIcon(Icons.undo_rounded));
    await tester.pumpAndSettle();
    expect(find.text('EV'), findsOneWidget);
  });

  test('BoxFit.contain image rect and normalized [0,1] touch mapping strip black margins accurately', () {
    // 1. Default 3:4 portrait aspect inside 400x360 container -> 270x360 centered (65px pillarbox on left & right)
    final portraitRect = computeContainedImageRect(
      containerSize: const Size(400, 360),
    );
    expect(portraitRect.left, closeTo(65.0, 1e-6));
    expect(portraitRect.top, closeTo(0.0, 1e-6));
    expect(portraitRect.width, closeTo(270.0, 1e-6));
    expect(portraitRect.height, closeTo(360.0, 1e-6));

    // Left edge of image (x=65) -> 0.0, center (x=200) -> 0.5, right edge (x=335) -> 1.0
    final leftEdgeNorm = mapLocalTapToNormalizedImagePoint(
      localPosition: const Offset(65.0, 180.0),
      imageRect: portraitRect,
    );
    expect(leftEdgeNorm.dx, closeTo(0.0, 1e-6));
    expect(leftEdgeNorm.dy, closeTo(0.5, 1e-6));

    final centerNorm = mapLocalTapToNormalizedImagePoint(
      localPosition: const Offset(200.0, 180.0),
      imageRect: portraitRect,
    );
    expect(centerNorm.dx, closeTo(0.5, 1e-6));
    expect(centerNorm.dy, closeTo(0.5, 1e-6));

    final rightBlackBarTap = mapLocalTapToNormalizedImagePoint(
      localPosition: const Offset(390.0, 90.0),
      imageRect: portraitRect,
    );
    expect(rightBlackBarTap.dx, closeTo(1.0, 1e-6));
    expect(rightBlackBarTap.dy, closeTo(0.25, 1e-6));

    // 2. Explicit 4:3 landscape (4000x3000) inside 320x360 container -> 320x240 centered (60px letterbox top & bottom)
    final landscapeRect = computeContainedImageRect(
      containerSize: const Size(320, 360),
      imageWidth: 4000,
      imageHeight: 3000,
    );
    expect(landscapeRect.left, closeTo(0.0, 1e-6));
    expect(landscapeRect.top, closeTo(60.0, 1e-6));
    expect(landscapeRect.width, closeTo(320.0, 1e-6));
    expect(landscapeRect.height, closeTo(240.0, 1e-6));

    final topImageEdge = mapLocalTapToNormalizedImagePoint(
      localPosition: const Offset(80.0, 60.0),
      imageRect: landscapeRect,
    );
    expect(topImageEdge.dx, closeTo(0.25, 1e-6));
    expect(topImageEdge.dy, closeTo(0.0, 1e-6));

    final roundTripCanvas = mapNormalizedImagePointToCanvasOffset(
      focusNorm: topImageEdge,
      imageRect: landscapeRect,
    );
    expect(roundTripCanvas.dx, closeTo(80.0, 1e-6));
    expect(roundTripCanvas.dy, closeTo(60.0, 1e-6));
  });

  testWidgets('PortraitStudioFramePainter renders corner reticle, studio lighting pill and distance warning cleanly', (WidgetTester tester) async {
    const basePainter = PortraitStudioFramePainter(
      focusNorm: Offset(0.5, 0.45),
      aperture: 2.8,
      lightingIndex: 1,
      lightIntensity: 0.80,
      subjectRadiusRatio: 0.34,
      zoomFactor: 1.0,
      subjectDetectionLabel: 'YÜZ ALGILANDI · ARKA PLAN AYRILDI',
    );
    const warnPainter = PortraitStudioFramePainter(
      focusNorm: Offset(0.5, 0.45),
      aperture: 2.8,
      lightingIndex: 4,
      lightIntensity: 0.80,
      subjectRadiusRatio: 0.34,
      zoomFactor: 2.0,
      subjectDetectionLabel: 'NESNE ALGILANDI · 15 cm',
      distanceWarning: 'Daha uzağa gidin',
    );

    expect(basePainter.shouldRepaint(basePainter), isFalse);
    expect(warnPainter.shouldRepaint(basePainter), isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 760,
            child: CustomPaint(painter: basePainter),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 760,
            child: CustomPaint(painter: warnPainter),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('CaptureInspectorModal supports PORTRE On/Off pill, BoxFit.contain tap focus, and Light Intensity 0..100 slider', (WidgetTester tester) async {
    final parsedResult = CapturePhotoResult.fromMap(const {
      'cameraId': '2',
      'jpegPath': '/tmp/zamera_portrait_test.jpg',
      'oemJpegPath': '/tmp/zamera_oem_test.jpg',
      'outputWidth': 3000,
      'outputHeight': 4000,
      'portraitDepthActive': true,
    });
    expect(parsedResult.portraitDepthActive, isTrue);

    final recordedCalls = <MethodCall>[];
    const channel = MethodChannel('com.akarworks.zamera/capture_probe');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      recordedCalls.add(call);
      return <String, dynamic>{};
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              height: 600,
              child: CaptureInspectorModal(
                captureResult: parsedResult,
                initialAperture: 2.8,
                initialLightingIndex: 0,
                initialLightIntensity: 0.75,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. PORTRE toggle pill starts enabled; Toggle PORTRE pill off -> sends portraitEnabled: false
    expect(find.byKey(const ValueKey('inspector_portrait_toggle_pill')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inspector_portrait_toggle_pill')));
    await tester.pumpAndSettle();
    expect(find.text('KAPALI'), findsOneWidget);
    expect(recordedCalls, isNotEmpty);
    expect(recordedCalls.last.method, equals('reprocessPortraitPhoto'));
    expect((recordedCalls.last.arguments as Map)['portraitEnabled'], isFalse);

    // 2. Scroll to Post-Capture Sliders: verify Light Intensity (0..100) disabled at lightingIndex == 0, active when > 0
    await tester.scrollUntilVisible(
      find.text('STÜDYO IŞIĞI'),
      160.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('IŞIK ŞİDDETİ'), findsOneWidget);

    Slider lightSlider() => tester.widget<Slider>(
          find.byKey(const ValueKey('inspector_light_intensity_slider')),
        );
    expect(lightSlider().min, equals(0.0));
    expect(lightSlider().max, equals(100.0));
    expect(lightSlider().value, closeTo(75.0, 1e-3));
    expect(lightSlider().onChanged, isNull);

    await tester.tap(find.text('STÜDYO IŞIĞI'));
    await tester.pumpAndSettle();
    expect(lightSlider().onChanged, isNotNull);
  });

  test('ColorCalibrationStore persists and isolates per-lens ColorChecker, Gray-Card WB, and 8x6 flat-field', () async {
    SharedPreferences.setMockInitialValues({});
    const store = ColorCalibrationStore();

    final measured = ZameraCapture.simulateUncalibratedSensor24(
      redShift: 1.42,
      greenShift: 1.15,
      blueShift: 0.85,
    );
    final baseCal = ZameraCapture.calibrateColorChecker24(measured);
    final sensorCal = ColorCheckerCalibrationResult.fromMap({
      ...baseCal.toMap(),
      'isMeasuredFromSensor': true,
    });
    final flatField = List<double>.filled(48, 1.04);

    expect(await store.saveCalibrationResult('2', sensorCal), isTrue);
    expect(
      await store.saveGrayCardWb(
        '2',
        wbGains: const [1.72, 1.0, 1.54],
        enabled: true,
      ),
      isTrue,
    );
    expect(await store.saveFlatField8x6('2', flatField), isTrue);

    final loadedLens2 = await store.loadForLens('2');
    expect(loadedLens2.hasSensorCalibration, isTrue);
    expect(loadedLens2.calibrationResult!.isMeasuredFromSensor, isTrue);
    expect(loadedLens2.calibrationResult!.meanDeltaEAfter, lessThan(0.5));
    expect(loadedLens2.hasGrayCardWb, isTrue);
    expect(loadedLens2.useGrayCardWb, isTrue);
    expect(loadedLens2.grayCardWbGains, equals(const [1.72, 1.0, 1.54]));
    expect(loadedLens2.hasFlatField, isTrue);

    // Other physical lens ('3') stays untouched
    final loadedLens3 = await store.loadForLens('3');
    expect(loadedLens3.hasSensorCalibration, isFalse);
    expect(loadedLens3.hasGrayCardWb, isFalse);

    // Reset clears lens '2'
    expect(await store.resetForLens('2'), isTrue);
    final afterReset = await store.loadForLens('2');
    expect(afterReset.hasSensorCalibration, isFalse);
    expect(afterReset.hasGrayCardWb, isFalse);
    expect(afterReset.hasFlatField, isFalse);
  });

  testWidgets('TrueColorSpotMeterBadge and CalibrationAndProbeSheet render 1:1 color telemetry and profile actions', (WidgetTester tester) async {
    final lab = ZameraCapture.srgb8ToLabD50(194, 150, 130);
    final patch = ZameraCapture.nearestColorCheckerPatch(lab);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TrueColorSpotMeterBadge(
                srgb8: const [194, 150, 130],
                labD50: lab,
                nearestPatch: patch,
                isCalibrated: true,
                wbLabel: 'GRİ KART',
              ),
              const TrueColorCenterReticle(
                srgb8: [194, 150, 130],
                isCalibrated: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#C29682'), findsOneWidget);
    expect(find.textContaining('3×3 · GRİ KART'), findsOneWidget);
    expect(find.textContaining('ΔE00'), findsOneWidget);

    bool triggerCalled = false;
    bool resetCalled = false;
    final rawCal = ZameraCapture.calibrateColorChecker24(
      ZameraCapture.simulateUncalibratedSensor24(),
    );
    final sensorCal = ColorCheckerCalibrationResult.fromMap({
      ...rawCal.toMap(),
      'isMeasuredFromSensor': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalibrationAndProbeSheet(
            calibrationResult: sensorCal,
            activeCameraId: '2',
            onTriggerCameraCalibration: () => triggerCalled = true,
            onResetCalibration: () => resetCalled = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gerçek Sensör Kalibrasyonu'), findsOneWidget);
    expect(find.text('24-Yama Kalibre Et'), findsOneWidget);
    expect(find.text('Kalibrasyonu Sıfırla'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calibration_trigger_button')));
    await tester.pumpAndSettle();
    expect(triggerCalled, isTrue);

    await tester.tap(find.byKey(const ValueKey('calibration_reset_button')));
    await tester.pumpAndSettle();
    expect(resetCalled, isTrue);
  });

  testWidgets('CaptureInspectorModal in Sanat Modu shows 1:1 title, TrueColor vs OEM A/B toggle, and dart:ui pixel Lab/DeltaE00', (WidgetTester tester) async {
    late Directory tempDir;
    late File trueColorPng;
    late File oemPng;

    final artworkSetup = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('zamera_inspector_v2_');
      Future<Uint8List> encodeSplitTestPng(
        Color leftColor,
        Color rightColor,
      ) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 10, 20),
          Paint()..color = leftColor,
        );
        canvas.drawRect(
          const Rect.fromLTWH(10, 0, 10, 20),
          Paint()..color = rightColor,
        );
        final pic = recorder.endRecording();
        final img = await pic.toImage(20, 20);
        final bd = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        pic.dispose();
        return bd!.buffer.asUint8List();
      }

      final tcFile = File('${dir.path}/truecolor.png');
      final oemFile = File('${dir.path}/oem.png');
      await tcFile.writeAsBytes(
        await encodeSplitTestPng(
          const Color(0xFFC29682),
          const Color(0xFF627A9D),
        ),
      );
      await oemFile.writeAsBytes(
        await encodeSplitTestPng(
          const Color(0xFFD67E2C),
          const Color(0xFFD67E2C),
        ),
      );
      return (dir: dir, tc: tcFile, oem: oemFile);
    });
    tempDir = artworkSetup!.dir;
    trueColorPng = artworkSetup.tc;
    oemPng = artworkSetup.oem;

    final artworkResult = CapturePhotoResult.fromMap({
      'cameraId': '2',
      'jpegPath': trueColorPng.path,
      'oemJpegPath': oemPng.path,
      'outputWidth': 20,
      'outputHeight': 20,
      'portraitDepthActive': false,
      'colorSpaceTag': 'Display P3',
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                height: 760,
                child: CaptureInspectorModal(
                  captureResult: artworkResult,
                  initialPortraitEnabled: false,
                  isPortraitCapture: false,
                ),
              ),
            ),
          ),
        ),
      );
      // Wait for real dart:io + dart:ui image decode to complete in root async zone
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 15));
        await tester.pump();
        if (find.text('#627A9D').evaluate().isNotEmpty ||
            find.text('#C29682').evaluate().isNotEmpty) {
          break;
        }
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('Sanat Modu — 1:1 Gerçek Renk Denetçisi'), findsOneWidget);
    expect(find.byKey(const ValueKey('inspector_ab_oem_toggle')), findsOneWidget);
    expect(find.text('A/B: TRUECOLOR 1:1'), findsOneWidget);
    expect(find.text('Display P3'), findsOneWidget);

    // Tap left side of the contained 20x20 square inside canvas -> samples #C29682 (Açık Ten)
    final canvasBox = tester.getRect(find.byKey(const ValueKey('inspector_photo_canvas')));
    await tester.tapAt(Offset(canvasBox.center.dx - 60, canvasBox.center.dy));
    await tester.pump();
    expect(find.text('#C29682'), findsOneWidget);
    expect(find.textContaining('Açık Ten'), findsOneWidget);

    // Toggle A/B to Stok Kamera (OEM) -> re-decodes OEM image (#D67E2C Turuncu) inside runAsync
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('inspector_ab_oem_toggle')));
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 15));
        await tester.pump();
        if (find.text('#D67E2C').evaluate().isNotEmpty) {
          break;
        }
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('A/B: STOK KAMERA (OEM)'), findsOneWidget);
    expect(find.text('#D67E2C'), findsOneWidget);

    // Unmount Image.file and evict imageCache before deleting temp files on Windows
    imageCache.clear();
    imageCache.clearLiveImages();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          debugPrint('Temp cleanup skipped: $e');
        }
      }
    });
  });

  testWidgets('Sanat Modu defaults to 1:1 TON (mode 2), exposes visible quick pills, and pushes wbGains & camToXyzD50 to live preview and capture', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'zamera_last_seen_version': AppVersionInfo.currentVersion,
      'zamera_last_seen_build': AppVersionInfo.currentBuildNumber,
      'zamera_has_completed_onboarding': true,
    });
    final vs = await VersionTrackingService.initialize();

    final recordedCalls = <MethodCall>[];
    final calRaw = ZameraCapture.calibrateColorChecker24(
      ZameraCapture.simulateUncalibratedSensor24(),
    );
    final measuredCalMap = <String, dynamic>{
      ...calRaw.toMap(),
      'isMeasuredFromSensor': true,
    };

    const channel = MethodChannel('com.akarworks.zamera/capture_probe');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      recordedCalls.add(call);
      switch (call.method) {
        case 'probeDeviceCapabilities':
          return <String, dynamic>{
            'platform': 'android',
            'manufacturer': 'Test',
            'brand': 'Test',
            'model': 'Pro',
            'device': 'pro',
            'sdkInt': 35,
            'release': '15',
            'rustCoreVersion': '0.2.0',
            'cameraIdList': ['2'],
            'cameras': [
              {
                'cameraId': '2',
                'isDirectlyOpenableInCameraIdList': true,
                'facing': 'BACK',
                'hardwareLevel': 'FULL',
                'supportsRawSensor': true,
                'rawSensorSizes': ['4000x3000'],
                'maxResolutionRawSensorSizes': ['4000x3000'],
                'physicalCameraIds': <String>[],
                'focalLengthsMm': [6.8],
                'apertures': [1.8],
                'minimumFocusDistanceDiopters': 10.0,
                'supportsOis': true,
                'capabilities': ['RAW'],
                'tenBitDynamicRangeProfiles': <String>[],
              },
            ],
          };
        case 'startPreviewSession':
          return <String, dynamic>{
            'textureId': -1,
            'previewWidth': 1920,
            'previewHeight': 1440,
            'sensorOrientation': 90,
            'activeCameraId': '2',
            'supportsRawSensor': true,
          };
        case 'getLiveTelemetry':
          return <String, dynamic>{
            'iso': 100,
            'exposureTimeNs': 8000000,
            'liveCenterSrgb': [194, 150, 130],
            'liveCenterLabD50': [65.7, 18.1, 17.8],
          };
        case 'updateManualControls':
          return true;
        case 'capturePhoto':
          final args = call.arguments as Map;
          return <String, dynamic>{
            'cameraId': '2',
            'jpegPath': '/tmp/zamera_art.jpg',
            'rustIspActive': true,
            'centerLinearCamRgb': [0.18, 0.25, 0.16],
            'solvedCctKelvin': 5400.0,
            if (args['calibrateColorChecker'] == true)
              'liveCalibrationResult': measuredCalMap,
          };
        default:
          return <String, dynamic>{};
      }
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(ZameraApp(versionService: vs));
    await tester.pumpAndSettle();

    // Visible Sanat Modu 1:1 pills without opening top drawer
    expect(find.text('1:1 TON'), findsOneWidget);
    expect(find.text('GRİ KART WB'), findsOneWidget);
    expect(find.text('24-YAMA KALİBRE'), findsOneWidget);
    expect(find.text('RENK ÖLÇER'), findsOneWidget);
    expect(find.text('KAYIPSIZ PNG'), findsOneWidget);
    expect(find.byType(TrueColorSpotMeterBadge), findsOneWidget);

    // Toggle 1:1 TON -> KAĞIT L*94 -> back to 1:1 TON
    await tester.tap(find.text('1:1 TON'));
    await tester.pumpAndSettle();
    expect(find.text('KAĞIT L*94'), findsOneWidget);
    await tester.tap(find.text('KAĞIT L*94'));
    await tester.pumpAndSettle();
    expect(find.text('1:1 TON'), findsOneWidget);

    // Enable KAYIPSIZ PNG, calibrate 24-patch, and lock GRİ KART WB
    await tester.tap(find.text('KAYIPSIZ PNG'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('24-YAMA KALİBRE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GRİ KART WB'));
    await tester.pumpAndSettle();

    // Verify live preview received both customWbGains and camToXyzD50!
    final previewControlCalls = recordedCalls
        .where((c) => c.method == 'updateManualControls')
        .toList();
    expect(previewControlCalls, isNotEmpty);
    final lastPreviewArgs = previewControlCalls.last.arguments as Map;
    expect(lastPreviewArgs['customWbGains'], isNotNull);
    expect((lastPreviewArgs['customWbGains'] as List).length, equals(3));
    expect(lastPreviewArgs['camToXyzD50'], isNotNull);
    expect((lastPreviewArgs['camToXyzD50'] as List).length, equals(9));

    // Trigger Sanat Modu capture in KAĞIT L*94 -> artworkExposureMode=1, normalizeExposure=true
    await tester.tap(find.text('1:1 TON'));
    await tester.pumpAndSettle();
    expect(find.text('KAĞIT L*94'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shutter_button_gesture')));
    await tester.pumpAndSettle();
    final paperL94CaptureArgs = recordedCalls
        .where((c) => c.method == 'capturePhoto')
        .last
        .arguments as Map;
    expect(paperL94CaptureArgs['artworkExposureMode'], equals(1));
    expect(paperL94CaptureArgs['normalizeExposure'], isTrue);

    // Switch back to 1:1 TON and trigger final Sanat Modu capture -> artworkExposureMode=2, normalizeExposure=false, losslessPng=true, wbGains, camToXyzD50
    await tester.tap(find.text('KAĞIT L*94'));
    await tester.pumpAndSettle();
    expect(find.text('1:1 TON'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shutter_button_gesture')));
    await tester.pumpAndSettle();

    final captureCalls = recordedCalls
        .where((c) => c.method == 'capturePhoto')
        .toList();
    final finalCaptureArgs = captureCalls.last.arguments as Map;
    expect(finalCaptureArgs['artworkExposureMode'], equals(2));
    expect(finalCaptureArgs['normalizeExposure'], isFalse);
    expect(finalCaptureArgs['losslessPng'], isTrue);
    expect(finalCaptureArgs['wbGains'], isNotNull);
    expect(finalCaptureArgs['camToXyzD50'], isNotNull);
    expect((finalCaptureArgs['camToXyzD50'] as List).length, equals(9));
  });
}
