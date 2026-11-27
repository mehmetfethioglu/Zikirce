# Hasibu (`com.akarworks.hasibu`)

**Hasibu** is a cross-platform (Android, iOS, Windows ARM64/x64) offline-first enterprise attendance (PDKS), shift scheduling, leave management, and encrypted digital personnel dossier platform developed by **Akarworks (Akar Bilişim Teknolojileri)**.

> **Güncel Sürüm:** `v1.0.18+19` (Windows ARM64 MSIX: `1.0.18.0`)

---

## Temel Yetenekler (Faz 1 — Aktif Kurumsal PDKS & İK Platformu)

- **Canlı Yoklama & Çoklu Şube Yönetimi:** Gerçek zamanlı giriş/çıkış takibi, çoklu şube yetkilendirmesi (`allowedBranchIds`), katı şube sorumlusu izolasyonu ve yetkili şube değiştirici.
- **Çok Günlü Devam / Devamsızlık Raporu, Aylık Puantaj Matrisi & CSV Dışa Aktarım:** Tarih aralığı, şube ve durum bazlı puantaj analizi, 31 günlük cetvel, hafta tatili/UBGT mesaisi ve formül enjeksiyonu korumalı UTF-8 BOM CSV raporu.
- **Yüz Okutma Terminali & Windows Şube Köprüsü:** Tenfei D35 / ZKTeco TCP 4370 terminalleriyle çift yönlü senkronizasyon (çekim, saat eşitleme, kadro gönderme/ayrılan silme) ve `HasibuBranchBridge.exe` üzerinden çakışmasız şube gelen kutusu (`hasibu_branch_inbox_<slug>.enc`).
- **Şube GPS Konum Yoklama:** Sahte konum (`isMocked`) kalkanlı ve Geofence doğrulamalı mobil giriş/çıkış.
- **Vardiya Rotasyonu, Yarım Gün İzin & 4857 Uyum:** Tarih bazlı vardiya atamaları, yarım gün/saatlik izin ve Arefe takibi, dini bayram & UBGT takvimi, 4857 uyumlu izin bakiyesi (0.5 gün hassasiyetli), gece 7,5 saat ve haftalık 45 saat uyarıları.
- **Personel Self-Servis Portalı & Dijital Özlük Dosyası:** Kişisel aylık puantaj özeti, zorunlu/opsiyonel evrak kontrol listesi (KVKK açık rıza dahil) ve AES-256-GCM şifreli `.hasibu_doc` belge kasası.
- **Tekil Otomatik Giriş & Şifre Kurtarma:** Rol sekmesiz tekil kimlik algılama, ilk kurulumda zorunlu yönetici parola kalkanı ve şirket Gmail hesabı üzerinden 6 haneli tek kullanımlık doğrulama koduyla parola sıfırlama.
- **Sıfır-Sunuculu Güvenlik & Bulut Yedekleme:** Yerelde **SQLCipher AES-256** veritabanı, **PBKDF2/Argon2id** parola özetleme, **HMAC-SHA256** kayıt bütünlüğü ve yalnızca kullanıcının kendi Google Drive hesabında (`drive.file` dar kapsamı) saklanan **AES-256-GCM** şifreli yedekler.

---

## Platformlar & Dağıtım

- **Android:** Kod karartmalı (`--obfuscate`) Release `.aab` (Google Play) ve `.apk`
- **iOS:** Xcode 27 / iOS 27 SDK (`ITMS-90725` uyumlu) TestFlight dağıtımı (`.github/workflows/ios-build.yml`)
- **Windows (ARM64):** Kod karartmalı Release MSIX (`com.akarworks.hasibu`)
- **Şube Köprüsü (Windows x64):** `tools/hasibu_branch_bridge/` (.NET 10 tek dosya)

## Resmi Bağlantılar

- **Ana Sayfa / Ürün Portalı:** https://mehmetfethioglu.github.io/hasibu-privacy/
- **Gizlilik Politikası (KVKK & Google API Limited Use):** https://mehmetfethioglu.github.io/hasibu-privacy/privacy.html
- **Teknik Destek:** https://mehmetfethioglu.github.io/hasibu-privacy/support.html
- **İletişim:** `akarbilisimteknolojileri@gmail.com`

## Yerel Doğrulama & Derleme Komutları

```powershell
flutter analyze
flutter test
flutter build apk --release --obfuscate --split-debug-info=./build/symbols --dart-define-from-file=.\dart_defines.local.json --android-skip-build-dependency-validation
flutter build appbundle --release --obfuscate --split-debug-info=./build/symbols --dart-define-from-file=.\dart_defines.local.json --android-skip-build-dependency-validation
flutter build windows --release --obfuscate --split-debug-info=./build/symbols --dart-define-from-file=.\dart_defines.local.json
dart run msix:create --build-windows=false
```
