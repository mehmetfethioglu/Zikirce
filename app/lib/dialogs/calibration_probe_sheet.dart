import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zamera_capture/zamera_capture.dart';
import '../constants/camera_colors.dart';

/// Modal bottom sheet displaying ColorChecker 24-patch calibration matrix and hardware probe JSON.
class CalibrationAndProbeSheet extends StatelessWidget {
  final ColorCheckerCalibrationResult calibrationResult;
  final ZameraProbeReport? probeReport;

  const CalibrationAndProbeSheet({
    super.key,
    required this.calibrationResult,
    this.probeReport,
  });

  static Future<void> show(
    BuildContext context, {
    required ColorCheckerCalibrationResult calibrationResult,
    ZameraProbeReport? probeReport,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => CalibrationAndProbeSheet(
        calibrationResult: calibrationResult,
        probeReport: probeReport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cal = calibrationResult;
    final report = probeReport;

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
                      color: kIosYellow,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Probe JSON panoya kopyalandı!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.copy_all_rounded, color: kZameraCyan),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '• Kalibrasyon Öncesi: ΔE00 = ${cal.meanDeltaEBefore.toStringAsFixed(2)} → Kalibrasyon Sonrası: ΔE00 Ort = ${cal.meanDeltaEAfter.toStringAsFixed(2)} (Maks = ${cal.maxDeltaEAfter.toStringAsFixed(2)})',
              style: const TextStyle(
                fontSize: 12,
                color: kZameraCyan,
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
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 24, color: Colors.white24),
            if (report != null) ...[
              Text(
                '${report.brand.toUpperCase()} ${report.model} (${report.device}) — ${report.rustCoreVersion}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: kIosYellow,
                ),
              ),
              const SizedBox(height: 8),
              for (final cam in report.cameras)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${cam.opticalBadgeLabel}: RAW=${cam.rawSensorSizes.join("/")} | MaxRAW=${cam.maxResolutionRawSensorSizes.join("/")} | White=${cam.sensorWhiteLevel ?? "-"}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
