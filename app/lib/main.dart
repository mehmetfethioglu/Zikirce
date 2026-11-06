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
  String _selectedCameraId = '0';
  String? _lastCaptureMessage;

  // Sanat Modu (TrueColor) State
  double _simulatedSensorWarmth = 1.45;
  bool _showPerspectiveGrid = true;
  bool _showColorCheckerOverlay = false;
  bool _flatFieldEnabled = true;
  late ColorCheckerCalibrationResult _calibrationResult;

  // Pro Fotoğraf State
  bool _manualExposure = true;
  double _iso = 100.0;
  double _shutterDenominator = 125.0; // 1/125 sec
  bool _manualFocus = false;
  double _focusDistance = 0.5;
  bool _manualWb = true;
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

  Future<void> _runDeviceProbe() async {
    setState(() {
      _loadingProbe = true;
      _probeError = null;
    });
    try {
      final report = await ZameraCapture.probeDeviceCapabilities();
      if (!mounted) return;
      setState(() {
        _probeReport = report;
        if (report.cameraIdList.isNotEmpty) {
          _selectedCameraId = report.cameraIdList.first;
        }
        _loadingProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _probeError = e.toString();
        _loadingProbe = false;
      });
    }
  }

  Future<void> _startOrSwitchCamera(String cameraId) async {
    setState(() => _selectedCameraId = cameraId);
    try {
      final info = await ZameraCapture.startPreviewSession(cameraId: cameraId);
      if (!mounted) return;
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
    final gains = artworkMode
        ? [
            _calibrationResult.wbGains[0],
            _calibrationResult.wbGains[1],
            _calibrationResult.wbGains[1],
            _calibrationResult.wbGains[2],
          ]
        : ZameraCapture.kelvinAndTintToRggbGains(_kelvin, _tint);
    try {
      await ZameraCapture.updateManualControls(
        manualExposure: _manualExposure,
        iso: _iso,
        exposureTimeNs: exposureNs,
        manualFocus: _manualFocus,
        focusDistance: _focusDistance,
        manualWb: _manualWb || artworkMode,
        rggbGains: gains,
        artworkLinearMode: artworkMode,
      );
    } catch (_) {}
  }

  Future<void> _triggerPhotoCapture({required bool isArtworkMode}) async {
    try {
      final res = await ZameraCapture.capturePhoto(
        captureRaw: true,
        preferProRaw: !isArtworkMode && _preferProRaw48Mp,
      );
      if (!mounted) return;
      setState(() {
        _lastCaptureMessage = isArtworkMode
            ? 'Sanat RAW+sRGB kaydedildi (ΔE00 ort: ${_calibrationResult.meanDeltaEAfter.toStringAsFixed(2)}): ${res.dngPath ?? res.jpegPath}'
            : 'Pro RAW+JPEG kaydedildi (${res.cameraId}): ${res.dngPath ?? res.jpegPath}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastCaptureMessage = 'Çekim bildirimi: $e';
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
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
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
    return Card(
      color: const Color(0xFF12151C),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (session != null && session.textureId >= 0)
                  Texture(textureId: session.textureId)
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
                    child: CustomPaint(painter: _ArtworkPerspectivePainter()),
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
                        'ZEBRA %95 | ${_showFocusPeaking ? "PEAKING ON | " : ""}ISO ${_iso.toInt()} | 1/${_shutterDenominator.toInt()}s | ${_kelvin.toInt()}K',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Color(0xFF4ECDC4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _lastCaptureMessage ??
                        (isArtworkMode
                            ? 'Kalibre ΔE00 Ort: ${_calibrationResult.meanDeltaEAfter.toStringAsFixed(2)} (Hedef ≤ 2.0)'
                            : 'Aktif Fiziksel Lens ID: $_selectedCameraId'),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      _triggerPhotoCapture(isArtworkMode: isArtworkMode),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: Text(
                    isArtworkMode ? 'RAW + Gerçek Renk Çek' : 'RAW + Pro Çek',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkTrueColorStudioTab() {
    final cal = _calibrationResult;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildViewfinderCard(isArtworkMode: true),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF181B22),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Çizim & Sanat Eseri Hizalama Araçları (iOS + Android)',
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
                      label: const Text('4-Köşe Perspektif Kılavuzu'),
                      selected: _showPerspectiveGrid,
                      onSelected: (v) =>
                          setState(() => _showPerspectiveGrid = v),
                    ),
                    FilterChip(
                      label: const Text('Flat-Field (Masa Lambası Dengeleme)'),
                      selected: _flatFieldEnabled,
                      onSelected: (v) => setState(() => _flatFieldEnabled = v),
                    ),
                    FilterChip(
                      label: const Text('24-Yama ColorChecker Tablosu'),
                      selected: _showColorCheckerOverlay,
                      onSelected: (v) =>
                          setState(() => _showColorCheckerOverlay = v),
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
                const Text(
                  '2. 24-Yama ColorChecker & %18 Gri Kart Kalibrasyon Motoru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE5A93C),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kağıt beyazı optik parlatıcı içerdiğinden beyaz dengesi Yama #20 (Neutral 8) ve Yama #22 (%18 Gri Kart) üzerinden kilitlenir; 24 yamanın tamamıyla 3×3 Kamera RGB → CIE XYZ (D50) matrisi çözülür.',
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
                        '• Gri Kart RGGB Kazançları: R=${cal.wbGains[0].toStringAsFixed(3)}, G=${cal.wbGains[1].toStringAsFixed(3)}, B=${cal.wbGains[2].toStringAsFixed(3)}',
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
    final cameraIds = _probeReport?.cameraIdList.isNotEmpty == true
        ? _probeReport!.cameraIdList
        : const ['0', '1', '2', '3'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildViewfinderCard(isArtworkMode: false),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF181B22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fiziksel Lens Kilidi (Otomatik Makro / Dijital Crop Engelleme)',
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
                    for (final id in cameraIds)
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
                  value: _manualExposure,
                  onChanged: (v) {
                    setState(() => _manualExposure = v);
                    _pushManualControlsToNative(artworkMode: false);
                  },
                ),
                if (_manualExposure) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text('ISO: ${_iso.toInt()}'),
                      ),
                      Expanded(
                        child: Slider(
                          value: _iso,
                          min: 50,
                          max: 6400,
                          divisions: 63,
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
                  title: const Text('Manuel Beyaz Dengesi (Kelvin & Tint Kilidi)'),
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Manuel Odak (Focus Pull Kilidi)'),
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
                            : 'Saf Bayer RAW (12MP Sıfır ISP)',
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
                  '• iOS (iPhone 17 Pro Max): Apple Log / Apple Log 2 + ProRes 422 HQ + Harici USB-C SSD + Open Gate (4:3)\n'
                  '• Android (Xiaomi 17 Pro Max): Camera2 DynamicRangeProfiles.HLG10 (10-bit BT.2020 HEVC) + Düz Ton Eğrisi\n'
                  '• Ortak: 180° Shutter Angle Kilidi, Gerçek Zamanlı .cube 3D LUT Önizleme, Stereo Ses VU-Meter',
                  style: TextStyle(height: 1.45, color: Colors.white70),
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
            'Probe Hatası:\n$_probeError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }
    final report = _probeReport!;
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
                  '${report.brand.toUpperCase()} — ${report.model}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE5A93C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Platform: ${report.platform.toUpperCase()} ${report.release} (SDK ${report.sdkInt})',
                ),
                const SizedBox(height: 4),
                Text(
                  'Rust Çekirdek: ${report.rustCoreVersion}',
                  style: const TextStyle(
                    color: Color(0xFF4ECDC4),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Açık Kamera ID Listesi: ${report.cameraIdList.join(", ")}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final cam in report.cameras)
          Card(
            color: const Color(0xFF181B22),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        cam.supportsRawSensor
                            ? Icons.raw_on_rounded
                            : Icons.videocam_outlined,
                        color: cam.supportsRawSensor
                            ? const Color(0xFF4ECDC4)
                            : Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kamera #${cam.cameraId} (${cam.facing}) — ${cam.hardwareLevel}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (cam.error != null)
                    Text(
                      'HAL Kısıtı: ${cam.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    )
                  else ...[
                    Text(
                      'RAW Sensör Desteği: ${cam.supportsRawSensor ? "✅ EVET" : "❌ HAYIR"}',
                    ),
                    if (cam.rawSensorSizes.isNotEmpty)
                      Text('RAW Boyutları: ${cam.rawSensorSizes.join(", ")}'),
                    if (cam.maxResolutionRawSensorSizes.isNotEmpty)
                      Text(
                        'Tam Çözünürlük (Max-Res) RAW: ${cam.maxResolutionRawSensorSizes.join(", ")}',
                      ),
                    if (cam.physicalCameraIds.isNotEmpty)
                      Text(
                        'Alt Fiziksel Lens ID\'leri: ${cam.physicalCameraIds.join(", ")}',
                      ),
                    if (cam.focalLengthsMm.isNotEmpty)
                      Text(
                        'Odak / Zoom Çarpanları: ${cam.focalLengthsMm.join(", ")}',
                      ),
                    if (cam.apertures.isNotEmpty)
                      Text('Diyafram: f/${cam.apertures.join(", f/")}'),
                    if (cam.isoRange != null && cam.isoRange!.length == 2)
                      Text(
                        'ISO Aralığı: ${cam.isoRange![0].toInt()} – ${cam.isoRange![1].toInt()}',
                      ),
                    if (cam.tenBitDynamicRangeProfiles.isNotEmpty)
                      Text(
                        '10-Bit / Renk Uzayları: ${cam.tenBitDynamicRangeProfiles.join(", ")}',
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: cam.capabilities
                          .map(
                            (c) => Chip(
                              label: Text(
                                c,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
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

class _ArtworkPerspectivePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5A93C).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.12,
      size.width * 0.76,
      size.height * 0.76,
    );
    canvas.drawRect(rect, paint);

    // 4 Corner Fiducial Brackets for Artwork Alignment
    const cornerLen = 22.0;
    final bracketPaint = Paint()
      ..color = const Color(0xFF4ECDC4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerLen, 0), bracketPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerLen), bracketPaint);
    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cornerLen, 0), bracketPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerLen), bracketPaint);
    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerLen, 0), bracketPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerLen), bracketPaint);
    // Bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cornerLen, 0), bracketPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cornerLen), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
