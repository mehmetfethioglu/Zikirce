import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zamera_capture/zamera_capture.dart';
import 'package:zamera_video/zamera_video.dart';
import '../constants/camera_colors.dart';
import '../models/active_pro_dial.dart';
import '../models/dslr_exposure_model.dart';
import '../models/radial_ring_models.dart';
import '../models/zamera_preferences.dart';
import '../services/color_calibration_store.dart';
import '../services/version_tracking_service.dart';
import '../services/zamera_settings_store.dart';
import '../dialogs/release_notes_dialog.dart';
import '../dialogs/settings_sheet.dart';
import '../dialogs/capture_inspector_modal.dart';
import '../dialogs/calibration_probe_sheet.dart';
import '../widgets/pro_dslr_hud_bar.dart';
import '../widgets/radial_shutter_feature_arc.dart';
import '../widgets/truecolor_spot_meter_badge.dart';
import '../widgets/video_cinema_hud.dart';
import '../painters/portrait_studio_painter.dart';
import '../painters/radial_guide_arc_painter.dart';
import '../painters/manual_focus_hud_painter.dart';
import '../painters/radial_wheel_painter.dart';
import '../painters/raw_histogram_painter.dart';
import '../painters/live_zebra_peaking_painter.dart';
import '../painters/viewfinder_grid_painter.dart';

class ZameraHomeScreen extends StatefulWidget {
  final VersionTrackingService? versionService;
  final ColorCalibrationStore calibrationStore;
  final ZameraSettingsRepository settingsStore;

  const ZameraHomeScreen({
    super.key,
    this.versionService,
    this.calibrationStore = const ColorCalibrationStore(),
    this.settingsStore = const SharedPrefsZameraSettingsStore(),
  });

  @override
  State<ZameraHomeScreen> createState() => _ZameraHomeScreenState();
}

class _ZameraHomeScreenState extends State<ZameraHomeScreen>
    with WidgetsBindingObserver {
  // 0 = SANAT, 1 = PRO, 2 = PORTRE, 3 = VİDEO
  int _selectedMode = 0;
  ActiveProDial _activeDial = ActiveProDial.none;
  bool _radialMenuOpen = false;
  double _shutterVerticalDragDy = 0.0;
  ZameraPreferences _userPrefs = const ZameraPreferences();

  // Continuous unquantized wheel position [0.0 .. 1.0] for 120 FPS butter-smooth radial sensitivity (Ring 0)
  double _continuousWheelNorm = 0.5;
  int _lastHapticTickIndex = -1;
  // Continuous scroll index [0 .. N-1] for the concentric 4mm middle secondary ring (Ring 1)
  double _secondaryArcScrollPos = 0.0;
  int _lastSecondaryHapticIndex = -1;
  // Continuous scroll index [0 .. M-1] for the outermost mode-feature ring (Ring 2)
  double _outerFeatureArcScrollPos = 0.0;
  int _lastOuterFeatureHapticIndex = -1;
  // Locked concentric ring band for the active gesture so Ring 0, Ring 1, and Ring 2 never cross-mutate
  RadialRingBand _activeDragRingBand = RadialRingBand.none;
  // Independent angular offsets for multi-tier radial button arcs when radial menu is open
  double _menuOuterArcOffsetRad = 0.0;
  double _menuInnerArcOffsetRad = 0.0;
  bool _draggingMenuOuterButtonArc = false;
  bool _topDrawerExpanded = false;
  bool _showLiveHistogram = false;

  // Coalesced Native Control Push State (prevents MethodChannel IPC from blocking 120Hz radial gestures)
  bool _isPushingControls = false;
  bool _pendingControlsPush = false;

  // Device Probe State
  ZameraProbeReport? _probeReport;
  bool _loadingProbe = true;

  // Live Camera Session & Telemetry State
  PreviewSessionInfo? _previewSession;
  String _selectedCameraId = '2';
  String? _statusBanner;
  CapturePhotoResult? _lastCaptureResult;
  bool _isCapturing = false;
  bool _isStartingCamera = false;
  Offset? _lastFocusTapNorm;
  Timer? _telemetryTimer;
  Map<String, dynamic> _liveTelemetry = const {};

  // Optical / Digital Zoom Factor displayed on the iOS Lens Radial Wheel (0.5x .. 10.0x)
  double _zoomFactor = 1.0;

  // Portrait Mode State (f/1.4 .. f/16 Aperture + 10 Studio, Monochrome & Gobo Effects + Live Bokeh Portal)
  double _portraitAperture = 2.8;
  int _portraitLightingIndex = 0;
  double _portraitLightIntensity = 0.80;
  double _portraitSubjectRadius = 0.34;
  static const List<String> _kPortraitLightingNames = [
    'DOĞAL IŞIK',
    'STÜDYO IŞIĞI',
    'KONTUR IŞIĞI',
    'SAHNE IŞIĞI',
    'SAHNE MONO',
    'YÜKSEK ANAHTAR MONO',
    'PANJUR GÖLGESİ',
    'PANJUR MONO',
    'ALTIN SAAT',
    'PRİZMA & SİNEMA',
  ];

  // Sanat Modu (TrueColor 1:1) State — V2
  final double _simulatedSensorWarmth = 1.45;
  bool _showPerspectiveGrid = false;
  bool _applyPerspectiveWarp = false;
  List<Offset> _perspectiveCorners = const [
    Offset(0.10, 0.14),
    Offset(0.90, 0.14),
    Offset(0.90, 0.84),
    Offset(0.10, 0.84),
  ];
  bool _flatFieldEnabled = true;
  bool _useDisplayP3 = false;
  bool _fullResolution = true;
  // 2 = 1:1 Doğal Ton (varsayılan), 1 = Kağıt L*94
  int _artworkExposureMode = 2;
  bool _showSpotMeter = true;
  bool _losslessPng = false;
  bool _useMeasuredGrayCardWb = false;
  List<double>? _measuredGrayCardWbGains;
  List<double>? _measuredFlatField8x6;
  late ColorCheckerCalibrationResult _calibrationResult;

  // Pro Fotoğraf State — Faz 2A & 2B + DSLR PASM & Drive
  DslrExposureMode _dslrMode = DslrExposureMode.programP;
  ProDriveMode _proDriveMode = ProDriveMode.single;
  int? _selfTimerRemainingSec;
  Timer? _selfTimerCountdown;
  bool _aeAfLocked = false;
  bool _manualExposure = false;
  double _evCompensation = 0.0;
  double _iso = 100.0;
  int _shutterExposureNs = 8000000; // 1/125 sec
  double _shutterDenominator = 125.0; // 1/125 sec
  bool _manualFocus = false;
  double _focusDistance = 0.5;
  bool _manualWb = false;
  double _kelvin = 5500.0;
  double _tint = 0.0;
  bool _preferProRaw48Mp = false;
  bool _showZebra = true;
  bool _showZebra70 = false;
  bool _showFalseColor = false;
  bool _showFocusPeaking = false;

  // Faz 3 Pro Video Sinema State & Ownership Coordinator (WP-3.0 .. WP-3.6)
  final CameraOwnershipCoordinator _ownershipCoordinator =
      CameraOwnershipCoordinator();
  int _videoResolutionHeight = 2160; // 2160 (4K UHD) or 1080 (FHD)
  int _videoFps = 30; // 24, 25, 30, 60 (WP-3.6 ideal default: 4K 30fps)
  double _videoShutterAngleDeg = 180.0; // 11.25° .. 360° (default 180° -> 1/60s @ 30fps)
  bool _videoLockShutterAngle = true;
  bool _videoStabilization = true;
  ZameraVideoProfile _videoProfile = ZameraVideoProfile.universalRec709Locked;
  ZameraLutPreset _videoLutPreset = ZameraLutPreset.rec709Monitor;
  bool _videoLutBypass = false;
  bool _videoFpsTrayOpen = false;
  bool _videoProfileTrayOpen = false;
  ZameraCubeLut3D? _customCubeLut;
  bool _isVideoRecording = false;
  ZameraVideoTelemetry? _videoTelemetry;
  ZameraVideoRecordingResult? _lastVideoResult;
  List<ZameraAudioInputDevice> _audioInputDevices = const [];
  String _selectedAudioDeviceId = 'default';
  double _focusPullPointA = 0.12; // ~1.5m
  double _focusPullPointB = 0.65; // ~30cm
  int _rackFocusDurationMs = 2000;
  bool _hasFocusPointA = false;
  bool _hasFocusPointB = false;
  bool _isPullingFocus = false;
  bool _focusPullAtB = false;
  Timer? _rackFocusResetTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vs = widget.versionService;
      if (vs != null) {
        if (vs.isFirstLaunch) {
          ReleaseNotesDialog.show(
            context,
            showFeatures: true,
            onDismissed: () => vs.markCurrentVersionSeen(),
          );
        } else if (vs.isVersionUpdate) {
          ReleaseNotesDialog.show(
            context,
            showFeatures: false,
            onDismissed: () => vs.markCurrentVersionSeen(),
          );
        }
      }
    });
    _applyIdealPresetForMode(0, pushToNative: false);
    _loadStoredPreferences();
    _recomputeCalibration();
    _loadStoredCalibrationForLens(_selectedCameraId);
    _runDeviceProbe();
    _telemetryTimer = Timer.periodic(
      const Duration(milliseconds: 350),
      (_) => _pollLiveTelemetry(),
    );
  }

  void _triggerRadialHaptic() {
    if (_userPrefs.radialHapticFeedback) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _loadStoredPreferences() async {
    try {
      final loaded = await widget.settingsStore.load();
      if (!mounted) return;
      _applyUserPreferences(loaded, persist: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusBanner = 'Ayarlar varsayılanla başlatıldı ($e)';
      });
    }
  }

  Future<void> _persistUserPreferences(ZameraPreferences nextPrefs) async {
    try {
      await widget.settingsStore.save(nextPrefs);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusBanner = 'Ayarlar kaydedilemedi: $e';
      });
    }
  }

  void _applyUserPreferences(
    ZameraPreferences nextPrefs, {
    bool persist = true,
  }) {
    final bool restartVideo = !_isVideoRecording &&
        _selectedMode == 3 &&
        (_videoResolutionHeight != nextPrefs.videoResolution.heightPx ||
            _videoFps != nextPrefs.defaultVideoFps ||
            _videoProfile != nextPrefs.defaultVideoProfile ||
            _videoStabilization != nextPrefs.videoOisEisStabilization);

    setState(() {
      _userPrefs = nextPrefs;
      _preferProRaw48Mp = nextPrefs.photoFormat.prefersProRaw48Mp;
      _losslessPng = nextPrefs.photoFormat.isLosslessPng;
      _useDisplayP3 = nextPrefs.photoColorSpace.usesDisplayP3;
      _fullResolution = nextPrefs.fullSensorResolution;
      _flatFieldEnabled = nextPrefs.applyFlatFieldShading;
      _showSpotMeter = nextPrefs.showSpotColorMeterInArtMode;
      _showLiveHistogram = nextPrefs.showLiveHistogramByDefault;
      if (_selectedMode == 1) {
        _showZebra = nextPrefs.showOverexposureZebra95;
        _showZebra70 = nextPrefs.showSkinToneZebra70;
        _showFocusPeaking = nextPrefs.showFocusPeakingByDefault;
      }
      _videoResolutionHeight = nextPrefs.videoResolution.heightPx;
      _videoFps = nextPrefs.defaultVideoFps;
      _videoProfile = nextPrefs.defaultVideoProfile;
      _videoLockShutterAngle = nextPrefs.lock180ShutterAngleByDefault;
      _videoStabilization = nextPrefs.videoOisEisStabilization;
    });

    if (persist) {
      _persistUserPreferences(nextPrefs);
    }
    if (restartVideo) {
      _startOrSwitchVideoCamera(_selectedCameraId, keepZoom: _zoomFactor);
    } else {
      _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
    }
  }

  /// Applies the optimal default parameters for each camera category when first entered.
  /// If the user opens the radial settings afterward, they can freely override any parameter.
  void _applyIdealPresetForMode(int modeIndex, {bool pushToNative = true}) {
    final previousMode = _selectedMode;
    _selectedMode = modeIndex;
    _radialMenuOpen = false;
    _activeDial = ActiveProDial.none;
    _activeDragRingBand = RadialRingBand.none;
    _outerFeatureArcScrollPos = 0.0;
    _lastOuterFeatureHapticIndex = -1;
    _menuOuterArcOffsetRad = 0.0;
    _menuInnerArcOffsetRad = 0.0;
    _selfTimerCountdown?.cancel();
    _selfTimerRemainingSec = null;
    _aeAfLocked = false;
    _videoFpsTrayOpen = false;
    _videoProfileTrayOpen = false;

    switch (modeIndex) {
      case 0: // SANAT — 12.6MP Full-Res TrueColor ΔE00, 1:1 Doğal Ton (mode 2), 8x6 Flat-Field, 1.0x Main Optical
        _zoomFactor = 1.0;
        _fullResolution = _userPrefs.fullSensorResolution;
        _flatFieldEnabled = _userPrefs.applyFlatFieldShading;
        _artworkExposureMode = 2;
        _showSpotMeter = _userPrefs.showSpotColorMeterInArtMode;
        _losslessPng = _userPrefs.photoFormat.isLosslessPng;
        _preferProRaw48Mp = _userPrefs.photoFormat.prefersProRaw48Mp;
        _useDisplayP3 = _userPrefs.photoColorSpace.usesDisplayP3;
        _showPerspectiveGrid = false;
        _applyPerspectiveWarp = false;
        _dslrMode = DslrExposureMode.programP;
        _manualExposure = false;
        _evCompensation = 0.0;
        _iso = 100.0;
        _shutterExposureNs = 8000000;
        _shutterDenominator = 125.0;
        _manualFocus = false;
        _focusDistance = 0.25;
        _manualWb = false;
        _kelvin = 5500.0;
        _tint = 0.0;
        _showZebra = false;
        _showZebra70 = false;
        _showFalseColor = false;
        _showFocusPeaking = _userPrefs.showFocusPeakingByDefault;
        break;
      case 1: // PRO — 14-Bit DNG + JPEG, DSLR PASM (P Baseline, ISO 100, 1/125s, 5500K) + Zebra
        _zoomFactor = 1.0;
        _fullResolution = _userPrefs.fullSensorResolution;
        _losslessPng = _userPrefs.photoFormat.isLosslessPng;
        _preferProRaw48Mp = _userPrefs.photoFormat.prefersProRaw48Mp;
        _useDisplayP3 = _userPrefs.photoColorSpace.usesDisplayP3;
        _dslrMode = DslrExposureMode.programP;
        _proDriveMode = ProDriveMode.single;
        _manualExposure = false;
        _evCompensation = 0.0;
        _iso = 100.0;
        _shutterExposureNs = 8000000;
        _shutterDenominator = 125.0;
        _manualFocus = false;
        _focusDistance = 0.25;
        _manualWb = false;
        _kelvin = 5500.0;
        _tint = 0.0;
        _showZebra = _userPrefs.showOverexposureZebra95;
        _showZebra70 = _userPrefs.showSkinToneZebra70;
        _showFalseColor = false;
        _showFocusPeaking = _userPrefs.showFocusPeakingByDefault;
        break;
      case 2: // PORTRE — 1.0x Optical, f/2.8 Natural iPhone Bokeh, Doğal Işık (80%), Auto Face/Subject Focus
        _zoomFactor = 1.0;
        _portraitAperture = 2.8;
        _portraitLightingIndex = 0;
        _portraitLightIntensity = 0.80;
        _portraitSubjectRadius = 0.34;
        _dslrMode = DslrExposureMode.programP;
        _manualExposure = false;
        _evCompensation = 0.0;
        _iso = 100.0;
        _shutterExposureNs = 8000000;
        _shutterDenominator = 125.0;
        _manualFocus = false;
        _focusDistance = 0.12;
        _manualWb = false;
        _kelvin = 5500.0;
        _tint = 0.0;
        _showZebra = false;
        _showZebra70 = false;
        _showFalseColor = false;
        _showFocusPeaking = false;
        break;
      case 3: // VİDEO — WP-3.6 İdeal Varsayılanlar: 4K 30fps, Rec.709 SDR, 180° (1/60s) + Auto-ISO, OIS+EIS açık
        _zoomFactor = _selectedCameraId == '3' ? 0.5 : 1.0;
        _videoResolutionHeight = _userPrefs.videoResolution.heightPx;
        _videoFps = _userPrefs.defaultVideoFps;
        _videoShutterAngleDeg = 180.0;
        _videoLockShutterAngle = _userPrefs.lock180ShutterAngleByDefault;
        _videoStabilization = _userPrefs.videoOisEisStabilization;
        _videoProfile = _userPrefs.defaultVideoProfile;
        _videoLutPreset = ZameraLutPreset.rec709Monitor;
        _videoLutBypass = false;
        _dslrMode = DslrExposureMode.programP;
        _manualExposure = false;
        _evCompensation = 0.0;
        _iso = 100.0;
        _shutterExposureNs = 16666667;
        _shutterDenominator = 60.0;
        _manualFocus = false;
        _focusDistance = 0.15;
        _manualWb = false;
        _kelvin = 5500.0;
        _tint = 0.0;
        _showZebra = true;
        _showZebra70 = true;
        _showFalseColor = false;
        _showFocusPeaking = false;
        break;
    }

    if (pushToNative) {
      if (modeIndex == 3) {
        _switchOwnershipToVideoSession(
          cameraId: _selectedCameraId,
          keepZoom: _zoomFactor,
        );
      } else if (previousMode == 3 ||
          _selectedCameraId == '3' ||
          _previewSession == null) {
        _switchOwnershipToPhotoSession(
          cameraId: '2',
          keepZoom: 1.0,
        );
      } else {
        _scheduleNativeControlsPush(artworkMode: modeIndex == 0);
      }
    }
  }

  Future<void> _switchOwnershipToVideoSession({
    required String cameraId,
    double? keepZoom,
  }) async {
    await _ownershipCoordinator.switchToVideo(
      stopPhotoSession: () async {
        await ZameraCapture.stopPreviewSession();
      },
      startVideoSession: () async {
        await _startOrSwitchVideoCamera(cameraId, keepZoom: keepZoom);
      },
    );
  }

  Future<void> _switchOwnershipToPhotoSession({
    required String cameraId,
    double? keepZoom,
  }) async {
    await _ownershipCoordinator.switchToPhoto(
      stopVideoAndFinalizeIfRecording: () async {
        if (_isVideoRecording) {
          final res = await ZameraVideo.stopVideoRecording();
          _isVideoRecording = false;
          if (res != null) _lastVideoResult = res;
        }
        await ZameraVideo.stopVideoSession();
      },
      startPhotoSession: () async {
        await _startOrSwitchCamera(cameraId, keepZoom: keepZoom);
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _telemetryTimer?.cancel();
    _selfTimerCountdown?.cancel();
    _rackFocusResetTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _previewSession == null &&
        !_isStartingCamera &&
        !_loadingProbe) {
      if (_selectedMode == 3) {
        _switchOwnershipToVideoSession(
          cameraId: _selectedCameraId,
          keepZoom: _zoomFactor,
        );
      } else {
        _switchOwnershipToPhotoSession(
          cameraId: _selectedCameraId,
          keepZoom: _zoomFactor,
        );
      }
    } else if (state == AppLifecycleState.paused) {
      _ownershipCoordinator.releaseAllOnBackground(
        stopVideoAndFinalizeIfRecording: () async {
          if (_isVideoRecording) {
            final res = await ZameraVideo.stopVideoRecording();
            if (mounted) {
              setState(() {
                _isVideoRecording = false;
                if (res != null) _lastVideoResult = res;
                _statusBanner = 'Arka plana geçildi: Video güvenle kapatıldı';
              });
            }
          }
          await ZameraVideo.stopVideoSession();
        },
        stopPhotoSession: () => ZameraCapture.stopPreviewSession(),
      );
      if (mounted) {
        setState(() => _previewSession = null);
      }
    }
  }

  ColorCheckerCalibrationResult _computeFactoryReferenceCalibration() {
    final measured = ZameraCapture.simulateUncalibratedSensor24(
      redShift: _simulatedSensorWarmth,
      greenShift: 1.18,
      blueShift: 0.82,
    );
    return ZameraCapture.calibrateColorChecker24(measured);
  }

  void _recomputeCalibration() {
    _calibrationResult = _computeFactoryReferenceCalibration();
  }

  Future<void> _loadStoredCalibrationForLens(String cameraId) async {
    final stored = await widget.calibrationStore.loadForLens(cameraId);
    if (!mounted || cameraId != _selectedCameraId) return;
    setState(() {
      _calibrationResult =
          stored.calibrationResult ?? _computeFactoryReferenceCalibration();
      _measuredGrayCardWbGains = stored.grayCardWbGains;
      _useMeasuredGrayCardWb = stored.useGrayCardWb && stored.hasGrayCardWb;
      _measuredFlatField8x6 = stored.flatField8x6;
    });
    _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
  }

  Future<void> _resetCalibrationForActiveLens() async {
    final lensId = _selectedCameraId;
    await widget.calibrationStore.resetForLens(lensId);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _calibrationResult = _computeFactoryReferenceCalibration();
      _measuredGrayCardWbGains = null;
      _useMeasuredGrayCardWb = false;
      _measuredFlatField8x6 = null;
      _statusBanner =
          'Lens #$lensId kalibrasyonu fabrika referansına sıfırlandı';
    });
    _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
  }

  Future<void> _pollLiveTelemetry() async {
    if (!mounted || _previewSession == null || _isCapturing) return;
    try {
      if (_selectedMode == 3) {
        final vidTel = await ZameraVideo.getVideoTelemetry();
        if (!mounted) return;
        bool steppedDownFps = false;
        setState(() {
          _videoTelemetry = vidTel;
          if (vidTel.thermalLevel == ZameraThermalLevel.severe ||
              vidTel.thermalLevel == ZameraThermalLevel.critical) {
            _showFocusPeaking = false;
            _videoLutPreset = ZameraLutPreset.none;
            if (_videoFps > 30) {
              _videoFps = 30;
              steppedDownFps = true;
            }
          }
          if (_isVideoRecording && !vidTel.isRecording) {
            _isVideoRecording = false;
            _statusBanner =
                'Kayıt otomatik sonlandırıldı ve DCIM/Zamera\'ya kaydedildi (${vidTel.thermalLevel.badgeText})';
          }
        });
        if (steppedDownFps) {
          _scheduleNativeControlsPush(artworkMode: false);
        }
        return;
      }

      final tel = await ZameraCapture.getLiveTelemetry();
      if (!mounted || tel.isEmpty) return;
      final rawFace = tel['detectedFaceBox'];
      Offset? trackedFaceCenter;
      double? trackedFaceRadius;
      if (rawFace is List && rawFace.length >= 4) {
        final fx = (rawFace[0] as num).toDouble().clamp(0.12, 0.88);
        final fy = (rawFace[1] as num).toDouble().clamp(0.15, 0.78);
        final fw = (rawFace[2] as num).toDouble().clamp(0.12, 0.65);
        final fh = (rawFace[3] as num).toDouble().clamp(0.12, 0.65);
        trackedFaceCenter = Offset(fx, fy);
        trackedFaceRadius = (math.max(fw, fh) * 0.95).clamp(0.24, 0.48);
      }
      setState(() {
        _liveTelemetry = tel;
        if (trackedFaceCenter != null && _selectedMode == 2) {
          _lastFocusTapNorm = trackedFaceCenter;
          if (trackedFaceRadius != null) {
            _portraitSubjectRadius = trackedFaceRadius;
          }
        }
      });
    } catch (e) {
      _liveTelemetry = <String, dynamic>{
        ..._liveTelemetry,
        'telemetryWarning': e.toString(),
      };
    }
  }

  CameraUnitCapability? get _activeCameraCap {
    final report = _probeReport;
    if (report == null) return null;
    for (final cam in report.cameras) {
      if (cam.cameraId == _selectedCameraId) return cam;
    }
    return null;
  }

  double get _isoMin {
    final range = _activeCameraCap?.isoRange;
    return (range != null && range.length >= 2) ? range[0].toDouble() : 50.0;
  }

  double get _isoMax {
    final range = _activeCameraCap?.isoRange;
    return (range != null && range.length >= 2) ? range[1].toDouble() : 6400.0;
  }

  int get _shutterMinNs {
    final range = _activeCameraCap?.exposureTimeRangeNs;
    if (range != null && range.length >= 2 && range[0] > 0) {
      return range[0].clamp(25000, 1000000);
    }
    return 125000; // 1/8000s
  }

  int get _shutterMaxNs {
    final range = _activeCameraCap?.exposureTimeRangeNs;
    if (range != null && range.length >= 2 && range[1] > _shutterMinNs) {
      return range[1].clamp(50000000, 30000000000);
    }
    return 30000000000; // 30"
  }

  List<ZameraVideoProfile> get _availableVideoProfiles =>
      ZameraVideoProfile.supportedForPlatform(isIOS: Platform.isIOS);

  List<CinemaProfileOption> get _cinemaProfileOptions => [
        for (final p in _availableVideoProfiles)
          CinemaProfileOption(
            id: p.name,
            shortLabel: p.shortLabel,
            isTenBit: p.isTenBit,
          ),
      ];

  String? get _telephotoCameraId {
    final report = _probeReport;
    if (report == null) return null;
    for (final cam in report.cameras) {
      if (cam.facing == 'BACK' &&
          cam.cameraId != '2' &&
          cam.cameraId != '3' &&
          ((cam.focalLengthsMm.isNotEmpty && cam.focalLengthsMm.first >= 7.8) ||
              cam.cameraId.toLowerCase().contains('tele'))) {
        return cam.cameraId;
      }
    }
    return null;
  }

  List<CinemaLensOption> get _cinemaLensOptions {
    final teleId = _telephotoCameraId;
    return <CinemaLensOption>[
      const CinemaLensOption(id: '0.5', label: '0.5×'),
      const CinemaLensOption(id: '1.0', label: '1×'),
      const CinemaLensOption(id: '2.0', label: '2×'),
      if (teleId != null) const CinemaLensOption(id: '3.0', label: '3× TELE'),
    ];
  }

  String get _activeCinemaLensOptionId {
    if (_zoomFactor < 0.95) return '0.5';
    if (_zoomFactor >= 2.7 && _telephotoCameraId != null) return '3.0';
    if (_zoomFactor >= 1.8) return '2.0';
    return '1.0';
  }

  void _applyBumplessTransferFromLiveTelemetry() {
    final liveIsoNum = (_selectedMode == 3
            ? _videoTelemetry?.activeIso
            : (_liveTelemetry['iso'] as num?)) ??
        _lastCaptureResult?.iso;
    final liveExpNs = (_selectedMode == 3
            ? _videoTelemetry?.shutterExposureNs
            : (_liveTelemetry['exposureTimeNs'] as num?)?.toInt()) ??
        _lastCaptureResult?.exposureTimeNs;
    final snapped = DslrStopsRegistry.bumplessTransfer(
      liveIso: liveIsoNum,
      liveShutterNs: liveExpNs,
      minIso: _isoMin.round(),
      maxIso: _isoMax.round(),
      minNs: _shutterMinNs,
      maxNs: _shutterMaxNs,
    );
    if (!_dslrMode.isIsoManual) {
      _iso = snapped.iso.toDouble();
    }
    if (!_dslrMode.isShutterManual) {
      _shutterExposureNs = snapped.shutterNs;
      _shutterDenominator = (1e9 / _shutterExposureNs).clamp(0.033, 8000.0);
    }
  }

  void _setDslrExposureMode(DslrExposureMode nextMode) {
    if (_dslrMode == nextMode) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (nextMode != DslrExposureMode.programP) {
        _applyBumplessTransferFromLiveTelemetry();
      }
      _dslrMode = nextMode;
      _manualExposure = nextMode != DslrExposureMode.programP;
      if (_activeDial == ActiveProDial.iso ||
          _activeDial == ActiveProDial.shutter) {
        _continuousWheelNorm = _normalizedValueForDial(_activeDial);
      }
      _statusBanner = '${nextMode.shortLabel} · ${nextMode.badgeLabelTr}';
    });
    _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
  }

  void _toggleAeAfLock() {
    HapticFeedback.mediumImpact();
    setState(() {
      _aeAfLocked = !_aeAfLocked;
      _statusBanner =
          _aeAfLocked ? 'AE/AF KİLİTLİ (AEL/AFL)' : 'AE/AF KİLİDİ AÇILDI';
    });
    final pt = _lastFocusTapNorm ?? const Offset(0.5, 0.44);
    if (_selectedMode == 3) {
      ZameraVideo.setVideoFocusAndMeteringPoint(
        x: pt.dx,
        y: pt.dy,
        lockAeAf: _aeAfLocked,
      );
    } else if (_previewSession != null) {
      ZameraCapture.setFocusAndMeteringPoint(
        x: pt.dx,
        y: pt.dy,
        lockAeAf: _aeAfLocked,
      );
    }
    _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
  }

  /// Computes the hardware zoom ratio for the currently active physical lens:
  /// - When on Ultra-Wide (#3, 0.5x base), 0.5x..0.99x maps to 1.0x..1.98x crop on #3
  /// - When on Main (#2, 1.0x base), 1.0x..10.0x maps directly to 1.0x..10.0x on #2
  double get _effectiveHardwareZoomRatio {
    if (_selectedCameraId == '3') {
      return (_zoomFactor / 0.5).clamp(1.0, 2.0);
    }
    return _zoomFactor.clamp(1.0, 10.0);
  }

  Future<void> _runDeviceProbe() async {
    setState(() {
      _loadingProbe = true;
    });
    try {
      final report = await ZameraCapture.probeDeviceCapabilities();
      if (!mounted) return;
      final preferredId = report.cameraIdList.contains('2')
          ? '2'
          : (report.cameraIdList.isNotEmpty ? report.cameraIdList.first : '0');
      setState(() {
        _probeReport = report;
        _selectedCameraId = preferredId;
        _zoomFactor = preferredId == '3' ? 0.5 : 1.0;
        _loadingProbe = false;
      });
      await _startOrSwitchCamera(preferredId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusBanner = 'Donanım tarama: $e';
        _loadingProbe = false;
      });
    }
  }

  Future<void> _startOrSwitchCamera(String cameraId, {double? keepZoom}) async {
    if (_selectedMode == 3) {
      await _startOrSwitchVideoCamera(cameraId, keepZoom: keepZoom);
      return;
    }
    if (_isStartingCamera) return;
    _isStartingCamera = true;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCameraId = cameraId;
      _zoomFactor = keepZoom ?? (cameraId == '3' ? 0.5 : 1.0);
      if (_activeDial == ActiveProDial.lens) {
        _continuousWheelNorm = _normalizedValueForDial(ActiveProDial.lens);
      }
      _lastFocusTapNorm = null;
      _statusBanner = null;
    });
    try {
      final info = await ZameraCapture.startPreviewSession(cameraId: cameraId);
      if (!mounted) return;
      final cap = _activeCameraCap;
      if (cap != null && !cap.supportsVariableFocus && _manualFocus) {
        _manualFocus = false;
        if (_activeDial == ActiveProDial.focus) {
          _activeDial = ActiveProDial.none;
        }
      }
      final isoRange = cap?.isoRange;
      if (isoRange != null && isoRange.length >= 2) {
        _iso = _iso.clamp(isoRange[0].toDouble(), isoRange[1].toDouble());
      }
      setState(() {
        _previewSession = info;
        _statusBanner = null;
      });
      await _loadStoredCalibrationForLens(cameraId);
      _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
      await _pollLiveTelemetry();
    } catch (e) {
      if (!mounted) return;
      if (_previewSession == null) {
        setState(() {
          _statusBanner = 'Kamera başlatılamadı: $e';
        });
      }
    } finally {
      _isStartingCamera = false;
    }
  }

  Future<void> _startOrSwitchVideoCamera(
    String cameraId, {
    double? keepZoom,
  }) async {
    if (_isStartingCamera || _isVideoRecording) return;
    _isStartingCamera = true;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCameraId = cameraId;
      _zoomFactor = keepZoom ?? (cameraId == '3' ? 0.5 : 1.0);
      if (_activeDial == ActiveProDial.lens) {
        _continuousWheelNorm = _normalizedValueForDial(ActiveProDial.lens);
      }
      _lastFocusTapNorm = null;
      _statusBanner = null;
    });
    try {
      final resWidth = _videoResolutionHeight >= 2160 ? 3840 : 1920;
      final resHeight = _videoResolutionHeight >= 2160 ? 2160 : 1080;
      final map = await ZameraVideo.startVideoSession(
        cameraId: cameraId,
        width: resWidth,
        height: resHeight,
        fps: _videoFps,
        shutterAngleDeg: _videoShutterAngleDeg,
        profile: _videoProfile,
        videoStabilization: _videoStabilization,
      );
      final devices = await ZameraVideo.listAudioInputDevices();
      if (!mounted) return;
      setState(() {
        _previewSession = PreviewSessionInfo.fromMap(map);
        _audioInputDevices = devices;
        if (_selectedAudioDeviceId == 'default' && devices.isNotEmpty) {
          _selectedAudioDeviceId = devices.first.id;
        }
        _statusBanner = null;
      });
      _scheduleNativeControlsPush(artworkMode: false);
      await _pollLiveTelemetry();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusBanner = 'Video oturumu başlatılamadı: $e';
      });
    } finally {
      _isStartingCamera = false;
    }
  }

  void _scheduleNativeControlsPush({required bool artworkMode}) {
    if (_previewSession == null) return;
    if (_isPushingControls) {
      _pendingControlsPush = true;
      return;
    }
    if (_selectedMode == 3) {
      _pushVideoControlsToNative();
    } else {
      _pushManualControlsToNative(artworkMode: artworkMode);
    }
  }

  Future<void> _pushVideoControlsToNative() async {
    if (_previewSession == null) return;
    _isPushingControls = true;
    final supportsFocus = _activeCameraCap?.supportsVariableFocus ?? true;
    final videoManualIso = _dslrMode.isIsoManual || _manualExposure;
    try {
      await ZameraVideo.updateVideoControls(
        fps: _videoFps,
        shutterAngleDeg: _videoShutterAngleDeg,
        lockShutterAngle: _videoLockShutterAngle,
        manualIso: videoManualIso,
        iso: _iso,
        evCompensation: !videoManualIso ? _evCompensation : 0.0,
        manualWb: _manualWb,
        kelvin: _kelvin,
        tint: _tint,
        manualFocus: supportsFocus && _manualFocus,
        focusDistance: _focusDistance,
        zoomRatio: _effectiveHardwareZoomRatio,
        profile: _videoProfile,
        aeAfLocked: _aeAfLocked,
      );
    } catch (e) {
      if (mounted) {
        _liveTelemetry = <String, dynamic>{
          ..._liveTelemetry,
          'videoControlWarning': e.toString(),
        };
      }
    } finally {
      _isPushingControls = false;
      if (_pendingControlsPush && mounted) {
        _pendingControlsPush = false;
        _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
      }
    }
  }

  Future<void> _toggleVideoRecording() async {
    if (_isCapturing) return;
    HapticFeedback.heavyImpact();
    if (_isVideoRecording) {
      setState(() {
        _isCapturing = true;
        _statusBanner =
            'Video dosyası kapatılıyor ve DCIM/Zamera\'ya aktarılıyor...';
      });
      try {
        final res = await ZameraVideo.stopVideoRecording();
        if (!mounted) return;
        setState(() {
          _isVideoRecording = false;
          _isCapturing = false;
          if (res != null) {
            _lastVideoResult = res;
            final secStr = (res.durationMs / 1000.0).toStringAsFixed(1);
            final mbStr =
                (res.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
            _statusBanner =
                'Video Kaydedildi: ${res.width}×${res.height} ${res.fps}fps · ${res.colorStandard} (${secStr}sn · ${mbStr}MB)';
          } else {
            _statusBanner = 'Video Kaydedildi';
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isVideoRecording = false;
          _isCapturing = false;
          _statusBanner = 'Video durdurma hatası: $e';
        });
      }
    } else {
      setState(() {
        _isCapturing = true;
        _statusBanner =
            '${_videoResolutionHeight >= 2160 ? "4K" : "1080P"} ${_videoFps}fps · ${_videoProfile.shortLabel} kayıt başlatılıyor...';
      });
      try {
        final map = await ZameraVideo.startVideoRecording(
          audioDeviceId:
              _selectedAudioDeviceId != 'default' ? _selectedAudioDeviceId : null,
        );
        if (!mounted) return;
        final ok = map['started'] == true;
        final shutterStr = ZameraCinemaMath.formatShutterFromAngle(
          _videoShutterAngleDeg,
          _videoFps,
        );
        setState(() {
          _isCapturing = false;
          _isVideoRecording = ok;
          _statusBanner = ok
              ? 'REC · ${_videoResolutionHeight >= 2160 ? "4K" : "1080P"} ${_videoFps}FPS · ${_videoShutterAngleDeg.round()}° ($shutterStr)'
              : 'Video kaydı başlatılamadı';
        });
        await _pollLiveTelemetry();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isCapturing = false;
          _isVideoRecording = false;
          _statusBanner = 'Video kayıt hatası: $e';
        });
      }
    }
  }

  Future<void> _triggerVideoFocusPull() async {
    HapticFeedback.mediumImpact();
    final fromNorm = _focusPullAtB ? _focusPullPointB : _focusPullPointA;
    final toNorm = _focusPullAtB ? _focusPullPointA : _focusPullPointB;
    final durSec = _rackFocusDurationMs / 1000.0;
    setState(() {
      _manualFocus = true;
      _isPullingFocus = true;
      _focusPullAtB = !_focusPullAtB;
      _focusDistance = toNorm;
      _statusBanner =
          'A↔B Sinema Odak Geçişi (${durSec.toStringAsFixed(1)}sn)...';
    });
    try {
      await ZameraVideo.triggerFocusPull(
        fromFocusNorm: fromNorm,
        toFocusNorm: toNorm,
        durationMs: _rackFocusDurationMs,
      );
      _rackFocusResetTimer?.cancel();
      _rackFocusResetTimer = Timer(
        Duration(milliseconds: _rackFocusDurationMs),
        () {
          if (mounted) {
            setState(() => _isPullingFocus = false);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPullingFocus = false;
          _statusBanner = 'Odak geçişi uyarısı: $e';
        });
      }
    }
  }

  Future<void> _loadCustomCubeLutSample() async {
    HapticFeedback.selectionClick();
    try {
      final picked = await ZameraVideo.pickCubeLutFile();
      final String cubeContent;
      if (picked != null &&
          picked['content'] is String &&
          (picked['content'] as String).trim().isNotEmpty) {
        cubeContent = picked['content'] as String;
      } else {
        final sb = StringBuffer()
          ..writeln('TITLE "ZAMERA_TEAL_AMBER_17"')
          ..writeln('LUT_3D_SIZE 17')
          ..writeln('DOMAIN_MIN 0.0 0.0 0.0')
          ..writeln('DOMAIN_MAX 1.0 1.0 1.0');
        for (int b = 0; b < 17; b++) {
          final fb = b / 16.0;
          for (int g = 0; g < 17; g++) {
            final fg = g / 16.0;
            for (int r = 0; r < 17; r++) {
              final fr = r / 16.0;
              final luma = 0.2126 * fr + 0.7152 * fg + 0.0722 * fb;
              final or = (fr * 1.06 + luma * 0.03).clamp(0.0, 1.0);
              final og = (fg * 1.01).clamp(0.0, 1.0);
              final ob = (fb * 0.94 + (1.0 - luma) * 0.05).clamp(0.0, 1.0);
              sb.writeln(
                '${or.toStringAsFixed(5)} ${og.toStringAsFixed(5)} ${ob.toStringAsFixed(5)}',
              );
            }
          }
        }
        cubeContent = sb.toString();
      }
      final parsed = ZameraCubeLut3D.parse(cubeContent);
      if (!mounted) return;
      setState(() {
        _customCubeLut = parsed;
        _videoLutPreset = ZameraLutPreset.customCube;
        _statusBanner =
            'Özel 3D LUT Yüklendi: ${parsed.title} (${parsed.size}³ Trilinear)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusBanner = '.cube LUT ayrıştırma hatası: $e';
      });
    }
  }

  List<double>? _resolveActiveWbGains({required bool isArtworkMode}) {
    if (isArtworkMode &&
        _useMeasuredGrayCardWb &&
        _measuredGrayCardWbGains != null &&
        _measuredGrayCardWbGains!.length >= 3) {
      return _measuredGrayCardWbGains;
    }
    if (_manualWb) {
      final rggb = ZameraCapture.kelvinAndTintToRggbGains(_kelvin, _tint);
      return <double>[rggb[0], rggb[1], rggb[3]];
    }
    if (isArtworkMode &&
        _calibrationResult.isMeasuredFromSensor &&
        _calibrationResult.wbGains.length >= 3) {
      return _calibrationResult.wbGains;
    }
    return null;
  }

  List<double>? _resolveActiveCamToXyzD50({required bool isArtworkMode}) {
    if (isArtworkMode && _calibrationResult.isMeasuredFromSensor) {
      return _calibrationResult.flattenedCamToXyzD50;
    }
    return null;
  }

  String get _activeArtworkWbBadgeLabel {
    if (_useMeasuredGrayCardWb && _measuredGrayCardWbGains != null) {
      return 'GRİ KART';
    }
    if (_manualWb) {
      return '${_kelvin.round()}K';
    }
    if (_calibrationResult.isMeasuredFromSensor) {
      return 'CC24 WB';
    }
    return 'DNG';
  }

  Future<void> _pushManualControlsToNative({required bool artworkMode}) async {
    if (_previewSession == null) return;
    _isPushingControls = true;
    final isIsoManual = _selectedMode == 1
        ? _dslrMode.isIsoManual
        : _manualExposure;
    final isShutterManual = _selectedMode == 1
        ? _dslrMode.isShutterManual
        : _manualExposure;
    final anyManualExp = isIsoManual || isShutterManual;
    final exposureNs = _selectedMode == 1
        ? _shutterExposureNs
        : (1e9 / _shutterDenominator).round();
    final activeCustomWb = _resolveActiveWbGains(isArtworkMode: artworkMode);
    final activeCamMatrix = _resolveActiveCamToXyzD50(
      isArtworkMode: artworkMode,
    );
    final gains = (activeCustomWb != null && activeCustomWb.length >= 3)
        ? <double>[
            activeCustomWb[0],
            activeCustomWb[1],
            activeCustomWb[1],
            activeCustomWb[2],
          ]
        : ZameraCapture.kelvinAndTintToRggbGains(_kelvin, _tint);
    final supportsFocus = _activeCameraCap?.supportsVariableFocus ?? true;
    try {
      await ZameraCapture.updateManualControls(
        manualExposure: anyManualExp,
        manualIso: isIsoManual,
        manualShutter: isShutterManual,
        aeAfLocked: _aeAfLocked,
        iso: _iso,
        exposureTimeNs: exposureNs,
        evCompensation: !(isIsoManual && isShutterManual) ? _evCompensation : 0.0,
        manualFocus: supportsFocus && _manualFocus,
        focusDistance: _focusDistance,
        manualWb: _manualWb || activeCustomWb != null,
        kelvin: _kelvin,
        tint: _tint,
        rggbGains: gains,
        customWbGains: activeCustomWb,
        camToXyzD50: activeCamMatrix,
        artworkLinearMode: artworkMode,
        zoomRatio: _effectiveHardwareZoomRatio,
        monoMode: _selectedMode == 2 &&
            (_portraitLightingIndex == 4 ||
                _portraitLightingIndex == 5 ||
                _portraitLightingIndex == 7),
      );
    } catch (e) {
      if (mounted) {
        _liveTelemetry = <String, dynamic>{
          ..._liveTelemetry,
          'photoControlWarning': e.toString(),
        };
      }
    } finally {
      _isPushingControls = false;
      if (_pendingControlsPush && mounted) {
        _pendingControlsPush = false;
        _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
      }
    }
  }

  void _resetAllProControlsToAuto() {
    HapticFeedback.mediumImpact();
    setState(() {
      _dslrMode = DslrExposureMode.programP;
      _aeAfLocked = false;
      _manualExposure = false;
      _evCompensation = 0.0;
      _manualFocus = false;
      _manualWb = false;
      _tint = 0.0;
      if (_selectedMode == 0 && _useMeasuredGrayCardWb) {
        _useMeasuredGrayCardWb = false;
        widget.calibrationStore.saveGrayCardWb(
          _selectedCameraId,
          wbGains: _measuredGrayCardWbGains,
          enabled: false,
        );
      }
      _continuousWheelNorm = _normalizedValueForDial(_activeDial);
      _statusBanner = 'AUTO (P · AE/AF/AWB)';
    });
    _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
  }

  Future<void> _onViewfinderTapUp(
    TapUpDetails details,
    BoxConstraints constraints,
  ) async {
    if (_topDrawerExpanded || _videoFpsTrayOpen || _videoProfileTrayOpen) {
      setState(() {
        _topDrawerExpanded = false;
        _videoFpsTrayOpen = false;
        _videoProfileTrayOpen = false;
      });
      return;
    }
    if ((_activeDial != ActiveProDial.none || _radialMenuOpen) &&
        details.localPosition.dy < constraints.maxHeight - 250) {
      HapticFeedback.lightImpact();
      setState(() {
        _activeDial = ActiveProDial.none;
        _radialMenuOpen = false;
      });
      return;
    }

    if (_previewSession == null) return;
    final normX =
        (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final normY =
        (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);
    HapticFeedback.lightImpact();
    setState(() {
      _lastFocusTapNorm = Offset(normX, normY);
      if (_aeAfLocked) {
        _aeAfLocked = false;
      }
    });
    try {
      if (_selectedMode == 3) {
        await ZameraVideo.setVideoFocusAndMeteringPoint(
          x: normX,
          y: normY,
          lockAeAf: false,
        );
      } else {
        await ZameraCapture.setFocusAndMeteringPoint(
          x: normX,
          y: normY,
          lockAeAf: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _liveTelemetry['focusTapWarning'] = e.toString();
      }
    }
  }

  Future<void> _onViewfinderLongPressStart(
    LongPressStartDetails details,
    BoxConstraints constraints,
  ) async {
    if (_previewSession == null) return;
    final normX =
        (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final normY =
        (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);
    HapticFeedback.heavyImpact();
    setState(() {
      _lastFocusTapNorm = Offset(normX, normY);
      _aeAfLocked = true;
      _statusBanner = 'AE/AF KİLİTLİ (Dokunarak açın)';
    });
    try {
      if (_selectedMode == 3) {
        await ZameraVideo.setVideoFocusAndMeteringPoint(
          x: normX,
          y: normY,
          lockAeAf: true,
        );
      } else {
        await ZameraCapture.setFocusAndMeteringPoint(
          x: normX,
          y: normY,
          lockAeAf: true,
        );
      }
      _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
    } catch (e) {
      if (mounted) {
        _liveTelemetry['focusTapWarning'] = e.toString();
      }
    }
  }

  Future<void> _triggerProCaptureWithDriveMode({
    required bool isArtworkMode,
    required bool isPortraitMode,
  }) async {
    if (_selfTimerRemainingSec != null) {
      _selfTimerCountdown?.cancel();
      HapticFeedback.selectionClick();
      setState(() {
        _selfTimerRemainingSec = null;
        _statusBanner = 'Zamanlayıcı iptal edildi';
      });
      return;
    }

    if (_selectedMode == 1 && _proDriveMode == ProDriveMode.aeb3) {
      await _triggerBracketedCapture();
      return;
    }

    final timerSec = _selectedMode == 1 ? _proDriveMode.timerSeconds : 0;
    if (timerSec > 0) {
      HapticFeedback.mediumImpact();
      setState(() {
        _selfTimerRemainingSec = timerSec;
        _statusBanner = 'Zamanlayıcı: ${timerSec}sn...';
      });
      _selfTimerCountdown?.cancel();
      _selfTimerCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final next = (_selfTimerRemainingSec ?? 1) - 1;
        if (next <= 0) {
          timer.cancel();
          setState(() {
            _selfTimerRemainingSec = null;
          });
          _triggerPhotoCapture(
            isArtworkMode: isArtworkMode,
            isPortraitMode: isPortraitMode,
          );
        } else {
          HapticFeedback.selectionClick();
          setState(() {
            _selfTimerRemainingSec = next;
            _statusBanner = 'Zamanlayıcı: ${next}sn...';
          });
        }
      });
      return;
    }

    await _triggerPhotoCapture(
      isArtworkMode: isArtworkMode,
      isPortraitMode: isPortraitMode,
    );
  }

  Future<void> _triggerPhotoCapture({
    required bool isArtworkMode,
    bool isPortraitMode = false,
    bool lockGrayCardFromCenter = false,
    bool calibrateColorChecker = false,
  }) async {
    if (_isCapturing) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isCapturing = true;
      _statusBanner = isPortraitMode
          ? 'Portre f/${_portraitAperture.toStringAsFixed(1)} · ${_kPortraitLightingNames[_portraitLightingIndex]} işleniyor...'
          : (calibrateColorChecker
              ? '24-Yama ColorChecker sensörden ölçülüyor...'
              : (lockGrayCardFromCenter
                  ? '%18 Gri Kart WB ve 8×6 Flat-Field ölçülüyor...'
                  : (isArtworkMode
                      ? '14-Bit RAW 1:1 TrueColor işleniyor...'
                      : 'Pro DNG + JPEG çekiliyor...')));
    });
    try {
      final cornersFlat = <double>[
        for (final pt in _perspectiveCorners) ...[pt.dx, pt.dy],
      ];
      final effectiveExposureMode = isArtworkMode ? _artworkExposureMode : 2;
      final activeWbGains = lockGrayCardFromCenter
          ? null
          : _resolveActiveWbGains(isArtworkMode: isArtworkMode);
      final activeCamMatrix = calibrateColorChecker
          ? null
          : _resolveActiveCamToXyzD50(isArtworkMode: isArtworkMode);

      final res = await ZameraCapture.capturePhoto(
        captureRaw: isPortraitMode
            ? false
            : (isArtworkMode ? true : _userPrefs.photoFormat.capturesRaw),
        isArtworkMode: isArtworkMode,
        isPortraitMode: isPortraitMode,
        portraitAperture: _portraitAperture,
        portraitLighting: _portraitLightingIndex,
        portraitLightIntensity: _portraitLightIntensity,
        portraitSubjectRadius: _portraitSubjectRadius,
        focusPointX: _lastFocusTapNorm?.dx ?? 0.5,
        focusPointY: _lastFocusTapNorm?.dy ?? 0.44,
        zoomRatio: _effectiveHardwareZoomRatio,
        preferProRaw: !isArtworkMode &&
            (_preferProRaw48Mp || _userPrefs.photoFormat.prefersProRaw48Mp),
        useDisplayP3: _useDisplayP3,
        fullResolution: _fullResolution,
        normalizeExposure: isArtworkMode && effectiveExposureMode == 1,
        artworkExposureMode: effectiveExposureMode,
        calibrateColorChecker: isArtworkMode && calibrateColorChecker,
        losslessPng:
            _losslessPng || (!isPortraitMode && _userPrefs.photoFormat.isLosslessPng),
        applyPerspectiveWarp: isArtworkMode && _applyPerspectiveWarp,
        perspectiveCornersNorm:
            (isArtworkMode && _applyPerspectiveWarp) ? cornersFlat : null,
        wbGains: activeWbGains,
        camToXyzD50: activeCamMatrix,
        flatFieldGrid8x6:
            (_flatFieldEnabled && _measuredFlatField8x6 != null)
                ? _measuredFlatField8x6
                : null,
      );
      if (!mounted) return;

      bool shouldPushLiveControls = false;
      if (lockGrayCardFromCenter) {
        if (res.centerLinearCamRgb != null &&
            res.centerLinearCamRgb!.length >= 3) {
          final cr = res.centerLinearCamRgb![0].clamp(1e-4, 1.0);
          final cg = res.centerLinearCamRgb![1].clamp(1e-4, 1.0);
          final cb = res.centerLinearCamRgb![2].clamp(1e-4, 1.0);
          _measuredGrayCardWbGains = [cg / cr, 1.0, cg / cb];
          _useMeasuredGrayCardWb = true;
          shouldPushLiveControls = true;
          await widget.calibrationStore.saveGrayCardWb(
            _selectedCameraId,
            wbGains: _measuredGrayCardWbGains,
            enabled: true,
          );
        } else if (res.wbGainsUsed != null && res.wbGainsUsed!.length >= 3) {
          _measuredGrayCardWbGains = [
            res.wbGainsUsed![0],
            res.wbGainsUsed![1],
            res.wbGainsUsed![2],
          ];
          _useMeasuredGrayCardWb = true;
          shouldPushLiveControls = true;
          await widget.calibrationStore.saveGrayCardWb(
            _selectedCameraId,
            wbGains: _measuredGrayCardWbGains,
            enabled: true,
          );
        }
        if (res.measuredFlatField8x6 != null &&
            res.measuredFlatField8x6!.length == 48) {
          _measuredFlatField8x6 = res.measuredFlatField8x6;
          _flatFieldEnabled = true;
          await widget.calibrationStore.saveFlatField8x6(
            _selectedCameraId,
            res.measuredFlatField8x6!,
          );
        }
      }

      if (calibrateColorChecker && res.liveCalibrationResult != null) {
        _calibrationResult = res.liveCalibrationResult!;
        shouldPushLiveControls = true;
        await widget.calibrationStore.saveCalibrationResult(
          _selectedCameraId,
          res.liveCalibrationResult!,
        );
      }

      setState(() {
        _isCapturing = false;
        _lastCaptureResult = res;
        final cctStr = res.solvedCctKelvin != null
            ? '${res.solvedCctKelvin!.round()}K'
            : '';
        if (isPortraitMode) {
          _statusBanner =
              'Portre f/${_portraitAperture.toStringAsFixed(1)} Kaydedildi';
        } else if (calibrateColorChecker && res.liveCalibrationResult != null) {
          _statusBanner =
              '24-Yama Kalibre Edildi · ΔE00 Ort = ${res.liveCalibrationResult!.meanDeltaEAfter.toStringAsFixed(2)}';
        } else if (lockGrayCardFromCenter) {
          _statusBanner = cctStr.isNotEmpty
              ? 'Gri Kart WB Kilitlendi ($cctStr)'
              : 'Gri Kart WB Kilitlendi';
        } else {
          _statusBanner =
              cctStr.isNotEmpty ? 'Kaydedildi ($cctStr)' : 'Kaydedildi';
        }
      });

      if (shouldPushLiveControls) {
        _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _statusBanner = 'Çekim hatası: $e';
      });
    }
  }

  Future<void> _triggerBracketedCapture() async {
    if (_isCapturing) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isCapturing = true;
      _statusBanner = '3x AEB (-1.5, 0.0, +1.5 EV) çekiliyor...';
    });
    try {
      final results = await ZameraCapture.captureBracketedPhotos(
        evOffsets: const [-1.5, 0.0, 1.5],
      );
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        if (results.isNotEmpty) {
          _lastCaptureResult = results[results.length ~/ 2];
        }
        _statusBanner = '3x AEB Tamamlandı (${results.length} kare)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _statusBanner = 'AEB hatası: $e';
      });
    }
  }

  String _formatShutter(int? expNs) {
    if (_selectedMode == 1 && _manualExposure) {
      return '1/${_shutterDenominator.round()}s';
    }
    if (expNs == null || expNs <= 0) return '1/100s';
    final sec = expNs / 1e9;
    if (sec >= 0.5) return '${sec.toStringAsFixed(1)}s';
    final denom = (1.0 / sec).round().clamp(1, 16000);
    return '1/${denom}s';
  }

  String _formatFocusDistance(double? diopters) {
    final cap = _activeCameraCap;
    if (cap != null && !cap.supportsVariableFocus) return '∞';
    final maxDiopters = (cap?.minimumFocusDistanceDiopters ?? 10.0) > 0.0
        ? (cap?.minimumFocusDistanceDiopters ?? 10.0)
        : 10.0;
    final d = _manualFocus
        ? (_focusDistance * maxDiopters)
        : (diopters ?? 0.0);
    if (d <= 0.05) return '∞';
    final meters = (1.0 / d).clamp(0.08, 99.0);
    return meters < 1.0
        ? '${(meters * 100).round()}cm'
        : '${meters.toStringAsFixed(1)}m';
  }

  void _setManualFocusPreset(
    double? normDistance, {
    bool syncInnerWheel = false,
  }) {
    _triggerRadialHaptic();
    setState(() {
      if (normDistance == null) {
        _manualFocus = false;
      } else {
        _manualFocus = true;
        _focusDistance = normDistance.clamp(0.0, 1.0);
        if (syncInnerWheel && _activeDial == ActiveProDial.focus) {
          _continuousWheelNorm =
              _normalizedValueForDial(ActiveProDial.focus);
        }
      }
    });
    _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
  }

  double _normalizedValueForDial(ActiveProDial dial) {
    switch (dial) {
      case ActiveProDial.lens:
        final minL = math.log(0.5);
        final maxL = math.log(10.0);
        final curL = math.log(_zoomFactor.clamp(0.5, 10.0));
        return ((curL - minL) / (maxL - minL)).clamp(0.0, 1.0);
      case ActiveProDial.aperture:
        final minL = math.log(1.4);
        final maxL = math.log(16.0);
        final curL = math.log(_portraitAperture.clamp(1.4, 16.0));
        return ((curL - minL) / (maxL - minL)).clamp(0.0, 1.0);
      case ActiveProDial.portraitLight:
        if ((_portraitLightIntensity - 0.80).abs() < 0.02 &&
            _portraitLightingIndex == 0) {
          return 0.0;
        }
        return (0.12 + 0.88 * _portraitLightIntensity).clamp(0.0, 1.0);
      case ActiveProDial.ev:
        return ((_evCompensation + 3.0) / 6.0).clamp(0.0, 1.0);
      case ActiveProDial.iso:
        final isoManual = _selectedMode == 1
            ? _dslrMode.isIsoManual
            : _manualExposure;
        if (!isoManual) return 0.0;
        return (0.12 +
                0.88 *
                    DslrStopsRegistry.isoToNorm(
                      _iso,
                      minIso: _isoMin.round(),
                      maxIso: _isoMax.round(),
                    ))
            .clamp(0.0, 1.0);
      case ActiveProDial.shutter:
        final shutterManual = _selectedMode == 1
            ? _dslrMode.isShutterManual
            : _manualExposure;
        if (!shutterManual) return 0.0;
        // High norm = fast shutter (1/8000s), low norm = long exposure (30")
        final fastNorm =
            1.0 -
            DslrStopsRegistry.shutterNsToNorm(
              _shutterExposureNs,
              minNs: _shutterMinNs,
              maxNs: _shutterMaxNs,
            );
        return (0.12 + 0.88 * fastNorm).clamp(0.0, 1.0);
      case ActiveProDial.shutterAngle:
        if (!_videoLockShutterAngle) return 0.0;
        return (0.12 + 0.88 * ((_videoShutterAngleDeg - 45.0) / (360.0 - 45.0)))
            .clamp(0.0, 1.0);
      case ActiveProDial.videoFps:
        if (_videoFps <= 24) return 0.33;
        if (_videoFps == 25) return 0.50;
        if (_videoFps == 30) return 0.0;
        return 1.0;
      case ActiveProDial.videoProfile:
        final profiles = _availableVideoProfiles;
        final idx = profiles.indexOf(_videoProfile);
        return idx < 0 || profiles.length <= 1
            ? 0.0
            : (idx / (profiles.length - 1)).clamp(0.0, 1.0);
      case ActiveProDial.videoLut:
        final presets = ZameraLutPreset.values;
        return (_videoLutPreset.index / (presets.length - 1)).clamp(0.0, 1.0);
      case ActiveProDial.videoAudio:
        if (_audioInputDevices.length <= 1) return 0.5;
        final idx = _audioInputDevices.indexWhere(
          (d) => d.id == _selectedAudioDeviceId,
        );
        return idx < 0
            ? 0.0
            : (idx / (_audioInputDevices.length - 1)).clamp(0.0, 1.0);
      case ActiveProDial.wb:
        if (!_manualWb) return 0.0;
        return (0.12 + 0.88 * ((_kelvin - 2500.0) / (9000.0 - 2500.0)))
            .clamp(0.0, 1.0);
      case ActiveProDial.focus:
        if (!_manualFocus) return 0.0;
        return (0.12 + 0.88 * _focusDistance.clamp(0.0, 1.0)).clamp(0.0, 1.0);
      case ActiveProDial.none:
        return 0.5;
    }
  }

  void _scrubContinuousWheelByDeltaNorm(
    double deltaNorm, {
    required bool isArtwork,
  }) {
    final dial = _activeDial;
    if (dial == ActiveProDial.none) return;

    final t = (_continuousWheelNorm + deltaNorm).clamp(0.0, 1.0);
    _continuousWheelNorm = t;

    final tickIdx = (t * 60).round();
    if (tickIdx != _lastHapticTickIndex) {
      _lastHapticTickIndex = tickIdx;
      _triggerRadialHaptic();
    }

    if (dial == ActiveProDial.lens) {
      final minL = math.log(0.5);
      final maxL = math.log(10.0);
      final nextZoom = math.exp(minL + t * (maxL - minL));
      setState(() {
        _zoomFactor = nextZoom.clamp(0.5, 10.0);
      });
      final targetCam = _zoomFactor < 0.95 ? '3' : '2';
      if (targetCam != _selectedCameraId && !_isStartingCamera) {
        _startOrSwitchCamera(targetCam, keepZoom: _zoomFactor);
      } else {
        // Push live hardware zoom ratio immediately to Camera2 preview!
        _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
      }
      return;
    }

    if (dial == ActiveProDial.aperture) {
      final minL = math.log(1.4);
      final maxL = math.log(16.0);
      setState(() {
        _portraitAperture =
            math.exp(minL + t * (maxL - minL)).clamp(1.4, 16.0);
      });
      return;
    }

    if (dial == ActiveProDial.portraitLight) {
      // Ring 0 independently adjusts ONLY light intensity (never mutates Ring 1 _portraitLightingIndex or _secondaryArcScrollPos)
      setState(() {
        _portraitLightIntensity = t.clamp(0.0, 1.0);
      });
      _scheduleNativeControlsPush(artworkMode: false);
      return;
    }

    bool needsVideoSessionRestart = false;
    setState(() {
      switch (dial) {
        case ActiveProDial.ev:
          if (_selectedMode == 1 && _dslrMode == DslrExposureMode.manualM) {
            _dslrMode = DslrExposureMode.programP;
          }
          _manualExposure = _selectedMode == 1
              ? _dslrMode != DslrExposureMode.programP
              : false;
          if ((t - 0.50).abs() < 0.035) {
            _evCompensation = 0.0;
          } else {
            _evCompensation = (t * 6.0 - 3.0).clamp(-3.0, 3.0);
          }
          break;
        case ActiveProDial.iso:
          if (t < 0.08) {
            if (_selectedMode == 1) {
              _dslrMode = _dslrMode.isShutterManual
                  ? DslrExposureMode.shutterTv
                  : DslrExposureMode.programP;
              _manualExposure = _dslrMode != DslrExposureMode.programP;
            } else {
              _manualExposure = false;
            }
          } else {
            if (_selectedMode == 1 && !_dslrMode.isIsoManual) {
              _applyBumplessTransferFromLiveTelemetry();
              _dslrMode = _dslrMode.isShutterManual
                  ? DslrExposureMode.manualM
                  : DslrExposureMode.isoSv;
            }
            _manualExposure = true;
            final normScale = ((t - 0.08) / 0.92).clamp(0.0, 1.0);
            _iso = DslrStopsRegistry.isoFromNorm(
              normScale,
              minIso: _isoMin.round(),
              maxIso: _isoMax.round(),
            ).toDouble();
          }
          break;
        case ActiveProDial.shutter:
          if (t < 0.08) {
            if (_selectedMode == 1) {
              _dslrMode = _dslrMode.isIsoManual
                  ? DslrExposureMode.isoSv
                  : DslrExposureMode.programP;
              _manualExposure = _dslrMode != DslrExposureMode.programP;
            } else {
              _manualExposure = false;
            }
          } else {
            if (_selectedMode == 1 && !_dslrMode.isShutterManual) {
              _applyBumplessTransferFromLiveTelemetry();
              _dslrMode = _dslrMode.isIsoManual
                  ? DslrExposureMode.manualM
                  : DslrExposureMode.shutterTv;
            }
            _manualExposure = true;
            final normScale = ((t - 0.08) / 0.92).clamp(0.0, 1.0);
            // High normScale = fast shutter (1/8000s), low normScale = long exposure (30")
            _shutterExposureNs = DslrStopsRegistry.shutterNsFromNorm(
              1.0 - normScale,
              minNs: _shutterMinNs,
              maxNs: _shutterMaxNs,
            );
            _shutterDenominator =
                (1e9 / _shutterExposureNs).clamp(0.033, 8000.0);
          }
          break;
        case ActiveProDial.shutterAngle:
          if (t < 0.08) {
            _videoLockShutterAngle = false;
            _videoShutterAngleDeg = 180.0;
          } else {
            _videoLockShutterAngle = true;
            final normScale = ((t - 0.08) / 0.92).clamp(0.0, 1.0);
            _videoShutterAngleDeg =
                (45.0 + normScale * (360.0 - 45.0)).clamp(45.0, 360.0);
          }
          break;
        case ActiveProDial.videoFps:
          if (t < 0.18) {
            if (_videoFps != 30) {
              _videoFps = 30;
              needsVideoSessionRestart = !_isVideoRecording;
            }
          } else {
            const fpsStops = [24, 25, 30, 60];
            final idx = (((t - 0.18) / 0.82) * (fpsStops.length - 1))
                .round()
                .clamp(0, fpsStops.length - 1);
            if (_videoFps != fpsStops[idx]) {
              _videoFps = fpsStops[idx];
              needsVideoSessionRestart = !_isVideoRecording;
            }
          }
          break;
        case ActiveProDial.videoProfile:
          final profiles = _availableVideoProfiles;
          final idx =
              (t * (profiles.length - 1)).round().clamp(0, profiles.length - 1);
          if (_videoProfile != profiles[idx]) {
            _videoProfile = profiles[idx];
            needsVideoSessionRestart = !_isVideoRecording;
          }
          break;
        case ActiveProDial.videoLut:
          final presets = ZameraLutPreset.values;
          final idx =
              (t * (presets.length - 1)).round().clamp(0, presets.length - 1);
          _videoLutPreset = presets[idx];
          break;
        case ActiveProDial.videoAudio:
          if (_audioInputDevices.isNotEmpty) {
            final idx = (t * (_audioInputDevices.length - 1))
                .round()
                .clamp(0, _audioInputDevices.length - 1);
            _selectedAudioDeviceId = _audioInputDevices[idx].id;
          }
          break;
        case ActiveProDial.wb:
          if (t < 0.08) {
            _manualWb = false;
          } else {
            _manualWb = true;
            final normScale = ((t - 0.08) / 0.92).clamp(0.0, 1.0);
            _kelvin =
                (2500.0 + normScale * (9000.0 - 2500.0)).clamp(2500.0, 9000.0);
          }
          break;
        case ActiveProDial.focus:
          if (t < 0.08) {
            _manualFocus = false;
          } else {
            _manualFocus = true;
            _focusDistance = ((t - 0.08) / 0.92).clamp(0.0, 1.0);
          }
          break;
        case ActiveProDial.lens:
        case ActiveProDial.aperture:
        case ActiveProDial.portraitLight:
        case ActiveProDial.none:
          break;
      }
    });
    if (needsVideoSessionRestart && _selectedMode == 3) {
      _startOrSwitchVideoCamera(_selectedCameraId, keepZoom: _zoomFactor);
      return;
    }
    _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
  }

  @override
  Widget build(BuildContext context) {
    final isArtwork = _selectedMode == 0;
    final isProPhoto = _selectedMode == 1;
    final isPortrait = _selectedMode == 2;
    final isVideo = _selectedMode == 3;

    return Scaffold(
      backgroundColor: kObsidianBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. FULL-BLEED CAMERA CANVAS (Shared across Photo & Pro Video with 3D LUT / False Color / Zebra / HUD)
                Positioned.fill(
                  child: _buildFullScreenCameraCanvas(
                    isArtworkMode: isArtwork,
                    isProPhoto: isProPhoto,
                    isPortraitMode: isPortrait,
                    isVideoMode: isVideo,
                    constraints: constraints,
                  ),
                ),

                // 2. PURE iOS TOP BAR (No Zamera logo/text! Only circular icon buttons)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildMinimalIosTopBar(
                    isArtwork: isArtwork,
                    isProPhoto: isProPhoto,
                    isPortrait: isPortrait,
                    isVideo: isVideo,
                  ),
                ),

                // 3. ROTATING iOS RADIAL DOME + INDEPENDENT CONCENTRIC RINGS (Ring 0 + Ring 1 + Outermost Ring 2)
                if (_activeDial != ActiveProDial.none)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 356,
                    child: _buildIosFullBottomRadialDome(
                      isArtwork: isArtwork,
                      isVideo: isVideo,
                      width: constraints.maxWidth,
                    ),
                  ),

                // 4. RADIAL SETTING BUTTONS ARC
                // Only visible when radial menu is open and NO specific dial is currently selected!
                // When a setting is selected, this arc hides so icons don't clutter the wheel!
                if (_radialMenuOpen && _activeDial == ActiveProDial.none)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 144,
                    height: isVideo ? 168 : 118,
                    child: _buildRadialSettingButtonsArc(
                      width: constraints.maxWidth,
                      isPortrait: isPortrait,
                      isVideo: isVideo,
                    ),
                  ),

                // 6. BOTTOM iOS MODE STRIP & SHUTTER DECK
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomIosCameraDeck(
                    isArtwork: isArtwork,
                    isProPhoto: isProPhoto,
                    isPortrait: isPortrait,
                    isVideo: isVideo,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Pure iOS Camera Top Bar (Zamera logo & text removed as requested!)
  Widget _buildMinimalIosTopBar({
    required bool isArtwork,
    required bool isProPhoto,
    required bool isPortrait,
    required bool isVideo,
  }) {
    final liveIso = _manualExposure && (isProPhoto || isVideo)
        ? _iso.round()
        : ((_videoTelemetry?.activeIso) ??
            (_liveTelemetry['iso'] as num?)?.round() ??
            _lastCaptureResult?.iso ??
            100);
    final liveExpNs = (_videoTelemetry?.shutterExposureNs) ??
        (_liveTelemetry['exposureTimeNs'] as num?)?.toInt() ??
        _lastCaptureResult?.exposureTimeNs;
    final liveCct = ((isProPhoto || isVideo) && _manualWb)
        ? _kelvin.round()
        : ((_lastCaptureResult?.solvedCctKelvin ??
                    (_liveTelemetry['solvedCctKelvin'] as num?)?.toDouble() ??
                    5500.0)
                .round());

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top-Left: In Portrait mode shows iconic iOS `f 2.8` circle; otherwise Histogram/RAW circle
              if (isPortrait)
                GestureDetector(
                  onTap: () => _selectRadialSettingDial(ActiveProDial.aperture),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _activeDial == ActiveProDial.aperture
                          ? kIosYellow
                          : Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _activeDial == ActiveProDial.aperture
                            ? kIosYellow
                            : Colors.white38,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      'ƒ ${_portraitAperture.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _activeDial == ActiveProDial.aperture
                            ? Colors.black
                            : kIosYellow,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () =>
                      setState(() => _showLiveHistogram = !_showLiveHistogram),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _showLiveHistogram
                          ? kIosYellow.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.38),
                      border: Border.all(
                        color: _showLiveHistogram
                            ? kIosYellow
                            : Colors.white.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.equalizer_rounded,
                      size: 16,
                      color: _showLiveHistogram ? kIosYellow : Colors.white,
                    ),
                  ),
                ),

              // Top-Center: Iconic iOS Circular Chevron Button (^)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _topDrawerExpanded = !_topDrawerExpanded);
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _topDrawerExpanded
                        ? kIosYellow.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _topDrawerExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 20,
                    color: _topDrawerExpanded ? kIosYellow : Colors.white,
                  ),
                ),
              ),

              // Top-Right: Settings Gear Icon (Full-screen Zamera Settings, Formats, Probe, Privacy, Support)
              GestureDetector(
                onTap: () {
                  _triggerRadialHaptic();
                  SettingsSheet.show(
                    context,
                    onOpenProbe: () => _showCalibrationAndProbeSheet(),
                    onOpenCalibration: () => _showCalibrationAndProbeSheet(),
                    initialPreferences: _userPrefs,
                    availableVideoProfiles: _availableVideoProfiles,
                    onPreferencesChanged: (nextPrefs) {
                      _applyUserPreferences(nextPrefs, persist: true);
                    },
                    onResetPreferences: () async {
                      try {
                        await widget.settingsStore.reset();
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _statusBanner = 'Sıfırlama uyarısı: $e';
                          });
                        }
                      }
                      if (!mounted) return;
                      _applyUserPreferences(
                        const ZameraPreferences(),
                        persist: false,
                      );
                    },
                  );
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          // Expandable iOS Drawer (ONLY visible when user taps the ^ chevron)
          if (_topDrawerExpanded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ISO $liveIso  ·  ${_formatShutter(liveExpNs)}  ·  ${liveCct}K  ·  ${_zoomFactor.toStringAsFixed(1)}×',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: kIosYellow,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (isArtwork) ...[
                          _buildQuickTogglePill(
                            label: _fullResolution ? '12.6MP' : '3.1MP',
                            active: _fullResolution,
                            onTap: () => setState(
                              () => _fullResolution = !_fullResolution,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickTogglePill(
                            label: _useDisplayP3 ? 'DISPLAY P3' : 'sRGB',
                            active: _useDisplayP3,
                            onTap: () =>
                                setState(() => _useDisplayP3 = !_useDisplayP3),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickTogglePill(
                            label: 'FLAT-FIELD',
                            active: _flatFieldEnabled,
                            onTap: () => setState(
                              () => _flatFieldEnabled = !_flatFieldEnabled,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickTogglePill(
                            label: _applyPerspectiveWarp
                                ? 'WARP AÇIK'
                                : '4-KÖŞE',
                            active: _showPerspectiveGrid,
                            onTap: () {
                              setState(() {
                                if (!_showPerspectiveGrid) {
                                  _showPerspectiveGrid = true;
                                } else if (!_applyPerspectiveWarp) {
                                  _applyPerspectiveWarp = true;
                                } else {
                                  _applyPerspectiveWarp = false;
                                  _showPerspectiveGrid = false;
                                }
                              });
                            },
                          ),
                        ] else ...[
                          if (isVideo) ...[
                            _buildQuickTogglePill(
                              label: _videoResolutionHeight >= 2160 ? '4K UHD' : '1080P FHD',
                              active: _videoResolutionHeight >= 2160,
                              onTap: () {
                                if (_isVideoRecording) return;
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _videoResolutionHeight =
                                      _videoResolutionHeight >= 2160 ? 1080 : 2160;
                                });
                                _startOrSwitchVideoCamera(
                                  _selectedCameraId,
                                  keepZoom: _zoomFactor,
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildQuickTogglePill(
                              label: _videoStabilization ? 'OIS+EIS (KIRPMA)' : 'OIS SAF',
                              active: _videoStabilization,
                              onTap: () {
                                if (_isVideoRecording) return;
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _videoStabilization = !_videoStabilization;
                                });
                                _startOrSwitchVideoCamera(
                                  _selectedCameraId,
                                  keepZoom: _zoomFactor,
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildQuickTogglePill(
                              label: 'SES: ${_audioInputDevices.where((d) => d.id == _selectedAudioDeviceId).firstOrNull?.name ?? "DAHİLİ"}',
                              active: _selectedAudioDeviceId != 'default',
                              onTap: () {
                                if (_isVideoRecording ||
                                    _audioInputDevices.isEmpty) {
                                  _selectRadialSettingDial(
                                    ActiveProDial.videoAudio,
                                  );
                                  return;
                                }
                                HapticFeedback.selectionClick();
                                final idx = _audioInputDevices.indexWhere(
                                  (d) => d.id == _selectedAudioDeviceId,
                                );
                                final nextDev = _audioInputDevices[
                                    (idx + 1) % _audioInputDevices.length];
                                setState(() {
                                  _selectedAudioDeviceId = nextDev.id;
                                  _topDrawerExpanded = false;
                                });
                                _startOrSwitchVideoCamera(
                                  _selectedCameraId,
                                  keepZoom: _zoomFactor,
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                          ] else ...[
                            _buildQuickTogglePill(
                              label: 'DNG 14B',
                              active: true,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _statusBanner =
                                      '14-Bit Doğrusal DNG + JPEG ikili kayıt aktif';
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                          _buildQuickTogglePill(
                            label: 'ZEBRA 95',
                            active: _showZebra,
                            onTap: () =>
                                setState(() => _showZebra = !_showZebra),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickTogglePill(
                            label: 'ZEBRA 70',
                            active: _showZebra70,
                            onTap: () =>
                                setState(() => _showZebra70 = !_showZebra70),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickTogglePill(
                            label: 'FALSE COLOR',
                            active: _showFalseColor,
                            onTap: () => setState(
                              () => _showFalseColor = !_showFalseColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickTogglePill(
                            label: 'PEAKING',
                            active: _showFocusPeaking,
                            onTap: () => setState(
                              () => _showFocusPeaking = !_showFocusPeaking,
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        _buildQuickTogglePill(
                          label: 'HİSTOGRAM',
                          active: _showLiveHistogram,
                          onTap: () => setState(
                            () => _showLiveHistogram = !_showLiveHistogram,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildQuickTogglePill(
                          label: 'KALİBRASYON',
                          active: false,
                          onTap: _showCalibrationAndProbeSheet,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickTogglePill({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: active
              ? kIosYellow.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? kIosYellow.withValues(alpha: 0.8) : Colors.white12,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: active ? kIosYellow : Colors.white70,
          ),
        ),
      ),
    );
  }

  /// Full-Bleed Edge-to-Edge Camera Canvas
  Widget _buildFullScreenCameraCanvas({
    required bool isArtworkMode,
    required bool isProPhoto,
    required bool isPortraitMode,
    required bool isVideoMode,
    required BoxConstraints constraints,
  }) {
    final session = _previewSession;
    final lastRes = _lastCaptureResult;
    final liveHist64Raw = _liveTelemetry['liveHistogram64'];
    final liveHist32Raw = _liveTelemetry['liveHistogram32'];
    final List<double> hist;
    if (isVideoMode &&
        _videoTelemetry != null &&
        _videoTelemetry!.liveHistogram64.isNotEmpty) {
      hist = _videoTelemetry!.liveHistogram64;
    } else if (liveHist64Raw is List && liveHist64Raw.isNotEmpty) {
      hist = liveHist64Raw.map((e) => (e as num).toDouble()).toList();
    } else if (liveHist32Raw is List && liveHist32Raw.isNotEmpty) {
      hist = liveHist32Raw.map((e) => (e as num).toDouble()).toList();
    } else {
      hist = lastRes?.rawHistogram32 ?? const <double>[];
    }
    final liveZebraRatio = isVideoMode
        ? (_videoTelemetry?.liveZebraRatioHigh ??
            (_liveTelemetry['liveZebraRatio'] as num?)?.toDouble() ??
            0.0)
        : ((_liveTelemetry['liveZebraRatio'] as num?)?.toDouble() ??
            lastRes?.zebraRatio ??
            0.0);
    final liveZebraRatio70 = isVideoMode
        ? (_videoTelemetry?.liveZebraRatioLow ??
            (_liveTelemetry['liveZebraRatio70'] as num?)?.toDouble() ??
            0.0)
        : ((_liveTelemetry['liveZebraRatio70'] as num?)?.toDouble() ?? 0.0);
    final livePeakingScore = isVideoMode
        ? (_videoTelemetry?.liveFocusPeakingScore ??
            (_liveTelemetry['liveFocusPeakingScore'] as num?)?.toDouble() ??
            0.0)
        : ((_liveTelemetry['liveFocusPeakingScore'] as num?)?.toDouble() ??
            lastRes?.focusPeakingScore ??
            0.0);
    final liveZebraGridRaw = _liveTelemetry['liveZebraGrid16x12'];
    final liveZebraGrid = (isVideoMode &&
            _videoTelemetry != null &&
            _videoTelemetry!.liveZebraGrid16x12.length == 192)
        ? _videoTelemetry!.liveZebraGrid16x12
        : ((liveZebraGridRaw is List && liveZebraGridRaw.length == 192)
            ? liveZebraGridRaw.map((e) => (e as num).toDouble()).toList()
            : const <double>[]);
    final livePeakingGridRaw = _liveTelemetry['livePeakingGrid16x12'];
    final livePeakingGrid = (isVideoMode &&
            _videoTelemetry != null &&
            _videoTelemetry!.livePeakingGrid16x12.length == 192)
        ? _videoTelemetry!.livePeakingGrid16x12
        : ((livePeakingGridRaw is List && livePeakingGridRaw.length == 192)
            ? livePeakingGridRaw.map((e) => (e as num).toDouble()).toList()
            : const <double>[]);
    final liveFalseColorRaw = _liveTelemetry['liveFalseColorGrid16x12'];
    final liveFalseColorGrid = (isVideoMode &&
            _videoTelemetry != null &&
            _videoTelemetry!.liveFalseColorGrid16x12.length == 192)
        ? _videoTelemetry!.liveFalseColorGrid16x12
        : ((liveFalseColorRaw is List && liveFalseColorRaw.length == 192)
            ? liveFalseColorRaw.map((e) => (e as num).toInt()).toList()
            : const <int>[]);
    final rawCenterSrgb = _liveTelemetry['liveCenterSrgb'];
    final liveCenterSrgb = (rawCenterSrgb is List && rawCenterSrgb.length >= 3)
        ? <int>[
            (rawCenterSrgb[0] as num).round().clamp(0, 255),
            (rawCenterSrgb[1] as num).round().clamp(0, 255),
            (rawCenterSrgb[2] as num).round().clamp(0, 255),
          ]
        : const <int>[128, 128, 128];
    final rawCenterLab = _liveTelemetry['liveCenterLabD50'];
    final liveCenterLabD50 = (rawCenterLab is List && rawCenterLab.length >= 3)
        ? <double>[
            (rawCenterLab[0] as num).toDouble(),
            (rawCenterLab[1] as num).toDouble(),
            (rawCenterLab[2] as num).toDouble(),
          ]
        : ZameraCapture.srgb8ToLabD50(
            liveCenterSrgb[0],
            liveCenterSrgb[1],
            liveCenterSrgb[2],
          );
    final anyManualLocked =
        _dslrMode != DslrExposureMode.programP ||
        _manualExposure ||
        _aeAfLocked ||
        _manualWb ||
        _manualFocus ||
        _evCompensation != 0.0 ||
        (isArtworkMode && _useMeasuredGrayCardWb);
    final isMonoPortrait = isPortraitMode &&
        (_portraitLightingIndex == 4 ||
            _portraitLightingIndex == 5 ||
            _portraitLightingIndex == 7);
    final isHighKeyMono = isPortraitMode && _portraitLightingIndex == 5;
    final focusCenterNorm = _lastFocusTapNorm ?? const Offset(0.5, 0.44);
    final videoLutMatrix = (isVideoMode && !_videoLutBypass)
        ? ZameraCinemaMath.previewColorMatrixForLut(
            preset: _videoLutPreset,
            profile: _videoProfile,
            customCube: _customCubeLut,
          )
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _onViewfinderTapUp(details, constraints),
      onLongPressStart: (details) =>
          _onViewfinderLongPressStart(details, constraints),
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) {
          if (isPortraitMode) {
            // In Portrait mode, 2-finger pinch resizes the subject bokeh portal!
            setState(() {
              _portraitSubjectRadius = (_portraitSubjectRadius *
                      (1.0 + (details.scale - 1.0) * 0.05))
                  .clamp(0.20, 0.56);
            });
            return;
          }
          final nextZ = (_zoomFactor * (1.0 + (details.scale - 1.0) * 0.08))
              .clamp(0.5, 10.0);
          setState(() {
            _zoomFactor = nextZ;
            _activeDial = ActiveProDial.lens;
            _continuousWheelNorm = _normalizedValueForDial(ActiveProDial.lens);
          });
          _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
        } else if (isPortraitMode && _activeDial == ActiveProDial.none) {
          // Single-finger drag in Portrait mode smoothly repositions the subject focus portal
          final nx = (details.localFocalPoint.dx / constraints.maxWidth)
              .clamp(0.12, 0.88);
          final ny = (details.localFocalPoint.dy / constraints.maxHeight)
              .clamp(0.16, 0.78);
          setState(() {
            _lastFocusTapNorm = Offset(nx, ny);
          });
        } else if (!isArtworkMode &&
            !isPortraitMode &&
            _lastFocusTapNorm != null &&
            _activeDial == ActiveProDial.none &&
            details.focalPointDelta.dy.abs() > 0.5) {
          // Live vertical Sun Exposure Rail drag for quick EV bias in Pro & Video modes!
          final evStep = -details.focalPointDelta.dy / 95.0;
          setState(() {
            _evCompensation = (_evCompensation + evStep).clamp(-3.0, 3.0);
          });
          _scheduleNativeControlsPush(artworkMode: false);
        }
      },
      onPanUpdate: (isArtworkMode &&
              _showPerspectiveGrid &&
              _activeDial == ActiveProDial.none)
          ? (details) {
              final nx = (details.localPosition.dx / constraints.maxWidth)
                  .clamp(0.04, 0.96);
              final ny = (details.localPosition.dy / constraints.maxHeight)
                  .clamp(0.08, 0.86);
              final pt = Offset(nx, ny);
              int closestIdx = -1;
              double minDist = 0.14;
              for (int i = 0; i < _perspectiveCorners.length; i++) {
                final d = (_perspectiveCorners[i] - pt).distance;
                if (d < minDist) {
                  minDist = d;
                  closestIdx = i;
                }
              }
              if (closestIdx >= 0) {
                setState(() {
                  final updated = List<Offset>.from(_perspectiveCorners);
                  updated[closestIdx] = pt;
                  _perspectiveCorners = updated;
                });
              }
            }
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. FULL-BLEED CAMERA TEXTURE (with real-time Monochrome shader or Video 3D LUT / HLG-to-SDR Monitor)
          if (session != null && session.textureId >= 0)
            ClipRect(
              child: ColorFiltered(
                colorFilter: isMonoPortrait
                    ? ColorFilter.matrix(
                        isHighKeyMono
                            ? const <double>[
                                0.36, 0.71, 0.14, 0, 24,
                                0.36, 0.71, 0.14, 0, 24,
                                0.36, 0.71, 0.14, 0, 24,
                                0, 0, 0, 1, 0,
                              ]
                            : const <double>[
                                0.38, 0.75, 0.15, 0, -14,
                                0.38, 0.75, 0.15, 0, -14,
                                0.38, 0.75, 0.15, 0, -14,
                                0, 0, 0, 1, 0,
                              ],
                      )
                    : (videoLutMatrix != null
                        ? ColorFilter.matrix(videoLutMatrix)
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          )),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: session.previewHeight.toDouble(),
                    height: session.previewWidth.toDouble(),
                    child: Texture(textureId: session.textureId),
                  ),
                ),
              ),
            )
          else
            Container(
              color: const Color(0xFF090B10),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sensors_rounded,
                      size: 36,
                      color: kIosYellow,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadingProbe
                          ? 'Fiziksel Sensörler Taranıyor...'
                          : 'Canlı Vizör Hazır (#$_selectedCameraId)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => isVideoMode
                          ? _startOrSwitchVideoCamera(
                              _selectedCameraId,
                              keepZoom: _zoomFactor,
                            )
                          : _startOrSwitchCamera(_selectedCameraId),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Vizörü Başlat'),
                    ),
                  ],
                ),
              ),
            ),

          // 1B. REAL-TIME LEICA PANCHROMATIC MONOCHROME SHADER (Stage Mono, High-Key Mono & Panjur Mono)
          if (isMonoPortrait)
            IgnorePointer(
              child: BackdropFilter(
                filter: ColorFilter.matrix(
                  isHighKeyMono
                      ? const <double>[
                          0.42, 0.56, 0.12, 0, 24,
                          0.42, 0.56, 0.12, 0, 24,
                          0.42, 0.56, 0.12, 0, 22,
                          0, 0, 0, 1, 0,
                        ]
                      : const <double>[
                          0.44, 0.58, 0.10, 0, -18,
                          0.43, 0.58, 0.10, 0, -18,
                          0.41, 0.57, 0.10, 0, -20,
                          0, 0, 0, 1, 0,
                        ],
                ),
                child: const SizedBox.expand(),
              ),
            ),

          // 2A. Sanat Modu (1:1 TrueColor) Center Spot Reticle, Live Lab/ΔE00 Badge & Quick Action Bar
          if (isArtworkMode) ...[
            if (_showSpotMeter) ...[
              Center(
                child: TrueColorCenterReticle(
                  srgb8: liveCenterSrgb,
                  isCalibrated: _calibrationResult.isMeasuredFromSensor,
                ),
              ),
              Positioned(
                top: _showLiveHistogram ? 108 : (anyManualLocked ? 78 : 54),
                left: 14,
                right: 14,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showCalibrationAndProbeSheet,
                    child: TrueColorSpotMeterBadge(
                      srgb8: liveCenterSrgb,
                      labD50: liveCenterLabD50,
                      isCalibrated: _calibrationResult.isMeasuredFromSensor,
                      wbLabel: _activeArtworkWbBadgeLabel,
                    ),
                  ),
                ),
              ),
            ],
            if (!_radialMenuOpen && _activeDial == ActiveProDial.none)
              Positioned(
                left: 0,
                right: 0,
                bottom: 146,
                child: RadialShutterFeatureArc(
                  key: const ValueKey('artwork_truecolor_quick_bar'),
                  nodes: _buildRadialArcNodesForMode(0),
                ),
              ),
          ],

          // 2. Portrait Mode Live Studio HUD & Radial Optical Focal-Length Arc (Zero Viewfinder Blur!)
          if (isPortraitMode) ...[
            IgnorePointer(
              child: CustomPaint(
                painter: PortraitStudioFramePainter(
                  focusNorm: focusCenterNorm,
                  aperture: _portraitAperture,
                  lightingIndex: _portraitLightingIndex,
                  lightIntensity: _portraitLightIntensity,
                  subjectRadiusRatio: _portraitSubjectRadius,
                  zoomFactor: _zoomFactor,
                  subjectDetectionLabel: (_liveTelemetry['detectedFaceBox'] !=
                          null)
                      ? 'YÜZ ALGILANDI · ARKA PLAN AYRILDI'
                      : 'NESNE ALGILANDI · ${_formatFocusDistance((_liveTelemetry['focusDistanceDiopters'] as num?)?.toDouble())}',
                  distanceWarning: (((_liveTelemetry['focusDistanceDiopters']
                                  as num?)
                              ?.toDouble() ??
                          0.0) >
                      5.0)
                      ? 'Daha uzağa gidin'
                      : null,
                ),
              ),
            ),
            if (!_radialMenuOpen && _activeDial == ActiveProDial.none)
              Positioned(
                left: 0,
                right: 0,
                bottom: 146,
                child: RadialShutterFeatureArc(
                  key: const ValueKey('portrait_radial_feature_arc'),
                  nodes: _buildRadialArcNodesForMode(2),
                ),
              ),
          ],

          // 2C. Live Manual Focus & Focus Peaking HUD Overlay
          if (_manualFocus ||
              _activeDial == ActiveProDial.focus ||
              _showFocusPeaking)
            IgnorePointer(
              child: CustomPaint(
                painter: ManualFocusHudPainter(
                  focusNorm: focusCenterNorm,
                  focusDistanceNorm: _focusDistance,
                  formattedDistance: _formatFocusDistance(
                    (_liveTelemetry['focusDistanceDiopters'] as num?)
                        ?.toDouble(),
                  ),
                  manualFocusLocked: _manualFocus,
                  showPeaking: _showFocusPeaking ||
                      _manualFocus ||
                      _activeDial == ActiveProDial.focus,
                ),
              ),
            ),

          // 3. Crisp iOS Corner Framing Brackets & Optional Perspective Quad
          IgnorePointer(
            child: CustomPaint(
              painter: ViewfinderGridAndPerspectivePainter(
                showPerspectiveQuad: isArtworkMode && _showPerspectiveGrid,
                warpActive: isArtworkMode && _applyPerspectiveWarp,
                corners: _perspectiveCorners,
              ),
            ),
          ),

          // 3A. Real-Time Sensor Overexposure Zebra Stripes (95% & 70% IRE), 6-Band False Color & Spatial Focus Peaking Grid
          if (_showZebra ||
              _showZebra70 ||
              _showFalseColor ||
              _showFocusPeaking)
            IgnorePointer(
              child: CustomPaint(
                painter: LiveZebraAndPeakingOverlayPainter(
                  showZebra: _showZebra,
                  showZebra70: _showZebra70,
                  showFalseColor: _showFalseColor,
                  showFocusPeaking: _showFocusPeaking,
                  zebraGrid16x12: liveZebraGrid,
                  peakingGrid16x12: livePeakingGrid,
                  falseColorGrid16x12: liveFalseColorGrid,
                  zebraRatio: liveZebraRatio,
                  zebra70Ratio: liveZebraRatio70,
                  peakingScore: livePeakingScore,
                ),
              ),
            ),

          // 3B. ARRI/FX3 Recording Tally Frame + Interactive Cinema Pro Video HUD & Quick Deck
          if (isVideoMode) ...[
            Positioned.fill(
              child: VideoRecTallyBorder(isRecording: _isVideoRecording),
            ),
            Positioned(
              top: 50,
              left: 12,
              right: 12,
              child: _buildInteractiveVideoCinemaHud(),
            ),
            if (!_radialMenuOpen && _activeDial == ActiveProDial.none)
              Positioned(
                left: 12,
                right: 12,
                bottom: 146,
                child: Center(
                  child: VideoCinemaQuickDeck(
                    lensOptions: _cinemaLensOptions,
                    activeLensId: _activeCinemaLensOptionId,
                    onSelectLens: (lensId) {
                      final z = double.tryParse(lensId) ?? 1.0;
                      final targetCam = z < 0.95
                          ? '3'
                          : (z >= 2.7 && _telephotoCameraId != null
                              ? _telephotoCameraId!
                              : '2');
                      if (!_isVideoRecording &&
                          targetCam != _selectedCameraId) {
                        _startOrSwitchVideoCamera(targetCam, keepZoom: z);
                      } else {
                        setState(() => _zoomFactor = z);
                        _scheduleNativeControlsPush(artworkMode: false);
                      }
                    },
                    rackDurationMs: _rackFocusDurationMs,
                    hasPointA: _hasFocusPointA,
                    hasPointB: _hasFocusPointB,
                    isRackActive: _isPullingFocus,
                    onSetPointA: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _manualFocus = true;
                        _focusPullPointA = _focusDistance;
                        _hasFocusPointA = true;
                        _statusBanner =
                            'Odak Noktası A kilitlendi (%${(_focusPullPointA * 100).round()})';
                      });
                      _scheduleNativeControlsPush(artworkMode: false);
                    },
                    onSetPointB: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _manualFocus = true;
                        _focusPullPointB = _focusDistance;
                        _hasFocusPointB = true;
                        _statusBanner =
                            'Odak Noktası B kilitlendi (%${(_focusPullPointB * 100).round()})';
                      });
                      _scheduleNativeControlsPush(artworkMode: false);
                    },
                    onTriggerRackAB: _triggerVideoFocusPull,
                    onCycleRackDuration: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _rackFocusDurationMs = _rackFocusDurationMs <= 900
                            ? 2000
                            : (_rackFocusDurationMs <= 2100 ? 3500 : 800);
                      });
                    },
                    eisEnabled: _videoStabilization,
                    onToggleEis: _isVideoRecording
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _videoStabilization = !_videoStabilization;
                            });
                            _startOrSwitchVideoCamera(
                              _selectedCameraId,
                              keepZoom: _zoomFactor,
                            );
                          },
                    aeAfLocked: _aeAfLocked,
                    onToggleAeAfLock: _toggleAeAfLock,
                  ),
                ),
              ),
          ],

          // 3C. DSLR Pro Photo HUD Bar (P/Tv/Sv/M + Live [-3..+3] EV Meter + Drive/Timer + AEL/AFL) + Above-Shutter Radial Feature Arc
          if (isProPhoto && !_radialMenuOpen && _activeDial == ActiveProDial.none)
            Positioned(
              left: 0,
              right: 0,
              bottom: 146,
              child: RadialShutterFeatureArc(
                key: const ValueKey('pro_radial_feature_arc'),
                nodes: _buildRadialArcNodesForMode(1),
              ),
            ),
          if (isProPhoto && _activeDial == ActiveProDial.none)
            Positioned(
              top: 50,
              left: 12,
              right: 12,
              child: ProDslrExposureBar(
                mode: _dslrMode,
                driveMode: _proDriveMode,
                meteredEvDelta:
                    ((_liveTelemetry['meteredEvDelta'] as num?)?.toDouble() ??
                            0.0)
                        .clamp(-3.0, 3.0),
                evCompensation: _evCompensation,
                aeAfLocked: _aeAfLocked,
                liveIso: _dslrMode.isIsoManual
                    ? _iso.round()
                    : ((_liveTelemetry['iso'] as num?)?.round() ??
                        _lastCaptureResult?.iso ??
                        100),
                liveShutterLabel: _dslrMode.isShutterManual
                    ? DslrStopsRegistry.formatShutterNs(_shutterExposureNs)
                    : DslrStopsRegistry.formatShutterNs(
                        (_liveTelemetry['exposureTimeNs'] as num?)?.toInt() ??
                            _lastCaptureResult?.exposureTimeNs ??
                            8000000,
                      ),
                liveWbLabel: _manualWb
                    ? '${_kelvin.round()}K${_tint.abs() >= 1 ? " ${_tint > 0 ? "+${_tint.round()}M" : "${_tint.round()}G"}" : ""}'
                    : 'AWB ${((_liveTelemetry['solvedCctKelvin'] as num?)?.round() ?? 5500)}K',
                countdownRemainingSec: _selfTimerRemainingSec,
                onModeChanged: _setDslrExposureMode,
                onDriveModeChanged: (nextDrive) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _proDriveMode = nextDrive;
                    _statusBanner = 'Sürücü Modu: ${nextDrive.shortLabel}';
                  });
                },
                onToggleAeAfLock: _toggleAeAfLock,
                onTapShutter: () =>
                    _selectRadialSettingDial(ActiveProDial.shutter),
                onTapIso: () => _selectRadialSettingDial(ActiveProDial.iso),
                onTapWb: () => _selectRadialSettingDial(ActiveProDial.wb),
                onEvChanged: (nextEv) {
                  setState(() {
                    if (_dslrMode == DslrExposureMode.manualM) {
                      _dslrMode = DslrExposureMode.programP;
                      _manualExposure = false;
                    }
                    _evCompensation = nextEv.clamp(-3.0, 3.0);
                  });
                  _scheduleNativeControlsPush(artworkMode: false);
                },
              ),
            ),

          // 4. iOS Yellow Tap-to-Focus Box + Sun Exposure Rail
          if (_lastFocusTapNorm != null)
            Positioned(
              left: (_lastFocusTapNorm!.dx * constraints.maxWidth) - 34,
              top: (_lastFocusTapNorm!.dy * constraints.maxHeight) - 34,
              child: IgnorePointer(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: kIosYellow,
                          width: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 1.0,
                          height: 18,
                          color: kIosYellow.withValues(alpha: 0.8),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Icon(
                            Icons.wb_sunny_rounded,
                            size: 13,
                            color: kIosYellow,
                          ),
                        ),
                        Container(
                          width: 1.0,
                          height: 18,
                          color: kIosYellow.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 5. Real-Time Sensor Luma Histogram (64-Bin in Video / 32-Bin in Photo — No Fake Fallback Array!)
          if (_showLiveHistogram)
            Positioned(
              top: isVideoMode ? 144 : (isProPhoto ? 152 : 56),
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12, width: 0.6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hist.isNotEmpty
                              ? 'CANLI Y-LUMA (${hist.length}B)'
                              : 'SENSÖR BEKLENİYOR',
                          style: const TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            color: kIosYellow,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Z95:${(liveZebraRatio * 100).toStringAsFixed(1)}% · Z70:${(liveZebraRatio70 * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            color: kZameraCyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 112,
                      height: 24,
                      child: CustomPaint(
                        painter: RawHistogramPainter(hist),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 6. Top-Center iOS Yellow Badge (Only for Manual Lock in Sanat — Pro uses DSLR HUD Bar)
          if (!isPortraitMode && !isVideoMode && !isProPhoto && anyManualLocked)
            Positioned(
              top: 52,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _resetAllProControlsToAuto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kIosYellow.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'MANUEL · AUTO SIFIRLA',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 7. Subtle Status Toast
          if (_statusBanner != null && _activeDial == ActiveProDial.none)
            Positioned(
              bottom: 242,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _statusBanner!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Single Source of Truth (SSOT) for each camera mode's above-shutter quick features.
  /// Rendered on [RadialShutterFeatureArc] / [VideoCinemaQuickDeck] when idle, and moved to the
  /// outermost concentric ring (Ring 2) of [IosCameraRadialWheelPainter] when a radial dial is selected.
  List<({
    RadialOuterFeatureSpec spec,
    Key? pillKey,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  })> _aboveShutterFeaturesForMode(int modeIndex) {
    switch (modeIndex) {
      case 0: // SANAT (TrueColor 1:1)
        final isNaturalTone = _artworkExposureMode == 2;
        final grayLocked =
            _useMeasuredGrayCardWb && _measuredGrayCardWbGains != null;
        return [
          (
            spec: RadialOuterFeatureSpec(
              id: 'art_exposure_mode',
              label: isNaturalTone ? '1:1 TON' : 'KAĞIT L*94',
              isActive: isNaturalTone,
              accentColor: isNaturalTone ? kZameraCyan : kIosYellow,
            ),
            pillKey: const ValueKey('artwork_pill_exposure_mode'),
            onTap: () {
              _triggerRadialHaptic();
              setState(() {
                _artworkExposureMode = _artworkExposureMode == 2 ? 1 : 2;
                _statusBanner = _artworkExposureMode == 2
                    ? '1:1 Doğal Ton aktif (artworkExposureMode = 2)'
                    : 'Kağıt L*94 beyaz normalizasyonu aktif';
              });
              _scheduleNativeControlsPush(artworkMode: true);
            },
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'art_gray_wb',
              label: 'GRİ KART WB',
              isActive: grayLocked,
              accentColor: kIosYellow,
            ),
            pillKey: const ValueKey('artwork_pill_gray_card_wb'),
            onTap: _isCapturing
                ? null
                : () {
                    if (_measuredGrayCardWbGains == null) {
                      _triggerPhotoCapture(
                        isArtworkMode: true,
                        lockGrayCardFromCenter: true,
                      );
                    } else {
                      _triggerRadialHaptic();
                      final nextVal = !_useMeasuredGrayCardWb;
                      setState(() {
                        _useMeasuredGrayCardWb = nextVal;
                        _statusBanner = nextVal
                            ? 'Gri Kart WB aktif (yeniden ölçmek için basılı tutun)'
                            : 'Gri Kart WB kapatıldı · DNG WB aktif';
                      });
                      widget.calibrationStore.saveGrayCardWb(
                        _selectedCameraId,
                        wbGains: _measuredGrayCardWbGains,
                        enabled: nextVal,
                      );
                      _scheduleNativeControlsPush(artworkMode: true);
                    }
                  },
            onLongPress: _isCapturing
                ? null
                : () {
                    _triggerPhotoCapture(
                      isArtworkMode: true,
                      lockGrayCardFromCenter: true,
                    );
                  },
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'art_24patch',
              label: '24-YAMA KALİBRE',
              isActive: _calibrationResult.isMeasuredFromSensor,
              accentColor: const Color(0xFF30D158),
            ),
            pillKey: const ValueKey('artwork_pill_24patch_calibrate'),
            onTap: _isCapturing
                ? null
                : () {
                    _triggerPhotoCapture(
                      isArtworkMode: true,
                      calibrateColorChecker: true,
                    );
                  },
            onLongPress: _showCalibrationAndProbeSheet,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'art_spot_meter',
              label: 'RENK ÖLÇER',
              isActive: _showSpotMeter,
              accentColor: kZameraCyan,
            ),
            pillKey: const ValueKey('artwork_pill_spot_meter'),
            onTap: () {
              _triggerRadialHaptic();
              setState(() => _showSpotMeter = !_showSpotMeter);
            },
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'art_lossless_png',
              label: 'KAYIPSIZ PNG',
              isActive: _losslessPng,
              accentColor: kIosYellow,
            ),
            pillKey: const ValueKey('artwork_pill_lossless_png'),
            onTap: () {
              _triggerRadialHaptic();
              setState(() {
                _losslessPng = !_losslessPng;
                _statusBanner = _losslessPng
                    ? 'Kayıpsız 1:1 PNG çıktısı açık'
                    : 'Yüksek kalite JPEG + DNG çıktısı aktif';
              });
            },
            onLongPress: null,
          ),
        ];

      case 1: // PRO (DSLR Photo Assists & Capture Format)
        const cycleOrder = <PhotoCaptureFormat>[
          PhotoCaptureFormat.rawPlusJpeg,
          PhotoCaptureFormat.proRaw48Mp,
          PhotoCaptureFormat.dngRawOnly,
          PhotoCaptureFormat.losslessPng,
          PhotoCaptureFormat.jpegOnly,
        ];
        return [
          (
            spec: RadialOuterFeatureSpec(
              id: 'pro_format',
              label: _userPrefs.photoFormat.shortLabel,
              isActive: _userPrefs.photoFormat.capturesRaw,
              accentColor: kIosYellow,
            ),
            pillKey: const ValueKey('pro_pill_photo_format'),
            onTap: () {
              _triggerRadialHaptic();
              final curIdx = cycleOrder.indexOf(_userPrefs.photoFormat);
              final nextFmt = cycleOrder[(curIdx + 1) % cycleOrder.length];
              final nextPrefs = _userPrefs.copyWith(photoFormat: nextFmt);
              _applyUserPreferences(nextPrefs, persist: true);
              setState(() {
                _statusBanner = 'Kayıt Formatı: ${nextFmt.titleTr}';
              });
            },
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'pro_zebra95',
              label: 'ZEBRA %95',
              isActive: _showZebra,
              accentColor: kIosYellow,
            ),
            pillKey: const ValueKey('pro_pill_zebra95'),
            onTap: () {
              _triggerRadialHaptic();
              setState(() => _showZebra = !_showZebra);
            },
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'pro_peaking',
              label: 'PEAKING',
              isActive: _showFocusPeaking,
              accentColor: const Color(0xFF30D158),
            ),
            pillKey: const ValueKey('pro_pill_peaking'),
            onTap: () {
              _triggerRadialHaptic();
              setState(() => _showFocusPeaking = !_showFocusPeaking);
            },
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'pro_false_color',
              label: 'SAHTE RENK',
              isActive: _showFalseColor,
              accentColor: kZameraCyan,
            ),
            pillKey: const ValueKey('pro_pill_false_color'),
            onTap: () {
              _triggerRadialHaptic();
              setState(() => _showFalseColor = !_showFalseColor);
            },
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'pro_histogram',
              label: 'HİSTOGRAM',
              isActive: _showLiveHistogram,
              accentColor: kIosYellow,
            ),
            pillKey: const ValueKey('pro_pill_histogram'),
            onTap: () {
              _triggerRadialHaptic();
              setState(() => _showLiveHistogram = !_showLiveHistogram);
            },
            onLongPress: null,
          ),
        ];

      case 2: // PORTRE (Optical Focal-Length Stops & Studio Assists)
        return [
          (
            spec: RadialOuterFeatureSpec(
              id: 'portrait_1x',
              label: '1×',
              secondaryLabel: '24mm',
              isActive: _zoomFactor < 1.8,
              accentColor: kIosYellow,
            ),
            pillKey: const ValueKey('portrait_pill_1x'),
            onTap: () => _applyPortraitOpticalZoom(1.0),
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'portrait_2x',
              label: '2×',
              secondaryLabel: '48mm',
              isActive: _zoomFactor >= 1.8 && _zoomFactor < 2.7,
              accentColor: kIosYellow,
            ),
            pillKey: const ValueKey('portrait_pill_2x'),
            onTap: () => _applyPortraitOpticalZoom(2.0),
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'portrait_3x',
              label: '3×',
              secondaryLabel: '77mm',
              isActive: _zoomFactor >= 2.7,
              accentColor: kIosYellow,
            ),
            pillKey: const ValueKey('portrait_pill_3x'),
            onTap: () => _applyPortraitOpticalZoom(3.0),
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'portrait_peaking',
              label: 'PEAKING',
              isActive: _showFocusPeaking,
              accentColor: const Color(0xFF30D158),
            ),
            pillKey: const ValueKey('portrait_pill_peaking'),
            onTap: () {
              _triggerRadialHaptic();
              setState(() => _showFocusPeaking = !_showFocusPeaking);
            },
            onLongPress: null,
          ),
        ];

      case 3: // VİDEO (Cinema Quick Deck features moved to Outermost Ring 2 when radial dial is active)
      default:
        return [
          for (final lens in _cinemaLensOptions)
            (
              spec: RadialOuterFeatureSpec(
                id: 'vid_lens_${lens.id}',
                label: lens.label,
                isActive: _activeCinemaLensOptionId == lens.id,
                accentColor: kIosYellow,
              ),
              pillKey: null,
              onTap: () {
                final z = double.tryParse(lens.id) ?? 1.0;
                final targetCam = z < 0.95
                    ? '3'
                    : (z >= 2.7 && _telephotoCameraId != null
                        ? _telephotoCameraId!
                        : '2');
                if (!_isVideoRecording && targetCam != _selectedCameraId) {
                  _startOrSwitchVideoCamera(targetCam, keepZoom: z);
                } else {
                  setState(() => _zoomFactor = z);
                  _scheduleNativeControlsPush(artworkMode: false);
                }
              },
              onLongPress: null,
            ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'vid_pt_a',
              label: 'ODAK A',
              isActive: _hasFocusPointA,
              accentColor: kIosYellow,
            ),
            pillKey: null,
            onTap: () {
              _triggerRadialHaptic();
              setState(() {
                _manualFocus = true;
                _focusPullPointA = _focusDistance;
                _hasFocusPointA = true;
                _statusBanner =
                    'Odak Noktası A kilitlendi (%${(_focusPullPointA * 100).round()})';
              });
              _scheduleNativeControlsPush(artworkMode: false);
            },
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'vid_pt_b',
              label: 'ODAK B',
              isActive: _hasFocusPointB,
              accentColor: kIosYellow,
            ),
            pillKey: null,
            onTap: () {
              _triggerRadialHaptic();
              setState(() {
                _manualFocus = true;
                _focusPullPointB = _focusDistance;
                _hasFocusPointB = true;
                _statusBanner =
                    'Odak Noktası B kilitlendi (%${(_focusPullPointB * 100).round()})';
              });
              _scheduleNativeControlsPush(artworkMode: false);
            },
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'vid_rack_ab',
              label: 'A↔B GEÇİŞ',
              isActive: _isPullingFocus,
              accentColor: kZameraCyan,
            ),
            pillKey: null,
            onTap: _triggerVideoFocusPull,
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'vid_rack_dur',
              label: '${(_rackFocusDurationMs / 1000.0).toStringAsFixed(1)}s HIZ',
              isActive: false,
              accentColor: kIosYellow,
            ),
            pillKey: null,
            onTap: () {
              _triggerRadialHaptic();
              setState(() {
                _rackFocusDurationMs = _rackFocusDurationMs <= 900
                    ? 2000
                    : (_rackFocusDurationMs <= 2100 ? 3500 : 800);
              });
            },
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'vid_eis',
              label: _videoStabilization ? 'EIS AÇIK' : 'EIS SAF',
              isActive: _videoStabilization,
              accentColor: kZameraCyan,
            ),
            pillKey: null,
            onTap: _isVideoRecording
                ? null
                : () {
                    _triggerRadialHaptic();
                    setState(() {
                      _videoStabilization = !_videoStabilization;
                    });
                    _startOrSwitchVideoCamera(
                      _selectedCameraId,
                      keepZoom: _zoomFactor,
                    );
                  },
            onLongPress: null,
          ),
          (
            spec: RadialOuterFeatureSpec(
              id: 'vid_ael',
              label: 'AEL KİLİT',
              isActive: _aeAfLocked,
              accentColor: kIosYellow,
            ),
            pillKey: null,
            onTap: _toggleAeAfLock,
            onLongPress: null,
          ),
        ];
    }
  }

  List<RadialArcFeatureNode> _buildRadialArcNodesForMode(int modeIndex) {
    final items = _aboveShutterFeaturesForMode(modeIndex);
    return [
      for (final item in items)
        RadialArcFeatureNode(
          id: item.spec.id,
          primaryLabel: item.spec.label,
          secondaryLabel: item.spec.secondaryLabel,
          isActive: item.spec.isActive,
          accentColor: item.spec.accentColor,
          key: item.pillKey,
          icon: item.spec.icon,
          onTap: item.onTap,
          onLongPress: item.onLongPress,
        ),
    ];
  }

  /// Returns the secondary option labels for Ring 1 (middle concentric ring).
  /// Decoupled from Ring 0 (_continuousWheelNorm) and Ring 2 (_outerFeatureArcScrollPos).
  List<({String label, VoidCallback onSelect, bool applyOnDrag})>
      _secondaryRingOptionsForDial(
    ActiveProDial dial, {
    required bool isVideo,
  }) {
    if (dial == ActiveProDial.focus) {
      final distStr = _formatFocusDistance(
        (_liveTelemetry['focusDistanceDiopters'] as num?)?.toDouble(),
      );
      return [
        (
          label: _manualFocus ? 'MF: $distStr' : 'AF (OTOMATİK)',
          applyOnDrag: false,
          onSelect: () {
            setState(() {
              _manualFocus = false;
            });
            _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
          },
        ),
        (
          label: '∞ SONSUZ',
          applyOnDrag: false,
          onSelect: () => _setManualFocusPreset(0.0, syncInnerWheel: false),
        ),
        (
          label: '1.5M PORTRE',
          applyOnDrag: false,
          onSelect: () => _setManualFocusPreset(0.12, syncInnerWheel: false),
        ),
        (
          label: '40CM YAKIN',
          applyOnDrag: false,
          onSelect: () => _setManualFocusPreset(0.35, syncInnerWheel: false),
        ),
        (
          label: '10CM MAKRO',
          applyOnDrag: false,
          onSelect: () => _setManualFocusPreset(1.0, syncInnerWheel: false),
        ),
        if (isVideo) ...[
          (
            label: 'A KAYDET (${(_focusPullPointA * 100).round()}%)',
            applyOnDrag: false,
            onSelect: () {
              setState(() {
                _manualFocus = true;
                _focusPullPointA = _focusDistance;
                _hasFocusPointA = true;
                _statusBanner =
                    'Odak Noktası A kaydedildi: %${(_focusPullPointA * 100).round()}';
              });
            },
          ),
          (
            label: 'B KAYDET (${(_focusPullPointB * 100).round()}%)',
            applyOnDrag: false,
            onSelect: () {
              setState(() {
                _manualFocus = true;
                _focusPullPointB = _focusDistance;
                _hasFocusPointB = true;
                _statusBanner =
                    'Odak Noktası B kaydedildi: %${(_focusPullPointB * 100).round()}';
              });
            },
          ),
          (
            label: 'A↔B ODAK GEÇİŞİ',
            applyOnDrag: false,
            onSelect: _triggerVideoFocusPull,
          ),
          (
            label: 'PEAKING',
            applyOnDrag: false,
            onSelect: () =>
                setState(() => _showFocusPeaking = !_showFocusPeaking),
          ),
        ],
      ];
    } else if (dial == ActiveProDial.portraitLight) {
      return [
        for (int i = 0; i < _kPortraitLightingNames.length; i++)
          (
            label: i == 0 ? 'DOĞAL IŞIK' : _kPortraitLightingNames[i],
            applyOnDrag: true,
            onSelect: () {
              setState(() {
                _portraitLightingIndex = i;
              });
              _scheduleNativeControlsPush(artworkMode: false);
            },
          ),
      ];
    } else if (dial == ActiveProDial.wb) {
      return [
        (
          label: 'AWB (OTO)',
          applyOnDrag: false,
          onSelect: () {
            setState(() {
              _manualWb = false;
              _tint = 0.0;
            });
            _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
          },
        ),
        for (final preset in WbPresetRegistry.presets)
          (
            label: '${preset.labelTr} ${preset.kelvin}K',
            applyOnDrag: false,
            onSelect: () {
              setState(() {
                _manualWb = true;
                _kelvin = preset.kelvin.toDouble();
                _tint = preset.tint;
              });
              _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
            },
          ),
        for (final tintVal in WbPresetRegistry.tintPresets)
          (
            label: tintVal == 0
                ? 'TİNT 0'
                : (tintVal < 0
                    ? 'TİNT ${tintVal.round()}G'
                    : 'TİNT +${tintVal.round()}M'),
            applyOnDrag: true,
            onSelect: () {
              setState(() {
                _manualWb = true;
                _tint = tintVal;
              });
              _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
            },
          ),
      ];
    } else if (dial == ActiveProDial.shutterAngle) {
      return [
        (
          label: 'OTO (180°)',
          applyOnDrag: false,
          onSelect: () {
            setState(() {
              _videoLockShutterAngle = false;
              _videoShutterAngleDeg = 180.0;
            });
            _scheduleNativeControlsPush(artworkMode: false);
          },
        ),
        for (final deg in ZameraCinemaMath.standardShutterAngles)
          (
            label:
                '${deg == deg.roundToDouble() ? deg.round() : deg.toStringAsFixed(1)}°',
            applyOnDrag: false,
            onSelect: () {
              setState(() {
                _videoLockShutterAngle = true;
                _videoShutterAngleDeg = deg;
              });
              _scheduleNativeControlsPush(artworkMode: false);
            },
          ),
      ];
    } else if (dial == ActiveProDial.videoProfile) {
      final profiles = _availableVideoProfiles;
      return [
        for (final prof in profiles)
          (
            label: prof.shortLabel,
            applyOnDrag: false,
            onSelect: () {
              if (_isVideoRecording) return;
              setState(() {
                _videoProfile = prof;
              });
              _startOrSwitchVideoCamera(
                _selectedCameraId,
                keepZoom: _zoomFactor,
              );
            },
          ),
      ];
    } else if (dial == ActiveProDial.videoLut) {
      return [
        for (final preset in ZameraLutPreset.values)
          (
            label: preset.label,
            applyOnDrag: true,
            onSelect: () {
              setState(() {
                _videoLutPreset = preset;
                _videoLutBypass = false;
                if (preset != ZameraLutPreset.customCube) {
                  _customCubeLut = null;
                }
              });
            },
          ),
        (
          label: _customCubeLut != null
              ? '.CUBE (${_customCubeLut!.size}³)'
              : '.CUBE YÜKLE',
          applyOnDrag: false,
          onSelect: _loadCustomCubeLutSample,
        ),
      ];
    }
    return const [];
  }

  double _initialSecondaryScrollIndexForDial(ActiveProDial dial) {
    switch (dial) {
      case ActiveProDial.focus:
        if (!_manualFocus) return 0.0;
        if (_focusDistance <= 0.04) return 1.0;
        if ((_focusDistance - 0.12).abs() < 0.08) return 2.0;
        if ((_focusDistance - 0.35).abs() < 0.15) return 3.0;
        return 4.0;
      case ActiveProDial.portraitLight:
        return _portraitLightingIndex.toDouble();
      case ActiveProDial.wb:
        if (!_manualWb) return 0.0;
        final idx = WbPresetRegistry.presets.indexWhere(
          (p) => (p.kelvin - _kelvin).abs() <= 250,
        );
        return idx >= 0 ? (idx + 1).toDouble() : 1.0;
      case ActiveProDial.shutterAngle:
        if (!_videoLockShutterAngle) return 0.0;
        final idx = ZameraCinemaMath.standardShutterAngles.indexWhere(
          (a) => (a - _videoShutterAngleDeg).abs() < 1.0,
        );
        return idx >= 0 ? (idx + 1).toDouble() : 5.0;
      case ActiveProDial.videoProfile:
        final profiles = _availableVideoProfiles;
        final idx = profiles.indexOf(_videoProfile);
        return (idx >= 0 ? idx : 0).toDouble();
      case ActiveProDial.videoLut:
        if (_customCubeLut != null) {
          return ZameraLutPreset.values.length.toDouble();
        }
        return _videoLutPreset.index.toDouble();
      default:
        return 0.0;
    }
  }

  /// Selects a setting button from the radial arc and immediately opens its radial adjustment wheel
  void _selectRadialSettingDial(ActiveProDial dial, {double? targetZoom}) {
    _triggerRadialHaptic();
    final outerCount = _aboveShutterFeaturesForMode(_selectedMode).length;
    final defaultOuterScroll =
        outerCount > 1 ? ((outerCount - 1) * 0.5) : 0.0;

    if (targetZoom != null) {
      final clamped = targetZoom.clamp(0.5, 10.0);
      final targetCam = clamped < 0.95 ? '3' : '2';
      setState(() {
        _zoomFactor = clamped;
        _radialMenuOpen = true;
        if (_activeDial != ActiveProDial.lens) {
          _outerFeatureArcScrollPos = defaultOuterScroll;
          _lastOuterFeatureHapticIndex = _outerFeatureArcScrollPos.round();
        }
        _activeDial = ActiveProDial.lens;
        _activeDragRingBand = RadialRingBand.none;
        _continuousWheelNorm = _normalizedValueForDial(ActiveProDial.lens);
        _lastHapticTickIndex = (_continuousWheelNorm * 60).round();
      });
      if (targetCam != _selectedCameraId &&
          !_isStartingCamera &&
          !_isVideoRecording) {
        if (_selectedMode == 3) {
          _startOrSwitchVideoCamera(targetCam, keepZoom: clamped);
        } else {
          _startOrSwitchCamera(targetCam, keepZoom: clamped);
        }
      } else {
        _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
      }
      return;
    }

    setState(() {
      _radialMenuOpen = true;
      _activeDragRingBand = RadialRingBand.none;
      if (_activeDial == dial) {
        _activeDial = ActiveProDial.none;
      } else {
        if (_activeDial == ActiveProDial.none) {
          _outerFeatureArcScrollPos = defaultOuterScroll;
          _lastOuterFeatureHapticIndex = _outerFeatureArcScrollPos.round();
        }
        _activeDial = dial;
        _continuousWheelNorm = _normalizedValueForDial(dial);
        _lastHapticTickIndex = (_continuousWheelNorm * 60).round();
        _secondaryArcScrollPos = _initialSecondaryScrollIndexForDial(dial);
        _lastSecondaryHapticIndex = _secondaryArcScrollPos.round();
      }
    });
  }

  /// Radial Fan / Arc of Circular Setting Buttons (.5 · 1× · 2× · MF · EV · ISO · S/AÇI · WB · FPS · PROFİL · LUT · SES)
  /// Opens radially when the user swipes upward on the shutter button in the arrow direction.
  Widget _buildRadialSettingButtonsArc({
    required double width,
    required bool isPortrait,
    required bool isVideo,
  }) {
    final isWide05 = _zoomFactor < 0.95;
    final isZoom1x = _zoomFactor >= 0.95 && _zoomFactor < 1.8;
    final isZoom2x = isPortrait
        ? (_zoomFactor >= 1.8 && _zoomFactor < 2.7)
        : (_zoomFactor >= 1.8);
    final isZoom3x = _zoomFactor >= 2.7;

    final items = <({
      String label,
      bool selected,
      bool activeDialRing,
      VoidCallback onTap,
      void Function(double dx, double screenW)? onDrag,
    })>[
      if (!isPortrait)
        (
          label: '.5',
          selected: isWide05,
          activeDialRing: _activeDial == ActiveProDial.lens && isWide05,
          onTap: () => _selectRadialSettingDial(
                ActiveProDial.lens,
                targetZoom: 0.5,
              ),
          onDrag: (dx, w) {
            if (_activeDial != ActiveProDial.lens) {
              setState(() {
                _activeDial = ActiveProDial.lens;
                _continuousWheelNorm =
                    _normalizedValueForDial(ActiveProDial.lens);
              });
            }
            _scrubContinuousWheelByDeltaNorm(
              -dx / (w * 0.42),
              isArtwork: _selectedMode == 0,
            );
          },
        ),
      (
        label: isZoom1x
            ? (isPortrait
                ? '1× 24'
                : '${_zoomFactor.toStringAsFixed(_zoomFactor == _zoomFactor.roundToDouble() ? 0 : 1)}×')
            : '1×',
        selected: isZoom1x,
        activeDialRing: _activeDial == ActiveProDial.lens && isZoom1x,
        onTap: () => _selectRadialSettingDial(
              ActiveProDial.lens,
              targetZoom: 1.0,
            ),
        onDrag: (dx, w) {
          if (_activeDial != ActiveProDial.lens) {
            setState(() {
              _activeDial = ActiveProDial.lens;
              _continuousWheelNorm =
                  _normalizedValueForDial(ActiveProDial.lens);
            });
          }
          _scrubContinuousWheelByDeltaNorm(
            -dx / (w * 0.42),
            isArtwork: _selectedMode == 0,
          );
        },
      ),
      (
        label: isZoom2x
            ? (isPortrait
                ? '2× 48'
                : '${_zoomFactor.toStringAsFixed(_zoomFactor == _zoomFactor.roundToDouble() ? 0 : 1)}×${isVideo ? " DİJ" : ""}')
            : (isVideo ? '2× DİJ' : '2×'),
        selected: isZoom2x,
        activeDialRing: _activeDial == ActiveProDial.lens && isZoom2x,
        onTap: () => _selectRadialSettingDial(
              ActiveProDial.lens,
              targetZoom: 2.0,
            ),
        onDrag: (dx, w) {
          if (_activeDial != ActiveProDial.lens) {
            setState(() {
              _activeDial = ActiveProDial.lens;
              _continuousWheelNorm =
                  _normalizedValueForDial(ActiveProDial.lens);
            });
          }
          _scrubContinuousWheelByDeltaNorm(
            -dx / (w * 0.42),
            isArtwork: _selectedMode == 0,
          );
        },
      ),
      if (isPortrait) ...[
        (
          label: isZoom3x ? '3× 77' : '3×',
          selected: isZoom3x,
          activeDialRing: _activeDial == ActiveProDial.lens && isZoom3x,
          onTap: () => _selectRadialSettingDial(
                ActiveProDial.lens,
                targetZoom: 3.0,
              ),
          onDrag: (dx, w) {
            if (_activeDial != ActiveProDial.lens) {
              setState(() {
                _activeDial = ActiveProDial.lens;
                _continuousWheelNorm =
                    _normalizedValueForDial(ActiveProDial.lens);
              });
            }
            _scrubContinuousWheelByDeltaNorm(
              -dx / (w * 0.42),
              isArtwork: false,
            );
          },
        ),
        (
          label: 'ƒ${_portraitAperture.toStringAsFixed(1)}',
          selected: true,
          activeDialRing: _activeDial == ActiveProDial.aperture,
          onTap: () => _selectRadialSettingDial(ActiveProDial.aperture),
          onDrag: null,
        ),
        (
          label: 'IŞIK',
          selected: _portraitLightingIndex > 0 ||
              (_portraitLightIntensity - 0.80).abs() > 0.02,
          activeDialRing: _activeDial == ActiveProDial.portraitLight,
          onTap: () => _selectRadialSettingDial(ActiveProDial.portraitLight),
          onDrag: null,
        ),
      ],
      if (isVideo) ...[
        (
          label: 'FPS',
          selected: _videoFps != 24,
          activeDialRing: _activeDial == ActiveProDial.videoFps,
          onTap: () => _selectRadialSettingDial(ActiveProDial.videoFps),
          onDrag: null,
        ),
        (
          label: 'AÇI',
          selected: (_videoShutterAngleDeg - 180.0).abs() > 1.0,
          activeDialRing: _activeDial == ActiveProDial.shutterAngle,
          onTap: () => _selectRadialSettingDial(ActiveProDial.shutterAngle),
          onDrag: null,
        ),
      ],
      (
        label: 'MF',
        selected: _manualFocus,
        activeDialRing: _activeDial == ActiveProDial.focus,
        onTap: () => _selectRadialSettingDial(ActiveProDial.focus),
        onDrag: null,
      ),
      (
        label: 'EV',
        selected: _evCompensation.abs() > 0.05,
        activeDialRing: _activeDial == ActiveProDial.ev,
        onTap: () => _selectRadialSettingDial(ActiveProDial.ev),
        onDrag: null,
      ),
      (
        label: 'ISO',
        selected: _selectedMode == 1 ? _dslrMode.isIsoManual : _manualExposure,
        activeDialRing: _activeDial == ActiveProDial.iso,
        onTap: () => _selectRadialSettingDial(ActiveProDial.iso),
        onDrag: null,
      ),
      if (!isPortrait && !isVideo)
        (
          label: 'S',
          selected:
              _selectedMode == 1 ? _dslrMode.isShutterManual : _manualExposure,
          activeDialRing: _activeDial == ActiveProDial.shutter,
          onTap: () => _selectRadialSettingDial(ActiveProDial.shutter),
          onDrag: null,
        ),
      (
        label: 'WB',
        selected: _manualWb,
        activeDialRing: _activeDial == ActiveProDial.wb,
        onTap: () => _selectRadialSettingDial(ActiveProDial.wb),
        onDrag: null,
      ),
      if (isVideo) ...[
        (
          label: 'PROFİL',
          selected: _videoProfile != ZameraVideoProfile.universalRec709Locked,
          activeDialRing: _activeDial == ActiveProDial.videoProfile,
          onTap: () => _selectRadialSettingDial(ActiveProDial.videoProfile),
          onDrag: null,
        ),
        (
          label: 'LUT',
          selected:
              _videoLutPreset != ZameraLutPreset.none || _customCubeLut != null,
          activeDialRing: _activeDial == ActiveProDial.videoLut,
          onTap: () => _selectRadialSettingDial(ActiveProDial.videoLut),
          onDrag: null,
        ),
        (
          label: 'SES',
          selected: _selectedAudioDeviceId != 'default',
          activeDialRing: _activeDial == ActiveProDial.videoAudio,
          onTap: () => _selectRadialSettingDial(ActiveProDial.videoAudio),
          onDrag: null,
        ),
      ],
    ];

    final count = items.length;
    final centerX = width * 0.5;
    if (count > 9) {
      // Clean 2-tier concentric arc for Pro Cinema Video (zero overlap, >20px spacing)
      final outerItems = items
          .where(
            (it) =>
                it.label != 'FPS' &&
                it.label != 'AÇI' &&
                it.label != 'PROFİL' &&
                it.label != 'LUT' &&
                it.label != 'SES',
          )
          .toList();
      final innerItems = items
          .where(
            (it) =>
                it.label == 'FPS' ||
                it.label == 'AÇI' ||
                it.label == 'PROFİL' ||
                it.label == 'LUT' ||
                it.label == 'SES',
          )
          .toList();
      final outerRadius = math.min(width * 0.46, 182.0);
      final innerRadius = math.min(width * 0.35, 134.0);
      const dualCenterY = 226.0;
      const outerStart = -math.pi * 0.82;
      const outerEnd = -math.pi * 0.18;
      const innerStart = -math.pi * 0.78;
      const innerEnd = -math.pi * 0.22;
      final splitRadius = (outerRadius + innerRadius) * 0.5;

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          final dist =
              (details.localPosition - Offset(centerX, dualCenterY)).distance;
          _draggingMenuOuterButtonArc = dist >= splitRadius;
        },
        onHorizontalDragUpdate: (details) {
          final dx = details.delta.dx;
          setState(() {
            if (_draggingMenuOuterButtonArc) {
              _menuOuterArcOffsetRad =
                  (_menuOuterArcOffsetRad + dx / outerRadius).clamp(-0.28, 0.28);
            } else {
              _menuInnerArcOffsetRad =
                  (_menuInnerArcOffsetRad + dx / innerRadius).clamp(-0.28, 0.28);
            }
          });
        },
        child: SizedBox(
          width: width,
          height: 168,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: RadialButtonsGuideArcPainter(
                      arcCenter: Offset(centerX, dualCenterY),
                      arcRadius: outerRadius,
                      startAngle: outerStart + _menuOuterArcOffsetRad,
                      sweepAngle: outerEnd - outerStart,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: RadialButtonsGuideArcPainter(
                      arcCenter: Offset(centerX, dualCenterY),
                      arcRadius: innerRadius,
                      startAngle: innerStart + _menuInnerArcOffsetRad,
                      sweepAngle: innerEnd - innerStart,
                    ),
                  ),
                ),
              ),
              for (int i = 0; i < outerItems.length; i++)
                Builder(
                  builder: (context) {
                    final t = outerItems.length > 1
                        ? i / (outerItems.length - 1)
                        : 0.5;
                    final angle = outerStart +
                        t * (outerEnd - outerStart) +
                        _menuOuterArcOffsetRad;
                    final bx = centerX + outerRadius * math.cos(angle);
                    final by = dualCenterY + outerRadius * math.sin(angle);
                    final item = outerItems[i];
                    return Positioned(
                      left: bx - 19,
                      top: by - 19,
                      child: _buildCircularTriggerButton(
                        label: item.label,
                        selected: item.selected,
                        activeDialRing: item.activeDialRing,
                        onTap: item.onTap,
                        onHorizontalDragUpdate: item.onDrag,
                      ),
                    );
                  },
                ),
              for (int i = 0; i < innerItems.length; i++)
                Builder(
                  builder: (context) {
                    final t = innerItems.length > 1
                        ? i / (innerItems.length - 1)
                        : 0.5;
                    final angle = innerStart +
                        t * (innerEnd - innerStart) +
                        _menuInnerArcOffsetRad;
                    final bx = centerX + innerRadius * math.cos(angle);
                    final by = dualCenterY + innerRadius * math.sin(angle);
                    final item = innerItems[i];
                    return Positioned(
                      left: bx - 19,
                      top: by - 19,
                      child: _buildCircularTriggerButton(
                        label: item.label,
                        selected: item.selected,
                        activeDialRing: item.activeDialRing,
                        onTap: item.onTap,
                        onHorizontalDragUpdate: item.onDrag,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }

    final arcRadius = math.min(width * 0.46, 176.0);
    const arcCenterY = 202.0;
    const startAngle = -math.pi * 0.84;
    const endAngle = -math.pi * 0.16;

    return SizedBox(
      width: width,
      height: 118,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Subtle radial guide arc connecting the buttons
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: RadialButtonsGuideArcPainter(
                  arcCenter: Offset(centerX, arcCenterY),
                  arcRadius: arcRadius,
                  startAngle: startAngle,
                  sweepAngle: endAngle - startAngle,
                ),
              ),
            ),
          ),
          for (int i = 0; i < count; i++)
            Builder(
              builder: (context) {
                final t = count > 1 ? i / (count - 1) : 0.5;
                final angle = startAngle + t * (endAngle - startAngle);
                final bx = centerX + arcRadius * math.cos(angle);
                final by = arcCenterY + arcRadius * math.sin(angle);
                final item = items[i];
                return Positioned(
                  left: bx - 19,
                  top: by - 19,
                  child: _buildCircularTriggerButton(
                    label: item.label,
                    selected: item.selected,
                    activeDialRing: item.activeDialRing,
                    onTap: item.onTap,
                    onHorizontalDragUpdate: item.onDrag,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCircularTriggerButton({
    required String label,
    required bool selected,
    bool activeDialRing = false,
    required VoidCallback onTap,
    void Function(double dx, double screenW)? onHorizontalDragUpdate,
  }) {
    final screenW = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      key: ValueKey<String>('radial_menu_btn_$label'),
      onTap: onTap,
      onHorizontalDragUpdate: onHorizontalDragUpdate != null
          ? (d) => onHorizontalDragUpdate(d.primaryDelta ?? 0.0, screenW)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: BoxConstraints(
          minWidth: activeDialRing ? 36 : 32,
          minHeight: activeDialRing ? 36 : 32,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: activeDialRing
              ? kIosYellow.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: selected ? 0.65 : 0.40),
          border: Border.all(
            color: activeDialRing
                ? kIosYellow
                : (selected
                    ? kIosYellow.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.15)),
            width: activeDialRing ? 1.4 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: activeDialRing ? 11 : 10,
            fontWeight:
                (selected || activeDialRing) ? FontWeight.w800 : FontWeight.w600,
            color: (selected || activeDialRing) ? kIosYellow : Colors.white,
          ),
        ),
      ),
    );
  }

  /// Authentic iOS Camera Full-Bottom Semi-Circular Rotating Radial Dome
  /// with 3 strictly independent concentric rings (Ring 0 Primary, Ring 1 Secondary, Ring 2 Outermost Mode Features).
  Widget _buildIosFullBottomRadialDome({
    required bool isArtwork,
    required bool isVideo,
    required double width,
  }) {
    final dial = _activeDial;
    final norm = _continuousWheelNorm;
    final supportsFocus = _activeCameraCap?.supportsVariableFocus ?? true;
    final secondaryOpts = _secondaryRingOptionsForDial(dial, isVideo: isVideo);
    final outerModeFeatures = _aboveShutterFeaturesForMode(_selectedMode);
    final wheelRadius = RadialRingGeometry.computeInnerWheelRadius(width);
    const wheelHeight = 356.0;
    final wheelCenter = Offset(width * 0.5, wheelHeight - 46.0);

    String centerValueText = '';
    final vIso = _videoTelemetry?.activeIso ?? 0;
    final liveIso = isVideo
        ? (vIso > 0 ? vIso : 100)
        : ((_liveTelemetry['iso'] as num?)?.round() ??
            _lastCaptureResult?.iso ??
            100);
    final vKelvin = _videoTelemetry?.solvedCctKelvin ?? 0;
    final liveKelvin = isVideo
        ? (vKelvin > 0 ? vKelvin : 5500)
        : ((_liveTelemetry['solvedCctKelvin'] as num?)?.round() ?? 5500);
    final liveExpNs = isVideo
        ? _videoTelemetry?.shutterExposureNs
        : ((_liveTelemetry['exposureTimeNs'] as num?)?.toInt() ??
            _lastCaptureResult?.exposureTimeNs);
    final liveShutterLabel = liveExpNs != null && liveExpNs > 0
        ? DslrStopsRegistry.formatShutterNs(liveExpNs)
        : '1/60s';
    final isIsoManualNow =
        _selectedMode == 1 ? _dslrMode.isIsoManual : _manualExposure;
    final isShutterManualNow =
        _selectedMode == 1 ? _dslrMode.isShutterManual : _manualExposure;

    switch (dial) {
      case ActiveProDial.lens:
        centerValueText = _zoomFactor == 1.0
            ? '1.0× (STANDART)'
            : '${_zoomFactor.toStringAsFixed(1)}×';
        break;
      case ActiveProDial.aperture:
        centerValueText = 'ƒ ${_portraitAperture.toStringAsFixed(1)}';
        break;
      case ActiveProDial.portraitLight:
        centerValueText = _portraitLightingIndex == 0
            ? 'DOĞAL (OTO)'
            : '${_kPortraitLightingNames[_portraitLightingIndex]} %${(_portraitLightIntensity * 100).round()}';
        break;
      case ActiveProDial.ev:
        centerValueText = _evCompensation == 0.0
            ? '0.0 EV (OTO)'
            : '${_evCompensation >= 0 ? "+" : ""}${_evCompensation.toStringAsFixed(1)} EV';
        break;
      case ActiveProDial.iso:
        centerValueText = !isIsoManualNow
            ? 'OTO (ISO $liveIso)'
            : '${_iso.round()} ISO';
        break;
      case ActiveProDial.shutter:
        centerValueText = !isShutterManualNow
            ? 'OTO ($liveShutterLabel)'
            : DslrStopsRegistry.formatShutterNs(_shutterExposureNs);
        break;
      case ActiveProDial.wb:
        final tintSuffix = _tint.abs() >= 1.0
            ? ' ${_tint < 0 ? "${_tint.round()}G" : "+${_tint.round()}M"}'
            : '';
        centerValueText = !_manualWb
            ? 'AWB (${liveKelvin}K)'
            : '${_kelvin.round()}K$tintSuffix';
        break;
      case ActiveProDial.focus:
        centerValueText = !_manualFocus
            ? 'AF (OTOMATİK)'
            : !supportsFocus
                ? '∞'
                : _formatFocusDistance(
                    _focusDistance *
                        (_activeCameraCap?.minimumFocusDistanceDiopters ?? 10.0),
                  );
        break;
      case ActiveProDial.shutterAngle:
        final eqShutter = ZameraCinemaMath.formatShutterFromAngle(
          _videoShutterAngleDeg,
          _videoFps,
        );
        final degText = _videoShutterAngleDeg ==
                _videoShutterAngleDeg.roundToDouble()
            ? '${_videoShutterAngleDeg.round()}°'
            : '${_videoShutterAngleDeg.toStringAsFixed(1)}°';
        centerValueText = !_videoLockShutterAngle
            ? 'OTO (180°)'
            : '$degText ($eqShutter)';
        break;
      case ActiveProDial.videoFps:
        centerValueText =
            _videoFps == 30 ? '30 FPS (OTO)' : '$_videoFps FPS';
        break;
      case ActiveProDial.videoProfile:
        centerValueText = _videoProfile.shortLabel;
        break;
      case ActiveProDial.videoLut:
        centerValueText = _customCubeLut != null
            ? _customCubeLut!.title
            : _videoLutPreset.label;
        break;
      case ActiveProDial.videoAudio:
        final activeDev = _audioInputDevices
            .where((d) => d.id == _selectedAudioDeviceId)
            .firstOrNull;
        centerValueText = activeDev?.name ?? 'Dahili Mik.';
        break;
      case ActiveProDial.none:
        break;
    }

    final hasSecondary = secondaryOpts.isNotEmpty;
    final hasOuter = outerModeFeatures.isNotEmpty;
    final clampedOuterScroll = hasOuter
        ? _outerFeatureArcScrollPos.clamp(
            0.0,
            (outerModeFeatures.length - 1).toDouble(),
          )
        : 0.0;

    return GestureDetector(
      key: const ValueKey('radial_concentric_dome_gesture'),
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        final hitBand = RadialRingGeometry.hitTestBand(
          point: details.localPosition,
          center: wheelCenter,
          innerWheelRadius: wheelRadius,
          hasSecondary: hasSecondary,
          hasOuterFeature: hasOuter,
        );
        setState(() {
          _activeDragRingBand = hitBand;
        });
      },
      onPanUpdate: (details) {
        switch (_activeDragRingBand) {
          case RadialRingBand.outerFeature:
            if (!hasOuter) return;
            final nextOuter = RadialRingGeometry.scrollPosAfterDrag(
              currentScrollPos: clampedOuterScroll,
              deltaDx: details.delta.dx,
              itemCount: outerModeFeatures.length,
            );
            setState(() {
              _outerFeatureArcScrollPos = nextOuter;
            });
            final outerIdx =
                nextOuter.round().clamp(0, outerModeFeatures.length - 1);
            if (outerIdx != _lastOuterFeatureHapticIndex) {
              _lastOuterFeatureHapticIndex = outerIdx;
              _triggerRadialHaptic();
            }
            return;

          case RadialRingBand.middleSecondary:
            if (!hasSecondary) return;
            final nextSecondary = RadialRingGeometry.scrollPosAfterDrag(
              currentScrollPos: _secondaryArcScrollPos,
              deltaDx: details.delta.dx,
              itemCount: secondaryOpts.length,
            );
            setState(() {
              _secondaryArcScrollPos = nextSecondary;
            });
            final activeIdx =
                nextSecondary.round().clamp(0, secondaryOpts.length - 1);
            if (activeIdx != _lastSecondaryHapticIndex) {
              _lastSecondaryHapticIndex = activeIdx;
              _triggerRadialHaptic();
              if (secondaryOpts[activeIdx].applyOnDrag) {
                secondaryOpts[activeIdx].onSelect();
              }
            }
            return;

          case RadialRingBand.innerPrimary:
            final dx = details.delta.dx;
            final dy = details.delta.dy;
            final local = details.localPosition;
            final sideSign = local.dx < width * 0.5 ? -1.0 : 1.0;
            final combinedDelta = dx - (dy * 0.35 * sideSign);
            _scrubContinuousWheelByDeltaNorm(
              -combinedDelta / (width * 0.42),
              isArtwork: isArtwork,
            );
            return;

          case RadialRingBand.none:
            return;
        }
      },
      onPanEnd: (_) {
        if (_activeDragRingBand != RadialRingBand.none) {
          setState(() => _activeDragRingBand = RadialRingBand.none);
        }
      },
      onPanCancel: () {
        if (_activeDragRingBand != RadialRingBand.none) {
          setState(() => _activeDragRingBand = RadialRingBand.none);
        }
      },
      onTapUp: (details) {
        final local = details.localPosition;
        final tappedBand = RadialRingGeometry.hitTestBand(
          point: local,
          center: wheelCenter,
          innerWheelRadius: wheelRadius,
          hasSecondary: hasSecondary,
          hasOuterFeature: hasOuter,
        );
        if (tappedBand == RadialRingBand.outerFeature && hasOuter) {
          final tappedIdx = RadialRingGeometry.hitTestArcItemIndex(
            point: local,
            center: wheelCenter,
            currentScrollPos: clampedOuterScroll,
            itemCount: outerModeFeatures.length,
            angleStep: IosCameraRadialWheelPainter.kOuterFeatureItemAngleStep,
          );
          if (tappedIdx != null) {
            _triggerRadialHaptic();
            setState(() {
              _outerFeatureArcScrollPos = tappedIdx.toDouble();
              _lastOuterFeatureHapticIndex = tappedIdx;
            });
            outerModeFeatures[tappedIdx].onTap?.call();
          }
          return;
        }

        if (tappedBand == RadialRingBand.middleSecondary && hasSecondary) {
          final tappedIdx = RadialRingGeometry.hitTestArcItemIndex(
            point: local,
            center: wheelCenter,
            currentScrollPos: _secondaryArcScrollPos,
            itemCount: secondaryOpts.length,
            angleStep: IosCameraRadialWheelPainter.kSecondaryItemAngleStep,
          );
          if (tappedIdx != null) {
            _triggerRadialHaptic();
            setState(() {
              _secondaryArcScrollPos = tappedIdx.toDouble();
              _lastSecondaryHapticIndex = tappedIdx;
            });
            secondaryOpts[tappedIdx].onSelect();
          }
        }
      },
      child: CustomPaint(
        size: Size(width, wheelHeight),
        painter: IosCameraRadialWheelPainter(
          dial: dial,
          normalizedValue: norm,
          centerValueText: centerValueText,
          stops: _majorStopsForDial(dial),
          secondaryItems: [for (final o in secondaryOpts) o.label],
          secondaryScrollPos: _secondaryArcScrollPos,
          outerFeatureItems: [for (final f in outerModeFeatures) f.spec],
          outerFeatureScrollPos: clampedOuterScroll,
          activeRingBand: _activeDragRingBand,
        ),
      ),
    );
  }

  List<({double norm, String primary, String secondary})> _majorStopsForDial(
    ActiveProDial dial,
  ) {
    switch (dial) {
      case ActiveProDial.lens:
        final minL = math.log(0.5);
        final maxL = math.log(10.0);
        double normOf(double z) => (math.log(z) - minL) / (maxL - minL);
        return [
          (norm: normOf(0.5), primary: '0.5', secondary: '13 MM'),
          (norm: normOf(1.0), primary: '1', secondary: '26 MM'),
          (norm: normOf(2.0), primary: '2', secondary: '52 MM'),
          (norm: normOf(5.0), primary: '5', secondary: '120 MM'),
          (norm: normOf(10.0), primary: '10', secondary: ''),
        ];
      case ActiveProDial.aperture:
        final minL = math.log(1.4);
        final maxL = math.log(16.0);
        double normOf(double f) => (math.log(f) - minL) / (maxL - minL);
        return [
          (norm: normOf(1.4), primary: '1.4', secondary: 'F'),
          (norm: normOf(2.0), primary: '2.0', secondary: 'F'),
          (norm: normOf(2.8), primary: '2.8', secondary: 'F'),
          (norm: normOf(4.0), primary: '4.0', secondary: 'F'),
          (norm: normOf(5.6), primary: '5.6', secondary: 'F'),
          (norm: normOf(8.0), primary: '8.0', secondary: 'F'),
          (norm: normOf(16.0), primary: '16', secondary: 'F'),
        ];
      case ActiveProDial.portraitLight:
        return const [
          (norm: 0.0, primary: 'OTO', secondary: 'DOĞAL'),
          (norm: 0.25, primary: '25', secondary: '%'),
          (norm: 0.50, primary: '50', secondary: '%'),
          (norm: 0.75, primary: '75', secondary: '%'),
          (norm: 1.0, primary: '100', secondary: '% IŞIK'),
        ];
      case ActiveProDial.ev:
        return const [
          (norm: 0.0, primary: '-3', secondary: 'EV'),
          (norm: 0.167, primary: '-2', secondary: 'EV'),
          (norm: 0.333, primary: '-1', secondary: 'EV'),
          (norm: 0.5, primary: 'OTO', secondary: '0 EV'),
          (norm: 0.667, primary: '+1', secondary: 'EV'),
          (norm: 0.833, primary: '+2', secondary: 'EV'),
          (norm: 1.0, primary: '+3', secondary: 'EV'),
        ];
      case ActiveProDial.iso:
        return const [
          (norm: 0.0, primary: 'OTO', secondary: 'ISO'),
          (norm: 0.16, primary: '100', secondary: 'ISO'),
          (norm: 0.34, primary: '400', secondary: 'ISO'),
          (norm: 0.52, primary: '800', secondary: 'ISO'),
          (norm: 0.70, primary: '1600', secondary: 'ISO'),
          (norm: 0.86, primary: '6400', secondary: 'ISO'),
          (norm: 1.0, primary: '12800', secondary: 'ISO'),
        ];
      case ActiveProDial.shutter:
        return const [
          (norm: 0.0, primary: 'OTO', secondary: 'EXP'),
          (norm: 0.14, primary: '15"', secondary: 'UZUN'),
          (norm: 0.30, primary: '1"', secondary: 'SN'),
          (norm: 0.50, primary: '1/30', secondary: 'S'),
          (norm: 0.68, primary: '1/125', secondary: 'S'),
          (norm: 0.85, primary: '1/1000', secondary: 'S'),
          (norm: 1.0, primary: '1/8000', secondary: 'S'),
        ];
      case ActiveProDial.wb:
        return const [
          (norm: 0.0, primary: 'OTO', secondary: 'AWB'),
          (norm: 0.20, primary: '3200', secondary: 'K'),
          (norm: 0.45, primary: '4500', secondary: 'K'),
          (norm: 0.70, primary: '5500', secondary: 'GÜN'),
          (norm: 0.85, primary: '6500', secondary: 'BULUT'),
          (norm: 1.0, primary: '8500', secondary: 'GÖLGE'),
        ];
      case ActiveProDial.focus:
        return const [
          (norm: 0.0, primary: 'OTO', secondary: 'AF'),
          (norm: 0.20, primary: '∞', secondary: 'SONSUZ'),
          (norm: 0.42, primary: '2.0', secondary: 'M'),
          (norm: 0.70, primary: '40', secondary: 'CM'),
          (norm: 1.0, primary: '10', secondary: 'MAKRO'),
        ];
      case ActiveProDial.shutterAngle:
        return const [
          (norm: 0.0, primary: 'OTO', secondary: '180°'),
          (norm: 0.20, primary: '45°', secondary: 'AÇI'),
          (norm: 0.40, primary: '90°', secondary: 'AÇI'),
          (norm: 0.60, primary: '180°', secondary: 'SİNEMA'),
          (norm: 0.80, primary: '270°', secondary: 'AÇI'),
          (norm: 1.0, primary: '360°', secondary: 'AÇI'),
        ];
      case ActiveProDial.videoFps:
        return const [
          (norm: 0.0, primary: 'OTO', secondary: '30P'),
          (norm: 0.333, primary: '24', secondary: 'SİNEMA'),
          (norm: 0.667, primary: '30', secondary: 'NTSC'),
          (norm: 1.0, primary: '60', secondary: 'AKICI'),
        ];
      case ActiveProDial.videoProfile:
        final profiles = _availableVideoProfiles;
        if (profiles.isEmpty) return const [];
        return [
          for (int i = 0; i < profiles.length; i++)
            (
              norm: profiles.length > 1 ? i / (profiles.length - 1) : 0.0,
              primary: profiles[i].shortLabel,
              secondary: profiles[i].isTenBit ? '10-BİT' : 'SDR 8B',
            ),
        ];
      case ActiveProDial.videoLut:
        return const [
          (norm: 0.0, primary: 'YOK', secondary: 'KAPALI'),
          (norm: 0.25, primary: 'REC.709', secondary: 'İZLEME'),
          (norm: 0.50, primary: 'SICAK', secondary: 'SİNEMA'),
          (norm: 0.75, primary: 'NOIR', secondary: 'MONO'),
          (norm: 1.0, primary: '.CUBE', secondary: 'ÖZEL'),
        ];
      case ActiveProDial.videoAudio:
        return const [
          (norm: 0.0, primary: 'DAHİLİ', secondary: 'MİK'),
          (norm: 0.50, primary: 'USB-C', secondary: 'HARİCİ'),
          (norm: 1.0, primary: 'BT', secondary: 'KABLOSUZ'),
        ];
      case ActiveProDial.none:
        return const [];
    }
  }

  /// Interactive Cinema Pro Video Top HUD Overlay (SMPTE Timecode, Clickable 4K/FPS/180°/Profile/LUT+BYPASS, Broadcast dBFS Meter)
  Widget _buildInteractiveVideoCinemaHud() {
    final tel = _videoTelemetry;
    final tc = tel?.timecodeString ?? '00:00:00:00';
    final peakDb = tel?.samplePeakDbfs ?? -60.0;
    final rmsDb = tel?.rmsDbfs ?? -60.0;
    final thermal = tel?.thermalLevel ?? ZameraThermalLevel.normal;
    final remMin = (tel?.remainingRecordSeconds ?? 0) / 60.0;
    final ndRec = tel?.ndFilterRecommendation;
    final eqShutter = ZameraCinemaMath.formatShutterFromAngle(
      _videoShutterAngleDeg,
      _videoFps,
    );
    final degText =
        _videoShutterAngleDeg == _videoShutterAngleDeg.roundToDouble()
            ? '${_videoShutterAngleDeg.round()}°'
            : '${_videoShutterAngleDeg.toStringAsFixed(1)}°';
    final hasActiveLut =
        _videoLutPreset != ZameraLutPreset.none || _customCubeLut != null;

    final hud = ProVideoCinemaHud(
      isRecording: _isVideoRecording,
      timecode: tc,
      resolutionLabel: _videoResolutionHeight >= 2160 ? '4K' : '1080P',
      fps: _videoFps,
      fpsOptions: const <int>[24, 25, 30, 60],
      isFpsSelectorOpen: _videoFpsTrayOpen,
      shutterAngleLabel: degText,
      shutterSpeedLabel: eqShutter,
      isShutterLocked: _videoLockShutterAngle,
      activeProfileId: _videoProfile.name,
      profileLabel: _videoProfile.shortLabel,
      isTenBitOverride: _videoProfile.isTenBit,
      profileOptions: _cinemaProfileOptions,
      isProfileSelectorOpen: _videoProfileTrayOpen,
      lutLabel: _customCubeLut?.title ??
          (hasActiveLut ? _videoLutPreset.label : 'LUT YOK'),
      isLutEnabled: hasActiveLut,
      isLutBypassed: _videoLutBypass,
      audioRmsDb: rmsDb,
      audioPeakDb: peakDb,
      thermalLabel: thermal.badgeText,
      isThermalWarning: thermal != ZameraThermalLevel.normal,
      remainingMinutes: remMin > 0 ? remMin.round() : null,
      droppedFrames: tel?.droppedFrameCount ?? 0,
      ndFilterWarning: ndRec != null,
      onCycleResolution: _isVideoRecording
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() {
                _videoResolutionHeight =
                    _videoResolutionHeight >= 2160 ? 1080 : 2160;
              });
              _startOrSwitchVideoCamera(
                _selectedCameraId,
                keepZoom: _zoomFactor,
              );
            },
      onTapFps: _isVideoRecording
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() {
                _videoFpsTrayOpen = !_videoFpsTrayOpen;
                if (_videoFpsTrayOpen) _videoProfileTrayOpen = false;
              });
            },
      onSelectFps: _isVideoRecording
          ? null
          : (nextFps) {
              HapticFeedback.selectionClick();
              setState(() {
                _videoFps = nextFps;
                _videoFpsTrayOpen = false;
              });
              _startOrSwitchVideoCamera(
                _selectedCameraId,
                keepZoom: _zoomFactor,
              );
            },
      onTapShutterAngle: () =>
          _selectRadialSettingDial(ActiveProDial.shutterAngle),
      onToggleShutterLock: () {
        HapticFeedback.selectionClick();
        setState(() {
          _videoLockShutterAngle = !_videoLockShutterAngle;
        });
        _scheduleNativeControlsPush(artworkMode: false);
      },
      onTapProfile: _isVideoRecording
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() {
                _videoProfileTrayOpen = !_videoProfileTrayOpen;
                if (_videoProfileTrayOpen) _videoFpsTrayOpen = false;
              });
            },
      onSelectProfile: _isVideoRecording
          ? null
          : (profId) {
              final matched = _availableVideoProfiles
                  .where((p) => p.name == profId)
                  .firstOrNull;
              if (matched == null) return;
              HapticFeedback.selectionClick();
              setState(() {
                _videoProfile = matched;
                _videoProfileTrayOpen = false;
              });
              _startOrSwitchVideoCamera(
                _selectedCameraId,
                keepZoom: _zoomFactor,
              );
            },
      onTapLut: () => _selectRadialSettingDial(ActiveProDial.videoLut),
      onToggleLutBypass: () {
        HapticFeedback.selectionClick();
        setState(() {
          _videoLutBypass = !_videoLutBypass;
        });
      },
    );

    final lastVideo = _lastVideoResult;
    if (_isVideoRecording || lastVideo == null) {
      return hud;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hud,
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12, width: 0.6),
            ),
            child: Text(
              'SON: ${lastVideo.codec} · ${(lastVideo.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: kZameraCyan,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getDialBadgeName(ActiveProDial dial) {
    switch (dial) {
      case ActiveProDial.lens:
        return 'LENS';
      case ActiveProDial.aperture:
        return 'ƒ';
      case ActiveProDial.portraitLight:
        return 'IŞIK';
      case ActiveProDial.ev:
        return 'EV';
      case ActiveProDial.iso:
        return 'ISO';
      case ActiveProDial.shutter:
        return 'S';
      case ActiveProDial.shutterAngle:
        return 'AÇI';
      case ActiveProDial.videoFps:
        return 'FPS';
      case ActiveProDial.videoProfile:
        return 'PROFİL';
      case ActiveProDial.videoLut:
        return 'LUT';
      case ActiveProDial.videoAudio:
        return 'SES';
      case ActiveProDial.wb:
        return 'WB';
      case ActiveProDial.focus:
        return 'MF';
      case ActiveProDial.none:
        return '';
    }
  }

  String _getActiveDialDisplayValue(ActiveProDial dial) {
    final isVideo = _selectedMode == 3;
    final vIso = _videoTelemetry?.activeIso ?? 0;
    final liveIso = isVideo
        ? (vIso > 0 ? vIso : 100)
        : ((_liveTelemetry['iso'] as num?)?.round() ??
            _lastCaptureResult?.iso ??
            100);
    final vKelvin = _videoTelemetry?.solvedCctKelvin ?? 0;
    final liveKelvin = isVideo
        ? (vKelvin > 0 ? vKelvin : 5500)
        : ((_liveTelemetry['solvedCctKelvin'] as num?)?.round() ?? 5500);
    final supportsFocus = _activeCameraCap?.supportsVariableFocus ?? true;
    final isIsoManualNow =
        _selectedMode == 1 ? _dslrMode.isIsoManual : _manualExposure;
    final isShutterManualNow =
        _selectedMode == 1 ? _dslrMode.isShutterManual : _manualExposure;

    switch (dial) {
      case ActiveProDial.lens:
        return _zoomFactor == 1.0
            ? '1.0× OTO'
            : '${_zoomFactor.toStringAsFixed(1)}×';
      case ActiveProDial.aperture:
        return 'ƒ ${_portraitAperture.toStringAsFixed(1)}';
      case ActiveProDial.portraitLight:
        return _portraitLightingIndex == 0
            ? 'DOĞAL (OTO)'
            : _kPortraitLightingNames[_portraitLightingIndex];
      case ActiveProDial.ev:
        return _evCompensation == 0.0
            ? '0.0 (OTO)'
            : '${_evCompensation >= 0 ? "+" : ""}${_evCompensation.toStringAsFixed(1)}';
      case ActiveProDial.iso:
        return !isIsoManualNow ? 'OTO (ISO $liveIso)' : '${_iso.round()}';
      case ActiveProDial.shutter:
        return !isShutterManualNow
            ? 'OTO'
            : DslrStopsRegistry.formatShutterNs(_shutterExposureNs);
      case ActiveProDial.wb:
        final tintSuffix = _tint.abs() >= 1.0
            ? ' ${_tint < 0 ? "${_tint.round()}G" : "+${_tint.round()}M"}'
            : '';
        return !_manualWb
            ? 'AWB (${liveKelvin}K)'
            : '${_kelvin.round()}K$tintSuffix';
      case ActiveProDial.focus:
        return !_manualFocus
            ? 'AF (OTO)'
            : !supportsFocus
                ? '∞'
                : _formatFocusDistance(
                    _focusDistance *
                        (_activeCameraCap?.minimumFocusDistanceDiopters ?? 10.0),
                  );
      case ActiveProDial.shutterAngle:
        final degText =
            _videoShutterAngleDeg == _videoShutterAngleDeg.roundToDouble()
                ? '${_videoShutterAngleDeg.round()}°'
                : '${_videoShutterAngleDeg.toStringAsFixed(1)}°';
        return !_videoLockShutterAngle ? 'OTO (180°)' : degText;
      case ActiveProDial.videoFps:
        return _videoFps == 30 ? '30P (OTO)' : '$_videoFps FPS';
      case ActiveProDial.videoProfile:
        return _videoProfile.shortLabel;
      case ActiveProDial.videoLut:
        return _customCubeLut != null
            ? _customCubeLut!.title
            : _videoLutPreset.label;
      case ActiveProDial.videoAudio:
        final activeDev = _audioInputDevices
            .where((d) => d.id == _selectedAudioDeviceId)
            .firstOrNull;
        return activeDev?.name ?? 'Dahili Mik.';
      case ActiveProDial.none:
        return '';
    }
  }

  Widget _buildActiveDialReturnPill() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeDial = ActiveProDial.none;
          _radialMenuOpen = true;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kIosYellow, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: kIosYellow.withValues(alpha: 0.30),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.undo_rounded,
              size: 15,
              color: kIosYellow,
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kIosYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getDialBadgeName(_activeDial),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getActiveDialDisplayValue(_activeDial),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.tune_rounded,
              size: 14,
              color: kIosYellow,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIosCameraDeck({
    required bool isArtwork,
    required bool isProPhoto,
    required bool isPortrait,
    required bool isVideo,
  }) {
    final lastRes = _lastCaptureResult;
    final thumbFile =
        lastRes?.jpegPath != null ? File(lastRes!.jpegPath!) : null;
    final hasThumb = thumbFile != null && thumbFile.existsSync();

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
      decoration: BoxDecoration(
        gradient: _activeDial != ActiveProDial.none
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.52),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Return to Radial Settings Menu Pill Button (Displayed directly above SANAT · PRO · PORTRE · VİDEO)
          if (_activeDial != ActiveProDial.none) ...[
            _buildActiveDialReturnPill(),
            const SizedBox(height: 8),
          ],
          // Row 1: Shortened iOS Camera Mode Strip (SANAT · PRO · PORTRE · VİDEO)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIosModeTab('SANAT', 0),
                const SizedBox(width: 24),
                _buildIosModeTab('PRO', 1),
                const SizedBox(width: 24),
                _buildIosModeTab('PORTRE', 2),
                const SizedBox(width: 24),
                _buildIosModeTab('VİDEO', 3),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Row 2: Thumbnail | Arrow + Pure iOS Concentric White/Red Shutter | Camera Flip / Pro Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: iOS Squircle Last Capture Thumbnail (Tap for Post-Capture Refocus & Subject Copy!)
              GestureDetector(
                onTap: lastRes != null ? _showLastCaptureInspectorModal : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasThumb ? kIosYellow : Colors.white12,
                          width: hasThumb ? 1.3 : 0.8,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasThumb
                          ? Image.file(
                              thumbFile,
                              key: ValueKey(thumbFile.path),
                              fit: BoxFit.cover,
                            )
                          : const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white54,
                              size: 20,
                            ),
                    ),
                    if (hasThumb)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: kIosYellow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'f · ✂',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Center: Background-Free Chevron Arrow directly above the Shutter Button + Swipe-to-Open Radial Settings!
              GestureDetector(
                key: const ValueKey('shutter_button_gesture'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) {
                  _shutterVerticalDragDy = 0.0;
                },
                onVerticalDragUpdate: (details) {
                  _shutterVerticalDragDy += details.primaryDelta ?? 0.0;
                  if (_shutterVerticalDragDy < -8.0 && !_radialMenuOpen) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _radialMenuOpen = true;
                    });
                  } else if (_shutterVerticalDragDy > 8.0 &&
                      (_radialMenuOpen || _activeDial != ActiveProDial.none)) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _radialMenuOpen = false;
                      _activeDial = ActiveProDial.none;
                    });
                  }
                },
                onTap: _isCapturing
                    ? null
                    : () {
                        if (isVideo) {
                          _toggleVideoRecording();
                        } else {
                          _triggerProCaptureWithDriveMode(
                            isArtworkMode: isArtwork,
                            isPortraitMode: isPortrait,
                          );
                        }
                      },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (_radialMenuOpen ||
                              _activeDial != ActiveProDial.none) {
                            _radialMenuOpen = false;
                            _activeDial = ActiveProDial.none;
                          } else {
                            _radialMenuOpen = true;
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Icon(
                          (_radialMenuOpen ||
                                  _activeDial != ActiveProDial.none)
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 22,
                          color: (_radialMenuOpen ||
                                  _activeDial != ActiveProDial.none)
                              ? kIosYellow
                              : Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      padding: EdgeInsets.all(
                        isVideo && _isVideoRecording ? 18 : 4,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isVideo && _isVideoRecording
                              ? const Color(0xFFFF453A)
                              : Colors.white,
                          width: 3.5,
                        ),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            isVideo && _isVideoRecording ? 8 : 36,
                          ),
                          color: _isCapturing
                              ? Colors.white54
                              : (isVideo
                                  ? const Color(0xFFFF3B30)
                                  : Colors.white),
                        ),
                        alignment: Alignment.center,
                        child: _isCapturing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : ((_selfTimerRemainingSec ?? 0) > 0 && !isVideo
                                ? Text(
                                    '$_selfTimerRemainingSec',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  )
                                : null),
                      ),
                    ),
                  ],
                ),
              ),

              // Right: Clean iOS Circular Button (Flip Front/Back Camera on Tap, Gray Card / AEB on LongPress)
              GestureDetector(
                onTap: () {
                  if (isVideo && _isVideoRecording) return;
                  final nextId = _selectedCameraId == '1' ? '2' : '1';
                  if (isVideo) {
                    _startOrSwitchVideoCamera(nextId, keepZoom: _zoomFactor);
                  } else {
                    _startOrSwitchCamera(nextId);
                  }
                },
                onLongPress: (_isCapturing || isVideo)
                    ? null
                    : () {
                        if (isArtwork) {
                          _triggerPhotoCapture(
                            isArtworkMode: true,
                            lockGrayCardFromCenter: true,
                          );
                        } else {
                          _triggerBracketedCapture();
                        }
                      },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.sync_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIosModeTab(String label, int modeIndex) {
    final selected = _selectedMode == modeIndex;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _applyIdealPresetForMode(modeIndex);
        });
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          letterSpacing: 1.0,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? kIosYellow : Colors.white,
          shadows: const [
            Shadow(
              color: Colors.black54,
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  void _applyPortraitOpticalZoom(double targetZoom) {
    HapticFeedback.selectionClick();
    final clamped = targetZoom.clamp(1.0, 10.0);
    setState(() {
      _zoomFactor = clamped;
      _continuousWheelNorm = _normalizedValueForDial(ActiveProDial.lens);
    });
    if (_selectedCameraId == '3' &&
        !_isStartingCamera &&
        !_isVideoRecording) {
      _startOrSwitchCamera('2', keepZoom: clamped);
    } else {
      _scheduleNativeControlsPush(artworkMode: false);
    }
  }

  void _showLastCaptureInspectorModal() {
    final res = _lastCaptureResult;
    if (res == null) return;
    final isPortraitShot = _selectedMode == 2 || res.portraitDepthActive;
    CaptureInspectorModal.show(
      context,
      captureResult: res,
      initialAperture: _portraitAperture,
      initialLightingIndex: _portraitLightingIndex,
      initialLightIntensity: _portraitLightIntensity,
      subjectRadiusRatio: _portraitSubjectRadius,
      initialFocusTapNorm: _lastFocusTapNorm,
      initialPortraitEnabled: isPortraitShot,
      isPortraitCapture: isPortraitShot,
    );
  }

  void _showCalibrationAndProbeSheet() {
    CalibrationAndProbeSheet.show(
      context,
      calibrationResult: _calibrationResult,
      probeReport: _probeReport,
      activeCameraId: _selectedCameraId,
      onTriggerCameraCalibration: () => _triggerPhotoCapture(
        isArtworkMode: true,
        calibrateColorChecker: true,
      ),
      onResetCalibration: _resetCalibrationForActiveLens,
    );
  }
}
