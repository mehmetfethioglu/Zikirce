# CueDeck v2.0.0 (Build 25) Sürüm Notları / Release Notes

## 🇹🇷 Türkçe Sürüm Notları

**Yayın Tarihi:** 17 Kasım 2026  
**Sürüm:** `v2.0.0+25`

### Yenilikler
1. **Evrensel Smart TV Sürücü Mimarisi (Faz 1):**
   - **Samsung Tizen (`wss://:8002` & `ws://:8001`):** Kalıcı WebSocket bağlantısı, eşleştirme token saklama, telefonda klavye IME metin enjeksiyonu ve Wake-on-LAN (Magic Packet) ile kapalı TV uyandırma.
   - **LG webOS (`wss://:3001` & `ws://:3000`):** `client-key` kalıcı kayıt, gerçek `getPointerInputSocket` üzerinden yön tuşları (`UP`/`DOWN`/`LEFT`/`RIGHT`/`ENTER`/`BACK`/`HOME`), Magic Mouse imleç hareketi, sol/sağ tık ve dokunmatik tekerlek kaydırma.
   - **Roku ECP (`:8060`), Philips JointSpace (`1926/1925`), Hisense VIDAA (`36669`), Sony Bravia IRCC-IP, Arçelik / Grundig / Vestel (`8085`/`56789`/`7681`) + UPnP/DLNA:** Tüm popüler Smart TV ağ protokolleri modüler tek kayıt merkezinde (`TvDriverRegistry`) birleştirildi.
   - **Wi-Fi Gerektirmeyen Kızılötesi (IR) Kumanda Modu:** IR vericili Android telefonlar için 7 marka profili (Arçelik/Beko, Vestel/Regal, Samsung, LG, Sony, Philips, TCL/Sunny) ile donanımsal `ConsumerIrManager` kontrolü.
2. **Paylaş Menüsünden Doğrudan TV'ye Işınlama (Faz 2):**
   - YouTube, Netflix, Prime Video, tabii veya web tarayıcıdan **«Paylaş → CueDeck»** ile ya da **«📲 Link Işınla»** tuşuyla linki yakalayıp tek dokunuşla TV'de başlatma veya akşam saatine planlama (`ShareToTvBeamSheet`).
   - Evrensel **YouTube DIAL v2 / Lounge** başlatıcısı ile Android TV dışındaki Samsung, LG ve Roku TV'lere doğrudan video/oynatma listesi gönderme.
3. **Esnek Pro Planlar & Temiz Katmanlı Mimari (Faz 3):**
   - Haftalık, Yıllık Pro (**3 Gün Ücretsiz Deneme**), Ömür Boyu Tek Ödeme ve 10 günlük sadakat ödülü seçenekleri + 1 ödüllü reklam ile 24 Saat Pro Pass.
   - Sıfır harici bağımlılık artışıyla 5 katmanlı döngüsüz DAG & SOLID yazılım mimarisi.

---

## 🇬🇧 English Release Notes

**Release Date:** November 17, 2026  
**Version:** `v2.0.0+25`

### What's New
1. **Universal Smart TV Driver Engine (Phase 1):**
   - **Samsung Tizen (`8002`/`8001`):** Persistent WebSocket session, local token vault, IME text injection, and Wake-on-LAN Magic Packet power-on.
   - **LG webOS (`3001`/`3000`):** Persistent `client-key` pairing plus `getPointerInputSocket` support for hardware D-Pad navigation, Magic Remote cursor tracking, wheel scrolling, and SSAP text input.
   - **Roku (`8060`), Philips (`1926`/`1925`), Hisense VIDAA (`36669`), Sony IRCC-IP, Arçelik / Vestel / UPnP-DLNA:** Unified multi-protocol remote engine (`TvDriverRegistry`).
   - **Zero-Wi-Fi Android IR Blaster Mode:** Hardware `ConsumerIrManager` support across 7 major TV brand profiles (NEC, Samsung32, RC5, Sony12).
2. **Share-to-TV Instant Beaming (Phase 2):**
   - Share any YouTube video/playlist or streaming URL directly from Android/iOS Share Sheet or `cuedeck://share` to **Launch on TV Now** or **Schedule Tonight** via Universal DIAL v2 & ADB.
3. **Flexible Pro Plans & 5-Layer Clean Architecture (Phase 3):**
   - Weekly, Annual (3-Day Free Trial), Lifetime Pro, Loyalty 40% discount, plus 24-Hour Rewarded Pro Pass without interrupting basic remote control keys.
