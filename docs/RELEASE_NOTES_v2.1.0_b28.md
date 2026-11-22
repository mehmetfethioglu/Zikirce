# CueDeck v2.1.0 (Build 28) Sürüm Notları / Release Notes

## 🇹🇷 Türkçe Sürüm Notları

**Yayın Tarihi:** 22 Kasım 2026  
**Sürüm:** `v2.1.0+28`

### Yenilikler
1. **Kapalı TV Uyandırma — IR Olmayan iPhone & Android Telefonlarla Evrensel Wake-on-LAN:**
   - **Manuel MAC Kurulumu & Hızlı Uyandırma (`WakeOnLanSetupSheet`):** Kumanda üzerindeki **`⚡ TV Uyandır`** çipi, Ayarlar **`⚡ WoL MAC`** satırı ve Ağ Tarama ekranı üzerinden TV'nin MAC adresi (ve opsiyonel IP adresi) kolayca kaydedilip tek dokunuşla uyandırılabilir.
   - **Çoklu Marka Otomatik MAC Keşfi:** Samsung Tizen (`8001/api/v2/`), Roku (`8060/query/device-info`), Google Cast / Android TV (`8008/setup/eureka_info` + ADB `wlan0`/`eth0`), SSDP (`WAKEUP: MAC=...`), UPnP XML ve mDNS `TXT` kayıtlarından otomatik MAC çıkarımı eklendi (modem `BSSID` adresleri hariç tutulur).
   - **Tüm Sürücülerde Güç Tuşu → WoL Yedeklemesi:** Philips JointSpace, Sony BRAVIA IRCC, Hisense/Toshiba VIDAA, Arçelik/Grundig, Vestel SmartCenter, UPnP/DLNA, Samsung Tizen, LG webOS, Roku ve Android/Google TV (`5555`/`6466`) sürücülerinde TV kapalıyken `Güç` tuşuna basıldığında otomatik Wake-on-LAN Magic Packet gönderilir ve ağ yeniden taramalarında kayıtlı MAC korunur.
   - **Gelişmiş Alt Ağ WoL Yayını:** `255.255.255.255` yanında hedef alt ağ yönlendirmeli yayın (`x.x.x.255`) ve çoklu paket gönderimi ile güvenilirlik artırıldı.

---

## 🇬🇧 English Release Notes

**Release Date:** November 22, 2026  
**Version:** `v2.1.0+28`

### What's New
1. **Wake Turned-Off TVs — Universal Wake-on-LAN for iPhone & Non-IR Android Phones:**
   - **Manual MAC Setup & One-Tap Wake (`WakeOnLanSetupSheet`):** Enter and save your TV's MAC address (plus optional IP) directly from the remote's **`⚡ TV Uyandır`** chip, Settings, or Network Discovery — even when the physical remote is lost and the TV is off.
   - **Multi-Brand Automatic MAC Discovery:** Automatically extracts TV MAC addresses from Samsung Tizen (`8001/api/v2/`), Roku ECP (`8060/query/device-info`), Google Cast / Android TV (`8008/setup/eureka_info` + ADB `wlan0`/`eth0`), SSDP (`WAKEUP: MAC=...`), UPnP XML, and mDNS `TXT` records while ignoring router `BSSID`.
   - **Universal Power Key → WoL Fallback:** All drivers (Philips JointSpace, Sony BRAVIA, Hisense/Toshiba VIDAA, Arçelik/Vestel/UPnP, Samsung Tizen, LG webOS, Roku, and Android/Google TV `5555`/`6466`) now automatically send Wake-on-LAN magic packets when pressing Power on an offline TV and preserve saved MACs across rescans.

---

## 📱 Google Play Console XML (<500 Karakter)

```xml
<tr-TR>
v2.1.0:
• Kapalı TV Uyandırma (Wake-on-LAN): IR vericisi olmayan iPhone ve Android telefonlarla kapalı TV'leri açın.
• Manuel MAC Kurulumu: Kumanda («⚡ TV Uyandır»), Ayarlar ve ağ taramadan MAC adresini kolayca kaydedip uyandırın.
• Otomatik MAC Keşfi: Samsung, LG, Roku, Philips, VIDAA, Sony, Arçelik/Vestel ve Android/Google TV'lerden otomatik MAC algılama.
• Tüm sürücülerde Güç tuşuna otomatik Wake-on-LAN yedeklemesi eklendi.
</tr-TR>
<en-US>
v2.1.0:
• Wake Turned-Off TVs (Wake-on-LAN): Power on compatible TVs from iPhones and Android phones without an IR blaster.
• Manual MAC Setup: Save your TV's MAC address and wake it with one tap from the remote, Settings, or Network Discovery.
• Multi-Brand Auto MAC Discovery: Automatic MAC extraction across Samsung, LG, Roku, Philips, VIDAA, Sony, Arcelik/Vestel, and Android/Google TV.
• Automatic Power-key Wake-on-LAN fallback added across all TV drivers.
</en-US>
```
