import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/camera_colors.dart';
import '../painters/radial_guide_arc_painter.dart';

/// Descriptor for an individual mode feature pill/circle positioned along
/// [RadialShutterFeatureArc] above the shutter button.
@immutable
class RadialArcFeatureNode {
  final String id;
  final String primaryLabel;
  final String? secondaryLabel;
  final bool isActive;
  final Color accentColor;
  final Key? key;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const RadialArcFeatureNode({
    required this.id,
    required this.primaryLabel,
    this.secondaryLabel,
    this.isActive = false,
    this.accentColor = kIosYellow,
    this.key,
    this.icon,
    this.onTap,
    this.onLongPress,
  });
}

/// Semi-circular curved feature arc positioned concentrically above the shutter.
///
/// Renders [nodes] along a [RadialButtonsGuideArcPainter] guide arc and supports
/// independent horizontal drag scrolling along the arc trajectory without leaking
/// gestures to underlying dial wheels.
class RadialShutterFeatureArc extends StatefulWidget {
  final List<RadialArcFeatureNode> nodes;
  final double height;
  final double? arcRadius;
  final double maxHalfSweepRad;

  const RadialShutterFeatureArc({
    super.key,
    required this.nodes,
    this.height = 88.0,
    this.arcRadius,
    this.maxHalfSweepRad = 0.66,
  });

  @override
  State<RadialShutterFeatureArc> createState() =>
      _RadialShutterFeatureArcState();
}

class _RadialShutterFeatureArcState extends State<RadialShutterFeatureArc> {
  double _scrollAngleOffset = 0.0;

  @override
  void didUpdateWidget(covariant RadialShutterFeatureArc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes.length != widget.nodes.length) {
      _scrollAngleOffset = _scrollAngleOffset.clamp(-0.34, 0.34);
    }
  }

  static double _nodeWeight(RadialArcFeatureNode node) {
    final int primaryLen = node.primaryLabel.length;
    final int secondaryLen = node.secondaryLabel?.length ?? 0;
    final int maxLen = math.max(primaryLen, secondaryLen);
    return (maxLen + (node.icon != null ? 2.4 : 0.8)).clamp(4.4, 18.5);
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details, double radius) {
    if (widget.nodes.isEmpty || radius <= 0) return;
    const double bound = 0.34;
    final double deltaAngle = details.delta.dx / radius;
    final double next = (_scrollAngleOffset + deltaAngle).clamp(-bound, bound);
    if ((next - _scrollAngleOffset).abs() > 0.0005) {
      setState(() {
        _scrollAngleOffset = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double totalWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final bool compact = totalWidth < 440.0;
          final int count = widget.nodes.length;
          final double fanWidth = totalWidth.clamp(320.0, 560.0);
          final double defaultRadius = count <= 3
              ? 240.0
              : (compact ? 420.0 : 580.0);
          final double radius = widget.arcRadius ?? defaultRadius;
          final double centerX = totalWidth * 0.5;
          const double apexY = 19.0;
          final double arcCenterY = apexY + radius;
          const double topApexAngle = -math.pi * 0.5;

          final List<double> weights =
              widget.nodes.map(_nodeWeight).toList(growable: false);
          double totalWeights = 0.0;
          for (final double w in weights) {
            totalWeights += w;
          }

          final double maxHalfChord = math.min(
            radius * 0.72,
            math.max(60.0, fanWidth * 0.5 - (compact ? 26.0 : 38.0)),
          );
          final double targetHalfChord = count <= 1
              ? 0.0
              : (count == 2
                  ? math.min(maxHalfChord, 56.0)
                  : (count == 3
                      ? math.min(maxHalfChord, 88.0)
                      : math.min(
                          maxHalfChord,
                          totalWeights * (compact ? 2.55 : 3.35),
                        )));
          final double baseHalfSweep = targetHalfChord <= 0.0
              ? 0.0
              : math.asin((targetHalfChord / radius).clamp(0.0, 0.92));
          final double guideHalfSweep = math.max(0.26, baseHalfSweep + 0.055);

          double totalIntervals = 0.0;
          for (int i = 0; i < count - 1; i++) {
            totalIntervals += (weights[i] + weights[i + 1]) * 0.5;
          }

          final List<double> baseAngles = <double>[];
          if (count == 1 || totalIntervals <= 0.0) {
            baseAngles.add(topApexAngle);
          } else {
            double cursor = 0.0;
            for (int i = 0; i < count; i++) {
              final double norm = (cursor / totalIntervals) * 2.0 - 1.0;
              baseAngles.add(topApexAngle + norm * baseHalfSweep);
              if (i < count - 1) {
                cursor += (weights[i] + weights[i + 1]) * 0.5;
              }
            }
          }

          final List<Widget> positionedNodes = <Widget>[];
          for (int i = 0; i < count; i++) {
            final RadialArcFeatureNode node = widget.nodes[i];
            final double angle = baseAngles[i] + _scrollAngleOffset;
            final double angularDist = (angle - topApexAngle).abs();
            if (angularDist > widget.maxHalfSweepRad + 0.28) {
              continue;
            }

            final double nodeCenterX = centerX + radius * math.cos(angle);
            final double nodeCenterY = arcCenterY + radius * math.sin(angle);
            final double edgeFade = (1.0 -
                    ((angularDist - (baseHalfSweep + 0.16)) / 0.26)
                        .clamp(0.0, 1.0))
                .clamp(0.32, 1.0);

            const double slotWidth = 176.0;
            const double slotHeight = 42.0;

            positionedNodes.add(
              Positioned(
                left: nodeCenterX - slotWidth * 0.5,
                top: nodeCenterY - slotHeight * 0.5,
                width: slotWidth,
                height: slotHeight,
                child: Opacity(
                  opacity: edgeFade,
                  child: Center(
                    child: _RadialArcNodeButton(
                      key: node.key,
                      node: node,
                      compact: compact,
                    ),
                  ),
                ),
              ),
            );
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (DragUpdateDetails details) =>
                _handleHorizontalDragUpdate(details, radius),
            child: SizedBox(
              width: totalWidth,
              height: widget.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: RadialButtonsGuideArcPainter(
                          arcCenter: Offset(centerX, arcCenterY),
                          arcRadius: radius,
                          startAngle: topApexAngle - guideHalfSweep,
                          sweepAngle: guideHalfSweep * 2.0,
                        ),
                      ),
                    ),
                  ),
                  ...positionedNodes,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RadialArcNodeButton extends StatelessWidget {
  final RadialArcFeatureNode node;
  final bool compact;

  const _RadialArcNodeButton({
    super.key,
    required this.node,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasSecondary =
        node.secondaryLabel != null && node.secondaryLabel!.isNotEmpty;
    final Color activeColor = node.accentColor;
    final Color bgColor = node.isActive
        ? activeColor.withValues(alpha: 0.20)
        : kObsidianBg.withValues(alpha: 0.68);
    final Color borderColor = node.isActive
        ? activeColor
        : Colors.white.withValues(alpha: 0.22);
    final Color primaryFg = node.isActive ? activeColor : Colors.white;
    final Color secondaryFg = node.isActive
        ? activeColor.withValues(alpha: 0.88)
        : Colors.white60;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: node.onTap,
      onLongPress: node.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(
          minWidth: compact ? 32.0 : 36.0,
          minHeight: compact ? 30.0 : 33.0,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5.0 : (hasSecondary ? 8.0 : 7.5),
          vertical: hasSecondary ? 2.5 : 5.0,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: borderColor,
            width: node.isActive ? 1.25 : 0.9,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black54,
              blurRadius: 6.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (node.icon != null) ...<Widget>[
                  Icon(
                    node.icon,
                    size: compact ? 9.5 : 10.5,
                    color: primaryFg,
                  ),
                  SizedBox(width: compact ? 1.8 : 2.5),
                ],
                Text(
                  node.primaryLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: primaryFg,
                    fontSize: hasSecondary
                        ? (compact ? 9.5 : 10.5)
                        : (compact ? 8.0 : 9.2),
                    fontWeight:
                        node.isActive ? FontWeight.w800 : FontWeight.w700,
                    height: 1.05,
                    letterSpacing: compact ? -0.2 : -0.1,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
            if (hasSecondary) ...<Widget>[
              const SizedBox(height: 1.5),
              Text(
                node.secondaryLabel!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: secondaryFg,
                  fontSize: 8.0,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: 0.1,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
