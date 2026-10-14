# 📜 TAHRİR - Versiyon Geçmişi & Değişiklik Günlüğü (Changelog)

Bu doküman, **Tahrir** uygulamasının sürüm geçmişini, her versiyonda eklenen yeni özellikleri, mimari geliştirmeleri ve optimizasyonları takip etmek için tutulmaktadır. Sürüm numaralandırmasında [Semantik Versiyonlama (SemVer)](https://semver.org/lang/tr/) standardı (`MAJOR.MINOR.PATCH`) esas alınır.

---

## 🏆 [1.0.0+3] - 14 Ekim 2026 (Mağaza Amiral Gemisi Sürümü / Store Flagship Release)
*Hezarfen Piyasa Boşluk Analizi & 7 Sensei Tam Spektrum Mavi Okyanus Yükseltmesi*

### 🌊 1. Piyasa Boşluklarını Kapatan Mavi Okyanus Özellikleri
* **Y-Koordinat & Girinti Duyarlı PDF Smart Reflow:** PDF sayfalarındaki dikey satır boşluklarını (`bounds.top - prev.bounds.bottom`), paragraf başı girintilerini (`bounds.left`) ve başlık puntolarını analiz ederek gerçek paragraf mimarisini koruyan yeniden akış motoru + LRU bellek önbelleği ile 0ms sayfa geçişi.
* **Orijinal PDF Akıllı Gece/Parşömen Filtresi & Auto-Crop:** Orijinal PDF görünümünde göz kamaştıran beyaz arka planı aktif temaya (*Tahrir Parşömeni, İs Mürekkebi AMOLED, Gece Safiri, Zeytin & Orman*) uyarlayan akıllı renk matrisi ve tek tıkla kenar boşluğu kırpma (`Auto-Crop 1.18x`) modu.
* **Tam Kapsamlı EPUB, Markdown (`.md`) ve `.txt` DOM Motoru:** Alt bölümleri (`SubChapters`) rekürsif tarayan, paragraf/başlık hiyerarşisini koruyan ve gerçek kitap/yazar/bölüm üstverisini çıkaran birleşik çok formatlı motor + İçindekiler (TOC) Gezgini.
* **%100 Çevrimdışı Prosedürel WAV Akustik Sentezleyici & Audio Ducking:** İnternet bağlantısına veya harici sunucuya ihtiyaç duymadan bellekte gerçek zamanlı PCM/WAV ses üreten 5 ambiyans modu (*Hafif Yağmur, Şömine Çıtırtısı, Kütüphane Ambiyansı, Kafe Lo-Fi, Klasik Ney & Huzur*) + TTS sesli okuma konuşurken ambiyansı otomatik %25'e kısan **Audio Ducking**.
* **Canlı TTS Karaoke Kelime Vurgulama:** Sesli dinleme sırasında okunan kelimenin metin üzerinde canlı olarak aydınlatılması.
* **130+ Kelimelik Klasik, Osmanlıca & Etimolojik Türkçe Lügat + Morfolojik Kök Çözümleyici:** Çekimli kelimelerin (*-ları, -dan, -nın, -dır* ve ünsüz yumuşaması) eklerini soyarak kök maddeyi bulan, canlı arama çubuğu ve ilişkili kavram önerileri sunan çevrimdışı lügat.
* **İnteraktif Haşiye / Derkenar (Marginalia) & Gerçek 3.0x PNG Export:**
  * Metin seçildiğinde 4 kategori (*Düşünce, Alıntı, Soru, Eleştiri*), 5 mürekkep rengi ve kişisel şerh notu ekleme modalı + paragraf altı derkenar kartları.
  * **Alıntı Stüdyosu (`QuoteStudioSheet`)** içinde 4 şablon (*Parşömen, Story 9:16, Kare 1:1, İs Mürekkebi AMOLED*) ve `RepaintBoundary` (`3.0x` piksel oranı) ile **gerçek yüksek çözünürlüklü PNG görsel paylaşımı**.
  * **Tahrir Okuma Beratı (`CompletionSealDialog`)** sertifikasını gerçek PNG görseli olarak dışa aktarma ve kitap bitişinde otomatik kutlama.
* **TextRank Cihaz İçi AI Katip & Sokratik Çalışma Soruları:** Cümle merkeziliği (Lexical Centrality / TF-IDF) algoritmasıyla en önemli 3 cümleyi seçen ve sayfa içeriğinden otomatik **Sokratik Tefekkür & Çalışma Soruları** üreten yerel analiz motoru.
* **Poka-Yoke & Yalın Mühendislik (Riverpod `select` & Deterministik `dispose`):** Sıfır sahte veri (gerçek günlük okuma dakikası, gerçek ısı haritası, kümülatif olmayan delta oturum kaydı), QR tarayıcı tekil okuma kilidi (debounce) ve Zikirce_ standardında çift dilli (`TR`/`EN`) uygulama içi sürüm notları (`ChangelogService`).

---

## 🚀 [0.9.0] - 27 Ağustos 2026
*İlk Fonksiyonel Ön Sürüm (Beta / Temel Mimari, Çok Formatlı Okuma, Bilişsel Modlar & Şerh Ekosistemi)*

### 🏛️ 1. Mimari & Çekirdek Altyapı
* **Flutter 3.x & Impeller:** 120Hz yüksek yenileme hızına sahip kompakt ekranlarda yağ gibi akıcı sayfa kaydırma ve sıfır gecikme (Zero-Lag).
* **Temiz Mimari & SOLID:** Katmanlı mimari (`core/`, `domain/`, `data/`, `features/`) ile modüler ve tip güvenli kod yapısı.
* **Durum Yönetimi:** `flutter_riverpod` tabanlı reaktif durum yönetimi ve bağımlılık enjeksiyonu.
* **Yerel Öncelikli Veritabanı (Local-First):** SQLite (`sqflite`) ve `SharedPreferences` ile tüm kitapların, şerhlerin, okuma oturumlarının ve alışkanlık verilerinin tamamen cihaz içinde saklanması.
* **Güvenli Hata Yönetimi:** Fonksiyonel `Result<T>` ve `AppError` kalıbı.

---

### 🎨 2. Görsel Temalar & Tipografi Motoru
* **5 Özel Okuma Teması:**
  * 📜 *Tahrir Parşömeni* (#F5EEDB zemin, sıcak kemik / el yazması tonu).
  * 🖤 *İs Mürekkebi AMOLED* (#000000 zemin, saf siyah ve yüksek kontrast).
  * 🌌 *Gece Safiri* (#0F172A zemin, derin lacivert modern koyu tema).
  * 📄 *Hakiki Kağıt Beyazı* (#FAF9F6 zemin, birinci hamur kitap kağıdı doğallığı).
  * 🌿 *Zeytin & Orman* (#13201C zemin, gözü dinlendiren adaçayı tonu).
* **Cihaz Sistem Teması Uyumu:** Açık, koyu veya cihaz sistem temasına otomatik adapte olma (`ThemeMode.system`).
* **Çevrimdışı Edebi Fontlar:** *Literata*, *Lora*, *Merriweather*, *Inter*, *JetBrains Mono*.
* **Tipografik Ayarlar:** Canlı ayarlanabilir punto boyutu (13-28 pt), satır aralığı (1.2x - 2.2x) ve kenar boşlukları (8-48 px).

---

### 📖 3. Çok Formatlı Okuma & Akıllı Reflow Motoru
* **Çok Format Desteği:** PDF, EPUB, TXT ve Markdown formatlarını tek birleşik tipografik akış altında okuma.
* **PDF Smart Reflow:** Koordinat tabanlı bloklama, tire temizleme (de-hyphenation) ve sayfa üst/alt bilgi filtreleme.
* **Hibrit Çift Görünüm (Dual-View):** Tek dokunuşla Orijinal Vektörel PDF görünümü ile Akıllı Metin Akışı arasında geçiş yapabilme.
* **Otomatik Kenar Kırpma (Auto-Crop):** Orijinal PDF görünümünde sayfa kenarındaki beyaz boşlukları kırparak mobilde maksimum genişlik sunma.
* **Tek Dokunuşla Dosya İçe Aktarma:** Cihaz belleğindeki dosyaları `file_picker` ile anında kütüphaneye ekleme.

---

### 🧠 4. Bilişsel Okuma Modları (Cognitive Suite)
* **Bionic / Hızlı Odak Modu:** Kelimelerin ilk harflerini belirginleştirerek gözün satırda takılmadan kaymasını sağlayan hızlı okuma teknolojisi.
* **Canlı Vurgulu Sesli Dinleme (TTS):** Cihazın yerel yüksek kaliteli ses motoru ile metni dinleme ve aynı anda okunan kelimeyi canlı takip etme.
* **Ambiyans & Odak Sesleri Mikseri:** Dahili ses jeneratörü ile hafif yağmur, şömine çıtırtısı, kütüphane sessizliği ve kafe lo-fi sesleri.
* **Okuma Cetveli (Line Focus Overlay):** Dikkat dağınıklığını önlemek için okunan satır haricindeki alanları yarı saydam karartan sürüklenebilir odak cetveli.
* **İnteraktif Dipnot Baloncukları (Inline Footnote Modal):** Metin içindeki `[1]`, `*` gibi dipnot işaretlerine dokunulduğunda akışı kesmeden açılan pop-up sheet.
* **Görsel Lightbox (Pinch-to-Zoom):** Metin içindeki görsellere dokunulduğunda tam ekran yüksek çözünürlüklü modal inceleme.
* **Çevrimdışı Akıllı Katip:** İnternetsiz çalışan yerel analiz algoritmasıyla sayfanın anahtar kavramlarını ve 3 maddelik hızlı özetini tek dokunuşla çıkarma.

---

### ✍️ 5. Şerh, Lügat & Sosyal Paylaşım
* **Dahili Türkçe Lügat & Etimoloji:** Metindeki herhangi bir kelimeye basılı tutulduğunda açılan çevrimdışı köken, tanım ve edebi örnek kartı.
* **Çok Katmanlı Şerh & Vurgulama:** Düşünce, alıntı, soru ve eleştiri kategorilerinde renkli not alma.
* **Alıntı Paylaşım Stüdyosu:** Seçilen alıntıları tek tıkla Instagram Story (9:16), Minimal Kare (1:1) veya Lüks Parşömen kartı olarak üretme ve `share_plus` ile paylaşma.
* **Markdown Dışa Aktarma:** Alınan tüm notları ve şerhleri tek tıkla Obsidian/Notion uyumlu `.md` dosyası olarak kaydetme.
* **Çevrimdışı Eşler Arası (P2P / QR Kod) Takas:** İnternet olmadan dinamik QR kod üreterek iki cihaz arasında kitap notlarını ve şerhleri takas etme.

---

### 📚 6. Sanal Kitaplık, Oyunlaştırma & Alışkanlık Takibi
* **Estetik 3D / Minimal Ahşap Raf:** Kitapları sıradan liste yerine kabartmalı kapaklar ve kitap sırtları (spines) ile sergileme.
* **Otomatik Edebi Kapak Jeneratörü:** Kapağı olmayan PDF'ler için başlık özetine göre otomatik tipografik klasik kapak üretme.
* **Günlük Streak Zinciri & Hedef Sayacı:** Günlük minimum okuma süresi takibi ve zincirleme seri göstergesi.
* **Okuma Aktivite Isı Haritası:** Son 7 haftalık (49 gün) okuma alışkanlığını GitHub tarzı yeşil matrisle görselleştirme.
* **Okuma Hızı (WPM) & İstatistikler:** Dakikada okunan kelime sayısı, toplam okunan sayfa ve aktif okuma süresi analitiği.
* **Kitap Tamamlama Ritüeli & Tahrir Mührü:** Kitap bitirildiğinde özel kutlama animasyonu ve mühürlü "Tahrir Okuma Beratı" sertifikası.

---

## 🔮 Gelecek Sürüm Yol Haritası

### [1.0.0] - *Hedeflenen Kararlı Ana Sürüm*
* [ ] iOS & Android ana ekran widget'larının (Home Widget) yerel köprülerle bağlanması.
* [ ] Çevrimdışı Wi-Fi / Bluetooth yerel kütüphane yedekleme ve geri yükleme.
* [ ] Tablet ve katlanabilir (Foldable) cihazlar için iki sütunlu açık kitap düzeni.
* [ ] Okuma istatistiklerini PDF / Görsel rapor olarak dışa aktarma.
