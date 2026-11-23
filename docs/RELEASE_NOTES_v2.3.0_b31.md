# CueDeck v2.3.0 (Build 31) — Sürüm Notları / Release Notes

## 🇹🇷 Türkçe (Google Play / App Store "Bu Sürümde Neler Var?")
v2.3.0:
• Tam Arçelik TV Kontrolü: Arçelik/Beko/Grundig Smart TV'ler için şifreli ArWebsocket (port 8080) bağlanma, ses, kanal, yön, menü, klavye ve akıllı tanılama desteği eklendi.
• Otomatik Sesli Arama: Mikrofona söyleyip bitirdiğinizde TV'de arama otomatik başlar; manuel Enter'a basmaya gerek kalmaz.
• Tek Dokunuşla Yeni Arama: Arama yaptıktan sonra mikrofona tekrar dokunduğunuzda önceki arama kutusu temizlenir ve yeni arama başlar.

## 🇺🇸 English (Google Play / App Store "What's New")
v2.3.0:
• Full Arçelik/Beko/Grundig Control: Added encrypted ArWebsocket (port 8080) support for volume, channels, D-pad, menu, keyboard input, and smart diagnostics.
• Hands-Free Auto-Search: Voice commands automatically submit and search on your TV as soon as you finish speaking—no manual Enter required.
• Instant Clean Re-Search: Tapping the mic again clears the previous search text in CueDeck and on your TV before starting your new voice search.

---

## 📋 Google Play Console Çok Dilli Sürüm Notları (Copy-Paste XML)
```xml
<tr-TR>
v2.3.0:
• Tam Arçelik TV Kontrolü: Arçelik/Beko/Grundig Smart TV'ler için şifreli ArWebsocket (port 8080) bağlanma, ses, kanal, yön, menü, klavye ve akıllı tanılama desteği eklendi.
• Otomatik Sesli Arama: Mikrofona söyleyip bitirdiğinizde TV'de arama otomatik başlar; manuel Enter'a basmaya gerek kalmaz.
• Tek Dokunuşla Yeni Arama: Arama yaptıktan sonra mikrofona tekrar dokunduğunuzda önceki arama kutusu temizlenir ve yeni arama başlar.
</tr-TR>
<en-US>
v2.3.0:
• Full Arçelik/Beko/Grundig Control: Added encrypted ArWebsocket (port 8080) support for volume, channels, D-pad, menu, keyboard input, and smart diagnostics.
• Hands-Free Auto-Search: Voice commands automatically submit and search on your TV as soon as you finish speaking—no manual Enter required.
• Instant Clean Re-Search: Tapping the mic again clears the previous search text in CueDeck and on your TV before starting your new voice search.
</en-US>
```

---

## 🔧 Teknik Değişiklik Özeti (Build 31)
- **Arçelik / Beko / Grundig (`ArWebsocket` over `wss://<ip>:8080`):**
  - `ArcelikVestelUpnpDriver` içinde kalıcı WSS bağlantısı (`Sec-WebSocket-Protocol: ArWebsocket`, `userAgent: okhttp/3.12.1`), `on-rc-input` (`RC_*`), `on-keyboard-input`, `probeArWebsocket` ve `clearArWebsocketText` desteği.
  - Eski `56789` (Vestel SmartCenter) portundan `8080` ArWebsocket protokolüne otomatik geçiş ve keşif/tanılama iyileştirmesi.
- **Akıllı Otomatik Sesli Arama & Temizleme (`Android` / `iOS` / Tüm TV Sürücüleri):**
  - Android `RecognizerIntent` sessizlik süreleri (`1200ms`/`1000ms`) ve iOS `voiceSilenceTimer` (`1.15s`) optimize edildi; konuşma bittiğinde sonuç otomatik gönderilir (`submitEnter: true`).
  - `TvRemoteDriver.sendText(..., clearExisting: true)` sözleşmesi Samsung (`SendInputEnd` + `KEY_BACKSPACE`), LG (`replace: 1`), Roku (20x Backspace), Arçelik (`clearArWebsocketText`), Philips, VIDAA ve Android ADB/YouTube DIAL akışlarında uygulandı.
  - Sesli arama butonuna yeniden basıldığında hem uygulama içindeki metin hem de TV arama kutusundaki önceki metin otomatik silinir.
- **Kalite Kapısı:** `dart analyze` (0 hata) ve `flutter test` (51/51 test geçti) ile doğrulandı.
