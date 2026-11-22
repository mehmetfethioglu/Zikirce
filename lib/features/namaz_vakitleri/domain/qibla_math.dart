import 'dart:math' as math;

/// Saf kıble, eğim düzeltmeli pusula, manyetik sapma ve güneş astronomisi matematiği.
///
/// Dış paket veya Flutter UI bağımlılığı içermez; birim testleriyle doğrudan doğrulanır.
class QiblaMath {
  QiblaMath._();

  static const double kaabaLat = 21.422487;
  static const double kaabaLng = 39.826206;

  /// Kıbleye kilitlenme (hysteresis giriş) ve kilitten çıkma (çıkış) eşikleri.
  static const double alignmentEnterDeg = 4.0;
  static const double alignmentExitDeg = 9.0;
  static const double approachingThresholdDeg = 25.0;

  /// Telefonun yere paralel sayılacağı eğim sınırları (derece).
  static const double maxFlatTiltDeg = 22.0;
  static const double maxLockedTiltDeg = 32.0;

  /// Doğal Dünya manyetik alanı tipik aralığı (µT). Dışı parazit/kalibrasyon uyarısı üretir.
  static const double minValidMagneticFieldUt = 20.0;
  static const double maxValidMagneticFieldUt = 75.0;

  static const double _earthRadiusKm = 6371.0088;
  static const double _degToRad = math.pi / 180.0;
  static const double _radToDeg = 180.0 / math.pi;

  /// WMM 2025-2026 tabanlı küresel manyetik sapma (declination, derece) tablosu.
  ///
  /// Satırlar enlem: -75° .. +75° (15° adım, 11 satır).
  /// Sütunlar boylam: -180° .. +180° (15° adım, 25 sütun).
  /// Pozitif değer Doğu sapmasıdır: gerçekKuzey = manyetikKuzey + sapma.
  static const List<List<double>> _wmmDeclinationGrid = <List<double>>[
    // -75° (Antarktika)
    <double>[
      24.0, 29.0, 35.0, 41.0, 44.0, 39.0, 22.0, -3.0, -24.0, -36.0, -40.0, -39.0, -35.0,
      -34.0, -38.0, -47.0, -56.0, -61.0, -55.0, -38.0, -14.0, 6.0, 17.0, 21.0, 24.0,
    ],
    // -60°
    <double>[
      17.0, 21.0, 25.0, 28.0, 27.0, 21.0, 11.0, -2.0, -14.0, -23.0, -28.0, -30.0, -30.0,
      -31.0, -34.0, -40.0, -46.0, -47.0, -40.0, -24.0, -5.0, 7.0, 12.0, 15.0, 17.0,
    ],
    // -45°
    <double>[
      14.5, 16.5, 18.0, 18.5, 16.5, 12.0, 5.0, -3.5, -12.0, -18.5, -22.5, -24.5, -25.0,
      -26.0, -27.5, -30.5, -31.5, -26.5, -14.5, -1.0, 8.0, 11.5, 12.5, 13.5, 14.5,
    ],
    // -30°
    <double>[
      11.5, 12.5, 13.5, 13.5, 11.0, 6.5, -0.5, -8.5, -16.0, -20.5, -22.0, -21.0, -19.0,
      -17.5, -16.5, -15.5, -13.0, -8.0, -2.0, 3.0, 6.5, 8.5, 9.5, 10.5, 11.5,
    ],
    // -15°
    <double>[
      9.5, 10.0, 10.0, 9.5, 7.5, 3.5, -2.5, -10.5, -17.5, -21.0, -19.5, -14.5, -9.5,
      -5.5, -3.0, -2.0, -1.5, -0.5, 1.0, 3.0, 5.0, 6.5, 7.5, 8.5, 9.5,
    ],
    // 0° (Ekvator)
    <double>[
      8.5, 8.5, 8.5, 8.0, 6.5, 3.5, -2.5, -10.0, -16.5, -17.5, -12.5, -6.0, -1.5,
      1.0, 2.0, 2.0, 1.5, 0.5, 0.5, 1.5, 3.0, 5.0, 6.5, 7.5, 8.5,
    ],
    // +15°
    <double>[
      8.5, 8.5, 9.0, 9.0, 8.0, 5.5, -0.5, -7.0, -13.5, -15.0, -9.5, -3.5, 0.5,
      2.5, 3.2, 2.9, 2.0, 0.5, -0.8, -1.2, 0.0, 2.5, 5.0, 7.0, 8.5,
    ],
    // +30°
    <double>[
      9.5, 10.0, 11.0, 11.5, 10.5, 7.5, -1.8, -10.2, -14.5, -14.0, -9.5, -3.5, 1.6,
      3.8, 5.1, 4.6, 3.0, 0.5, -2.5, -5.0, -4.5, -0.5, 4.0, 7.0, 9.5,
    ],
    // +45°
    <double>[
      9.5, 11.5, 13.5, 14.5, 13.5, 8.5, -2.4, -12.8, -15.7, -15.0, -9.0, -3.0, 1.3,
      4.5, 7.1, 9.0, 8.0, 3.5, -3.0, -8.5, -9.5, -5.0, 1.0, 5.5, 9.5,
    ],
    // +60°
    <double>[
      8.5, 12.5, 17.5, 20.5, 19.0, 9.5, -4.5, -14.5, -17.5, -16.5, -11.5, -4.5, 1.5,
      6.5, 11.5, 17.5, 18.0, 9.5, -3.5, -11.5, -12.5, -8.5, -2.0, 3.5, 8.5,
    ],
    // +75°
    <double>[
      2.0, 11.0, 22.0, 30.0, 26.0, 5.0, -21.0, -32.0, -28.0, -21.0, -14.0, -5.0, 4.0,
      12.0, 21.0, 31.0, 32.0, 14.0, -11.0, -19.0, -16.0, -11.0, -5.0, -1.0, 2.0,
    ],
  ];

  /// Kullanıcı konumundan Kâbe'ye başlangıç azimut açısını [0, 360) derece olarak hesaplar.
  static double calculateQiblaBearing(double lat, double lng) {
    const kaabaLatRad = kaabaLat * _degToRad;
    const kaabaLngRad = kaabaLng * _degToRad;
    final userLatRad = lat * _degToRad;
    final userLngRad = lng * _degToRad;
    final deltaLng = kaabaLngRad - userLngRad;

    final y = math.sin(deltaLng) * math.cos(kaabaLatRad);
    final x = math.cos(userLatRad) * math.sin(kaabaLatRad) -
        math.sin(userLatRad) * math.cos(kaabaLatRad) * math.cos(deltaLng);

    final bearing = math.atan2(y, x) * _radToDeg;
    return normalizeAngleDeg(bearing);
  }

  /// Haversine formülü ile Kâbe-i Muazzama'ya kuş uçuşu mesafeyi (km) döndürür.
  static double calculateDistanceToKaabaKm(double lat, double lng) {
    final dLat = (kaabaLat - lat) * _degToRad;
    final dLng = (kaabaLng - lng) * _degToRad;
    final lat1 = lat * _degToRad;
    const lat2 = kaabaLat * _degToRad;

    final sinHalfLat = math.sin(dLat / 2.0);
    final sinHalfLng = math.sin(dLng / 2.0);
    final a = sinHalfLat * sinHalfLat +
        math.cos(lat1) * math.cos(lat2) * sinHalfLng * sinHalfLng;
    final c = 2.0 * math.atan2(math.sqrt(a), math.sqrt((1.0 - a).clamp(0.0, 1.0)));
    return _earthRadiusKm * c;
  }

  /// Çift doğrusal (bilinear) enterpolasyon ile yaklaşık manyetik sapma açısını (°) döndürür.
  static double estimateMagneticDeclination(double lat, double lng) {
    final clampedLat = lat.clamp(-75.0, 75.0);
    var normLng = ((lng + 180.0) % 360.0 + 360.0) % 360.0 - 180.0;
    if (normLng == -180.0 && lng > 0) normLng = 180.0;

    final latPos = (clampedLat + 75.0) / 15.0;
    final lngPos = (normLng + 180.0) / 15.0;

    final r0 = latPos.floor().clamp(0, 9);
    final r1 = (r0 + 1).clamp(0, 10);
    final c0 = lngPos.floor().clamp(0, 23);
    final c1 = (c0 + 1).clamp(0, 24);

    final ty = (latPos - r0).clamp(0.0, 1.0);
    final tx = (lngPos - c0).clamp(0.0, 1.0);

    final v00 = _wmmDeclinationGrid[r0][c0];
    final v01 = _wmmDeclinationGrid[r0][c1];
    final v10 = _wmmDeclinationGrid[r1][c0];
    final v11 = _wmmDeclinationGrid[r1][c1];

    final top = v00 * (1.0 - tx) + v01 * tx;
    final bottom = v10 * (1.0 - tx) + v11 * tx;
    return top * (1.0 - ty) + bottom * ty;
  }

  /// İvmeölçer ve manyetometre verilerinden 3B eğim düzeltmeli manyetik yönü [0, 360) hesaplar.
  ///
  /// Cihazın üst kenarının (+Y) Manyetik Kuzey'e göre saat yönündeki açısını döndürür.
  /// Vektör normu yetersizse `null` döner.
  static double? calculateTiltCompensatedHeading({
    required double ax,
    required double ay,
    required double az,
    required double mx,
    required double my,
    required double mz,
  }) {
    final gNorm = math.sqrt(ax * ax + ay * ay + az * az);
    if (gNorm < 0.1) return null;

    final gx = ax / gNorm;
    final gy = ay / gNorm;
    final gz = az / gNorm;

    // Doğu vektörü H = M × g
    final hxRaw = my * gz - mz * gy;
    final hyRaw = mz * gx - mx * gz;
    final hzRaw = mx * gy - my * gx;
    final hNorm = math.sqrt(hxRaw * hxRaw + hyRaw * hyRaw + hzRaw * hzRaw);
    if (hNorm < 0.1) return null;

    final hx = hxRaw / hNorm;
    final hy = hyRaw / hNorm;
    final hz = hzRaw / hNorm;

    // Kuzey vektörü N = g × h
    final ny = gz * hx - gx * hz;

    final headingDeg = math.atan2(hy, ny) * _radToDeg;
    return normalizeAngleDeg(headingDeg);
  }

  /// İvmeölçer vektöründen telefonun yatay düzlemden toplam eğimini ve pitch/roll açılarını hesaplar.
  static ({double tiltDeg, double pitchDeg, double rollDeg}) calculateTiltDegrees(
    double ax,
    double ay,
    double az,
  ) {
    final norm = math.sqrt(ax * ax + ay * ay + az * az);
    if (norm < 0.1) {
      return (tiltDeg: 0.0, pitchDeg: 0.0, rollDeg: 0.0);
    }

    final cosTilt = (az / norm).clamp(-1.0, 1.0);
    final tiltDeg = math.acos(cosTilt) * _radToDeg;
    final safeAz = az.abs() < 1e-4 ? (az.isNegative ? -1e-4 : 1e-4) : az;
    final pitchDeg = math.atan2(ay, safeAz) * _radToDeg;
    final rollDeg = math.atan2(ax, safeAz) * _radToDeg;
    return (tiltDeg: tiltDeg, pitchDeg: pitchDeg, rollDeg: rollDeg);
  }

  /// Açıyı [0, 360) aralığına normalize eder.
  static double normalizeAngleDeg(double deg) {
    final wrapped = (deg % 360.0 + 360.0) % 360.0;
    return wrapped >= 360.0 || wrapped == -0.0 ? 0.0 : wrapped;
  }

  /// `fromDeg` açsından `toDeg` açısına en kısa işaretli dönüşü (-180, 180] döndürür.
  ///
  /// Pozitif değer saat yönünde (sağa), negatif değer saat yönünün tersine (sola) dönüştür.
  static double shortestAngleDelta(double fromDeg, double toDeg) {
    var diff = (toDeg - fromDeg) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff <= -180.0) diff += 360.0;
    return diff;
  }

  /// 359° ↔ 0° sınırından atlamadan dairesel açı yumuşatması uygular.
  static double smoothAngleDeg(double currentDeg, double targetDeg, double alpha) {
    final clampedAlpha = alpha.clamp(0.0, 1.0);
    final delta = shortestAngleDelta(currentDeg, targetDeg);
    return normalizeAngleDeg(currentDeg + delta * clampedAlpha);
  }

  /// Çevrimdışı NOAA güneş pozisyonu hesabı: Güneş azimutu [0, 360) ve ufuk yüksekliği (°).
  static ({double azimuthDeg, double elevationDeg}) calculateSolarPosition(
    double lat,
    double lng,
    DateTime utcTime,
  ) {
    final utc = utcTime.toUtc();
    final jd = utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
    final n = jd - 2451545.0;

    final meanLongDeg = normalizeAngleDeg(280.460 + 0.9856474 * n);
    final meanAnomDeg = normalizeAngleDeg(357.528 + 0.9856003 * n);
    final meanAnomRad = meanAnomDeg * _degToRad;

    final eclipticLongDeg = meanLongDeg +
        1.915 * math.sin(meanAnomRad) +
        0.020 * math.sin(2.0 * meanAnomRad);
    final eclipticLongRad = eclipticLongDeg * _degToRad;

    final obliquityRad = (23.439 - 0.0000004 * n) * _degToRad;

    final sinDecl = math.sin(obliquityRad) * math.sin(eclipticLongRad);
    final declRad = math.asin(sinDecl.clamp(-1.0, 1.0));

    final raRad = math.atan2(
      math.cos(obliquityRad) * math.sin(eclipticLongRad),
      math.cos(eclipticLongRad),
    );
    final raDeg = normalizeAngleDeg(raRad * _radToDeg);

    final gmstDeg =
        normalizeAngleDeg(280.46061837 + 360.98564736629 * (jd - 2451545.0));
    final hourAngleRad = (gmstDeg + lng - raDeg) * _degToRad;

    final latRad = lat * _degToRad;
    final sinAlt = math.sin(latRad) * math.sin(declRad) +
        math.cos(latRad) * math.cos(declRad) * math.cos(hourAngleRad);
    final elevationDeg = math.asin(sinAlt.clamp(-1.0, 1.0)) * _radToDeg;

    final y = -math.cos(declRad) * math.sin(hourAngleRad);
    final x = math.cos(latRad) * math.sin(declRad) -
        math.sin(latRad) * math.cos(declRad) * math.cos(hourAngleRad);
    final azimuthDeg = normalizeAngleDeg(math.atan2(y, x) * _radToDeg);

    return (azimuthDeg: azimuthDeg, elevationDeg: elevationDeg);
  }

  /// Verilen pusula açısı için 8'li ana/ara yön kısaltmasını döndürür.
  static String cardinalDirectionLabel(double deg, {required bool isTurkish}) {
    const trLabels = <String>['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
    const enLabels = <String>['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final normalized = normalizeAngleDeg(deg);
    final index = ((normalized + 22.5) / 45.0).floor() % 8;
    return isTurkish ? trLabels[index] : enLabels[index];
  }
}
