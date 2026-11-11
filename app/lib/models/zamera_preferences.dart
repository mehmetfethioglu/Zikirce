import 'package:flutter/foundation.dart';
import 'package:zamera_video/zamera_video.dart' show ZameraVideoProfile;

/// OCP-compliant photo capture format descriptors carrying immutable capability flags.
enum PhotoCaptureFormat {
  jpegOnly(
    shortLabel: 'JPEG',
    titleTr: 'Yüksek Uyumluluk (JPEG)',
    subtitleTr: '8-bit hızlı kayıt, tüm cihaz ve galerilerle anında uyumlu',
    capturesRaw: false,
    isLosslessPng: false,
    prefersProRaw48Mp: false,
  ),
  heif10Bit(
    shortLabel: 'HEIF 10B',
    titleTr: 'Yüksek Verimlilik (10-bit HEIF)',
    subtitleTr: '10-bit geniş ton geçişi ve %50 daha verimli depolama',
    capturesRaw: false,
    isLosslessPng: false,
    prefersProRaw48Mp: false,
  ),
  losslessPng(
    shortLabel: 'PNG 1:1',
    titleTr: 'Kayıpsız Arşiv (Lossless PNG)',
    subtitleTr: 'Sıkıştırma artefaktı olmadan 1:1 kalibre edilmiş piksel kaydı',
    capturesRaw: false,
    isLosslessPng: true,
    prefersProRaw48Mp: false,
  ),
  dngRawOnly(
    shortLabel: 'DNG RAW',
    titleTr: 'Saf Sensör (14-bit DNG RAW)',
    subtitleTr: 'Sıkıştırılmamış doğrusal Bayer sensör verisi, maksimum esneklik',
    capturesRaw: true,
    isLosslessPng: false,
    prefersProRaw48Mp: false,
  ),
  rawPlusJpeg(
    shortLabel: 'RAW+JPG',
    titleTr: 'Hibrit Çekim (DNG RAW + JPEG)',
    subtitleTr: '14-bit DNG negatif ile işlenmiş JPEG karesini birlikte saklar',
    capturesRaw: true,
    isLosslessPng: false,
    prefersProRaw48Mp: false,
  ),
  proRaw48Mp(
    shortLabel: 'PRORAW 48',
    titleTr: 'Tam Çözünürlük 48MP ProRAW / DNG',
    subtitleTr: 'Destekleyen sensörlerde 48MP doğrusal DNG / Apple ProRAW kaydı',
    capturesRaw: true,
    isLosslessPng: false,
    prefersProRaw48Mp: true,
  );

  const PhotoCaptureFormat({
    required this.shortLabel,
    required this.titleTr,
    required this.subtitleTr,
    required this.capturesRaw,
    required this.isLosslessPng,
    required this.prefersProRaw48Mp,
  });

  final String shortLabel;
  final String titleTr;
  final String subtitleTr;
  final bool capturesRaw;
  final bool isLosslessPng;
  final bool prefersProRaw48Mp;

  static PhotoCaptureFormat fromName(
    Object? raw, {
    PhotoCaptureFormat fallback = PhotoCaptureFormat.rawPlusJpeg,
  }) =>
      _enumByName(values, raw, fallback);
}

/// OCP-compliant output color space descriptors for Photo and Art modes.
enum PhotoColorSpace {
  sRgb(
    shortLabel: 'sRGB',
    titleTr: 'Standart sRGB (IEC 61966-2-1)',
    subtitleTr: 'Web, baskı ve tüm ekranlarla evrensel uyumlu renk uzayı',
    usesDisplayP3: false,
  ),
  displayP3(
    shortLabel: 'Display P3',
    titleTr: 'Geniş Gamut Display P3',
    subtitleTr: '%25 daha geniş sinematik renk hacmi ve zengin doygun tonlar',
    usesDisplayP3: true,
  ),
  trueColorLabD50(
    shortLabel: 'D50 Doğal',
    titleTr: 'Kalibre CIE L*a*b* (D50 Referans)',
    subtitleTr: 'ColorChecker 3x3 matrisiyle ΔE₀₀ ≤ 1.0 kolorimetrik doğruluk',
    usesDisplayP3: false,
  );

  const PhotoColorSpace({
    required this.shortLabel,
    required this.titleTr,
    required this.subtitleTr,
    required this.usesDisplayP3,
  });

  final String shortLabel;
  final String titleTr;
  final String subtitleTr;
  final bool usesDisplayP3;

  static PhotoColorSpace fromName(
    Object? raw, {
    PhotoColorSpace fallback = PhotoColorSpace.sRgb,
  }) =>
      _enumByName(values, raw, fallback);
}

/// OCP-compliant video container and codec descriptors.
enum VideoContainerFormat {
  mp4Hevc10Bit(
    shortLabel: 'HEVC 10B',
    titleTr: 'MP4 · H.265 / HEVC (10-bit Main10)',
    subtitleTr: 'Yüksek verimli 10-bit sinematik MP4 konteyner',
    fileExtension: 'mp4',
  ),
  mp4H264Compat(
    shortLabel: 'H.264 MP4',
    titleTr: 'MP4 · H.264 / AVC (Evrensel)',
    subtitleTr: '8-bit Rec.709 hızlı kurgu ve tüm oynatıcılarla tam uyum',
    fileExtension: 'mp4',
  ),
  movProRes422Hq(
    shortLabel: 'ProRes HQ',
    titleTr: 'MOV · Apple ProRes 422 HQ',
    subtitleTr: '10-bit 4:2:2 intra-frame kurgu kodeği (destekleyen cihazlarda)',
    fileExtension: 'mov',
  );

  const VideoContainerFormat({
    required this.shortLabel,
    required this.titleTr,
    required this.subtitleTr,
    required this.fileExtension,
  });

  final String shortLabel;
  final String titleTr;
  final String subtitleTr;
  final String fileExtension;

  static VideoContainerFormat fromName(
    Object? raw, {
    VideoContainerFormat fallback = VideoContainerFormat.mp4Hevc10Bit,
  }) =>
      _enumByName(values, raw, fallback);
}

/// OCP-compliant video resolution presets.
enum VideoResolutionPreset {
  uhd4k(
    shortLabel: '4K',
    titleTr: '4K UHD (3840×2160)',
    subtitleTr: '3840×2160 tam sensör okumalı sinema çözünürlüğü',
    widthPx: 3840,
    heightPx: 2160,
  ),
  fhd1080p(
    shortLabel: '1080P',
    titleTr: '1080p Full HD (1920×1080)',
    subtitleTr: '1920×1080 düşük ısınma ve uzun süreli kesintisiz kayıt',
    widthPx: 1920,
    heightPx: 1080,
  );

  const VideoResolutionPreset({
    required this.shortLabel,
    required this.titleTr,
    required this.subtitleTr,
    required this.widthPx,
    required this.heightPx,
  });

  final String shortLabel;
  final String titleTr;
  final String subtitleTr;
  final int widthPx;
  final int heightPx;

  static VideoResolutionPreset fromName(
    Object? raw, {
    VideoResolutionPreset fallback = VideoResolutionPreset.uhd4k,
  }) =>
      _enumByName(values, raw, fallback);
}

/// OCP-compliant target video bitrate tiers.
enum VideoBitrateTier {
  standard(
    shortLabel: '50 Mbps',
    subtitleTr: 'Günlük çekim ve dengeli depolama (Long-GOP)',
    mbps: 50,
  ),
  broadcastHigh(
    shortLabel: '120 Mbps',
    subtitleTr: 'Yayın kalitesinde yüksek detay ve renk derecelendirme',
    mbps: 120,
  ),
  cinemaAllIntra(
    shortLabel: '240 Mbps',
    subtitleTr: 'Sinema seviyesi maksimum bit hızı ve ağır post-prodüksiyon',
    mbps: 240,
  );

  const VideoBitrateTier({
    required this.shortLabel,
    required this.subtitleTr,
    required this.mbps,
  });

  final String shortLabel;
  final String subtitleTr;
  final int mbps;

  int get bitsPerSecond => mbps * 1000000;

  static VideoBitrateTier fromName(
    Object? raw, {
    VideoBitrateTier fallback = VideoBitrateTier.broadcastHigh,
  }) =>
      _enumByName(values, raw, fallback);
}

/// OCP-compliant video audio capture format descriptors.
enum VideoAudioFormat {
  aacStereo48k(
    shortLabel: 'AAC 48kHz',
    titleTr: 'AAC Stereo (48 kHz / 320 kbps)',
    subtitleTr: 'Evrensel uyumlu yüksek kaliteli stereo ses kaydı',
  ),
  pcm24BitUncompressed(
    shortLabel: 'PCM 24-bit',
    titleTr: 'Doğrusal PCM (24-bit / 48 kHz Kayıpsız)',
    subtitleTr: 'Sıkıştırılmamış yayın kalitesinde stüdyo ses kaydı',
  );

  const VideoAudioFormat({
    required this.shortLabel,
    required this.titleTr,
    required this.subtitleTr,
  });

  final String shortLabel;
  final String titleTr;
  final String subtitleTr;

  bool get isUncompressedPcm => this == VideoAudioFormat.pcm24BitUncompressed;

  static VideoAudioFormat fromName(
    Object? raw, {
    VideoAudioFormat fallback = VideoAudioFormat.pcm24BitUncompressed,
  }) =>
      _enumByName(values, raw, fallback);
}

/// Immutable, value-equal user preferences snapshot for Zamera Photo, Art, and Cinema Video modes.
@immutable
class ZameraPreferences {
  static const ZameraPreferences defaults = ZameraPreferences();
  static const Set<int> supportedVideoFpsValues = <int>{24, 25, 30, 60, 120};

  final PhotoCaptureFormat photoFormat;
  final PhotoColorSpace photoColorSpace;
  final bool fullSensorResolution;
  final bool embedExifAndIccProfile;

  final VideoContainerFormat videoContainer;
  final VideoResolutionPreset videoResolution;
  final int defaultVideoFps;
  final ZameraVideoProfile defaultVideoProfile;
  final VideoBitrateTier videoBitrate;
  final VideoAudioFormat videoAudioFormat;
  final bool lock180ShutterAngleByDefault;
  final bool videoOisEisStabilization;

  final bool showLiveHistogramByDefault;
  final bool showOverexposureZebra95;
  final bool showSkinToneZebra70;
  final bool showFocusPeakingByDefault;
  final bool showSpotColorMeterInArtMode;
  final bool applyFlatFieldShading;
  final bool radialHapticFeedback;
  final bool mirrorFrontCamera;

  const ZameraPreferences({
    this.photoFormat = PhotoCaptureFormat.rawPlusJpeg,
    this.photoColorSpace = PhotoColorSpace.sRgb,
    this.fullSensorResolution = true,
    this.embedExifAndIccProfile = true,
    this.videoContainer = VideoContainerFormat.mp4Hevc10Bit,
    this.videoResolution = VideoResolutionPreset.uhd4k,
    this.defaultVideoFps = 30,
    this.defaultVideoProfile = ZameraVideoProfile.universalRec709Locked,
    this.videoBitrate = VideoBitrateTier.broadcastHigh,
    this.videoAudioFormat = VideoAudioFormat.pcm24BitUncompressed,
    this.lock180ShutterAngleByDefault = true,
    this.videoOisEisStabilization = true,
    this.showLiveHistogramByDefault = false,
    this.showOverexposureZebra95 = true,
    this.showSkinToneZebra70 = false,
    this.showFocusPeakingByDefault = false,
    this.showSpotColorMeterInArtMode = true,
    this.applyFlatFieldShading = true,
    this.radialHapticFeedback = true,
    this.mirrorFrontCamera = true,
  });

  ZameraPreferences copyWith({
    PhotoCaptureFormat? photoFormat,
    PhotoColorSpace? photoColorSpace,
    bool? fullSensorResolution,
    bool? embedExifAndIccProfile,
    VideoContainerFormat? videoContainer,
    VideoResolutionPreset? videoResolution,
    int? defaultVideoFps,
    ZameraVideoProfile? defaultVideoProfile,
    VideoBitrateTier? videoBitrate,
    VideoAudioFormat? videoAudioFormat,
    bool? lock180ShutterAngleByDefault,
    bool? videoOisEisStabilization,
    bool? showLiveHistogramByDefault,
    bool? showOverexposureZebra95,
    bool? showSkinToneZebra70,
    bool? showFocusPeakingByDefault,
    bool? showSpotColorMeterInArtMode,
    bool? applyFlatFieldShading,
    bool? radialHapticFeedback,
    bool? mirrorFrontCamera,
  }) {
    return ZameraPreferences(
      photoFormat: photoFormat ?? this.photoFormat,
      photoColorSpace: photoColorSpace ?? this.photoColorSpace,
      fullSensorResolution: fullSensorResolution ?? this.fullSensorResolution,
      embedExifAndIccProfile:
          embedExifAndIccProfile ?? this.embedExifAndIccProfile,
      videoContainer: videoContainer ?? this.videoContainer,
      videoResolution: videoResolution ?? this.videoResolution,
      defaultVideoFps: defaultVideoFps ?? this.defaultVideoFps,
      defaultVideoProfile: defaultVideoProfile ?? this.defaultVideoProfile,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      videoAudioFormat: videoAudioFormat ?? this.videoAudioFormat,
      lock180ShutterAngleByDefault:
          lock180ShutterAngleByDefault ?? this.lock180ShutterAngleByDefault,
      videoOisEisStabilization:
          videoOisEisStabilization ?? this.videoOisEisStabilization,
      showLiveHistogramByDefault:
          showLiveHistogramByDefault ?? this.showLiveHistogramByDefault,
      showOverexposureZebra95:
          showOverexposureZebra95 ?? this.showOverexposureZebra95,
      showSkinToneZebra70: showSkinToneZebra70 ?? this.showSkinToneZebra70,
      showFocusPeakingByDefault:
          showFocusPeakingByDefault ?? this.showFocusPeakingByDefault,
      showSpotColorMeterInArtMode:
          showSpotColorMeterInArtMode ?? this.showSpotColorMeterInArtMode,
      applyFlatFieldShading:
          applyFlatFieldShading ?? this.applyFlatFieldShading,
      radialHapticFeedback: radialHapticFeedback ?? this.radialHapticFeedback,
      mirrorFrontCamera: mirrorFrontCamera ?? this.mirrorFrontCamera,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'photoFormat': photoFormat.name,
      'photoColorSpace': photoColorSpace.name,
      'fullSensorResolution': fullSensorResolution,
      'embedExifAndIccProfile': embedExifAndIccProfile,
      'videoContainer': videoContainer.name,
      'videoResolution': videoResolution.name,
      'defaultVideoFps': defaultVideoFps,
      'defaultVideoProfile': defaultVideoProfile.name,
      'videoBitrate': videoBitrate.name,
      'videoAudioFormat': videoAudioFormat.name,
      'lock180ShutterAngleByDefault': lock180ShutterAngleByDefault,
      'videoOisEisStabilization': videoOisEisStabilization,
      'showLiveHistogramByDefault': showLiveHistogramByDefault,
      'showOverexposureZebra95': showOverexposureZebra95,
      'showSkinToneZebra70': showSkinToneZebra70,
      'showFocusPeakingByDefault': showFocusPeakingByDefault,
      'showSpotColorMeterInArtMode': showSpotColorMeterInArtMode,
      'applyFlatFieldShading': applyFlatFieldShading,
      'radialHapticFeedback': radialHapticFeedback,
      'mirrorFrontCamera': mirrorFrontCamera,
    };
  }

  factory ZameraPreferences.fromJson(Map<Object?, Object?> json) {
    final parsedFps = _readInt(json, 'defaultVideoFps', 30);
    final sanitizedFps =
        supportedVideoFpsValues.contains(parsedFps) ? parsedFps : 30;

    return ZameraPreferences(
      photoFormat: PhotoCaptureFormat.fromName(json['photoFormat']),
      photoColorSpace: PhotoColorSpace.fromName(json['photoColorSpace']),
      fullSensorResolution: _readBool(json, 'fullSensorResolution', true),
      embedExifAndIccProfile: _readBool(json, 'embedExifAndIccProfile', true),
      videoContainer: VideoContainerFormat.fromName(json['videoContainer']),
      videoResolution: VideoResolutionPreset.fromName(json['videoResolution']),
      defaultVideoFps: sanitizedFps,
      defaultVideoProfile: _enumByName(
        ZameraVideoProfile.values,
        json['defaultVideoProfile'],
        ZameraVideoProfile.universalRec709Locked,
      ),
      videoBitrate: VideoBitrateTier.fromName(json['videoBitrate']),
      videoAudioFormat: VideoAudioFormat.fromName(json['videoAudioFormat']),
      lock180ShutterAngleByDefault:
          _readBool(json, 'lock180ShutterAngleByDefault', true),
      videoOisEisStabilization:
          _readBool(json, 'videoOisEisStabilization', true),
      showLiveHistogramByDefault:
          _readBool(json, 'showLiveHistogramByDefault', false),
      showOverexposureZebra95: _readBool(json, 'showOverexposureZebra95', true),
      showSkinToneZebra70: _readBool(json, 'showSkinToneZebra70', false),
      showFocusPeakingByDefault:
          _readBool(json, 'showFocusPeakingByDefault', false),
      showSpotColorMeterInArtMode:
          _readBool(json, 'showSpotColorMeterInArtMode', true),
      applyFlatFieldShading: _readBool(json, 'applyFlatFieldShading', true),
      radialHapticFeedback: _readBool(json, 'radialHapticFeedback', true),
      mirrorFrontCamera: _readBool(json, 'mirrorFrontCamera', true),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZameraPreferences &&
        other.photoFormat == photoFormat &&
        other.photoColorSpace == photoColorSpace &&
        other.fullSensorResolution == fullSensorResolution &&
        other.embedExifAndIccProfile == embedExifAndIccProfile &&
        other.videoContainer == videoContainer &&
        other.videoResolution == videoResolution &&
        other.defaultVideoFps == defaultVideoFps &&
        other.defaultVideoProfile == defaultVideoProfile &&
        other.videoBitrate == videoBitrate &&
        other.videoAudioFormat == videoAudioFormat &&
        other.lock180ShutterAngleByDefault == lock180ShutterAngleByDefault &&
        other.videoOisEisStabilization == videoOisEisStabilization &&
        other.showLiveHistogramByDefault == showLiveHistogramByDefault &&
        other.showOverexposureZebra95 == showOverexposureZebra95 &&
        other.showSkinToneZebra70 == showSkinToneZebra70 &&
        other.showFocusPeakingByDefault == showFocusPeakingByDefault &&
        other.showSpotColorMeterInArtMode == showSpotColorMeterInArtMode &&
        other.applyFlatFieldShading == applyFlatFieldShading &&
        other.radialHapticFeedback == radialHapticFeedback &&
        other.mirrorFrontCamera == mirrorFrontCamera;
  }

  @override
  int get hashCode => Object.hashAll(<Object>[
        photoFormat,
        photoColorSpace,
        fullSensorResolution,
        embedExifAndIccProfile,
        videoContainer,
        videoResolution,
        defaultVideoFps,
        defaultVideoProfile,
        videoBitrate,
        videoAudioFormat,
        lock180ShutterAngleByDefault,
        videoOisEisStabilization,
        showLiveHistogramByDefault,
        showOverexposureZebra95,
        showSkinToneZebra70,
        showFocusPeakingByDefault,
        showSpotColorMeterInArtMode,
        applyFlatFieldShading,
        radialHapticFeedback,
        mirrorFrontCamera,
      ]);
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String || raw.isEmpty) return fallback;
  return values.asNameMap()[raw] ?? fallback;
}

bool _readBool(Map<Object?, Object?> json, String key, bool fallback) {
  final value = json[key];
  return value is bool ? value : fallback;
}

int _readInt(Map<Object?, Object?> json, String key, int fallback) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value.isFinite) return value.toInt();
  return fallback;
}
