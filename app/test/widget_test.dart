import 'package:flutter_test/flutter_test.dart';
import 'package:zamera_capture/zamera_capture.dart';
import 'package:zamera_video/zamera_video.dart';
import 'package:zamera/main.dart';

void main() {
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

  test('Pro Video module is isolated and defaults to disabled in Phase 0/1', () {
    const info = ZameraVideoIsolationInfo();
    expect(info.isEnabledByFlag, isFalse);
    expect(info.plannedProfiles, isNotEmpty);
  });

  testWidgets('Zamera Studio UI renders all 4 navigation tabs and 24-patch calibrator', (WidgetTester tester) async {
    await tester.pumpWidget(const ZameraApp());
    expect(find.text('ZAMERA'), findsOneWidget);
    expect(find.text('Sanat (Gerçek Renk)'), findsOneWidget);
    expect(find.text('Pro Fotoğraf'), findsOneWidget);
    expect(find.text('Pro Video'), findsOneWidget);
    expect(find.text('Faz 0: Probe'), findsOneWidget);
  });
}
