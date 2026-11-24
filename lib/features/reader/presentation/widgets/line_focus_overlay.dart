import 'package:flutter/material.dart';

class LineFocusOverlay extends StatefulWidget {
  final bool isEnabled;
  final Widget child;
  final double? autoPaceProgress;

  const LineFocusOverlay({
    super.key,
    required this.isEnabled,
    required this.child,
    this.autoPaceProgress,
  });

  @override
  State<LineFocusOverlay> createState() => _LineFocusOverlayState();
}

class _LineFocusOverlayState extends State<LineFocusOverlay> {
  double _focusY = 280.0;
  final double _focusHeight = 110.0;

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final isAutoPacing = widget.autoPaceProgress != null;
        const minManualY = 80.0;
        final maxManualY =
            (totalHeight - _focusHeight - 80.0).clamp(minManualY, totalHeight);
        const minAutoY = 24.0;
        final maxAutoY =
            (totalHeight - _focusHeight - 24.0).clamp(minAutoY, totalHeight);

        final effectiveFocusY = isAutoPacing
            ? minAutoY +
                ((maxAutoY - minAutoY) *
                    widget.autoPaceProgress!.clamp(0.0, 1.0))
            : _focusY.clamp(minManualY, maxManualY);
        final bandDuration =
            isAutoPacing ? const Duration(milliseconds: 140) : Duration.zero;
        final maskColor = Colors.black.withValues(alpha: 0.55);

        return Stack(
          children: [
            widget.child,
            AnimatedPositioned(
              duration: bandDuration,
              curve: Curves.linear,
              top: 0,
              left: 0,
              right: 0,
              height: effectiveFocusY.clamp(0.0, totalHeight),
              child: IgnorePointer(
                child: Container(color: maskColor),
              ),
            ),
            AnimatedPositioned(
              duration: bandDuration,
              curve: Curves.linear,
              top: (effectiveFocusY + _focusHeight).clamp(0.0, totalHeight),
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(color: maskColor),
              ),
            ),
            AnimatedPositioned(
              duration: bandDuration,
              curve: Curves.linear,
              top: effectiveFocusY,
              left: 0,
              right: 0,
              height: _focusHeight,
              child: IgnorePointer(
                ignoring: isAutoPacing,
                child: GestureDetector(
                  onVerticalDragUpdate: isAutoPacing
                      ? null
                      : (details) {
                          setState(() {
                            _focusY = (_focusY + details.delta.dy)
                                .clamp(minManualY, maxManualY);
                          });
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.8),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
