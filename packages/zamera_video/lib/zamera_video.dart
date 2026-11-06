library zamera_video;

/// Compile-time feature flag for the isolated Pro Video module (ADR-5 & ADR-6).
///
/// Controlled via `--dart-define=ZAMERA_VIDEO=true` (defaults to `false` until Phase 3).
/// Ensures zero coupling with `zamera_capture` (Sanat Modu & Pro Fotoğraf).
/// Can be extracted into a standalone "Zamera Cine" companion app in 1-2 weeks if needed.
const bool kZameraVideoEnabled = bool.fromEnvironment(
  'ZAMERA_VIDEO',
  defaultValue: false,
);

/// Supported professional video recording profiles across iOS and Android.
enum ZameraVideoProfile {
  /// iOS: Apple Log / Apple Log 2 + ProRes 422 HQ (External USB-C SSD required for 4K60/120)
  iosAppleLogProRes422Hq,

  /// iOS: Apple Log + HEVC 10-bit 4:2:2 / 4:2:0 internal recording
  iosAppleLogHevc10Bit,

  /// Android: Camera2 `DynamicRangeProfiles.HLG10` 10-bit BT.2020 HEVC with flat tone curve
  androidHlg10Hevc10Bit,

  /// Universal Rec.709 180-degree shutter locked cinema profile
  universalRec709Locked,
}

/// Isolated session contract for Pro Video recording.
/// Never shares an `AVCaptureSession` or `CameraCaptureSession` with `zamera_capture`.
class ZameraVideoIsolationInfo {
  final bool isEnabledByFlag;
  final String isolationPolicy;
  final List<ZameraVideoProfile> plannedProfiles;

  const ZameraVideoIsolationInfo({
    this.isEnabledByFlag = kZameraVideoEnabled,
    this.isolationPolicy =
        'Tam İzole Oturum (packages/zamera_video): Fotoğraf/Sanat oturumu kapatılmadan video oturumu açılmaz. '
            'Gerekirse tek komutla "Zamera Cine" yan uygulamasına ayrılabilir.',
    this.plannedProfiles = ZameraVideoProfile.values,
  });
}
