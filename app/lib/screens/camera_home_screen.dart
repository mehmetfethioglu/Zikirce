import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zamera_capture/zamera_capture.dart';
import 'package:zamera_video/zamera_video.dart';
import '../constants/camera_colors.dart';
import '../models/active_pro_dial.dart';
import '../services/version_tracking_service.dart';
import '../dialogs/release_notes_dialog.dart';
import '../dialogs/settings_sheet.dart';
import '../dialogs/capture_inspector_modal.dart';
import '../dialogs/calibration_probe_sheet.dart';
import '../painters/portrait_studio_painter.dart';
import '../painters/radial_guide_arc_painter.dart';
import '../painters/manual_focus_hud_painter.dart';
import '../painters/radial_wheel_painter.dart';
import '../painters/raw_histogram_painter.dart';
import '../painters/live_zebra_peaking_painter.dart';
import '../painters/viewfinder_grid_painter.dart';

class ZameraHomeScreen extends StatefulWidget {
  final VersionTrackingService? versionService;
  const ZameraHomeScreen({super.key, this.versionService});

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

  // Continuous unquantized wheel position [0.0 .. 1.0] for 120 FPS butter-smooth radial sensitivity
  double _continuousWheelNorm = 0.5;
  int _lastHapticTickIndex = -1;
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
  double _portraitAperture = 2.0;
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

  // Sanat Modu (TrueColor) State — Faz 2.0
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
  bool _normalizeExposure = true;
  bool _useMeasuredGrayCardWb = false;
  List<double>? _measuredGrayCardWbGains;
  List<double>? _measuredFlatField8x6;
  late ColorCheckerCalibrationResult _calibrationResult;

  // Pro Fotoğraf State — Faz 2A & 2B
  bool _manualExposure = false;
  double _evCompensation = 0.0;
  double _iso = 100.0;
  double _shutterDenominator = 125.0; // 1/125 sec
  bool _manualFocus = false;
  double _focusDistance = 0.5;
  bool _manualWb = false;
  double _kelvin = 5500.0;
  double _tint = 0.0;
  final bool _preferProRaw48Mp = false;
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
  ZameraCubeLut3D? _customCubeLut;
  bool _isVideoRecording = false;
  ZameraVideoTelemetry? _videoTelemetry;
  ZameraVideoRecordingResult? _lastVideoResult;
  List<ZameraAudioInputDevice> _audioInputDevices = const [];
  String _selectedAudioDeviceId = 'default';
  double _focusPullPointA = 0.12; // ~1.5m
  double _focusPullPointB = 0.65; // ~30cm
  double _focusPullDurationSec = 2.0;
  bool _focusPullAtB = false;

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
    _recomputeCalibration();
    _runDeviceProbe();
    _telemetryTimer = Timer.periodic(
      const Duration(milliseconds: 350),
      (_) => _pollLiveTelemetry(),
    );
  }

  /// Applies the optimal default parameters for each camera category when first entered.
  /// If the user opens the radial settings afterward, they can freely override any parameter.
  void _applyIdealPresetForMode(int modeIndex, {bool pushToNative = true}) {
    final previousMode = _selectedMode;
    _selectedMode = modeIndex;
    _radialMenuOpen = false;
    _activeDial = ActiveProDial.none;

    switch (modeIndex) {
      case 0: // SANAT — 12.6MP Full-Res TrueColor ΔE00, 8x6 Flat-Field, L*≈94, 1.0x Main Optical
        _zoomFactor = 1.0;
        _fullResolution = true;
        _flatFieldEnabled = true;
        _normalizeExposure = true;
        _useDisplayP3 = false;
        _showPerspectiveGrid = false;
        _applyPerspectiveWarp = false;
        _manualExposure = false;
        _evCompensation = 0.0;
        _iso = 100.0;
        _shutterDenominator = 125.0;
        _manualFocus = false;
        _focusDistance = 0.25;
        _manualWb = false;
        _kelvin = 5500.0;
        _tint = 0.0;
        _showZebra = false;
        _showZebra70 = false;
        _showFalseColor = false;
        _showFocusPeaking = false;
        break;
      case 1: // PRO — 14-Bit DNG + JPEG, Smart Auto Baseline (ISO 100, 1/125s, 5500K) + Zebra
        _zoomFactor = 1.0;
        _fullResolution = true;
        _manualExposure = false;
        _evCompensation = 0.0;
        _iso = 100.0;
        _shutterDenominator = 125.0;
        _manualFocus = false;
        _focusDistance = 0.25;
        _manualWb = false;
        _kelvin = 5500.0;
        _tint = 0.0;
        _showZebra = true;
        _showZebra70 = false;
        _showFalseColor = false;
        _showFocusPeaking = false;
        break;
      case 2: // PORTRE — 1.0x Optical, f/2.0 Creamy Bokeh, Doğal Işık (80%), Auto Face/Subject Focus
        _zoomFactor = 1.0;
        _portraitAperture = 2.0;
        _portraitLightingIndex = 0;
        _portraitLightIntensity = 0.80;
        _portraitSubjectRadius = 0.34;
        _manualExposure = false;
        _evCompensation = 0.0;
        _iso = 100.0;
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
        _zoomFactor = 1.0;
        _videoResolutionHeight = 2160;
        _videoFps = 30;
        _videoShutterAngleDeg = 180.0;
        _videoLockShutterAngle = true;
        _videoStabilization = true;
        _videoProfile = ZameraVideoProfile.universalRec709Locked;
        _videoLutPreset = ZameraLutPreset.rec709Monitor;
        _manualExposure = false;
        _evCompensation = 0.0;
        _iso = 100.0;
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
          cameraId: _selectedCameraId == '3' ? '2' : _selectedCameraId,
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

  void _recomputeCalibration() {
    final measured = ZameraCapture.simulateUncalibratedSensor24(
      redShift: _simulatedSensorWarmth,
      greenShift: 1.18,
      blueShift: 0.82,
    );
    _calibrationResult = ZameraCapture.calibrateColorChecker24(measured);
  }

  Future<void> _pollLiveTelemetry() async {
    if (!mounted || _previewSession == null || _isCapturing) return;
    try {
      final tel = await ZameraCapture.getLiveTelemetry();
      ZameraVideoTelemetry? vidTel;
      if (_selectedMode == 3) {
        vidTel = await ZameraVideo.getVideoTelemetry();
      }
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
      bool steppedDownFps = false;
      setState(() {
        _liveTelemetry = tel;
        if (vidTel != null) {
          _videoTelemetry = vidTel;
          // WP-3.5: Under SEVERE/CRITICAL thermal load, disable Peaking & 3D LUT automatically and step down 60fps -> 30fps
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
        }
        if (trackedFaceCenter != null && _selectedMode == 2) {
          _lastFocusTapNorm = trackedFaceCenter;
          if (trackedFaceRadius != null) {
            _portraitSubjectRadius = trackedFaceRadius;
          }
        }
      });
      if (steppedDownFps) {
        _scheduleNativeControlsPush(artworkMode: false);
      }
    } catch (e) {
      _liveTelemetry['telemetryWarning'] = e.toString();
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
    return (range != null && range.length >= 2) ? range[1].toDouble() : 3200.0;
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
    try {
      await ZameraVideo.updateVideoControls(
        fps: _videoFps,
        shutterAngleDeg: _videoShutterAngleDeg,
        lockShutterAngle: _videoLockShutterAngle,
        manualIso: _manualExposure,
        iso: _iso,
        evCompensation: !_manualExposure ? _evCompensation : 0.0,
        manualWb: _manualWb,
        kelvin: _kelvin,
        tint: _tint,
        manualFocus: supportsFocus && _manualFocus,
        focusDistance: _focusDistance,
        zoomRatio: _effectiveHardwareZoomRatio,
        profile: _videoProfile,
      );
    } catch (e) {
      if (mounted) {
        _liveTelemetry['videoControlWarning'] = e.toString();
      }
    } finally {
      _isPushingControls = false;
      if (_pendingControlsPush && mounted) {
        _pendingControlsPush = false;
        _pushVideoControlsToNative();
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
    setState(() {
      _manualFocus = true;
      _focusPullAtB = !_focusPullAtB;
      _focusDistance = toNorm;
      _statusBanner =
          'A↔B Sinema Odak Geçişi (${_focusPullDurationSec.toStringAsFixed(1)}sn)...';
    });
    try {
      await ZameraVideo.triggerFocusPull(
        fromFocusNorm: fromNorm,
        toFocusNorm: toNorm,
        durationMs: (_focusPullDurationSec * 1000).round(),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
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

  Future<void> _pushManualControlsToNative({required bool artworkMode}) async {
    if (_previewSession == null) return;
    _isPushingControls = true;
    final exposureNs = (1e9 / _shutterDenominator).round();
    final gains = ZameraCapture.kelvinAndTintToRggbGains(_kelvin, _tint);
    final supportsFocus = _activeCameraCap?.supportsVariableFocus ?? true;
    try {
      await ZameraCapture.updateManualControls(
        manualExposure: _manualExposure,
        iso: _iso,
        exposureTimeNs: exposureNs,
        evCompensation: !_manualExposure ? _evCompensation : 0.0,
        manualFocus: supportsFocus && _manualFocus,
        focusDistance: _focusDistance,
        manualWb: _manualWb,
        kelvin: _kelvin,
        tint: _tint,
        rggbGains: gains,
        artworkLinearMode: artworkMode && !_manualExposure && !_manualWb,
        zoomRatio: _effectiveHardwareZoomRatio,
        monoMode: _selectedMode == 2 &&
            (_portraitLightingIndex == 4 ||
                _portraitLightingIndex == 5 ||
                _portraitLightingIndex == 7),
      );
    } catch (e) {
      if (mounted) {
        _liveTelemetry['photoControlWarning'] = e.toString();
      }
    } finally {
      _isPushingControls = false;
      if (_pendingControlsPush && mounted) {
        _pendingControlsPush = false;
        _pushManualControlsToNative(artworkMode: _selectedMode == 0);
      }
    }
  }

  void _resetAllProControlsToAuto() {
    HapticFeedback.mediumImpact();
    setState(() {
      _manualExposure = false;
      _evCompensation = 0.0;
      _manualFocus = false;
      _manualWb = false;
      _tint = 0.0;
      _continuousWheelNorm = _normalizedValueForDial(_activeDial);
      _statusBanner = 'AUTO (AE/AF/AWB)';
    });
    _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
  }

  Future<void> _onViewfinderTapUp(
    TapUpDetails details,
    BoxConstraints constraints,
  ) async {
    if (_topDrawerExpanded) {
      setState(() => _topDrawerExpanded = false);
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
    });
    try {
      await ZameraCapture.setFocusAndMeteringPoint(
        x: normX,
        y: normY,
      );
    } catch (e) {
      if (mounted) {
        _liveTelemetry['focusTapWarning'] = e.toString();
      }
    }
  }

  Future<void> _triggerPhotoCapture({
    required bool isArtworkMode,
    bool isPortraitMode = false,
    bool lockGrayCardFromCenter = false,
  }) async {
    if (_isCapturing) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isCapturing = true;
      _statusBanner = isPortraitMode
          ? 'Portre f/${_portraitAperture.toStringAsFixed(1)} · ${_kPortraitLightingNames[_portraitLightingIndex]} işleniyor...'
          : (isArtworkMode
              ? '14-Bit RAW TrueColor işleniyor...'
              : 'Pro DNG + JPEG çekiliyor...');
    });
    try {
      final cornersFlat = <double>[
        for (final pt in _perspectiveCorners) ...[pt.dx, pt.dy],
      ];
      final res = await ZameraCapture.capturePhoto(
        captureRaw: !isPortraitMode,
        isArtworkMode: isArtworkMode,
        isPortraitMode: isPortraitMode,
        portraitAperture: _portraitAperture,
        portraitLighting: _portraitLightingIndex,
        portraitLightIntensity: _portraitLightIntensity,
        portraitSubjectRadius: _portraitSubjectRadius,
        focusPointX: _lastFocusTapNorm?.dx ?? 0.5,
        focusPointY: _lastFocusTapNorm?.dy ?? 0.44,
        zoomRatio: _effectiveHardwareZoomRatio,
        preferProRaw: !isArtworkMode && _preferProRaw48Mp,
        useDisplayP3: _useDisplayP3,
        fullResolution: _fullResolution,
        normalizeExposure: _normalizeExposure && !_useMeasuredGrayCardWb,
        applyPerspectiveWarp: isArtworkMode && _applyPerspectiveWarp,
        perspectiveCornersNorm:
            (isArtworkMode && _applyPerspectiveWarp) ? cornersFlat : null,
        wbGains: _useMeasuredGrayCardWb ? _measuredGrayCardWbGains : null,
        flatFieldGrid8x6:
            (_flatFieldEnabled && _measuredFlatField8x6 != null)
                ? _measuredFlatField8x6
                : null,
      );
      if (!mounted) return;

      if (lockGrayCardFromCenter) {
        if (res.centerLinearCamRgb != null &&
            res.centerLinearCamRgb!.length >= 3) {
          final cr = res.centerLinearCamRgb![0].clamp(1e-4, 1.0);
          final cg = res.centerLinearCamRgb![1].clamp(1e-4, 1.0);
          final cb = res.centerLinearCamRgb![2].clamp(1e-4, 1.0);
          _measuredGrayCardWbGains = [cg / cr, 1.0, cg / cb];
          _useMeasuredGrayCardWb = true;
        }
        if (res.measuredFlatField8x6 != null &&
            res.measuredFlatField8x6!.length == 48) {
          _measuredFlatField8x6 = res.measuredFlatField8x6;
          _flatFieldEnabled = true;
        }
      }

      setState(() {
        _isCapturing = false;
        _lastCaptureResult = res;
        final cctStr = res.solvedCctKelvin != null
            ? '${res.solvedCctKelvin!.round()}K'
            : '';
        _statusBanner = isPortraitMode
            ? 'Portre f/${_portraitAperture.toStringAsFixed(1)} Kaydedildi'
            : (lockGrayCardFromCenter
                ? 'Gri Kart WB Kilitlendi ($cctStr)'
                : 'Kaydedildi ($cctStr)');
      });
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

  void _setManualFocusPreset(double? normDistance) {
    HapticFeedback.selectionClick();
    setState(() {
      if (normDistance == null) {
        _manualFocus = false;
      } else {
        _manualFocus = true;
        _focusDistance = normDistance.clamp(0.0, 1.0);
        if (_activeDial == ActiveProDial.focus) {
          _continuousWheelNorm = _focusDistance;
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
        if (!_manualExposure) return 0.0;
        final minL = math.log(_isoMin);
        final maxL = math.log(_isoMax);
        final curL = math.log(_iso.clamp(_isoMin, _isoMax));
        return (0.12 + 0.88 * ((curL - minL) / (maxL - minL))).clamp(0.0, 1.0);
      case ActiveProDial.shutter:
        if (!_manualExposure) return 0.0;
        final minL = math.log(2.0);
        final maxL = math.log(4000.0);
        final curL = math.log(_shutterDenominator.clamp(2.0, 4000.0));
        return (0.12 + 0.88 * ((curL - minL) / (maxL - minL))).clamp(0.0, 1.0);
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
        const profiles = [
          ZameraVideoProfile.universalRec709Locked,
          ZameraVideoProfile.androidHlg10Hevc10Bit,
          ZameraVideoProfile.zameraFlatSdr,
        ];
        final idx = profiles.indexOf(_videoProfile);
        return idx < 0 ? 0.0 : (idx / (profiles.length - 1)).clamp(0.0, 1.0);
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
      HapticFeedback.selectionClick();
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
      setState(() {
        if (t < 0.08) {
          _portraitLightingIndex = 0;
          _portraitLightIntensity = 0.80;
        } else {
          _portraitLightIntensity = ((t - 0.08) / 0.92).clamp(0.0, 1.0);
        }
      });
      _scheduleNativeControlsPush(artworkMode: false);
      return;
    }

    bool needsVideoSessionRestart = false;
    setState(() {
      switch (dial) {
        case ActiveProDial.ev:
          _manualExposure = false;
          if ((t - 0.50).abs() < 0.035) {
            _evCompensation = 0.0;
          } else {
            _evCompensation = (t * 6.0 - 3.0).clamp(-3.0, 3.0);
          }
          break;
        case ActiveProDial.iso:
          if (t < 0.08) {
            _manualExposure = false;
          } else {
            final minL = math.log(_isoMin);
            final maxL = math.log(_isoMax);
            _manualExposure = true;
            final normScale = ((t - 0.08) / 0.92).clamp(0.0, 1.0);
            _iso = math.exp(minL + normScale * (maxL - minL))
                .clamp(_isoMin, _isoMax);
          }
          break;
        case ActiveProDial.shutter:
          if (t < 0.08) {
            _manualExposure = false;
          } else {
            final minL = math.log(2.0);
            final maxL = math.log(4000.0);
            _manualExposure = true;
            final normScale = ((t - 0.08) / 0.92).clamp(0.0, 1.0);
            _shutterDenominator = math.exp(minL + normScale * (maxL - minL))
                .clamp(2.0, 4000.0);
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
          const profiles = [
            ZameraVideoProfile.universalRec709Locked,
            ZameraVideoProfile.androidHlg10Hevc10Bit,
            ZameraVideoProfile.zameraFlatSdr,
          ];
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

                // 3. ROTATING iOS RADIAL DOME (Appears when a radial setting button is selected in Photo or Video)
                if (_activeDial != ActiveProDial.none)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 315,
                    child: _buildIosFullBottomRadialDome(
                      isArtwork: isArtwork,
                      width: constraints.maxWidth,
                    ),
                  ),

                // 3B. RADIAL TANGENT OPTIONS ARC (when MF, IŞIK, PROFİL or LUT dial is open)
                // Curved smoothly along the top edge of the rotating radial wheel; rotatable by dragging!
                if (_activeDial == ActiveProDial.focus ||
                    _activeDial == ActiveProDial.portraitLight ||
                    _activeDial == ActiveProDial.videoProfile ||
                    _activeDial == ActiveProDial.videoLut)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 236,
                    height: 84,
                    child: _buildRadialTangentOptionsArc(
                      width: constraints.maxWidth,
                      isVideo: isVideo,
                    ),
                  ),

                // 4. RADIAL SETTING BUTTONS ARC
                // Only visible when radial menu is open and NO specific dial is currently selected!
                // When a setting is selected, this arc hides so icons don't clutter the wheel!
                if (_radialMenuOpen && _activeDial == ActiveProDial.none)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 118,
                    height: 118,
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
              // Top-Left: In Portrait mode shows iconic iOS `f 2.0` circle; otherwise Histogram/RAW circle
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

              // Top-Right: Settings Gear Icon (Release notes, probe, privacy, about)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  SettingsSheet.show(
                    context,
                    onOpenProbe: () => _showCalibrationAndProbeSheet(),
                    onOpenCalibration: () => _showCalibrationAndProbeSheet(),
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
                            label: 'L*≈94',
                            active: _normalizeExposure,
                            onTap: () => setState(
                              () => _normalizeExposure = !_normalizeExposure,
                            ),
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
    final liveZebraRatio =
        (_liveTelemetry['liveZebraRatio'] as num?)?.toDouble() ??
            _videoTelemetry?.liveZebraRatioHigh ??
            lastRes?.zebraRatio ??
            0.0;
    final liveZebraRatio70 =
        (_liveTelemetry['liveZebraRatio70'] as num?)?.toDouble() ??
            _videoTelemetry?.liveZebraRatioLow ??
            0.0;
    final livePeakingScore =
        (_liveTelemetry['liveFocusPeakingScore'] as num?)?.toDouble() ??
            lastRes?.focusPeakingScore ??
            0.0;
    final liveZebraGridRaw = _liveTelemetry['liveZebraGrid16x12'];
    final liveZebraGrid =
        (liveZebraGridRaw is List && liveZebraGridRaw.length == 192)
            ? liveZebraGridRaw.map((e) => (e as num).toDouble()).toList()
            : const <double>[];
    final livePeakingGridRaw = _liveTelemetry['livePeakingGrid16x12'];
    final livePeakingGrid =
        (livePeakingGridRaw is List && livePeakingGridRaw.length == 192)
            ? livePeakingGridRaw.map((e) => (e as num).toDouble()).toList()
            : const <double>[];
    final liveFalseColorRaw = _liveTelemetry['liveFalseColorGrid16x12'];
    final liveFalseColorGrid =
        (liveFalseColorRaw is List && liveFalseColorRaw.length == 192)
            ? liveFalseColorRaw.map((e) => (e as num).toInt()).toList()
            : (_videoTelemetry?.liveFalseColorGrid16x12 ?? const <int>[]);
    final anyManualLocked =
        _manualExposure || _manualWb || _manualFocus || _evCompensation != 0.0;
    final isMonoPortrait = isPortraitMode &&
        (_portraitLightingIndex == 4 ||
            _portraitLightingIndex == 5 ||
            _portraitLightingIndex == 7);
    final isHighKeyMono = isPortraitMode && _portraitLightingIndex == 5;
    final focusCenterNorm = _lastFocusTapNorm ?? const Offset(0.5, 0.44);
    final videoLutMatrix = isVideoMode
        ? ZameraCinemaMath.previewColorMatrixForLut(
            preset: _videoLutPreset,
            profile: _videoProfile,
            customCube: _customCubeLut,
          )
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _onViewfinderTapUp(details, constraints),
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

          // 2. Portrait Mode Live Studio, Venetian Blinds Gobo & Subject Depth Portal Frame (Zero Viewfinder Blur!)
          if (isPortraitMode)
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
                ),
              ),
            ),

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

          // 3B. Cinema Pro Video HUD (Timecode, 180° Shutter Angle, dBFS Peak/RMS Audio Meter, Thermal & Storage Badge)
          if (isVideoMode)
            Positioned(
              top: 50,
              left: 12,
              right: 12,
              child: _buildProVideoCinemaHudOverlay(),
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
              top: isVideoMode ? 118 : 56,
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

          // 6. Top-Center iOS Yellow Badge (Only for Manual Lock in Pro/Sanat)
          if (!isPortraitMode && !isVideoMode && anyManualLocked)
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
              bottom: isPortraitMode ? 220 : 185,
              left: 20,
              right: 20,
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
        ],
      ),
    );
  }

  /// Radial Arc of Option Pills Curved Tangent to the Rotating Bottom Radial Wheel.
  /// Replaces flat horizontal bars so options curve along the radial wheel and spin/scroll smoothly!
  Widget _buildRadialTangentOptionsArc({
    required double width,
    required bool isVideo,
  }) {
    final dial = _activeDial;
    final List<({String label, bool active, VoidCallback onTap})> items = [];

    if (dial == ActiveProDial.focus) {
      final distStr = _formatFocusDistance(
        (_liveTelemetry['focusDistanceDiopters'] as num?)?.toDouble(),
      );
      items.add((
        label: _manualFocus ? 'MF: $distStr' : 'AF (OTOMATİK)',
        active: !_manualFocus,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _manualFocus = false;
            _continuousWheelNorm = 0.0;
          });
          _scheduleNativeControlsPush(artworkMode: _selectedMode == 0);
        },
      ));
      items.add((
        label: '∞ SONSUZ',
        active: _manualFocus && _focusDistance <= 0.04,
        onTap: () => _setManualFocusPreset(0.0),
      ));
      items.add((
        label: '1.5M PORTRE',
        active: _manualFocus && (_focusDistance - 0.12).abs() < 0.05,
        onTap: () => _setManualFocusPreset(0.12),
      ));
      items.add((
        label: '40CM YAKIN',
        active: _manualFocus && (_focusDistance - 0.35).abs() < 0.06,
        onTap: () => _setManualFocusPreset(0.35),
      ));
      items.add((
        label: '10CM MAKRO',
        active: _manualFocus && _focusDistance >= 0.92,
        onTap: () => _setManualFocusPreset(1.0),
      ));
      if (isVideo) {
        items.add((
          label: 'A KAYDET (${(_focusPullPointA * 100).round()}%)',
          active: (_focusDistance - _focusPullPointA).abs() < 0.02,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _manualFocus = true;
              _focusPullPointA = _focusDistance;
              _statusBanner =
                  'Odak Noktası A kaydedildi: %${(_focusPullPointA * 100).round()}';
            });
          },
        ));
        items.add((
          label: 'B KAYDET (${(_focusPullPointB * 100).round()}%)',
          active: (_focusDistance - _focusPullPointB).abs() < 0.02,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _manualFocus = true;
              _focusPullPointB = _focusDistance;
              _statusBanner =
                  'Odak Noktası B kaydedildi: %${(_focusPullPointB * 100).round()}';
            });
          },
        ));
        items.add((
          label: 'SÜRE: ${_focusPullDurationSec.toInt()}SN',
          active: false,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (_focusPullDurationSec <= 1.0) {
                _focusPullDurationSec = 2.0;
              } else if (_focusPullDurationSec <= 2.0) {
                _focusPullDurationSec = 3.0;
              } else if (_focusPullDurationSec <= 3.0) {
                _focusPullDurationSec = 5.0;
              } else {
                _focusPullDurationSec = 1.0;
              }
            });
          },
        ));
        items.add((
          label: 'A↔B ODAK GEÇİŞİ',
          active: false,
          onTap: _triggerVideoFocusPull,
        ));
        items.add((
          label: 'PEAKING',
          active: _showFocusPeaking,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showFocusPeaking = !_showFocusPeaking);
          },
        ));
      }
    } else if (dial == ActiveProDial.portraitLight) {
      for (int i = 0; i < _kPortraitLightingNames.length; i++) {
        final idx = i;
        items.add((
          label: idx == 0 ? 'DOĞAL (OTO)' : _kPortraitLightingNames[idx],
          active: _portraitLightingIndex == idx,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _portraitLightingIndex = idx;
              if (idx == 0) {
                _portraitLightIntensity = 0.80;
                _continuousWheelNorm = 0.0;
              }
            });
            _scheduleNativeControlsPush(artworkMode: false);
          },
        ));
      }
    } else if (dial == ActiveProDial.videoProfile ||
        dial == ActiveProDial.videoLut) {
      for (final prof in ZameraVideoProfile.values) {
        items.add((
          label: prof.shortLabel,
          active: _videoProfile == prof,
          onTap: () {
            if (_isVideoRecording) return;
            HapticFeedback.selectionClick();
            setState(() {
              _videoProfile = prof;
              if (_activeDial == ActiveProDial.videoProfile) {
                _continuousWheelNorm =
                    _normalizedValueForDial(ActiveProDial.videoProfile);
              }
            });
            _startOrSwitchVideoCamera(
              _selectedCameraId,
              keepZoom: _zoomFactor,
            );
          },
        ));
      }
      for (final preset in ZameraLutPreset.values) {
        items.add((
          label: preset.label,
          active: _videoLutPreset == preset && _customCubeLut == null,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _videoLutPreset = preset;
              if (preset != ZameraLutPreset.customCube) {
                _customCubeLut = null;
              }
              if (_activeDial == ActiveProDial.videoLut) {
                _continuousWheelNorm =
                    _normalizedValueForDial(ActiveProDial.videoLut);
              }
            });
          },
        ));
      }
      items.add((
        label: _customCubeLut != null
            ? '.CUBE AKTİF (${_customCubeLut!.size}³)'
            : '.CUBE YÜKLE',
        active: _customCubeLut != null,
        onTap: _loadCustomCubeLutSample,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    const double arcRadius = 240.0;
    const double barHeight = 84.0;

    return SizedBox(
      width: width,
      height: barHeight,
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          setState(() {});
          return false;
        },
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: width * 0.36),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Builder(
                builder: (pillCtx) {
                  double dx = 0.0;
                  final renderObj = pillCtx.findRenderObject();
                  if (renderObj is RenderBox &&
                      renderObj.hasSize &&
                      renderObj.attached) {
                    final pos = renderObj.localToGlobal(Offset.zero);
                    dx = (pos.dx + renderObj.size.width * 0.5) - (width * 0.5);
                  }

                  final clampedDx =
                      dx.clamp(-arcRadius * 0.90, arcRadius * 0.90);
                  final radSq = arcRadius * arcRadius - clampedDx * clampedDx;
                  final dy = (arcRadius - math.sqrt(math.max(0.0, radSq)))
                      .clamp(0.0, barHeight * 0.65);
                  final rotAngle =
                      math.asin((clampedDx / arcRadius).clamp(-0.80, 0.80)) *
                          0.65;

                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.rotate(
                      angle: rotAngle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: GestureDetector(
                          onTap: item.onTap,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: item.active
                                  ? kIosYellow.withValues(alpha: 0.28)
                                  : Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: item.active
                                    ? kIosYellow
                                    : Colors.white.withValues(alpha: 0.22),
                                width: item.active ? 1.4 : 0.8,
                              ),
                              boxShadow: item.active
                                  ? [
                                      BoxShadow(
                                        color:
                                            kIosYellow.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: item.active
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color:
                                    item.active ? kIosYellow : Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Selects a setting button from the radial arc and immediately opens its radial adjustment wheel
  void _selectRadialSettingDial(ActiveProDial dial, {double? targetZoom}) {
    HapticFeedback.selectionClick();
    if (targetZoom != null) {
      final clamped = targetZoom.clamp(0.5, 10.0);
      final targetCam = clamped < 0.95 ? '3' : '2';
      setState(() {
        _zoomFactor = clamped;
        _radialMenuOpen = true;
        _activeDial = ActiveProDial.lens;
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
      if (_activeDial == dial) {
        _activeDial = ActiveProDial.none;
      } else {
        _activeDial = dial;
        _continuousWheelNorm = _normalizedValueForDial(dial);
        _lastHapticTickIndex = (_continuousWheelNorm * 60).round();
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
    final isZoom2x = _zoomFactor >= 1.8;

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
            ? '${_zoomFactor.toStringAsFixed(_zoomFactor == _zoomFactor.roundToDouble() ? 0 : 1)}×'
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
            ? '${_zoomFactor.toStringAsFixed(_zoomFactor == _zoomFactor.roundToDouble() ? 0 : 1)}×${isVideo ? " DİJ" : ""}'
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
        selected: _manualExposure,
        activeDialRing: _activeDial == ActiveProDial.iso,
        onTap: () => _selectRadialSettingDial(ActiveProDial.iso),
        onDrag: null,
      ),
      if (!isPortrait && !isVideo)
        (
          label: 'S',
          selected: _manualExposure,
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
    final arcRadius = math.min(width * 0.46, 176.0);
    const arcCenterY = 202.0;
    final centerX = width * 0.5;
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
  Widget _buildIosFullBottomRadialDome({
    required bool isArtwork,
    required double width,
  }) {
    final dial = _activeDial;
    final norm = _continuousWheelNorm;
    final supportsFocus = _activeCameraCap?.supportsVariableFocus ?? true;

    String centerValueText = '';
    final liveIso = (_liveTelemetry['iso'] as num?)?.round() ??
        _lastCaptureResult?.iso ??
        100;
    final liveKelvin = (_liveTelemetry['solvedCctKelvin'] as num?)?.round() ??
        5500;
    final liveExpNs = (_liveTelemetry['exposureTimeNs'] as num?)?.toInt() ??
        _lastCaptureResult?.exposureTimeNs;
    final liveShutterDenominator = liveExpNs != null && liveExpNs > 0
        ? (1e9 / liveExpNs).round()
        : 60;

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
            : '%${(_portraitLightIntensity * 100).round()}';
        break;
      case ActiveProDial.ev:
        centerValueText = _evCompensation == 0.0
            ? '0.0 EV (OTO)'
            : '${_evCompensation >= 0 ? "+" : ""}${_evCompensation.toStringAsFixed(1)} EV';
        break;
      case ActiveProDial.iso:
        centerValueText = !_manualExposure
            ? 'OTO (ISO $liveIso)'
            : '${_iso.round()} ISO';
        break;
      case ActiveProDial.shutter:
        centerValueText = !_manualExposure
            ? 'OTO (1/${liveShutterDenominator}s)'
            : '1/${_shutterDenominator.round()}s';
        break;
      case ActiveProDial.wb:
        centerValueText =
            !_manualWb ? 'AWB (${liveKelvin}K)' : '${_kelvin.round()}K';
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
        centerValueText = !_videoLockShutterAngle
            ? 'OTO (180°)'
            : '${_videoShutterAngleDeg.round()}° ($eqShutter)';
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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (details) {
        final dx = details.delta.dx;
        final dy = details.delta.dy;
        final local = details.localPosition;
        final sideSign = local.dx < width * 0.5 ? -1.0 : 1.0;
        final combinedDelta = dx - (dy * 0.35 * sideSign);
        _scrubContinuousWheelByDeltaNorm(
          -combinedDelta / (width * 0.42),
          isArtwork: isArtwork,
        );
      },
      child: CustomPaint(
        size: Size(width, 315),
        painter: IosCameraRadialWheelPainter(
          dial: dial,
          normalizedValue: norm,
          centerValueText: centerValueText,
          stops: _majorStopsForDial(dial),
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
          (norm: 0.20, primary: '100', secondary: 'ISO'),
          (norm: 0.36, primary: '200', secondary: 'ISO'),
          (norm: 0.52, primary: '400', secondary: 'ISO'),
          (norm: 0.68, primary: '800', secondary: 'ISO'),
          (norm: 0.84, primary: '1600', secondary: 'ISO'),
          (norm: 1.0, primary: '3200', secondary: 'ISO'),
        ];
      case ActiveProDial.shutter:
        return const [
          (norm: 0.0, primary: 'OTO', secondary: 'EXP'),
          (norm: 0.20, primary: '1/30', secondary: 'S'),
          (norm: 0.40, primary: '1/60', secondary: 'S'),
          (norm: 0.58, primary: '1/125', secondary: 'S'),
          (norm: 0.75, primary: '1/500', secondary: 'S'),
          (norm: 0.90, primary: '1/2000', secondary: 'S'),
          (norm: 1.0, primary: '1/4000', secondary: 'S'),
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
        return const [
          (norm: 0.0, primary: '709', secondary: 'SDR 8B'),
          (norm: 0.5, primary: 'HLG10', secondary: '10-BİT'),
          (norm: 1.0, primary: 'FLAT', secondary: 'LOG-BENZERİ'),
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

  /// Cinema Pro Video Top HUD Overlay (SMPTE Timecode, 180° Shutter Angle, dBFS Peak/RMS Meter, Thermal & Storage Guard)
  Widget _buildProVideoCinemaHudOverlay() {
    final tel = _videoTelemetry;
    final tc = tel?.timecodeString ?? '00:00:00:00';
    final peakDb = tel?.samplePeakDbfs ?? -60.0;
    final rmsDb = tel?.rmsDbfs ?? -60.0;
    final peakNorm = ((peakDb + 60.0) / 60.0).clamp(0.0, 1.0);
    final rmsNorm = ((rmsDb + 60.0) / 60.0).clamp(0.0, 1.0);
    final isClip = peakDb >= -0.5;
    final thermal = tel?.thermalLevel ?? ZameraThermalLevel.normal;
    final remMin = (tel?.remainingRecordSeconds ?? 0) / 60.0;
    final ndRec = tel?.ndFilterRecommendation;
    final eqShutter = ZameraCinemaMath.formatShutterFromAngle(
      _videoShutterAngleDeg,
      _videoFps,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isVideoRecording
              ? const Color(0xFFFF3B30).withValues(alpha: 0.85)
              : Colors.white12,
          width: _isVideoRecording ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isVideoRecording
                          ? const Color(0xFFFF3B30)
                          : kZameraCyan,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isVideoRecording ? 'REC  $tc' : 'STBY $tc',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      color: _isVideoRecording
                          ? const Color(0xFFFF453A)
                          : Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                '${_videoResolutionHeight >= 2160 ? "4K" : "1080P"} ${_videoFps}P · ${_videoShutterAngleDeg.round()}° ($eqShutter) · ${_videoProfile.shortLabel}',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: kIosYellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Text(
                'dBFS',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: Colors.white12),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: rmsNorm,
                          child: Container(
                            color: const Color(0xFF32D74B),
                          ),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: peakNorm,
                          child: Container(
                            color: isClip
                                ? const Color(0xFFFF3B30)
                                : kIosYellow.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${peakDb.toStringAsFixed(0)}dB',
                style: TextStyle(
                  fontSize: 8,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: isClip ? const Color(0xFFFF453A) : Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                thermal.badgeText,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: thermal == ZameraThermalLevel.normal
                      ? const Color(0xFF32D74B)
                      : const Color(0xFFFF9F0A),
                ),
              ),
              if (remMin > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '${remMin.toStringAsFixed(0)}dk',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
          if (ndRec != null || _lastVideoResult != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (ndRec != null)
                  Text(
                    '⚠ $ndRec',
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: kIosYellow,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (_lastVideoResult != null)
                  Text(
                    'SON: ${_lastVideoResult!.codec} · ${(_lastVideoResult!.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: kZameraCyan,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
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
    final liveIso = (_liveTelemetry['iso'] as num?)?.round() ??
        _lastCaptureResult?.iso ??
        100;
    final liveKelvin = (_liveTelemetry['solvedCctKelvin'] as num?)?.round() ??
        5500;
    final supportsFocus = _activeCameraCap?.supportsVariableFocus ?? true;

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
        return !_manualExposure ? 'OTO (ISO $liveIso)' : '${_iso.round()}';
      case ActiveProDial.shutter:
        return !_manualExposure ? 'OTO' : '1/${_shutterDenominator.round()}s';
      case ActiveProDial.wb:
        return !_manualWb ? 'AWB (${liveKelvin}K)' : '${_kelvin.round()}K';
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
        return !_videoLockShutterAngle
            ? 'OTO (180°)'
            : '${_videoShutterAngleDeg.round()}°';
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
                          _triggerPhotoCapture(
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
                            : null,
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

  void _showLastCaptureInspectorModal() {
    final res = _lastCaptureResult;
    if (res == null) return;
    CaptureInspectorModal.show(
      context,
      captureResult: res,
      initialAperture: _portraitAperture,
      initialLightingIndex: _portraitLightingIndex,
      initialLightIntensity: _portraitLightIntensity,
      subjectRadiusRatio: _portraitSubjectRadius,
      initialFocusTapNorm: _lastFocusTapNorm,
    );
  }

  void _showCalibrationAndProbeSheet() {
    CalibrationAndProbeSheet.show(
      context,
      calibrationResult: _calibrationResult,
      probeReport: _probeReport,
    );
  }
}
