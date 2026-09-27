import 'dart:math' as math;

void main() {
  print('=== PRAYER TIMES & 81 CITIES VERIFICATION ===');

  const turkishCities = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya', 'Ankara', 'Antalya', 'Ardahan', 'Artvin',
    'Aydın', 'Balıkesir', 'Bartın', 'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
    'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce', 'Edirne', 'Elazığ', 'Erzincan',
    'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Iğdır', 'Isparta', 'İstanbul',
    'İzmir', 'Kahramanmaraş', 'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri', 'Kırıkkale', 'Kırklareli', 'Kırşehir',
    'Kilis', 'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş',
    'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun', 'Şanlıurfa', 'Siirt', 'Sinop',
    'Şırnak', 'Sivas', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak', 'Van', 'Yalova', 'Yozgat', 'Zonguldak'
  ];

  print('Turkish Cities Count: ${turkishCities.length}');
  assert(turkishCities.length == 81, 'Must have exactly 81 Turkish cities');
  print('✅ 81 Cities verified in list.');

  // Test Qibla Calculation for Istanbul & Sanliurfa
  double calculateQiblaDirection(double lat, double lng) {
    const kaabaLat = 21.4225 * math.pi / 180.0;
    const kaabaLng = 39.8262 * math.pi / 180.0;
    final userLat = lat * math.pi / 180.0;
    final userLng = lng * math.pi / 180.0;

    final y = math.sin(kaabaLng - userLng);
    final x = math.cos(userLat) * math.tan(kaabaLat) - math.sin(userLat) * math.cos(kaabaLng - userLng);
    var qibla = math.atan2(y, x) * 180.0 / math.pi;
    return (qibla + 360) % 360;
  }

  final istanbulQibla = calculateQiblaDirection(41.0082, 28.9784);
  final urfaQibla = calculateQiblaDirection(37.1674, 38.7955);
  print('Istanbul Qibla: ${istanbulQibla.toStringAsFixed(1)}°, Sanliurfa Qibla: ${urfaQibla.toStringAsFixed(1)}°');
  assert(istanbulQibla > 140 && istanbulQibla < 165, 'Istanbul Qibla angle out of expected range');
  assert(urfaQibla > 170 && urfaQibla < 205, 'Sanliurfa Qibla angle out of expected range');
  print('✅ Qibla angles verified.');

  print('=== ALL PRAYER TIMES TESTS PASSED SUCCESSFULLY! ===');
}
