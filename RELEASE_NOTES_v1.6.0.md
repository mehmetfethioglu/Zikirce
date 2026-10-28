# CueDeck v1.6.0+9 — Sürüm Notları / Release Notes

**Sürüm / Version:** `1.6.0+9` (Build `9`)  
**Tarih / Date:** 28.10.2026  
**Hedef Platform / Target Platform:** Android (ARM64 / ARMv7 / x86_64 Release APK) & Android TV (`Port 5555` ADB-over-TCP)  
**Paket / Package:** `CueDeck_v1.6.0+9_Release.apk` (`53.39 MB` / `55,987,980 byte`)  
**SHA-256:** `514B8356564A2099F473A5B2DD597DEEA6A68220C1EFC7050D1A0A6D7EE28519`

---

## 🇹🇷 Türkçe Sürüm Notları (`changelog_tr`)

### 🎨 Öne Çıkan Yenilikler & İyileştirmeler (v1.6.0+9)
1. **Uygulama Geneli Uçtan Uca Açık / Koyu Tema (`isDarkMode`) Uyumluluğu**
   - Tema anahtarı (`Gerçek Siyah #000000` vs `G10 Beyaz Kumanda`) artık yalnızca ana kumanda gövdesini değil, uygulamadaki **tüm alt pencereleri, çekmeceleri ve diyalogları** anlık olarak (`AnimatedContainer`) dönüştürür:
     - **Ayarlar, TV Bağlantısı & İzleme Planı Paneli (`_SettingsAndPlannerSheet`):** Açık temada ferah `#F3F5F9` zemin, `#FFFFFF` kart yüzeyleri, `#D8DEE8` ince kenarlıklar, `#141821` yüksek kontrastlı metinler ve `#B87818` kehribar-altın vurgular; koyu temada ise `#0B0D13` obsidyen zemin ve `#141722` kart yüzeyleri.
     - **Google Drive & Yerel Yedekleme Kartı (`_CloudAndLocalBackupSection`) ve Yedek Seçici (`_BackupPickerSheet`):** Bulut oturum durumu, aksiyon butonları ve yedek geçmişi listesi seçili temaya tam uyumlu hale getirildi.
     - **Sesli Kumanda (`_VoiceControlSheet`) & TV Klavye (`_RemoteKeyboardSheet`) Çekmeceleri:** Mikrofon dinleme alanı, hızlı sesli komut çipleri ve uzaktan metin giriş alanı açık/koyu tema renk şemasına bağlandı.
     - **İzleme Planı Ekleme / Düzenleme Formu (`_AddOrEditCueBottomSheet`) & Hatırlatıcı Başlığı (`ReminderAlertBanner`):** Tüm form girdileri (`#F0F2F7` / `#090A0F`), gün/periyot seçicileri ve bildirim kartları çift tema desteğine kavuşturuldu.

2. **120 FPS İlerleme Halkası (`CircularProgressRingPainter`) & OAuth Penceresi Kontrast İyileştirmesi**
   - `CircularProgressRingPainter` bileşenine `isDarkMode` duyarlı arka plan iz rengi (`trackColor`) eklendi; açık temada dairesel ilerleme halkasının görünürlüğü artırıldı.
   - `GoogleOAuthSheet` üst başlık çubuğu ve güvenlik rozeti hem açık hem koyu temada yüksek okunabilirlik sağlayacak şekilde güncellendi.

3. **Android Alt Navigasyon Güvenli Alan (`SafeArea` / `padding.bottom`) Koruması**
   - Tüm kaydırılabilir alt çekmecelere (`DraggableScrollableSheet` / `ModalBottomSheet`) dinamik `MediaQuery.of(context).padding.bottom` alt boşluğu eklenerek Android sistem navigasyon çubuğuyla çakışmalar önlendi.

---

## 🇬🇧 English Release Notes (`changelog_en`)

### 🎨 What's New & Improved in v1.6.0+9
1. **App-Wide End-to-End Light & Dark Theme (`isDarkMode`) Synchronization**
   - Switching between **True Black (`#000000`) Dark Mode** and **Classic G10 White (`#F3F5F9`) Light Mode** now dynamically styles **every screen, modal bottom sheet, and banner** across the entire application:
     - **Settings, TV Discovery & Watch Planner Sheet (`_SettingsAndPlannerSheet`):** Crisp `#F3F5F9` sheet background, `#FFFFFF` cards, `#D8DEE8` borders, `#141821` primary typography, and `#B87818` warm gold accents in Light Mode; deep `#0B0D13` obsidian surfaces in Dark Mode.
     - **Google Drive & Local Backup Section (`_CloudAndLocalBackupSection`) & Snapshot Picker (`_BackupPickerSheet`):** Fully adaptive surfaces, borders, and typography for cloud/local backup management.
     - **Voice Control (`_VoiceControlSheet`) & Remote Keyboard (`_RemoteKeyboardSheet`) Sheets:** Adaptive light/dark styling for microphone status cards, quick voice command chips, and TV text input fields.
     - **Add/Edit Watch Plan Sheet (`_AddOrEditCueBottomSheet`) & `ReminderAlertBanner`:** Form inputs (`#F0F2F7` vs `#090A0F`), recurrence/weekday chips, and pre-show alert banners seamlessly adapt to the active theme.

2. **Adaptive 120 FPS Progress Ring (`CircularProgressRingPainter`) & OAuth Header Contrast**
   - Added theme-aware `isDarkMode` track rendering to `CircularProgressRingPainter` so circular completion rings remain crisp on white card surfaces.
   - Refined `GoogleOAuthSheet` header bar and security subtitle contrast across both Light and Dark themes.

3. **System Navigation Bar Safe-Area Padding (`padding.bottom`)**
   - Added dynamic `MediaQuery.of(context).padding.bottom` bottom insets across all modal sheets to prevent content from overlapping the Android gesture/navigation bar.
