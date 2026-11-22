import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

/// Material / Adaptive window width breakpoints (dp).
enum WindowWidthClass {
  /// `< 600dp`: folded cover screen, standard phone, or split-screen slice.
  compact,

  /// `600dp .. 839.99dp`: unfolded book-style foldable (portrait) or small tablet.
  medium,

  /// `>= 840dp`: unfolded foldable (landscape), large tablet, or desktop.
  expanded,
}

/// Physical posture resolved from platform window metrics and hinge/fold display features.
enum FoldablePosture {
  /// Normal flat screen (phone, unfolded flat, iOS foldable, tablet, or desktop).
  flat,

  /// Vertical fold/hinge bisecting the viewport side-by-side (book / dual-pane posture).
  book,

  /// Horizontal half-opened fold/hinge bisecting the viewport top/bottom (tabletop / flex posture).
  tabletop,
}

/// Immutable responsive and foldable posture snapshot for the active window.
@immutable
class FoldableLayoutInfo {
  final Size windowSize;
  final WindowWidthClass widthClass;
  final FoldablePosture posture;
  final Rect? hingeBounds;
  final bool hasPhysicalFoldFeature;
  final bool isNarrowCoverScreen;

  const FoldableLayoutInfo({
    required this.windowSize,
    required this.widthClass,
    required this.posture,
    this.hingeBounds,
    this.hasPhysicalFoldFeature = false,
    this.isNarrowCoverScreen = false,
  });

  /// Computes foldable posture and width classes from raw window metrics.
  factory FoldableLayoutInfo.fromMetrics({
    required Size windowSize,
    required List<ui.DisplayFeature> displayFeatures,
  }) {
    bool hasFoldFeature = false;
    FoldablePosture posture = FoldablePosture.flat;
    Rect? activeHingeBounds;
    Rect? fallbackFlatVerticalFold;

    for (final feature in displayFeatures) {
      final isFoldOrHinge = feature.type == ui.DisplayFeatureType.hinge ||
          feature.type == ui.DisplayFeatureType.fold;
      if (!isFoldOrHinge) continue;

      hasFoldFeature = true;
      final bounds = feature.bounds;
      final isVertical = bounds.height >= bounds.width;
      final isHorizontal = bounds.width > bounds.height;
      final isHalfOpened =
          feature.state == ui.DisplayFeatureState.postureHalfOpened;

      if (isVertical &&
          (feature.type == ui.DisplayFeatureType.hinge || isHalfOpened) &&
          bounds.left >= 180.0 &&
          (windowSize.width - bounds.right) >= 180.0) {
        posture = FoldablePosture.book;
        activeHingeBounds = bounds;
        break;
      }

      if (isHorizontal &&
          isHalfOpened &&
          bounds.top >= 120.0 &&
          (windowSize.height - bounds.bottom) >= 120.0) {
        posture = FoldablePosture.tabletop;
        activeHingeBounds = bounds;
        break;
      }

      if (isVertical &&
          feature.type == ui.DisplayFeatureType.fold &&
          bounds.left >= 200.0 &&
          (windowSize.width - bounds.right) >= 200.0) {
        fallbackFlatVerticalFold ??= bounds;
      }
    }

    final width = windowSize.width;
    final WindowWidthClass widthClass;
    if (width < 600.0) {
      widthClass = WindowWidthClass.compact;
    } else if (width < 840.0) {
      widthClass = WindowWidthClass.medium;
    } else {
      widthClass = WindowWidthClass.expanded;
    }

    return FoldableLayoutInfo(
      windowSize: windowSize,
      widthClass: widthClass,
      posture: posture,
      hingeBounds: activeHingeBounds ?? fallbackFlatVerticalFold,
      hasPhysicalFoldFeature: hasFoldFeature,
      isNarrowCoverScreen: width < 360.0,
    );
  }

  /// Reads the current window size and display features via granular [MediaQuery] selectors.
  factory FoldableLayoutInfo.of(BuildContext context) {
    return FoldableLayoutInfo.fromMetrics(
      windowSize: MediaQuery.sizeOf(context),
      displayFeatures: MediaQuery.displayFeaturesOf(context),
    );
  }

  bool get isCompact => widthClass == WindowWidthClass.compact;
  bool get isMediumOrLarger => widthClass != WindowWidthClass.compact;
  bool get isExpanded => widthClass == WindowWidthClass.expanded;
  bool get isBookPosture => posture == FoldablePosture.book;
  bool get isTabletopPosture => posture == FoldablePosture.tabletop;

  /// Uses a side rail on medium/expanded unfolded screens, avoiding it in tabletop posture.
  bool get useNavigationRail =>
      widthClass != WindowWidthClass.compact && !isTabletopPosture;

  bool get useExtendedNavigationRail => windowSize.width >= 1024.0;

  bool get supportsTwoPaneHorizontal =>
      isBookPosture || (windowSize.width >= 600.0 && !isTabletopPosture);

  bool get supportsTwoPageSpread =>
      isBookPosture ||
      (windowSize.width >= 640.0 &&
          windowSize.height >= 420.0 &&
          !isTabletopPosture);

  double verticalHingeWidth({double fallback = 20.0}) {
    final bounds = hingeBounds;
    if (bounds != null && bounds.height >= bounds.width && bounds.width > 0.0) {
      return bounds.width;
    }
    return fallback;
  }

  double horizontalHingeHeight({double fallback = 16.0}) {
    final bounds = hingeBounds;
    if (bounds != null && bounds.width > bounds.height && bounds.height > 0.0) {
      return bounds.height;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoldableLayoutInfo &&
        other.windowSize == windowSize &&
        other.widthClass == widthClass &&
        other.posture == posture &&
        other.hingeBounds == hingeBounds &&
        other.hasPhysicalFoldFeature == hasPhysicalFoldFeature &&
        other.isNarrowCoverScreen == isNarrowCoverScreen;
  }

  @override
  int get hashCode => Object.hash(
        windowSize,
        widthClass,
        posture,
        hingeBounds,
        hasPhysicalFoldFeature,
        isNarrowCoverScreen,
      );
}
