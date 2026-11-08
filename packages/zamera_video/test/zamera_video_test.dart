import 'package:flutter_test/flutter_test.dart';
import 'package:zamera_video/zamera_video.dart';

void main() {
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
}
