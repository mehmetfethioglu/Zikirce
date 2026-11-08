# Cihaz Yetenek Dökümleri (`Zamera Probe`)

Bu klasör, **Faz 0** kapsamında geliştirilen **Zamera Probe** ekranından alınan gerçek cihaz kamera yetenek JSON çıktılarını barındırır.

## Mevcut & Hedef Cihaz Dökümleri
1. [`xiaomi_14_houji_probe.json`](file:///c:/Users/theak/source/repos/zamera/docs/cihaz_yetenekleri/xiaomi_14_houji_probe.json) — Doğrulanmış fiziksel **Xiaomi 14 (`23127PN0CG`, `houji`, Android 16 / SDK 36)** Camera2 API yetenek dökümü (`INFO_SUPPORTED_HARDWARE_LEVEL_3`, `RAW_SENSOR 4096x3072`, fiziksel lens ID'leri `#2` 23mm Ana ve `#3` 14mm Ultra Geniş, `DynamicRangeProfiles` `HLG10`/`HDR10`/`HDR10_PLUS`/`DOLBY_VISION_10B`, `LENS_SHADING_MAP`).
2. `iphone_pro_probe.json` (Hedef) — iOS AVFoundation yetenek dökümü (`.builtInWideAngleCamera`, `.builtInTelephotoCamera`, `.builtInUltraWideCamera`, Bayer RAW 12MP vs ProRAW 48MP formatları, Apple Log / Log 2 ve ProRes 422 HQ / Open Gate formatları).

## Nasıl Eklenir?
1. Uygulamayı cihazda açın ve sağ üstteki **Probe JSON Paylaş / Kopyala** butonuna dokunun.
2. Çıktıyı ilgili dosya adıyla bu klasöre kaydedin.
