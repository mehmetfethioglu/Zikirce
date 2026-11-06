import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zamera_capture_method_channel.dart';

abstract class ZameraCapturePlatform extends PlatformInterface {
  /// Constructs a ZameraCapturePlatform.
  ZameraCapturePlatform() : super(token: _token);

  static final Object _token = Object();

  static ZameraCapturePlatform _instance = MethodChannelZameraCapture();

  /// The default instance of [ZameraCapturePlatform] to use.
  ///
  /// Defaults to [MethodChannelZameraCapture].
  static ZameraCapturePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ZameraCapturePlatform] when
  /// they register themselves.
  static set instance(ZameraCapturePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
