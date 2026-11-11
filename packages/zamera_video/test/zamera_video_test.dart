import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamera_video/zamera_video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WP-3.2: 180-degree shutter exposure math and audio dBFS', () {
    expect(ZameraCinemaMath.shutterExposureNsFromAngle(180.0, 24), 20833333);
    expect(ZameraCinemaMath.shutterExposureNsFromAngle(180.0, 25), 20000000);
    expect(ZameraCinemaMath.shutterExposureNsFromAngle(180.0, 30), 16666667);
    expect(ZameraCinemaMath.shutterExposureNsFromAngle(180.0, 60), 8333333);
    expect(ZameraCinemaMath.formatShutterFromAngle(180.0, 25), '1/50s');

    final fullScale =
        ZameraCinemaMath.computeAudioPeakAndRmsDbfs(const [1.0, -1.0]);
    expect(fullScale.peakDbfs, closeTo(0.0, 1e-3));
    expect(fullScale.rmsDbfs, closeTo(0.0, 1e-3));

    final halfScale =
        ZameraCinemaMath.computeAudioPeakAndRmsDbfs(const [0.5, -0.5]);
    expect(halfScale.peakDbfs, closeTo(-6.0206, 0.02));
  });

  test('WP-3.3: 3D .cube LUT parser identity accuracy <= 1/1023 and error handling', () {
    final buf = StringBuffer()
      ..writeln('TITLE "Zamera Identity 17"')
      ..writeln('DOMAIN_MIN 0.0 0.0 0.0')
      ..writeln('DOMAIN_MAX 1.0 1.0 1.0')
      ..writeln('LUT_3D_SIZE 17');
    for (int b = 0; b < 17; b++) {
      for (int g = 0; g < 17; g++) {
        for (int r = 0; r < 17; r++) {
          buf.writeln(
            '${(r / 16.0).toStringAsFixed(6)} ${(g / 16.0).toStringAsFixed(6)} ${(b / 16.0).toStringAsFixed(6)}',
          );
        }
      }
    }
    final lut = ZameraCubeLut3D.parse(buf.toString());
    expect(lut.size, 17);
    final sampled = lut.sampleTrilinear(const [0.24, 0.58, 0.81]);
    expect(sampled[0], closeTo(0.24, 1.0 / 1023.0));
    expect(sampled[1], closeTo(0.58, 1.0 / 1023.0));
    expect(sampled[2], closeTo(0.81, 1.0 / 1023.0));

    expect(
      () => ZameraCubeLut3D.parse('LUT_3D_SIZE 17\n0.0 0.0 0.0\n'),
      throwsFormatException,
    );
  });

  test('WP-3.0: CameraOwnershipCoordinator serializes photo and video transitions', () async {
    final coordinator = CameraOwnershipCoordinator();
    final events = <String>[];

    await coordinator.switchToVideo(
      stopPhotoSession: () async => events.add('stopPhoto'),
      startVideoSession: () async => events.add('startVideo'),
    );
    expect(coordinator.currentOwner, CameraOwnerMode.video);

    await coordinator.switchToPhoto(
      stopVideoAndFinalizeIfRecording: () async => events.add('stopVideo'),
      startPhotoSession: () async => events.add('startPhoto'),
    );
    expect(coordinator.currentOwner, CameraOwnerMode.photo);
    expect(events, ['stopPhoto', 'startVideo', 'stopVideo', 'startPhoto']);
  });

  test('Platform profile OCP registry, standard shutter angles, telemetry & video focus/lock channel contracts', () async {
    expect(
      ZameraVideoProfile.supportedForPlatform(isIOS: true),
      equals(const [
        ZameraVideoProfile.universalRec709Locked,
        ZameraVideoProfile.iosAppleLogHevc10Bit,
        ZameraVideoProfile.iosAppleLogProRes422Hq,
      ]),
    );
    expect(
      ZameraVideoProfile.supportedForPlatform(isIOS: false),
      equals(const [
        ZameraVideoProfile.universalRec709Locked,
        ZameraVideoProfile.androidHlg10Hevc10Bit,
        ZameraVideoProfile.zameraFlatSdr,
      ]),
    );
    expect(
      ZameraCinemaMath.standardShutterAngles,
      equals(const <double>[45.0, 90.0, 144.0, 172.8, 180.0, 270.0, 360.0]),
    );

    const defaults = ZameraVideoTelemetry();
    expect(defaults.liveZebraGrid16x12, isEmpty);
    expect(defaults.livePeakingGrid16x12, isEmpty);
    expect(defaults.liveFocusPeakingScore, 0.0);
    expect(defaults.solvedCctKelvin, 5500);
    expect(defaults.aeAfLocked, isFalse);
    expect(defaults.meteredEvDelta, 0.0);

    final parsed = ZameraVideoTelemetry.fromMap({
      'liveZebraGrid16x12': List<double>.filled(192, 0.25),
      'livePeakingGrid16x12': List<double>.filled(192, 0.75),
      'liveFocusPeakingScore': 0.84,
      'solvedCctKelvin': 4300,
      'aeAfLocked': true,
      'meteredEvDelta': -0.65,
    });
    expect(parsed.liveZebraGrid16x12.length, 192);
    expect(parsed.liveZebraGrid16x12.first, closeTo(0.25, 1e-6));
    expect(parsed.livePeakingGrid16x12.length, 192);
    expect(parsed.livePeakingGrid16x12.first, closeTo(0.75, 1e-6));
    expect(parsed.liveFocusPeakingScore, closeTo(0.84, 1e-6));
    expect(parsed.solvedCctKelvin, 4300);
    expect(parsed.aeAfLocked, isTrue);
    expect(parsed.meteredEvDelta, closeTo(-0.65, 1e-6));

    const channel = MethodChannel('com.akarworks.zamera/video_engine');
    String? lastMethod;
    Map<dynamic, dynamic>? lastArgs;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      lastMethod = call.method;
      lastArgs = call.arguments as Map<dynamic, dynamic>?;
      if (call.method == 'updateVideoControls' ||
          call.method == 'setVideoFocusAndMeteringPoint') {
        return true;
      }
      return null;
    });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final ctrlOk = await ZameraVideo.updateVideoControls(
      fps: 24,
      shutterAngleDeg: 172.8,
      lockShutterAngle: true,
      manualIso: false,
      iso: 100,
      evCompensation: 0.0,
      manualFocus: false,
      focusDistance: 0.0,
      manualWb: false,
      kelvin: 5500,
      tint: 0.0,
      zoomRatio: 1.0,
      profile: ZameraVideoProfile.universalRec709Locked,
      aeAfLocked: true,
    );
    expect(ctrlOk, isTrue);
    expect(lastMethod, 'updateVideoControls');
    expect(lastArgs?['aeAfLocked'], isTrue);
    expect(lastArgs?['shutterAngleDeg'], 172.8);

    final focusDefault = await ZameraVideo.setVideoFocusAndMeteringPoint(
      x: 0.3,
      y: 0.7,
    );
    expect(focusDefault, isTrue);
    expect(lastMethod, 'setVideoFocusAndMeteringPoint');
    expect(lastArgs, equals({'x': 0.3, 'y': 0.7, 'lockAeAf': false}));

    final focusLocked = await ZameraVideo.setVideoFocusAndMeteringPoint(
      x: 0.6,
      y: 0.4,
      lockAeAf: true,
    );
    expect(focusLocked, isTrue);
    expect(lastArgs, equals({'x': 0.6, 'y': 0.4, 'lockAeAf': true}));
  });
}
