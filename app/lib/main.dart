import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zamera_capture/zamera_capture.dart';
import 'package:zamera_video/zamera_video.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZameraApp());
}

class ZameraApp extends StatelessWidget {
  const ZameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zamera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E1014),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE5A93C),
          secondary: Color(0xFF4ECDC4),
          surface: Color(0xFF181B22),
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

class _ZameraHomeScreenState extends State<ZameraHomeScreen> {
  int _selectedIndex = 0;

  // Device Probe State
  ZameraProbeReport? _probeReport;
  String? _probeError;
  bool _loadingProbe = true;

  // Live Camera Session State (shared between Sanat Modu & Pro Foto)
  PreviewSessionInfo? _previewSession;
  String _selectedCameraId = '2';
  String? _lastCaptureMessage;
  CapturePhotoResult? _lastCaptureResult;
  bool _isCapturing = false;
  Offset? _lastFocusTapNorm;

  // Sanat Modu (TrueColor) State — Faz 2.0
  double _simulatedSensorWarmth = 1.45;
  bool _showPerspectiveGrid = true;
  bool _flatFieldEnabled = true;
  bool _useDisplayP3 = false;
  bool _fullResolution = true;
  bool _normalizeExposure = true;
  bool _useMeasuredGrayCardWb = false;
  List<double>? _measuredGrayCardWbGains;
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
  bool _preferProRaw48Mp = false;
  bool _showZebra = true;
  bool _showFocusPeaking = false;

  @override
  void initState() {
    super.initState();
    _recomputeCalibration();
    _runDeviceProbe();
  }

  void _recomputeCalibration() {
    final measured = ZameraCapture.simulateUncalibratedSensor24(
      redShift: _simulatedSensorWarmth,
      greenShift: 1.18,
      blueShift: 0.82,
    );
    _calibrationResult = ZameraCapture.calibrateColorChecker24(measured);
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
      _probeError = null;
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
      if (_previewSession == null) {
        await _startOrSwitchCamera(preferredId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _probeError = e.toString();
        _loadingProbe = false;
      });
    }
  }

  Future<void> _startOrSwitchCamera(String cameraId) async {
    setState(() {
      _selectedCameraId = cameraId;
      _lastFocusTapNorm = null;
    });
    try {
      final info = await ZameraCapture.startPreviewSession(cameraId: cameraId);
      if (!mounted) return;
      final cap = _activeCameraCap;
      if (cap != null && !cap.supportsVariableFocus && _manualFocus) {
        _manualFocus = false;
      }
      final isoRange = cap?.isoRange;
      if (isoRange != null && isoRange.length >= 2) {
        final minIso = isoRange[0].toDouble();
        final maxIso = isoRange[1].toDouble();
        _iso = _iso.clamp(minIso, maxIso);
      }
      setState(() => _previewSession = info);
      await _pushManualControlsToNative(artworkMode: _selectedIndex == 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastCaptureMessage = 'Kamera oturumu başlatılamadı: $e';
      });
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
    final normX = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final normY = (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);
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
        _lastCaptureMessage = (ok && afSupported)
            ? 'Dokunmatik AF + Spot AE Noktası: (${(normX * 100).round()}%, ${(normY * 100).round()}%)'
            : 'Sabit Odaklı Lens — Yalnızca Spot AE Ölçüm Noktası Güncellendi';
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
      _lastCaptureMessage = isArtworkMode
          ? '14-Bit RAW (${_fullResolution ? "12.6MP Tam Çözünürlük" : "3.1MP Hızlı"}) çekiliyor ve Rust TrueColor ISP işleniyor...'
          : 'Pro RAW (.dng) + JPEG çekiliyor...';
    });
    try {
      final res = await ZameraCapture.capturePhoto(
        captureRaw: true,
        isArtworkMode: isArtworkMode,
        preferProRaw: !isArtworkMode && _preferProRaw48Mp,
        useDisplayP3: _useDisplayP3,
        fullResolution: _fullResolution,
        normalizeExposure: _normalizeExposure && !_useMeasuredGrayCardWb,
        wbGains: _useMeasuredGrayCardWb ? _measuredGrayCardWbGains : null,
      );
      if (!mounted) return;

      if (lockGrayCardFromCenter &&
          res.centerLinearCamRgb != null &&
          res.centerLinearCamRgb!.length >= 3) {
        final cr = res.centerLinearCamRgb![0].clamp(1e-4, 1.0);
        final cg = res.centerLinearCamRgb![1].clamp(1e-4, 1.0);
        final cb = res.centerLinearCamRgb![2].clamp(1e-4, 1.0);
        _measuredGrayCardWbGains = [cg / cr, 1.0, cg / cb];
        _useMeasuredGrayCardWb = true;
      }

      setState(() {
        _isCapturing = false;
        _lastCaptureResult = res;
        final dcimStatus = res.mediaStoreJpegUri != null
            ? 'Galeriye (DCIM/Zamera) kaydedildi'
            : 'Uygulama dizinine kaydedildi';
        final cctStr = res.solvedCctKelvin != null
            ? ' · ${res.solvedCctKelvin!.round()}K'
            : '';
        final resStr = (res.outputWidth != null && res.outputHeight != null)
            ? ' (${res.outputWidth}×${res.outputHeight})'
            : '';
        _lastCaptureMessage = isArtworkMode
            ? 'Sanat RAW + TrueColor$resStr$cctStr $dcimStatus!'
            : 'Pro RAW+JPEG (#${res.cameraId}$cctStr) $dcimStatus!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _lastCaptureMessage = 'Çekim bildirimi: $e';
      });
    }
  }

  Future<void> _triggerBracketedCapture() async {
    if (_isCapturing) return;
    setState(() {
      _isCapturing = true;
      _lastCaptureMessage = '3-Kare AE Braketleme (-1.5 EV, 0 EV, +1.5 EV) çekiliyor...';
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
        _lastCaptureMessage =
            '3-Kare AE Braketleme tamamlandı (${results.length} adet DNG+JPEG DCIM/Zamera dizinine kaydedildi)!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _lastCaptureMessage = 'Braketleme bildirimi: $e';
      });
    }
  }

  Future<void> _copyJsonToClipboard() async {
    final report = _probeReport;
    if (report == null) return;
    await Clipboard.setData(ClipboardData(text: report.toPrettyJson()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cihaz yetenek JSON raporu panoya kopyalandı (docs/cihaz_yetenekleri/ için hazır).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF14171E),
        title: const Row(
          children: [
            Icon(Icons.camera_enhance_rounded, color: Color(0xFFE5A93C)),
            SizedBox(width: 10),
            Text(
              'ZAMERA',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          if (_probeReport != null)
            IconButton(
              tooltip: 'Probe JSON Kopyala',
              onPressed: _copyJsonToClipboard,
              icon: const Icon(Icons.copy_all_rounded),
            ),
          IconButton(
            tooltip: 'Donanımı Yeniden Tara',
            onPressed: _runDeviceProbe,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildArtworkTrueColorStudioTab(),
          _buildProCameraStudioTab(),
          _buildProVideoIsolationTab(),
          _buildProbeTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) {
          setState(() => _selectedIndex = idx);
          if (idx == 0 || idx == 1) {
            _pushManualControlsToNative(artworkMode: idx == 0);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.palette_outlined),
            label: 'Sanat (Gerçek Renk)',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_rounded),
            label: 'Pro Fotoğraf',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            label: 'Pro Video',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_rounded),
            label: 'Faz 0: Probe',
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinderCard({required bool isArtworkMode}) {
    final session = _previewSession;
    final lastRes = _lastCaptureResult;
    final hist = lastRes?.rawHistogram32;
    return Card(
      color: const Color(0xFF12151C),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _onViewfinderTapUp(details, constraints),
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
                        Container(
                          color: const Color(0xFF0A0C10),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.sensors_rounded,
                                size: 42,
                                color: Color(0xFFE5A93C),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isArtworkMode
                                    ? 'Sanat Modu Canlı RAW Vizörü (sRGB / Display P3 Doğrusal)'
                                    : 'Pro Kamera Fiziksel Lens Vizörü (Sıfır Otomatik Lens Geçişi)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    _startOrSwitchCamera(_selectedCameraId),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Canlı Vizörü Başlat'),
                              ),
                            ],
                          ),
                        ),
                      if (isArtworkMode && _showPerspectiveGrid)
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _ArtworkPerspectivePainter(),
                          ),
                        ),
                      if (_lastFocusTapNorm != null)
                        Positioned(
                          left: (_lastFocusTapNorm!.dx * constraints.maxWidth) - 26,
                          top: (_lastFocusTapNorm!.dy * constraints.maxHeight) - 26,
                          child: IgnorePointer(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE5A93C),
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4ECDC4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!isArtworkMode && _showZebra)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ZEBRA ${((lastRes?.zebraRatio ?? 0.0) * 100).toStringAsFixed(1)}% | '
                              '${_showFocusPeaking ? "PEAK ${(lastRes?.focusPeakingScore ?? 0.0).toStringAsFixed(2)} | " : ""}'
                              'LENS #$_selectedCameraId | '
                              '${_manualExposure ? "ISO ${_iso.toInt()} 1/${_shutterDenominator.toInt()}s" : "AE ${_evCompensation >= 0 ? "+" : ""}${_evCompensation.toStringAsFixed(1)}EV"}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Color(0xFF4ECDC4),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isArtworkMode
                                ? (_useMeasuredGrayCardWb
                                    ? 'GRİ KART WB KİLİTLİ'
                                    : 'DNG CCT WB (${lastRes?.solvedCctKelvin?.round() ?? 5500}K)')
                                : (_manualWb
                                    ? '${_kelvin.toInt()}K (T:${_tint.toInt()})'
                                    : 'RAW+JPEG (${lastRes?.solvedCctKelvin?.round() ?? 5500}K)'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE5A93C),
                            ),
                          ),
                        ),
                      ),
                      if (hist != null && hist.length == 32)
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            width: 148,
                            height: 46,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: CustomPaint(
                              painter: _RawHistogramPainter(hist),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _lastCaptureMessage ??
                      (isArtworkMode
                          ? 'Aktif Fiziksel Lens #$_selectedCameraId (14-Bit RAW → 12.6MP Rust TrueColor ISP)'
                          : 'Aktif Fiziksel Lens: ${_activeCameraCap?.opticalBadgeLabel ?? "#$_selectedCameraId"} (Dokunmatik AF/AE Aktif)'),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    if (isArtworkMode)
                      OutlinedButton.icon(
                        onPressed: _isCapturing
                            ? null
                            : () => _triggerPhotoCapture(
                                  isArtworkMode: true,
                                  lockGrayCardFromCenter: true,
                                ),
                        icon: const Icon(
                          Icons.filter_center_focus_rounded,
                          size: 18,
                        ),
                        label: const Text('Merkez %18 Gri Kart Ölç'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed:
                            _isCapturing ? null : _triggerBracketedCapture,
                        icon: const Icon(Icons.burst_mode_rounded, size: 18),
                        label: const Text('3-Kare Braket (±1.5 EV)'),
                      ),
                    FilledButton.icon(
                      onPressed: _isCapturing
                          ? null
                          : () => _triggerPhotoCapture(
                                isArtworkMode: isArtworkMode,
                              ),
                      icon: _isCapturing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_rounded),
                      label: Text(
                        isArtworkMode ? 'RAW + Gerçek Renk Çek' : 'RAW + Pro Çek',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastCaptureComparisonCard() {
    final res = _lastCaptureResult;
    if (res == null) return const SizedBox.shrink();

    final trueColorFile = res.jpegPath != null ? File(res.jpegPath!) : null;
    final oemFile = res.oemJpegPath != null ? File(res.oemJpegPath!) : null;
    final hasTrueColor = trueColorFile != null && trueColorFile.existsSync();
    final hasOem = oemFile != null && oemFile.existsSync();

    return Card(
      color: const Color(0xFF181B22),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.compare_rounded,
                  color: Color(0xFF4ECDC4),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Son Çekim: ${res.rustIspActive ? "Rust TrueColor ISP (${res.outputWidth ?? "-"}×${res.outputHeight ?? "-"})" : "Pro RAW + OEM JPEG (Hızlı Telemetri)"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4ECDC4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (hasTrueColor || hasOem)
              Row(
                children: [
                  if (hasTrueColor)
                    Expanded(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              trueColorFile,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            res.rustIspActive
                                ? 'Zamera TrueColor (${_useDisplayP3 ? "P3" : "sRGB"})'
                                : 'Kaydedilen JPEG',
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
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              oemFile,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 4),
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF101318),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• Galeri (DCIM/Zamera): ${res.mediaStoreJpegUri ?? "Yerel Dizin"}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                  Text(
                    '• Arşiv DNG (14-Bit Dik Orientation=6): ${res.mediaStoreDngUri ?? res.dngPath ?? "-"}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                  if (res.solvedCctKelvin != null)
                    Text(
                      '• Çözülen Işık CCT: ${res.solvedCctKelvin!.round()}K | Pozlama Kazancı: ×${(res.exposureNormGain ?? 1.0).toStringAsFixed(2)} | Zebra: ${((res.zebraRatio ?? 0.0) * 100).toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Color(0xFF4ECDC4),
                      ),
                    ),
                  if (res.whiteLevel != null)
                    Text(
                      '• Sensör Dinamik: WhiteLevel=${res.whiteLevel!.toInt()} | Black=${res.blackLevel?.map((e) => e.toInt()).toList()} | LensShadingApplied=${res.lensShadingApplied}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  if (res.centerLinearCamRgb != null)
                    Text(
                      '• Merkez ROI Doğrusal RGB: [${res.centerLinearCamRgb!.map((e) => e.toStringAsFixed(4)).join(", ")}] | Highlight Clip: ${((res.highlightClippedRatio ?? 0.0) * 100).toStringAsFixed(2)}%',
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
        ),
      ),
    );
  }

  Widget _buildArtworkTrueColorStudioTab() {
    final cal = _calibrationResult;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildViewfinderCard(isArtworkMode: true),
        _buildLastCaptureComparisonCard(),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF181B22),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Çizim & Sanat Eseri Hizalama, Tam Çözünürlük ve Pozlama (Faz 2.0)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE5A93C),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text(
                        _fullResolution
                            ? 'Tam Çözünürlük 12.6MP (3072×4096)'
                            : 'Hızlı Önizleme 3.1MP (1536×2048)',
                      ),
                      selected: _fullResolution,
                      onSelected: (v) => setState(() => _fullResolution = v),
                    ),
                    FilterChip(
                      label: const Text('Beyaz Nokta Pozlama Dengeleme (L*≈94)'),
                      selected: _normalizeExposure,
                      onSelected: (v) => setState(() => _normalizeExposure = v),
                    ),
                    FilterChip(
                      label: const Text('4-Köşe Perspektif Kılavuzu'),
                      selected: _showPerspectiveGrid,
                      onSelected: (v) =>
                          setState(() => _showPerspectiveGrid = v),
                    ),
                    FilterChip(
                      label: const Text('Flat-Field (8×6 Aydınlatma Düzeltme)'),
                      selected: _flatFieldEnabled,
                      onSelected: (v) => setState(() => _flatFieldEnabled = v),
                    ),
                    FilterChip(
                      label: Text(
                        _useDisplayP3
                            ? 'Çıktı: Display P3'
                            : 'Çıktı: sRGB (Standart)',
                      ),
                      selected: _useDisplayP3,
                      onSelected: (v) => setState(() => _useDisplayP3 = v),
                    ),
                    if (_measuredGrayCardWbGains != null)
                      FilterChip(
                        label: const Text('Ölçülen %18 Gri Kart WB Aktif'),
                        selected: _useMeasuredGrayCardWb,
                        onSelected: (v) =>
                            setState(() => _useMeasuredGrayCardWb = v),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF181B22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '2. 24-Yama ColorChecker & %18 Gri Kart Kalibrasyon Motoru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE5A93C),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _useMeasuredGrayCardWb
                            ? const Color(0xFF1D4E4A)
                            : const Color(0xFF3A2E18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _useMeasuredGrayCardWb
                            ? 'CANLI SENSÖR WB'
                            : 'DNG CCT İNTERPOLASYON',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'DNG 1.7 standardına göre sahne renk sıcaklığı (CCT) AsShotNeutral + ColorMatrix1/2 üzerinden çözülür ve ForwardMatrix1 (D65) ile ForwardMatrix2 (StdA) mired uzayında enterpole edilir.',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Sensör Sıcaklık Sapması Simülasyonu:'),
                    Expanded(
                      child: Slider(
                        value: _simulatedSensorWarmth,
                        min: 1.0,
                        max: 2.0,
                        divisions: 20,
                        label: _simulatedSensorWarmth.toStringAsFixed(2),
                        onChanged: (v) {
                          setState(() {
                            _simulatedSensorWarmth = v;
                            _recomputeCalibration();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101318),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• Kalibrasyon Öncesi Ortalama Sapma: ΔE00 = ${cal.meanDeltaEBefore.toStringAsFixed(2)} (Bozuk Renk)',
                        style: const TextStyle(color: Colors.amberAccent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Zamera 3×3 Kalibrasyon Sonrası: ΔE00 Ort = ${cal.meanDeltaEAfter.toStringAsFixed(2)} | Maks = ${cal.maxDeltaEAfter.toStringAsFixed(2)} (Müze Standardı ≤ 2.0)',
                        style: const TextStyle(
                          color: Color(0xFF4ECDC4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _useMeasuredGrayCardWb && _measuredGrayCardWbGains != null
                            ? '• Canlı Ölçülen %18 Gri Kart Kazançları: R=${_measuredGrayCardWbGains![0].toStringAsFixed(3)}, G=1.000, B=${_measuredGrayCardWbGains![2].toStringAsFixed(3)}'
                            : '• Simüle Gri Kart RGGB Kazançları: R=${cal.wbGains[0].toStringAsFixed(3)}, G=${cal.wbGains[1].toStringAsFixed(3)}, B=${cal.wbGains[2].toStringAsFixed(3)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: kColorChecker24Patches.length,
                  itemBuilder: (context, i) {
                    final patch = kColorChecker24Patches[i];
                    final deAfter = cal.patchDeltaEAfter[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Color(patch.previewArgb),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      padding: const EdgeInsets.all(4),
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        color: Colors.black54,
                        child: Text(
                          '#${patch.index}\nΔ${deAfter.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProCameraStudioTab() {
    final cameras = _probeReport?.cameras ?? const <CameraUnitCapability>[];
    final activeCap = _activeCameraCap;
    final isoRange = activeCap?.isoRange;
    final isoMin = (isoRange != null && isoRange.length >= 2)
        ? isoRange[0].toDouble()
        : 50.0;
    final isoMax = (isoRange != null && isoRange.length >= 2)
        ? isoRange[1].toDouble()
        : 3200.0;
    final clampedIso = _iso.clamp(isoMin, isoMax);
    final supportsVariableFocus = activeCap?.supportsVariableFocus ?? true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildViewfinderCard(isArtworkMode: false),
        _buildLastCaptureComparisonCard(),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF181B22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fiziksel Lens Kilidi (1.0× Optik Sabit — Otomatik Makro / Dijital Crop Engelleme)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE5A93C),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (cameras.isNotEmpty)
                      for (final cam in cameras)
                        ChoiceChip(
                          label: Text(cam.opticalBadgeLabel),
                          selected: _selectedCameraId == cam.cameraId,
                          onSelected: (_) => _startOrSwitchCamera(cam.cameraId),
                        )
                    else
                      for (final id in const ['0', '1', '2', '3'])
                        ChoiceChip(
                          label: Text('Fiziksel Lens #$id'),
                          selected: _selectedCameraId == id,
                          onSelected: (_) => _startOrSwitchCamera(id),
                        ),
                  ],
                ),
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Manuel Pozlama Kilidi (ISO & Enstantane)'),
                  subtitle: Text(
                    _manualExposure
                        ? 'Sensör Donanım Aralığı: ISO ${isoMin.toInt()}..${isoMax.toInt()}'
                        : 'Otomatik AE Aktif — Aşağıdan ±3.0 EV Pozlama Telafisi Verilebilir',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  value: _manualExposure,
                  onChanged: (v) {
                    setState(() => _manualExposure = v);
                    _pushManualControlsToNative(artworkMode: false);
                  },
                ),
                if (!_manualExposure)
                  Row(
                    children: [
                      SizedBox(
                        width: 115,
                        child: Text(
                          'EV Telafi: ${_evCompensation >= 0 ? "+" : ""}${_evCompensation.toStringAsFixed(1)}',
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
                            setState(() => _evCompensation = v);
                            _pushManualControlsToNative(artworkMode: false);
                          },
                        ),
                      ),
                    ],
                  ),
                if (_manualExposure) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text('ISO: ${clampedIso.toInt()}'),
                      ),
                      Expanded(
                        child: Slider(
                          value: clampedIso,
                          min: isoMin,
                          max: isoMax,
                          divisions: ((isoMax - isoMin) / 25).round().clamp(10, 120),
                          onChanged: (v) {
                            setState(() => _iso = v);
                            _pushManualControlsToNative(artworkMode: false);
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text('Shutter: 1/${_shutterDenominator.toInt()}s'),
                      ),
                      Expanded(
                        child: Slider(
                          value: _shutterDenominator,
                          min: 2,
                          max: 4000,
                          onChanged: (v) {
                            setState(() => _shutterDenominator = v);
                            _pushManualControlsToNative(artworkMode: false);
                          },
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('180° (24fps → 1/48s)'),
                        onPressed: () {
                          setState(() => _shutterDenominator = 48);
                          _pushManualControlsToNative(artworkMode: false);
                        },
                      ),
                      ActionChip(
                        label: const Text('180° (60fps → 1/120s)'),
                        onPressed: () {
                          setState(() => _shutterDenominator = 120);
                          _pushManualControlsToNative(artworkMode: false);
                        },
                      ),
                    ],
                  ),
                ],
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Manuel Beyaz Dengesi (DNG Kelvin & Tint Matris Kilidi)',
                  ),
                  subtitle: const Text(
                    'Sensör ColorMatrix1/2 & ForwardMatrix1/2 üzerinden gerçek kromatik uyarlama',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  value: _manualWb,
                  onChanged: (v) {
                    setState(() => _manualWb = v);
                    _pushManualControlsToNative(artworkMode: false);
                  },
                ),
                if (_manualWb) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text('Kelvin: ${_kelvin.toInt()}K'),
                      ),
                      Expanded(
                        child: Slider(
                          value: _kelvin,
                          min: 2500,
                          max: 9000,
                          divisions: 65,
                          onChanged: (v) {
                            setState(() => _kelvin = v);
                            _pushManualControlsToNative(artworkMode: false);
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text('Tint: ${_tint.toInt()}'),
                      ),
                      Expanded(
                        child: Slider(
                          value: _tint,
                          min: -50,
                          max: 50,
                          divisions: 100,
                          onChanged: (v) {
                            setState(() => _tint = v);
                            _pushManualControlsToNative(artworkMode: false);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 24),
                if (!supportsVariableFocus)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.lock_clock_rounded, color: Colors.amber),
                    title: Text('Sabit Odaklı Fiziksel Lens (Sonsuz Hiperfokal)'),
                    subtitle: Text(
                      'Bu lens (minimumFocusDistance = 0.0 dioptri) sabit odaklıdır; manuel odak sürgüsü devre dışıdır.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  )
                else ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Manuel Odak (0.0 Sonsuz .. ${(activeCap?.minimumFocusDistanceDiopters ?? 10.0).toStringAsFixed(1)} Dioptri)',
                    ),
                    value: _manualFocus,
                    onChanged: (v) {
                      setState(() => _manualFocus = v);
                      _pushManualControlsToNative(artworkMode: false);
                    },
                  ),
                  if (_manualFocus)
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            'Odak: ${_focusDistance.toStringAsFixed(2)}',
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _focusDistance,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (v) {
                              setState(() => _focusDistance = v);
                              _pushManualControlsToNative(artworkMode: false);
                            },
                          ),
                        ),
                      ],
                    ),
                ],
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Zebra (%95 Gelinlik Highlight)'),
                      selected: _showZebra,
                      onSelected: (v) => setState(() => _showZebra = v),
                    ),
                    FilterChip(
                      label: const Text('Focus Peaking'),
                      selected: _showFocusPeaking,
                      onSelected: (v) => setState(() => _showFocusPeaking = v),
                    ),
                    FilterChip(
                      label: Text(
                        _preferProRaw48Mp
                            ? 'iOS 48MP ProRAW / Max-Res'
                            : 'Saf Bayer RAW (12.6MP Sıfır ISP)',
                      ),
                      selected: _preferProRaw48Mp,
                      onSelected: (v) => setState(() => _preferProRaw48Mp = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProVideoIsolationTab() {
    const videoInfo = ZameraVideoIsolationInfo();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF181B22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      videoInfo.isEnabledByFlag
                          ? Icons.videocam_rounded
                          : Icons.shield_outlined,
                      color: const Color(0xFF4ECDC4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pro Video Modülü (ZAMERA_VIDEO=${videoInfo.isEnabledByFlag})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE5A93C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  videoInfo.isolationPolicy,
                  style: const TextStyle(height: 1.45),
                ),
                const Divider(height: 24),
                const Text(
                  'Desteklenen / Planlanan Sinema Profilleri:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• iOS 17+ Apple Log & ProRes 422 HQ (Harici USB-C SSD Doğrudan Kayıt)\n'
                  '• Android 14+ 10-bit HLG10 / HDR10 (DynamicRangeProfiles)\n'
                  '• 180° Shutter Angle Kilidi (24fps → 1/48s, 60fps → 1/120s)\n'
                  '• Termal & Bellek İzolasyonu: Sanat Modu RAW oturumu ile sıfır çakışma',
                  style: TextStyle(color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProbeTab() {
    if (_loadingProbe) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_probeError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Donanım tarama hatası:\n$_probeError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }
    final report = _probeReport;
    if (report == null) {
      return const Center(child: Text('Henüz rapor yok.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF181B22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.brand.toUpperCase()} ${report.model} (${report.device})',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE5A93C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Platform: ${report.platform.toUpperCase()} ${report.release} (API/SDK ${report.sdkInt})',
                ),
                Text(
                  'Rust Motoru: ${report.rustCoreVersion}',
                  style: TextStyle(
                    color: report.rustCoreVersion.contains('UNLOADED')
                        ? Colors.redAccent
                        : const Color(0xFF4ECDC4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Keşfedilen Kamera ID Listesi: ${report.cameraIdList.join(", ")}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final cam in report.cameras)
          Card(
            color: const Color(0xFF181B22),
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        cam.supportsRawSensor
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        color: cam.supportsRawSensor
                            ? const Color(0xFF4ECDC4)
                            : Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${cam.opticalBadgeLabel} (${cam.facing}) — ${cam.hardwareLevel}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (cam.error != null)
                    Text(
                      'HAL Durumu: ${cam.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    )
                  else ...[
                    Text(
                      '• RAW_SENSOR: ${cam.supportsRawSensor ? "EVET (${cam.rawSensorSizes.join(", ")})" : "HAYIR"} | WhiteLevel: ${cam.sensorWhiteLevel ?? "-"}',
                    ),
                    Text(
                      '• LensShadingApplied: ${cam.lensShadingApplied} | Orientation: ${cam.sensorOrientation}°',
                    ),
                    if (cam.physicalCameraIds.isNotEmpty)
                      Text(
                        '• Alt Fiziksel Lens ID\'leri: ${cam.physicalCameraIds.join(", ")}',
                      ),
                    if (cam.focalLengthsMm.isNotEmpty)
                      Text(
                        '• Odak Uzaklığı / Diyafram: ${cam.focalLengthsMm.join(", ")} mm | f/${cam.apertures.join(", f/")}',
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
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

class _ArtworkPerspectivePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFFE5A93C).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rect = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.1,
      size.width * 0.8,
      size.height * 0.8,
    );
    canvas.drawRect(rect, borderPaint);

    final centerRoi = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.5),
      width: size.width * 0.14,
      height: size.width * 0.14,
    );
    final roiPaint = Paint()
      ..color = const Color(0xFF4ECDC4).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(centerRoi, roiPaint);

    final cornerPaint = Paint()
      ..color = const Color(0xFF4ECDC4)
      ..style = PaintingStyle.fill;
    for (final pt in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(pt, 6.0, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
