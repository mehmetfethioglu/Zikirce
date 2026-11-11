import 'package:flutter/material.dart';

import '../constants/camera_colors.dart';
import '../models/dslr_exposure_model.dart';

/// Atomic DSLR viewfinder HUD bar with P/Tv/Sv/M badges, shutter/ISO/WB cells,
/// Drive + AEL/AFL pills, and a real [-3..+3] EV light-meter scale.
class ProDslrExposureBar extends StatelessWidget {
  final DslrExposureMode mode;
  final ProDriveMode driveMode;
  final double meteredEvDelta;
  final double evCompensation;
  final bool aeAfLocked;
  final num? liveIso;
  final String liveShutterLabel;
  final String liveWbLabel;
  final int? countdownRemainingSec;
  final ValueChanged<DslrExposureMode>? onModeChanged;
  final ValueChanged<ProDriveMode>? onDriveModeChanged;
  final VoidCallback? onToggleAeAfLock;
  final VoidCallback? onTapIso;
  final VoidCallback? onTapShutter;
  final VoidCallback? onTapWb;
  final ValueChanged<double>? onEvChanged;

  const ProDslrExposureBar({
    super.key,
    required this.mode,
    this.driveMode = ProDriveMode.single,
    this.meteredEvDelta = 0.0,
    this.evCompensation = 0.0,
    this.aeAfLocked = false,
    this.liveIso = 100,
    this.liveShutterLabel = '1/125s',
    this.liveWbLabel = 'AWB',
    this.countdownRemainingSec,
    this.onModeChanged,
    this.onDriveModeChanged,
    this.onToggleAeAfLock,
    this.onTapIso,
    this.onTapShutter,
    this.onTapWb,
    this.onEvChanged,
  });

  @override
  Widget build(BuildContext context) {
    final int isoDisplay = (liveIso != null && liveIso! > 0)
        ? liveIso!.round()
        : 100;
    final int activeCountdown = countdownRemainingSec ?? 0;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: kSurfaceDark.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorderDark, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _DslrModeAndDriveRow(
              mode: mode,
              driveMode: driveMode,
              aeAfLocked: aeAfLocked,
              countdownRemainingSec: activeCountdown,
              onModeChanged: onModeChanged,
              onDriveModeChanged: onDriveModeChanged,
              onToggleAeAfLock: onToggleAeAfLock,
            ),
            const SizedBox(height: 6),
            _DslrTelemetryCellsRow(
              shutterLabel: liveShutterLabel,
              isShutterManual: mode.isShutterManual,
              isoValue: isoDisplay,
              isIsoManual: mode.isIsoManual,
              wbLabel: liveWbLabel,
              onTapShutter: onTapShutter,
              onTapIso: onTapIso,
              onTapWb: onTapWb,
            ),
            const SizedBox(height: 6),
            _DslrEvMeterRuler(
              meteredEvDelta: meteredEvDelta,
              evCompensation: evCompensation,
              isManualMode: mode == DslrExposureMode.manualM,
              aeAfLocked: aeAfLocked,
              onEvChanged: onEvChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DslrModeAndDriveRow extends StatelessWidget {
  final DslrExposureMode mode;
  final ProDriveMode driveMode;
  final bool aeAfLocked;
  final int countdownRemainingSec;
  final ValueChanged<DslrExposureMode>? onModeChanged;
  final ValueChanged<ProDriveMode>? onDriveModeChanged;
  final VoidCallback? onToggleAeAfLock;

  const _DslrModeAndDriveRow({
    required this.mode,
    required this.driveMode,
    required this.aeAfLocked,
    required this.countdownRemainingSec,
    required this.onModeChanged,
    required this.onDriveModeChanged,
    required this.onToggleAeAfLock,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: kObsidianBg.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorderDark, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final DslrExposureMode item in DslrExposureMode.values)
                _DslrModeBadge(
                  item: item,
                  isSelected: item == mode,
                  onModeChanged: onModeChanged,
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            mode.badgeLabelTr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB0B6C6),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        if (countdownRemainingSec > 0) ...<Widget>[
          _DslrCountdownBadge(seconds: countdownRemainingSec),
          const SizedBox(width: 5),
        ],
        _DslrDrivePill(
          driveMode: driveMode,
          onDriveModeChanged: onDriveModeChanged,
        ),
        const SizedBox(width: 5),
        _DslrAeAfLockPill(
          aeAfLocked: aeAfLocked,
          onToggleAeAfLock: onToggleAeAfLock,
        ),
      ],
    );
  }
}

class _DslrModeBadge extends StatelessWidget {
  final DslrExposureMode item;
  final bool isSelected;
  final ValueChanged<DslrExposureMode>? onModeChanged;

  const _DslrModeBadge({
    required this.item,
    required this.isSelected,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onModeChanged != null ? () => onModeChanged!(item) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? kIosYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          item.shortLabel,
          style: TextStyle(
            color: isSelected ? kObsidianBg : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _DslrCountdownBadge extends StatelessWidget {
  final int seconds;

  const _DslrCountdownBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFF3B30), width: 1),
      ),
      child: Text(
        '${seconds}s',
        style: const TextStyle(
          color: Color(0xFFFF6961),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _DslrDrivePill extends StatelessWidget {
  final ProDriveMode driveMode;
  final ValueChanged<ProDriveMode>? onDriveModeChanged;

  const _DslrDrivePill({
    required this.driveMode,
    required this.onDriveModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSpecial = driveMode != ProDriveMode.single;
    final Color accent = isSpecial ? kZameraCyan : Colors.white70;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDriveModeChanged != null
          ? () => onDriveModeChanged!(driveMode.next)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSpecial
              ? kZameraCyan.withValues(alpha: 0.16)
              : kCardDark,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isSpecial ? kZameraCyan : kBorderDark,
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              driveMode == ProDriveMode.aeb3
                  ? Icons.burst_mode_rounded
                  : (driveMode.timerSeconds > 0
                        ? Icons.timer_outlined
                        : Icons.crop_din_rounded),
              size: 11,
              color: accent,
            ),
            const SizedBox(width: 3.5),
            Text(
              driveMode.shortLabel,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DslrAeAfLockPill extends StatelessWidget {
  final bool aeAfLocked;
  final VoidCallback? onToggleAeAfLock;

  const _DslrAeAfLockPill({
    required this.aeAfLocked,
    required this.onToggleAeAfLock,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = aeAfLocked ? kObsidianBg : Colors.white70;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleAeAfLock,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: aeAfLocked ? kIosYellow : kCardDark,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: aeAfLocked ? kIosYellow : kBorderDark,
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              aeAfLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 11,
              color: fg,
            ),
            const SizedBox(width: 3),
            Text(
              'AEL/AFL',
              style: TextStyle(
                color: fg,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DslrTelemetryCellsRow extends StatelessWidget {
  final String shutterLabel;
  final bool isShutterManual;
  final int isoValue;
  final bool isIsoManual;
  final String wbLabel;
  final VoidCallback? onTapShutter;
  final VoidCallback? onTapIso;
  final VoidCallback? onTapWb;

  const _DslrTelemetryCellsRow({
    required this.shutterLabel,
    required this.isShutterManual,
    required this.isoValue,
    required this.isIsoManual,
    required this.wbLabel,
    required this.onTapShutter,
    required this.onTapIso,
    required this.onTapWb,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _DslrExposureCell(
            title: 'ENSTANTANE',
            value: shutterLabel,
            stateTag: isShutterManual ? 'M' : 'A',
            isManual: isShutterManual,
            onTap: onTapShutter,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _DslrExposureCell(
            title: 'ISO',
            value: '$isoValue',
            stateTag: isIsoManual ? 'M' : 'A',
            isManual: isIsoManual,
            onTap: onTapIso,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _DslrExposureCell(
            title: 'WB',
            value: wbLabel,
            stateTag: wbLabel.toUpperCase() == 'AWB' ? 'A' : 'K',
            isManual: wbLabel.toUpperCase() != 'AWB',
            onTap: onTapWb,
          ),
        ),
      ],
    );
  }
}

class _DslrExposureCell extends StatelessWidget {
  final String title;
  final String value;
  final String stateTag;
  final bool isManual;
  final VoidCallback? onTap;

  const _DslrExposureCell({
    required this.title,
    required this.value,
    required this.stateTag,
    required this.isManual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = isManual ? kIosYellow : kZameraCyan;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: kCardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isManual
                ? kIosYellow.withValues(alpha: 0.55)
                : kBorderDark,
            width: 0.9,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8E95A8),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3.5,
                    vertical: 0.5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3.5),
                  ),
                  child: Text(
                    stateTag,
                    style: TextStyle(
                      color: accent,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isManual ? kIosYellow : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DslrEvMeterRuler extends StatelessWidget {
  final double meteredEvDelta;
  final double evCompensation;
  final bool isManualMode;
  final bool aeAfLocked;
  final ValueChanged<double>? onEvChanged;

  const _DslrEvMeterRuler({
    required this.meteredEvDelta,
    required this.evCompensation,
    required this.isManualMode,
    required this.aeAfLocked,
    required this.onEvChanged,
  });

  static double _snapToThirdStop(double localDx, double width) {
    if (width <= 0) return 0.0;
    final double norm = (localDx / width).clamp(0.0, 1.0);
    final double rawEv = -3.0 + norm * 6.0;
    return ((rawEv * 3.0).round() / 3.0).clamp(-3.0, 3.0);
  }

  static String _formatEv(double ev) {
    final double clamped = ev.clamp(-3.0, 3.0);
    if (clamped.abs() < 0.05) return '±0.0';
    final String sign = clamped > 0 ? '+' : '';
    return '$sign${clamped.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool canAdjustEv = !isManualMode && onEvChanged != null;
    final double activeReadout = isManualMode ? meteredEvDelta : evCompensation;
    final bool isOutBounds = meteredEvDelta.abs() > 2.0;

    return Row(
      children: <Widget>[
        Container(
          width: 58,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: kObsidianBg.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isOutBounds
                  ? const Color(0xFFFF6961)
                  : kBorderDark,
              width: 0.8,
            ),
          ),
          child: Text(
            '${isManualMode ? "M.M" : "EV"} ${_formatEv(activeReadout)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isManualMode
                  ? (isOutBounds ? const Color(0xFFFF6961) : kZameraCyan)
                  : (evCompensation.abs() >= 0.05 ? kIosYellow : Colors.white70),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: canAdjustEv
                    ? (TapDownDetails d) => onEvChanged!(
                        _snapToThirdStop(d.localPosition.dx, width),
                      )
                    : null,
                onHorizontalDragUpdate: canAdjustEv
                    ? (DragUpdateDetails d) => onEvChanged!(
                        _snapToThirdStop(d.localPosition.dx, width),
                      )
                    : null,
                onDoubleTap: canAdjustEv ? () => onEvChanged!(0.0) : null,
                child: SizedBox(
                  height: 26,
                  width: width,
                  child: CustomPaint(
                    painter: _DslrEvScalePainter(
                      meteredEvDelta: meteredEvDelta.clamp(-3.0, 3.0),
                      evCompensation: evCompensation.clamp(-3.0, 3.0),
                      isManualMode: isManualMode,
                      aeAfLocked: aeAfLocked,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DslrEvScalePainter extends CustomPainter {
  final double meteredEvDelta;
  final double evCompensation;
  final bool isManualMode;
  final bool aeAfLocked;

  const _DslrEvScalePainter({
    required this.meteredEvDelta,
    required this.evCompensation,
    required this.isManualMode,
    required this.aeAfLocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padX = 8.0;
    final double usableW = (size.width - padX * 2).clamp(1.0, size.width);
    final double centerX = padX + usableW * 0.5;
    const double tickBaseY = 12.0;

    final Paint majorTickPaint = Paint()
      ..color = const Color(0xFFD5DAE6)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final Paint minorTickPaint = Paint()
      ..color = const Color(0xFF676E82)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // 18 sub-intervals (-3..+3 in 1/3 EV stops => 19 ticks: i = -9..+9)
    for (int i = -9; i <= 9; i++) {
      final double norm = (i + 9) / 18.0;
      final double x = padX + norm * usableW;
      final bool isWholeStop = i % 3 == 0;
      final bool isZero = i == 0;

      final double topY = isZero ? 2.5 : (isWholeStop ? 4.5 : 7.5);
      canvas.drawLine(
        Offset(x, topY),
        Offset(x, tickBaseY),
        isWholeStop ? majorTickPaint : minorTickPaint,
      );

      if (isWholeStop) {
        final int stopVal = i ~/ 3;
        final String label = stopVal > 0 ? '+$stopVal' : '$stopVal';
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: isZero ? kIosYellow : const Color(0xFF9EA5B8),
              fontSize: 8.5,
              fontWeight: isZero ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width * 0.5, tickBaseY + 2.0));
      }
    }

    // Live metered EV delta bar from center 0 EV
    final double meteredX =
        padX + ((meteredEvDelta + 3.0) / 6.0).clamp(0.0, 1.0) * usableW;
    final Color meterColor = meteredEvDelta.abs() > 1.8
        ? const Color(0xFFFF453A)
        : (aeAfLocked ? kIosYellow : kZameraCyan);

    final Paint barPaint = Paint()
      ..color = meterColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX, tickBaseY),
      Offset(meteredX, tickBaseY),
      barPaint,
    );

    // Metered needle diamond
    final Path needle = Path()
      ..moveTo(meteredX, 1.5)
      ..lineTo(meteredX - 3.2, 5.5)
      ..lineTo(meteredX + 3.2, 5.5)
      ..close();
    canvas.drawPath(needle, Paint()..color = meterColor);

    // Target EV compensation marker in P/Tv/Sv modes
    if (!isManualMode) {
      final double targetX =
          padX + ((evCompensation + 3.0) / 6.0).clamp(0.0, 1.0) * usableW;
      final Path compPointer = Path()
        ..moveTo(targetX, tickBaseY + 1.0)
        ..lineTo(targetX - 3.6, tickBaseY - 3.5)
        ..lineTo(targetX + 3.6, tickBaseY - 3.5)
        ..close();
      canvas.drawPath(compPointer, Paint()..color = kIosYellow);
    }
  }

  @override
  bool shouldRepaint(covariant _DslrEvScalePainter oldDelegate) {
    return oldDelegate.meteredEvDelta != meteredEvDelta ||
        oldDelegate.evCompensation != evCompensation ||
        oldDelegate.isManualMode != isManualMode ||
        oldDelegate.aeAfLocked != aeAfLocked;
  }
}
