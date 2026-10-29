# CueDeck v1.9.5 (Build 17) — Çift Dilli Sürüm Notları / Bilingual Release Notes

## 🇹🇷 Türkçe (`tr-TR`)
- **Doğal iOS `en0` (`IP_BOUND_IF`) & Bonjour TV Tarayıcı:** iPhone 17 Pro Max ve iOS cihazlarda hücresel veri (`pdp_ip0`) ve iCloud Özel Geçiş (`utun`) yönlendirmesini aşarak doğrudan fiziksel `en0` Wi-Fi donanım arayüzüne bağlanan doğal Swift (`AppDelegate.swift`) ADB ve `/24` alt ağ tarayıcısı eklendi.
- **2-Aşamalı Wi-Fi ARP Uyandırma & Tam `/24` Ağ Taraması:** Wi-Fi güç tasarrufundaki (`DTIM` uyku modu) TV'leri önce hızlı ARP uyandırma paketiyle uyandırıp ardından Port 5555 ve 6466 üzerinden tespit eden 2 aşamalı keşif motoru devreye alındı.
- **iPhone «Yerel Ağ» İzin Denetimi:** iOS Yerel Ağ izni kapalıysa (`errno 65 EHOSTUNREACH`) otomatik algılayıp doğrudan `iPhone Ayarlar > CueDeck > Yerel Ağ` sayfasını açan tek dokunuşlu buton eklendi.

## 🇺🇸 English (`en-US`)
- **Native iOS `en0` (`IP_BOUND_IF`) & Bonjour TV Scanner:** Added a native Swift (`AppDelegate.swift`) ADB and `/24` subnet scanner bound directly to the physical `en0` Wi-Fi hardware interface on iPhone 17 Pro Max, bypassing cellular (`pdp_ip0`) and VPN/Private Relay (`utun`) routing.
- **2-Stage Wi-Fi ARP Warmup & Full `/24` Subnet Sweep:** Wakes 802.11 power-saving TVs with an initial ARP warmup wave before probing Ports 5555 and 6466.
- **iOS Local Network Permission Detector:** Automatically detects `EHOSTUNREACH (errno 65)` when iOS Local Network access is disabled and provides a 1-tap shortcut to `iPhone Settings > CueDeck > Local Network`.
