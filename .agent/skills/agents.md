# Skill: Akarworks 11-Sensei Yıldız Topolojisi & Yalın Token Ekonomisi (v5.1)

Description: Ultra-yalın 11-Sensei otonom yazılım fabrikası orkestrasyonu. Mükerrer dosya okumalarını, gereksiz alt-ajan çağrılarını ve MCP şema şişkinliğini sıfırlayan Kanuni-Defterdar Token Ekonomisi protokolü.

---

## 1. 11-Sensei Yıldız Topolojisi & Model Katmanlaması (`Model Tiering`)

| Sensei | Rol & Sorumluluk | Varsayılan Çağrı Modu | MCP Şeması (`inheritMcp`) |
| :--- | :--- | :--- | :--- |
| **`kanuni`** | Orkestra Şefi, Promptmaster 9D, Veri Modeli & Hızlı Hat İcrası | Ana Oturum | `false` |
| **`mimar-sinan`** | 60/120 FPS Flutter UI, `CustomPainter`, Riverpod `.select()` | `Model: "inherit"` | `true` (`flutter_dart`) |
| **`cezeri-piri`** | TCP 4370, SQLite/Supabase İndeks, GIS/DPoP, Drive Senkron | `Model: "inherit"` | `false` |
| **`hezarfen`** | `search_web` Rakip Radarı, `notebooklm-mcp`, `_AudioOverview.mp3`, GEO/ASO | `Model: "flash"` | `true` (`notebooklm`) |
| **`barbaros`** | SemVer +1, Çift Dilli Sürüm Notu, Play/App Store CI/CD & GEO Paketi | `Model: "flash"` | `false` |
| **`katip-celebi`** | Sıcak Hafıza (`PROJECT_MEMORY.md <= 4 KB`), `docs/kararlar.md` & NotebookLM | `Model: "flash"` | `true` (`notebooklm`) |
| **`el-kindi`** | Salt-Okunur SAST (`el_kindi_security_scanner.py`, `bandit`) | Birleşik CLI / `flash` | `false` |
| **`kilic-ali`** | Salt-Okunur Red-Team (`kilic_ali_pentest_simulator.py`) | Birleşik CLI / `flash` | `false` |
| **`ali-kuscu`** | Salt-Okunur 120 FPS, `dispose()` & SQLite (`ali_kuscu_observatory.py`) | Birleşik CLI / `flash` | `false` |
| **`ebussuud`** | Salt-Okunur Hedefli `dart analyze`, `flutter test` & `google-lean-guardrails` | Birleşik CLI / `flash` | `false` |
| **`matrakci`** | Salt-Okunur Görsel "Göz", `widget_inspector` & `<= 390px` Taşma Denetimi | `Model: "flash"` | `true` (`flutter_dart`) |

---

## 2. Kanuni-Defterdar Token Tasarruf Kuralları (Sıfır Muda)

1. **Hat 1 (`1–2 Dosya`):** Alt-ajan çağrılmaz (`0 subagent`). `kanuni` doğrudan düzenler ve `dart analyze <dosya>` çalıştırır.
2. **Hat 2 (`3–5 Dosya`):** 5 ayrı denetçi alt-ajan başlatılmaz! `akarworks_unified_audit.py --audit "<Proje>" --files <dosyalar>` ile El-Kindi, Kılıç Ali, Ali Kuşçu ve Ebussuud kontrolleri **0 LLM Token** ile tek komutta koşulur.
3. **Hat 3 (`6+ Dosya / Kritik Mimari`):** Denetçi alt-ajanlar `Model: "flash"` ile çağrılır; sağlam dosyaları baştan sona okumaz, yalnızca CLI bulgu satırlarını (`StartLine`/`EndLine`, maks. 5 `read_file`) inceler.
4. **Sıcak Hafıza Tavanı:** `.agent/PROJECT_MEMORY.md` maksimum `4 KB` (~800 token) güncel mimari indeks tutar; geçmiş kararlar `docs/kararlar.md` dosyasına arşivlenir.
