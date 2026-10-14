# 🦅 TAHRİR — Küresel E-Kitap & PDF Okuyucu Piyasa İstihbaratı ve Mavi Okyanus Mimari Raporu

> **Hazırlayan Hücreler:** `Hezarfen-Radar` × `Hezarfen-Tech` × `Hezarfen-Sentez` & `Kanuni-Pazar`  
> **Denetim İlkesi:** *Sıfır Dalkavukluk & Kesin Objektiflik (Genchi Genbutsu)*  
> **Sürüm Hedefi:** Tahrir v1.0.0 (Mağaza Amiral Gemisi Sürümü)

---

## 1. Küresel Piyasa Analizi ve Rakip Zaafiyet Raporu (1-Yıldız Şikayet Kök Nedenleri)

Google Play Store, Apple App Store, Reddit (`r/ereader`, `r/pdf`, `r/ObsidianMD`), Trustpilot ve Şikayetvar üzerindeki gerçek kullanıcı verileri incelendiğinde mevcut pazarın **iki uç arasında sıkıştığı** tespit edilmiştir: bir tarafta soğuk ve pahalı kurumsal PDF araçları, diğer tarafta PDF mizanpajını parçalayan demode e-kitap okuyucular.

| Uygulama | İndirme / Puan | Fiyatlandırma | Güçlü Yönü | En Büyük 1-Yıldız Şikayetleri (Kök Neden) |
| :--- | :--- | :--- | :--- | :--- |
| **ReadEra** | 50M+ (4.8★) | Ücretsiz / $14.99 Pro | Hızlı yerel indeksleme, reklamsız temel okuma | Çift sütunlu akademik PDF'lerde reflow çökmesi, dipnotların cümlenin ortasına karışması, taranmış PDF'lerde OCR/akış olmaması, 2018'den kalma dosya yöneticisi arayüzü. |
| **Moon+ Reader Pro** | 10M+ / 1M+ Pro (4.3★) | ~$9.99 | Derin EPUB özelleştirmesi, otomatik kaydırma | "Uçak kokpiti" gibi karmaşık ayar menüleri, zayıf PDF motoru, PDF reflow modunda görsellerin ve tabloların tamamen kaybolması. |
| **LiquidText / MarginNote** | 1M+ (4.5★) | $79.99 - $174.99 / yıl | iPad üzerinde sonsuz tuval ve zihin haritası | **Cep telefonunda (6.1"-6.7") tamamen kullanılamaz mizanpaj**, fahiş yıllık SaaS aboneliği, Android/Windows ekosisteminde zayıflık. |
| **Speechify / NaturalReader** | 10M+ (4.3★) | $119 - $139 / yıl | Doğal sesli okuma (Bulut TTS) | Deneme süresi sonrası habersiz yıllık $139 çekim şikayetleri, internet kesilince robotik sese düşme, **PDF okurken her sayfada üstbilgi/altbilgi ve dipnot numaralarını cümlenin ortasında okuma aptallığı**. |
| **Adobe Acrobat / Xodo** | 500M+ / 10M+ (4.5★) | $120 - $239 / yıl | Kurumsal PDF form ve imza | Aşırı şişkin (bloatware), en temel özelliklerde agresif abonelik duvarı, edebi okuma ruhunun sıfır olması, gece modunda görselleri negatif röntgene çevirme. |
| **Kindle / Apple Books** | 100M+ (4.7★) | Kapalı Ekosistem | Kendi mağaza kitaplarında senkronizasyon | Dışarıdan yüklenen (sideloaded) PDF'lerde kötü reflow, alınan notları ve şerhleri **Obsidian / Notion (`.md`)** formatında dışa aktarma engeli (ekosistem hapsi), klasik/Osmanlıca kelimelerde yetersiz sözlük. |

---

## 2. Piyasadaki 7 Kritik Boşluk ve Tahrir'in Mavi Okyanus Konumlandırması

### Boşluk 1: Kompakt Telefon Ekranlarında Akademik & Edebi PDF Reflow + Dipnot Bütünlüğü
* **Sorun:** Standart PDF okuyucular ya kullanıcıyı 6 inç ekranda sürekli sağa-sola kaydırmaya (pan & zoom) mahkum eder ya da metni akıtırken tüm paragrafları birbirine yapıştırıp dipnotları metnin ortasına gömer.
* **Tahrir Çözümü:**
  * `LayoutColumnDetector` ile çift sütunlu akademik makaleleri önce sol, sonra sağ sütun sırasıyla okuma.
  * Y-koordinatı boşluğu (`bounds.top - prev.bounds.bottom`), satır başı girintisi (`bounds.left`) ve punto yüksekliği (`bounds.height`) analiziyle gerçek paragraf ve başlık mimarisini koruma.
  * Sayfa altı dipnotlarını (`[1]`, `¹`, `*`) metin akışını hiç kesmeyen tıklanabilir **İnteraktif Dipnot Baloncuklarına (`InlineFootnoteModal`)** dönüştürme.
  * Orijinal PDF görünümünde **Akıllı Parşömen / Gece / AMOLED Renk Matrisi** ve tek tıkla **Auto-Crop (Kenar Boşluğu Kırpma)** zoom desteği.

### Boşluk 2: Klasik & Akademik Türkçe Okurları İçin Çevrimdışı Etimolojik Lügat
* **Sorun:** Tarih, edebiyat, felsefe, tasavvuf veya klasik metinler (İnalcık, Tanpınar, Cemil Meriç, Kutadgu Bilig, İbn Haldun vb.) okuyan bir okur; *istinsah, mütecessis, derkenar, mukaddime, tahayyül, belagat, vakanüvis* gibi kelimelerde uygulamadan çıkıp tarayıcıda arama yapmak zorunda kalır ve odak (Flow State) kırılır.
* **Tahrir Çözümü:**
  * 130+ temel klasik, edebi, felsefi ve tarihsel kavramı kökeni, sözcük türü, detaylı tanımı ve edebi örnek cümlesiyle barındıran **Dahili Etimolojik Lügat (`DictionaryService`)**.
  * **Türkçe Morfolojik Kök Çözümleyici (Suffix Stemmer):** Kitapta geçen çekimli kelimelerin (*"hikmetin"*, *"müellifler"*, *"şerhleri"*, *"kitabın"*) eklerini ve ünsüz yumuşamalarını soyarak doğrudan kök maddeyi bulma + sayfa içi canlı lügat arama çubuğu.

### Boşluk 3: Sıfır İnternet Bağımlılıklı Akustik Ambiyans Sentezleyici + TTS Audio Ducking
* **Sorun:** Okuyucular odaklanmak için arka planda yağmur, kütüphane, şömine veya ney sesi açmak istediğinde ya internet bağlantısına ihtiyaç duyar ya da TTS (sesli okuma) açıldığında ambiyans sesi konuşmayı bastırır.
* **Tahrir Çözümü:**
  * **Prosedürel PCM/WAV Akustik Sentezleyici (`AmbientAudioService`):** Uygulama boyutunu tek bir megabayt bile şişirmeden ve internet bağlantısına ihtiyaç duymadan cihaz belleğinde gerçek zamanlı üretilen 5 döngüsel ses katmanı (*Hafif Yağmur, Şömine Çıtırtısı, Kütüphane Ambiyansı, Kafe Lo-Fi, Klasik Ney & Huzur*).
  * **Otomatik Audio Ducking:** Canlı TTS sesli okuma başladığında ambiyans sesini otomatik olarak %25 seviyesine kısma, durduğunda eski seviyesine yükseltme ve okunan kelimeyi metin üzerinde **canlı karaoke vurgusuyla** takip etme.

### Boşluk 4: Haşiye / Derkenar (Marginalia) Kültürü + Obsidian Markdown & QR P2P Takas
* **Sorun:** Mevcut okuyucularda alınan notlar uygulama içinde hapis kalır; aynı kitabı okuyan iki arkadaşın veya öğrencinin notlarını sunucusuz paylaşması imkansızdır.
* **Tahrir Çözümü:**
  * Metin seçildiğinde açılan zengin **Şerh & Haşiye Ekleme Modalı** (4 kategori: *Düşünce 💡, Alıntı ✨, Soru ❓, Eleştiri ⚡* + 5 özel mürekkep rengi + kişisel şerh notu).
  * Okuma ekranında paragraf altında doğrudan görünen **Derkenar Kartları**.
  * Tek tıkla **Obsidian / Notion uyumlu Markdown (`.md`)** dışa aktarma ve internet olmadan **QR Kod (P2P)** ile şerh takası.

### Boşluk 5: Gerçek PNG Çıktılı Viral Alıntı Stüdyosu & Mühürlü Okuma Beratı
* **Sorun:** Okurlar beğendikleri cümleleri sosyal medyada paylaşmak için ekran görüntüsü alıp kırpmakla uğraşır.
* **Tahrir Çözümü:**
  * **Tahrir Alıntı Stüdyosu (`QuoteStudioSheet`):** Seçilen cümleyi *Parşömen, Story (9:16), Kare (1:1)* ve *İs Mürekkebi (AMOLED)* şablonlarında `3.0x` yüksek çözünürlüklü **gerçek PNG görseli** olarak üretip paylaşma.
  * **Tahrir Okuma Beratı (`CompletionSealDialog`):** Kitap tamamlandığında okurun başarısını belgeleyen mühürlü sertifikayı yüksek çözünürlüklü PNG olarak dışa aktarma.

### Boşluk 6: Cihaz İçi TextRank AI Katip & Sokratik Çalışma Soruları
* **Sorun:** Bulut tabanlı AI özetleyiciler hem gizliliği ihlal eder hem de aylık ücret/internet gerektirir.
* **Tahrir Çözümü:**
  * %100 cihaz içinde çalışan **TextRank Cümle Merkeziliği (Lexical Centrality)** algoritması ile sayfanın en kritik 3 önermesini, anahtar kavramlarını, metin ağırlık derecesini ve okurun anlayışını pekiştiren **Sokratik Tefekkür & Çalışma Sorularını** anında üretme.
