# Akarworks Otonom Fabrika Yönetmeliği & Anayasası (GEMINI.md)
> **Sürüm:** 2.1 (Yalın 8. İsraf: Yetenek İsrafı Önleme, JIT Ultra Matrisi, SMED Hızlandırma & Git Güvenceli Otonom Geliştirme Standardı)  
> **Kapsam:** Mobil Direktör Terminali, Arka Plan İşçi Motoru (`worker.py`), Antigravity 2.0 IDE ve 7 Sensei Çoklu Ajan (MAS) Ekosistemi.

---

## 🏛️ BÖLÜM 1: YALIN ÜRETİM (LEAN) FELSEFESİ VE TEMEL İLKELER

Akarworks Otonom Yazılım Fabrikası, Toyota Üretim Sistemi (TPS) ve Yalın Yazılım Geliştirme felsefesini (DOWNTIME - 8 İsraf) otonom kodlama süreçlerine tavizsiz uygular:

1. **Muda (無駄 - İsraf) Yok Etme & 8. İsraf (Yetenek İsrafı):**
   - **Ölü Kod İsrafı:** Kullanılmayan fonksiyonlar, ölü importlar, gereksiz soyutlamalar kod tabanından derhal ayıklanır (Seiri - Ayıklama).
   - **Token & Bağlam İsrafı:** Ajanlar gereksiz dosya okumaları veya sonsuz konuşmalar yapamaz. Yalnızca hedef dosyalar üzerinde atomik çalışılır.
   - **UI & Bellek İsrafı:** Gereksiz widget çizimleri (overdraw) ve rebuild'ler engellenir.
   - **8. İSRAF: Yetenek İsrafı (Non-Utilized Talent) & Aşırı İşleme Dengesi:**
     - Fabrika emrine tahsis edilmiş **Gemini Ultra Cephaneliğinin** (`image-generator` / Nano Banana, `search_web` / Deep Research, Deep Think UX/Mikro-Etkileşim Sentezi, `invoke_subagent` Paralel Alt-Ajan Hücreleri ve NotebookLM Kaynak Paketleri) ilgili görevde kullanılmayıp sıradan/jenerik kodlarla yetinilmesi **en büyük israftır (8. Muda: Yetenek İsrafı)**.
     - Buna karşılık, basit bir hata düzeltme veya tek satırlık ayar görevinde ağır görsel/araştırma araçlarını tetikleyerek zaman kaybetmek ise **Aşırı İşleme İsrafıdır (Over-Processing Muda)**. Bu denge **JIT (Tam Zamanında) Kademeli Yetenek Matrisi** ile sağlanır.
   - **Zaman & Bekleme İsrafı (SMED - Hedefli Doğrulama):**
     - Tüm depoda hantal `flutter analyze` (~110 sn) koşturmak yerine **yalnızca değişen dosyalarda** `dart analyze <değişen_dosyalar>` (~4 sn) ve **yalnızca ilgili hedef test dosyasında** `flutter test <hedef_test>` koşturulur. Ajan doğrulamayı tamamladığında arka plan işçisi (`worker.py`) mükerrer test çalıştırmaz.
2. **Jidoka (自働化 - Hata Anında Otonom Duruş):**
   - Fabrika hattında bir hata (derleme, analiz, test veya entegrasyon kırılması) tespit edildiğinde sistem hatayı örtbas etmez veya üzerine kod yazmaya devam etmez.
   - Hatayı tespit eden ajan derhal **Andon Kordonu**'nu çeker; işlem durdurulur ve düzeltme denenir. İki denemede çözülemezse emniyetli geri alma (Rollback) tetiklenir.
3. **Poka-Yoke (ポカヨケ - Hata Önleyici Tasarım):**
   - Hatanın oluşması tasarım ve altyapı seviyesinde imkansız kılınır. Tip güvenliği, statik kod analizi ve otomatik Git zırhı ile insan ve ajan hataları kaynağında engellenir.
4. **Tek Parça Akışı (One-Piece Flow / WIP = 1) & Hücresel Paralellik:**
   - Her proje deposunda aynı anda yalnızca **1 aktif kodlama görevi** yürütülebilir.
   - Ancak aktif görevin kendi içinde (3+ dosya veya bağımsız katmanlar varsa), ana orkestratör (Kanuni) işi tek başına seri yapmak yerine `invoke_subagent` (`image-generator`, `research`, `self`) ile **paralel mikro hücreler** çalıştırarak tamamlanma süresini %60-%70 kısaltır.
5. **Genchi Genbutsu (現地現物 - Yerinde İnceleme):**
   - Tahminlerle veya statik kelime eşleştiricilerle kod/plan yazılamaz. Gerçek dosya ağacı, gerçek hata logları ve gerçek linter çıktıları incelenerek kararlar verilir.

---

## 🎯 BÖLÜM 1.5: JIT (TAM ZAMANINDA) KADEMELİ ULTRA YETENEK MATRİSİ

8. İsrafı (Yetenek İsrafı) sıfırlamak ve yapılan işe "Gemini Ultra" kalitesini somut olarak yansıtmak için görevler 4 JIT hattına ayrılır:

| Görev Hattı | Tetiklenen Sensei & Ultra Yetenekleri | Zorunlu Kalite Çıktısı (Deliverable) | Hız & Paralellik Kuralı |
| :--- | :--- | :--- | :--- |
| **1. UI/UX, Kart, Rozet & Görsel Görevler** (`ui_design` / `creative_media`) | **Mimar Sinan** (`image-generator` / Nano Banana + `CustomPainter` / Shader) | Standart `Icons.*` ve düz `Container` ile yetinilmez! Projeye özel özgün görsel/doku (PNG/WebP) veya zengin geometrik/hat `CustomPainter` katmanı üretilir; görsel varlıklar `akarworks_bridge.py save-ultra-asset` ile Google Drive `Media_Studio/` klasörüne arşivlenir. | Görsel üretimi (`image-generator` alt-ajanı) ile UI widget kodlaması **paralel** yürütülür. |
| **2. Çok Dosyalı / Karmaşık Mimari Görevler** (`complex_software`) | **Kanuni + Piri Reis + Sokollu** (Deep Think UX + Paralel `self` Alt-Ajanları) | Kanuni, kullanıcı deneyimi inceliklerini (Haptic geri bildirim, ses efekti, animasyon eğrisi, edge-case koruması) mimariye işler. | 3+ dosya değişiminde veri katmanı (`provider`) ve sunum katmanı (`screen/widget`) paralel alt-ajanlarla eşzamanlı işlenir. |
| **3. Araştırma, Benchmark & Piyasa Radarı** (`research`) | **Hezarfen Ahmed** (`search_web` / Deep Research + `research` Alt-Ajanı) | Sıfır dalkavuklukla gerçek rakip ve mağaza 1-yıldız verileri taranır; çıktı `akarworks_bridge.py save-ultra-asset` ile Google Drive `NotebookLM_Sources/` altına kaydedilir. | `research` alt-ajanı web taramasını paralel yürütür. |
| **4. Hızlı Hat: Basit Bug, Metin & Ayar** (`fast_track`) | **İlgili Tekil Sensei** (Sıfır Ek Yük / Zero Over-Processing) | Ağır medya üretimi veya dış araştırma tetiklenmez; doğrudan hedef dosyada atomik düzeltme yapılır. | Tek adımda düzenleme + 4 sn `dart analyze <hedef_dosya>` ile anında teslimat. |

---

## 🛡️ BÖLÜM 2: GİT GÜVENCESİ & REGRESYON ÖNLEME ANAYASASI (ÜÇ KADEMELİ GİT ZIRHI)

Uzaktan görev atandığında mevcut çalışan oyun/uygulama kodlarının bozulmasını engellemek için şu beş kanun istisnasız uygulanır:

### 1. Kademe: Sahipsiz Değişiklik Koruması (Stash Guard)
- Herhangi bir görev işleme alınmadan önce projenin çalışma ağacı denetlenir (`git status --porcelain`).
- Eğer depoda kaydedilmemiş veya sahipsiz değişiklikler varsa, bunlar güvence altına alınmadan yeni dala geçilemez:
  ```bash
  git stash push -u -m "akarworks-autostash-before-<task_id>"
  ```

### 2. Kademe: Kararlı Durum Emniyet Etiketi (Baseline Checkpoint Tag)
- Göreve başlanmadan önce ana dalın (`main` / `master`) kararlı son commit'ine silinemez bir emniyet etiketi basılır:
  ```bash
  git tag -f checkpoint/task-<task_id>
  ```
- Bu etiket, görev başarıyla ana dala birleşene kadar silinmez ve en kötü senaryoda fabrika için mutlak sığınaktır.

### 3. Kademe: Sıkı İzole Dal Disiplini (Strict Branch Isolation)
- Ajanlar ASLA doğrudan `main` üzerinde kod yazamaz.
- Her görev için bağımsız bir özellik dalı açılır:
  ```bash
  git checkout -B akarworks/feature-<task_id>
  ```
- Tüm değişiklikler, derlemeler ve ara testler yalnızca bu izole dal içerisinde koşturulur.

### 4. Kademe: Jidoka Geri Alma Protokolü (Autonomous Rollback)
- Görev sırasında çözülemeyen bir hata oluşursa veya mobil yönetici terminalinden "İptal / Geri Al" emri verilirse:
  1. Ana dala dönülür: `git checkout main`
  2. Depo mutlak emniyet etiketine sıfırlanır: `git reset --hard checkpoint/task-<task_id>`
  3. Sahipsiz tüm geçici dosyalar temizlenir: `git clean -fd`
  4. Hatalı dal tamamen imha edilir: `git branch -D akarworks/feature-<task_id>`
  5. Varsa otomatik stash geri yüklenir: `git stash pop`
  6. Emniyet etiketi temizlenir: `git tag -d checkpoint/task-<task_id>`
- Böylece proje 1 saniye içinde görev verilmeden önceki kusursuz haline döner.

### 5. Kademe: İnsan Onay Kapısı / Turbo Teslimat
- Görev tamamlandığında detaylı rapor, `ultra_talent_proof` (8. İsraf yetenek kanıtı) ve sürüm notları Google Drive'a ve mobil kumandaya anında iletilir.

---

## ⚡ BÖLÜM 3: KOD YAZMA, HIZLANDIRILMIŞ ANALİZ VE KALİTE STANDARTLARI (POKA-YOKE & SMED)

Ajanlar kod üretirken aşağıdaki katı mühendislik standartlarına uymak zorundadır:

### 1. Hedefli Statik Analiz & Sıfır Tolerans (4 Saniye Kuralı)
- Zaman israfını önlemek için tüm depo üzerinde `flutter analyze` çalıştırmak yerine, **yalnızca değiştirilen ve eklenen dosyalar üzerinde** `dart analyze <dosya1> <dosya2>` çalıştırılır (**0 Hata ve 0 Uyarı** zorunludur).
- Python/Node.js projelerinde hedef dosyalar üzerinde flake8/eslint sıfır toleransla işletilir.

### 2. UI & Widget Rebuild İzolasyonu (Flutter / Riverpod)
- Gereksiz widget yeniden çizimleri (rebuild) kesinlikle yasaktır:
  - Bütün widget ağaçlarında `ref.watch(provider.select((s) => s.specificField))` seçicisi kullanılmalıdır.
  - Dinamik alt widget'lar `const` kurucularla izole bağımsız widget sınıflarına bölünmelidir.

### 3. Bellek ve Yaşam Döngüsü Disiplini (Deterministic Disposal)
- Bellek sızıntıları (Memory Leak) kritik kusurdur:
  - Bütün `TextEditingController`, `AnimationController`, `FocusNode`, `ScrollController`, `StreamSubscription` ve `ChangeNotifier` nesneleri `dispose()` metodu içinde deterministik olarak yok edilmelidir.

### 4. Asenkron & I/O Pipeline İzolasyonu
- UI iş parçacığı (UI thread / event loop) asla bloke edilemez.
- Ağır JSON parse işlemleri, FFI çağrıları veya yoğun veri işleme `compute()` veya izole worker thread'lerine devredilmelidir.

### 5. Tekil Hedefli Test Doğrulaması (Sıfır Mükerrer Test)
- Tüm test süitini 3 kez koşturmak yerine, ilgili özelliğin test dosyası (`flutter test test/<ilgili_test>.dart`) çalıştırılır ve %100 yeşil doğrulandığında `akarworks_bridge.py complete-task` ile görev tek seferde kapatılır.

---

## 👥 BÖLÜM 4: EKİP VE OPERASYON YÖNETMELİĞİ (7 SENSEI JIT HİYERARŞİSİ)

Görevlerin icrasında 7 Baş Sensei ve onların dinamik (JIT) mikro hücreleri görev yapar:

1. **Kanuni (Yüce Orkestratör, Deep Think & Değer Akışı):**
   - Görev sınırlarını çizer, kullanıcı taleplerine **Deep Think UX incelikleri** (Haptic, mikro-animasyon, ses, edge-case) katarak teknik şartnameye (PRD) dönüştürür.
   - Çok dosyalı görevlerde paralel alt-ajan (`invoke_subagent`) hücrelerini orkestre eder.
   - `Kanuni-Defterdar`: Token ve zaman israfını engeller.
2. **Mimar Sinan (Sürtünmesiz UI/UX, Nano Banana & Görsel Sanat):**
   - Sıfır overdraw, akıcı 60/120 FPS arayüz, özel `CustomPainter` sanat katmanları ve `image-generator` (Nano Banana) ile özgün uygulama içi görsel varlıklar üretir; `Media_Studio/` arşivine kaydeder.
   - `Sinan-Matrakçı`: Yalnızca mevcut golden testleri varsa hızlı ekran görüntüsü yakalar; golden testi olmayan görevlerde boşuna 35 sn bekleme yapmaz.
3. **Sokollu Mehmet (Altyapı, Ağ & Monetizasyon):**
   - Supabase Realtime, WebSocket, AdMob ve RevenueCat altyapılarını, devre kesici (circuit breaker) ve offline dayanıklılık kurallarıyla yönetir.
4. **Piri Reis (Sıfır Kayıp Kalıcılık & 1M+ Veri Atlası):**
   - SQLite, Drift, Supabase ve SharedPreferences üzerinde minimum bayt ile veri saklar.
5. **Ebussuud (Otomasyonel Kalite, Hukuk & Hızlı Poka-Yoke):**
   - Hedefli `dart analyze` (0 hata/uyarı), 5S kod temizliği ve mağaza uyumluluk denetimini icra eder.
6. **Barbaros Hayreddin (Lojistik, Sürümleme & Dağıtım):**
   - Sürüm kodlarını (`pubspec.yaml` SemVer +1) kilitli artırır.
   - Zikirce_ Standardında Türkçe ve İngilizce çift dilli sürüm notlarını hem `changelog_service.dart`'a hem Fastlane metadata'sına yazar.
7. **Hezarfen Ahmed Çelebi (Deep Research & Rakip İstihbaratı):**
   - "Sıfır Dalkavukluk & Kesin Objektiflik" ilkesiyle `search_web` üzerinden gerçek rakipleri ve mağaza 1-yıldız şikayetlerini analiz eder; `NotebookLM_Sources/` kaynak paketleri üretir.

---

## 🌉 BÖLÜM 5: ÇİFT MOTORLU SENKRONİZASYON VE YETENEK KANIT KARNESİ

1. Görev atandığında `worker.py`, görevin JIT Yetenek Matrisi sınıfını (`ui_design`, `complex_software`, `research`, `fast_track`) belirler ve Antigravity 2.0'a gönderilen emre **zorunlu Ultra yetenek direktiflerini** enjekte eder.
2. Kodlama ve hedefli doğrulama bittiğinde sonuç raporu `akarworks_bridge.py complete-task` ile tek adımda kaydedilir:
   - `executive_summary`: 3-4 somut Türkçe madde + kullanılan Ultra yeteneğin kalite katkısı,
   - `ultra_talent_proof`: **8. İsraf Denetimi & Kullanılan Ultra Yetenekler** (Hangi Sensei Ultra aracının veya paralel alt-ajanın kullanıldığı ve işe nasıl somut kalite kattığının kanıtı),
   - `steps` & `changed_files`: Gerçek değişen dosyalar ve tamamlanan adımlar,
   - `changelog_tr` & `changelog_en`: Çift dilli kullanıcı sürüm notları,
   - `report`: Detaylı Markdown teknik raporu (Google Drive `Reports/` klasörüne otomatik arşivlenir).

---
**Kanun Yürürlüğü:** Bu yönetmelik, tüm Akarworks yazılım fabrikalarında ve bağlı depolarında anayasa niteliğinde olup aksi yönde kod yazılamaz ve işlem yürütülemez.
