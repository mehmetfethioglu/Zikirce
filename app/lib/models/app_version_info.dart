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
  static const String currentVersion = '0.1.1';
  static const int currentBuildNumber = 2;
  static const String appName = 'Zamera';
  static const String privacyPolicyUrl = 'https://mehmetfethioglu.github.io/Zamera/';
  static const String supportEmail = 'akarworks@gmail.com';

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
