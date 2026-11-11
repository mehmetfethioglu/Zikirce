import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zamera_video/zamera_video.dart' show ZameraVideoProfile;

import '../constants/camera_colors.dart';
import '../models/app_version_info.dart';
import '../models/zamera_preferences.dart';
import 'release_notes_dialog.dart';

/// Comprehensive full-screen Settings & Configuration dialog for Zamera.
class SettingsSheet extends StatefulWidget {
  final VoidCallback onOpenProbe;
  final VoidCallback onOpenCalibration;
  final ZameraPreferences initialPreferences;
  final ValueChanged<ZameraPreferences>? onPreferencesChanged;
  final VoidCallback? onResetPreferences;
  final List<ZameraVideoProfile> availableVideoProfiles;

  const SettingsSheet({
    super.key,
    required this.onOpenProbe,
    required this.onOpenCalibration,
    this.initialPreferences = const ZameraPreferences(),
    this.onPreferencesChanged,
    this.onResetPreferences,
    this.availableVideoProfiles = const <ZameraVideoProfile>[
      ZameraVideoProfile.universalRec709Locked,
      ZameraVideoProfile.androidHlg10Hevc10Bit,
      ZameraVideoProfile.zameraFlatSdr,
    ],
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onOpenProbe,
    required VoidCallback onOpenCalibration,
    ZameraPreferences initialPreferences = const ZameraPreferences(),
    ValueChanged<ZameraPreferences>? onPreferencesChanged,
    VoidCallback? onResetPreferences,
    List<ZameraVideoProfile> availableVideoProfiles =
        const <ZameraVideoProfile>[
      ZameraVideoProfile.universalRec709Locked,
      ZameraVideoProfile.androidHlg10Hevc10Bit,
      ZameraVideoProfile.zameraFlatSdr,
    ],
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext ctx) => SettingsSheet(
          onOpenProbe: onOpenProbe,
          onOpenCalibration: onOpenCalibration,
          initialPreferences: initialPreferences,
          onPreferencesChanged: onPreferencesChanged,
          onResetPreferences: onResetPreferences,
          availableVideoProfiles: availableVideoProfiles,
        ),
      ),
    );
  }

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late ZameraPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.initialPreferences;
  }

  @override
  void didUpdateWidget(covariant SettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPreferences != widget.initialPreferences) {
      _prefs = widget.initialPreferences;
    }
  }

  void _updatePreferences(ZameraPreferences next) {
    if (next == _prefs) return;
    setState(() {
      _prefs = next;
    });
    widget.onPreferencesChanged?.call(next);
  }

  void _handleReset() {
    const ZameraPreferences defaults = ZameraPreferences.defaults;
    setState(() {
      _prefs = defaults;
    });
    if (widget.onResetPreferences != null) {
      widget.onResetPreferences!();
    } else {
      widget.onPreferencesChanged?.call(defaults);
    }
  }

  void _closeIfPossible() {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _openReleaseNotes({required bool showFeatures}) {
    final NavigatorState navigator = Navigator.of(context);
    final BuildContext hostContext = navigator.context;
    if (navigator.canPop()) {
      navigator.pop();
    }
    ReleaseNotesDialog.show(hostContext, showFeatures: showFeatures);
  }

  void _openProbeTool() {
    _closeIfPossible();
    widget.onOpenProbe();
  }

  void _openCalibrationTool() {
    _closeIfPossible();
    widget.onOpenCalibration();
  }

  Future<void> _launchExternalUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch URL $url: $e');
    }
  }

  void _openLicenseDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => const _LicensePolicyDialog(),
    );
  }

  List<ZameraVideoProfile> _effectiveVideoProfiles() {
    if (widget.availableVideoProfiles.isEmpty) {
      return const <ZameraVideoProfile>[
        ZameraVideoProfile.universalRec709Locked,
      ];
    }
    if (widget.availableVideoProfiles.contains(_prefs.defaultVideoProfile)) {
      return widget.availableVideoProfiles;
    }
    return <ZameraVideoProfile>[
      ...widget.availableVideoProfiles,
      _prefs.defaultVideoProfile,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<ZameraVideoProfile> profiles = _effectiveVideoProfiles();

    return Scaffold(
      backgroundColor: kSurfaceDark,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _SettingsTopBar(
              onReset: _handleReset,
              onClose: _closeIfPossible,
            ),
            const Divider(color: kBorderDark, height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool isTwoColumn = constraints.maxWidth >= 680.0;
                  if (isTwoColumn) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18.0,
                        vertical: 10.0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 11,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _PhotoFormatsSection(
                                  preferences: _prefs,
                                  onChanged: _updatePreferences,
                                ),
                                const SizedBox(height: 14),
                                _VideoFormatsSection(
                                  preferences: _prefs,
                                  availableProfiles: profiles,
                                  onChanged: _updatePreferences,
                                ),
                                const SizedBox(height: 14),
                                _ViewfinderAssistsSection(
                                  preferences: _prefs,
                                  onChanged: _updatePreferences,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 10,
                            child: _AboutHardwareLegalSection(
                              onOpenReleaseNotes: () =>
                                  _openReleaseNotes(showFeatures: false),
                              onOpenGeneralFeatures: () =>
                                  _openReleaseNotes(showFeatures: true),
                              onOpenProbe: _openProbeTool,
                              onOpenCalibration: _openCalibrationTool,
                              onOpenPrivacyPolicy: () => _launchExternalUrl(
                                AppVersionInfo.privacyPolicyUrl,
                              ),
                              onOpenLicenses: _openLicenseDialog,
                              onContactSupport: () => _launchExternalUrl(
                                'mailto:${AppVersionInfo.supportEmail}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _PhotoFormatsSection(
                          preferences: _prefs,
                          onChanged: _updatePreferences,
                        ),
                        const SizedBox(height: 16),
                        _VideoFormatsSection(
                          preferences: _prefs,
                          availableProfiles: profiles,
                          onChanged: _updatePreferences,
                        ),
                        const SizedBox(height: 16),
                        _ViewfinderAssistsSection(
                          preferences: _prefs,
                          onChanged: _updatePreferences,
                        ),
                        const SizedBox(height: 16),
                        _AboutHardwareLegalSection(
                          onOpenReleaseNotes: () =>
                              _openReleaseNotes(showFeatures: false),
                          onOpenGeneralFeatures: () =>
                              _openReleaseNotes(showFeatures: true),
                          onOpenProbe: _openProbeTool,
                          onOpenCalibration: _openCalibrationTool,
                          onOpenPrivacyPolicy: () => _launchExternalUrl(
                            AppVersionInfo.privacyPolicyUrl,
                          ),
                          onOpenLicenses: _openLicenseDialog,
                          onContactSupport: () => _launchExternalUrl(
                            'mailto:${AppVersionInfo.supportEmail}',
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
    );
  }
}

class _SettingsTopBar extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onClose;

  const _SettingsTopBar({
    required this.onReset,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 7.0),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[kIosYellow, Color(0xFFFF9F0A)],
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Z',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kObsidianBg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Zamera Ayarları',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Kayıt Formatları, Vizör & Kalibrasyon',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onReset,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.restart_alt_rounded, size: 15),
            label: const Text(
              'Sıfırla',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Kapat',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _PhotoFormatsSection extends StatelessWidget {
  final ZameraPreferences preferences;
  final ValueChanged<ZameraPreferences> onChanged;

  const _PhotoFormatsSection({
    required this.preferences,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SettingsSectionHeader(title: 'GÖRÜNTÜ KAYIT FORMATLARI'),
        _SettingsCardContainer(
          children: <Widget>[
            _SettingsChipGroupRow<PhotoCaptureFormat>(
              label: 'Fotoğraf & Sanat Çekim Formatı',
              activeSubtitle:
                  '${preferences.photoFormat.titleTr} — ${preferences.photoFormat.subtitleTr}',
              options: PhotoCaptureFormat.values,
              selected: preferences.photoFormat,
              labelOf: (PhotoCaptureFormat f) => f.shortLabel,
              accentColor: kIosYellow,
              onSelected: (PhotoCaptureFormat next) =>
                  onChanged(preferences.copyWith(photoFormat: next)),
            ),
            const Divider(color: kBorderDark, height: 16),
            _SettingsChipGroupRow<PhotoColorSpace>(
              label: 'Çıkış Renk Uzayı (Gamut)',
              activeSubtitle:
                  '${preferences.photoColorSpace.titleTr} — ${preferences.photoColorSpace.subtitleTr}',
              options: PhotoColorSpace.values,
              selected: preferences.photoColorSpace,
              labelOf: (PhotoColorSpace s) => s.shortLabel,
              accentColor: kZameraCyan,
              onSelected: (PhotoColorSpace next) =>
                  onChanged(preferences.copyWith(photoColorSpace: next)),
            ),
            const Divider(color: kBorderDark, height: 16),
            _SettingsSwitchTile(
              icon: Icons.fullscreen_rounded,
              iconColor: kIosYellow,
              title: 'Tam Çözünürlük Sensör Çıktısı',
              subtitle:
                  'Destekleyen lenslerde piksel gruplama olmadan maksimum MP kayıt',
              value: preferences.fullSensorResolution,
              onChanged: (bool v) =>
                  onChanged(preferences.copyWith(fullSensorResolution: v)),
            ),
            const Divider(color: kBorderDark, height: 12),
            _SettingsSwitchTile(
              icon: Icons.verified_outlined,
              iconColor: kZameraCyan,
              title: 'EXIF & ICC Renk Profili Gömme',
              subtitle:
                  'Pozlama meta verilerini ve kalibre edilmiş ICC profilini dosyaya yaz',
              value: preferences.embedExifAndIccProfile,
              onChanged: (bool v) =>
                  onChanged(preferences.copyWith(embedExifAndIccProfile: v)),
            ),
          ],
        ),
      ],
    );
  }
}

class _VideoFormatsSection extends StatelessWidget {
  static const List<int> _fpsChoices = <int>[24, 25, 30, 60];

  final ZameraPreferences preferences;
  final List<ZameraVideoProfile> availableProfiles;
  final ValueChanged<ZameraPreferences> onChanged;

  const _VideoFormatsSection({
    required this.preferences,
    required this.availableProfiles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SettingsSectionHeader(title: 'VİDEO KAYIT FORMATLARI'),
        _SettingsCardContainer(
          children: <Widget>[
            _SettingsChipGroupRow<VideoContainerFormat>(
              label: 'Konteyner & Kodek',
              activeSubtitle:
                  '${preferences.videoContainer.titleTr} — ${preferences.videoContainer.subtitleTr}',
              options: VideoContainerFormat.values,
              selected: preferences.videoContainer,
              labelOf: (VideoContainerFormat c) => c.shortLabel,
              accentColor: kIosYellow,
              onSelected: (VideoContainerFormat next) =>
                  onChanged(preferences.copyWith(videoContainer: next)),
            ),
            const Divider(color: kBorderDark, height: 16),
            _SettingsChipGroupRow<VideoResolutionPreset>(
              label: 'Varsayılan Çözünürlük',
              activeSubtitle: preferences.videoResolution.subtitleTr,
              options: VideoResolutionPreset.values,
              selected: preferences.videoResolution,
              labelOf: (VideoResolutionPreset r) => r.shortLabel,
              accentColor: kIosYellow,
              onSelected: (VideoResolutionPreset next) =>
                  onChanged(preferences.copyWith(videoResolution: next)),
            ),
            const Divider(color: kBorderDark, height: 16),
            _SettingsChipGroupRow<int>(
              label: 'Varsayılan Kare Hızı (FPS)',
              activeSubtitle:
                  '${preferences.defaultVideoFps}p sinema zaman tabanı',
              options: _fpsChoices,
              selected: preferences.defaultVideoFps,
              labelOf: (int fps) => '${fps}p',
              accentColor: kZameraCyan,
              onSelected: (int next) =>
                  onChanged(preferences.copyWith(defaultVideoFps: next)),
            ),
            const Divider(color: kBorderDark, height: 16),
            _SettingsChipGroupRow<VideoBitrateTier>(
              label: 'Hedef Bit Hızı (Bitrate)',
              activeSubtitle: preferences.videoBitrate.subtitleTr,
              options: VideoBitrateTier.values,
              selected: preferences.videoBitrate,
              labelOf: (VideoBitrateTier b) => b.shortLabel,
              accentColor: kIosYellow,
              onSelected: (VideoBitrateTier next) =>
                  onChanged(preferences.copyWith(videoBitrate: next)),
            ),
            const Divider(color: kBorderDark, height: 16),
            _SettingsChipGroupRow<ZameraVideoProfile>(
              label: 'Sinema Gama & Dinamik Aralık Profili',
              activeSubtitle: preferences.defaultVideoProfile.isTenBit
                  ? '10-bit geniş dinamik aralık ve renk derecelendirme akışı'
                  : '8-bit doğrulanmış SDR yayın uyumluluğu',
              options: availableProfiles,
              selected: preferences.defaultVideoProfile,
              labelOf: (ZameraVideoProfile p) => p.shortLabel,
              accentColor: const Color(0xFFFF453A),
              onSelected: (ZameraVideoProfile next) =>
                  onChanged(preferences.copyWith(defaultVideoProfile: next)),
            ),
            const Divider(color: kBorderDark, height: 16),
            _SettingsChipGroupRow<VideoAudioFormat>(
              label: 'Ses Kayıt Formatı',
              activeSubtitle:
                  '${preferences.videoAudioFormat.titleTr} — ${preferences.videoAudioFormat.subtitleTr}',
              options: VideoAudioFormat.values,
              selected: preferences.videoAudioFormat,
              labelOf: (VideoAudioFormat a) => a.shortLabel,
              accentColor: kZameraCyan,
              onSelected: (VideoAudioFormat next) =>
                  onChanged(preferences.copyWith(videoAudioFormat: next)),
            ),
            const Divider(color: kBorderDark, height: 16),
            _SettingsSwitchTile(
              icon: Icons.shutter_speed_rounded,
              iconColor: kIosYellow,
              title: '180° Sinema Enstantane Kilidi',
              subtitle:
                  'Video oturumunu 1/(2×FPS) doğal sinematik hareket açısıyla başlat',
              value: preferences.lock180ShutterAngleByDefault,
              onChanged: (bool v) => onChanged(
                preferences.copyWith(lock180ShutterAngleByDefault: v),
              ),
            ),
            const Divider(color: kBorderDark, height: 12),
            _SettingsSwitchTile(
              icon: Icons.vibration_rounded,
              iconColor: kZameraCyan,
              title: 'OIS+EIS Hibrit Video Sabitleme',
              subtitle:
                  'Optik ve elektronik jiroskop sabitlemeyi kayıt sırasında etkinleştir',
              value: preferences.videoOisEisStabilization,
              onChanged: (bool v) =>
                  onChanged(preferences.copyWith(videoOisEisStabilization: v)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ViewfinderAssistsSection extends StatelessWidget {
  final ZameraPreferences preferences;
  final ValueChanged<ZameraPreferences> onChanged;

  const _ViewfinderAssistsSection({
    required this.preferences,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SettingsSectionHeader(title: 'VİZÖR & ÇEKİM YARDIMCILARI'),
        _SettingsCardContainer(
          children: <Widget>[
            _SettingsSwitchTile(
              icon: Icons.bar_chart_rounded,
              iconColor: kIosYellow,
              title: 'Canlı RGB / Parlaklık Histogramı',
              subtitle: 'Vizörde gerçek zamanlı pozlama dağılım grafiğini aç',
              value: preferences.showLiveHistogramByDefault,
              onChanged: (bool v) => onChanged(
                preferences.copyWith(showLiveHistogramByDefault: v),
              ),
            ),
            const Divider(color: kBorderDark, height: 12),
            _SettingsSwitchTile(
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFFF453A),
              title: '%95 Aşırı Pozlama Zebra Uyarısı',
              subtitle: 'Patlayan parlak bölgeleri (%95+ IRE) vizörde çizgile',
              value: preferences.showOverexposureZebra95,
              onChanged: (bool v) =>
                  onChanged(preferences.copyWith(showOverexposureZebra95: v)),
            ),
            const Divider(color: kBorderDark, height: 12),
            _SettingsSwitchTile(
              icon: Icons.face_retouching_natural_outlined,
              iconColor: const Color(0xFFFF9F0A),
              title: '%70 Cilt Tonu Zebra Kılavuzu',
              subtitle:
                  'Portre ve sinemada %70 IRE referans cilt parlaklık kuşağı',
              value: preferences.showSkinToneZebra70,
              onChanged: (bool v) =>
                  onChanged(preferences.copyWith(showSkinToneZebra70: v)),
            ),
            const Divider(color: kBorderDark, height: 12),
            _SettingsSwitchTile(
              icon: Icons.center_focus_strong_outlined,
              iconColor: const Color(0xFF30D158),
              title: 'Focus Peaking (Netlik Vurgusu)',
              subtitle: 'Manuel odakta net kenarları yüksek kontrastla vurgula',
              value: preferences.showFocusPeakingByDefault,
              onChanged: (bool v) =>
                  onChanged(preferences.copyWith(showFocusPeakingByDefault: v)),
            ),
            const Divider(color: kBorderDark, height: 12),
            _SettingsSwitchTile(
              icon: Icons.colorize_rounded,
              iconColor: kZameraCyan,
              title: 'Sanat Modu Canlı Renk Ölçer',
              subtitle: 'Merkez CIE L*a*b*, #HEX ve ΔE₀₀ spot kolorimetre rozeti',
              value: preferences.showSpotColorMeterInArtMode,
              onChanged: (bool v) => onChanged(
                preferences.copyWith(showSpotColorMeterInArtMode: v),
              ),
            ),
            const Divider(color: kBorderDark, height: 12),
            _SettingsSwitchTile(
              icon: Icons.blur_circular_rounded,
              iconColor: const Color(0xFF64D2FF),
              title: 'Flat-Field Köşe Kararması Düzeltmesi',
              subtitle:
                  '4-kanal RGGB LensShadingMap ile vinyet ve renk kaymasını gider',
              value: preferences.applyFlatFieldShading,
              onChanged: (bool v) =>
                  onChanged(preferences.copyWith(applyFlatFieldShading: v)),
            ),
            const Divider(color: kBorderDark, height: 12),
            _SettingsSwitchTile(
              icon: Icons.touch_app_outlined,
              iconColor: kIosYellow,
              title: 'Radyal Kadran Haptik Titreşimi',
              subtitle: 'Tekerlek duraklarında hassas mekanik klik hissi üret',
              value: preferences.radialHapticFeedback,
              onChanged: (bool v) =>
                  onChanged(preferences.copyWith(radialHapticFeedback: v)),
            ),
            const Divider(color: kBorderDark, height: 12),
            _SettingsSwitchTile(
              icon: Icons.flip_rounded,
              iconColor: const Color(0xFFBF5AF2),
              title: 'Ön Kamera Ayna Kaydı',
              subtitle: 'Selfie karelerini vizör önizlemesiyle aynı yönde sakla',
              value: preferences.mirrorFrontCamera,
              onChanged: (bool v) =>
                  onChanged(preferences.copyWith(mirrorFrontCamera: v)),
            ),
          ],
        ),
      ],
    );
  }
}

class _AboutHardwareLegalSection extends StatelessWidget {
  final VoidCallback onOpenReleaseNotes;
  final VoidCallback onOpenGeneralFeatures;
  final VoidCallback onOpenProbe;
  final VoidCallback onOpenCalibration;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenLicenses;
  final VoidCallback onContactSupport;

  const _AboutHardwareLegalSection({
    required this.onOpenReleaseNotes,
    required this.onOpenGeneralFeatures,
    required this.onOpenProbe,
    required this.onOpenCalibration,
    required this.onOpenPrivacyPolicy,
    required this.onOpenLicenses,
    required this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SettingsSectionHeader(title: 'BİLGİ & YENİLİKLER'),
        _SettingsActionTile(
          icon: Icons.new_releases_outlined,
          iconColor: kIosYellow,
          title: 'Sürüm Notları & Yenilikler',
          subtitle: 'v${AppVersionInfo.currentVersion} güncelleme detayları',
          onTap: onOpenReleaseNotes,
        ),
        _SettingsActionTile(
          icon: Icons.auto_awesome_outlined,
          iconColor: kZameraCyan,
          title: 'Zamera Genel Özellikleri',
          subtitle: 'Sanat Modu, Pro Foto, Video & Gizlilik rehberi',
          onTap: onOpenGeneralFeatures,
        ),
        const SizedBox(height: 8),
        const _SettingsSectionHeader(title: 'DONANIM & KALİBRASYON'),
        _SettingsActionTile(
          icon: Icons.memory_outlined,
          iconColor: const Color(0xFF64D2FF),
          title: 'Cihaz Yetenek Probe (Faz 0)',
          subtitle: 'Camera2 / AVFoundation donanım ve lens dökümü',
          onTap: onOpenProbe,
        ),
        _SettingsActionTile(
          icon: Icons.palette_outlined,
          iconColor: const Color(0xFF34C759),
          title: 'ColorChecker Kalibrasyonu (Faz 1)',
          subtitle: '24-Yama D50 CIE-DE2000 renk matrisi çözücü',
          onTap: onOpenCalibration,
        ),
        const SizedBox(height: 8),
        const _SettingsSectionHeader(title: 'GİZLİLİK & YASAL'),
        _SettingsActionTile(
          icon: Icons.security_outlined,
          iconColor: const Color(0xFF30D158),
          title: 'Gizlilik Politikası (GitHub Pages)',
          subtitle: 'KVKK, GDPR & %100 çevrimdışı yerel veri güvencesi',
          onTap: onOpenPrivacyPolicy,
        ),
        _SettingsActionTile(
          icon: Icons.policy_outlined,
          iconColor: const Color(0xFFBF5AF2),
          title: 'Telif & Açık Kaynak Lisansları',
          subtitle: 'ADR-2 sıfır-GPL mağaza uyumluluk beyanı',
          onTap: onOpenLicenses,
        ),
        _SettingsActionTile(
          icon: Icons.mail_outline,
          iconColor: const Color(0xFFFF9F0A),
          title: 'Destek & İletişim',
          subtitle: AppVersionInfo.supportEmail,
          onTap: onContactSupport,
        ),
        const SizedBox(height: 10),
        const _SettingsVersionFooter(),
      ],
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;

  const _SettingsSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 5),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: Colors.white38,
        ),
      ),
    );
  }
}

class _SettingsCardContainer extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCardContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SettingsChipGroupRow<T> extends StatelessWidget {
  final String label;
  final String activeSubtitle;
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final Color accentColor;
  final ValueChanged<T> onSelected;

  const _SettingsChipGroupRow({
    required this.label,
    required this.activeSubtitle,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.accentColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          activeSubtitle,
          style: const TextStyle(
            fontSize: 10.5,
            color: Colors.white54,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final T item in options)
              _SettingsOptionChip(
                label: labelOf(item),
                isSelected: item == selected,
                accentColor: accentColor,
                onTap: () => onSelected(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _SettingsOptionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _SettingsOptionChip({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.20)
              : kSurfaceDark,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected ? accentColor : kBorderDark,
            width: isSelected ? 1.2 : 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? accentColor : Colors.white70,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.white54,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              activeThumbColor: kIosYellow,
              activeTrackColor: kIosYellow.withValues(alpha: 0.36),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderDark),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white30,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsVersionFooter extends StatelessWidget {
  const _SettingsVersionFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: <Widget>[
          Text(
            'Zamera v${AppVersionInfo.currentVersion} (Derleme ${AppVersionInfo.currentBuildNumber})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Akarworks Studio · TrueColor CIEDE2000 Engine',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}

class _LicensePolicyDialog extends StatelessWidget {
  const _LicensePolicyDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kSurfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: kBorderDark),
      ),
      title: const Text(
        'Telif & Lisans Politikası',
        style: TextStyle(
          color: kIosYellow,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Zamera — Sıfır GPL Bağımsız Mimari (ADR-2)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Bu uygulama App Store ve Google Play Console ticari mağaza gereksinimlerine uygun olarak yalnızca MIT, Apache-2.0, BSD ve ISC lisanslı bağımlılıklar ile inşa edilmiştir.\n\n'
              'Gömülü Rust renk bilimi çekirdeği (zamera_core), Sharma 2005 CIEDE2000 formülleri ve BabelColor D50 referans matrisi kullanılarak geliştirilmiştir. Hiçbir statik GPL/AGPL kodu içermez.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            SizedBox(height: 14),
            Text(
              '© 2026 Akarworks. Tüm Hakları Saklıdır.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat', style: TextStyle(color: kIosYellow)),
        ),
      ],
    );
  }
}
