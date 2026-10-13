# Akarworks Otonom Fabrika Yönetmeliği & Anayasası (GEMINI.md)
> **Sürüm:** 2.0 (Yalın Üretim & Git Güvenceli Otonom Geliştirme Standardı)  
> **Kapsam:** Mobil Direktör Terminali, Arka Plan İşçi Motoru (`worker.py`), Antigravity IDE ve Çoklu Ajan (MAS) Ekosistemi.

---

## 🏛️ BÖLÜM 1: YALIN ÜRETİM (LEAN) FELSEFESİ VE TEMEL İLKELER

Akarworks Otonom Yazılım Fabrikası, Toyota Üretim Sistemi (TPS) ve Yalın Yazılım Geliştirme felsefesini otonom kodlama süreçlerine tavizsiz uygular:

1. **Muda (無駄 - İsraf) Yok Etme:**
   - **Ölü Kod İsrafı:** Kullanılmayan fonksiyonlar, ölü importlar, gereksiz soyutlamalar kod tabanından derhal ayıklanır (Seiri - Ayıklama).
   - **Token & Bağlam İsrafı:** Ajanlar gereksiz dosya okumaları veya sonsuz konuşmalar yapamaz. Yalnızca hedef dosyalar üzerinde atomik çalışılır.
   - **UI & Bellek İsrafı:** Gereksiz widget çizimleri (overdraw) ve rebuild'ler engellenir.
2. **Jidoka (自働化 - Hata Anında Otonom Duruş):**
   - Fabrika hattında bir hata (derleme, analiz, test veya entegrasyon kırılması) tespit edildiğinde sistem hatayı örtbas etmez veya üzerine kod yazmaya devam etmez.
   - Hatayı tespit eden ajan derhal **Andon Kordonu**'nu çeker; işlem durdurulur ve düzeltme denenir. İki denemede çözülemezse emniyetli geri alma (Rollback) tetiklenir.
3. **Poka-Yoke (ポカヨケ - Hata Önleyici Tasarım):**
   - Hatanın oluşması tasarım ve altyapı seviyesinde imkansız kılınır. Tip güvenliği, statik kod analizi ve otomatik Git zırhı ile insan ve ajan hataları kaynağında engellenir.
4. **Tek Parça Akışı (One-Piece Flow / WIP = 1):**
   - Her proje deposunda aynı anda yalnızca **1 aktif kodlama görevi** yürütülebilir.
   - Bir görev tamamlanıp mobil direktör tarafından onaylanıp ana dala (`main`) birleştirilmeden veya iptal edilip geri alınmadan o projede yeni görev başlatılamaz. Git çatışmaları (merge conflict) bu ilkeyle sıfırlanır.
5. **Genchi Genbutsu (現地現物 - Yerinde İnceleme):**
   - Tahminlerle kod yazılamaz. Gerçek hata logları, gerçek linter çıktıları ve gerçek test sonuçları incelenerek kararlar verilir.

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

### 5. Kademe: İnsan Onay Kapısı (Human-in-the-Loop Merge Gate)
- Ajanlar görev kodlamasını bitirse dahi ana dala (`main`) otomatik `merge` yapamaz.
- Görev `waiting_approval` (Onay Bekliyor) durumuna geçer; mobil direktör cep telefonundan `executive_summary`, teknik rapor ve ekran görüntüsünü inceleyip "Onayla ve Koda Dahil Et" butonuna basana kadar izole dalda bekletilir.

---

## ⚡ BÖLÜM 3: KOD YAZMA VE KALİTE STANDARTLARI (TAM SPEKTRUM POKA-YOKE)

Ajanlar kod üretirken aşağıdaki katı mühendislik standartlarına uymak zorundadır:

### 1. Statik Analiz & Sıfır Tolerans
- Flutter projelerinde `flutter analyze` çıktısında **0 Hata (Errors)** ve **0 Uyarı (Warnings/Lints)** esastır. Hiçbir görev geride analiz uyarısı bırakamaz.
- Python/Node.js projelerinde flake8/eslint kuralları sıfır toleransla işletilir.

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

### 5. Test ve Doğrulama
- Her görev, tamamlanmadan önce proje için tanımlanmış `test_cmd` (`flutter test`, `pytest`, vb.) komutunu çalıştırmalı ve testlerin %100 yeşil olduğunu doğrulamalıdır.

---

## 👥 BÖLÜM 4: EKİP VE OPERASYON YÖNETMELİĞİ (7 SENSEI JIT HİYERARŞİSİ)

Görevlerin icrasında 7 Baş Sensei ve onların dinamik (JIT) mikro hücreleri görev yapar:

1. **Kanuni (Yüce Orkestratör & Değer Akışı):**
   - Görev sınırlarını çizer, 1 satırlık talepleri teknik şartnameye (PRD) dönüştürür.
   - Heijunka kuyruğunu ve WIP=1 kuralını yönetir.
   - `Kanuni-Defterdar`: Token israfını ve kota aşımlarını engeller; kilitlenmelerde `CancellationToken` (SIGINT) çeker.
2. **Mimar Sinan (Sürtünmesiz UI/UX & Görsel Tasarım):**
   - Sıfır overdraw, akıcı 60/120 FPS arayüz ve oyun grafikleri üretir.
   - `Sinan-Matrakçı`: Headless altın ekran görüntüleri (Golden Screenshot) yakalar. Gerçek render harici sahte/mock görsel kullanımını (Muda) yasaklar.
3. **Sokollu Mehmet (Altyapı, Ağ & Monetizasyon):**
   - Supabase Realtime, WebSocket, AdMob ve RevenueCat altyapılarını yönetir.
   - Circuit breaker ve offline dayanıklılık kurallarını koyar.
4. **Piri Reis (Sıfır Kayıp Kalıcılık & Telemetri):**
   - SQLite, Supabase ve SharedPreferences üzerinde minimum bayt ile veri saklar.
   - Görev metriklerini ve analiz loglarını toplar.
5. **Ebussuud (Otomasyonel Kalite, Hukuk & Poka-Yoke):**
   - Sistemin başyargıcıdır. Statik analiz, 5S kod temizliği ve Google Play / App Store mağaza uyumluluk denetimini icra eder.
6. **Barbaros Hayreddin (Lojistik, Sürümleme & Dağıtım):**
   - Sürüm kodlarını (`pubspec.yaml` SemVer +1) kilitli artırır.
   - Zikirce_ Standardında Türkçe ve İngilizce çift dilli sürüm notlarını hem `changelog_service.dart`'a hem Fastlane metadata'sına yazar.
   - İmzalı APK/AAB derlemelerini Google Drive ve dahili test hatlarına iletir.
7. **Hezarfen Ahmed Çelebi (Piyasa Radarı & Rakip İstihbaratı):**
   - "Sıfır Dalkavukluk & Kesin Objektiflik" ilkesiyle çalışır. Kendi uygulamalarımıza kör övgüyü yasaklar; gerçek rakipleri ve mağaza 1-yıldız şikayetlerini analiz ederek objektif rapor sunar.

---

## 🌉 BÖLÜM 5: ÇİFT MOTORLU SENKRONİZASYON (AKARWORKS DUAL-ENGINE BRIDGE)

1. Görev `worker/sync_drive/pending_coding_task.json` dosyasına yazıldığında Antigravity IDE derhal ilgili izole dala geçer.
2. Kodlama bittiğinde ve testler %100 geçtiğinde sonuç raporu aynı JSON dosyasına kaydedilir:
   - `report`: Detaylı teknik adımlar ve değiştirilen dosyalar,
   - `executive_summary`: Mobil yönetici için 3 maddelik sade özet,
   - `changelog_tr` & `changelog_en`: Çift dilli kullanıcı sürüm notları.
3. Arka plan işçisi (`worker.py`) bu çıktıyı okuduğu anda görevi `waiting_approval` durumuna geçirir ve cep telefonuna push bildirim fırlatır.

---
**Kanun Yürürlüğü:** Bu yönetmelik, tüm Akarworks yazılım fabrikalarında ve bağlı depolarında anayasa niteliğinde olup aksi yönde kod yazılamaz ve işlem yürütülemez.
