# Kilerce: Barkod, Dolap & Tarif (`organicscore`)

Kilerce; barkod tarama, içindekiler OCR analizi, Tarım ve Orman Bakanlığı Taklit & Tağşiş sorgulama, etik/boykot kontrolü, akıllı buzdolabı/kiler/dondurucu envanteri ve 100 bölgesel Türk ev yemeği tarif motorunu tek çatı altında birleştiren Flutter uygulamasıdır.

## Mimari & Özellikler

- **Akıllı Kiler & İsraf Kurtarma (`lib/features/kiler/`):**
  - Buzdolabı, Kiler & Dondurucu stok takibi, SKT takibi ve günlük yerel Android SKT bildirimleri (`ExpiryReminderService`).
  - Market fişi ML Kit OCR ayrıştırma (`ReceiptOcrService`) ve 6 barkodsuz pazar/kasap kanalı (`NaturalPantryInputParser`).
- **Yemek Listesi & Tarif Motoru (`lib/features/recipes/`):**
  - 7 bölgeden 100 Türk ev yemeği kataloğu, kiler uyumluluk skorlaması, porsiyon ölçekleme ve haftalık yemek planlayıcı (Riverpod `MealModuleNotifier`).
- **Gıda Güvenliği & Puanlama (`lib/features/scoring/`, `lib/features/taklit_tagsis/`, `lib/features/network/`):**
  - Çevrimdışı SQLite v16 veritabanı (indeksli), E-kodu & Helal duyarlılık motoru (`OrganicScoreCalculator`), Open Food Facts canlı doğrulama ve Cloudflare Edge Worker proxy (`edge_worker/worker.js`).
- **Yedekleme & Çoklu Dil (`lib/core/services/kilerce_backup_service.dart`, `lib/l10n/`):**
  - Profil + kiler + alışveriş listesi + yemek planı + özel tarifler + aile profillerini kapsayan v2.0 JSON / Google Drive AppData yedeği.
  - `flutter_localizations` + `l10n.yaml` ile TR / EN çoklu dil desteği.

## Geliştirme, Test & Derleme

```powershell
flutter pub get
flutter gen-l10n
flutter analyze --no-pub
flutter test --no-pub
```

### Release APK & Canlı AdMob Yapılandırması

Kapalı test güvenliği için varsayılan olarak test reklamları aktiftir (`USE_TEST_ADS=true`). Canlı üretim derlemelerinde format bazlı ayrı Ad Unit ID'ler `--dart-define` ile geçilir:

```powershell
flutter build apk --release `
  --dart-define=USE_TEST_ADS=false `
  --dart-define=ADMOB_ANDROID_BANNER_ID=ca-app-pub-.../... `
  --dart-define=ADMOB_ANDROID_REWARDED_ID=ca-app-pub-.../... `
  --dart-define=ADMOB_ANDROID_INTERSTITIAL_ID=ca-app-pub-.../...
```

### Google Sign-In (Android & iOS) Yapılandırması

- **Android (`com.akarworks.organicscore`):** Google Cloud Console (`organicscore`) projesinde Debug, Upload ve Google Play App Signing SHA-1 sertifikaları için ayrı Android OAuth 2.0 Client ID'leri ve **Google Drive API** (`drive.appdata`) etkinleştirilmiştir.
- **iOS (`com.akarworks.kilerce`):** `ios/Runner/Info.plist` içinde `GIDClientID` ve ters URL şeması (`CFBundleURLTypes`) tanımlıdır; `ios/Runner/SceneDelegate.swift` içinde `UIScene` OAuth redirect callback'i `GIDSignIn.sharedInstance.handle(_:)` ile yönlendirilir.
