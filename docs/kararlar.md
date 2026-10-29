# CueDeck — Mimari Karar & Anti-Pattern Defteri (ADR & Karpathy Lessons Learned)

## [ADR-017] 2026-10-29: Gerçek Siyah (`#000000`) Ayarlar Sayfası, `🔍 Ağdaki Cihazları Ara` Butonu, 3 Adımda Kolay Eşleştirme Yönlendirmesi ve Özelleştirilebilir 6'lı Kumanda Uygulama Tuşları
- **Tarih & Ajanlar:** `2026-10-29` — Kanuni, Mimar Sinan, Kâtip Çelebi (Denetçiler: Matrakçı & Ebussuud — `KARAR: GEÇTİ`)
- **Karar & Uygulanan Değişiklikler:**
  1. **Koyu Temada Gerçek Siyah (`#000000`) Ayarlar Sayfası ([`CueDeckSettingsScreen`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1210-L1240)):** Ayarlar sayfası koyu temada `Colors.black` (`#000000`) zemin ve `#0A0C12` derin obsidiyen kart yüzeylerine geçirilerek G10 kumanda gövdesiyle tam görsel bütünlük sağlandı.
  2. **`🔍 Ağdaki Cihazları Ara` Butonu & 3 Adımda Kolay Eşleştirme Yönlendirmesi ([`CueDeckSettingsScreen`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1562-L1705), [`_TvSetupGuideSheet`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L2668-L2735)):** TV Bağlantı kartının en üstüne tam genişlikli **`🔍 Ağdaki Cihazları Ara`** butonu, bulunan TV'leri canlı durum ikonuyla (`🟢`/`⚪`) seçme çipleri ve kart içinde **"3 Adımda Kolay Eşleştirme & Bağlantı"** yönlendirme kutusu eklendi.
  3. **Kumanda Üzerindeki 6 Uygulama Tuşunu Değiştirme Özelliği ([`StreamingPlatform`](file:///c:/Users/theak/source/repos/cuedeck/lib/models/cue_models.dart#L5-L125), [`CueDeckNotifier.updateRemoteShortcutSlot`](file:///c:/Users/theak/source/repos/cuedeck/lib/providers/cuedeck_providers.dart#L734-L756), [`QuickLaunchAppDock`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L809-L879), [`_RemoteShortcutCustomizationCard`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L2013-L2189), [`_RemoteShortcutPickerSheet`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L2191-L2306)):**
     - `StreamingPlatform` kataloğu 16 popüler TV uygulamasına (`YouTube`, `Netflix`, `beIN`, `tabii`, `Tivibu`, `Zikirce`, `Prime Video`, `Disney+`, `Exxen`, `Max / BluTV`, `S Sport+`, `TOD TV`, `Spotify`, `Twitch`, `Kodi / IPTV`, `VLC Player`) çıkarıldı.
     - Kullanıcılar hem doğrudan kumanda üzerindeki 6 uygulama tuşundan herhangi birine **basılı tutarak (`onLongPress`)** hem de Ayarlar ekranındaki **"Kumanda Uygulama Tuşları (6 Yuva)"** kartından diledikleri tuşu değiştirebilir veya varsayılana sıfırlayabilir (`SharedPreferences` `cuedeck_remote_shortcuts_v1`).

---

## [ADR-016] 2026-10-29: iPhone 17 Pro Max & Xiaomi 14 Çoklu Cihaz Eşzamanlı TV Kontrolü (`_scheduleIdleDisconnect`), iOS `en0` Gruplu Ağ Taraması ve Yerel Ağ İzni Sonrası Otomatik Yeniden Tarama
- **Tarih & Ajanlar:** `2026-10-29` — Kanuni, El-Cezeri & Piri Reis, Ali Kuşçu, Kâtip Çelebi (Denetçiler: Ebussuud — `KARAR: GEÇTİ`)
- **Bağlam:**
  1. Kullanıcı **Xiaomi 14** (Android) ve **iPhone 17 Pro Max** (iOS TestFlight `v1.9.3+15`) cihazlarını aynı Wi-Fi ağında test ederken Xiaomi 14'ün TV'ye bağlandığını ancak iPhone 17 Pro Max'in bağlanamadığını bildirdi.
  2. **Kök Neden 1 (`adbd` Tek İstemci Kilidi):** Android TV üzerindeki `adbd` (TCP Port `5555`) aynı anda yalnızca **1 aktif TCP transport bağlantısını** kabul eder. Xiaomi 14 üzerinde CueDeck açıkken kalıcı `_socket` hiç kapatılmadığı için TV, iPhone 17 Pro Max'ten gelen `CNXN` el sıkışmasını bekletiyordu.
  3. **Kök Neden 2 (iOS `NSLocalNetworkUsageDescription` İlk Açılış Yarışı & 52 Soket ARP Taşması):** iOS'ta uygulama ilk açıldığında *"CueDeck yerel ağınızdaki cihazları bulmak ve bunlara bağlanmak istiyor"* sistem penceresi ekrandayken ilk `scanNetworkForTvs()` çağrısı `EHOSTDOWN`/`ENOBUFS` ile reddediliyor; ayrıca 52 IP'ye aynı anda paralel `Socket.connect` açılması iOS XNU `en0` ARP kuyruğunu dolduruyordu.
- **Karar & Çözüm:**
  1. **6 Saniye Hareketsizlikte Otomatik Soket Serbest Bırakma ([`AdbTvService._scheduleIdleDisconnect`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L243-L250)):** Tuş basımı bittikten 6 saniye sonra `_socket` otomatik kapatılır; sonraki tuş basımında ~35ms içinde yeniden bağlanır. Böylece Xiaomi 14 ve iPhone 17 Pro Max aynı anda açık olsa bile TV'yi sırayla kesintisiz kontrol edebilir.
  2. **iOS `en0` Öncelikli 10'arlı Gruplu (`batchSize = 10`) Alt Ağ Keşfi & Otomatik RSA Onay Süresi Uzatma ([`AdbTvService.discoverDevices`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L873-L1045), [`AdbTvService._connectInternal`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L358-L382)):** iOS'ta zaman aşımı `950ms`/`620ms` olarak optimize edildi, paralel soket sayısı 10'arlı gruplara bölündü ve ilk bağlantıda RSA onayı gerekiyorsa bekleme süresi otomatik +14 saniye uzatıldı.
  3. **iOS Yerel Ağ İzni Sonrası 4. Saniyede Otomatik Yeniden Tarama ([`CueDeckNotifier._initializeAsync`](file:///c:/Users/theak/source/repos/cuedeck/lib/providers/cuedeck_providers.dart#L314-L334)):** İlk açılış taramasında TV çevrimdışı dönerse (kullanıcı iOS "İzin Ver" butonuna basarken), 4 saniye sonra otomatik ikinci tarama (`_initialRetryTimer`) tetiklenir.

---

## [ADR-015] 2026-10-28: Uygulama İçi Sürüm Notları (`CueReleaseNotesService` & `showCueWhatsNewModal`), İlk Açılış Yenilikler Kartı ve GitHub Actions iOS TestFlight Dağıtımı (`v1.9.3+15`)
- **Tarih & Ajanlar:** `2026-10-28` — Kanuni, Mimar Sinan, Barbaros Hayreddin Paşa, Kâtip Çelebi (Denetçiler: Matrakçı & Ebussuud — `KARAR: GEÇTİ`, `8/8` test başarılı)
- **Karar & Uygulanan Değişiklikler:**
  1. **Uygulama İçi Sürüm Notları & İlk Açılış Algılayıcısı ([`cue_release_notes_service.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/cue_release_notes_service.dart#L1-L162), [`CueDeckHomeScreen`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L17-L56), [`showCueWhatsNewModal`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L4722-L5028)):**
     - `SharedPreferences` (`cuedeck_last_seen_release_version`) üzerinden çalışan sürüm ile son görülen sürümü karşılaştırarak güncelleme sonrası ilk açılışta otomatik olarak **"🎉 CueDeck Güncellendi!"** alt çekmecesini açar ve kullanıcıya yeni sürümde neler değiştiğini gösterir.
     - Ayrıca [`CueDeckSettingsScreen`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1357-L1395) içerisine eklenen **`📋 Sürüm Notları (v1.9.3)`** rozet butonu ile kullanıcı dilediği an hem aktif sürümü hem de geçmiş sürümleri (`v1.9.3`, `v1.9.1`, `v1.8.0`, `v1.7.0`) inceleyebilir.
  2. **GitHub Actions iOS TestFlight Hazırlığı ([`ios/Podfile`](file:///c:/Users/theak/source/repos/cuedeck/ios/Podfile#L1-L45), [`ios-build.yml`](file:///c:/Users/theak/source/repos/cuedeck/.github/workflows/ios-build.yml#L1-L128), [`Fastfile`](file:///c:/Users/theak/source/repos/cuedeck/ios/fastlane/Fastfile#L1-L185)):**
     - `ios/Podfile` (`platform :ios, '15.0'`), `project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET = 15.0`), `Info.plist` (`ITSAppUsesNonExemptEncryption = false`) ve 19 adet alfasız RGB `AppIcon.appiconset` ikonu oluşturularak GitHub Actions `macos-latest` TestFlight derlemesi başlatıldı.

---

## [ADR-014] 2026-10-28: Gerçek Google AdMob (`google_mobile_ads`), Gerçek Mağaza Ödeme Doğrulaması (`in_app_purchase`), Ana Kumanda Alt Banner, `149,99 ₺` Ömür Boyu Pro ve Pro/Pass Sıfırlama (`v1.9.2+14`)
- **Tarih & Ajanlar:** `2026-10-28` — Kanuni, Mimar Sinan, El-Cezeri & Piri Reis, Kâtip Çelebi, Barbaros (Denetçiler: El-Kindi, Ali Kuşçu, Matrakçı, Ebussuud — `KARAR: GEÇTİ`)
- **Karar & Çözülen Sorunlar:**
  1. **Gerçek `google_mobile_ads` (`^9.2.0`) SDK & Platform Bazlı Birim Yapılandırması ([`CueAdMobConfig`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/cue_monetization_service.dart#L16-L63), [`AndroidManifest.xml`](file:///c:/Users/theak/source/repos/cuedeck/android/app/src/main/AndroidManifest.xml#L44-L47), [`Info.plist`](file:///c:/Users/theak/source/repos/cuedeck/ios/Runner/Info.plist#L11-L30)):**
     - **Android (Kapalı Test Güvenli Modu):** AdMob Invalid Traffic (IVT) kurallarına tam uyum için resmi Google Test Uygulama Kimliği (`ca-app-pub-3940256099942544~3347511713`), Test Banner (`ca-app-pub-3940256099942544/6300978111`) ve Test Rewarded (`ca-app-pub-3940356099942544/5224354917`) birimleri bağlandı.
     - **iOS (Üretim Modu):** Resmi CueDeck iOS AdMob Uygulama Kimliği (`ca-app-pub-8040358402439788~5365691448`), iOS Banner (`ca-app-pub-8040358402439788/7325640375`) ve iOS Rewarded (`ca-app-pub-8040358402439788/1390787414`) birimleri + `SKAdNetworkItems` tanımlandı.
  2. **Gerçek Mağaza Ödeme Doğrulaması (`in_app_purchase: ^3.3.1`), `149,99 ₺` Fiyat ve Pro/Pass Sıfırlama ([`CueProProductCatalog`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/cue_monetization_service.dart#L66-L99), [`purchaseLifetimePro`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/cue_monetization_service.dart#L564-L682), [`_CueDeckProPassAndUpgradeSection`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L2010-L2040)):**
     - Tek Seferlik Ömür Boyu Pro fiyatı **`149,99 ₺`** (`cuedeck_pro_lifetime`), 10 günlük %40 Sadakat İndirimi fiyatı **`89,99 ₺`** (`cuedeck_pro_loyalty_40`) olarak güncellendi.
     - `"💎 Pro Al (149,99 ₺)"` butonuna basıldığında gerçek cihazlarda `InAppPurchase.instance.buyNonConsumable` üzerinden Google Play Billing / Apple StoreKit 2 ödeme penceresi sorgulanır; mağaza ödemesi doğrulanmadan `isProLifetime` asla aktifleşmez.
     - Kasa anahtarı `'cuedeck_entitlement_vault_v3'` yapılarak test sırasında yanlışlıkla aktifleşen Pro durumu otomatik temizlendi; ayrıca hem `isProLifetime` hem de `isPassActive` durumunda `"Ücretsiz Sürüme Dön (Test Pro / Pass Sıfırla)"` butonu görünür kılındı.
  3. **Ana Kumanda Ekranı (`CueDeckHomeScreen`) ve Ayarlar Ekranı (`CueDeckSettingsScreen`) Altında Sabitlenmiş Gerçek AdMob `BannerAd` ([`_CueNonIntrusiveAdBanner`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L2047-L2212)):**
     - Gerçek `AdWidget(ad: _bannerAd)` (`320x50`) hem ana kumanda ekranının en altına (`showQuickRemoveAction: true` — `"🎬 24s Kaldır"` hap butonu ile) hem de Ayarlar sayfasının en altına sabitlendi.

---

## [ADR-013] 2026-10-28: Barbaros `store-commander` Yeteneği — Play Console, Akıllı Paylaşım Portalları ve GitHub Actions Üzerinden App Store Connect TestFlight & Review Otomasyonu (`v1.9.1+13`)
- **Tarih & Ajanlar:** `2026-10-28` — Kanuni, Barbaros Hayreddin Paşa (`store-commander`), Kâtip Çelebi (Denetçiler: El-Kindi & Ebussuud — `KARAR: GEÇTİ`)
- **Karar & Uygulanan Altyapı:**
  1. **Barbaros `store-commander` Yeteneği ([`agent.md`](file:///c:/Users/theak/source/repos/cuedeck/.agent/agents/barbaros/agent.md), [`SKILL.md`](file:///c:/Users/theak/source/repos/cuedeck/.agent/skills/store-commander/SKILL.md)):** Barbaros Hayreddin Paşa hem global (`~/.gemini/config/`) hem de çalışma alanı düzeyinde Google Play Console, Akıllı Paylaşım/Gizlilik portalları ve GitHub Actions App Store Connect (TestFlight + Review) otomasyon yetenekleriyle donatıldı.
  2. **GitHub Actions & Fastlane iOS TestFlight + Otomatik App Store Review ([`ios-build.yml`](file:///c:/Users/theak/source/repos/cuedeck/.github/workflows/ios-build.yml), [`appstore-release.yml`](file:///c:/Users/theak/source/repos/cuedeck/.github/workflows/appstore-release.yml), [`ios/fastlane/Fastfile`](file:///c:/Users/theak/source/repos/cuedeck/ios/fastlane/Fastfile)):**
     - `POST /v1/bundleIds` ve `fastlane produce --skip_itc` ile `com.akarworks.cuedeck` Bundle ID kaydını Apple Developer Portal üzerinde otomatik tescil eder.
     - `macos-latest` üzerinde `CueDeck.ipa` imzalayıp TestFlight'a yükler; `appstore-release.yml` ise `ES256` JWT ile `1.9.1` sürümünü oluşturur, TR/EN `whatsNew` notlarını yazar, Build `13`'ü bağlar ve `reviewSubmissions` API'si ile doğrudan Apple İncelemesine gönderir.
  3. **Google Play Console Otomasyonu & Akıllı Paylaşım/Gizlilik Portalları ([`playstore-release.yml`](file:///c:/Users/theak/source/repos/cuedeck/.github/workflows/playstore-release.yml), [`android/fastlane/Fastfile`](file:///c:/Users/theak/source/repos/cuedeck/android/fastlane/Fastfile), [`app_store_privacy_support/index.html`](file:///c:/Users/theak/source/repos/cuedeck/app_store_privacy_support/index.html), [`indir.html`](file:///c:/Users/theak/source/repos/cuedeck/app_store_privacy_support/indir.html), [`RELEASE_NOTES_v1.9.1_b13.md`](file:///c:/Users/theak/source/repos/cuedeck/docs/RELEASE_NOTES_v1.9.1_b13.md), [`PLAY_CONSOLE_VE_APP_STORE_OPERASYON_REHBERI.md`](file:///c:/Users/theak/source/repos/cuedeck/docs/PLAY_CONSOLE_VE_APP_STORE_OPERASYON_REHBERI.md)):**
     - Çift dilli (TR/EN) KVKK/GDPR uyumlu Gizlilik Politikası & Destek sayfası, OpenGraph destekli Akıllı İndirme sayfası ve Play Console/App Store operasyon kılavuzu oluşturuldu ve `mehmetfethioglu/cuedeck-indir` GitHub Pages (`https://mehmetfethioglu.github.io/cuedeck-indir/`) üzerinde canlıya alındı.

---

## [ADR-012] 2026-10-28: Yumuşak Paletli Modern Ayarlar Arayüzü (`CueDeckSettingsScreen`) ve Google Play / Apple App Store Üretim Paketi Hazırlığı (`v1.9.1+13`)
- **Tarih & Ajanlar:** `2026-10-28` — Kanuni, Mimar Sinan, El-Cezeri & Piri Reis, Kâtip Çelebi, Barbaros (Denetçiler: El-Kindi, Kılıç Ali, Ali Kuşçu, Matrakçı, Ebussuud — `KARAR: GEÇTİ`)
- **Karar & Uygulanan Değişiklikler:**
  1. **Yumuşak Renk Paleti & Metin Sadeleştirmesi ([`CueDeckSettingsScreen`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1170-L1734), [`_CueDeckProPassAndUpgradeSection`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1766-L1993), [`_GoogleDriveBackupSection`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L2247-L2696), [`WatchPlanMasteryHeader`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L3275-L3375), [`WatchCueCard`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L3380-L3725)):**
     - Ayarlar ekranındaki boğuk zifiri siyah (`#000000`) zemin ve sert neon çerçeveler kaldırılarak gözü dinlendiren **Soft Slate (`#141824` sayfa zemini, `#1E2433` kart yüzeyi, `#E6C17A` yumuşak kum sarısı, `#6EE7B7` pastel adaçayı yeşili ve `0.06` opaklıkta mikro çerçeve)** ile **Warm Alabaster (`#F3F6FA` açık mod zemini, `#FFFFFF` kartlar)** paletine geçildi.
     - Kart içlerindeki uzun açıklama paragrafları tek satırlık yalın özetlere indirildi; mükerrer tema `Switch` anahtarı kaldırıldı; Pro satın alma ve 24s Pass butonları yan yana tek satırda toplandı; `WatchCueCard` alt bilgisindeki çift tekrarlı metin (`subtitle • checkpointSummary` -> `checkpointSummary`) sadeleştirildi.
  2. **Google Play Store & Apple App Store Mağaza Gönderim Hazırlığı ([`build.gradle.kts`](file:///c:/Users/theak/source/repos/cuedeck/android/app/build.gradle.kts), [`proguard-rules.pro`](file:///c:/Users/theak/source/repos/cuedeck/android/app/proguard-rules.pro), [`PrivacyInfo.xcprivacy`](file:///c:/Users/theak/source/repos/cuedeck/ios/Runner/PrivacyInfo.xcprivacy), [`.gitignore`](file:///c:/Users/theak/source/repos/cuedeck/.gitignore), [`pubspec.yaml`](file:///c:/Users/theak/source/repos/cuedeck/pubspec.yaml)):**
     - Android `release` derlemeleri için `key.properties` + `cuedeck-upload-keystore.jks` üretim imzalama yapılandırması ve `proguard-rules.pro` eklendi (`.gitignore` ile anahtar sızıntısı önlendi).
     - Apple App Store Connect zorunlu gizlilik bildirimi (`ios/Runner/PrivacyInfo.xcprivacy` — `NSPrivacyAccessedAPICategoryUserDefaults: CA92.1`, `NSPrivacyTracking: false`) oluşturuldu.
     - Sürüm `1.9.1+13` olarak yükseltilerek mağazaya yüklenmeye hazır imzalı `.aab` (Google Play App Bundle) ve `.apk` paketleri üretilip `G:\Drive'ım\CueDeck\Releases\` dizinine arşivlendi.

---

## [ADR-011] 2026-10-28: 3 Fazlı Yol Haritası Uygulaması — Tek Seferlik Pro + 24 Saatlik Ödüllü Pro Pass (`CueMonetizationService`), Port 6466 PIN Eşleştirme ve ASO Vitrin Paketi (`v1.9.0+12`)
- **Tarih & Ajanlar:** `2026-10-28` — Kanuni, Mimar Sinan, El-Cezeri & Piri Reis, Kâtip Çelebi, Barbaros (Denetçiler: El-Kindi, Kılıç Ali, Ali Kuşçu, Matrakçı, Ebussuud — `KARAR: GEÇTİ`)
- **Karar & Uygulanan 3 Faz:**
  1. **Faz 1 — Gelir, Tek Seferlik Pro & 24 Saatlik Ödüllü Pro Pass ([`cue_monetization_service.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/cue_monetization_service.dart), [`cuedeck_providers.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/providers/cuedeck_providers.dart#L800-L895), [`_CueDeckProPassAndUpgradeSection`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1720-L1955), [`_CueNonIntrusiveAdBanner`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1957-L2017)):**
     - `AndroidKeyStore` (`AES/GCM/NoPadding`, 256-bit) ve kanonik `SHA-256` bütünlük mührüyle korunan [`CueMonetizationService`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/cue_monetization_service.dart) oluşturuldu.
     - AdMob Invalid Traffic (IVT) soğuma süresi korumalı **24 Saatlik Ödüllü Pro Pass (`grantRewardedProPass`)**, 10 farklı gün sonunda açılan **%40 Sadakat İndirimi (`89,99 ₺` / `cuedeck_pro_loyalty_40`)** ve **Tek Seferlik Ömür Boyu Pro (`99,99 ₺` lansman / `149,99 ₺` standart / `cuedeck_pro_lifetime`)** devreye alındı.
     - Kumanda tuşlarına asla müdahale etmeyen, yalnızca [`CueDeckSettingsScreen`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1680-L1705) altında yer alan ve Pro/24s Pass aktif olduğunda otomatik gizlenen `_CueNonIntrusiveAdBanner` eklendi.
  2. **Faz 2 — Mağaza Yeterliliği İçin Port 6466 (6 Haneli PIN) Köprüsü & Görsel Kurulum Rehberi ([`TvConnectionProtocol`](file:///c:/Users/theak/source/repos/cuedeck/lib/models/cue_models.dart#L178-L200), [`AdbTvService.pairWithPin6466`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L550-L600), [`AdbTvService.buildRemote6466KeyFrame`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L521-L547), [`_Pin6466PairingSheet`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L2020-L2125), [`_TvSetupGuideSheet`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L2128-L2195)):**
     - Geliştirici Seçenekleri kapalı olan standart perakende Android TV / Google TV'ler için Port `6466/6467` TLS + 6 Haneli PIN eşleştirme (`pairWithPin6466`), `RemoteKeyInject` protobuf çerçeveleme (`buildRemote6466KeyFrame`) ve adım adım kurulum rehberi çekmecesi eklendi.
  3. **Faz 3 — Mağaza Vitrin (ASO) & İzin Uyumluluğu ([`AndroidManifest.xml`](file:///c:/Users/theak/source/repos/cuedeck/android/app/src/main/AndroidManifest.xml#L1-L15), [`Info.plist`](file:///c:/Users/theak/source/repos/cuedeck/ios/Runner/Info.plist#L9-L26), [`main.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/main.dart#L23-L26), [`magaza_vitrin_aso_paketi.md`](file:///c:/Users/theak/source/repos/cuedeck/docs/magaza_vitrin_aso_paketi.md)):**
     - `AndroidManifest.xml` içerisine `com.android.vending.BILLING` eklendi ve Google Play Console ret riskine karşı `USE_EXACT_ALARM` kaldırılıp `SCHEDULE_EXACT_ALARM` korundu; `ios/Runner/Info.plist` içerisine Bonjour (`_androidtvremote2._tcp`, `_adb._tcp`, `_googlecast._tcp`), yerel ağ ve mikrofon açıklamaları eklendi; TR/EN mağaza vitrin metinleri hazırlandı.

---

## [ADR-010] 2026-10-28: Piyasa Analizi, Mağaza Yeterliliği (Port 6466 vs Port 5555) ve Gelir Modeli (Freemium + 24s Ödüllü Pro Pass + Tek Seferlik Pro) Stratejisi
- **Tarih & Ajanlar:** `2026-10-28` — Kanuni, Hezarfen, Kâtip Çelebi
- **Bağlam:**
  1. CueDeck için ücretsiz reklamlı (AdMob) ve tek seferlik ödeme (Lifetime IAP) ile Pro satın alma modelinin piyasa/mağaza yeterliliği analiz edildi.
  2. *"Pro model X ücret ile satılacaksa reklamlardan 5X kazandıran kullanıcıya Pro hediye edelim"* fikrinin AdMob eCPM matematiği, Google Play/AdMob Invalid Traffic (IVT) politikaları ve pazarlama psikolojisi açısından uyumluluğu incelendi.
- **Karar & Bulgular ([`cuedeck_piyasa_ve_gelir_modeli_analizi.md`](file:///c:/Users/theak/source/repos/cuedeck/docs/cuedeck_piyasa_ve_gelir_modeli_analizi.md)):**
  1. **Gerçek Değer Önerisi (UVP):** Salt kumanda olarak pazarda boşluk yoktur; CueDeck'in kapattığı gerçek boşluk **"Zamanlanmış İzleme Planlayıcı (`WatchCueItem` + `AlarmManager`) ile Tek Dokunuşla TV'de İçerik/Playlist Başlatıcı (`launchPlatformOrDeepLink`) Arasındaki Otomasyon Köprüsü"**dür.
  2. **Mağaza Yeterliliği (Port 6466 Zorunluluğu):** Sıradan mağaza kullanıcılarının %85'i TV'de Geliştirici Seçeneklerini (Port 5555 Ağ ADB) açamayacağından, mağaza sürümünde temel tuşlar için **Port 6466/6467 (`Android TV Remote Protocol v2` — TLS 6 Haneli PIN)** "Sıfır Kurulum Modu" olarak eklenmeli, Port 5555 ADB ise "Deep-Link & Turbo Modu" olarak konumlandırılmalıdır.
  3. **5X Reklam = Bedava Pro Fikrinin Reddi ve Doğru Alternatif:** Türkiye AdMob eCPM verileriyle ($2.00–$4.50 Rewarded eCPM) bir kullanıcının $5X$ (~$25) kazandırması ~8.300 video reklam (~4,5 yıl) sürer ve arka arkaya reklam izletmek AdMob hesabını **Invalid Traffic (IVT)** nedeniyle kapatır. Bunun yerine **"1 Ödüllü Video = 24 Saat Pro Pass + 10 Farklı Gün Kullanımda %40 Tek Seferlik Pro Sadakat İndirimi"** ve **Tek Seferlik Pro (TR: 149,99 TL / Lansman: 99,99 TL, Global: $5.99 / Lansman: $3.99)** modeli benimsendi.

---

## [ADR-009] 2026-10-28: Tam Sayfa Ayarlar Ekranı (`CueDeckSettingsScreen`), Gerçek Android Sistem Bildirimleri (`NotificationManager` + `AlarmManager` + `CueDeckReminderReceiver`) ve Başlık Sadeleştirmesi (`v1.8.0+11`)
- **Tarih & Ajanlar:** `2026-10-28` — Kanuni, Mimar Sinan, El-Cezeri & Piri Reis, Kâtip Çelebi, Barbaros (Denetçiler: El-Kindi, Kılıç Ali, Ali Kuşçu, Matrakçı, Ebussuud — `KARAR: GEÇTİ`)
- **Bağlam:**
  1. Ayarlar ve İzleme Planı ekranının bottom sheet (`DraggableScrollableSheet`) yerine tam sayfa (`Scaffold`) olarak açılması talep edildi.
  2. İzleme planı bildirimlerinin yalnızca uygulama içi üst bant (`ReminderAlertBanner` baloncuğu) olarak kalmayıp gerçek işletim sistemi bildirimi olarak gönderilmesi istendi.
  3. Ayarlar başlığındaki `"Tahrir & Zikirce Tasarım Dili"` ibaresinin kaldırılması talep edildi.
- **Karar:**
  1. **Tam Sayfa `CueDeckSettingsScreen` & Başlık Sadeleştirmesi ([`cuedeck_home_screen.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L251-L259), [`CueDeckSettingsScreen`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1123-L1682)):** `showModalBottomSheet` + `DraggableScrollableSheet` yapısı kaldırılarak `Navigator.of(context).push(MaterialPageRoute(...))` ile açılan tam ekran `Scaffold` mimarisine geçildi; başlıktaki `"Tahrir & Zikirce Tasarım Dili"` ibaresi tamamen kaldırıldı.
  2. **Gerçek Android OS Bildirimleri & Zamanlanmış `AlarmManager` Alarmları ([`CueDeckReminderReceiver.kt`](file:///c:/Users/theak/source/repos/cuedeck/android/app/src/main/kotlin/com/akarworks/cuedeck/CueDeckReminderReceiver.kt#L19-L320), [`MainActivity.kt`](file:///c:/Users/theak/source/repos/cuedeck/android/app/src/main/kotlin/com/akarworks/cuedeck/MainActivity.kt#L179-L250), [`AndroidManifest.xml`](file:///c:/Users/theak/source/repos/cuedeck/android/app/src/main/AndroidManifest.xml#L5-L53), [`cue_notification_service.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/cue_notification_service.dart#L8-L131), [`cuedeck_providers.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/providers/cuedeck_providers.dart#L290-L355)):**
     - `AndroidManifest.xml` içerisine `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` izinleri ve `CueDeckReminderReceiver` eklendi.
     - `CueDeckNotificationHelper` üzerinde yüksek öncelikli (`NotificationManager.IMPORTANCE_HIGH`) `cuedeck_watch_reminders_v1` kanalı, `PendingIntent` ile uygulamayı öne getiren gerçek durum çubuğu / heads-up bildirimleri ve `AlarmManager.setExactAndAllowWhileIdle` (cihaz yeniden başlatıldığında `BOOT_COMPLETED` ile korunan `cuedeck_scheduled_alarms.json`) zamanlayıcısı kuruldu.
     - [`WatchCueItem.nextReminderDateTime`](file:///c:/Users/theak/source/repos/cuedeck/lib/models/cue_models.dart#L439-L459) ve [`WatchCueItem.nextWatchDateTime`](file:///c:/Users/theak/source/repos/cuedeck/lib/models/cue_models.dart#L420-L437) ile her aktif plan için hem ön hatırlatma (`scheduledTime - reminderMinutesBefore`) hem de tam başlama saati (`scheduledTime`) gerçek işletim sistemi alarmı olarak kaydedilir.

---

## [ADR-008] 2026-10-28: Evrensel Android TV & Google TV Mimarisi — ADB RSA-2048 `CMD_AUTH` Eşleştirme, `getprop` Dinamik Tuş Haritası ve mDNS Keşfi (`v1.7.0+10`)
- **Tarih & Ajanlar:** `2026-10-28` — Mimar Sinan, Ali Kuşçu, El-Cezeri, Hezarfen, Takiyüddin, Kâtip Çelebi (Denetçiler: El-Kindi, Kılıç Ali, Ali Kuşçu, Matrakçı, Ebussuud — `KARAR: GEÇTİ`)
- **Bağlam:**
  1. Standart perakende Android TV ve Google TV cihazları (Sony Bravia, TCL, Philips, Xiaomi Mi Box / TV Stick, Chromecast with Google TV, Nvidia Shield vb.) `ro.adb.secure=1` ile gelir ve `CNXN` paketine doğrudan `CNXN` yerine `CMD_AUTH` (`arg0 = 1`, 20-byte `AUTH_TOKEN`) yanıtı döner. Tam RSA-2048 imza ve açık anahtar (`AUTH_SIGNATURE` / `AUTH_RSAPUBLICKEY`) el sıkışması olmadan bu cihazlarla eşleşme yapılamaz.
  2. Realtek RTD2851P (Redline) dışındaki Android TV'lerde `/vendor/usr/keylayout/venus_IR_input.kl` ve `com.toptech.tvmenu` bulunmadığından, koşulsuz `/dev/input/event0` tarama kodu yazımı veya Toptech aktivite çağrısı diğer TV markalarında tuşların çalışmamasına yol açar.
  3. Yalnızca sabit DHCP oktetlerini Port `5555` üzerinden taramak, farklı IP alan veya henüz Ağ ADB'si açılmamış (ancak Port `6466` Android TV Remote v2 ve mDNS yayını açık olan) televizyonları bulamaz.
- **Karar:**
  1. **Donanım Korumalı ADB RSA-2048 `CMD_AUTH` Eşleştirme ([`MainActivity.getOrCreateAdbRsaKeyPair`](file:///c:/Users/theak/source/repos/cuedeck/android/app/src/main/kotlin/com/akarworks/cuedeck/MainActivity.kt#L172-L201), [`AdbRsaAuthenticator`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L13-L171), [`AdbTvService._onSocketData`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L356-L485), [`pairWithTv`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L517-L542)):**
     - Android tarafında 2048-bit RSA anahtar çifti üretilerek `AndroidKeyStore` (`CueDeck_Master_AES_Key`) AES-256-GCM ile şifrelenmiş `cuedeck_adb_rsa.vault` dosyasında saklanır.
     - İlk `CMD_AUTH` (`AUTH_TOKEN`) geldiğinde [`signAdbTokenSync`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L88-L123) ile 256-byte PKCS#1 v1.5 Type 1 SHA-1 `DigestInfo` imzası (`AUTH_SIGNATURE`, `arg0 = 2`) gönderilir.
     - TV anahtarı tanımıyorsa ikinci `AUTH_TOKEN` geldiğinde [`encodeAdbPublicKeyPayloadSync`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L127-L170) ile 524-byte Android `RSAPublicKey` C-struct (`modulus_size_words = 64`, `n0inv`, `n`, `rr`, `e = 65537`) Base64 + `' cuedeck@akarworks\x00'` (`AUTH_RSAPUBLICKEY`, `arg0 = 3`) gönderilerek TV ekranında `"Hata ayıklamaya izin ver?"` penceresi açılır ve 18 saniye kullanıcı onayı beklenir.
  2. **Canlı `getprop` Marka/Model Tespiti & Evrensel Tuş Haritası ([`probeTvDeviceProfile`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L546-L610), [`_buildFastKeyShellCommand`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L872-L883), [`sendKeyCommand`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L886-L896)):**
     - Bağlantı kurulduğunda `getprop ro.product.brand; getprop ro.product.model; getprop ro.board.platform; getprop ro.build.version.release` çalıştırılarak TV'nin gerçek marka/modeli arayüze yansıtılır.
     - Tuş komutlarında önce `venus_IR_input.kl` varlığı kontrol edilir (`if [ -w /dev/input/event0 ] && ( [ -f /vendor/usr/keylayout/venus_IR_input.kl ] || [ -f /system/usr/keylayout/venus_IR_input.kl ] ); then printf ... > /dev/input/event0; else input keyevent $code; fi`); böylece Redline RTD2851P'de ~40ms donanım hızı korunurken diğer tüm Android TV'lerde standart `input keyevent` sorunsuz çalışır.
     - `TvKeyCommand.inputs` komutunda `if pm path com.toptech.tvmenu >/dev/null 2>&1; then am start -n com.toptech.tvmenu/.input.InputActivity; else input keyevent 178; fi` kullanılarak evrensel `KEYCODE_TV_INPUT` (`178`) desteği sağlandı.
  3. **mDNS (`224.0.0.251:5353`) + Port `5555` / `6466` Hibrit Ağ Keşfi & Arayüz Entegrasyonu ([`_discoverViaMdns`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L615-L659), [`discoverDevices`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L723-L866), [`_SettingsAndPlannerSheet`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1469-L1627)):**
     - `_androidtvremote2._tcp.local`, `_adb._tcp.local` ve `_googlecast._tcp.local` mDNS PTR sorguları ile yerel `/24` alt ağda Port `5555` ve Port `6466` paralel taranır.
     - Ayarlar çekmecesine keşfedilen TV'ler arasında tek dokunuşla geçiş sağlayan `ChoiceChip` listesi ve `🔐 TV Eşleştir (RSA Onayı)` butonu eklendi.

---

## [ADR-007] 2026-10-28: Uygulama Geneli Reaktif Açık/Koyu Tema (`isDarkMode`) & Yüksek Kontrastlı `ChoiceChip` Mimarisi (`v1.6.0+9`)
- **Tarih & Ajanlar:** `2026-10-28` — Mimar Sinan, Ali Kuşçu, El-Cezeri, Hezarfen, Takiyüddin, Kâtip Çelebi (Denetçiler: Ali Kuşçu 100/100, Matrakçı 3/3 test, Ebussuud 0 hata — `KARAR: GEÇTİ`)
- **Karar:**
  1. **Kök `MaterialApp` Tema Senkronizasyonu ([`CueDeckApp`](file:///c:/Users/theak/source/repos/cuedeck/lib/main.dart#L16-L54)):** `ref.watch(cueDeckProvider.select((s) => s.isDarkMode))` ile `themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light` bağlandı.
  2. **Tüm Alt Çekmeceler ve Kartlarda Reaktif `isDarkMode` Paleti ([`cuedeck_home_screen.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L919-L3935), [`tactile_dpad_painter.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/widgets/tactile_dpad_painter.dart#L138-L195), [`google_oauth_sheet.dart`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/google_oauth_sheet.dart#L380-L540)):** Tüm alt çekmeceler, kartlar ve halka çiziciler reaktif Açık/Koyu tema paletine geçirildi.
  3. **Yüksek Kontrastlı `ChoiceChip` & `ActionChip` Mimarisi:** Tüm `ChoiceChip` bileşenlerinde `backgroundColor`, `selectedColor`, `checkmarkColor`, `side` ve `labelStyle` açıkça tanımlandı.

---

## [ADR-006] 2026-10-28: Resmi CueDeck Google Cloud OAuth 2.0 İstemcisi, WebView BotGuard/JS Düzeltmesi & Zikirce Uyumlu Google Drive Bulut Yedekleme (PKCE OAuth2 + AndroidKeyStore AES-256-GCM + Çoklu Cihaz Uzlaştırma + SAF Yerel Yedekleme) Mimarisi (`v1.5.0+6` → `v1.5.2+8`)
- **Tarih & Ajanlar:** `2026-10-27` / `2026-10-28` — Mimar Sinan, Ali Kuşçu, El-Cezeri, Hezarfen, Takiyüddin, Kâtip Çelebi
- **Karar:**
  1. **Resmi CueDeck Google Cloud OAuth 2.0 İstemcisi & WebView JavaScript / BotGuard Uyumluluğu ([GoogleService-Info.plist](file:///c:/Users/theak/source/repos/cuedeck/ios/Runner/GoogleService-Info.plist#L1-L14), [`GoogleOAuthConstants`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/google_oauth_sheet.dart#L12-L30), [`GoogleOAuthHelper.isAllowedGoogleOAuthHost`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/google_oauth_sheet.dart#L61-L83), [`GoogleOAuthSheet`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/google_oauth_sheet.dart#L171-L541)):** `CLIENT_ID: 803381919405-3j7rne8pv0j5b9u87faeesagnvrqd5gd.apps.googleusercontent.com`, `redirectUri: com.akarworks.cuedeck://`, PKCE (`S256`) + CSRF `state`, `setJavaScriptMode(JavaScriptMode.values.last)` ve BotGuard `about:blank` / `!request.isMainFrame` / `.google.com.tr` izinleri.
  2. **Donanım Destekli `AndroidKeyStore` AES-256-GCM Kasa Şifrelemesi, SHA-256 Checksum & Çoklu Cihaz Uzlaştırma ([`GoogleDriveBackupService`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/google_drive_backup_service.dart#L95-L815)):** 256-bit `AES/GCM/NoPadding` kasa şifrelemesi, 2 MB DoS sınırı, kanonik `SHA-256` `Checksum`, `syncAndMergeWithCloud` ve Android SAF yerel `.json` yedekleme.

### ⚠️ Çözülen OAuth2 & WebView Anti-Pattern'i (`v1.5.2+8`)
- **Anti-Pattern #3 — `webview_flutter` `JavaScriptMode` Enum Sırası Tuzağı (`values.first == disabled`) ve Google BotGuard `about:blank` / Subframe Engellemesi:** `JavaScriptMode.values.last` (`unrestricted`) ve `about:blank` / `!request.isMainFrame` / `.google.com.tr` beyaz listesi ile çözüldü.

---

## [ADR-005] 2026-10-27: Zikirce & Tahrir Tasarım Dilinde Minimal Modern CueDeck Marka & İkon Mimarisi (`v1.4.0+5`)
- **Karar:** [cuedeck_logo.svg](file:///c:/Users/theak/source/repos/cuedeck/assets/icons/cuedeck_logo.svg), [cuedeck_app_icon.png](file:///c:/Users/theak/source/repos/cuedeck/assets/images/cuedeck_app_icon.png) ve [`CueDeckBrandBadge`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1022-L1052) entegrasyonu.

---

## [ADR-004] 2026-10-27: YouTube Playlist Link Normalizasyonu ve Tüm Platformlar İçin Periyot / Gün / Saat / Seans Tabanlı İzleme Planlayıcısı (`v1.3.0+4`)
- **Karar:** [`WatchCueItem.normalizeContentLink`](file:///c:/Users/theak/source/repos/cuedeck/lib/models/cue_models.dart#L294-L319), [`WatchRecurrence`](file:///c:/Users/theak/source/repos/cuedeck/lib/models/cue_models.dart#L125-L144) ve [`WatchCueItem`](file:///c:/Users/theak/source/repos/cuedeck/lib/models/cue_models.dart#L248-L503) eklendi.

---

## [ADR-003] 2026-10-27: Google TV G10 Referans Kumanda Gövdesi, Gerçek Siyah (`#000000`) / Klasik Beyaz Tema ve Ayarlar (`⚙️`) İçine Taşınan TV Detayları + İzleme Planı (`v1.2.0+3`)
- **Karar:** [`G10PhysicalRemoteChassis`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L44-L261) ve [`_SettingsAndPlannerSheet`](file:///c:/Users/theak/source/repos/cuedeck/lib/screens/cuedeck_home_screen.dart#L1127-L1701) oluşturuldu.

---

## [ADR-002] 2026-10-27: Kalıcı ADB TCP 5555 Durum Makinesi, `/dev/input/event0` Donanım Tuş Enjeksiyonu, Yerel Sesli Komut ve 2 Sekmeli Yalın Arayüz (`v1.1.0+2`)
- **Karar:** [`AdbTvService`](file:///c:/Users/theak/source/repos/cuedeck/lib/services/adb_tv_service.dart#L176-L485) içerisinde kalıcı TCP 5555 durum makinesi, `/dev/input/event0` 64-byte donanım tuş enjeksiyonu ve yerel Android `RecognizerIntent` (`tr-TR`) sesli komut köprüsü kuruldu.

### ⚠️ Çözülen Anti-Pattern'ler (Karpathy Lessons Learned Wiki)
1. **Anti-Pattern #1 — Erken `socket.destroy()` (80ms) Nedeniyle `input keyevent` JVM Sürecinin `SIGHUP` ile Ölmesi:** Kalıcı soket + `CLSE` bekleme + `/dev/input/event0` enjeksiyonu ile çözüldü.
2. **Anti-Pattern #2 — Tek Tırnaklı Kabuk Komutlarında `Uri.encodeQueryComponent` Tek Tırnak (`'`) Kaçışı Eksikliği:** `.replaceAll("'", '%27')` ile çözüldü.

---

## [ADR-001] 2026-10-27: Tester Release APK Dağıtımı & Ağ İzinleri (`v1.0.0+1`)
- **Karar:** `AndroidManifest.xml` içerisine `INTERNET`, `ACCESS_NETWORK_STATE` ve `usesCleartextTraffic="true"` eklendi; `cuedeck_v1.0.0+1_release.apk` üretilerek Google Drive `Releases/` arşivine kopyalandı.
