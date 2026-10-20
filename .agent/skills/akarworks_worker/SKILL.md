---
name: akarworks-worker
description: Antigravity IDE ile Akarworks Otonom Fabrika İşçi Motoru (Worker) arasındaki çift hatlı senkronizasyon, JIT Ultra Yetenek Matrisi (8. İsraf Önleme) ve SMED hızlandırılmış otonom kodlama protokolü.
---

# Akarworks Otonom Fabrika Köprüsü (Antigravity 2.0 JIT Ultra & SMED Protokolü)

Bu beceri, Akarworks Mobil Kumandası ve Fabrika Motoru (`worker.py`) tarafından Antigravity IDE'ye gönderilen görevlerin [GEMINI.md](file:///c:/Users/theak/source/repos/akarworks/GEMINI.md) (Sürüm 2.1) yönetmeliğine uygun olarak **8. İsrafı (Yetenek İsrafı)** ve **Zaman İsrafını (Waiting/Over-Processing Muda)** sıfırlayarak işlenmesini sağlar.

---

## 🎯 BÖLÜM 1: 8. İSRAF (YETENEK İSRAFI) ÖNLEME & JIT ULTRA YETENEK MATRİSİ

Görev işlenirken ajanlar ellerindeki Gemini Ultra yeteneklerini atıl bırakamaz (8. İsraf: *Non-Utilized Talent*), ancak basit görevlerde de gereksiz araç çalıştırarak vakit kaybedemez (*Over-Processing Muda*):

1. **UI/UX, Kart, Rozet & Görsel Görevler (`ui_design` / `creative_media`):**
   - **Mimar Sinan Zorunluluğu:** Standart `Icons.*` ve düz `Container` ile yetinmek yasaktır!
   - Göreve özel arka plan/rozet/illüstrasyon gerekiyorsa `invoke_subagent` ile `image-generator` (Nano Banana) çağrılır veya zengin geometrik/hat sanatı `CustomPainter` / Shader katmanı kodlanır.
   - Üretilen görsel veya medya varlıkları `python C:/Users/theak/source/repos/akarworks/worker/akarworks_bridge.py save-ultra-asset <task_id> nano_banana "<Başlık>" "<DosyaYolu>" mimar_sinan` komutuyla Google Drive `Media_Studio/` klasörüne arşivlenir.
2. **Çok Dosyalı / Karmaşık Mimari Görevler (`complex_software`):**
   - **Kanuni Deep Think UX:** Kullanıcı talebine Haptic geri bildirim, mikro-animasyon eğrileri ve edge-case korumaları eklenir.
   - **Paralel Alt-Ajan Hücreleri (`invoke_subagent`):** 3 veya daha fazla bağımsız dosya/katman değişecekse, tek ajanın seri çalışması yerine veri katmanı (`provider`) ve arayüz katmanı (`widget`) paralel alt-ajanlarla eşzamanlı yürütülür.
3. **Araştırma, Benchmark & Piyasa Radarı (`research`):**
   - **Hezarfen Deep Research:** `search_web` veya `research` alt-ajanı ile gerçek rakipler ve mağaza 1-yıldız yorumları incelenir; çıktı `save-ultra-asset <task_id> deep_research` ile Google Drive `NotebookLM_Sources/` klasörüne kaydedilir.
4. **Hızlı Hat: Basit Bug, Metin & Ayar (`fast_track`):**
   - Sıfır ek yük: Ağır görsel veya dış araştırma araçları tetiklenmez; doğrudan hedef dosyada atomik düzeltme yapılır.

---

## ⚡ BÖLÜM 2: YALIN HIZLANDIRMA (SMED - 4 SANİYE ANALİZ KURALI)

Görev tamamlanma sürelerini %60-%70 kısaltmak için şu kurallar kesindir:
1. **Tam Depo `flutter analyze` Yasağı:** Tüm depo üzerinde `flutter analyze` çalıştırmak (~110 sn) yerine **yalnızca değiştirilen ve eklenen dosyalar üzerinde** `dart analyze <değişen_dosya_1> <değişen_dosya_2>` (~4 sn) çalıştırılır (0 hata / 0 uyarı).
2. **Hedefli Birim Testi:** Tüm test süitini baştan sona koşturmak yerine yalnızca ilgili özelliğin testi (`flutter test test/<ilgili_test>.dart`) çalıştırılır.
3. **Sıfır Onay Diyaloğu (Zero-Prompt):** Bilgisayar başında kullanıcı bulunmadığında etkileşimli onay bekleyen `call_mcp_tool` yerine doğrudan `write_file` ve `run_command` (`python C:/Users/theak/source/repos/akarworks/worker/akarworks_bridge.py ...`) kullanılır.

---

## 🌉 BÖLÜM 3: SONUÇ RAPORLAMA VE YETENEK KANIT KARNESİ (`ultra_talent_proof`)

İşlem tamamlandığında `C:/Users/theak/source/repos/akarworks/worker/sync_drive/result_<task_id>.json` dosyasına şu yapı yazılır:
```json
{
  "executive_summary": "• 1. Somut yapılan iş ve mimari kazanım\n• 2. Güncellenen gerçek dosyalar ve bileşenler\n• 3. ⚡ Ultra Kalite Katkısı: Kullanılan Gemini Ultra yeteneği ve yarattığı fark\n• 4. Hedefli dart analyze (0 hata) ve test sonuçları",
  "ultra_talent_proof": "Bu görevde 8. İsrafı (Yetenek İsrafı) önlemek adına [Mimar Sinan Nano Banana / CustomPainter / Kanuni Deep Think UX / Paralel Alt-Ajan / Hezarfen Deep Research] yeteneği aktif kullanılmış ve [somut kalite çıktısı] üretilmiştir.",
  "steps": [
    {"step": 1, "title": "Adım Başlığı", "description": "Yapılan somut teknik işlem", "target_file": "gercek/dosya/yolu.dart", "agent": "mimar_sinan", "status": "completed"}
  ],
  "changed_files": ["gercek/dosya/yolu.dart"],
  "changelog_tr": "Türkçe sürüm notu başlığı ve açıklaması",
  "changelog_en": "English release note title and description",
  "changelog_type": "improvement",
  "changelog_icon": "auto_awesome_rounded",
  "report": "# 🛡️ Teknik İcra Raporu\n\nDetaylı Markdown rapor..."
}
```
Ardından şu komutla görev tek seferde tamamlanır:
```bash
python "C:/Users/theak/source/repos/akarworks/worker/akarworks_bridge.py" complete-task <task_id> "C:/Users/theak/source/repos/akarworks/worker/sync_drive/result_<task_id>.json"
```
