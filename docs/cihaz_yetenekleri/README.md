# Cihaz Yetenek Dökümleri (`Zamera Probe`)

Bu klasör, **Faz 0** kapsamında geliştirilen **Zamera Probe** ekranından alınan gerçek cihaz kamera yetenek JSON çıktılarını barındırır.

## Hedef Cihazlar
1. `xiaomi_17_pro_max.json` — Android Camera2 API yetenek dökümü (`INFO_SUPPORTED_HARDWARE_LEVEL`, `RAW_SENSOR`, `ULTRA_HIGH_RESOLUTION_SENSOR`, fiziksel lens ID'leri, `DynamicRangeProfiles` HLG10/10-bit, `LENS_SHADING_MAP`).
2. `iphone_17_pro_max.json` — iOS AVFoundation yetenek dökümü (`.builtInWideAngleCamera`, `.builtInTelephotoCamera`, `.builtInUltraWideCamera`, Bayer RAW 12MP vs ProRAW 48MP formatları, Apple Log / Log 2 ve ProRes 422 HQ / Open Gate formatları).

## Nasıl Eklenir?
1. Uygulamayı cihazda açın ve sağ üstteki **Probe JSON Paylaş / Kopyala** butonuna dokunun.
2. Çıktıyı ilgili dosya adıyla bu klasöre kaydedin.
