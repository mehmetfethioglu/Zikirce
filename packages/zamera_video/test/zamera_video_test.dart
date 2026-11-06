import 'package:flutter_test/flutter_test.dart';
import 'package:zamera_video/zamera_video.dart';

void main() {
  test('ZameraVideoIsolationInfo default flag is false', () {
    const info = ZameraVideoIsolationInfo();
    expect(info.isEnabledByFlag, isFalse);
  });
}
