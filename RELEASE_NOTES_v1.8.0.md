# CueDeck v1.8.0+11 — Sürüm Notları / Release Notes

**Sürüm / Version:** `1.8.0+11` (Build `11`)  
**Tarih / Date:** 28.10.2026  
**Hedef Platform / Target Platform:** Android (ARM64 / ARMv7 / x86_64 Release APK) & Universal Android TV / Google TV (`Port 5555` ADB-over-TCP & `mDNS`)  
**Paket / Package:** `CueDeck_v1.8.0+11_release.apk` (`53.61 MB` / `56,217,740 byte`)  
**SHA-256:** `25F31EB7F07B02091630A7821F81B0B18814923437F3D8CEA8741412B87338E6`

---

## 🇹🇷 Türkçe Sürüm Notları (`changelog_tr`)

### 🚀 Öne Çıkan Yenilikler (v1.8.0+11 — Tam Sayfa Ayarlar Ekranı & Gerçek Android OS Bildirim Mimarisi)
1. **Tam Sayfa (`Scaffold`) Ayarlar & İzleme Planı Ekranı (`CueDeckSettingsScreen`)**
   - Ayarlar ve İzleme Planı ekranı (`⚙️`), artık yarım ekran alt çekmece (`DraggableScrollableSheet`) yerine `Navigator.push(MaterialPageRoute(...))` ile tam sayfa (`Scaffold`) olarak açılır; geniş ekran alanı sayesinde TV cihaz yönetimi, Google Drive bulut yedekleme ve izleme planı kartları çok daha ferah ve akıcı bir deneyim sunar.
   - Ayarlar başlığı sadeleştirilerek alt başlıktaki `"Tahrir & Zikirce Tasarım Dili"` ibaresi kaldırıldı.

2. **Gerçek Android Sistem Bildirimleri (`NotificationManager`) & Arka Plan Zamanlayıcısı (`AlarmManager`)**
   - İzleme planı hatırlatmaları artık yalnızca uygulama içi üst bant (`ReminderAlertBanner`) ile sınırlı kalmayıp, `CueDeckReminderReceiver`, `CueDeckNotificationHelper` ve `CueNotificationService` üzerinden yüksek öncelikli (`IMPORTANCE_HIGH`, `cuedeck_watch_reminders_v1`) gerçek Android durum çubuğu, kilit ekranı ve açılır (heads-up) sistem bildirimi olarak gönderilir.
   - `AlarmManager.setExactAndAllowWhileIdle` ve `BOOT_COMPLETED` kalıcılığı (`cuedeck_scheduled_alarms.json`) sayesinde uygulama kapalıyken veya cihaz yeniden başlatıldığında dahi her aktif izleme planı için hem ön hatırlatma (`scheduledTime - reminderMinutesBefore`) hem de tam başlama saati (`scheduledTime`) bildirimleri zamanında tetiklenir.
   - Android 13+ (`TIRAMISU`) için `POST_NOTIFICATIONS` çalışma zamanı izin yönetimi ve bildirimden tek dokunuşla uygulamayı öne getiren `PendingIntent` entegrasyonu eklendi.

---

## 🇬🇧 English Release Notes (`changelog_en`)

### 🚀 What's New in v1.8.0+11 (Full-Page Settings Screen & Native Android OS Notification Architecture)
1. **Full-Page (`Scaffold`) Settings & Watch Planner Screen (`CueDeckSettingsScreen`)**
   - Transitioned the Settings & Watch Planner interface (`⚙️`) from a modal bottom sheet (`DraggableScrollableSheet`) to a dedicated full-screen page (`Scaffold` via `MaterialPageRoute`), providing a cleaner, full-height layout for TV discovery/pairing, Google Drive cloud backups, and watch cue management.
   - Streamlined the Settings header by removing the `"Tahrir & Zikirce Tasarım Dili"` subtitle text.

2. **Native Android OS Notifications (`NotificationManager`) & Exact Background Alarms (`AlarmManager`)**
   - Watch plan reminders now dispatch real high-priority (`IMPORTANCE_HIGH`, `cuedeck_watch_reminders_v1`) Android system notifications (status bar, lock screen, and heads-up banners) via `CueDeckReminderReceiver`, `CueDeckNotificationHelper`, and `CueNotificationService` in addition to in-app alerts.
   - Powered by `AlarmManager.setExactAndAllowWhileIdle` and `BOOT_COMPLETED` persistence (`cuedeck_scheduled_alarms.json`), automatically scheduling both pre-watch reminders (`scheduledTime - reminderMinutesBefore`) and exact start-time alerts (`scheduledTime`) even when the app is closed or the device reboots.
   - Added Android 13+ (`POST_NOTIFICATIONS`) runtime permission handling and `PendingIntent` deep-tap support to bring CueDeck directly to the foreground.
