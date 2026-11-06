import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zamera_capture/zamera_capture.dart';
import 'package:zamera_video/zamera_video.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF08090C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ZameraApp());
}

enum ActiveProDial { none, ev, iso, shutter, wb, focus }

class ZameraApp extends StatelessWidget {
  const ZameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zamera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08090C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE5A93C),
          secondary: Color(0xFF4ECDC4),
          surface: Color(0xFF12141A),
        ),
        useMaterial3: true,
      ),
      home: const ZameraHomeScreen(),
    );
  }
}

class ZameraHomeScreen extends StatefulWidget {
  const ZameraHomeScreen({super.key});

  @override
  State<ZameraHomeScreen> createState() => _ZameraHomeScreenState();
}

class _ZameraHomeScreenState extends State<ZameraHomeScreen>
    with WidgetsBindingObserver {
  // 0 = Sanat (Gerçek Renk), 1 = Pro Fotoğraf, 2 = Pro Video
  int _selectedMode = 0;
  ActiveProDial _activeDial = ActiveProDial.none;

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

  // Sanat Modu (TrueColor) State — Faz 2.0
  final double _simulatedSensorWarmth = 1.45;
  bool _showPerspectiveGrid = true;
  bool _applyPerspectiveWarp = false;
  List<Offset> _perspectiveCorners = const [
    Offset(0.10, 0.10),
    Offset(0.90, 0.10),
    Offset(0.90, 0.90),
    Offset(0.10, 0.90),
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
  bool _showFocusPeaking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recomputeCalibration();
    _runDeviceProbe();
    _telemetryTimer = Timer.periodic(
      const Duration(milliseconds: 350),
      (_) => _pollLiveTelemetry(),
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
      _startOrSwitchCamera(_selectedCameraId);
    } else if (state == AppLifecycleState.paused) {
      ZameraCapture.stopPreviewSession();
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
      if (!mounted || tel.isEmpty) return;
      setState(() => _liveTelemetry = tel);
    } catch (_) {}
  }

  CameraUnitCapability? get _activeCameraCap {
    final report = _probeReport;
    if (report == null) return null;
    for (final cam in report.cameras) {
      if (cam.cameraId == _selectedCameraId) return cam;
    }
    return null;
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

  Future<void> _startOrSwitchCamera(String cameraId) async {
    if (_isStartingCamera) return;
    _isStartingCamera = true;
    setState(() {
      _selectedCameraId = cameraId;
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
      await _pushManualControlsToNative(artworkMode: _selectedMode == 0);
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

  Future<void> _pushManualControlsToNative({required bool artworkMode}) async {
    if (_previewSession == null) return;
    final exposureNs = (1e9 / _shutterDenominator).round();
    final gains = ZameraCapture.kelvinAndTintToRggbGains(_kelvin, _tint);
    final supportsFocus = _activeCameraCap?.supportsVariableFocus ?? true;
    try {
      await ZameraCapture.updateManualControls(
        manualExposure: !artworkMode && _manualExposure,
        iso: _iso,
        exposureTimeNs: exposureNs,
        evCompensation: !artworkMode && !_manualExposure ? _evCompensation : 0.0,
        manualFocus: !artworkMode && supportsFocus && _manualFocus,
        focusDistance: _focusDistance,
        manualWb: !artworkMode && _manualWb,
        kelvin: _kelvin,
        tint: _tint,
        rggbGains: gains,
        artworkLinearMode: artworkMode,
      );
    } catch (_) {}
  }

  Future<void> _onViewfinderTapUp(
    TapUpDetails details,
    BoxConstraints constraints,
  ) async {
    if (_previewSession == null) return;
    final normX =
        (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final normY =
        (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);
    setState(() {
      _lastFocusTapNorm = Offset(normX, normY);
    });
    try {
      final ok = await ZameraCapture.setFocusAndMeteringPoint(
        x: normX,
        y: normY,
      );
      if (!mounted) return;
      final afSupported = _activeCameraCap?.supportsVariableFocus ?? true;
      setState(() {
        _statusBanner = (ok && afSupported)
            ? 'AF + Spot AE Kilitlendi (${(normX * 100).round()}%, ${(normY * 100).round()}%)'
            : 'Sabit Odak — Spot AE Ölçüm Noktası Güncellendi';
      });
    } catch (_) {}
  }

  Future<void> _triggerPhotoCapture({
    required bool isArtworkMode,
    bool lockGrayCardFromCenter = false,
  }) async {
    if (_isCapturing) return;
    setState(() {
      _isCapturing = true;
      _statusBanner = isArtworkMode
          ? '14-Bit RAW → ${_fullResolution ? "12.6MP" : "3.1MP"} TrueColor ISP işleniyor...'
          : 'Pro DNG + JPEG çekiliyor...';
    });
    try {
      final cornersFlat = <double>[
        for (final pt in _perspectiveCorners) ...[pt.dx, pt.dy],
      ];
      final res = await ZameraCapture.capturePhoto(
        captureRaw: true,
        isArtworkMode: isArtworkMode,
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
        final resStr = (res.outputWidth != null && res.outputHeight != null)
            ? '${res.outputWidth}×${res.outputHeight}'
            : '';
        _statusBanner = lockGrayCardFromCenter
            ? 'Gri Kart WB + 8×6 Flat-Field Kalibre Edildi ($cctStr)'
            : (isArtworkMode
                ? 'TrueColor $resStr ($cctStr) DCIM/Zamera\'ya kaydedildi'
                : 'Pro DNG+JPEG ($cctStr) DCIM/Zamera\'ya kaydedildi');
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
    setState(() {
      _isCapturing = true;
      _statusBanner = '3x AEB (-1.5, 0.0, +1.5 EV) DNG+JPEG çekiliyor...';
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
        _statusBanner =
            '3x AEB Tamamlandı (${results.length} DNG+JPEG DCIM/Zamera\'da)';
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
    if (cap != null && !cap.supportsVariableFocus) return '∞ SABİT';
    final d = (_selectedMode == 1 && _manualFocus)
        ? (_focusDistance * (cap?.minimumFocusDistanceDiopters ?? 10.0))
        : (diopters ?? 0.0);
    if (d <= 0.05) return '∞';
    final meters = (1.0 / d).clamp(0.08, 99.0);
    return meters < 1.0
        ? '${(meters * 100).round()}cm'
        : '${meters.toStringAsFixed(1)}m';
  }

  @override
  Widget build(BuildContext context) {
    final isArtwork = _selectedMode == 0;
    final isProPhoto = _selectedMode == 1;
    final isVideo = _selectedMode == 2;

    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopProHudBar(isArtwork: isArtwork, isProPhoto: isProPhoto),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Center(
                  child: isVideo
                      ? _buildProVideoViewfinderOverlay()
                      : _buildCameraViewfinder(isArtworkMode: isArtwork),
                ),
              ),
            ),
            if (!isVideo && _activeDial != ActiveProDial.none)
              _buildExpandableProDialBar(isArtwork: isArtwork),
            _buildBottomProControlDeck(
              isArtwork: isArtwork,
              isProPhoto: isProPhoto,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProHudBar({
    required bool isArtwork,
    required bool isProPhoto,
  }) {
    final liveIso = _manualExposure && isProPhoto
        ? _iso.round()
        : ((_liveTelemetry['iso'] as num?)?.round() ??
            _lastCaptureResult?.iso ??
            100);
    final liveExpNs = (_liveTelemetry['exposureTimeNs'] as num?)?.toInt() ??
        _lastCaptureResult?.exposureTimeNs;
    final liveCct = (isProPhoto && _manualWb)
        ? _kelvin.round()
        : ((_lastCaptureResult?.solvedCctKelvin ??
                    (_liveTelemetry['solvedCctKelvin'] as num?)?.toDouble() ??
                    5500.0)
                .round());
    final liveDiopters =
        (_liveTelemetry['focusDistanceDiopters'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F14),
        border: Border(
          bottom: BorderSide(color: Colors.white10, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.camera_enhance_rounded,
                color: Color(0xFFE5A93C),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'ZAMERA',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildHudMetricChip('ISO $liveIso', highlight: _manualExposure && isProPhoto),
                      const SizedBox(width: 4),
                      _buildHudMetricChip(_formatShutter(liveExpNs), highlight: _manualExposure && isProPhoto),
                      const SizedBox(width: 4),
                      _buildHudMetricChip('${liveCct}K', highlight: (_manualWb && isProPhoto) || _useMeasuredGrayCardWb),
                      const SizedBox(width: 4),
                      _buildHudMetricChip('AF ${_formatFocusDistance(liveDiopters)}', highlight: _manualFocus && isProPhoto),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _showCalibrationAndProbeSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1E28),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 13, color: Color(0xFFE5A93C)),
                      SizedBox(width: 4),
                      Text(
                        'Faz 0: Probe',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (isArtwork) ...[
                  _buildQuickTogglePill(
                    label: _fullResolution ? '12.6MP TAM' : '3.1MP HIZLI',
                    active: _fullResolution,
                    onTap: () => setState(() => _fullResolution = !_fullResolution),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTogglePill(
                    label: _useDisplayP3 ? 'DISPLAY P3' : 'sRGB',
                    active: _useDisplayP3,
                    onTap: () => setState(() => _useDisplayP3 = !_useDisplayP3),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTogglePill(
                    label: 'L*≈94 POZLAMA',
                    active: _normalizeExposure,
                    onTap: () =>
                        setState(() => _normalizeExposure = !_normalizeExposure),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTogglePill(
                    label: '8×6 FLAT-FIELD',
                    active: _flatFieldEnabled,
                    onTap: () =>
                        setState(() => _flatFieldEnabled = !_flatFieldEnabled),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTogglePill(
                    label: _applyPerspectiveWarp ? 'WARP AÇIK' : '4-KÖŞE KILAVUZ',
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
                  _buildQuickTogglePill(
                    label: 'DNG 14-BİT',
                    active: true,
                    onTap: () {},
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTogglePill(
                    label: 'ZEBRA %95',
                    active: _showZebra,
                    onTap: () => setState(() => _showZebra = !_showZebra),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTogglePill(
                    label: 'PEAKING',
                    active: _showFocusPeaking,
                    onTap: () =>
                        setState(() => _showFocusPeaking = !_showFocusPeaking),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTogglePill(
                    label: '1.0× OPTİK KİLİT',
                    active: true,
                    onTap: () {},
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudMetricChip(String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF2B2210) : const Color(0xFF151821),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight ? const Color(0xFFE5A93C) : Colors.white12,
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          color: highlight ? const Color(0xFFE5A93C) : const Color(0xFF4ECDC4),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFE5A93C).withValues(alpha: 0.18)
              : const Color(0xFF14171F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFFE5A93C) : Colors.white12,
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: active ? const Color(0xFFE5A93C) : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraViewfinder({required bool isArtworkMode}) {
    final session = _previewSession;
    final lastRes = _lastCaptureResult;
    final hist = lastRes?.rawHistogram32;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF050608),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isArtworkMode
                ? const Color(0xFFE5A93C).withValues(alpha: 0.45)
                : Colors.white24,
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _onViewfinderTapUp(details, constraints),
              onPanUpdate: (isArtworkMode && _showPerspectiveGrid)
                  ? (details) {
                      final nx = (details.localPosition.dx /
                              constraints.maxWidth)
                          .clamp(0.04, 0.96);
                      final ny = (details.localPosition.dy /
                              constraints.maxHeight)
                          .clamp(0.04, 0.96);
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
                  if (session != null && session.textureId >= 0)
                    ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: session.previewHeight.toDouble(),
                          height: session.previewWidth.toDouble(),
                          child: Texture(textureId: session.textureId),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sensors_rounded,
                            size: 40,
                            color: Color(0xFFE5A93C),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _loadingProbe
                                ? 'Fiziksel Sensörler Taranıyor...'
                                : 'Canlı Vizör Hazır (#$_selectedCameraId)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _startOrSwitchCamera(_selectedCameraId),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Vizörü Başlat'),
                          ),
                        ],
                      ),
                    ),

                  // Subtle Rule-of-Thirds & Perspective Overlay
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _ViewfinderGridAndPerspectivePainter(
                        showPerspectiveQuad:
                            isArtworkMode && _showPerspectiveGrid,
                        warpActive: isArtworkMode && _applyPerspectiveWarp,
                        corners: _perspectiveCorners,
                      ),
                    ),
                  ),

                  // Tap-to-Focus & Spot AE Reticle
                  if (_lastFocusTapNorm != null)
                    Positioned(
                      left:
                          (_lastFocusTapNorm!.dx * constraints.maxWidth) - 26,
                      top:
                          (_lastFocusTapNorm!.dy * constraints.maxHeight) - 26,
                      child: IgnorePointer(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE5A93C),
                              width: 1.8,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ECDC4),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Top-Left: Compact 32-Bin 14-Bit RAW Histogram & Telemetry Overlay
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 116,
                            height: 30,
                            child: CustomPaint(
                              painter: _RawHistogramPainter(
                                (hist != null && hist.length == 32)
                                    ? hist
                                    : const [
                                        0.05, 0.12, 0.22, 0.35, 0.48, 0.62,
                                        0.75, 0.82, 0.78, 0.68, 0.58, 0.52,
                                        0.48, 0.44, 0.40, 0.38, 0.35, 0.32,
                                        0.28, 0.25, 0.22, 0.18, 0.15, 0.12,
                                        0.10, 0.08, 0.06, 0.05, 0.04, 0.03,
                                        0.02, 0.01,
                                      ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'RAW 14b · ZEBRA ${((lastRes?.zebraRatio ?? 0.0) * 100).toStringAsFixed(1)}%'
                            '${_showFocusPeaking ? " · PEAK ${(lastRes?.focusPeakingScore ?? 0.0).toStringAsFixed(2)}" : ""}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontFamily: 'monospace',
                              color: Color(0xFF4ECDC4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top-Right: Active Color Science / WB Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        isArtworkMode
                            ? (_useMeasuredGrayCardWb
                                ? 'GRİ KART + FF KİLİTLİ'
                                : 'DNG CCT MATRİS WB')
                            : (_manualWb
                                ? 'MANUEL ${_kelvin.round()}K'
                                : 'AWB DNG 14-BİT'),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFFE5A93C),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Floating Status Pill inside Viewfinder
                  if (_statusBanner != null)
                    Positioned(
                      bottom: 8,
                      left: 12,
                      right: 12,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
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
          },
        ),
      ),
    );
  }

  Widget _buildProVideoViewfinderOverlay() {
    const videoInfo = ZameraVideoIsolationInfo();
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1016),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4ECDC4).withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_rounded,
              size: 46,
              color: Color(0xFF4ECDC4),
            ),
            const SizedBox(height: 10),
            Text(
              'Pro Video Sinema Modülü (ZAMERA_VIDEO=${videoInfo.isEnabledByFlag})',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE5A93C),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              videoInfo.isolationPolicy,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 14),
            const Text(
              '• 10-Bit HLG10 / HDR10 (DynamicRangeProfiles)\n'
              '• iOS 17+ Apple Log & ProRes 422 HQ (Harici USB-C SSD)\n'
              '• 180° Shutter Angle Kilidi (24fps → 1/48s, 60fps → 1/120s)',
              style: TextStyle(fontSize: 11, color: Color(0xFF4ECDC4), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableProDialBar({required bool isArtwork}) {
    final activeCap = _activeCameraCap;
    final isoRange = activeCap?.isoRange;
    final isoMin = (isoRange != null && isoRange.length >= 2)
        ? isoRange[0].toDouble()
        : 50.0;
    final isoMax = (isoRange != null && isoRange.length >= 2)
        ? isoRange[1].toDouble()
        : 3200.0;
    final clampedIso = _iso.clamp(isoMin, isoMax);
    final supportsFocus = activeCap?.supportsVariableFocus ?? true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF12151E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_activeDial == ActiveProDial.ev)
            Row(
              children: [
                const Text(
                  'EV TELAFİ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE5A93C),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _evCompensation,
                    min: -3.0,
                    max: 3.0,
                    divisions: 24,
                    label:
                        '${_evCompensation >= 0 ? "+" : ""}${_evCompensation.toStringAsFixed(1)} EV',
                    onChanged: (v) {
                      setState(() {
                        _manualExposure = false;
                        _evCompensation = v;
                      });
                      _pushManualControlsToNative(artworkMode: isArtwork);
                    },
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _evCompensation = 0.0);
                    _pushManualControlsToNative(artworkMode: isArtwork);
                  },
                  child: const Text('0.0 EV', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          if (_activeDial == ActiveProDial.iso)
            Row(
              children: [
                FilterChip(
                  label: Text(_manualExposure ? 'MANUEL' : 'AUTO AE'),
                  selected: _manualExposure,
                  onSelected: (v) {
                    setState(() => _manualExposure = v);
                    _pushManualControlsToNative(artworkMode: isArtwork);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: clampedIso,
                    min: isoMin,
                    max: isoMax,
                    divisions: ((isoMax - isoMin) / 25).round().clamp(10, 120),
                    label: 'ISO ${clampedIso.round()}',
                    onChanged: (v) {
                      setState(() {
                        _manualExposure = true;
                        _iso = v;
                      });
                      _pushManualControlsToNative(artworkMode: isArtwork);
                    },
                  ),
                ),
                Text(
                  'ISO ${clampedIso.round()}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          if (_activeDial == ActiveProDial.shutter)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    FilterChip(
                      label: Text(_manualExposure ? 'MANUEL' : 'AUTO AE'),
                      selected: _manualExposure,
                      onSelected: (v) {
                        setState(() => _manualExposure = v);
                        _pushManualControlsToNative(artworkMode: isArtwork);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _shutterDenominator,
                        min: 2,
                        max: 4000,
                        label: '1/${_shutterDenominator.round()}s',
                        onChanged: (v) {
                          setState(() {
                            _manualExposure = true;
                            _shutterDenominator = v;
                          });
                          _pushManualControlsToNative(artworkMode: isArtwork);
                        },
                      ),
                    ),
                    Text(
                      '1/${_shutterDenominator.round()}s',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final denom in const [48, 60, 120, 250, 500, 1000])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _manualExposure = true;
                              _shutterDenominator = denom.toDouble();
                            });
                            _pushManualControlsToNative(artworkMode: isArtwork);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (_shutterDenominator.round() == denom &&
                                      _manualExposure)
                                  ? const Color(0xFFE5A93C)
                                  : const Color(0xFF1C202B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '1/${denom}s',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: (_shutterDenominator.round() == denom &&
                                        _manualExposure)
                                    ? Colors.black
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          if (_activeDial == ActiveProDial.wb)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    FilterChip(
                      label: Text(_manualWb ? 'MANUEL K' : 'AWB DNG'),
                      selected: _manualWb,
                      onSelected: (v) {
                        setState(() => _manualWb = v);
                        _pushManualControlsToNative(artworkMode: isArtwork);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _kelvin,
                        min: 2500,
                        max: 9000,
                        divisions: 65,
                        label: '${_kelvin.round()}K',
                        onChanged: (v) {
                          setState(() {
                            _manualWb = true;
                            _kelvin = v;
                          });
                          _pushManualControlsToNative(artworkMode: isArtwork);
                        },
                      ),
                    ),
                    Text(
                      '${_kelvin.round()}K',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(
                      width: 72,
                      child: Text('Tint (G/M)', style: TextStyle(fontSize: 11)),
                    ),
                    Expanded(
                      child: Slider(
                        value: _tint,
                        min: -50,
                        max: 50,
                        divisions: 100,
                        label: '${_tint.round()}',
                        onChanged: (v) {
                          setState(() {
                            _manualWb = true;
                            _tint = v;
                          });
                          _pushManualControlsToNative(artworkMode: isArtwork);
                        },
                      ),
                    ),
                    Text(
                      '${_tint >= 0 ? "+" : ""}${_tint.round()}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          if (_activeDial == ActiveProDial.focus)
            if (!supportsFocus)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Bu fiziksel lens sabit odaklıdır (0.0 Dioptri / Sonsuz Hiperfokal).',
                  style: TextStyle(fontSize: 11, color: Colors.amberAccent),
                ),
              )
            else
              Row(
                children: [
                  FilterChip(
                    label: Text(_manualFocus ? 'MF KİLİT' : 'AF SÜREKLİ'),
                    selected: _manualFocus,
                    onSelected: (v) {
                      setState(() => _manualFocus = v);
                      _pushManualControlsToNative(artworkMode: isArtwork);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: _focusDistance,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) {
                        setState(() {
                          _manualFocus = true;
                          _focusDistance = v;
                        });
                        _pushManualControlsToNative(artworkMode: isArtwork);
                      },
                    ),
                  ),
                  Text(
                    _formatFocusDistance(
                      _focusDistance *
                          (activeCap?.minimumFocusDistanceDiopters ?? 10.0),
                    ),
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildBottomProControlDeck({
    required bool isArtwork,
    required bool isProPhoto,
  }) {
    final cameras = _probeReport?.cameras ?? const <CameraUnitCapability>[];
    final lastRes = _lastCaptureResult;
    final thumbFile = lastRes?.jpegPath != null ? File(lastRes!.jpegPath!) : null;
    final hasThumb = thumbFile != null && thumbFile.existsSync();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E13),
        border: Border(top: BorderSide(color: Colors.white12, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Physical Optical Lens Switcher + Pro Dial Selector Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (cameras.isNotEmpty)
                  for (final cam in cameras.where((c) => c.cameraId != '0'))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildLensPill(
                        label: cam.facing == 'FRONT'
                            ? 'Ön'
                            : (cam.focalLengthsMm.isNotEmpty &&
                                    cam.focalLengthsMm.first >= 6.0
                                ? '23mm 14b'
                                : '14mm'),
                        selected: _selectedCameraId == cam.cameraId,
                        onTap: () => _startOrSwitchCamera(cam.cameraId),
                      ),
                    )
                else
                  for (final id in const ['3', '2', '1'])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildLensPill(
                        label: id == '2'
                            ? '23mm 14b'
                            : (id == '3' ? '14mm' : 'Ön'),
                        selected: _selectedCameraId == id,
                        onTap: () => _startOrSwitchCamera(id),
                      ),
                    ),
                const SizedBox(width: 6),
                Container(width: 1, height: 18, color: Colors.white24),
                const SizedBox(width: 8),
                _buildDialPill('EV', ActiveProDial.ev, activeValue: _evCompensation != 0),
                const SizedBox(width: 5),
                _buildDialPill('ISO', ActiveProDial.iso, activeValue: _manualExposure),
                const SizedBox(width: 5),
                _buildDialPill('S', ActiveProDial.shutter, activeValue: _manualExposure),
                const SizedBox(width: 5),
                _buildDialPill('WB', ActiveProDial.wb, activeValue: _manualWb),
                const SizedBox(width: 5),
                _buildDialPill('AF', ActiveProDial.focus, activeValue: _manualFocus),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Row 2: Mode Selector Strip (Sanat · Pro Fotoğraf · Pro Video)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModeTab('Sanat (Gerçek Renk)', 0),
              const SizedBox(width: 14),
              _buildModeTab('Pro Fotoğraf', 1),
              const SizedBox(width: 14),
              _buildModeTab('Pro Video', 2),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Thumbnail Preview | Tactile Pro Shutter Ring | Context Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Last Capture Thumbnail & Inspector Trigger
              GestureDetector(
                onTap: lastRes != null ? _showLastCaptureInspectorModal : null,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161922),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasThumb ? const Color(0xFF4ECDC4) : Colors.white24,
                      width: 1.4,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasThumb
                      ? Image.file(thumbFile, fit: BoxFit.cover)
                      : const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white38,
                          size: 22,
                        ),
                ),
              ),

              // Center: Tactile Concentric Pro Shutter Button
              GestureDetector(
                onTap: _isCapturing
                    ? null
                    : () => _triggerPhotoCapture(isArtworkMode: isArtwork),
                child: Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isArtwork
                          ? const Color(0xFFE5A93C)
                          : const Color(0xFF4ECDC4),
                      width: 3.0,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCapturing
                          ? Colors.white38
                          : (isArtwork
                              ? const Color(0xFFE5A93C)
                              : Colors.white),
                    ),
                    alignment: Alignment.center,
                    child: _isCapturing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            isArtwork
                                ? Icons.palette_rounded
                                : Icons.camera_rounded,
                            color: Colors.black87,
                            size: 26,
                          ),
                  ),
                ),
              ),

              // Right: Context Pro Action (Gray Card + Flat-Field Lock OR 3x AEB Bracketing)
              if (isArtwork)
                 InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _isCapturing
                      ? null
                      : () {
                          if (_useMeasuredGrayCardWb) {
                            setState(() {
                              _useMeasuredGrayCardWb = false;
                              _statusBanner = 'DNG Otomatik CCT WB\'ye dönüldü';
                            });
                          } else {
                            _triggerPhotoCapture(
                              isArtworkMode: true,
                              lockGrayCardFromCenter: true,
                            );
                          }
                        },
                  child: Container(
                    width: 92,
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: _useMeasuredGrayCardWb
                          ? const Color(0xFF193C38)
                          : const Color(0xFF161922),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _useMeasuredGrayCardWb
                            ? const Color(0xFF4ECDC4)
                            : Colors.white24,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _useMeasuredGrayCardWb
                                ? Icons.lock_rounded
                                : Icons.filter_center_focus_rounded,
                            size: 18,
                            color: _useMeasuredGrayCardWb
                                ? const Color(0xFF4ECDC4)
                                : const Color(0xFFE5A93C),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _useMeasuredGrayCardWb ? 'WB Kilitli' : 'Gri Kart Ölç',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _isCapturing ? null : _triggerBracketedCapture,
                  child: Container(
                    width: 92,
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161922),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.burst_mode_rounded,
                            size: 18,
                            color: Color(0xFF4ECDC4),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '3x AEB ±1.5',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLensPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE5A93C) : const Color(0xFF171A24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFE5A93C) : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDialPill(
    String label,
    ActiveProDial dial, {
    bool activeValue = false,
  }) {
    final isOpen = _activeDial == dial;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeDial = isOpen ? ActiveProDial.none : dial;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isOpen
              ? const Color(0xFF4ECDC4)
              : (activeValue
                  ? const Color(0xFF282214)
                  : const Color(0xFF151821)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOpen
                ? const Color(0xFF4ECDC4)
                : (activeValue ? const Color(0xFFE5A93C) : Colors.white24),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isOpen
                ? Colors.black
                : (activeValue ? const Color(0xFFE5A93C) : Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, int modeIndex) {
    final selected = _selectedMode == modeIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = modeIndex;
          _activeDial = ActiveProDial.none;
        });
        if (modeIndex == 0 || modeIndex == 1) {
          _pushManualControlsToNative(artworkMode: modeIndex == 0);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? const Color(0xFFE5A93C) : Colors.white54,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: selected ? 22 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: const Color(0xFFE5A93C),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  void _showLastCaptureInspectorModal() {
    final res = _lastCaptureResult;
    if (res == null) return;
    final trueColorFile = res.jpegPath != null ? File(res.jpegPath!) : null;
    final oemFile = res.oemJpegPath != null ? File(res.oemJpegPath!) : null;
    final hasTrueColor = trueColorFile != null && trueColorFile.existsSync();
    final hasOem = oemFile != null && oemFile.existsSync();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Son Çekim Analizi (${res.outputWidth ?? "-"}×${res.outputHeight ?? "-"} · ${res.solvedCctKelvin?.round() ?? 5500}K)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE5A93C),
                  ),
                ),
                const SizedBox(height: 12),
                if (hasTrueColor || hasOem)
                  Row(
                    children: [
                      if (hasTrueColor)
                        Expanded(
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  trueColorFile,
                                  height: 220,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                res.rustIspActive
                                    ? 'Zamera TrueColor 12.6MP'
                                    : 'Kaydedilen Pro JPEG',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4ECDC4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (hasTrueColor && hasOem) const SizedBox(width: 10),
                      if (hasOem)
                        Expanded(
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  oemFile,
                                  height: 220,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'OEM Kamera (Leica/ISP)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amberAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0C10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• DCIM JPEG: ${res.mediaStoreJpegUri ?? res.jpegPath ?? "-"}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                      Text(
                        '• DCIM 14-Bit DNG (Orientation=6): ${res.mediaStoreDngUri ?? res.dngPath ?? "-"}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                      Text(
                        '• Işık Sıcaklığı: ${res.solvedCctKelvin?.round() ?? "-"}K | Pozlama Kazancı: ×${(res.exposureNormGain ?? 1.0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Color(0xFF4ECDC4),
                        ),
                      ),
                      if (res.centerLinearCamRgb != null)
                        Text(
                          '• Merkez Doğrusal RGB: [${res.centerLinearCamRgb!.map((e) => e.toStringAsFixed(4)).join(", ")}]',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFFE5A93C),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCalibrationAndProbeSheet() {
    final cal = _calibrationResult;
    final report = _probeReport;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '24-Yama ColorChecker Kalibrasyon & Donanım Raporu',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE5A93C),
                        ),
                      ),
                    ),
                    if (report != null)
                      IconButton(
                        tooltip: 'JSON Kopyala',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: report.toPrettyJson()),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.copy_all_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• Kalibrasyon Öncesi: ΔE00 = ${cal.meanDeltaEBefore.toStringAsFixed(2)} → Kalibrasyon Sonrası: ΔE00 Ort = ${cal.meanDeltaEAfter.toStringAsFixed(2)} (Maks = ${cal.maxDeltaEAfter.toStringAsFixed(2)})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4ECDC4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: kColorChecker24Patches.length,
                  itemBuilder: (context, i) {
                    final patch = kColorChecker24Patches[i];
                    final deAfter = cal.patchDeltaEAfter[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Color(patch.previewArgb),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white24),
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          '#${patch.index} Δ${deAfter.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 8, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
                if (report != null) ...[
                  Text(
                    '${report.brand.toUpperCase()} ${report.model} (${report.device}) — ${report.rustCoreVersion}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE5A93C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final cam in report.cameras)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${cam.opticalBadgeLabel}: RAW=${cam.rawSensorSizes.join("/")} | White=${cam.sensorWhiteLevel ?? "-"} | MinFocus=${cam.minimumFocusDistanceDiopters}D',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _RawHistogramPainter extends CustomPainter {
  const _RawHistogramPainter(this.bins);
  final List<double> bins;

  @override
  void paint(Canvas canvas, Size size) {
    if (bins.isEmpty) return;
    double maxVal = 1e-5;
    for (final v in bins) {
      if (v > maxVal) maxVal = v;
    }
    final barW = size.width / bins.length;
    for (int i = 0; i < bins.length; i++) {
      final norm = (bins[i] / maxVal).clamp(0.0, 1.0);
      final barH = norm * (size.height - 2);
      final isHighlightZone = i >= 30;
      final paint = Paint()
        ..color = isHighlightZone
            ? const Color(0xFFE5A93C)
            : const Color(0xFF4ECDC4).withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(
          i * barW,
          size.height - barH,
          (barW - 1.0).clamp(1.0, barW),
          barH,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RawHistogramPainter oldDelegate) =>
      oldDelegate.bins != bins;
}

class _ViewfinderGridAndPerspectivePainter extends CustomPainter {
  const _ViewfinderGridAndPerspectivePainter({
    required this.showPerspectiveQuad,
    required this.warpActive,
    required this.corners,
  });

  final bool showPerspectiveQuad;
  final bool warpActive;
  final List<Offset> corners;

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle Rule of Thirds lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      gridPaint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      gridPaint,
    );

    if (!showPerspectiveQuad || corners.length < 4) return;

    final pts = [
      for (final c in corners) Offset(c.dx * size.width, c.dy * size.height),
    ];
    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();

    final borderPaint = Paint()
      ..color = warpActive
          ? const Color(0xFF4ECDC4).withValues(alpha: 0.9)
          : const Color(0xFFE5A93C).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(path, borderPaint);

    // Center 18% Gray Card spot target
    final centerRoi = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.5),
      width: size.width * 0.12,
      height: size.width * 0.12,
    );
    canvas.drawRect(
      centerRoi,
      Paint()
        ..color = const Color(0xFF4ECDC4).withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final handlePaint = Paint()
      ..color = const Color(0xFFE5A93C)
      ..style = PaintingStyle.fill;
    for (final pt in pts) {
      canvas.drawCircle(pt, 6.5, handlePaint);
    }
  }

  @override
  bool shouldRepaint(
    covariant _ViewfinderGridAndPerspectivePainter oldDelegate,
  ) =>
      oldDelegate.showPerspectiveQuad != showPerspectiveQuad ||
      oldDelegate.warpActive != warpActive ||
      oldDelegate.corners != corners;
}
