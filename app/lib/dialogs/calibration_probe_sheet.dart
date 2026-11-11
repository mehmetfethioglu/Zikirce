import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zamera_capture/zamera_capture.dart';
import '../constants/camera_colors.dart';

/// Modal bottom sheet displaying ColorChecker 24-patch calibration matrix,
/// sensor vs factory profile source, live calibration actions, and hardware probe JSON.
class CalibrationAndProbeSheet extends StatelessWidget {
  final ColorCheckerCalibrationResult calibrationResult;
  final ZameraProbeReport? probeReport;
  final String? activeCameraId;
  final VoidCallback? onTriggerCameraCalibration;
  final VoidCallback? onResetCalibration;

  const CalibrationAndProbeSheet({
    super.key,
    required this.calibrationResult,
    this.probeReport,
    this.activeCameraId,
    this.onTriggerCameraCalibration,
    this.onResetCalibration,
  });

  static Future<void> show(
    BuildContext context, {
    required ColorCheckerCalibrationResult calibrationResult,
    ZameraProbeReport? probeReport,
    String? activeCameraId,
    VoidCallback? onTriggerCameraCalibration,
    VoidCallback? onResetCalibration,
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
        activeCameraId: activeCameraId,
        onTriggerCameraCalibration: onTriggerCameraCalibration,
        onResetCalibration: onResetCalibration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cal = calibrationResult;
    final report = probeReport;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
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
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(
                      Icons.copy_all_rounded,
                      color: kZameraCyan,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _CalibrationProfileSourceCard(
              calibrationResult: cal,
              activeCameraId: activeCameraId,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('calibration_trigger_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kIosYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onTriggerCameraCalibration == null
                        ? null
                        : () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                            onTriggerCameraCalibration!();
                          },
                    icon: const Icon(Icons.grid_on_rounded, size: 16),
                    label: const Text(
                      '24-Yama Kalibre Et',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('calibration_reset_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onResetCalibration == null
                        ? null
                        : () {
                            onResetCalibration!();
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text(
                      'Kalibrasyonu Sıfırla',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.25,
              ),
              itemCount: kColorChecker24Patches.length,
              itemBuilder: (context, i) {
                final patch = kColorChecker24Patches[i];
                final deBefore = i < cal.patchDeltaEBefore.length
                    ? cal.patchDeltaEBefore[i]
                    : cal.meanDeltaEBefore;
                final deAfter = i < cal.patchDeltaEAfter.length
                    ? cal.patchDeltaEAfter[i]
                    : cal.meanDeltaEAfter;
                return _ColorCheckerPatchTile(
                  patch: patch,
                  deltaEBefore: deBefore,
                  deltaEAfter: deAfter,
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

class _CalibrationProfileSourceCard extends StatelessWidget {
  final ColorCheckerCalibrationResult calibrationResult;
  final String? activeCameraId;

  const _CalibrationProfileSourceCard({
    required this.calibrationResult,
    this.activeCameraId,
  });

  @override
  Widget build(BuildContext context) {
    final isSensor = calibrationResult.isMeasuredFromSensor;
    final sourceLabel = isSensor
        ? 'Gerçek Sensör Kalibrasyonu'
        : 'Fabrika/Referans';
    final badgeColor = isSensor ? const Color(0xFF30D158) : kIosYellow;
    final wb = calibrationResult.wbGains;
    final wbText = wb.length >= 3
        ? 'WB [${wb[0].toStringAsFixed(2)}, ${wb[1].toStringAsFixed(2)}, ${wb[2].toStringAsFixed(2)}]'
        : 'WB [DNG]';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF161B24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSensor ? Icons.verified_rounded : Icons.science_outlined,
                size: 16,
                color: badgeColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sourceLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
              if (activeCameraId != null)
                Text(
                  'Lens #$activeCameraId · $wbText',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• Kalibrasyon Öncesi: ΔE00 = ${calibrationResult.meanDeltaEBefore.toStringAsFixed(2)} → Kalibrasyon Sonrası: ΔE00 Ort = ${calibrationResult.meanDeltaEAfter.toStringAsFixed(2)} (Maks = ${calibrationResult.maxDeltaEAfter.toStringAsFixed(2)})',
            style: const TextStyle(
              fontSize: 11.5,
              color: kZameraCyan,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorCheckerPatchTile extends StatelessWidget {
  final ColorCheckerPatch patch;
  final double deltaEBefore;
  final double deltaEAfter;

  const _ColorCheckerPatchTile({
    required this.patch,
    required this.deltaEBefore,
    required this.deltaEAfter,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = deltaEAfter <= 1.5;
    return Container(
      decoration: BoxDecoration(
        color: Color(patch.previewArgb),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '#${patch.index} L*${patch.labD50[0].round()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8.0,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  patch.nameTr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  'Δ${deltaEBefore.toStringAsFixed(1)}→${deltaEAfter.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.0,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    color: isGood ? const Color(0xFF30D158) : kIosYellow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
