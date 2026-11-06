import 'package:flutter_test/flutter_test.dart';
import 'package:zamera_capture/zamera_capture.dart';

void main() {
  test('Sharma 2005 CIEDE2000 reference pairs pass', () {
    final d = ZameraCapture.computeCiede2000(
      const [50.0000, 2.6772, -79.7751],
      const [50.0000, 0.0000, -82.7485],
    );
    expect((d - 2.0425).abs(), lessThan(1e-3));
  });
}
