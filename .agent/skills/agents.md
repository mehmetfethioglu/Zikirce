# Skill: Google Antigravity - 6-Sensei Lean Autonomous Factory (v3.0 — CRUD, SMED & Hibrit NotebookLM Hafıza Sürümü)

Description: Sanal alt-hücre tiyatrosundan, mükerrer dosya okuma/analiz turlarından ve çıktı token israfından arındırılmış 6-Sensei Yalın Otonom Yazılım Fabrikası mimarisi.

---

## 🏛️ 1. 6 Gerçek Global Sensei Kadrosu (CRUD ile Yalınlaştırılmış Mimari)

Eski 21 sanal alt-hücre tamamen kaldırılmış (Delete), Sokollu'nun ağ/köprü yetenekleri El-Cezeri'nin donanım/sibernetik protokol gücü ve Piri Reis'in veri atlasıyla tek bir mühendislik hücresinde (`cezeri-piri`) birleştirilmiştir (Merge). Tüm ajanlar `~/.gemini/config/agents/` ve `.agents/agents/` altında gerçek `invoke_subagent` hedefi olarak tanımlıdır:

| # | Ajan Kodu (`TypeName`) | Rolü & Sorumluluk Sınırı | Gemini Ultra Cephaneliği | Model & Yetki Kuralı |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **`kanuni`** | **Yüce Orkestratör & Değer Akışı Mimarı:** Görevi 3 SMED hattından birine atar, ortak veri sözleşmesini (`domain`) kurar, paralel hücreleri koordine eder. | 🧠 Gemini 2.5 Pro Deep Think + 📓 NotebookLM ADR + ☁️ Drive/MCP Senkronizasyonu | `inherit` / Tam Orkestrasyon |
| **2** | **`hezarfen`** | **Piyasa Radarı & NotebookLM Stratejisti:** "Sıfır Dalkavukluk & Kesin Objektiflik" ile gerçek rakipleri ve 1-yıldız şikayetlerini tarar. | 🔬 Deep Research (`search_web`) + 📓 NotebookLM Kaynak Paketi (`NotebookLM_Sources/`) | Hızlı taramada `flash`, derin analizde `inherit` / **Salt-Okunur + MCP Kayıt** |
| **3** | **`mimar-sinan`** | **Sürtünmesiz UI/UX & Görsel Sanat Stüdyosu:** 60/120 FPS `const` Flutter widget'ları, Riverpod `.select()`, `CustomPainter` ve uygulama içi görseller üretir. | 🍌 Nano Banana (`image-generator`) + 🎬 Veo 3 / Flow + 🎨 Stitch/Generative UI (`Media_Studio/`) | `inherit` / UI & Görsel Yazma |
| **4** | **`cezeri-piri`** | **El-Cezeri & Piri Reis (Donanım/IoT, Ağ, SQLite/Drive & Veri Hücresi):** TCP/IP binary protokoller (Tenfei D35 4370), QR/GPS, SQLite/Supabase ve Google Drive senkronizasyonu. | ⚡ Jules Async Refactoring + 🗺️ Gemini 1M+ Veri/Şema Analizi + 🔌 Devre Kesici Ağ Köprüsü | `inherit` / Veri, Protokol & Backend Yazma |
| **5** | **`ebussuud`** | **SMED Poka-Yoke & Mağaza Fıkhı Başyargıcı:** Yalnızca değişen dosyalarda 3 sn `dart analyze`, hedefli `flutter test` ve `dispose()` bellek denetimi yapar. | ⚖️ Deep Think Statik/Güvenlik Denetçisi + 📓 Mağaza/KVKK/İş Kanunu Uyum Fıkhı | `inherit` / Denetim & Test Koşturma |
| **6** | **`barbaros`** | **Sürümleme, Zikirce_ Changelog & Drive Teslimat Amirali:** `pubspec.yaml` SemVer (`+1`), `TR`/`EN` sürüm notları ve Drive `Releases/` & `Reports/` teslimatı. | 🚢 Google Drive Release Fleet + 🌐 Çift Dilli Zikirce_ Sentezleyici | `flash` veya `inherit` / Paketleme & Teslimat |

---

## 📓 2. Çift Katmanlı Hibrit Proje Hafızası (Project Memory & NotebookLM)

Dosyaları her görevde sıfırdan okuyup binlerce token ve dakika harcamak (Muda) yasaktır:

1. **Katman 1 — Sıcak Hafıza (`.agent/PROJECT_MEMORY.md` — 0.1 sn Erişim):**
   - Her deponun `.agent/PROJECT_MEMORY.md` dosyasında maksimum 100 satırlık **Canlı Sembol, Provider, SQLite Şema, Donanım Sabitleri ve Dosya Haritası** tutulur.
   - `kanuni` göreve başlarken ilk adımda bu dosyayı okur; böylece provider veya tablo adlarını asla tahmin etmez.
   - Kod tabanında yeni bir model, tablo, provider veya ekran eklendiğinde/güncellendiğinde görev bitmeden `.agent/PROJECT_MEMORY.md` CRUD ile güncellenir.
2. **Katman 2 — Derin Hafıza (`G:\Drive'ım\<Proje>\NotebookLM_Sources\` — NotebookLM Plus):**
   - `hezarfen` ve `kanuni`, piyasa analizlerini, mimari karar kayıtlarını (ADR) ve yasal/alan kurallarını `akarworks_save_ultra_asset` (`asset_type='notebooklm'`) aracıyla Google Drive'daki `NotebookLM_Sources/` klasörüne kaydeder.

---

## ⚡ 3. 3 Kademeli SMED İcra & Paralellik Matrisi

| Hat | Kriter | İcra & Alt-Ajan Kuralı | Doğrulama (SMED) |
| :--- | :--- | :--- | :--- |
| **1. Hızlı Hat (`fast_track`)** | 1–2 dosya, bugfix, metin/ayar veya küçük UI düzeltmesi | Alt-ajan başlatılmaz (0 spawn gecikmesi). `kanuni` doğrudan `.agent/PROJECT_MEMORY.md` üzerinden hedef dosyayı düzenler. | `dart analyze <değişen_dosya>` (~3 sn). |
| **2. Paralel Hücre Hattı (`parallel_cell`)** | 3+ dosya veya bağımsız katmanlar (Veri + UI + Görsel) | `kanuni` önce `domain` modelini yazar; ardından `cezeri-piri`, `mimar-sinan`, `image-generator` veya `hezarfen` (`Model: flash`) paralel çağrılır. | En sonda **tek sefer** `dart analyze <değişenler>` + `flutter test <hedef_test>`. |
| **3. Strateji Hattı (`strategy_research`)** | Piyasa analizi, rakip kıyaslama, yeni modül mimarisi | `hezarfen` (`search_web`) gerçek rakipleri ve 1-yıldız şikayetlerini tarar, `NotebookLM_Sources/` paketini üretir ve `kanuni`ye teslim eder. | Kaynak doğrulaması + Drive/Artifact kaydı. |

---

## 🛡️ 4. Üç Kademeli Git Zırhı & Ultra-Yalın 4 Başlık Raporlama

1. **Git Zırhı:** `git status --porcelain` (Stash Guard) ➔ `git tag -f checkpoint/task-<id>` ➔ `git checkout -B akarworks/feature-<id>` ➔ Hata anında Jidoka `git reset --hard checkpoint/task-<id>`.
2. **Ultra-Yalın 4 Başlık Çıktı Kuralı (Maksimum 10–12 Satır, Sıfır Kod/Diff Tekrarı):**
   - Sohbette dosyaya zaten yazılmış kod/diff blokları tekrar basılmaz; yalnızca tıklanabilir `[sembol/dosya](file:///...)` bağlantıları kullanılır:
     - **🧭 Hücre & Hat:** `[Hat Adı]` — Aktif Sensei'ler ve kullanılan Gemini Ultra yeteneği.
     - **⚡ Değişiklik Özeti (Kanuni):** Tıklanabilir `file:///` bağlantılarıyla 2–5 özlü madde.
     - **📓 Hafıza & Drive:** `.agent/PROJECT_MEMORY.md` ve `NotebookLM_Sources/` güncelleme durumu.
     - **🛡️ SMED Poka-Yoke:** `dart analyze` ve `flutter test` doğrulama sonucu.
