import 'package:flutter/material.dart';

/// Single item in release notes or feature highlight.
class FeatureHighlight {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const FeatureHighlight({
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor = const Color(0xFFFFD60A),
  });
}

/// Release note metadata and changelog for a specific version.
class ReleaseNote {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String titleTr;
  final String titleEn;
  final List<String> bulletPointsTr;
  final List<String> bulletPointsEn;

  const ReleaseNote({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.titleTr,
    required this.titleEn,
    required this.bulletPointsTr,
    required this.bulletPointsEn,
  });
}

/// Central repository of Zamera features and version release history.
class AppVersionInfo {
  static const String currentVersion = '0.1.4';
  static const int currentBuildNumber = 5;
  static const String appName = 'Zamera';
  static const String privacyPolicyUrl = 'https://mehmetfethioglu.github.io/Zamera/';
  static const String supportEmail = 'theakar@windowslive.com';

  /// General features presented to users on their first launch or via Settings.
  static const List<FeatureHighlight> generalFeatures = [
    FeatureHighlight(
      title: 'Gerçek Renk & Sanat Modu (ΔE₀₀ ≤ 1.0)',
      description:
          'X-Rite 24-yama ColorChecker Classic desteğiyle sensör renk sapmalarını sıfırlar. Sharma 2005 doğrulanmış CIE-DE2000 renk bilimi motoru doğrudan cihaz üzerinde çalışır.',
      icon: Icons.palette_outlined,
      accentColor: Color(0xFF4ECDC4),
    ),
    FeatureHighlight(
      title: 'Manuel Profesyonel Fotoğrafçılık',
      description:
          'Fiziksel lens kilidi (13mm/24mm/100mm), 14-bit Bayer RAW / Apple ProRAW, manuel enstantane, ISO, Kelvin/Tint beyaz dengesi ve 3-kare AE braket çekimi.',
      icon: Icons.camera_alt_outlined,
      accentColor: Color(0xFFFFD60A),
    ),
    FeatureHighlight(
      title: 'Sinema Seviyesi Pro Video (180° Kilit)',
      description:
          '180° enstantane açısı kilitli sinematik hareket bulanıklığı, Apple Log & HLG10 HEVC desteği, gerçek zamanlı 3D .cube LUT önizleme ve 48kHz stereo ses takibi.',
      icon: Icons.videocam_outlined,
      accentColor: Color(0xFFFF453A),
    ),
    FeatureHighlight(
      title: 'Stüdyo Portre & Nesne Ayırma Çıkartması',
      description:
          'Çekim sonrası sanal diyafram (f/1.4..f/16) ve stüdyo ışık yeniden işleme; tek dokunuşla kişiyi şeffaf PNG çıkartma olarak panoya kopyalama ve paylaşma.',
      icon: Icons.portrait_outlined,
      accentColor: Color(0xFFBF5AF2),
    ),
    FeatureHighlight(
      title: '%100 Cihaz İçi Gizlilik & Sıfır Takip',
      description:
          'Hiçbir fotoğraf veya video buluta gönderilmez. Sıfır reklam, sıfır ticari izleyici; tamamen yerel, bağımsız ve güvenli.',
      icon: Icons.security_outlined,
      accentColor: Color(0xFF34C759),
    ),
  ];

  /// Changelog history of all releases.
  static const List<ReleaseNote> releaseHistory = [
    ReleaseNote(
      version: '0.1.4',
      buildNumber: 5,
      releaseDate: '13 Kasım 2026',
      titleTr: 'Sanat Modu 1:1 Radyometrik Pozlama, iOS Vizör & Portre İyileştirmeleri',
      titleEn: 'Art Mode 1:1 Radiometric Exposure, iOS Viewfinder & Portrait Refinements',
      bulletPointsTr: [
        'Sanat Modu (1:1 TON ve KAĞIT L*94) çekimlerinde ΔE00 renk doğruluğu, CIE (x, y) kromatisitesi ve koyu (chiaroscuro) tonlar %100 korunarak karanlık kalan RAW pozlama sahne-doğrusal radyometrik referansla düzeltildi.',
        'Vernik, cam ve çerçeve kaynaklı noktasal yansımaların pozlamayı kilitlemesi önlendi (p96 difüz tavan) ve L* ≈ 96 sabit-tonlu parlak alan geçişi iyileştirildi.',
        'iOS kamera vizöründe oturum başlatma ve geçiş sırasındaki görüntü akışı kararlılığı iyileştirildi.',
        'Stüdyo Portre Sahne Işığı maskesi, şeffaf PNG çıkartmasını doğrudan panoya kopyalama akışı ve çekim denetçisinde dokunarak piksel renk ölçümü geliştirildi.',
      ],
      bulletPointsEn: [
        'Fixed dark RAW output in Art Mode (1:1 Tone & Paper L*94) via scene-linear radiometric midtone matching while preserving 100% of ΔE00 color accuracy, hue, and dark chiaroscuro tones.',
        'Isolated specular varnish/glass glints from locking down exposure (p96 diffuse ceiling) and refined the L* ≈ 96 constant-hue highlight shoulder.',
        'Improved iOS live viewfinder stream stability across camera session startup and lens transitions.',
        'Refined Portrait Studio Stage Light backdrop mask, clipboard-first transparent PNG cutout workflow, and tap-to-measure pixel colorimetry in Capture Inspector.',
      ],
    ),
    ReleaseNote(
      version: '0.1.3',
      buildNumber: 4,
      releaseDate: '11 Kasım 2026',
      titleTr: 'Gerçek DSLR Pozlama (PASM) & Sinema Video Deneyimi',
      titleEn: 'True DSLR Exposure (PASM) & Cinema Video Experience',
      bulletPointsTr: [
        'Pro moduna sarsıntısız (Bumpless) P / Tv / Sv / M pozlama önceliği, 1/3-EV DSLR durakları (ISO 50..12800, 30"..1/8000s), canlı [-3..+3] EV pozometre, AEB ±2 / zamanlayıcı sürücü modları ve AEL/AFL kilidi eklendi.',
        'Video moduna etkileşimli Sinema HUD (4K/1080P, 24/25/30/60p FPS, 180° açı kilidi, 10-bit profil, tek dokunuş LUT BYPASS) ve STBY/REC yayın seviyesi (-60..0 dB) ses göstergesi eklendi.',
        'Kayıt sırasında kesintisiz çalışan Sinema Hızlı Güvertesi (optik lens geçişi, canlı A · B · A↔B Rack Focus ve hız seçimi) ile ARRI/FX3 kırmızı REC Tally çerçevesi eklendi.',
        'Video oturumu tek-IPC telemetri ve vizör spot AF/AE dokunuş kancalarıyla optimize edildi; 2 katmanlı eşmerkezli radyal ayar yayı ile buton çakışmaları giderildi.',
      ],
      bulletPointsEn: [
        'Added bumpless P / Tv / Sv / M DSLR exposure priority, 1/3-EV stops (ISO 50..12800, 30"..1/8000s), live [-3..+3] EV light meter, AEB ±2 / self-timer drive modes, and AEL/AFL lock to Pro mode.',
        'Added interactive Cinema HUD (4K/1080P, 24/25/30/60p FPS, 180° shutter lock, 10-bit profile, 1-tap LUT BYPASS) and broadcast (-60..0 dB) Peak+RMS audio meter in both Standby and Recording.',
        'Added live Cinema Quick Deck (optical lens switcher, live A · B · A↔B Rack Focus with speed control) and ARRI/FX3 crimson REC Tally frame.',
        'Optimized Video mode with single-IPC telemetry, active video session spot AF/AE gestures, and an overlap-free 2-tier concentric radial settings arc.',
      ],
    ),
    ReleaseNote(
      version: '0.1.2',
      buildNumber: 3,
      releaseDate: '11 Kasım 2026',
      titleTr: 'Sanat Modu — 1:1 Gerçek Renk Kalibrasyonu & Canlı Kolorimetre',
      titleEn: 'Art Mode — 1:1 True-Color Calibration & Live Colorimeter',
      bulletPointsTr: [
        'Canlı vizörde üretici S-eğrisi yerine sRGB/Gamma 2.2 ton haritalama, wideColorGamut ekran renk yönetimi ve kalibre edilmiş 3x3 CCM matrisi aktif edildi.',
        'Rust çekirdeğinde sabit-ton/sabit-parlaklık negatif gamut sıkıştırma, 1:1 Doğal Ton pozlama modu ve 4-kanal RGGB LensShadingMap düzeltmesi eklendi.',
        '14-bit RAW karesinden doğrudan 24-yama ColorChecker ölçümü, D50 beyaz noktası kısıtlı kalibrasyon ve lens bazlı kalıcı profil saklama eklendi.',
        'Canlı merkez CIE L*a*b* / #HEX / ΔE00 renk ölçer rozeti, Kayıpsız PNG kaydı ve çekim sonrası TrueColor ↔ Stok Kamera (OEM) A/B piksel denetçisi eklendi.',
      ],
      bulletPointsEn: [
        'Enabled live viewfinder sRGB/Gamma 2.2 tone mapping, wideColorGamut display color management, and real-time calibrated 3x3 CCM preview.',
        'Added constant-hue/luminance negative gamut compression, 1:1 Natural Tone exposure mode, and 4-channel RGGB LensShadingMap correction in Rust.',
        'Added direct 14-bit RAW 24-patch ColorChecker extraction, D50 white-preserving calibration, and persistent per-lens profile storage.',
        'Added live center CIE L*a*b* / #HEX / ΔE00 spot colorimeter, Lossless PNG export, and post-capture TrueColor vs OEM A/B pixel inspector.',
      ],
    ),
    ReleaseNote(
      version: '0.1.1',
      buildNumber: 2,
      releaseDate: 'Kasım 2026',
      titleTr: 'Faz 0-3 iOS Eşliği, Sürüm Notları & Pro Video Entegrasyonu',
      titleEn: 'Phase 0-3 iOS Parity, Release Notes & Pro Video Integration',
      bulletPointsTr: [
        'iOS için Faz 0, 1, 2 ve 3 tam eşliği tamamlandı: Apple Log, ProRes 422 HQ, AE Braketleme ve Vision kişi ayırma çıkartması native olarak eklendi.',
        'Sürüm Notları ve İlk Açılış Rehberi eklendi; Ayarlar menüsünden her an erişilebilir hale getirildi.',
        'GitHub Pages üzerinden resmi Gizlilik Politikası ve Destek Portalı yayına alındı.',
        'Proje mimarisi Akarworks v6.1 kurallarına (Saf SRP, tek vazife blokları) göre modüler hale getirildi.',
        '120 FPS akıcı tekerlek kontrolü ve bellek sızıntı korumaları güçlendirildi.',
      ],
      bulletPointsEn: [
        'Completed full iOS parity across Phase 0, 1, 2, and 3: native Apple Log, ProRes 422 HQ, AE Bracketing, and Vision subject cutout.',
        'Added Release Notes & First Launch Welcome Guide, accessible anytime from the new Settings menu.',
        'Launched official Privacy Policy & Support portal on GitHub Pages.',
        'Refactored architecture to Akarworks v6.1 Single Responsibility Principle (SRP) standards.',
        'Optimized 120 FPS radial wheel controls and strict disposal safety.',
      ],
    ),
    ReleaseNote(
      version: '0.1.0',
      buildNumber: 1,
      releaseDate: 'Kasım 2026',
      titleTr: 'İlk Halka Açık Önizleme: Sanat Modu & Pro Kamera Çekirdeği',
      titleEn: 'Initial Public Preview: Art Mode & Pro Camera Core',
      bulletPointsTr: [
        'Donanım yetenek probe sistemi (Camera2 / AVFoundation).',
        'Rust zamera_core CIEDE2000 renk motoru ve ColorChecker 24-yama matrisi.',
        '14-bit Bayer RAW ve DNG yazımı.',
        'Minimalist tam ekran vizör ve radyal kadran arayüzü.',
      ],
      bulletPointsEn: [
        'Hardware capability probe for Camera2 and AVFoundation.',
        'Embedded Rust zamera_core CIEDE2000 engine with 24-patch ColorChecker solver.',
        '14-bit Bayer RAW capture and DNG export.',
        'Minimalist full-screen viewfinder and radial dials UI.',
      ],
    ),
  ];

  static ReleaseNote get latestRelease => releaseHistory.first;
}
