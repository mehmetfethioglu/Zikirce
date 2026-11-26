# Zamera v0.1.7 (Build 8) — Çift Dilli Mağaza Sürüm Notları (Google Play & App Store Connect)

## 1. Google Play Console (`<500` Karakter)

<tr-TR>
Zamera v0.1.7:
• Abonelik & Uyum: 30 gün ücretsiz deneme sonrası otomatik abonelik yenileme doğrulaması, Google Play teklif token koruması ve Kullanım Koşulları (EULA) eklendi.
• Çift Dilli TR/EN & Erişilebilirlik: Türkçe/İngilizce arayüz, TalkBack etiketleri ve Android 11+ bağlantı uyumu sağlandı.
• 120 FPS & Güvenlik: İzole vizör telemetrisi, panik korumalı 16 KB hizalı Rust renk çekirdeği ve yalnızca kamera oturumunda açık ekran koruması.
</tr-TR>

<en-US>
Zamera v0.1.7:
• Billing & Store Compliance: Added StoreKit 2 / Play Billing lifecycle revalidation, free-trial offerToken selection, and Terms of Use (EULA) links.
• Bilingual TR/EN & Accessibility: Added English/Turkish UI support, Semantics labels for screen readers, and Android 11+ external URL queries.
• 120 FPS & Hardening: Isolated live telemetry repaints, added Rust FFI catch_unwind/bounds guards, and scoped keep-screen-on strictly to active camera sessions.
</en-US>

---

## 2. Apple App Store Connect & TestFlight (`v0.1.7` — Build `8`)

### Türkçe (tr)
Zamera v0.1.7 Yenilikleri:
• iOS Rust Çekirdeği & FFI Emniyeti: Ortak Rust renk bilimi motoru (zamera_core) iOS derlemesine doğrudan bağlandı; tüm FFI sınırları taşma ve panik (catch_unwind) korumasıyla güçlendirildi.
• Zamera Pro Abonelik Senkronizasyonu & EULA: StoreKit 2 üzerinde 30 gün ücretsiz deneme sonrası yenileme doğrulaması, asenkron Satın Alımları Geri Yükleme akışı ve Kullanım Koşulları (EULA) bağlantısı eklendi.
• Çift Dilli Arayüz (TR/EN) & Erişilebilirlik: İngilizce/Türkçe sistem dili desteği, iOS izin açıklamalarının yerelleştirilmesi ve VoiceOver erişilebilirlik etiketleri eklendi.
• 120 FPS Vizör Performansı: Canlı pozometre, kolorimetre ve sinema telemetri katmanları RepaintBoundary ile izole edilerek dokunmatik kadran akıcılığı artırıldı.

### English (en-US)
What's New in Zamera v0.1.7:
• Native iOS Rust Linkage & FFI Safety: Linked the shared Rust color-science engine (zamera_core) directly into iOS builds and hardened all C/JNI FFI boundaries with catch_unwind and bounds validation.
• Zamera Pro Billing Sync & EULA: Added StoreKit 2 / Google Play Billing lifecycle revalidation across trial-to-paid transitions, reliable async purchase restore, and Terms of Use (EULA) links.
• Bilingual TR/EN UI & Accessibility: Added English/Turkish localization, localized iOS permission prompts, VoiceOver/TalkBack Semantics labels, and Android 11+ URL query support.
• 120 FPS Viewfinder Isolation: Decoupled live telemetry updates from root widget rebuilds using ValueNotifier and RepaintBoundary layers for smoother manual dial responsiveness.
