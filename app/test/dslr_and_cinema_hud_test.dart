import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zamera/main.dart';
import 'package:zamera/models/app_version_info.dart';
import 'package:zamera/models/dslr_exposure_model.dart';
import 'package:zamera/services/version_tracking_service.dart';
import 'package:zamera/widgets/pro_dslr_hud_bar.dart';
import 'package:zamera/widgets/video_cinema_hud.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DslrStopsRegistry & WbPresetRegistry unit tests', () {
    test('formats standard 1/3-EV shutter stops from 1/8000s to 30"', () {
      expect(DslrStopsRegistry.formatShutterNs(125000), equals('1/8000s'));
      expect(DslrStopsRegistry.formatShutterNs(8000000), equals('1/125s'));
      expect(DslrStopsRegistry.formatShutterNs(500000000), equals('0.5"'));
      expect(DslrStopsRegistry.formatShutterNs(1300000000), equals('1.3"'));
      expect(DslrStopsRegistry.formatShutterNs(30000000000), equals('30"'));
    });

    test('logarithmic ISO and Shutter round-trips snap to 1/3-EV stops', () {
      for (final stop in const <int>[50, 100, 320, 800, 3200, 12800]) {
        final norm = DslrStopsRegistry.isoToNorm(stop);
        expect(DslrStopsRegistry.isoFromNorm(norm), equals(stop));
      }

      for (final ns in const <int>[
        125000,
        1000000,
        8000000,
        33333333,
        1000000000,
        30000000000,
      ]) {
        final norm = DslrStopsRegistry.shutterNsToNorm(ns);
        expect(DslrStopsRegistry.shutterNsFromNorm(norm), equals(ns));
      }
    });

    test('bumplessTransfer snaps live AE sensor telemetry to nearest 1/3-EV stops', () {
      final transferred = DslrStopsRegistry.bumplessTransfer(
        liveIso: 312,
        liveShutterNs: 8200000,
      );
      expect(transferred.iso, equals(320));
      expect(transferred.shutterNs, equals(8000000));
      expect(WbPresetRegistry.presets.length, greaterThanOrEqualTo(6));
      expect(WbPresetRegistry.tintPresets, containsAll(<double>[-30, 0, 30]));
    });
  });

  group('ProDslrExposureBar & Cinema HUD atomic widget tests', () {
    testWidgets('ProDslrExposureBar switches PASM modes, Drive modes, and AEL/AFL lock', (tester) async {
      DslrExposureMode activeMode = DslrExposureMode.programP;
      ProDriveMode activeDrive = ProDriveMode.single;
      bool locked = false;
      int isoTaps = 0;
      int shutterTaps = 0;
      int wbTaps = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setLocalState) {
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 390,
                    child: ProDslrExposureBar(
                      mode: activeMode,
                      driveMode: activeDrive,
                      meteredEvDelta: -0.7,
                      evCompensation: 0.3,
                      aeAfLocked: locked,
                      liveIso: 400,
                      liveShutterLabel: '1/250s',
                      liveWbLabel: '5500K',
                      onModeChanged: (m) => setLocalState(() => activeMode = m),
                      onDriveModeChanged: (d) =>
                          setLocalState(() => activeDrive = d),
                      onToggleAeAfLock: () =>
                          setLocalState(() => locked = !locked),
                      onTapIso: () => isoTaps++,
                      onTapShutter: () => shutterTaps++,
                      onTapWb: () => wbTaps++,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('P'), findsOneWidget);
      expect(find.text('Tv'), findsOneWidget);
      expect(find.text('Sv'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);

      await tester.tap(find.text('Tv'));
      await tester.pump();
      expect(activeMode, equals(DslrExposureMode.shutterTv));

      await tester.tap(find.text('M').first);
      await tester.pump();
      expect(activeMode, equals(DslrExposureMode.manualM));

      await tester.tap(find.text('TEK'));
      await tester.pump();
      expect(activeDrive, equals(ProDriveMode.aeb3));
      expect(find.text('AEB ±2'), findsOneWidget);

      await tester.tap(find.text('AEL/AFL'));
      await tester.pump();
      expect(locked, isTrue);

      await tester.tap(find.text('1/250s'));
      await tester.tap(find.textContaining('400'));
      await tester.tap(find.text('5500K'));
      expect(shutterTaps, equals(1));
      expect(isoTaps, equals(1));
      expect(wbTaps, equals(1));
    });

    testWidgets('ProVideoCinemaHud & VideoCinemaQuickDeck handle FPS/Profile trays, LUT bypass, and Rack Focus', (tester) async {
      bool fpsOpen = false;
      int selectedFps = 24;
      bool lutBypass = false;
      bool hasA = false;
      bool hasB = false;
      int rackTriggers = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setLocalState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    ProVideoCinemaHud(
                      isRecording: true,
                      timecode: '00:01:14:12',
                      resolutionLabel: '4K',
                      fps: selectedFps,
                      fpsOptions: const [24, 25, 30, 60],
                      isFpsSelectorOpen: fpsOpen,
                      shutterAngleLabel: '180°',
                      shutterSpeedLabel: '1/48s',
                      isShutterLocked: true,
                      isLutEnabled: true,
                      lutLabel: 'REC.709 İZLEME',
                      isLutBypassed: lutBypass,
                      audioRmsDb: -14.0,
                      audioPeakDb: -6.0,
                      onTapFps: () => setLocalState(() => fpsOpen = !fpsOpen),
                      onSelectFps: (f) => setLocalState(() {
                        selectedFps = f;
                        fpsOpen = false;
                      }),
                      onToggleLutBypass: () =>
                          setLocalState(() => lutBypass = !lutBypass),
                    ),
                    VideoCinemaQuickDeck(
                      hasPointA: hasA,
                      hasPointB: hasB,
                      onSetPointA: () => setLocalState(() => hasA = true),
                      onSetPointB: () => setLocalState(() => hasB = true),
                      onTriggerRackAB: () => rackTriggers++,
                    ),
                    const SizedBox(
                      width: 120,
                      height: 80,
                      child: VideoRecTallyBorder(isRecording: true),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.textContaining('REC  00:01:14:12'), findsOneWidget);
      expect(find.text('-6dB'), findsOneWidget);

      await tester.tap(find.text('24FPS'));
      await tester.pump();
      expect(fpsOpen, isTrue);

      await tester.tap(find.text('60p'));
      await tester.pump();
      expect(selectedFps, equals(60));

      await tester.tap(find.byIcon(Icons.compare_rounded));
      await tester.pump();
      expect(lutBypass, isTrue);
      expect(find.text('HAM LOG'), findsOneWidget);

      await tester.tap(find.text('A'));
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(hasA, isTrue);
      expect(hasB, isTrue);

      await tester.tap(find.text('A↔B'));
      await tester.pump();
      expect(rackTriggers, equals(1));
    });
  });

  group('ZameraApp DSLR Pro & Cinema Video E2E hardware IPC integration', () {
    testWidgets('PRO mode executes Bumpless PASM (P -> Tv -> Sv -> M) and AEB ±2 Drive capture', (tester) async {
      SharedPreferences.setMockInitialValues({
        'zamera_last_seen_version': AppVersionInfo.currentVersion,
        'zamera_last_seen_build': AppVersionInfo.currentBuildNumber,
        'zamera_has_completed_onboarding': true,
      });
      final vs = await VersionTrackingService.initialize();

      final recordedCalls = <MethodCall>[];
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
              'model': 'DSLR-Ref',
              'device': 'dslr',
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
                  'isoRange': [50, 12800],
                  'exposureTimeRangeNs': [125000, 30000000000],
                  'minimumFocusDistanceDiopters': 10.0,
                  'supportsOis': true,
                  'capabilities': ['RAW', 'MANUAL_SENSOR'],
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
              'iso': 315,
              'exposureTimeNs': 4100000,
              'solvedCctKelvin': 5450,
              'meteredEvDelta': -0.4,
            };
          case 'updateManualControls':
            return true;
          case 'captureBracketedPhotos':
            return <String, dynamic>{
              'bracketCount': 3,
              'evOffsets': [-2.0, 0.0, 2.0],
              'frames': [
                {'cameraId': '2', 'jpegPath': '/tmp/aeb_m2.jpg'},
                {'cameraId': '2', 'jpegPath': '/tmp/aeb_0.jpg'},
                {'cameraId': '2', 'jpegPath': '/tmp/aeb_p2.jpg'},
              ],
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

      // Switch to PRO mode
      await tester.tap(find.text('PRO'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.byType(ProDslrExposureBar), findsOneWidget);

      // Tap Tv (Shutter Priority): Bumpless transfer snaps 4.1ms -> 4,000,000ns (1/250s) with manualShutter=true, manualIso=false
      await tester.tap(find.text('Tv'));
      await tester.pump(const Duration(milliseconds: 80));

      final tvCalls = recordedCalls
          .where((c) => c.method == 'updateManualControls')
          .toList();
      expect(tvCalls, isNotEmpty);
      final tvArgs = tvCalls.last.arguments as Map;
      expect(tvArgs['manualShutter'], isTrue);
      expect(tvArgs['manualIso'], isFalse);
      expect(tvArgs['exposureTimeNs'], equals(4000000));

      // Tap Sv (ISO Priority): manualIso=true, manualShutter=false, ISO snapped 315 -> 320
      await tester.tap(find.text('Sv'));
      await tester.pump(const Duration(milliseconds: 80));
      final svArgs = recordedCalls
          .where((c) => c.method == 'updateManualControls')
          .last
          .arguments as Map;
      expect(svArgs['manualIso'], isTrue);
      expect(svArgs['manualShutter'], isFalse);
      expect(svArgs['iso'], equals(320));

      // Switch Drive mode TEK -> AEB ±2 and tap Shutter -> triggers captureBracketedPhotos
      await tester.tap(find.text('TEK'));
      await tester.pumpAndSettle();
      expect(find.text('AEB ±2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shutter_button_gesture')));
      await tester.pump();
      expect(
        recordedCalls.any((c) => c.method == 'captureBracketedPhotos'),
        isTrue,
      );
    });

    testWidgets('VİDEO mode uses single-IPC telemetry, routes viewfinder focus to video session, and runs live Rack Focus', (tester) async {
      SharedPreferences.setMockInitialValues({
        'zamera_last_seen_version': AppVersionInfo.currentVersion,
        'zamera_last_seen_build': AppVersionInfo.currentBuildNumber,
        'zamera_has_completed_onboarding': true,
      });
      final vs = await VersionTrackingService.initialize();

      final recordedCalls = <MethodCall>[];
      const captureChannel = MethodChannel('com.akarworks.zamera/capture_probe');
      const videoChannel = MethodChannel('com.akarworks.zamera/video_engine');
      Future<Object?> mockHandler(MethodCall call) async {
        recordedCalls.add(call);
        switch (call.method) {
          case 'probeDeviceCapabilities':
            return <String, dynamic>{
              'platform': 'android',
              'manufacturer': 'Test',
              'brand': 'Test',
              'model': 'Cinema-Ref',
              'device': 'cine',
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
                  'tenBitDynamicRangeProfiles': ['HLG10'],
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
          case 'startVideoSession':
            return <String, dynamic>{
              'textureId': -1,
              'previewWidth': 3840,
              'previewHeight': 2160,
              'width': 3840,
              'height': 2160,
              'fps': 24,
              'activeProfile': 'hlg10',
              'isTenBitActive': true,
            };
          case 'getVideoTelemetry':
            return <String, dynamic>{
              'isRecording': false,
              'recordedDurationMs': 0,
              'samplePeakDbfs': -9.0,
              'rmsDbfs': -15.0,
              'activeIso': 200,
              'shutterExposureNs': 20833333,
              'shutterAngleDeg': 180.0,
              'fps': 24,
              'solvedCctKelvin': 5600,
              'liveHistogram64': List<double>.filled(64, 0.25),
            };
          case 'listAudioInputDevices':
            return <Map<String, dynamic>>[
              {'id': 'default', 'name': 'Dahili Mikrofon', 'type': 'BUILTIN_MIC'},
            ];
          case 'updateManualControls':
          case 'setVideoFocusAndMeteringPoint':
          case 'updateVideoControls':
          case 'triggerFocusPull':
          case 'stopPreviewSession':
          case 'stopVideoSession':
            return true;
          case 'startVideoRecording':
            return <String, dynamic>{
              'started': true,
              'videoPath': '/tmp/cine_take1.mp4',
            };
          default:
            return <String, dynamic>{};
        }
      }

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(captureChannel, mockHandler);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(videoChannel, mockHandler);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(captureChannel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(videoChannel, null);
      });

      await tester.pumpWidget(ZameraApp(versionService: vs));
      await tester.pumpAndSettle();

      // Switch to VİDEO mode
      await tester.tap(find.text('VİDEO'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      recordedCalls.clear();
      // Advance telemetry timer (350ms period): must call ONLY getVideoTelemetry (not getLiveTelemetry!)
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        recordedCalls.any((c) => c.method == 'getVideoTelemetry'),
        isTrue,
      );
      expect(
        recordedCalls.any((c) => c.method == 'getLiveTelemetry'),
        isFalse,
      );
      // Standby audio dBFS is live (-9dB)
      expect(find.text('-9dB'), findsOneWidget);

      // Tap center of viewfinder -> routes to setVideoFocusAndMeteringPoint
      await tester.tapAt(const Offset(200, 320));
      await tester.pump();
      expect(
        recordedCalls.any((c) => c.method == 'setVideoFocusAndMeteringPoint'),
        isTrue,
      );
      expect(
        recordedCalls.any((c) => c.method == 'setFocusAndMeteringPoint'),
        isFalse,
      );

      // Lock A, Lock B, and trigger live Rack Focus A↔B on VideoCinemaQuickDeck
      expect(find.byType(VideoCinemaQuickDeck), findsOneWidget);
      await tester.tap(find.text('A'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('B'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('A↔B'));
      await tester.pump(const Duration(seconds: 3));
      expect(
        recordedCalls.any((c) => c.method == 'triggerFocusPull'),
        isTrue,
      );
    });
  });
}
