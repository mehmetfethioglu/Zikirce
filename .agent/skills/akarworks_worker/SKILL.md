---
name: akarworks-worker
description: Antigravity IDE ile Akarworks Otonom Fabrika İşçi Motoru (Worker) arasındaki çift hatlı senkronizasyon ve otonom kodlama/planlama protokolü.
---

# Akarworks Otonom Fabrika Köprüsü (Antigravity 2.0 JIT Remote Cockpit Protokolü)

Bu beceri, Akarworks Mobil Kumandası ve Fabrika Motoru (`worker.py`) tarafından Antigravity IDE'ye gönderilen görevlerin [GEMINI.md](file:///c:/Users/theak/source/repos/akarworks/GEMINI.md) yönetmeliğine uygun, iki aşamalı (Planlama ➔ Onay ➔ İcra) ve sıfır halüsinasyonla işlenmesini sağlar.

---

## 🏛️ FAZ 1: KANUNİ MİMARİ PLANLAMA (Planning Phase)
Görev ilk atandığında veya plan revizyonu istendiğinde:
1. `worker/sync_drive/pending_plan_task.json` dosyasını veya verilen prompt talimatını incele.
2. **Genchi Genbutsu (Yerinde İnceleme):** Projenin gerçek dosya ağacını (`lib/`, `pubspec.yaml`, rotalar, `docs/`) oku. Asla uydurma/varsayımsal dosya veya paket adı üretme.
3. **Görev Türü Ayrımı:**
   - **Yazılım Görevi:** Gerçek dosya rotalarını ve servisleri belirle (`lib/main.dart`, vb.).
   - **Tasarım / Medya / Karakter Görevi:** Flutter kodu yerine; Karakter Anatomisi, Görsel Üretim Promptları (DALL-E/Midjourney), Ses Tasarımı ve Sosyal Medya Senaryoları planla (`docs/media/`).
4. **Planı Teslim Et:**
   - Planı `pending_plan_task.json` içine `"status": "completed"` ve `"plan_data"` olarak kaydet veya şu komutla doğrudan Supabase'e fırlat:
     ```bash
     python C:/Users/theak/source/repos/akarworks/worker/akarworks_bridge.py report-plan <task_id> <plan_json_path>
     ```
   - Görev mobilde anında **Onay Bekliyor (waiting_plan_approval)** durumuna geçer.

---

## 🛠️ FAZ 2: OTONOM İCRA & KALİTE GÜVENCESİ (Execution Phase)
Mobil yönetici plandaki adımları onayladığında:
1. `worker/sync_drive/pending_coding_task.json` dosyasını incele.
2. **Poka-Yoke Git Kontrolü:** Proje dizininde `branch_name` (`akarworks/feature-<task_id>`) dalında olduğunu ve `checkpoint/task-<task_id>` emniyet etiketinin mevcut olduğunu teyit et. Asla `main` üzerinde çalışma.
3. **Yol Haritasına Sadakat:** Onaylanan güncel yol haritasındaki (`steps`) her bir maddeyi sırasıyla icra et (`edit_file`, `write_to_file`).
4. **Kalite Standartları:**
   - Yazılım projelerinde `flutter analyze` 0 hata/0 uyarı ve `test_cmd` %100 yeşil olmalıdır.
   - Deterministik `dispose()` ve Riverpod fine-grained selector kurallarına uyulur.
   - Medya ve karakter projelerinde çıktılar `docs/media/` altına eksiksiz yazılır.
5. **Sonuç Raporlama:**
   - `worker/sync_drive/pending_coding_task.json` dosyasını güncelle:
     ```json
     {
       "task_id": "<TASK_ID>",
       "status": "completed",
       "report": "### 🛠️ Yapılan Teknik İşler & Doğrulama:\n...",
       "executive_summary": "• 1. madde\n• 2. madde",
       "changelog_tr": "Kullanıcıya yönelik Türkçe sürüm notu",
       "changelog_en": "User-facing English release note"
     }
     ```
   - Veya köprü komutunu çalıştır:
     ```bash
     python C:/Users/theak/source/repos/akarworks/worker/akarworks_bridge.py complete-task <task_id> <result_json_path>
     ```
   - Görev mobilde **Onay Bekliyor (waiting_approval)** durumuna geçer ve yönetici 'Onayla ve Birleştir' diyene kadar izole dalda emniyetle bekletilir.
