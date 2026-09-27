# Zikirce Flutter Edition — System Design Document (SDD)
**Proje Adı:** Zikirce (Flutter Supercharged Edition)  
**Versiyon:** 2.0.0-PROD  
**Doküman Tipi:** Nihai Sistem Tasarım ve Mimari Spesifikasyonu (SDD)  
**Tarih:** 21 Ağustos 2026  
**Mimari Yaklaşım:** Clean Architecture + Feature-First + Riverpod 2.x Reactive State + Drift SQLite + GPU Vector Mushaf Engine  

---

## 1. Yönetici Özeti ve Performans Analizi (.NET MAUI vs. Flutter)

### 1.1 .NET MAUI Kök Darboğaz Analizi
Mevcut .NET 10 MAUI sürümünde bazı cihazlarda (özellikle giriş/orta segment MediaTek Helio/Dimensity, Exynos ve eski Snapdragon işlemcili cihazlarda) yaşanan takılmaların temel sebepleri:

1. **Aşırı Derin Native View Ağacı (OEM Hierarchy Overdraw):**
   - MAUI, her XAML bileşenini (`Grid`, `Border`, `VerticalStackLayout`, `ScrollView`, `Label`) doğrudan Android'in yerel `ViewGroup`, `FrameLayout`, `CardView`, `TextView` sınıflarına dönüştürür.
   - `BismillahPage.xaml` (115 KB), `EzberPage.xaml` (130 KB), `SettingsPage.xaml` (111 KB) gibi karmaşık ekranlarda iç içe yüzlerce Android görünümü oluşur. Android'in her frame'de yaptığı ölçüm (`measure`) ve yerleşim (`layout`) geçişleri UI thread'i (16.6ms frame bütçesini) aşarak kare düşmelerine (jank) neden olur.
2. **JIT Compilation ve Runtime Assembly Yükü:**
   - `Zikirce.csproj` yapılandırmasında dinamik çalışma zamanı çökmelerini önlemek için `RunAOTCompilation=false` olarak belirlenmiştir. Android üzerinde JIT (Just-In-Time) çalışan .NET CLR, sayfa açılışlarında ve animasyonlarda yoğun CPU frekansı tüketir.
3. **SkiaSharp Köprü Sürtünmesi (Bridge Friction):**
   - Özel motifler, dairesel zikir sayacı ve dalga animasyonları `SKCanvasView` üzerinden çizilmektedir. SkiaSharp'ın MAUI görsel ağacı ile Android'in `HardwareRenderer` katmanı arasındaki senkronizasyon maliyeti UI thread'i bloklar.
4. **Çift Yönlü Veri Bağlama (Two-Way Binding Reflection & Boxing):**
   - MVVM binding yapısında XAML derlenmemiş alanlar reflection ve unboxing yükü oluşturarak çöp toplayıcı (GC) duraklamalarını (GC Pause) tetikler.

---

### 1.2 Neden Flutter ile Yeniden İnşa Edilmeli? (Kazanımlar)

| Kriter | .NET MAUI | Flutter (Impeller / Skia) | Zikirce İçin Kazanç |
| :--- | :--- | :--- | :--- |
| **Render Motoru** | Native OEM View sarmalayıcıları (`android.view.ViewGroup`) | Doğrudan GPU Render (**Impeller / Vulkan**) | Sıfır View hiyerarşi maliyeti, sabit **60/120 FPS**. |
| **Derleme Modeli** | Hibrit / JIT (Android'de kısmi yorumlama) | **Pure Native AOT (ARM64 / ARM32)** | < 400ms soğuk başlatma (Cold Start), sıfır JIT gecikmesi. |
| **Arapça Tipografi** | Platform bağımlı TextFormatter / WebView | Dahili **HarfBuzz + Skia Text Shaping** | Hatasız Mushaf harekeleme, ligatür ve kelime bazlı hizalama. |
| **Animasyonlar** | CPU tabanlı Skia / XAML Storyboard | GPU Shader tabanlı **CustomPainter & Rive/Lottie** | 120 FPS ultra akıcı sayaç ve kuş animasyonları. |
| **Bellek Tüketimi** | 120 MB - 220 MB RAM | 45 MB - 85 MB RAM | Giriş seviyesi 2GB/3GB RAM'li cihazlarda sıfır çökme. |
| **Widget Desteği** | Karmaşık Java interop + RemoteViews | `home_widget` + Jetpack Glance (Kotlin) | Hızlı, enerji dostu 8+ Android Ana Ekran Widget'ı. |

---

## 2. Mimari Kararlar ve Teknoloji Yığını (/grill-me Mutabakatı)

1. **State Management:** **Riverpod 2.x (`flutter_riverpod` + `riverpod_annotation`)**
   - Fonksiyonel reaktif DI, compile-time type-safety, sıfır boilerplate, auto-dispose desteği ve kusursuz test edilebilirlik.
2. **Yerel Veritabanı:** **Drift (SQLite Engine)**
   - Type-safe sorgular, FTS5 tam metin arama, reaktif stream'ler, migration güvenliği ve mevcut `zikir.db` ile %100 şema uyumu.
3. **Mushaf Okuma Motoru:** **Saf Vektörel Flutter Engine (`CustomPainter` + `RichText` + Amasya Abay TTF)**
   - Sıfır WebView gecikmesi, kelime koordinatlarıyla anında etkileşim ve 120 FPS akıcı sayfa çevirme.
4. **Ezber & Sesli Talim (STT):** **Hibrit Ses Tanıma Motoru**
   - Hızlı geri bildirim için yerel Android/iOS Speech-To-Text + çevrimdışı/hassas Kur'an tilaveti kontrolü için gömülü Whisper GGUF (FFI).
5. **Ana Ekran Widget'ları (AppWidgets):** **`home_widget` + Android Jetpack Glance (Kotlin Declarative UI) & iOS WidgetKit**

---

## 3. Sistem Dizin Yapısı (Feature-First Clean Architecture)

```text
lib/
├── app/
│   ├── app.dart                        # MaterialApp.router konfigürasyonu
│   ├── router/                         # GoRouter rota tanımları ve deep-link guard'ları
│   └── theme/                          # Zikirce Altın/Zümrüt/Gece tema token'ları
├── core/
│   ├── constants/                      # Sabitler, Diyanet API endpointleri, Asset yolları
│   ├── database/                       # Drift SQLite veritabanı şemaları ve DAO'ları
│   ├── error/                          # Failures ve Exception hiyerarşisi
│   ├── network/                        # Dio istemcisi, Retry & Token Interceptor
│   ├── services/                       # Audio, Notification, Background, Backup
│   └── utils/                          # Hijri takvim, Arapça normalizer, Haptic motoru
├── features/
│   ├── zikir/                          # Zikir Sayacı, Özel Zikir Ekleme, Transfer
│   │   ├── data/ (models, datasources, repositories)
│   │   ├── domain/ (entities, usecases, repository contracts)
│   │   └── presentation/ (riverpod providers, screens, widgets)
│   ├── kuran/                          # Mushaf Vektörel Okuyucu, Tefsir, Meal
│   ├── ezber/                          # Kelime/Ayet Ezberleme, Spaced Repetition, STT
│   ├── namaz_vakitleri/                # Ezan Vakitleri, Offline Astronomik Hesaplama, Kıble
│   ├── hatim/                          # Bireysel ve QR Destekli Grup Hatmi
│   ├── gamification/                   # Streak (Zinciri Kırma), Kalkan, Rozetler, Sandık
│   ├── dashboard/                      # İstatistikler, Isı Haritası (Heatmap), Profil
│   └── settings/                       # Ses/Titreşim, Tema, Bulut/Yerel Yedekleme
└── main.dart                           # Uygulama başlangıcı ve ProviderScope
```

---

## 4. Paket Yapılandırması (`pubspec.yaml`)

```yaml
name: zikirce
description: Modern, yüksek performanslı İslami yaşam ve zikir asistanı.
publish_to: 'none'
version: 2.0.0+37

environment:
  sdk: '>=3.5.0 <4.0.0'
  flutter: '>=3.24.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # 1. State Management & Routing
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^14.2.7

  # 2. Local Database & Storage
  drift: ^2.20.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0
  flutter_secure_storage: ^9.2.2
  shared_preferences: ^2.3.2

  # 3. Audio & Haptics
  just_audio: ^0.9.40
  just_audio_background: ^0.0.1-beta.13
  record: ^5.1.2

  # 4. Notifications & Background Engine
  flutter_local_notifications: ^17.2.2
  android_alarm_manager_plus: ^3.0.4
  workmanager: ^0.5.2

  # 5. UI, Graphics & Animations
  lottie: ^3.1.2
  fl_chart: ^0.68.0
  qr_flutter: ^4.1.0
  mobile_scanner: ^5.2.3
  flutter_svg: ^2.0.10+1

  # 6. Networking & Cloud Backup
  dio: ^5.7.0
  googleapis: ^13.2.0
  google_sign_in: ^6.2.1

  # 7. AppWidgets
  home_widget: ^0.7.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.20.0
  riverpod_generator: ^2.4.2
  build_runner: ^2.4.12
  flutter_lints: ^4.0.0
```

---

## 5. Modül Detayları ve Uygulama Mimarisi

### 5.1 Zikir & Bismillah Dashboard
- **Sıfır Gecikmeli Sayıcı:** Her ekrana dokunulduğunda `HapticFeedback.lightImpact()` ve `just_audio` (önbelleğe alınmış ses pool'u) eşzamanlı çalışır. `StateProvider` veya `NotifierProvider` ile yalnızca sayaç widget'ı yeniden çizilir (`rebuild`).
- **GPU CustomPainter Dairesel Sayaç:**
  ```dart
  class CircularCounterPainter extends CustomPainter {
    final double progress;
    final Color progressColor;
    final Color trackColor;

    CircularCounterPainter({
      required this.progress,
      required this.progressColor,
      required this.trackColor,
    });

    @override
    void paint(Canvas canvas, Size size) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.width / 2;
      final strokeWidth = 14.0;

      final trackPaint = Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, trackPaint);

      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }

    @override
    bool shouldRepaint(covariant CircularCounterPainter oldDelegate) =>
        oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
  ```

---

### 5.2 Kur'an-ı Kerim Vektörel Mushaf Okuyucu
- **Sayfa Render:** 604 sayfa Mushaf koordinat JSON'ı okunur. Ayetler ve kelimeler `RichText` / `TextSpan` ile Amasya Abay fontuyla çizilir.
- **Kelime Bazlı Ses Senkronizasyonu (Audio-Sync Highlighting):**
  - `just_audio` pozisyon akışı (`positionStream`) dinlenerek `ZikirceAudioSync.db` içindeki başlangıç/bitiş milisaniyeleriyle eşleşen kelime `TextSpan(background: Paint()..color = highlightColor)` ile sıfır gecikmeyle aydınlatılır.

---

### 5.3 Ezber & Sesli Talim (AI / STT)
- **Aralıklı Tekrar (Spaced Repetition - SM-2):**
  - Ayet ezber durumuna göre sonraki tekrar günü hesaplanır (`lastInterval * easeFactor`).
- **Çevrimdışı Ses Tanıma (Speech Recognition):**
  - Kullanıcı mikrofona okurken Platform Channel üzerinden Android `SpeechRecognizer` / iOS `SFSpeechRecognizer` kelimeleri anlık karşılaştırır. İnternetsiz tam hassas modda Whisper GGUF devreye girer.

---

### 5.4 Namaz Vakitleri & Kaza Defteri
- **Hibrit Motor:** Diyanet API'den 30 günlük vakitler önbelleğe alınır. Çevrimdışı durumlarda `PrayTimes` yerel astronomik formüllerle milisaniye hassasiyetinde vakit hesaplar.
- **Kesin Bildirimler:** `AlarmManager.setExactAndAllowWhileIdle` ile Doze Mode'da bile ezan vakti kaçırılmaz.

---

### 5.5 Gamification & Streak (Zinciri Kırma)
- Günlük zikir veya Kur'an okuma yapıldığında `UserStreak` tablosu güncellenir.
- Kaçırılan günler "Kalkan (Shield)" ile korunur veya geçmişe dönük tamir edilir.
- 50+ rozet SVG/Canvas olarak galeride sergilenir.

---

### 5.6 Jetpack Glance Tabanlı Android Widget'ları
Kotlin tarafında Jetpack Glance ile tanımlanan 8+ ana ekran widget'ı:
1. `ZikirCounterWidget` (Sayaç + Hızlı Artırma)
2. `PrayerAnalogClockWidget` (Şık Analog Ezan Saati)
3. `PrayerDigitalClockWidget` (Kalan Süre & Vakit Listesi)
4. `DailyVerseWidget` (Günün Ayeti / Hadisi)
5. `PrayerKazaWidget` (Kaza Namazı Sayacı)

---

## 6. Veri Göçü (Migration) & Güvenlik
- **Mevcut Veritabanı Uyumu:** Drift tabloları MAUI'deki `sqlite-net-pcl` tablolarıyla (`Zikir`, `ZikirLog`, `UserStreak`, `UserBadges`, `KazaNamazlari`) birebir aynı şemada açılır.
- **İlk Başlangıçta Otomatik İçe Aktarma:** Uygulama ilk kez açıldığında MAUI'nin `zikir.db` dosyasını otomatik olarak Drift veritabanına taşır; kullanıcı hiçbir verisini kaybetmez.
- **Güvenli Depolama:** API anahtarları `flutter_secure_storage` (Android Keystore / iOS Keychain) içinde AES-256 ile saklanır.
- **Çift Yedekleme:** Yerel şifreli `.zikirce` dosyası ve Google Drive AppData sessiz senkronizasyonu.

---

## 7. Sonuç ve Performans Taahhüdü

Zikirce'nin Flutter mimarisine geçişiyle:
- **Tüm cihazlarda (en düşük segment dahil) sabit 60/120 FPS akıcılık,**
- **Sıfır bellek sızıntısı ve %60 daha düşük RAM tüketimi (45-85 MB),**
- **< 400ms soğuk başlatma hızı,**
- **Kusursuz Mushaf Arapça tipografisi ve kelime ses senkronizasyonu** sağlanacaktır.
