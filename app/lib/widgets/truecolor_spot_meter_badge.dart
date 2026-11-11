import 'package:flutter/material.dart';
import 'package:zamera_capture/zamera_capture.dart';
import '../constants/camera_colors.dart';

/// Atomic 120-FPS HUD badge displaying live center-spot sRGB swatch, `#HEX`,
/// `CIE L*a*b* (D50)`, active WB/calibration state, and nearest ColorChecker `ΔE00`.
class TrueColorSpotMeterBadge extends StatelessWidget {
  final List<int> srgb8;
  final List<double> labD50;
  final ColorCheckerPatch? nearestPatch;
  final double? deltaE00;
  final bool isCalibrated;
  final String wbLabel;

  const TrueColorSpotMeterBadge({
    super.key,
    required this.srgb8,
    required this.labD50,
    this.nearestPatch,
    this.deltaE00,
    this.isCalibrated = false,
    this.wbLabel = 'DNG',
  });

  static String formatHex(int r, int g, int b) {
    final rh = r.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final gh = g.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final bh = b.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$rh$gh$bh'.toUpperCase();
  }

  static String _signedFixed(double value) {
    final sign = value >= 0.0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final r = srgb8.isNotEmpty ? srgb8[0].clamp(0, 255) : 128;
    final g = srgb8.length > 1 ? srgb8[1].clamp(0, 255) : 128;
    final b = srgb8.length > 2 ? srgb8[2].clamp(0, 255) : 128;

    final effectiveLab = labD50.length >= 3
        ? labD50
        : ZameraCapture.srgb8ToLabD50(r, g, b);
    final patch =
        nearestPatch ?? ZameraCapture.nearestColorCheckerPatch(effectiveLab);
    final de00 =
        deltaE00 ?? ZameraCapture.computeCiede2000(effectiveLab, patch.labD50);
    final hexStr = formatHex(r, g, b);

    final deColor = de00 <= 2.0
        ? const Color(0xFF30D158)
        : (de00 <= 4.5 ? kIosYellow : const Color(0xFFFF9F0A));

    return RepaintBoundary(
      child: Container(
        key: const ValueKey('truecolor_spot_meter_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isCalibrated
                ? kZameraCyan.withValues(alpha: 0.65)
                : Colors.white24,
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SpotColorComparisonSwatch(
              liveColor: Color.fromARGB(255, r, g, b),
              referenceColor: Color(patch.previewArgb),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hexStr,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isCalibrated
                              ? kZameraCyan.withValues(alpha: 0.22)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isCalibrated ? '3×3 · $wbLabel' : wbLabel,
                          style: TextStyle(
                            fontSize: 8.0,
                            fontWeight: FontWeight.w800,
                            color: isCalibrated ? kZameraCyan : kIosYellow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'L* ${effectiveLab[0].toStringAsFixed(1)}  a* ${_signedFixed(effectiveLab[1])}  b* ${_signedFixed(effectiveLab[2])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: kIosYellow,
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Text(
                    '#${patch.index} ${patch.nameTr} · ΔE00 ${de00.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: deColor,
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
}

class _SpotColorComparisonSwatch extends StatelessWidget {
  final Color liveColor;
  final Color referenceColor;

  const _SpotColorComparisonSwatch({
    required this.liveColor,
    required this.referenceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: liveColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white54, width: 1.0),
      ),
      alignment: Alignment.bottomRight,
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: referenceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            bottomRight: Radius.circular(6),
          ),
          border: Border.all(color: Colors.black54, width: 0.7),
        ),
      ),
    );
  }
}

/// Center optical spot-metering reticle for 1:1 Artwork TrueColor & Gray-Card WB sampling.
class TrueColorCenterReticle extends StatelessWidget {
  final double size;
  final List<int> srgb8;
  final bool isCalibrated;

  const TrueColorCenterReticle({
    super.key,
    this.size = 44.0,
    this.srgb8 = const [128, 128, 128],
    this.isCalibrated = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = srgb8.isNotEmpty ? srgb8[0].clamp(0, 255) : 128;
    final g = srgb8.length > 1 ? srgb8[1].clamp(0, 255) : 128;
    final b = srgb8.length > 2 ? srgb8[2].clamp(0, 255) : 128;

    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          key: const ValueKey('truecolor_center_reticle'),
          width: size,
          height: size,
          child: CustomPaint(
            painter: _TrueColorCenterReticlePainter(
              sampleColor: Color.fromARGB(255, r, g, b),
              isCalibrated: isCalibrated,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrueColorCenterReticlePainter extends CustomPainter {
  final Color sampleColor;
  final bool isCalibrated;

  const _TrueColorCenterReticlePainter({
    required this.sampleColor,
    required this.isCalibrated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final outerRadius = size.shortestSide * 0.42;
    final innerRadius = size.shortestSide * 0.14;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(center, outerRadius, shadowPaint);

    final ringPaint = Paint()
      ..color = isCalibrated ? kZameraCyan : kIosYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(center, outerRadius, ringPaint);

    final tickLen = size.shortestSide * 0.12;
    canvas.drawLine(
      Offset(center.dx - outerRadius - 3, center.dy),
      Offset(center.dx - outerRadius + tickLen, center.dy),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx + outerRadius - tickLen, center.dy),
      Offset(center.dx + outerRadius + 3, center.dy),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - outerRadius - 3),
      Offset(center.dx, center.dy - outerRadius + tickLen),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + outerRadius - tickLen),
      Offset(center.dx, center.dy + outerRadius + 3),
      ringPaint,
    );

    final fillPaint = Paint()
      ..color = sampleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, fillPaint);

    final dotBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawCircle(center, innerRadius, dotBorder);
  }

  @override
  bool shouldRepaint(covariant _TrueColorCenterReticlePainter oldDelegate) {
    return oldDelegate.sampleColor != sampleColor ||
        oldDelegate.isCalibrated != isCalibrated;
  }
}
