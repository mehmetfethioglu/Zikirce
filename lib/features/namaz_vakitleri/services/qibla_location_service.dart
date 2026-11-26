import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/qibla_models.dart';

/// Tek seferlik GPS konum çözümleme sonucu.
@immutable
class QiblaLocationResult {
  final QiblaLocationStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;

  const QiblaLocationResult({
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
  });

  bool get hasCoordinates =>
      status == QiblaLocationStatus.gpsActive &&
      latitude != null &&
      longitude != null;
}

/// Kıble için yalnızca kullanım anı konum sağlayıcısı (DIP: testlerde sahtelenebilir).
abstract interface class QiblaLocationService {
  Future<QiblaLocationResult> getCurrentLocation({bool requestPermission = true});
  Future<bool> openLocationSettings();
}

/// iOS (CLLocationManager) ve Android (LocationManager) native köprüsü üzerinden GPS konumu alır.
class NativeQiblaLocationService implements QiblaLocationService {
  static const MethodChannel _channel =
      MethodChannel('com.akarworks.zikirce/qibla_native');

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<QiblaLocationResult> getCurrentLocation({
    bool requestPermission = true,
  }) async {
    if (!_isMobilePlatform) {
      return const QiblaLocationResult(status: QiblaLocationStatus.unavailable);
    }

    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'getCurrentLocation',
        <String, Object?>{'requestPermission': requestPermission},
      );
      if (raw == null) {
        return const QiblaLocationResult(status: QiblaLocationStatus.unavailable);
      }

      final statusStr = raw['status']?.toString() ?? 'unavailable';
      final lat = (raw['latitude'] as num?)?.toDouble();
      final lng = (raw['longitude'] as num?)?.toDouble();
      final acc = (raw['accuracyMeters'] as num?)?.toDouble();

      switch (statusStr) {
        case 'granted':
          if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
            return QiblaLocationResult(
              status: QiblaLocationStatus.gpsActive,
              latitude: lat,
              longitude: lng,
              accuracyMeters: (acc != null && acc.isFinite) ? acc : null,
            );
          }
          return const QiblaLocationResult(
            status: QiblaLocationStatus.unavailable,
          );
        case 'denied':
          return const QiblaLocationResult(
            status: QiblaLocationStatus.permissionDenied,
          );
        case 'deniedForever':
          return const QiblaLocationResult(
            status: QiblaLocationStatus.permissionDeniedForever,
          );
        case 'serviceDisabled':
          return const QiblaLocationResult(
            status: QiblaLocationStatus.serviceDisabled,
          );
        default:
          return const QiblaLocationResult(
            status: QiblaLocationStatus.unavailable,
          );
      }
    } on MissingPluginException catch (e) {
      debugPrint('[QiblaLocation] Native plugin unavailable: $e');
      return const QiblaLocationResult(status: QiblaLocationStatus.unavailable);
    } on PlatformException catch (e) {
      debugPrint('[QiblaLocation] Platform error: ${e.code} ${e.message}');
      return const QiblaLocationResult(status: QiblaLocationStatus.unavailable);
    } catch (e) {
      debugPrint('[QiblaLocation] Unexpected location error: $e');
      return const QiblaLocationResult(status: QiblaLocationStatus.unavailable);
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    if (!_isMobilePlatform) return false;
    try {
      final opened = await _channel.invokeMethod<bool>('openLocationSettings');
      return opened ?? false;
    } on MissingPluginException catch (e) {
      debugPrint('[QiblaLocation] openLocationSettings unavailable: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('[QiblaLocation] openLocationSettings error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[QiblaLocation] openLocationSettings unexpected error: $e');
      return false;
    }
  }
}
