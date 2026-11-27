import 'pdks_models.dart';

/// Mobil konum okuma sonucu (GPS sensör veya masaüstü fallback).
class MobileLocationReading {
  final double latitude;
  final double longitude;
  final bool isMocked;
  final double accuracyMeters;
  final bool isSimulatedFallback;

  const MobileLocationReading({
    required this.latitude,
    required this.longitude,
    this.isMocked = false,
    this.accuracyMeters = 5.0,
    this.isSimulatedFallback = false,
  });
}

/// DIP Arayüzü: Mobil GPS/Geofence konum sağlayıcı sözleşmesi.
abstract interface class MobileLocationGateway {
  Future<MobileLocationReading> getCurrentLocation({
    required Branch fallbackBranch,
  });
}

/// Masaüstü / sensörsüz ortamlarda şube koordinatını kullanan varsayılan adaptör.
class BranchFallbackLocationGateway implements MobileLocationGateway {
  const BranchFallbackLocationGateway();

  @override
  Future<MobileLocationReading> getCurrentLocation({
    required Branch fallbackBranch,
  }) async {
    return MobileLocationReading(
      latitude: fallbackBranch.latitude,
      longitude: fallbackBranch.longitude,
      isMocked: false,
      accuracyMeters: 10.0,
      isSimulatedFallback: true,
    );
  }
}
