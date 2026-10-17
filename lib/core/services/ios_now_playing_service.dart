import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef RemoteAudioCommandCallback = void Function(String command);

/// Manages native iOS AVAudioSession(.playback), MPNowPlayingInfoCenter (Lock Screen
/// & Dynamic Island media controls), MPRemoteCommandCenter events, and background
/// transition task leases.
class IosNowPlayingService {
  static const MethodChannel _channel =
      MethodChannel('com.akarworks.zikirce/audio_background');

  static bool _initialized = false;
  static RemoteAudioCommandCallback? _commandCallback;

  static void _ensureInitialized() {
    if (_initialized || kIsWeb || !Platform.isIOS) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onRemoteCommand') {
        final cmd = call.arguments as String?;
        if (cmd != null) {
          _commandCallback?.call(cmd);
        }
      }
    });
  }

  static void setRemoteCommandCallback(RemoteAudioCommandCallback? callback) {
    if (kIsWeb || !Platform.isIOS) return;
    _ensureInitialized();
    _commandCallback = callback;
  }

  static Future<void> activateSession() async {
    if (kIsWeb || !Platform.isIOS) return;
    _ensureInitialized();
    try {
      await _channel.invokeMethod('activateSession');
    } catch (e) {
      debugPrint('[IosNowPlayingService] activateSession warning: $e');
    }
  }

  static Future<void> updateNowPlaying({
    required String title,
    required String subtitle,
    String album = 'Zikirce • Kur\'an-ı Kerim Tilaveti',
    required bool isPlaying,
    int durationMs = 0,
    int positionMs = 0,
    double speed = 1.0,
  }) async {
    if (kIsWeb || !Platform.isIOS) return;
    _ensureInitialized();
    try {
      await _channel.invokeMethod('updateNowPlaying', {
        'title': title,
        'subtitle': subtitle,
        'album': album,
        'isPlaying': isPlaying,
        'durationMs': durationMs.toDouble(),
        'positionMs': positionMs.toDouble(),
        'speed': speed,
      });
    } catch (e) {
      debugPrint('[IosNowPlayingService] updateNowPlaying warning: $e');
    }
  }

  static Future<void> beginTransitionTask() async {
    if (kIsWeb || !Platform.isIOS) return;
    _ensureInitialized();
    try {
      await _channel.invokeMethod('beginTransitionTask');
    } catch (_) {}
  }

  static Future<void> clearNowPlaying() async {
    if (kIsWeb || !Platform.isIOS) return;
    _ensureInitialized();
    try {
      await _channel.invokeMethod('clearNowPlaying');
    } catch (_) {}
  }
}
