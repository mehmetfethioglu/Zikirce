import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class ChangelogRelease {
  final String version;
  final String date;
  final String titleTr;
  final String titleEn;
  final List<String> highlightsTr;
  final List<String> highlightsEn;

  const ChangelogRelease({
    required this.version,
    required this.date,
    required this.titleTr,
    required this.titleEn,
    required this.highlightsTr,
    required this.highlightsEn,
  });
}

/// Zikirce_ Standardında çift dilli (TR / EN) sürüm geçmişi servisi.
class ChangelogService {
  const ChangelogService();

  static const String currentVersion = '1.15.0+21';

  static const List<ChangelogRelease> releases = [
    ChangelogRelease(
      version: 'v1.15.0',
      date: '2026-11-25',
      titleTr:
          'Çift Modlu Eski PDF Restorasyonu, Hibrit OCR (Tesseract 5 + Apple Vision) & Tahrir Pro',
      titleEn:
          'Dual-Mode Old PDF Restoration, Hybrid OCR (Tesseract 5 + Apple Vision) & Tahrir Pro',
      highlightsTr: [
        'C++/FFI Sayfa Restorasyonu & K2pdfopt Baskı Akışı: Sararmış kağıt ve eğik taramalar için Aydınlatma Düzleştirme, ±5° Deskew, Sauvola Binarizasyon, tema renkli şeffaf Baskı Akışı (Akış / Baskı / PDF), 150 MB Disk LRU önbelleği ve 300 DPI uzun-basma Büyüteç (Peek) eklendi.',
        'Cihaz İçi Hibrit OCR Doğrulaması: iOS Apple Vision (.accurate, TR/AR/EN) ve Android C++ FFI Tesseract 5 LSTM (PSM_SINGLE_LINE, SHA-256 doğrulamalı ~19 MB arka plan indirici) ile şüpheli ve Arapça satırlar otomatik iyileştirildi.',
        'Tahrir Pro & Banner\'sız Esnek Erişim: Kurulumda ilk 24 saat ücretsiz Pro deneme, kapatılabilir karşılama ekranı, temel modda ücretsiz Orijinal PDF okuma + Günlük Seri, 3 ödüllü reklam ile 24 saat Pro ve haftalık/aylık/yıllık/ömür boyu abonelik seçenekleri sunuldu.',
      ],
      highlightsEn: [
        'C++/FFI Page Restoration & Optical Reflow: Added Illumination Flattening, ±5° Deskew, Sauvola Binarization, theme-tinted transparent Optical Reflow (Flow / Print / PDF), 150 MB Disk LRU cache, and long-press 300 DPI original peek.',
        'On-Device Hybrid OCR Verification: Added iOS Apple Vision (.accurate, TR/AR/EN) and Android C++ FFI Tesseract 5 LSTM (PSM_SINGLE_LINE, SHA-256 verified ~19 MB background download) for low-confidence and Arabic lines.',
        'Tahrir Pro & Ad-Banner-Free Access: 24h free Pro trial on install, App Store compliant dismissible prompt, free Original PDF reading & Daily Streak in Basic mode, 3 rewarded ads for 24h Pro Pass, and weekly/monthly/yearly/lifetime plans.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.14.0',
      date: '2026-11-15',
      titleTr:
          'Kıraat & Akıcı Fasıl Okuma Koçu, Semantik Öbek Temposu & Göz Atölyesi',
      titleEn:
          'Guided Flow Reading Coach, In-Page Semantic Pacing & Eye Workshop',
      highlightsTr: [
        'Aktif Kitap Odaklı Isınma ➔ Akıcı Fasıl Köprüsü: İzole 21 kademeli parkur yerine açık kitabınızdan çıkarılan kavramlarla 60 saniyelik ön-ısınma ve doğrudan kitap sayfasında semantik öbek (2–4 kelime) vurgusuyla akıcı okuma eklendi.',
        'Soluklaşan Destek, Orijinal PDF Satır Cetveli & Haşiye Köprüsü: Gözün yardımsız akışı öğrenmesi için kademeli soluklaşan rehberlik, Orijinal PDF modunda ritmik satır cetveli, fasıl sonu aktif hatırlama ve tek satır notu Haşiye\'ye kaydetme sunuldu.',
        'Cezasız Süreklilik, Yoğunluk Uyumu & Göz Atölyesi: Seri düşüş cezaları kaldırılarak birleşik okuma serisi, metin yoğunluğuna (Akıcı / Edebi / İlmi) duyarlı hedef WPM, dayanıklılık mühürleri (5–30 dk) ve isteğe bağlı Göz Atölyesi (Piramit, Takistoskop, Schulte) kuruldu.',
      ],
      highlightsEn: [
        'Book-Centered Warmup ➔ Guided Flow Bridge: Replaced the isolated 21-stage course with a 60-second lexical warmup extracted from your active book and in-page 2–4 word semantic chunk pacing.',
        'Scaffolding Fade, Original PDF Pacer & Marginalia Bridge: Added gradual highlight fading for unassisted eye flow, rhythmic line-focus pacing on Original PDF pages, active recall reflection, and one-tap note saving to Highlights.',
        'Zero-Penalty Continuity, Density Adaptation & Eye Workshop: Unified reading streaks without regression penalties, added density-aware WPM targets (Fluent / Literary / Academic), stamina seals (5–30 min), and an optional Eye Workshop (Pyramid, Tachistoscope, Schulte).',
      ],
    ),
    ChangelogRelease(
      version: 'v1.13.0',
      date: '2026-11-13',
      titleTr:
          'Kusursuz Okuma Gözden Geçir Motoru, Ünsüz Benzeşmesi & Tüm Kitap Tashih Taraması',
      titleEn:
          'Flawless Reading Proofreader, Consonant Assimilation & Full-Book OCR Repair',
      highlightsTr: [
        'Türkçe Biçimbilim & Ünsüz Benzeşmesi Onarımı: Zemberek çözümleyicisine -laş/-leş, -(y)ıver, -(y)agel, -maksızın ve ek-fiil çekimleri (idi/imiş/ise) eklendi; fıstıkçı şahap ihlalleri ("kitapda→kitapta", "gitdi→gitti") ile kesme işaretli özel isim/sayı ekleri ("Osmanlı\'nm→Osmanlı\'nın", "1923\'de→1923\'te") otomatik düzeltilir.',
        'Bağlamsal Gerçek-Kelime Kayıt Tablosu & Dipnot/Tire Tashihi: OCP uyumlu bağlamsal kurallar ("olanak→olarak", "üzen→üzere", "dolay→dolayı", "gön→göre", "karar→kadar"), görünmez yumuşak tire (\\u00AD), bloklar arası kırık tire ve dipnot içi metin onarımı eklendi.',
        'Tüm Kitabı Tara & Kesintisiz Alt Çizgi Vurgusu: EPUB/MD/TXT bölümlerinde kalıcı SQLite önbelleği, "Tüm Kitabı Tara" ile kitap geneli otomatik onarım, yoksayılan kelime yönetimi ve satır sonlarını bozmayan Gözden Geçir arayüzü sunuldu.',
      ],
      highlightsEn: [
        'Turkish Morphology & Consonant Assimilation Healing: Extended Zemberek validation with -laş/-leş, -(y)ıver, -(y)agel, -maksızın, and copula forms; automatically fixes devoicing errors ("kitapda→kitapta", "gitdi→gitti") and apostrophe-inflected proper nouns/numbers ("Osmanlı\'nm→Osmanlı\'nın", "1923\'de→1923\'te").',
        'Contextual Real-Word Registry, Hyphen & Footnote Proofreading: Added OCP contextual disambiguation rules ("olanak→olarak", "üzen→üzere", "dolay→dolayı", "gön→göre", "karar→kadar"), soft/cross-block hyphen healing, and in-footnote correction support.',
        'Full-Book Scan & Line-Safe Proofreading UI: Added persistent SQLite chapter caching, one-tap Full-Book OCR scan & repair, custom dictionary/unignore management, and newline-safe underline highlights.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.12.0',
      date: '2026-11-08',
      titleTr:
          'Zemberek-NLP Morfolojik Çözümleyici, Optik Karışıklık Matrisi & Minimal Gözden Geçirme',
      titleEn:
          'Zemberek-NLP Morphological Analyzer, Optical Confusion Matrix & Streamlined Review',
      highlightsTr: [
        'Zemberek-NLP Morfolojik Çözümleyici: 34.795 kök ve dinamik ek kurallarıyla %100 çevrimdışı Türkçe kelime doğrulama eklendi.',
        'Optik Karışıklık Matrisi & Poka-Yoke Koruması: rn/m, cl/d, n/rı, hk/lık, yn/yı kaynaşmalarını onarırken geçerli kelimeleri regresyon koruma katmanıyla muhafaza eder.',
        'Minimal Üst Panel Gözden Geçirme: Okuma alanını daraltmayan Word tarzı hızlı OCR tashih arayüzü eklendi.',
      ],
      highlightsEn: [
        'Zemberek-NLP Morphological Engine: 100% offline Turkish root and inflection validation covering 34,795 roots.',
        'Optical Confusion Matrix & Regression Guard: Resolves rn/m, cl/d, n/rı, hk/lık, yn/yı ligatures while safeguarding valid dictionary words.',
        'Minimal Top-Bar Proofreading Panel: Streamlined Word-style review flow preserving maximum reading space.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.11.0',
      date: '2026-11-03',
      titleTr:
          'Kapsamlı rı/ri → n Ligatür Kaynaşması & Çift Ligatür Morfolojik Yerel AI OCR Onarımı',
      titleEn:
          'Comprehensive rı/ri → n Ligature Fusion & Dual-Ligature Morphological AI OCR Healing',
      highlightsTr: [
        'Ünsüz Sonrası, Alıntı Kelime ve Çift Ligatür Onarımı: Taranmış Türkçe/Osmanlıca eserlerde "rı/ri" harf çiftinin "n" olarak okunmasından kaynaklanan tekli ve çiftli kaynaşmaları ("aynca→ayrıca", "aynntılan→ayrıntıları", "yatınmlan→yatırımları", "üzennde→üzerinde", "tanh→tarih", "birbinne→birbirine", "cumhunyet→cumhuriyet", "hürnyet→hürriyet", "fikn→fikri", "şehn→şehri", "nehn→nehri") otomatik onarır.',
        'Morfolojik Çoğul+İyelik (-lan/-len/-lann/-lenn) Çözümleyicisi: "insanlann→insanların", "devletlenn→devletlerin", "kurumlan→kurumları", "koşullan→koşulları", "haklan→hakları" ek kaynaşmalarını edilgen ortaçlara ("yapılan", "verilen", "olan") dokunmadan onarır.',
        'Bağlamsal Gerçek-Kelime rı/ri → n Çözücüsü: Sözlükte geçerli olan ancak "rı/ri→n" kaynaşması nedeniyle anlamı bozulan kelimeleri ("bunlardan bin→biri", "gen çekildiğinde→geri", "içen girdi→içeri", "nüfusun yansından→yarısından", "tanm→tarım") komşu kelime bağlamıyla düzeltir.',
      ],
      highlightsEn: [
        'Post-Consonant, Loanword & Dual-Ligature Repair: Automatically heals single and double "rı/ri → n" OCR ligature fusions across Turkish and Ottoman texts ("aynca→ayrıca", "aynntılan→ayrıntıları", "yatınmlan→yatırımları", "üzennde→üzerinde", "tanh→tarih", "birbinne→birbirine", "cumhunyet→cumhuriyet", "fikn→fikri", "şehn→şehri").',
        'Morphological Plural+Possessive (-lan/-len/-lann/-lenn) Resolver: Restores fused plural-possessive suffixes ("insanlann→insanların", "devletlenn→devletlerin", "kurumlan→kurumları", "koşullan→koşulları", "haklan→hakları") while preserving valid passive participles ("yapılan", "verilen", "olan").',
        'Contextual Real-Word rı/ri → n Disambiguation: Repairs dictionary-valid words corrupted by "rı/ri → n" fusion ("bunlardan bin→biri", "gen çekildiğinde→geri", "içen girdi→içeri", "nüfusun yansından→yarısından", "tanm→tarım") using neighbor context.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.10.0',
      date: '2026-11-02',
      titleTr:
          'Katman 2c Bağlamsal Gerçek-Kelime OCR Karışıklık Çözücüsü & Morfolojik İsim/Fiil Doğrulayıcısı',
      titleEn:
          'Tier 2c Contextual Real-Word OCR Disambiguator & Morphological Noun/Verb Validator',
      highlightsTr: [
        'Katman 2c Bağlamsal Gerçek-Kelime OCR Karışıklık Çözücüsü: Tek başına sözlükte var olan ancak OCR harf karışıklığı (b↔d, l↔t, l↔k, r↔k, p↔ş) nedeniyle cümleyi anlamsızlaştıran kelimeleri ("120 dini→120 bini", "yalnızca diridir→yalnızca biridir", "ortalama getir→ortalama gelir", "yıllık yaklaşım 30 bin→yaklaşık 30 bin") sol ve sağ komşu bağlamına göre onarır.',
        'Klasik Terim, Yardımcı Fiil ve Coğrafya Bağlam Tashihi: "savaşa iştikak→iştirak", "mütenasip okur→olur", "60 bin oluş→olup", "ikiye ayrılık→ayrılır", "Fark Devleti→Fars Devleti", "Santa Aruz→Santa Cruz" ve "büyük yoğunluğu→çoğunluğu" gibi bağlamsal OCR sapmalarını otomatik düzeltir.',
        'Morfolojik İsim/Fiil (POS) Doğrulayıcısı: Fiil sıfat-fiil eklerinin (-dığı/-diği) yalnızca fiil köklerine gelmesini denetleyerek "bölümdüğü→bölündüğü" gibi sahte morfolojik türetmeleri yakalar ve doğru fiil gövdesine yönlendirir.',
      ],
      highlightsEn: [
        'Tier 2c Contextual Real-Word OCR Disambiguator: Repairs valid dictionary words that become semantically nonsensical due to OCR character confusions ("120 dini→120 bini", "yalnızca diridir→biridir", "ortalama getir→gelir", "yaklaşım 30 bin→yaklaşık 30 bin") using left/right neighbor context.',
        'Classical Term, Auxiliary Verb & Geographic Disambiguation: Automatically heals contextual OCR slips such as "savaşa iştikak→iştirak", "mütenasip okur→olur", "60 bin oluş→olup", "ikiye ayrılık→ayrılır", "Fark Devleti→Fars Devleti", and "Santa Aruz→Santa Cruz".',
        'Morphological Noun/Verb (POS) Validator: Enforces verb-only participle suffix rules (-dığı/-diği) against nominal stems so pseudo-valid OCR corruptions like "bölümdüğü" are accurately repaired to "bölündüğü".',
      ],
    ),
    ChangelogRelease(
      version: 'v1.9.0',
      date: '2026-11-02',
      titleTr:
          '3 Katmanlı Yerel Yapay Zeka OCR Tashih Motoru & Yön Duyarlı Sayfa Başı/Sonu Hizalaması',
      titleEn:
          '3-Tier On-Device AI OCR Proofreading Engine & Direction-Aware Page Edge Alignment',
      highlightsTr: [
        'Katman 1 — ML Kit Piksel Geometrisi & Güven Füzyonu: Satır içi mikro-boşlukları (avgCharWidth * 0.48) ve düşük güven skorlu (< 0.78) OCR sembollerini tespit ederek bölünmüş heceleri piksel düzeyinde birleştirir.',
        'Katman 2 — Türkçe Morfolojik SymSpell & Bağlamsal N-Gram Dil Modeli: O(1) simetrik silme indeksiyle aday üretir; sol ve sağ komşu kelimelerle Bigram/Trigram kolokasyon ve Türkçe morfosentaktik uyum puanlaması yapar.',
        'Katman 3 — Karakter Seviyesi Beam Search Çözücüsü: Hem hece bölünmesine hem de eşzamanlı harf bozulmasına/yer değiştirmesine uğrayan kelimeleri ("basarısız ilkle→başarısızlıkla", "gercek lestiğini→gerçekleştiğini") < 5 ms gecikmeyle %100 çevrimdışı onarır.',
        'Yön Duyarlı Sayfa Başı/Sonu Hizalaması: Sonraki sayfaya geçildiğinde sayfanın en üstüne, önceki sayfaya dönüldüğünde ise kaldığınız son satırları kesintisiz okumak için sayfanın en altına otomatik hizalanır.',
      ],
      highlightsEn: [
        'Tier 1 — ML Kit Pixel Geometry & Confidence Fusion: Detects intra-line micro-gaps (avgCharWidth * 0.48) and low-confidence (< 0.78) OCR symbols to fuse split syllables at the bounding-box level.',
        'Tier 2 — Turkish Morphological SymSpell & Contextual N-Gram Language Model: Generates candidates in O(1) via symmetric delete indexing and scores them against left/right neighbors using Bigram/Trigram collocations and morphosyntactic rules.',
        'Tier 3 — Character-Level Beam Search Decoder: Heals words suffering from simultaneous syllable splitting, diacritic loss, and character transposition ("basarısız ilkle→başarısızlıkla") 100% offline in < 5 ms per page.',
        'Direction-Aware Page Edge Alignment: Automatically aligns to the top of the page when advancing forward and to the bottom edge when returning to the previous page for seamless reading continuity.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.8.0',
      date: '2026-11-01',
      titleTr:
          'Bölünmüş Kelime & Osmanlıca Terkip OCR Tashih Veritabanı + Tek Dokunuşla Açılan Popup Lügat',
      titleEn:
          'Split-Word & Ottoman Terkip OCR Lexicon Database + One-Tap Contextual Popup Lexicon',
      highlightsTr: [
        'Genişletilmiş OCR Tashih Veritabanı (OcrLexiconDatabase): 350+ boşluklu hece bölünmesi (örn. "yurt taşlar→yurttaşlar", "bi çimini→biçimini"), yanlış birleştirme koruma listesi ve 1.500+ Türkçe/Osmanlıca kök sözlüğü eklendi.',
        'Osmanlıca Terkip & İzafet Onarımı: OCR sırasında kısa çizgisi düşen 2 ve 3 kelimelik Farsça/Arapça izafet terkipleri (örn. "devlet i aliyye→devlet-i aliyye", "adab ı muaşeret→âdâb-ı muaşeret", "nokta i nazar→nokta-i nazar") otomatik onarılır.',
        'Tek Dokunuşla Açılan Popup Lügat (PopupLugatCard): Okuma esnasında herhangi bir kelimeye tek dokunuşla anlamını, kökenini (Arapça/Farsça/Osmanlıca), morfolojik kök+ek analizini ve ilişkili kavramları gösteren zarif açılır kart eklendi.',
        'Bağlamsal Terkip Algılama & Kart İçi OCR Tashih: Tıklanan kelimenin cümle içindeki Osmanlıca terkip bütünlüğü otomatik algılanır ve kelime üzerinde OCR tashih önerisi varsa kart içinden tek dokunuşla düzeltilir.',
      ],
      highlightsEn: [
        'Expanded OCR Lexicon Database (OcrLexiconDatabase): Added 350+ space-split syllable repairs, a never-merge protection guard for reduplications/compounds, and 1,500+ Turkish/Ottoman root stems.',
        'Ottoman Terkip & Izafet Restoration: Automatically restores 2- and 3-word Persian/Arabic izafet compounds whose hyphens were dropped during OCR (e.g., "devlet-i aliyye", "âdâb-ı muaşeret", "nokta-i nazar").',
        'One-Tap Contextual Popup Lexicon (PopupLugatCard): Tap any word while reading to instantly view its definition, etymology (Arabic/Persian/Ottoman), morphological stem+suffix breakdown, and related concepts without leaving the page.',
        'Contextual Terkip Detection & In-Card OCR Repair: Automatically detects multi-word Ottoman compounds from sentence context and lets you apply or review OCR proofreading fixes in one tap inside the popup card.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.7.0',
      date: '2026-11-01',
      titleTr:
          'Mağaza & MMP Dönüşümü: JSON Yedekleme, Yalın 3 Raflı Kütüphane, Sadeleştirilmiş Okuyucu & Paket Optimizasyonu',
      titleEn:
          'Store & MMP Transformation: JSON Backup, Streamlined 3-Shelf Library, Clean Reader & Package Optimization',
      highlightsTr: [
        'Tam Kapsamlı JSON Yedekleme & Geri Yükleme: Tüm kitap, alıntı, okuma oturumu ve hızlı okuma verilerinizi tek dokunuşla JSON olarak dışa/içe aktarın.',
        'Yalın 3 Raflı Kütüphane & İlk Açılış Rehberi: Kalabalık kartlar temizlenerek "Okumaya Devam Et + 3 Raf (Son Açılanlar, Okunanlar, Tamamlananlar)" mimarisi ve 3 adımlı Karşılama Rehberi eklendi.',
        'Sadeleştirilmiş Okuyucu Barları & Canlı Derkenar Senkronizasyonu: Okuyucu üst/alt barları 4 temel aksiyona indirilip ikincil araçlar çekmecelere toplandı; Derkenar sekmesi canlı senkronize edildi.',
        'Tahrir Pro (Müderris Beratı), "Tahrir ile Aç" Dosya Köprüsü & Paket Küçültme: Kullanılmayan ONNX modelleri temizlenerek APK boyutu optimize edildi ve dışarıdan PDF/EPUB/TXT dosyalarını doğrudan Tahrir ile açma desteği eklendi.',
      ],
      highlightsEn: [
        'Full JSON Backup & Restore: Export and import all books, highlights, reading sessions, and speed reading progress in a single JSON file.',
        'Streamlined 3-Shelf Library & 3-Step Onboarding: Replaced top clutter with "Continue Reading + 3 Shelves (Recent Front Covers, Reading Spines, Completed Spines)" and a 3-step Welcome Onboarding.',
        'Clean Reader Toolbars & Live Marginalia Sync: Simplified top/bottom reader bars to 4 core actions with secondary tools organized in clean drawers; enabled instant live sync on the Marginalia tab.',
        'Tahrir Pro, "Open with Tahrir" Intent Bridge & APK Size Reduction: Removed unused ONNX runtime binaries to significantly reduce APK size and added native OS "Open with Tahrir" support for PDF/EPUB/TXT files.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.6.0',
      date: '2026-11-01',
      titleTr:
          'Tek Akışta 21 Kademeli Hızlı Okuma Serüven Yolu & Kitap Okuma Hızı Koordinasyonu',
      titleEn:
          'Single-Flow 21-Stage Speed Reading Adventure Path & Live Book Speed Coordination',
      highlightsTr: [
        'Hızlı Okuma Akademisi’ndeki 3 sekmeli ayrık yapı kaldırılarak uçtan uca "Tek Akışta 21 Kademeli Serüven Yolu" haritası ve üst barda kompakt "Serbest" pratik çekmecesi inşa edildi.',
        'Kitap Okuma Hızı Koordinasyonu: Kütüphanedeki gerçek kitapları okurken ölçülen WPM hızınız ile Hızlı Okuma Akademisi hedef hızları (Koordineli Hedef WPM) çift yönlü senkronize edildi.',
        'Dinamik Kademe Kalibrasyonu: Günlük serinin bozulması, kitap okuma hızının %15+ düşmesi veya sınav kavramasının %50 altında kalması halinde kademe ve hedef WPM şeffaf biçimde geriye çekilerek gerçekçi seviyeye uyarlanır.',
        'Canlı Kitap Kesiti & Değişken Metin Motoru: Okuduğunuz kitaplardan/alıntılardan otomatik kavrama sorulu antrenman pasajları üretilir ve her egzersiz açılışında farklı bir klasik metin sunularak ezberleme önlenir.',
      ],
      highlightsEn: [
        'Replaced the 3-tab layout in the Speed Reading Academy with a unified "Single-Flow 21-Stage Adventure Path" map and a compact "Free Practice" drawer.',
        'Book Reading Speed Coordination: Synchronizes your real-time book reading WPM from the Bookshelf directly with your Speed Reading Academy target WPM.',
        'Dynamic Stage Calibration: Automatically recalibrates your adventure stage and target WPM downward with transparent feedback when streaks break, book WPM drops by 15%+, or comprehension falls below 50%.',
        'Live Book Excerpt & Dynamic Passage Engine: Generates live drills and comprehension questions from your active books/highlights and rotates fresh classical passages on every run.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.5.0',
      date: '2026-10-30',
      titleTr:
          '8 Simülatörlü Habit-Forming Hızlı Okuma Akademisi, 6 Kıraat Mertebesi & 5 Dk Zihin Ateşi',
      titleEn:
          '8-Simulator Habit-Forming Speed Reading Academy, 6 Scholarly Ranks & 5-Min Mind Igniter',
      highlightsTr: [
        '8 Simülatörlü Habit-Forming Hızlı Okuma Akademisi: 2x Aşırı Hız Sprinti (Otoyol Etkisi / Overdrive), Çevresel Görüş Piramidi & Kanat Okuma, Otomatik İvmeli Auto-Ramp RSVP+ORP, Kombo Çarpanlı Takistoskop, Schulte Tablosu, Blok Pacer, 60 FPS Sakkadik Göz Kasları ve E-WPM Sınavı devreye alındı.',
        '6 Kıraat Mertebesi (Müptedi-i Kıraat → Kutb-u Kıraat), XP Ödül Sistemi, Günlük Seri & Hedef Halkası (3/3), 5 Boyutlu Bilişsel Yetenek Endeksi ve Canlı WPM Sparkline Grafiği eklendi.',
        'Tek Tuşla "⚡ Günlük 5 Dk Zihin Ateşi" (3 Aşamalı Kombine Seans: Schulte + Takistoskop + Auto-Ramp RSVP) ve 2 Sütunlu Modern Bento Grid Tasarım Dili inşa edildi.',
      ],
      highlightsEn: [
        '8-Simulator Habit-Forming Speed Reading Academy: Added 2x Overdrive Sprint (Highway Effect), Peripheral Pyramid & Wing Reading, Auto-Ramp Accelerating RSVP+ORP, Combo-Multiplier Tachistoscope, Schulte Grid, Chunk Pacer, 60 FPS Saccadic Eye Muscles, and E-WPM Exam.',
        'Introduced 6 Scholarly Reading Ranks (Muptedi-i Kiraat → Kutb-u Kiraat), XP Reward System, Daily Streak & Goal Ring (3/3), 5-Dimensional Cognitive Skill Index, and Live WPM Sparkline Chart.',
        'Built the one-tap "⚡ Daily 5-Min Mind Igniter" (3-Stage Combined Workout) and a modern 2-Column Bento Grid UI.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.4.0',
      date: '2026-10-29',
      titleTr:
          'Bilişsel Hızlı Okuma Akademisi, Canlı Kitap Hızlı Okuma Koçu & Otomatik OCR Gözden Geçir (Tashih)',
      titleEn:
          'Cognitive Speed Reading Academy, Live Book Speed Coach & Automatic OCR Proofreader',
      highlightsTr: [
        'Türkçe sondan eklemeli morfolojiye duyarlı Dinamik ORP (Kırmızı Odak Harfi) ve noktalama nefesi bırakan akıllı RSVP simülatörü eklendi.',
        'Parafoveal (çevresel) görüş açısını genişleten merkez odak noktalı Schulte Tablosu (3x3, 5x5, 7x7 — Klasik, Harf ve Dinamik Karışan modlar) devreye alındı.',
        'Geriye dönüşü (regresyonu) önleyen Blok Okuma Pacer (1–4 kelime gruplama), milisaniyelik Takistoskop (25–150 ms Flaş Algı) ve 60 FPS 5 rotalı Sakkadik Göz Kasları Antrenörü eklendi.',
        'Ham hız ile kavrama yüzdesini birleştiren E-WPM (Etkili Okuma Hızı) Seviye Tespit Sınavı, 21 Günlük Kademeli Müfredat ve 5 Bilişsel Teknik Rehberi inşa edildi.',
        'Okuyucu üst barındaki ⚡ Hızlı Okuma Koçu ile okunan kitabın aktif sayfasını veya tamamını doğrudan RSVP+ORP ve Blok Pacer ile okuma imkânı sağlandı.',
        'Taranmış PDF eserlerdeki OCR kaynaklı harf kaynaşmalarını (rn→m, cl→d, rı→n) ve ünlü düşmelerini otomatik onaran Word tarzı "Gözden Geçir & Tashih" çekmecesi eklendi.',
      ],
      highlightsEn: [
        'Added Turkish morphology-aware Dynamic ORP (Optimal Recognition Point) and punctuation-paced smart RSVP simulator.',
        'Built the center-fixation Schulte Grid (3x3, 5x5, 7x7 in Classic Number, Letter, and Dynamic Shuffle modes) to expand peripheral vision.',
        'Added anti-regression Chunk Pacer (1–4 word blocks), millisecond Tachistoscope (25–150 ms Flash Perception), and 60 FPS 5-route Saccadic Eye Muscle Trainer.',
        'Introduced the E-WPM (Effective Words Per Minute = Raw WPM × Comprehension %) Assessment Exam, 21-Day Progressive Curriculum, and 5 Cognitive Technique Guides.',
        'Integrated the in-reader ⚡ Live Book Speed Coach allowing any active book page or full chapter to be read directly inside RSVP+ORP or Chunk Pacer.',
        'Added the Word-style "OCR Proofreader & Review" sheet that automatically heals Turkish/Ottoman OCR character fusions and vowel drops on scanned PDFs.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.3.0',
      date: '2026-10-17',
      titleTr:
          '44.1 kHz Stüdyo Ambiyans Mikseri, 7 Günlük Seri Zinciri, Akıllı Bildirimler & Ana Ekran Widget’ları',
      titleEn:
          '44.1 kHz Studio Soundscape Mixer, 7-Day Streak Chain, Smart Notifications & Home Screen Widgets',
      highlightsTr: [
        '44.1 kHz Paul Kellet pembe gürültü ve dairesel eş-güçlü (Circular Equal-Power Overlap) kesintisiz sonsuz döngü motoruyla 10 yeni stüdyo ambiyans sesi (Pencere Önü Yağmur, Uzak Gök Gürültüsü, Klasik Ney, Şömine, Beyazıt Kütüphanesi, Gece Bahçesi & Şadırvan, Boğaz Dalgaları, Çam Ormanı, Derin Odak, Sahaflar Lo-Fi) eklendi.',
        'İki farklı ambiyans sesini aynı anda karıştırmayı sağlayan "Çift Katmanlı Ambiyans Mikseri" ve hazır mütalaa karışımları (Medrese Gecesi, Kış Kütüphanesi, Şadırvan & Tefekkür) devreye alındı.',
        'Günlük seri sistemi; 7-günlük canlı zincir halkaları, İlmi Rütbe terfileri (Mübtedi -> Talebe-i İlim -> Kâtip -> Müderris -> Allâme) ve "🛡️ Kıraat Kalkanı (Seri Dondurma)" ile güçlendirildi.',
        'Günlük hedef tamamlandığında asla rahatsız etmeyen, yalnızca hedef eksikse veya seri tehlikedeyse devreye giren "Gereklilik Odaklı Akıllı Bildirim Mekanizması" kuruldu.',
        'Telefon ana ekranına sabitlenebilen yerel "📱 Tahrir Cihaz Ana Ekran Widget’ı (Android AppWidget)" ile kütüphane içi "Günün Derkenar Hikmeti & 3 Dk Mikro-Fasıl" teşvik widget’ları eklendi.',
      ],
      highlightsEn: [
        'Replaced all ambient audio with a 44.1 kHz Paul Kellet pink-noise and circular equal-power crossfade zero-seam loop engine across 10 studio soundscapes (Rain, Distant Thunder, Classical Ney, Fireplace, Beyazit Library, Night Courtyard Fountain, Bosphorus Waves, Pine Forest, Deep Focus, BookBazaar Lo-Fi).',
        'Added the "Dual-Layer Soundscape Mixer" and one-tap preset mixes (Madrasa Night, Winter Library, Courtyard Reflection).',
        'Upgraded the Daily Streak system with a live 7-day chain ring, Scholarly Ranks (Mubtedi -> Talebe -> Katip -> Muderris -> Allame), and "🛡️ Streak Freeze Shield".',
        'Built the "Necessity-Driven Smart Notification Engine" that stays silent when daily goals are met and alerts only when a streak is at risk or goals are incomplete.',
        'Added a native Android OS Home Screen Widget ("Tahrir Daily Streak & Mutalaa") with 1-tap pinning alongside in-app "Daily Marginalia Recall & 3-Min Micro-Fasıl" incentive widgets.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.2.0',
      date: '2026-10-17',
      titleTr:
          'Canlı Derkenar Haşiyesi, Fiziksel Ayraç Kurdelesi, PDF Dönüşüm Laboratuvarı & Müderris Beratı',
      titleEn:
          'Live Marginalia Seal, Physical Bookmark Ribbon, PDF Transformation Lab & Muderris License',
      highlightsTr: [
        'Metin içi şerhlere "🖋️ Derkenar Haşiyesi" mührü ile tek dokunuşla Alıntı Stüdyosunda mühürleme ve Kavram Radarı aksiyonları eklendi.',
        'Sesli okuma (TTS) sırasında okunan paragrafı aydınlatıp diğer paragrafları yumuşakça loşlaştıran "🔊 Sinematik Odak Spotu" devreye alındı.',
        'Kitap sırtlarına okuma yüzdesine göre aşağı doğru uzayan fiziksel "Ayraç Kurdelesi" ve biten eserler için altın varaklı "🏆 Hatim Mührü" eklendi.',
        'Kütüphane ekranına Arapça hat, dipnot ve çift sütunlu akademik PDF dönüşümünü anında test ettiren "✨ Canlı PDF Dönüşüm Laboratuvarı" eklendi.',
        'Sıfır reklamlı "Tahrir Pro & Ömür Boyu Müderris Beratı" ve %50 Talebe/Akademisyen (.edu.tr) indirim mimarisi entegre edildi.',
      ],
      highlightsEn: [
        'Added the "🖋️ Live Marginalia Seal" with one-tap Quote Studio sealing and Concept Radar triggers directly inside inline highlight cards.',
        'Introduced "🔊 Cinematic Focus Spotlight" during Text-to-Speech (TTS), illuminating the active paragraph while gently dimming surrounding blocks.',
        'Upgraded book spines with a dynamic physical "Bookmark Ribbon" extending proportionally to reading progress and a gold "🏆 Completion Seal".',
        'Added the "✨ Live PDF Transformation Lab" on the Bookshelf to test Arabic calligraphy, footnote, and two-column academic PDF reflow in one tap.',
        'Integrated the zero-ad "Tahrir Pro & Lifetime Muderris License" paywall with a 50% Student & Academic (.edu) discount switch.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.1.0',
      date: '2026-10-17',
      titleTr: 'Mütalaa Ritüeli (Derin Odak Seansı) & Kitap İçi Kavram Radarı',
      titleEn: 'Mutalaa Ritual (Deep Focus Session) & In-Book Concept Radar',
      highlightsTr: [
        'Tek dokunuşla Ney ambiyansını, Odak Cetvelini, tam ekran dikkat kilidini ve 15 dakikalık geri sayımı başlatan "🕯️ Mütalaa Ritüeli" eklendi.',
        'Seçilen kavramın kitap boyunca geçtiği tüm sayfaları, cümle bağlamlarını ve birlikte geçtiği kavram ağını haritalayan "🧭 Kitap İçi Kavram Radarı (Concordance Engine)" geliştirildi.',
        'Morfolojik kök eşleştirme sayesinde kavramların çekimli halleri de (örn. "hikmetin", "hikmetle") çapraz indekse dahil edildi.',
        'Kütüphane vitrinindeki aktif okuma kartına doğrudan "15 Dk Mütalaa Ritüeli Başlat" aksiyonu eklendi.',
      ],
      highlightsEn: [
        'Added the one-tap "🕯️ Mutalaa Ritual" activating Ney ambient soundscape, Line Focus Ruler, distraction-free full-screen lock, and a 15-minute deep focus timer.',
        'Built the "🧭 In-Book Concept Radar (Concordance Engine)" mapping every page occurrence, contextual sentence, and co-occurring concept network across the book.',
        'Enabled morphological stem matching so inflected Turkish word forms are accurately indexed across pages.',
        'Added a direct "Start 15-Min Mutalaa Ritual" action button to the active reading card on the Bookshelf.',
      ],
    ),
    ChangelogRelease(
      version: 'v1.0.0',
      date: '2026-10-17',
      titleTr: 'X-Ray PDF Dönüşüm Perdesi, Mikro-Nefes Akışı & Yeni Tahrir İkonu',
      titleEn: 'X-Ray PDF Split Curtain, Micro-Breath Flow & New Tahrir App Icon',
      highlightsTr: [
        'Ham/sıkışık PDF görünümü ile Tahrir Akıllı Metin Akışı arasında parmakla sürüklenebilen canlı "X-Ray Dönüşüm Perdesi" eklendi.',
        'Okuma felcini önleyen "Mikro-Nefes (Fasıl) Akışı" rozeti ve alt araç çubuğuna tek dokunuşla "Biyonik Hızlı Odak" anahtarı eklendi.',
        'Katı PDF ızgarasının altın parşömen sayfasına ve kamış kaleme dönüşümünü simgeleyen yeni uygulama ikonu tüm platformlara entegre edildi.',
        '165+ maddelik kapsamlı Klasik Türkçe, Osmanlıca, Edebiyat, Felsefe, Tarih ve İslami İlimler Etimolojik Lügati eklendi.',
        'Türkçe çekim eklerini ve ünsüz yumuşamasını çözümleyen akıllı Morfolojik Kök Bulucu (Stemmer) devreye alındı.',
        'Tahrir Alıntı Stüdyosuna 4. şablon olarak "İs Mürekkebi (AMOLED)" eklendi ve 3x çözünürlükte gerçek PNG görsel paylaşımı sağlandı.',
        'Kitap bitirme sertifikası olan "Tahrir Mühür & Okuma Beratı" yüksek çözünürlüklü PNG olarak dışa aktarılabilir hale getirildi.',
      ],
      highlightsEn: [
        'Added the interactive "X-Ray Transformation Curtain" allowing real-time split-screen dragging between raw PDF pages and Tahrir Smart Reflow.',
        'Introduced "Micro-Breath (Fasıl) Flow" progress indicators and a one-tap "Bionic Fast Focus" toggle on the reading toolbar.',
        'Designed and deployed the new Tahrir master app icon across Android, iOS, and Web symbolizing PDF-to-parchment transformation.',
        'Added a comprehensive 165+ entry Etymological Lexicon covering Classical Turkish, Ottoman, Literature, Philosophy, History, and Islamic Sciences.',
        'Introduced an intelligent Turkish Morphological Stemmer handling inflectional suffixes and consonant softening.',
        'Added the "Soot Ink (AMOLED)" template to Tahrir Quote Studio along with true 3x high-resolution PNG image export and sharing.',
        'Upgraded the "Tahrir Completion Seal & Reading Diploma" with high-resolution PNG certificate export.',
      ],
    ),
    ChangelogRelease(
      version: 'v0.9.0',
      date: '2026-10-01',
      titleTr: 'Akıllı PDF Akışı (Reflow), Çevrimdışı Katip & Mütalaa Temelleri',
      titleEn: 'Smart PDF Reflow, Offline Scribe & Reading Foundations',
      highlightsTr: [
        'Taranmış ve vektörel PDF eserler için çift görünüm (Orijinal Mizanpaj & Akıllı Metin Akışı) motoru kuruldu.',
        'Arapça/Osmanlıca ibare ve hat levhalarını koruyan özel kaligrafi ve dipnot ayrıştırıcı geliştirildi.',
        'Tahrir Parşömeni, İs Mürekkebi (AMOLED), Gece Safiri, Kağıt Beyazı ve Zeytin/Orman okuma temaları eklendi.',
        'Çevrimdışı Bilişsel Özet (Yerel AI Katip), Odak Cetveli, Sesli Okuma (TTS) ve Ambiyans Sesleri entegre edildi.',
      ],
      highlightsEn: [
        'Built the dual-view reading engine (Original Layout & Smart Text Reflow) for vector and scanned PDFs.',
        'Developed specialized calligraphy, inline crop, and footnote parsers preserving Arabic/Ottoman script blocks.',
        'Added 5 curated reading themes: Tahrir Parchment, Soot Ink (AMOLED), Night Sapphire, Paper White, and Olive Forest.',
        'Integrated Offline Cognitive Summary (Local AI Scribe), Line Focus Ruler, Text-to-Speech (TTS), and Ambient Soundscapes.',
      ],
    ),
  ];

  List<ChangelogRelease> getAllReleases() => releases;

  ChangelogRelease get latestRelease => releases.first;
}

class ChangelogModal extends StatefulWidget {
  const ChangelogModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const ChangelogModal(),
    );
  }

  @override
  State<ChangelogModal> createState() => _ChangelogModalState();
}

class _ChangelogModalState extends State<ChangelogModal> {
  bool _isEnglish = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const releases = ChangelogService.releases;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('📜', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(
                        _isEnglish
                            ? 'Tahrir Release Chronicle'
                            : 'Tahrir Sürüm Sicili',
                        style: GoogleFonts.literata(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('TR')),
                      ButtonSegment(value: true, label: Text('EN')),
                    ],
                    selected: {_isEnglish},
                    onSelectionChanged: (s) =>
                        setState(() => _isEnglish = s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: releases.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final rel = releases[index];
                    final title = _isEnglish ? rel.titleEn : rel.titleTr;
                    final items =
                        _isEnglish ? rel.highlightsEn : rel.highlightsTr;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: index == 0
                              ? AppColors.amberGold.withValues(alpha: 0.7)
                              : theme.colorScheme.outline,
                          width: index == 0 ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  rel.version,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              Text(
                                rel.date,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: GoogleFonts.literata(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...items.map(
                            (bullet) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bullet,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        height: 1.45,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
