# CueDeck — Google Play & App Store Mağaza Vitrin (ASO) ve SKU Paketi (`v1.9.0+12`)

## 1. Mağaza Kimliği ve ASO Başlıkları (TR / EN)

### 🇹🇷 Türkçe (TR) Vitrin Metinleri
- **Uygulama Adı (30/50 Karakter):** `CueDeck: Akıllı TV Kumandası & İzleme Planlayıcı`
- **Kısa Açıklama (79 Karakter):** `Google TV & Android TV kumandası, zamanlanmış izleme planlayıcı ve playlist açıcı`
- **Uzun Açıklama (ASO Optimize):**
  > **Televizyonun Karşısına Geçtiğinizde "Ne İzlesem?" Karmaşasına Son Verin!**
  >
  > **CueDeck**, tüm Android TV ve Google TV cihazları (Sony Bravia, TCL, Philips, Xiaomi Mi Box/Stick, Chromecast, Redline vb.) için tasarlanmış **Google TV G10 referans dokunsal kumandayı** ve **Kişisel Zamanlanmış Yayın Planlayıcısını (Watch Cue)** tek bir uygulamada birleştirir.
  >
  > **🔥 CueDeck Hangi Boşluğu Kapatır?**
  > Klasik dizi takip uygulamaları size sadece bildirim gönderir ama televizyonunuzu kontrol edemez. Klasik kumanda uygulamaları ise sadece tuş basar ama yayın akışınızı bilmez. **CueDeck**, planladığınız saat geldiğinde telefonunuza bildirim gönderir ve **tek dokunuşla televizyonunuzda ilgili YouTube Oynatma Listesini (Playlist), Netflix, tabii, beIN CONNECT veya Tivibu yayınını anında başlatır!**
  >
  > **✨ Temel Özellikler:**
  > - **Çift Protokol TV Bağlantısı (Port 6466 PIN & Port 5555 ADB Turbo):** Kutudan çıkan standart televizyonlarla 6 haneli PIN koduyla sıfır kurulumla eşleşin veya ADB Turbo moduyla `<120ms` donanım hızında doğrudan YouTube Playlist linklerini TV'ye ışınlayın.
  > - **Zamanlanmış İzleme Planlayıcı & Gerçek OS Alarmları:** Günlük, hafta içi, hafta sonu veya seçili günlerde saat ve seans süresi belirleyin; kaldığınız dakikayı ve videoyu otomatik takip edin.
  > - **Türkçe Sesli Komut & Akıllı Arama:** Telefon mikrofonuna konuşarak TV sesini yönetin, kanal değiştirin veya doğrudan YouTube'da arama başlatın.
  > - **Gerçek Siyah (#000000 AMOLED) & Klasik Beyaz G10 Tema:** Göz yormayan gece modu ve yüksek kontrastlı gündüz modu.
  > - **Şifreli Google Drive & Yerel JSON Yedekleme:** `AES-256-GCM` donanım şifrelemesiyle izleme planlarınızı tüm cihazlarınızda eşitleyin.
  > - **Abonelik Yok! (Pay Once, Forever Yours):** İster 1 kısa video reklam izleyerek **24 Saatlik Pro Pass** açın, ister tek seferlik ödemeyle ömür boyu reklamsız **CueDeck Pro** sahibi olun.

---

### 🇺🇸 İngilizce (EN) Storefront Listing
- **App Title:** `CueDeck: Smart TV Remote & Watch Planner`
- **Short Description:** `Universal Google TV & Android TV remote, watch scheduler & YouTube playlist launcher`
- **Full Description:**
  > **Stop Scrolling Endless Menus — Beam Your Planned Watchlist Directly to Your TV!**
  >
  > **CueDeck** combines a tactile **Google TV G10 Reference Remote** with a **Personal Scheduled Watch Planner**. When your scheduled watch time arrives, tap the notification on your phone to instantly wake your Android TV / Google TV and launch your exact YouTube Playlist, Netflix, or live sports stream.
  >
  > - **Dual-Protocol Connectivity:** Zero-config Port 6466 (6-Digit PIN) for standard retail TVs + Port 5555 (ADB RSA-2048 Turbo) for `<120ms` key injection and instant Deep-Link URL beaming.
  > - **No Subscriptions:** Unlock 24 hours of Pro features with a single rewarded video ad, or buy **CueDeck Pro Lifetime** once and own it forever!

---

## 2. Google Play Console & App Store Connect Uygulama İçi Ürün (IAP SKU) Tanımları

| Ürün Kimliği (SKU) | Tür | Türkiye Fiyatı | Global (USD/EUR) | Açıklama |
| :--- | :--- | :--- | :--- | :--- |
| `cuedeck_pro_lifetime` | Tek Seferlik (Non-Consumable) | **99,99 ₺** *(Lansman)* / **149,99 ₺** *(Standart)* | **$3.99** *(Launch)* / **$5.99** *(Standard)* | Ömür boyu reklamsız kullanım, sınırsız izleme planı ve otomatik Google Drive bulut senkronizasyonu. |
| `cuedeck_pro_loyalty_40` | Tek Seferlik (Non-Consumable) | **89,99 ₺** | **$3.49** | 10 farklı günde 24 Saatlik Pro Pass açan sadık kullanıcılara özel %40 indirimli ömür boyu Pro lisansı. |
