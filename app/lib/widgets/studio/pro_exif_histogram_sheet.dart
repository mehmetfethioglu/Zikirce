import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/camera_colors.dart';
import '../../models/inspector_colorimetry.dart';
import '../../models/media_archive_item.dart';
import '../../painters/checkerboard_and_lift_painter.dart';

/// Displays EXIF optics metadata, RGB/Luminance 64-bin Histogram, `CIE L*a*b* (D50)` / `ΔE00`
/// pixel readout card, and separate JPEG / RAW DNG share buttons.
class ProExifHistogramCard extends StatelessWidget {
  final ZameraMediaItem item;
  final RgbHistogramData? rgbHistogram;
  final InspectedPixelMeasurement? pixelMeasurement;
  final bool showingOem;
  final VoidCallback? onToggleOem;
  final VoidCallback? onShareJpeg;
  final VoidCallback? onShareDng;

  const ProExifHistogramCard({
    super.key,
    required this.item,
    this.rgbHistogram,
    this.pixelMeasurement,
    this.showingOem = false,
    this.onToggleOem,
    this.onShareJpeg,
    this.onShareDng,
  });

  static String _formatShutter(int? exposureNs) {
    if (exposureNs == null || exposureNs <= 0) return 'Oto';
    final sec = exposureNs / 1e9;
    if (sec >= 0.4) return '${sec.toStringAsFixed(1)}s';
    final denom = (1.0 / sec).round().clamp(1, 32000);
    return '1/${denom}s';
  }

  static String _formatFileSize(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return '—';
      final bytes = f.lengthSync();
      if (bytes >= 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / 1024).round()} KB';
    } catch (e) {
      debugPrint('ProExifHistogramCard._formatFileSize warning: $e');
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final resStr = (item.width != null && item.height != null)
        ? '${item.width}×${item.height}'
        : '—';
    final isoStr = item.iso != null ? 'ISO ${item.iso}' : 'ISO Oto';
    final shutterStr = _formatShutter(item.exposureTimeNs);
    final kelvStr = item.solvedCctKelvin != null
        ? '${item.solvedCctKelvin!.round()}K'
        : '5500K';
    final csTag = item.colorSpaceTag?.isNotEmpty == true
        ? item.colorSpaceTag!
        : 'sRGB';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // EXIF & Optical Badges
        Container(
          key: const ValueKey('studio_exif_card'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF121620),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.camera_outlined,
                    size: 16,
                    color: kZameraCyan,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'OPTİK & SENSÖR TELEMETRİSİ',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  if (item.rustIspActive)
                    _MiniBadge(label: 'TRUECOLOR 1:1', color: kZameraCyan),
                  if (item.hasRaw) ...[
                    const SizedBox(width: 6),
                    const _MiniBadge(label: '14b DNG RAW', color: kIosYellow),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExifMetricTile(label: 'Duyarlılık', value: isoStr),
                  _ExifMetricTile(label: 'Enstantane', value: shutterStr),
                  _ExifMetricTile(label: 'Beyaz Dengesi', value: kelvStr),
                  _ExifMetricTile(label: 'Renk Uzayı', value: csTag),
                  _ExifMetricTile(label: 'Çözünürlük', value: resStr),
                  _ExifMetricTile(
                    label: 'Boyut',
                    value: _formatFileSize(item.primaryPath),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Multi-Channel RGB Histogram
        if ((rgbHistogram != null && !rgbHistogram!.isEmpty) ||
            (item.rawHistogram32 != null && item.rawHistogram32!.isNotEmpty))
          Container(
            key: const ValueKey('studio_histogram_card'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF121620),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RGB & LÜMİNANS HİSTOGRAMI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white70,
                      ),
                    ),
                    if (rgbHistogram != null && !rgbHistogram!.isEmpty)
                      Text(
                        'Highlight ${(rgbHistogram!.highlightClipRatio * 100).toStringAsFixed(1)}% · Shadow ${(rgbHistogram!.shadowClipRatio * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          color: kIosYellow,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 76,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: MultiChannelHistogramPainter(
                      rgbHistogram: rgbHistogram,
                      fallbackLumaBins: item.rawHistogram32,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (pixelMeasurement != null) ...[
          const SizedBox(height: 10),
          _PixelColorimeterDetailsCard(
            measurement: pixelMeasurement!,
            showingOem: showingOem,
            hasOemComparison: item.hasOemComparison,
            onToggleOem: onToggleOem,
          ),
        ],

        if (onShareJpeg != null || (item.hasRaw && onShareDng != null)) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (onShareJpeg != null)
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('studio_share_jpeg_btn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onShareJpeg,
                    icon: const Icon(Icons.photo_outlined, size: 16),
                    label: Text(
                      item.kind == ZameraMediaKind.sticker
                          ? 'PNG Paylaş'
                          : 'JPEG Paylaş',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (item.hasRaw && onShareDng != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('studio_share_dng_btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kIosYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onShareDng,
                    icon: const Icon(Icons.raw_on_rounded, size: 17),
                    label: const Text(
                      'RAW (.DNG) Paylaş',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ExifMetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _ExifMetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.white54),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PixelColorimeterDetailsCard extends StatelessWidget {
  final InspectedPixelMeasurement measurement;
  final bool showingOem;
  final bool hasOemComparison;
  final VoidCallback? onToggleOem;

  const _PixelColorimeterDetailsCard({
    required this.measurement,
    required this.showingOem,
    required this.hasOemComparison,
    this.onToggleOem,
  });

  static String _signed(double v) =>
      '${v >= 0.0 ? '+' : ''}${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final m = measurement;
    final deColor = m.deltaE00 <= 2.0
        ? const Color(0xFF30D158)
        : (m.deltaE00 <= 4.5 ? kIosYellow : const Color(0xFFFF9F0A));

    return Container(
      key: const ValueKey('inspector_artwork_colorimeter_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141821),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kZameraCyan.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, m.r, m.g, m.b),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white54, width: 1.0),
                ),
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Color(m.nearestPatch.previewArgb),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomRight: Radius.circular(7),
                    ),
                    border: Border.all(color: Colors.black54, width: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          m.hexString,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kZameraCyan.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            m.colorSpaceTag,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: kZameraCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'CIE L*a*b* (D50): L* ${m.labD50[0].toStringAsFixed(2)}  a* ${_signed(m.labD50[1])}  b* ${_signed(m.labD50[2])}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: kIosYellow,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '#HEX Kopyala',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          '${m.hexString} | L*=${m.labD50[0].toStringAsFixed(2)} a*=${m.labD50[1].toStringAsFixed(2)} b*=${m.labD50[2].toStringAsFixed(2)} | ΔE00=${m.deltaE00.toStringAsFixed(2)}',
                    ),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${m.hexString} ve CIE L*a*b* kopyalandı'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'sRGB (${m.r}, ${m.g}, ${m.b})  ·  Display P3 (${m.displayP3Rgb8[0]}, ${m.displayP3Rgb8[1]}, ${m.displayP3Rgb8[2]})',
            style: const TextStyle(
              fontSize: 10.0,
              fontFamily: 'monospace',
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ColorChecker #${m.nearestPatch.index} ${m.nearestPatch.nameTr} · ΔE00 = ${m.deltaE00.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: deColor,
                  ),
                ),
              ),
              if (hasOemComparison && onToggleOem != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: showingOem ? kIosYellow : kZameraCyan,
                  ),
                  onPressed: onToggleOem,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                  label: Text(
                    showingOem ? 'TrueColor Göster' : 'Stok (OEM) Göster',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
