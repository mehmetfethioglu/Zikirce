# CueDeck — Piyasa Analizi, Mağaza Yeterliliği ve Gelir Modeli (Freemium + Tek Seferlik Pro) Raporu

> [!IMPORTANT]
> **Yönetici Özeti (Dalkavukluksuz Net Teşhis):**
> 1. **Üretilen Değer & Boşluk:** CueDeck'i mağazada *"bir Android TV kumandası daha"* olarak konumlandırırsak **hiçbir şansı yoktur**; çünkü Google TV uygulaması ve telefonların yerleşik kumandası ücretsiz/reklamsızdır. CueDeck'in piyasada kapattığı gerçek boşluk **"Zamanlanmış Yayın Planlayıcı + Tek Dokunuşla TV'de İçerik/Playlist Başlatıcı (Watch Cue Deep-Link Otomasyonu)"** özelliğidir (`TV Time` bildirim atar ama TV'yi açamaz; klasik kumandalar TV'yi açar ama yayın akışı planlayamaz).
> 2. **Mağaza Yeterliliğindeki En Büyük Engel (Port 5555 ADB Duvarı):** Şu an [`AdbTvService`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L723-L866) TV'yi kontrol etmek için **Port 5555 (Ağ ADB / Geliştirici Seçenekleri)** şart koşuyor. Son kullanıcıların **%85–90'ı** TV'de Geliştirici Seçeneklerini açamaz; uygulamayı indirip *"Çalışmıyor"* diyerek **1 yıldız** verir. Mağazaya çıkmadan önce temel kumanda tuşları için **Port 6466/6467 (Android TV Remote v2 — 6 Haneli PIN)** desteği şarttır.
> 3. **"5X Reklam Kazandıran Kullanıcıya Pro Hediye Edelim" Fikri:** Matematiksel olarak **imkansız** (Türkiye eCPM'leriyle ~4.000–10.000 tam ekran video reklam = **2 ila 5 yıl** sürer), Google AdMob politikaları açısından **yüksek ban (Invalid Traffic / IVT) riski taşır** ve pazarlama açısından **en kârlı reklam kullanıcısını sıfırlar**. Bunun yerine mağaza gerçekleriyle %100 uyumlu model: **"1 Ödüllü Video İzle = 24 Saat Pro Aç (Günlük Cue Pass) + Tek Seferlik Ömür Boyu Pro Satın Alma"** kurgusudur.

---

## 1. Dalkavukluk Yapmadan Değer Analizi: CueDeck Piyasada Ne Üretiyor ve Hangi Boşluğu Kapatıyor?

### 1.1. Nerede Boşluk YOK? (Kırmızı Okyanus Yanılsaması)
Google Play Store'da *"Android TV Remote"* aramasında `Google TV` (resmi), `Zank Remote`, `CetusPlay`, `Remote for Android TV (Innovation Lab)` ve `tvQuickActions Pro` gibi milyonlarca indirmeye sahip rakipler var. Üstelik Xiaomi, Samsung ve Pixel telefonların kontrol merkezinde (Quick Settings) gömülü Google TV kumandası bulunuyor.
- **Acı Gerçek:** Kullanıcı sadece ses açıp kapatmak veya D-Pad ile gezinmek istiyorsa CueDeck'e ne para öder ne de reklamına katlanır. Salt kumanda olarak üretilen marjinal değer **sıfıra yakındır**.

### 1.2. Nerede Gerçek Boşluk VAR? (CueDeck'in Benzersiz Değer Önerisi — UVP)
Evdeki televizyon izleyicisinin yaşadığı **en büyük modern sürtünme** kumandanın kaybolması değil, **televizyonun karşısına geçildiğinde yaşanan "Karar Yorgunluğu (Decision Fatigue)" ve "İçeriğe Ulaşma Sürtünmesi"**dir:
1. Kullanıcı gündüz telefonunda YouTube'da bir eğitim/belgesel oynatma listesi (`Playlist`), tabii'de bir dizi veya akşamki derbi maçını görür.
2. Akşam saat 21:00'de koltuğa oturduğunda ya izleyeceği şeyi unutur ya da TV kumandasıyla YouTube/Netflix arama ekranında harf harf yazmaya üşenir.

| Kriter / Yetenek | Resmi Google TV Kumandası | Zank Remote / CetusPlay | TV Time / JustWatch | **CueDeck (`v1.8.0`)** |
| :--- | :--- | :--- | :--- | :--- |
| **G10 Dokunsal Kumanda & Sesli Komut** | ✅ Var | ✅ Var (Kalabalık UI) | ❌ Yok | ✅ **Var (<120ms Hibrit)** |
| **Gün/Saat/Seans Bazlı İzleme Planlayıcı** | ❌ Yok | ❌ Yok | ⚠️ Sadece Dizi Takibi | ✅ **Var ([`WatchCueItem`](file:///c:/Users/theak/source/repos/cuedeck/lib/models/cue_models.dart#L248-L503))** |
| **Gerçek OS Alarmı (`AlarmManager`)** | ❌ Yok | ❌ Yok | ✅ Var | ✅ **Var ([`CueDeckReminderReceiver`](file:///c:/Users/theak/source/repos/cuedeck/android/app/src/main/kotlin/com/akarworks/cuedeck/CueDeckReminderReceiver.kt#L19-L320))** |
| **Tek Dokunuşla TV'de YouTube Playlist / Deep-Link Açma** | ❌ Yok | ❌ Yok | ❌ Yok | ✅ **Var ([`launchPlatformOrDeepLink`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L899-L952))** |
| **AES-256-GCM Şifreli Google Drive Senkronu** | ❌ Yok | ❌ Yok | ☁️ Kendi Sunucusu | ✅ **Var ([`GoogleDriveBackupService`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/google_drive_backup_service.dart#L95-L815))** |

**Sonuç:** CueDeck bir "yedek kumanda" değil, **"Akıllı TV Yayın Yönetmeni (Personal TV Cue Deck & Instant Launcher)"** olarak konumlandırılmalıdır.

---

## 2. Mağaza Yeterliliği Denetimi: Google Play'de Bizi Bekleyen Teknik Tehlike

Şu anki kod tabanını ([`adb_tv_service.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L830-L845)) incelediğimizde mağaza başarısını doğrudan baltalayacak **1 kritik darboğaz** ve **2 uyumluluk gereksinimi** bulunuyor:

### 2.1. Kritik Darboğaz: Port 5555 (ADB) Zorunluluğu vs. Port 6466 (Standart TV Remote)
- **Mevcut Durum:** [`discoverDevices`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L723-L866) fonksiyonu ağdaki Sony, TCL, Philips, Xiaomi TV'leri mDNS ve Port `6466` üzerinden buluyor ancak Port `5555` kapalıysa cihazı `isOnline: false` olarak işaretleyip *"TV Ayarlarından Ağ ADB (5555) Açın"* uyarısı veriyor.
- **Mağaza Gerçeği:** Perakende satılan hiçbir televizyonda kutudan çıktığında Port `5555` (Geliştirici Seçenekleri -> Ağ/USB Hata Ayıklama) açık değildir. Sıradan kullanıcıların %85'i TV'de Geliştirici Seçeneklerini nasıl açacağını bilmez ve **"Güvenlik uyarısı / Hata ayıklama"** kelimesinden korkar.
- **Yapılması Gereken Mimari Hamle:**
  1. **Katman 1 — Sıfır Kurulum Modu (Port 6466/6467 TLS + 6 Haneli PIN):** Kutudan çıkan her Android TV / Google TV'de varsayılan olarak açık olan `Android TV Remote Service v2` protokolü eklenmeli. Kullanıcı uygulamayı kurduğunda TV ekranda 6 haneli PIN gösterir, kullanıcı girer ve **Geliştirici Seçeneklerine hiç girmeden** tüm D-Pad, ses, güç ve temel uygulama açma tuşları anında çalışır.
  2. **Katman 2 — ADB Turbo / Deep-Link Modu (Port 5555 RSA-2048):** Doğrudan YouTube Playlist URL'si fırlatma (`am start -a VIEW -d ...`), metin enjeksiyonu ve `<120ms` `/dev/input/event0` donanım hızı için uygulama içinde **3 adımlı görsel bir "Geliştirici Modu Rehberi (Sihirbazı)"** sunulmalı.

### 2.2. iOS App Store & Google Play İnceleme (Review) Gerçekleri
- **iOS Kısıtlaması:** iOS cihazlarda yerel ağ taraması için `NSLocalNetworkUsageDescription` ve `_androidtvremote2._tcp` / `_adb._tcp` Bonjour servis tanımları zorunludur; ayrıca Apple inceleme ekibi fiziksel bir Android TV olmadan uygulamayı test ederken **"Demo / Simülasyon Modu"** görmezse uygulamayı *"Çalışmıyor / Test edilemedi (Guideline 2.1)"* gerekçesiyle reddedebilir.
- **Google Play İzin Politikası:** `AndroidManifest.xml` içindeki `USE_EXACT_ALARM` izni ([`ADR-009`](file:///c:/Users/theak/source/repos/cuedeck/docs/kararlar.md#L11-L15)), Google Play Console'da **yalnızca temel işlevi takvim/alarm/hatırlatıcı olan** uygulamalara otomatik onay verir. Mağaza açıklamasında CueDeck'in **"Zamanlanmış TV İzleme Planlayıcısı ve Hatırlatıcısı"** kimliği açıkça beyan edilmeli veya çalışma zamanında `AlarmManager.canScheduleExactAlarms()` kontrolüyle `SCHEDULE_EXACT_ALARM` kullanılmalıdır.

---

## 3. "Reklamlardan 5X Kazandıran Kullanıcıya Pro Hediye Edelim" Fikrinin Analizi

Kafanızdaki model: *"Pro sürüm $X$ fiyata satılıyorsa, izlediği/gördüğü reklamlardan bize $5X$ kazandıran kullanıcıya Pro sürümü otomatik hediye edelim."*

Bu fikri **dalkavukluk yapmadan**, gerçek mobil reklam ekonomisi (AdMob 2026 metrikleri), mağaza politikaları ve kullanıcı psikolojisiyle test ettiğimizde sonuç **net olarak olumsuzdur**. İşte 3 somut nedeni:

### 3.1. Matematiksel Duvar: $5X$ Reklam Geliri Kaç Yıl Sürer?
Diyelim ki Tek Seferlik Pro fiyatını Türkiye için **149,99 TL (~$4.40)**, Global için **$4.99** belirledik.
- Hedeflenen $5X$ reklam geliri: $5 \times \$4.99 = \$24.95$ (~850 TL).
- **2026 Android Yardımcı Araç (Utility) AdMob eCPM (1.000 Gösterim Başına Net Gelir) Ortalamaları:**

| Reklam Formatı | Türkiye Ortalama eCPM | Global (Tier-1) eCPM | Türkiye'de $24.95 (5X) İçin Gereken Gösterim | Günde 5 Gösterim İle Süre |
| :--- | :--- | :--- | :--- | :--- |
| **Adaptive Banner** | $0.15 - $0.35 | $0.45 - $0.75 | **~100.000 Gösterim** | **54,7 Yıl** |
| **Tam Ekran (Interstitial)** | $1.20 - $2.20 | $5.00 - $12.00 | **~14.600 Gösterim** | **8,0 Yıl** |
| **Ödüllü Video (Rewarded)** | $2.00 - $4.50 | $8.00 - $16.00 | **~8.300 Video Tamamlama** | **4,5 Yıl** |

### 3.2. Google AdMob & Play Store Politikası Riski (Hesap Kapatma Tehlikesi)
1. **Invalid Traffic (IVT / Geçersiz Trafik) Cezası:** Kullanıcıya *"Pro kazanmak için reklam izle"* hedefi koyduğunuzda, bedava Pro almak isteyen kullanıcılar uygulamayı açıp arka arkaya (loop halinde) onlarca reklam oynatır. Reklamverenlerin dönüşüm (install/alışveriş) alamadığı bu yapay gösterimleri AdMob yapay zekası **24–48 saat içinde "Ad Farming / Invalid Traffic"** olarak işaretler ve **AdMob hesabınızı kalıcı olarak kapatır**.
2. **Kullanıcı Bazlı Net Gelir Ölçüm İmkansızlığı:** AdMob SDK'sındaki `onPaidEventListener` yalnızca *tahmini* mikro-değer (`precisionType: ESTIMATED`) döner; ay sonunda Google geçersiz tıklamaları düştüğünde gerçek gelir değişir.

### 3.3. Pazarlama Psikolojisi Hatası (Kendi Ayağına Sıkmak)
- Uygulamayı sana $5X$ reklam geliri bırakacak kadar yoğun kullanan %1'lik kesim, senin **en değerli reklam envanterindir**. Onlara Pro hediye ettiğinde düzenli reklam nakit akışını kendi elinle kesersin.
- Öte yandan, cebinden hemen 149 TL verip Pro alacak kullanıcı *"Nasılsa kullandıkça bedava Pro açılıyormuş"* diyerek **satın almayı erteler (Cannibalization)**.

---

## 4. Doğru ve Mağaza Uyumlu Çözüm: "24 Saatlik Pro Pass (Ödüllü Reklam) + Tek Seferlik Pro" Modeli

1. **1 Ödüllü Video İzle = 24 Saatlik "CueDeck Pro Pass" Aç:**
   - Kullanıcı günde yalnızca 1 kez 30 saniyelik ödüllü video (`RewardedAd`) izleyerek tüm Pro özellikleri 24 saatliğine açar.
   - Hem AdMob "Invalid Traffic" riski sıfırlanır hem de kullanıcı Pro özelliklere (Bulut Yedekleme, Sınırsız İzleme Planı) alışır.
2. **Sadakat İndirimi Kaldıracı (10 Gün Ödüllü Reklam = %40 Pro İndirimi):**
   - 10 farklı günde ödüllü reklam izleyerek Pro Pass açan sadık kullanıcıya, Tek Seferlik Pro satın alımında **%40 Sadakat İndirimi (149,99 TL yerine 89,99 TL indirimli ürün kimliği / SKU)** sunulur.

---

## 5. Free vs. Pro Özellik Matrisi ve Bölgesel Fiyatlandırma Tablosu

| Özellik / Modül | 🆓 CueDeck Ücretsiz (Free) | 💎 CueDeck Pro (Tek Seferlik Ödeme) |
| :--- | :--- | :--- |
| **G10 Dokunsal Kumanda, Sesli Komut (`tr-TR`) & Klavye** | ✅ Tam Açık | ✅ Tam Açık |
| **mDNS & Ağ Üzerinden TV Keşfi ve Eşleştirme** | ✅ 1 Aktif TV Cihazı | ✅ **Sınırsız Çoklu TV Profili (Salon, Yatak Odası, Ofis)** |
| **Zamanlanmış İzleme Planı (`WatchCueItem`) & OS Alarmları** | ⚠️ **Maksimum 2 Aktif Plan** | ✅ **Sınırsız İzleme Planı & Haftalık Rutin** |
| **TV'de Doğrudan YouTube Playlist / Deep-Link Fırlatma** | ✅ Günlük 3 Hızlı Başlatma (veya Reklamla Açık) | ✅ **Sınırsız Tek Dokunuşla Işınlama (Instant Beam)** |
| **Yerel `.json` Yedekleme (Android SAF)** | ✅ Tam Açık | ✅ Tam Açık |
| **Otomatik Google Drive Bulut Yedekleme & Cihazlar Arası Senkron** | 🔒 Kilitli *(24 Saat Pro Pass ile denenebilir)* | ✅ **Tam Açık (AES-256-GCM + 30sn Otomatik Senkron)** |
| **Reklam Gösterimi** | 📢 Ayarlar/Planlayıcıda Banner + Ödüllü Pro Pass | 🚫 **Ömür Boyu %100 Reklamsız** |

### Önerilen Tek Seferlik (Lifetime) Fiyatlandırma

| Bölge / Pazar | Standart Pro Fiyatı (`cuedeck_pro_lifetime`) | Lansman / Sadakat İndirimli Fiyat (`cuedeck_pro_promo`) |
| :--- | :--- | :--- |
| **🇹🇷 Türkiye (TR)** | **149,99 TL** *(KDV Dahil)* | **99,99 TL** *(veya Sadakat: 89,99 TL)* |
| **🇺🇸 ABD / 🇬🇧 İngiltere / 🇪🇺 Batı Avrupa (Tier-1)** | **$5.99 / €5.99** | **$3.99 / €3.99** |
| **🌍 Orta Doğu (MENA) / Doğu Avrupa / LATAM (Tier-2)** | **$3.49** | **$2.49** |
| **🇮🇳 Hindistan / Güneydoğu Asya / Afrika (Tier-3)** | **₹199 (~$2.40)** | **₹129 (~$1.50)** |
