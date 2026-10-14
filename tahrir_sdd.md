# TAHRİR - Akıllı Dijital Okuma, Şerh & Alışkanlık Ekosistemi
## Kapsamlı Yazılım Tasarım Belgesi (Software Design Document - SDD)

**Proje Adı:** Tahrir (Zarif, Akıcı ve Bilişsel Odaklı Okuma Deneyimi)  
**Doküman Sürümü:** 0.9.0  
**Tarih:** 27 Ağustos 2026  
**Hedef Platform:** Mobil (Android & iOS) - Öncelikli Optimizasyon: Kompakt Ekranlı Akıllı Telefonlar ve Katlanabilir Cihazlar  
**Mimari / Framework:** Flutter 3.x+ (Dart 3.x) & Yerel C++ FFI (Pdfium) + Rust/Native Ayrıştırıcılar  

---

## 1. Proje Özeti ve Vizyon

### 1.1. Vizyon ve İsim Felsefesi
**Tahrir**; klasik Doğu ve Akdeniz yazma/okuma kültüründeki *"metni kaydetme, şerh düşme, düzeltme ve tahrir etme"* zarafetini modern mobil tipografi ve bilişsel bilimle buluşturan, okumayı zahmetsiz ve karşı konulmaz derecede çekici kılan yeni nesil bir okuma ekosistemidir.

Geleneksel e-kitap okuyucuların hantal dosya yapısını ve PDF'lerin küçük ekranlardaki kaydırma çilesini ortadan kaldırır. Tahrir; kitabı yalnızca bir metin yığını olarak değil, kişisel bir düşünce atölyesi ve estetik bir ritüel olarak ele alır.

### 1.2. Çözülen Temel Problemler
1. **Sabit Mizanpaj (Fixed-Layout) Çıkmazı:** PDF'ler ve taranmış akademik dokümanlar A4/B5 gibi geniş baskılara göre dizilmiştir. Küçük ekranlarda sürekli iki parmakla sağa-sola kaydırma (horizontal scrolling) bilişsel yorgunluk üretir.
2. **Kopuk Görsel ve Dipnot Deneyimi:** Klasik reflow motorları metin içindeki şemaları/görselleri bozar, dipnotları sayfa sonuna atarak okuma akışını kesintiye uğratır.
3. **Format Dağınıklığı:** Kullanıcılar PDF için ayrı, EPUB için ayrı, web makaleleri ve markdown notları için ayrı uygulamalar kullanmak zorunda kalır.
4. **Bilişsel Sürtünme ve Dikkat Dağınıklığı:** Yoğun metinlerde göz satır kaybeder, odak çabuk dağılır ve okuma alışkanlığı sürdürülemez hale gelir.
5. **Kuru ve Ruhsuz Arayüzler:** Mevcut okuyucular kütüphane hissi vermekten uzak, gri ve mekanik listelerden ibarettir.

---

## 2. Temel İlkeler ve UX Felsefesi

1. **Sıfır Gecikme & 120Hz Akıcılık (Zero-Lag Flutter Impeller):** Her sayfa geçişi, kaydırma ve menü açılışı 120Hz ekranlarda yağ gibi akıcıdır; hiçbir işlem ana UI thread'ini bloke etmez.
2. **%100 Yerel Öncelikli & Gizlilik Odaklı (Local-First & Offline):** Tüm analizler, yerel yapay zeka çıkarımları, OCR ve veri saklama işlemleri tamamen cihaz üzerinde çalışır. İnternet bağlantısı veya harici sunucu zorunluluğu yoktur.
3. **Bilişsel Kolaylaştırıcılar (Cognitive Ease):** Canlı sesli dinleme (TTS), ortam ambiyans sesleri (Lo-Fi/Yağmur), metin içi açılır dipnotlar ve dokunulabilir görsel lightbox ile kesintisiz okuma akışı (Flow State).
4. **Dokunsal & Görsel Zevk (Aesthetic Delight):** Sanal 3D/minimal kitaplık rafları, kitap bitirme mühürleri, klasik ve modern hibrit renk paletleri.
5. **Eşler Arası Şerh Paylaşımı (Offline P2P Marginalia):** Kitaba düşülen notlar ve şerhler internet olmaksızın QR kod veya yerel dosya takasıyla diğer Tahrir kullanıcılarıyla paylaşılabilir.

---

## 3. Teknoloji Mimarisi & Kütüphane Yığını

| Katman | Teknoloji / Kütüphane | Kullanım Amacı & Açıklama |
| :--- | :--- | :--- |
| **Çatı (Framework)** | **Flutter 3.x+ (Dart 3.x)** | Impeller render motoru, 120 FPS akıcı animasyonlar, zengin tipografi. |
| **Durum Yönetimi** | `flutter_riverpod` + `freezed` | Tip güvenli, reaktif ve test edilebilir durum yönetimi. |
| **PDF & FFI Motoru** | `pdfx` (Pdfium C++ FFI) + `syncfusion_flutter_pdf` | Sayfa görselleştirme, glif koordinatları, beyaz kenarlık tespiti. |
| **EPUB & Web Motoru** | `epubx` / Özel DOM Parser | EPUB bölümlerini, CSS stillerini ve XHTML bileşenlerini ayrıştırma. |
| **Yerel Veritabanı** | `isar` / `drift` (SQLite) | Yüksek hızlı yerel indeksleme, okuma oturumları, şerhler, sözlük. |
| **Sesli Eşlikçi (TTS)** | `flutter_tts` / Yerel OS Neural TTS | Cihaz içi yüksek kaliteli metin okuma ve kelime bazlı senkronize vurgulama. |
| **Ambiyans Motoru** | `just_audio` + `audio_session` | Yağmur, şömine, kütüphane gibi arka plan seslerini miksleyip çalma. |
| **Çevrimdışı Yerel AI** | `google_mlkit_text_recognition` + On-Device Summarizer | Taranmış sayfalar için OCR ve cihaz içi özet/anahtar kelime analizi. |
| **Görsel & Lightbox** | `photo_view` + `RepaintBoundary` | Metin içi görseller için pinch-to-zoom ve yüksek çözünürlüklü popup. |
| **P2P & Paylaşım** | `qr_flutter` + `mobile_scanner` + `share_plus` | İnternetsiz QR kod ile not takası ve sosyal alıntı kartı paylaşımı. |
| **Widget Desteği** | `home_widget` | Android & iOS ana ekranına streak ve günlük alıntı widget'ı basma. |

---

## 4. Sistem Mimarisi ve Çekirdek Modüller

```
                                  ┌─────────────────────────────────────────┐
                                  │            TAHRİR Core Engine           │
                                  └────────────────────┬────────────────────┘
                                                       │
        ┌───────────────────────────────┬──────────────┴────────────────┬───────────────────────────────┐
        │                               │                               │                               │
        ▼                               ▼                               ▼                               ▼
 [ Çok Formatlı Motor ]      [ Bilişsel Okuma Modları ]      [ Şerh, Not & Sözlük ]          [ Estetik & Alışkanlık ]
 - PDF Smart Reflow          - TTS Canlı Sesli Eşlikçi       - İnteraktif Dipnot Baloncuğu   - 3D/Minimal Ahşap Raf
 - EPUB & Markdown Parser    - Ambiyans & Zen Odak           - Görsel Popup Lightbox         - Kitap Bitirme Mührü
 - De-hyphenation / Header   - Okuma Cetveli (Line Focus)    - Dahili Lügat & Etimoloji      - Streak & Isı Haritası
 - Çift Görünüm (Dual-View)  - Çevrimdışı Yerel AI Özet      - P2P QR Not Takası             - Alıntı Kartı Stüdyosu
```

---

### 4.1. Çok Formatlı Akıllı Okuma Motoru (Smart Reflow & Multi-Format)

1. **PDF Akıllı Yeniden Akış (Smart Reflow Engine):**
   * **Koordinat Tabanlı Bloklama:** Gliflerin `X` ve `Y` koordinatları taranır. Satır arası mesafesi harf yüksekliğinden büyük olan yerler paragraf olarak yapılandırılır.
   * **De-Hyphenation:** Satır sonunda tire (`-`) ile bölünen kelimeler sözlük kurallarına göre birleştirilir.
   * **Akıllı Üst/Alt Bilgi Eleme:** Her sayfada tekrar eden başlık, sayfa numarası ve marjinal bilgiler ana metin gövdesinden ayıklanır.
   * **Çift Sütun Desteği:** Sayfa orta ekseni hesaplanarak önce sol, ardından sağ sütun hiyerarşik sırada okunur.
2. **EPUB & Markdown & Web Makalesi Desteği:**
   * EPUB dosyaları DOM hiyerarşisi korunarak native widget ağacına dönüştürülür.
   * Markdown ve web makaleleri (Readability API tarzı yerel temizleyici) aynı tipografik temada render edilir.
3. **Hibrit Çift Görünüm (Dual-View Switcher):**
   * Kullanıcı tek dokunuşla veya çift tıklama jestiyle Orijinal PDF Görünümü ile Akıllı Akış Modu arasında anında geçiş yapabilir.
   * **Otomatik Kenar Kırpma (Auto-Crop):** Orijinal PDF modunda boş sayfa kenarlıkları otomatik kesilerek ekrana tam sığdırılır.

---

### 4.2. Bilişsel Okuma ve Odak Modları (Cognitive Reading Suite)

1. **Canlı Vurgulu Sesli Dinleme (TTS Audio Companion):**
   * Cihazın yerel ses motoru (Siri/Google TTS) kullanılarak metin seslendirilir.
   * Seslendirilen her kelime/cümle okuma ekranında yumuşak bir ışıkla (karaoke tarzı canlı vurgu) anlık olarak takip edilir.
   * Kullanıcı isterse sadece dinleyebilir, isterse dinlerken gözle takip ederek okuma hızını 2x artırabilir.
2. **Ambiyans & Zen Odak Modu (Atmosphere & Deep Focus):**
   * **Arka Plan Sesleri:** Yağmur damlaları, kütüphane sessizliği, şömine çıtırtısı ve kahve dükkanı lo-fi sesleri dahili ses mikseriyle ayarlanabilir.
   * **Okuma Cetveli (Line Focus Overlay):** Dikkat dağınıklığı yaşayanlar için okunan satır haricindeki kısımları yarı saydam karartan odak cetveli.
   * **Zen Modu:** Ekrandaki tüm menüleri, saat ve pil simgelerini gizleyerek saf metne odaklanma.
3. **Görsel & Tablo İnceleme (In-place Lightbox Popup):**
   * Metin içinde geçen görsellere, minyatürlere, haritalara veya tablolara dokunulduğunda akış bozulmaz; görsel tam ekran, yüksek çözünürlüklü, çift parmakla yakınlaştırılabilir (pinch-to-zoom) bir popup pencerede açılır.
4. **Çevrimdışı Akıllı Katip (On-Device AI Summarizer & Insights):**
   * İnternet gerektirmeyen Google ML Kit / Gemini Nano motoru ile sayfanın anahtar kavramları, karakter listesi ve 3 maddelik hızlı özeti tek dokunuşla üretilir.

---

### 4.3. Tahrir Şerh, İnteraktif Dipnot & Sözlük Sistemi

1. **İnteraktif Dipnot Baloncukları (Inline Footnote Preview):**
   * Sayfa altında veya kitabın en sonunda yer alan dipnot numaralarına (örn: `[1]`, `*`) dokunulduğunda sayfa kaydırılmaz; dipnot metni doğrudan kelimenin üzerinde şık bir baloncuk (pop-up sheet) olarak açılır.
2. **Dahili Lügat & Etimoloji Sözlüğü:**
   * Bilinmeyen kelimenin üzerine uzun basıldığında çevrimdışı Türkçe sözlük, etimolojik köken ve eş anlamlılar kartı açılır.
3. **Kenar Şerhi (Marginalia) & Çift Katmanlı Not Alma:**
   * Klasik yazmalardaki gibi metnin sağına/soluna serbest notlar düşülebilir.
   * Alınan notlar renklere göre kategorize edilir (Fikir, Alıntı, Soru, Eleştiri).
4. **Çevrimdışı Eşler Arası (P2P / QR Kod) Şerh Takası:**
   * Bir kitaba düşülen tüm şerhler ve altı çizili yerler, internet bağlantısı olmadan dinamik QR kod veya `.tahrir` paketi halinde başka bir kullanıcıya aktarılabilir.

---

### 4.4. Oyunlaştırma, Motivasyon & Estetik Kitaplık

1. **Estetik Sanal Kitaplık Rafı (3D / Minimal Spines):**
   * Kitaplar sadece liste olarak değil; ahşap veya monokrom raf üzerinde gerçek kitap sırtları (book spines) ve kabartmalı kapaklar şeklinde sergilenir.
   * Kapağı olmayan PDF'ler için Tahrir otomatik olarak şık bir edebi tipografik kapak üretir.
2. **Kitap Tamamlama Ritüeli & Mühürlü Sertifika (Tahrir Mührü):**
   * Bir kitap bitirildiğinde özel bir tamamlama animasyonu çalışır.
   * Okuma süresi, sayfa sayısı ve okuma hızını içeren geleneksel mühürlü "Tahrir Okuma Beratı / Sertifikası" üretilir ve galeriye kaydedilebilir.
3. **Alıntı Paylaşım Stüdyosu (Quote Studio):**
   * Seçilen cümle tek dokunuşla 9:16 Instagram Story, 1:1 Minimal Kare veya Lüks Parşömen şablonuna dökülür.
4. **Alışkanlık Takibi & Isı Haritası:**
   * Günlük okuma zinciri (Streak), GitHub tarzı aktivite ısı haritası ve WPM (dakikadaki kelime sayısı) analizi.
5. **Ana Ekran Widget Desteği (iOS & Android):**
   * Günün alıntısı, aktif streak sayısı ve tek tıkla son kitaba dönme butonunu içeren widget'lar.

---

## 5. Tipografi Koleksiyonu & Görsel Temalar

### 5.1. Renk Temaları Paleti
| Tema Adı | Arka Plan Kodu | Metin Rengi Kodu | Vurgu Rengi | Karakter & Atmosfer |
| :--- | :--- | :--- | :--- | :--- |
| **Tahrir Parşömeni** | `#F5EEDB` | `#33271E` | `#8B4513` (Lal) | Klasik el yazması, gözü dinlendiren sıcak kemik tonu. |
| **İs Mürekkebi (AMOLED)** | `#000000` | `#E2E8F0` | `#EAB308` (Altın) | Saf siyah, maksimum pil tasarrufu ve gece netliği. |
| **Gece Safiri** | `#0F172A` | `#CBD5E1` | `#38BDF8` (Buz Mavi) | Modern koyu tema, düşük mavi ışık etkisi. |
| **Hakiki Kağıt Beyazı** | `#FAF9F6` | `#1E293B` | `#059669` (Zümrüt) | Birinci hamur kitap kağıdı doğallığında gündüz okuması. |
| **Zeytin & Orman** | `#1C2826` | `#D8E2DC` | `#A3B18A` (Adaçayı) | Doğa tonları, uzun okuma seansları için nötr kontrast. |

### 5.2. Yazı Tipleri (Offline Font Suite)
* **Serif (Edebi & Klasik):** *Literata* (Google Books için özel tasarlanmış), *Lora*, *Merriweather*, *Amiri*.
* **Sans-Serif (Modern & Berrak):** *Inter*, *Plus Jakarta Sans*, *Outfit*.
* **Monospace (Teknik & Şiir):** *JetBrains Mono*, *Fira Code*.

---

## 6. Veri Modeli ve Şema Mimarisi (Isar DB / Drift)

```dart
import 'package:isar/isar.dart';

part 'tahrir_models.g.dart';

// 1. Kitap Modeli (PDF, EPUB, Makale)
@collection
class Book {
  Id id = Isar.autoIncrement;

  late String title;
  late String author;
  late String filePath;
  String? coverImagePath;
  
  @enumerated
  late BookFormat format; // pdf, epub, markdown, webArticle

  late int totalPages;
  int currentPage = 1;
  double progressPercentage = 0.0;
  
  int totalReadingTimeSeconds = 0;
  int estimatedReadingTimeMinutes = 0;

  DateTime addedDate = DateTime.now();
  DateTime lastReadDate = DateTime.now();
  bool isCompleted = false;
  DateTime? completedDate;
}

enum BookFormat { pdf, epub, markdown, webArticle }

// 2. Okuma Oturumu (Analytics, WPM & Streak)
@collection
class ReadingSession {
  Id id = Isar.autoIncrement;

  late int bookId;
  late DateTime sessionDate; // YYYY-MM-DD
  late int durationSeconds;
  late int pagesRead;
  late int wordsRead;
  double calculatedWpm = 0.0;
}

// 3. Şerh, Not ve Vurgular (Marginalia & Highlights)
@collection
class TahrirHighlight {
  Id id = Isar.autoIncrement;

  late int bookId;
  late int pageNumber;
  late String selectedText;
  String? userNote;
  
  @enumerated
  HighlightCategory category = HighlightCategory.thought; // thought, quote, question, critical

  late String colorHex;
  DateTime createdAt = DateTime.now();
}

enum HighlightCategory { thought, quote, question, critical }

// 4. İnteraktif Dipnot ve Lügat Önbelleği
@collection
class InlineFootnote {
  Id id = Isar.autoIncrement;

  late int bookId;
  late int pageNumber;
  late String anchorKey; // Örn: [1], *
  late String footnoteContent;
}

// 5. Günlük Alışkanlık, Streak & Mühürler
@collection
class UserHabitProfile {
  Id id = Isar.autoIncrement;

  late DateTime lastActiveDate;
  int currentStreak = 0;
  int longestStreak = 0;
  int dailyGoalMinutes = 20;

  List<String> earnedSeals = []; // Kazanılan Tahrir Mühürleri ID listesi
}
```

---

## 7. Kullanıcı Arayüzü (UI) ve Ekran Akışları

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           1. Sanal Kitaplık                             │
│       (3D/Minimal Ahşap Raf, Streak Rozeti, Son Kitap Vitrini)          │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ Kitaba Dokun
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    2. Tahrir Akıllı Okuma Ekranı                        │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │ [Üst Bar] Bölüm Adı | % İlerleme | Kalan Süre | [Zen / Ambiyans]│   │
│   ├─────────────────────────────────────────────────────────────────┤   │
│   │ [Metin Akışı]                                                   │   │
│   │ - Akıcı tipografi, satır cetveli                                │   │
│   │ - Tıklanabilir Dipnot [1] ──> [Baloncuk Pop-up]                 │   │
│   │ - Küçük Görsel Önizleme   ──> [Lightbox Pinch-Zoom Pop-up]      │   │
│   │ - Canlı Vurgulu TTS Dinleme [Kelime Kelime Işıklandırma]        │   │
│   ├─────────────────────────────────────────────────────────────────┤   │
│   │ [Alt Hızlı Çubuk] Font/Tema | Sesli Oku | Çift Görünüm (PDF)    │   │
│   └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘

## 9. Tahrir Geliştirme ve Uygulama TODO List (Tamamlanan Adımlar)

### Faz 1: Temel Mimari, Bağımlılıklar & Veri Katmanı (Core & Data Layer)
- [x] **1.1.** `pubspec.yaml` paket bağımlılıklarının yapılandırılması (Riverpod, SQLite/SharedPreferences, Google Fonts, TTS, Audio, PDF/EPUB, QR, File Picker).
- [x] **1.2.** Temiz Mimari (Clean Architecture / SOLID) klasör hiyerarşisinin kurulması (`core/`, `features/`, `data/`, `domain/`, `presentation/`).
- [x] **1.3.** Veri modelleri ve DTO'ların oluşturulması (`Book`, `ReadingSession`, `TahrirHighlight`, `InlineFootnote`, `UserHabitProfile`, `ThemeConfig`).
- [x] **1.4.** Yerel Depolama ve Veritabanı Servisinin kodlanması (`DatabaseService`, `LocalStorageService`, `Repository` katmanları).
- [x] **1.5.** Güvenli hata yakalama, Loglama ve Poka-Yoke doğrulamaları (`AppError`, `Result<T>`).

### Faz 2: Zengin Tema Sistemi & Tipografi (Aesthetics & Theming)
- [x] **2.1.** 5 Temalı Renk Paleti ve Material 3 Entegrasyonu (Tahrir Parşömeni, İs Mürekkebi AMOLED, Gece Safiri, Hakiki Kağıt Beyazı, Zeytin & Orman).
- [x] **2.2.** Dinamik Tema Yöneticisi (`ThemeProvider` - Açık, Koyu, AMOLED ve Cihaz Sistem Temasına Otomatik Uyum).
- [x] **2.3.** Tipografi Motoru (`FontProvider` - Literata, Lora, Merriweather, Inter, JetBrains Mono) + Satır yüksekliği, harf aralığı ve marjin denetleyicileri.

### Faz 3: Çok Formatlı Okuma ve Akıllı Reflow Motoru (Multi-Format & Engine)
- [x] **3.1.** Dosya İçe Aktarma Servisi (`BookImportService` - PDF, EPUB, TXT/Markdown, Web Makalesi).
- [x] **3.2.** PDF Koordinat Analiz ve Akıllı Reflow Motoru (`PdfReflowEngine` - De-hyphenation, Header/Footer filtreleme, çift sütun desteği).
- [x] **3.3.** EPUB & Markdown Render Ayrıştırıcısı (`EpubParserService`, `MarkdownReaderView`).
- [x] **3.4.** Hibrit Çift Görünüm (Dual-View: Orijinal Vektörel PDF vs Akıllı Metin Akışı) ve Otomatik Kenar Kırpma (Auto-Crop).

### Faz 4: Bilişsel Okuma Modları, Medya & Görsel Lightbox (Cognitive Reading)
- [x] **4.1.** Canlı Vurgulu TTS Sesli Dinleme Motoru (`TtsService` - Cihaz içi yüksek kaliteli ses ve kelime/cümle bazlı karaoke aydınlatması).
- [x] **4.2.** Ambiyans & Zen Odak Modu (`AmbientAudioService` - Yağmur, Kütüphane, Şömine, Kafe mikseri; Okuma Cetveli ve Odak Karartma).
- [x] **4.3.** İnteraktif Dipnot Baloncuk Sistemi (`InlineFootnotePopup` - Metin içi `[1]` dokunulduğunda akışı kesmeyen popup sheet).
- [x] **4.4.** Görsel & Şema Lightbox Modal (`ImageLightboxPopup` - Pinch-to-zoom, yüksek çözünürlüklü tam ekran inceleme).
- [x] **4.5.** Çevrimdışı Akıllı Katip (`OnDeviceSummaryService` - Sayfa anahtar kavramları ve hızlı özet çıkarıcı).

### Faz 5: Şerh, Lügat, P2P Paylaşım & Alıntı Stüdyosu (Marginalia & Social)
- [x] **5.1.** Çok Katmanlı Şerh ve Vurgulama Sistemi (`HighlightService` - Renkli alt çizgi, serbest kenar notları, etiketleme).
- [x] **5.2.** Çevrimdışı Dahili Türkçe Lügat & Etimoloji Sözlüğü (`TahrirDictionaryService`).
- [x] **5.3.** Çevrimdışı P2P (Dinamik QR Kod) Şerh ve Not Takası (`QrSyncService` - İnternetsiz not aktarımı).
- [x] **5.4.** Alıntı Paylaşım Stüdyosu (`QuoteStudioView` - 9:16 Story, 1:1 Kare, Lüks Parşömen şablonları ve PNG export).

### Faz 6: Sanal Kitaplık, Oyunlaştırma & Kitap Tamamlama Mührü (Delight & Habit)
- [x] **6.1.** Estetik 3D / Minimal Ahşap Kitaplık Rafı (`BookshelfView` - Kitap sırtları, kapak vitrini, kategori filtreleri, arama).
- [x] **6.2.** Otomatik Tipografik Edebi Kapak Jeneratörü (Kapağı olmayan PDF'ler için zarif kapak tasarımı).
- [x] **6.3.** Günlük Streak Zinciri, Aktivite Isı Haritası ve WPM Okuma Hızı Analizi (`HabitTrackerService`).
- [x] **6.4.** Kitap Tamamlama Ritüeli & Mühürlü "Tahrir Okuma Beratı" (`BookCompletionSealModal`).
- [x] **6.5.** Ana Ekran Widget Entegrasyonu ve Veri Köprüsü (`HomeWidgetService`).

### Faz 7: Testler, Doğrulama & Performans Optimizasyonu (QA & Polish)
- [x] **7.1.** Birim ve Entegrasyon Testleri (`flutter test` - 4/4 Başarılı Geçti).
- [x] **7.2.** 120Hz Pürüzsüz Scroll ve Bellek (Virtual Windowing) Optimizasyonu.
- [x] **7.3.** Mimari İnceleme ve Final Doğrulaması.

---
*Bu doküman TAHRİR uygulamasının eksiksiz mimari, tasarımsal ve fonksiyonel geliştirme şartnamesidir.*
