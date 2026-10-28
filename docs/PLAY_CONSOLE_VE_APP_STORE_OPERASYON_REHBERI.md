# CueDeck (`com.akarworks.cuedeck` v1.9.1+13) — Google Play Console, Paylaşım & Apple App Store Connect Operasyon Rehberi

Bu rehber, **Barbaros Hayreddin Paşa (`store-commander`)** tarafından **CueDeck v1.9.1 (Build 13)** sürümünün Google Play Console, Apple App Store Connect (TestFlight & Review) ve Akıllı Paylaşım Portalları üzerinden sıfır hatayla yayınlanması için hazırlanmıştır.

---

## 1. Üretilen Mağaza Paketleri ve Arşiv Konumları

| Platform / Paket | Dosya Konumu | Boyut & Durum |
| :--- | :--- | :--- |
| **Google Play App Bundle (`.aab`)** | `G:\Drive'ım\CueDeck\Releases\cuedeck_v1.9.1+13_release.aab` | `43.2 MB` — `cuedeck-upload-keystore.jks` ile imzalı, doğrudan Play Console'a yüklenmeye hazır |
| **Android Release APK (`.apk`)** | `G:\Drive'ım\CueDeck\Releases\cuedeck_v1.9.1+13_release.apk` | `52.5 MB` — Doğrudan cihaz kurulumu ve dağıtım için imzalı |
| **Tester Paylaşım APK Kopyası** | `G:\Drive'ım\CueDeck\cuedeck_v1.9.1_b13.apk` | `52.5 MB` — Google Drive / WhatsApp üzerinden tek tıkla tester paylaşımı için |
| **iOS TestFlight & App Store (`.ipa`)** | [`.github/workflows/ios-build.yml`](file:///c:/Users/theak/source/repos/cuedeck/.github/workflows/ios-build.yml) & [`.github/workflows/appstore-release.yml`](file:///c:/Users/theak/source/repos/cuedeck/.github/workflows/appstore-release.yml) | GitHub Actions `macos-latest` üzerinde derlenip doğrudan TestFlight & App Store Review'a gönderilir |

---

## 2. Google Play Console Adım Adım Gönderim Rehberi

### 2.1. Uygulama Oluşturma (İlk Kez Açılıyorsa)
1. [Google Play Console](https://play.google.com/console) adresine giriş yapın ve **Uygulama oluştur (Create app)** butonuna tıklayın:
   - **Uygulama adı:** `CueDeck: Akıllı TV Kumandası & İzleme Planlayıcı`
   - **Varsayılan dil:** `Türkçe (tr-TR)`
   - **Uygulama veya oyun:** `Uygulama (App)`
   - **Ücretsiz veya ücretli:** `Ücretsiz (Free)` *(Uygulama içi satın alma ve ödüllü reklam içerir)*
2. **Mağaza Girişi (Main Store Listing)** metinlerini [`docs/magaza_vitrin_aso_paketi.md`](file:///c:/Users/theak/source/repos/cuedeck/docs/magaza_vitrin_aso_paketi.md) dosyasından kopyalayın.
3. **Gizlilik Politikası URL'si:** GitHub Pages veya kendi alan adınızda yayınlanan [`app_store_privacy_support/index.html`](file:///c:/Users/theak/source/repos/cuedeck/app_store_privacy_support/index.html) adresini girin.

### 2.2. Veri Güvenliği (Data Safety) Formu Cevap Anahtarı
Google Play Console > **Uygulama içeriği (App content) > Veri güvenliği (Data safety)** bölümünde şu yanıtları işaretleyin:

| Soru / Bölüm | İşaretlenecek Yanıt | Açıklama |
| :--- | :--- | :--- |
| **Uygulamanız gerekli kullanıcı verisi türlerinden herhangi birini topluyor veya paylaşıyor mu?** | **Hayır (No)** *(veya yalnızca isteğe bağlı Google Drive yedekleme kapsamında kullanıcı hesabında şifreli saklanır)* | Tüm TV profilleri, RSA/PIN eşleştirme anahtarları ve izleme planları cihaz içinde (`AndroidKeyStore` `AES-256-GCM`) tutulur; geliştirici sunucularına hiçbir veri aktarılmaz. |
| **Aktarım sırasında veriler şifreleniyor mu?** | **Evet (Yes)** | Google Drive API (`appdata`) iletişimi TLS 1.3 + cihaz içi `AES-256-GCM` kasa şifrelemesi kullanır. |
| **Kullanıcılar verilerinin silinmesini talep edebilir mi?** | **Evet (Yes)** | Ayarlar ekranından yerel/bulut yedekleri tek dokunuşla silinebilir veya uygulama kaldırıldığında tüm veriler temizlenir. |

### 2.3. Hassas İzin Beyanları (`App Content > Sensitive Permissions`)
- **`SCHEDULE_EXACT_ALARM` (Tam Zamanlı Alarm):**
  - *Beyan:* "CueDeck bir Zamanlanmış TV İzleme Planlayıcı (`WatchCueItem`) uygulamasıdır. Kullanıcının belirlediği yayın saatinde (`scheduledTime`) ve ön hatırlatma dakikasında (`reminderMinutesBefore`) tam zamanında bildirim gönderip TV'de ilgili yayını başlatabilmek için `AlarmManager.setExactAndAllowWhileIdle` kullanır." *(Not: Mağaza ret riskine karşı `USE_EXACT_ALARM` manifestten kaldırılmış, yalnızca `SCHEDULE_EXACT_ALARM` korunmuştur).*
- **`RECORD_AUDIO` (Mikrofon / Sesli Komut):**
  - *Beyan:* "Yalnızca kullanıcı kumanda üzerindeki Mikrofon (Sesli Komut) tuşuna bastığında Android yerleşik `RecognizerIntent` (`tr-TR`) aracılığıyla sesli TV komutu veya YouTube araması yapmak için kullanılır; arka planda ses kaydı yapılmaz veya saklanmaz."

### 2.4. Uygulama İçi Ürünler (Monetization > Products > In-app products)
Play Console ve App Store Connect üzerinde aşağıdaki 2 tek seferlik (Non-Consumable) ürünü oluşturun:

| Ürün Kimliği (Product ID / SKU) | Ürün Türü | Türkiye Fiyatı | Global (USD) | Başlık & Açıklama |
| :--- | :--- | :--- | :--- | :--- |
| `cuedeck_pro_lifetime` | Tek Seferlik (`Non-Consumable`) | **99,99 ₺** *(Lansman)* / **149,99 ₺** | **$3.99** | **CueDeck Pro (Ömür Boyu):** Tüm reklamları kaldırır, sınırsız izleme planı, sınırsız TV profili ve Google Drive bulut yedeklemesini ömür boyu açar. |
| `cuedeck_pro_loyalty_40` | Tek Seferlik (`Non-Consumable`) | **89,99 ₺** | **$3.49** | **CueDeck Pro (%40 Sadakat İndirimi):** 10 farklı günde 24 Saatlik Pro Pass açan sadık kullanıcılara özel %40 indirimli ömür boyu Pro lisansı. |

### 2.5. `.aab` Paketini Yükleme ve Sürüm Notlarını Yapıştırma
1. Play Console > **Üretim (Production)** veya **Kapalı Test (Closed Testing)** > **Yeni sürüm oluştur (Create new release)** adımına gidin.
2. `G:\Drive'ım\CueDeck\Releases\cuedeck_v1.9.1+13_release.aab` dosyasını sürükleyip bırakın.
3. **Sürüm Notları (Release notes)** alanına [`docs/RELEASE_NOTES_v1.9.1_b13.md`](file:///c:/Users/theak/source/repos/cuedeck/docs/RELEASE_NOTES_v1.9.1_b13.md) içindeki `<tr-TR>` ve `<en-US>` XML bloğunu (500 karakter sınırına tam uyumlu) yapıştırıp **İncelemeye Gönder** butonuna basın.

---

## 3. GitHub Actions Üzerinden Apple App Store Connect (TestFlight & Auto-Submit) Otomasyonu

### 3.1. App Store Connect'te "New App" Kaydını 30 Saniyede Açma (Tek Seferlik)
Apple güvenlik politikası gereği bir uygulamanın **ilk kartı** App Store Connect web arayüzünden 1 kez açılmalıdır (Bundle ID `com.akarworks.cuedeck` ise Fastlane `produce` ve REST API `/v1/bundleIds` tarafından Apple Developer Portal'a otomatik kaydedilir):
1. [App Store Connect > Apps](https://appstoreconnect.apple.com/apps) sayfasına gidin ve **`(+)` > New App** butonuna tıklayın.
2. Şu 4 alanı seçip **Create** butonuna basın:
   - **Platforms:** `iOS`
   - **Name:** `CueDeck` *(veya `CueDeck: Smart TV Remote`)*
   - **Primary Language:** `Turkish (Türkçe)`
   - **Bundle ID:** `com.akarworks.cuedeck`
   - **SKU:** `cuedeck-001`
   - **User Access:** `Full Access`

### 3.2. GitHub Repository Secrets Tanımları (`Settings > Secrets and variables > Actions`)
Zikirce_ projesinde kullandığınız Apple ve Google Play anahtarlarını CueDeck GitHub deposuna da ekleyin:

| Secret Adı | Açıklama |
| :--- | :--- |
| `APP_STORE_KEY_ID` | App Store Connect API Key ID (Örn: `2X9R4H...`) |
| `APP_STORE_ISSUER_ID` | App Store Connect Issuer ID (UUID formatında) |
| `APP_STORE_PRIVATE_KEY` | `AuthKey_XXXX.p8` dosyasının tam metin içeriği (`-----BEGIN PRIVATE KEY----- ...`) |
| `BUILD_CERTIFICATE_BASE64` | Apple Distribution `.p12` sertifikasının Base64 kodlanmış hali (`[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12"))`) |
| `P12_PASSWORD` | `.p12` sertifikasının parolası |
| `ANDROID_KEYSTORE_BASE64` | `android/app/cuedeck-upload-keystore.jks` dosyasının Base64 hali |
| `ANDROID_KEY_PROPERTIES` | `android/key.properties` dosyasının tam metin içeriği |
| `PLAY_STORE_JSON_KEY` | Google Cloud Service Account JSON anahtarı (Play Console API erişimi için) |

### 3.3. Otomasyon İş Akışlarını Çalıştırma Sırası
1. **Adım 1 — iOS Derleme & TestFlight Yüklemesi ([`.github/workflows/ios-build.yml`](file:///c:/Users/theak/source/repos/cuedeck/.github/workflows/ios-build.yml)):**
   - `main` dalına push yapıldığında veya GitHub Actions sekmesinden **iOS Cloud Build & TestFlight Ready > Run workflow** tıklandığında çalışır.
   - `macos-latest` üzerinde `CueDeck.ipa` paketini imzalayıp doğrudan Apple TestFlight'a yükler.
2. **Adım 2 — Sürüm Oluşturma, TR/EN Sürüm Notu Yazma & İncelemeye Gönderme ([`.github/workflows/appstore-release.yml`](file:///c:/Users/theak/source/repos/cuedeck/.github/workflows/appstore-release.yml)):**
   - GitHub Actions sekmesinden **App Store Connect — Create v1.9.1, Attach Build 13 & Submit for Review > Run workflow** butonuna tıklayın (`version_string: 1.9.1`, `build_number: 13`).
   - Python `ES256` JWT betiği otomatik olarak `1.9.1` sürümünü açar, TR ve EN `whatsNew` sürüm notlarını yazar, Build `13` `VALID` olunca bağlar, `usesNonExemptEncryption: False` işaretler ve **Submit for Review** işlemini tamamlar.

---

## 4. Akıllı Paylaşım & Gizlilik Portalları (`app_store_privacy_support/`)

- **[`app_store_privacy_support/index.html`](file:///c:/Users/theak/source/repos/cuedeck/app_store_privacy_support/index.html):** Google Play Console ve App Store Connect için çift dilli (TR/EN), Soft Slate (`#141824` / `#E6C17A`) tasarımlı resmi Gizlilik Politikası (KVKK/GDPR) ve Sıkça Sorulan Sorular / Destek merkezi.
- **[`app_store_privacy_support/support.html`](file:///c:/Users/theak/source/repos/cuedeck/app_store_privacy_support/support.html):** App Store Connect "Support URL" alanı için `index.html#support` sekmesine otomatik yönlendirme sayfası.
- **[`app_store_privacy_support/indir.html`](file:///c:/Users/theak/source/repos/cuedeck/app_store_privacy_support/indir.html):** WhatsApp, Telegram ve sosyal medya paylaşımlarında zengin önizleme kartı (OpenGraph) çıkaran; giren kullanıcının cihazını (iOS/macOS vs Android) algılayarak ilgili mağaza veya doğrudan APK indirme butonunu öne çıkaran Akıllı İndirme & Paylaşım Portalı.
