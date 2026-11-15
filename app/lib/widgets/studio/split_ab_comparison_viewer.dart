import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/camera_colors.dart';
import '../../models/inspector_colorimetry.dart';
import '../../painters/checkerboard_and_lift_painter.dart';

/// Interactive full-screen photo/sticker inspection stage supporting:
/// - Pinch-to-zoom (`InteractiveViewer`, `1.0x..6.0x`) + double-tap 1:1/fit zoom
/// - Draggable Split-Slider A/B Curtain (`primaryImagePath` vs `secondaryImagePath`)
/// - Interactive 1:1 Pixel Colorimeter Loupe (`ΔE00` + `#HEX` preview while dragging)
/// - Portrait focal point reticle & tap-to-refocus
/// - Long-press Subject Lift with luminous glow animation
class SplitAbComparisonViewer extends StatefulWidget {
  final String primaryImagePath;
  final String? secondaryImagePath;
  final String primaryLabel;
  final String secondaryLabel;
  final bool isSticker;
  final bool abSplitEnabled;
  final bool colorimeterEnabled;
  final bool portraitRefocusEnabled;
  final bool isPortraitMode;
  final double portraitAperture;
  final int? imageWidth;
  final int? imageHeight;
  final Offset focusNorm;
  final InspectedPixelMeasurement? pixelMeasurement;
  final ValueChanged<bool>? onInteractionLockChanged;
  final ValueChanged<Offset>? onTapImage;
  final ValueChanged<Offset>? onColorimeterDrag;
  final ValueChanged<Offset>? onSubjectLift;

  const SplitAbComparisonViewer({
    super.key,
    required this.primaryImagePath,
    this.secondaryImagePath,
    this.primaryLabel = 'TRUECOLOR 1:1',
    this.secondaryLabel = 'STOK (OEM)',
    this.isSticker = false,
    this.abSplitEnabled = false,
    this.colorimeterEnabled = false,
    this.portraitRefocusEnabled = false,
    this.isPortraitMode = false,
    this.portraitAperture = 2.8,
    this.imageWidth,
    this.imageHeight,
    this.focusNorm = const Offset(0.5, 0.5),
    this.pixelMeasurement,
    this.onInteractionLockChanged,
    this.onTapImage,
    this.onColorimeterDrag,
    this.onSubjectLift,
  });

  @override
  State<SplitAbComparisonViewer> createState() =>
      _SplitAbComparisonViewerState();
}

class _SplitAbComparisonViewerState extends State<SplitAbComparisonViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _liftController;

  double _splitFraction = 0.50;
  bool _isZoomed = false;
  bool _isDraggingSplit = false;
  bool _isDraggingLoupe = false;
  Offset? _liftOriginNorm;
  Offset? _doubleTapLocalPos;

  @override
  void initState() {
    super.initState();
    _liftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void didUpdateWidget(covariant SplitAbComparisonViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryImagePath != widget.primaryImagePath) {
      _resetZoom();
      _liftOriginNorm = null;
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _liftController.dispose();
    super.dispose();
  }

  void _notifyLock() {
    widget.onInteractionLockChanged?.call(
      _isZoomed || _isDraggingSplit || _isDraggingLoupe,
    );
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    if (_isZoomed) {
      setState(() => _isZoomed = false);
      _notifyLock();
    }
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _resetZoom();
      return;
    }
    final tap = _doubleTapLocalPos;
    const targetScale = 2.6;
    final matrix = Matrix4.identity();
    if (tap != null) {
      matrix.translateByDouble(
        -tap.dx * (targetScale - 1.0),
        -tap.dy * (targetScale - 1.0),
        0.0,
        1.0,
      );
    }
    matrix.scaleByDouble(targetScale, targetScale, 1.0, 1.0);
    _transformController.value = matrix;
    setState(() => _isZoomed = true);
    _notifyLock();
  }

  void _triggerLiftGlow(Offset norm) {
    setState(() => _liftOriginNorm = norm);
    _liftController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final hasSecondary =
        widget.abSplitEnabled &&
        widget.secondaryImagePath != null &&
        widget.secondaryImagePath!.isNotEmpty &&
        !widget.isSticker;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final imageRect = computeContainedImageRect(
          containerSize: size,
          imageWidth: widget.imageWidth,
          imageHeight: widget.imageHeight,
        );

        final reticleSize = widget.isPortraitMode ? 68.0 : 46.0;
        final focusPt = mapNormalizedImagePointToCanvasOffset(
          focusNorm: widget.focusNorm,
          imageRect: imageRect,
        );
        final minLeft = imageRect.left;
        final maxLeft = math.max(minLeft, imageRect.right - reticleSize);
        final minTop = imageRect.top;
        final maxTop = math.max(minTop, imageRect.bottom - reticleSize);
        final reticleLeft = (focusPt.dx - reticleSize * 0.5).clamp(
          minLeft,
          maxLeft,
        );
        final reticleTop = (focusPt.dy - reticleSize * 0.5).clamp(
          minTop,
          maxTop,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.isSticker)
              const CustomPaint(
                painter: TransparencyCheckerboardPainter(tileSize: 16),
              ),
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 6.0,
              panEnabled: _isZoomed && !_isDraggingSplit && !_isDraggingLoupe,
              scaleEnabled: !_isDraggingSplit && !_isDraggingLoupe,
              onInteractionEnd: (_) {
                final scale = _transformController.value.getMaxScaleOnAxis();
                final zoomedNow = scale > 1.02;
                if (zoomedNow != _isZoomed) {
                  setState(() => _isZoomed = zoomedNow);
                  _notifyLock();
                }
              },
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasSecondary)
                      _SafeImageFileView(
                        path: widget.secondaryImagePath!,
                        fit: BoxFit.contain,
                      ),
                    if (hasSecondary)
                      ClipRect(
                        clipper: _LeftSplitClipper(_splitFraction),
                        child: _SafeImageFileView(
                          path: widget.primaryImagePath,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      _SafeImageFileView(
                        path: widget.primaryImagePath,
                        fit: BoxFit.contain,
                      ),
                  ],
                ),
              ),
            ),

            // Gesture Surface (Tap, Double-Tap, Colorimeter Drag, Subject Lift Long-Press)
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('studio_photo_canvas'),
                behavior: HitTestBehavior.translucent,
                onDoubleTapDown: (d) => _doubleTapLocalPos = d.localPosition,
                onDoubleTap: _handleDoubleTap,
                onTapUp: (details) {
                  final mapped = mapLocalTapToNormalizedImagePoint(
                    localPosition: details.localPosition,
                    imageRect: imageRect,
                  );
                  widget.onTapImage?.call(mapped);
                },
                onPanStart: widget.colorimeterEnabled
                    ? (details) {
                        setState(() => _isDraggingLoupe = true);
                        _notifyLock();
                        final mapped = mapLocalTapToNormalizedImagePoint(
                          localPosition: details.localPosition,
                          imageRect: imageRect,
                        );
                        widget.onColorimeterDrag?.call(mapped);
                      }
                    : null,
                onPanUpdate: widget.colorimeterEnabled
                    ? (details) {
                        final mapped = mapLocalTapToNormalizedImagePoint(
                          localPosition: details.localPosition,
                          imageRect: imageRect,
                        );
                        widget.onColorimeterDrag?.call(mapped);
                      }
                    : null,
                onPanEnd: widget.colorimeterEnabled
                    ? (_) {
                        setState(() => _isDraggingLoupe = false);
                        _notifyLock();
                      }
                    : null,
                onPanCancel: widget.colorimeterEnabled
                    ? () {
                        setState(() => _isDraggingLoupe = false);
                        _notifyLock();
                      }
                    : null,
                onLongPressStart: widget.isSticker
                    ? null
                    : (details) {
                        HapticFeedback.heavyImpact();
                        final mapped = mapLocalTapToNormalizedImagePoint(
                          localPosition: details.localPosition,
                          imageRect: imageRect,
                        );
                        _triggerLiftGlow(mapped);
                        widget.onSubjectLift?.call(mapped);
                      },
              ),
            ),

            // Focus / Colorimeter Reticle
            if (!widget.isSticker &&
                (widget.isPortraitMode || widget.colorimeterEnabled))
              Positioned(
                left: reticleLeft,
                top: reticleTop,
                child: IgnorePointer(
                  child: widget.isPortraitMode
                      ? Container(
                          width: reticleSize,
                          height: reticleSize,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: widget.portraitRefocusEnabled
                                  ? kIosYellow
                                  : Colors.white54,
                              width: 1.6,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.topCenter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            color: Colors.black87,
                            child: Text(
                              widget.portraitRefocusEnabled
                                  ? 'ODAK ƒ ${widget.portraitAperture.toStringAsFixed(1)}'
                                  : 'ODAK KAPALI',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: kIosYellow,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: reticleSize,
                          height: reticleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kZameraCyan, width: 1.6),
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.pixelMeasurement != null
                                    ? Color.fromARGB(
                                        255,
                                        widget.pixelMeasurement!.r,
                                        widget.pixelMeasurement!.g,
                                        widget.pixelMeasurement!.b,
                                      )
                                    : kIosYellow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),

            // Magnified Colorimeter Loupe Overlay
            if (widget.colorimeterEnabled &&
                widget.pixelMeasurement != null &&
                (_isDraggingLoupe || widget.pixelMeasurement!.isDecodedPixel))
              _ColorimeterLoupeOverlay(
                canvasSize: size,
                focusCanvasPoint: focusPt,
                measurement: widget.pixelMeasurement!,
                visible: _isDraggingLoupe,
              ),

            // Luminous Subject Lift Ripple
            if (_liftOriginNorm != null)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _liftController,
                  builder: (context, _) {
                    if (_liftController.isDismissed) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      painter: SubjectLiftGlowPainter(
                        imageRect: imageRect,
                        focusNorm: _liftOriginNorm!,
                        progress: _liftController.value,
                      ),
                    );
                  },
                ),
              ),

            // Draggable A/B Split-Slider Curtain Handle & Badges
            if (hasSecondary)
              _SplitCurtainOverlay(
                splitFraction: _splitFraction,
                primaryLabel: widget.primaryLabel,
                secondaryLabel: widget.secondaryLabel,
                containerSize: size,
                onDragStart: () {
                  setState(() => _isDraggingSplit = true);
                  _notifyLock();
                },
                onDragFraction: (next) {
                  setState(() => _splitFraction = next.clamp(0.05, 0.95));
                },
                onDragEnd: () {
                  setState(() => _isDraggingSplit = false);
                  _notifyLock();
                },
              ),
          ],
        );
      },
    );
  }
}

class _SafeImageFileView extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const _SafeImageFileView({required this.path, required this.fit});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white30,
          size: 46,
        ),
      );
    }
    return Image.file(
      file,
      key: ValueKey('img_$path'),
      fit: fit,
      gaplessPlayback: true,
    );
  }
}

class _LeftSplitClipper extends CustomClipper<Rect> {
  final double fraction;

  const _LeftSplitClipper(this.fraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(covariant _LeftSplitClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class _SplitCurtainOverlay extends StatelessWidget {
  final double splitFraction;
  final String primaryLabel;
  final String secondaryLabel;
  final Size containerSize;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragFraction;
  final VoidCallback onDragEnd;

  const _SplitCurtainOverlay({
    required this.splitFraction,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.containerSize,
    required this.onDragStart,
    required this.onDragFraction,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final x = (containerSize.width * splitFraction).clamp(
      18.0,
      math.max(18.0, containerSize.width - 18.0),
    );
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 12,
          child: IgnorePointer(
            child: _CurtainTag(label: primaryLabel, color: kZameraCyan),
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: IgnorePointer(
            child: _CurtainTag(label: secondaryLabel, color: kIosYellow),
          ),
        ),
        Positioned(
          left: x - 18,
          top: 0,
          bottom: 0,
          width: 36,
          child: GestureDetector(
            key: const ValueKey('studio_ab_split_handle'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => onDragStart(),
            onHorizontalDragUpdate: (details) {
              if (containerSize.width <= 0) return;
              final next =
                  (x + details.delta.dx) / containerSize.width;
              onDragFraction(next);
            },
            onHorizontalDragEnd: (_) => onDragEnd(),
            onHorizontalDragCancel: onDragEnd,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 2,
                  color: Colors.white.withValues(alpha: 0.90),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                  child: const Icon(
                    Icons.compare_arrows_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CurtainTag extends StatelessWidget {
  final String label;
  final Color color;

  const _CurtainTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ColorimeterLoupeOverlay extends StatelessWidget {
  final Size canvasSize;
  final Offset focusCanvasPoint;
  final InspectedPixelMeasurement measurement;
  final bool visible;

  const _ColorimeterLoupeOverlay({
    required this.canvasSize,
    required this.focusCanvasPoint,
    required this.measurement,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    const loupeW = 148.0;
    const loupeH = 58.0;
    final double left = (focusCanvasPoint.dx - loupeW * 0.5)
        .clamp(
          10.0,
          math.max(10.0, canvasSize.width - loupeW - 10.0),
        )
        .toDouble();
    final aboveTop = focusCanvasPoint.dy - loupeH - 42.0;
    final double top = aboveTop >= 12.0
        ? aboveTop
        : (focusCanvasPoint.dy + 34.0)
            .clamp(
              12.0,
              math.max(12.0, canvasSize.height - loupeH - 12.0),
            )
            .toDouble();

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          key: const ValueKey('studio_colorimeter_loupe'),
          width: loupeW,
          height: loupeH,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0E121B).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kZameraCyan, width: 1.4),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 12),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color.fromARGB(
                    255,
                    measurement.r,
                    measurement.g,
                    measurement.b,
                  ),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      measurement.hexString,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'ΔE00 ${measurement.deltaE00.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w800,
                        color: kIosYellow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
