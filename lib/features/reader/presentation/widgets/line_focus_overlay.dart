import 'package:flutter/material.dart';

class LineFocusOverlay extends StatefulWidget {
  final bool isEnabled;
  final Widget child;

  const LineFocusOverlay({
    super.key,
    required this.isEnabled,
    required this.child,
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

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _focusY.clamp(0, MediaQuery.of(context).size.height),
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),
        ),
        Positioned(
          top: _focusY + _focusHeight,
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),
        ),
        Positioned(
          top: _focusY,
          left: 0,
          right: 0,
          height: _focusHeight,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _focusY = (_focusY + details.delta.dy)
                    .clamp(80.0, MediaQuery.of(context).size.height - _focusHeight - 80);
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
