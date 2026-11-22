import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'foldable_layout_info.dart';

/// Propagates the window-coordinate origin offset of the current viewport
/// (for example, shifted right when a side NavigationRail is visible) so that
/// nested [FoldableTwoPane] widgets align accurately with physical hinge bounds.
class FoldableViewportScope extends InheritedWidget {
  final Offset windowOriginOffset;

  const FoldableViewportScope({
    super.key,
    required this.windowOriginOffset,
    required super.child,
  });

  static Offset offsetOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<FoldableViewportScope>()
            ?.windowOriginOffset ??
        Offset.zero;
  }

  @override
  bool updateShouldNotify(covariant FoldableViewportScope oldWidget) {
    return windowOriginOffset != oldWidget.windowOriginOffset;
  }
}

/// Split direction preference for [FoldableTwoPane].
enum FoldableSplitAxis {
  /// Vertical split in [FoldablePosture.tabletop], horizontal split otherwise.
  auto,
  horizontal,
  vertical,
}

/// Resolved pane widths/heights and hinge gap computed by [FoldableTwoPane].
@immutable
class FoldablePaneMetrics {
  final Axis splitAxis;
  final double firstExtent;
  final double hingeGap;
  final double secondExtent;
  final bool isHingeAligned;

  const FoldablePaneMetrics({
    required this.splitAxis,
    required this.firstExtent,
    required this.hingeGap,
    required this.secondExtent,
    required this.isHingeAligned,
  });

  /// Calculates pane extents aligned to a physical hinge when viable, or falls
  /// back cleanly to [paneProportion] without overflowing [availableSize].
  factory FoldablePaneMetrics.resolve({
    required Size availableSize,
    required Offset windowOriginOffset,
    required FoldableLayoutInfo layoutInfo,
    FoldableSplitAxis axis = FoldableSplitAxis.auto,
    double paneProportion = 0.5,
    double paneSpacing = 16.0,
    double minHorizontalPaneWidth = 220.0,
    double minVerticalPaneHeight = 140.0,
  }) {
    final Axis resolvedAxis;
    switch (axis) {
      case FoldableSplitAxis.auto:
        resolvedAxis =
            layoutInfo.isTabletopPosture ? Axis.vertical : Axis.horizontal;
      case FoldableSplitAxis.horizontal:
        resolvedAxis = Axis.horizontal;
      case FoldableSplitAxis.vertical:
        resolvedAxis = Axis.vertical;
    }

    final totalExtent = resolvedAxis == Axis.horizontal
        ? math.max(0.0, availableSize.width)
        : math.max(0.0, availableSize.height);
    final safeSpacing = math.max(0.0, paneSpacing).clamp(0.0, totalExtent);
    final hinge = layoutInfo.hingeBounds;

    if (resolvedAxis == Axis.horizontal &&
        hinge != null &&
        hinge.height >= hinge.width) {
      final localLeft = hinge.left - windowOriginOffset.dx;
      final localRight = hinge.right - windowOriginOffset.dx;
      final rawHingeWidth = math.max(0.0, localRight - localLeft);
      final gap = math.max(rawHingeWidth, safeSpacing).clamp(0.0, totalExtent);
      final hingeCenter = (localLeft + localRight) * 0.5;
      final first =
          rawHingeWidth >= safeSpacing ? localLeft : hingeCenter - (gap * 0.5);
      final second = totalExtent - first - gap;

      if (first >= minHorizontalPaneWidth && second >= minHorizontalPaneWidth) {
        return FoldablePaneMetrics(
          splitAxis: Axis.horizontal,
          firstExtent: first,
          hingeGap: gap,
          secondExtent: second,
          isHingeAligned: true,
        );
      }
    } else if (resolvedAxis == Axis.vertical &&
        hinge != null &&
        hinge.width > hinge.height) {
      final localTop = hinge.top - windowOriginOffset.dy;
      final localBottom = hinge.bottom - windowOriginOffset.dy;
      final rawHingeHeight = math.max(0.0, localBottom - localTop);
      final gap = math.max(rawHingeHeight, safeSpacing).clamp(0.0, totalExtent);
      final hingeCenter = (localTop + localBottom) * 0.5;
      final first =
          rawHingeHeight >= safeSpacing ? localTop : hingeCenter - (gap * 0.5);
      final second = totalExtent - first - gap;

      if (first >= minVerticalPaneHeight && second >= minVerticalPaneHeight) {
        return FoldablePaneMetrics(
          splitAxis: Axis.vertical,
          firstExtent: first,
          hingeGap: gap,
          secondExtent: second,
          isHingeAligned: true,
        );
      }
    }

    final usableExtent = math.max(0.0, totalExtent - safeSpacing);
    final clampedProportion = paneProportion.clamp(0.15, 0.85);
    final first = usableExtent * clampedProportion;
    final second = math.max(0.0, usableExtent - first);

    return FoldablePaneMetrics(
      splitAxis: resolvedAxis,
      firstExtent: first,
      hingeGap: safeSpacing,
      secondExtent: second,
      isHingeAligned: false,
    );
  }
}

/// Adaptive two-pane layout that respects foldable physical hinges, tabletop
/// half-opened postures, and unfolded wide screens on both Android and iOS.
class FoldableTwoPane extends StatelessWidget {
  final Widget startPane;
  final Widget endPane;
  final FoldableSplitAxis axis;
  final double paneProportion;
  final double paneSpacing;
  final double minHorizontalPaneWidth;
  final double minVerticalPaneHeight;

  /// When `true` in horizontal split, places [startPane] on the physical right
  /// and [endPane] on the physical left (ideal for RTL Mushaf two-page spreads).
  final bool reverseHorizontal;
  final Widget? hingeSeparator;
  final EdgeInsetsGeometry padding;

  const FoldableTwoPane({
    super.key,
    required this.startPane,
    required this.endPane,
    this.axis = FoldableSplitAxis.auto,
    this.paneProportion = 0.5,
    this.paneSpacing = 16.0,
    this.minHorizontalPaneWidth = 220.0,
    this.minVerticalPaneHeight = 140.0,
    this.reverseHorizontal = false,
    this.hingeSeparator,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final layoutInfo = FoldableLayoutInfo.of(context);
    final scopeOffset = FoldableViewportScope.offsetOf(context);
    final resolvedPadding = padding.resolve(Directionality.of(context));

    return Padding(
      padding: resolvedPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : math.max(0.0, layoutInfo.windowSize.width - resolvedPadding.horizontal);
          final maxH = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : math.max(0.0, layoutInfo.windowSize.height - resolvedPadding.vertical);

          final metrics = FoldablePaneMetrics.resolve(
            availableSize: Size(maxW, maxH),
            windowOriginOffset: scopeOffset.translate(
              resolvedPadding.left,
              resolvedPadding.top,
            ),
            layoutInfo: layoutInfo,
            axis: axis,
            paneProportion: paneProportion,
            paneSpacing: paneSpacing,
            minHorizontalPaneWidth: minHorizontalPaneWidth,
            minVerticalPaneHeight: minVerticalPaneHeight,
          );

          if (metrics.splitAxis == Axis.vertical) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: metrics.firstExtent,
                  child: startPane,
                ),
                SizedBox(
                  height: metrics.hingeGap,
                  child: hingeSeparator,
                ),
                SizedBox(
                  height: metrics.secondExtent,
                  child: endPane,
                ),
              ],
            );
          }

          final leftPane = reverseHorizontal ? endPane : startPane;
          final rightPane = reverseHorizontal ? startPane : endPane;

          return Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: metrics.firstExtent,
                child: leftPane,
              ),
              SizedBox(
                width: metrics.hingeGap,
                child: hingeSeparator,
              ),
              SizedBox(
                width: metrics.secondExtent,
                child: rightPane,
              ),
            ],
          );
        },
      ),
    );
  }
}
