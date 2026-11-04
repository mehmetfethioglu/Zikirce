# Akarworks Proje Kuralları (v6.0 — 6-Sensei Yalın Mimari)

> **Not:** Çekirdek 6-Sensei ve Kota Ekonomisi kuralları Global Anayasa (`C:\Users\theak\.gemini\GEMINI.md`) üzerinden yüklenir.

## 1. Kod Kalitesi & 120 FPS Standartları
- Değişen Dart dosyalarında `dart analyze --no-fatal-infos <değişen_dosyalar>` çıktısında **0 Hata / 0 Uyarı** zorunludur.
- Riverpod `ref.watch(provider.select(...))` izolasyonu, `const` widget ayrıştırması ve tüm controller/timer/subscription nesnelerinin `dispose()` içinde temizliği şarttır.

## 2. Git & Dağıtım Güvenliği
- Uzaktan otonom görevlerde (`pending_coding_task.json`) yönetici onayı olmadan `main` dalına birleştirme veya mağaza yayını yapılmaz.
