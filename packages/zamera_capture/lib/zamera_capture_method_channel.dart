import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'zamera_capture_platform_interface.dart';

/// An implementation of [ZameraCapturePlatform] that uses method channels.
class MethodChannelZameraCapture extends ZameraCapturePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('zamera_capture');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
