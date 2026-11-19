import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Viewport-aware auto-scroll utilities for synchronized Quran word and verse tracking.
///
/// Computes coordinates relative to the enclosing [Scrollable]'s [RenderBox] rather
/// than global screen dimensions so nested viewports, floating player bars, and
/// top banners are respected accurately across Mushaf and List modes.
class QuranTrackingScrollHelper {
  QuranTrackingScrollHelper._();

  /// Scrolls the enclosing [Scrollable] only when [targetContext] (or its
  /// [targetSubRect]) lies outside the unobstructed viewport band defined by
  /// [topSafePadding] and [bottomSafePadding].
  static void ensureContextVisibleInViewport(
    BuildContext? targetContext, {
    Rect? targetSubRect,
    double topSafePadding = 14.0,
    double bottomSafePadding = 18.0,
    double preferredAlignment = 0.26,
    bool forceAlign = false,
    Duration duration = const Duration(milliseconds: 280),
  }) {
    if (targetContext == null || !targetContext.mounted) return;

    final scrollableState = Scrollable.maybeOf(targetContext);
    if (scrollableState == null || !scrollableState.mounted) return;

    final position = scrollableState.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;

    final viewportBox = scrollableState.context.findRenderObject() as RenderBox?;
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    if (viewportBox == null ||
        !viewportBox.hasSize ||
        targetBox == null ||
        !targetBox.hasSize) {
      return;
    }

    final localRect = targetSubRect ?? (Offset.zero & targetBox.size);
    final topLeft = targetBox.localToGlobal(
      localRect.topLeft,
      ancestor: viewportBox,
    );
    final bottomRight = targetBox.localToGlobal(
      localRect.bottomRight,
      ancestor: viewportBox,
    );
    final rectInViewport = Rect.fromPoints(topLeft, bottomRight);

    final viewportHeight = viewportBox.size.height;
    final safeTop = topSafePadding.clamp(0.0, viewportHeight);
    final safeBottom = math.max(
      safeTop + 48.0,
      viewportHeight - bottomSafePadding,
    );

    final isFullyInsideBand =
        rectInViewport.top >= safeTop && rectInViewport.bottom <= safeBottom;
    if (!forceAlign && isFullyInsideBand) {
      return;
    }

    final availableBand = math.max(0.0, safeBottom - safeTop - rectInViewport.height);
    final desiredTop = safeTop + (availableBand * preferredAlignment.clamp(0.0, 1.0));
    final delta = rectInViewport.top - desiredTop;

    final targetPixels = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((targetPixels - position.pixels).abs() <= 2.0) {
      return;
    }

    position.animateTo(
      targetPixels,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  /// Scrolls a [ListView.builder] to bring the verse card at [targetIndex] into
  /// view, stepping closer when the card is taller than `cacheExtent` or not yet
  /// materialized in the sliver tree.
  static void scrollToVerseCard({
    required ScrollController scrollController,
    required Map<int, GlobalKey> verseKeys,
    required int targetIndex,
    required int totalCount,
    GlobalKey? activeWordKey,
    bool preferActiveWord = false,
    double topSafePadding = 14.0,
    double bottomSafePadding = 18.0,
    int remainingAttempts = 12,
    bool schedulePostFrame = true,
  }) {
    void performScroll() {
      if (!scrollController.hasClients) return;
      final position = scrollController.position;
      if (!position.hasPixels || !position.hasContentDimensions) return;

      if (preferActiveWord &&
          activeWordKey?.currentContext != null &&
          activeWordKey!.currentContext!.mounted) {
        ensureContextVisibleInViewport(
          activeWordKey.currentContext,
          topSafePadding: topSafePadding,
          bottomSafePadding: bottomSafePadding,
          preferredAlignment: 0.22,
          forceAlign: true,
        );
        return;
      }

      final ctx = verseKeys[targetIndex]?.currentContext;
      if (ctx != null && ctx.mounted) {
        final cardBox = ctx.findRenderObject() as RenderBox?;
        final scrollableState = Scrollable.maybeOf(ctx);
        final viewportBox =
            scrollableState?.context.findRenderObject() as RenderBox?;

        if (cardBox != null &&
            cardBox.hasSize &&
            viewportBox != null &&
            viewportBox.hasSize) {
          final topSubRect = Rect.fromLTWH(
            0,
            0,
            cardBox.size.width,
            math.min(cardBox.size.height, 72.0),
          );
          final cardTopInViewport = cardBox
              .localToGlobal(Offset.zero, ancestor: viewportBox)
              .dy;
          final safeTop = topSafePadding.clamp(0.0, viewportBox.size.height);
          final safeBottom = math.max(
            safeTop + 48.0,
            viewportBox.size.height - bottomSafePadding,
          );
          final availableTopBand = math.max(0.0, safeBottom - safeTop - topSubRect.height);
          final projectedDelta =
              cardTopInViewport - (safeTop + availableTopBand * 0.04);

          ensureContextVisibleInViewport(
            ctx,
            targetSubRect: topSubRect,
            topSafePadding: topSafePadding,
            bottomSafePadding: bottomSafePadding,
            preferredAlignment: 0.04,
            forceAlign: true,
          );

          if (activeWordKey != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final wordCtx = activeWordKey.currentContext;
              if (wordCtx == null || !wordCtx.mounted) return;
              final wordBox = wordCtx.findRenderObject() as RenderBox?;
              final wordScrollable = Scrollable.maybeOf(wordCtx);
              final vpBox =
                  wordScrollable?.context.findRenderObject() as RenderBox?;
              if (wordBox == null ||
                  !wordBox.hasSize ||
                  vpBox == null ||
                  !vpBox.hasSize) {
                return;
              }
              final wordTop =
                  wordBox.localToGlobal(Offset.zero, ancestor: vpBox).dy -
                      projectedDelta;
              final wordBottom = wordTop + wordBox.size.height;
              if (wordTop < safeTop || wordBottom > safeBottom) {
                ensureContextVisibleInViewport(
                  wordCtx,
                  topSafePadding: topSafePadding,
                  bottomSafePadding: bottomSafePadding,
                  preferredAlignment: 0.22,
                );
              }
            });
          }
        } else {
          ensureContextVisibleInViewport(
            ctx,
            topSafePadding: topSafePadding,
            bottomSafePadding: bottomSafePadding,
            preferredAlignment: 0.04,
            forceAlign: true,
          );
        }
        return;
      }

      if (remainingAttempts <= 0 || totalCount <= 0) return;

      int? minBuiltIndex;
      int? maxBuiltIndex;
      for (final entry in verseKeys.entries) {
        if (entry.value.currentContext != null &&
            entry.value.currentContext!.mounted) {
          if (minBuiltIndex == null || entry.key < minBuiltIndex) {
            minBuiltIndex = entry.key;
          }
          if (maxBuiltIndex == null || entry.key > maxBuiltIndex) {
            maxBuiltIndex = entry.key;
          }
        }
      }

      final minExt = position.minScrollExtent;
      final maxExt = position.maxScrollExtent;
      if (maxExt <= minExt) return;

      double estimatedOffset;
      final stepChunk = math.max(300.0, position.viewportDimension * 0.85);
      if (maxBuiltIndex != null && targetIndex > maxBuiltIndex) {
        final maxCtx = verseKeys[maxBuiltIndex]?.currentContext;
        final vpBox = maxCtx != null && maxCtx.mounted
            ? Scrollable.maybeOf(maxCtx)?.context.findRenderObject()
                as RenderBox?
            : null;
        final maxBox = maxCtx?.findRenderObject() as RenderBox?;
        final extraHops = (targetIndex - maxBuiltIndex - 1).clamp(0, 5);
        double firstHop = stepChunk;
        if (vpBox != null &&
            vpBox.hasSize &&
            maxBox != null &&
            maxBox.hasSize) {
          final maxBottomInVp = maxBox
              .localToGlobal(Offset(0, maxBox.size.height), ancestor: vpBox)
              .dy;
          firstHop = math.max(stepChunk, maxBottomInVp - topSafePadding);
        }
        estimatedOffset = position.pixels + firstHop + stepChunk * extraHops;
      } else if (minBuiltIndex != null && targetIndex < minBuiltIndex) {
        final minCtx = verseKeys[minBuiltIndex]?.currentContext;
        final vpBox = minCtx != null && minCtx.mounted
            ? Scrollable.maybeOf(minCtx)?.context.findRenderObject()
                as RenderBox?
            : null;
        final minBox = minCtx?.findRenderObject() as RenderBox?;
        final extraHops = (minBuiltIndex - targetIndex - 1).clamp(0, 5);
        double firstHopUp = stepChunk;
        if (vpBox != null &&
            vpBox.hasSize &&
            minBox != null &&
            minBox.hasSize) {
          final minTopInVp =
              minBox.localToGlobal(Offset.zero, ancestor: vpBox).dy;
          firstHopUp = math.max(
            stepChunk,
            position.viewportDimension * 0.45 - minTopInVp,
          );
        }
        estimatedOffset = position.pixels - firstHopUp - stepChunk * extraHops;
      } else {
        final ratio =
            totalCount <= 1 ? 0.0 : targetIndex / math.max(1, totalCount - 1);
        estimatedOffset = minExt + ratio * (maxExt - minExt);
      }

      final clampedOffset = estimatedOffset.clamp(minExt, maxExt);
      if ((clampedOffset - position.pixels).abs() < 1.0) return;

      scrollController.jumpTo(clampedOffset);
      scrollToVerseCard(
        scrollController: scrollController,
        verseKeys: verseKeys,
        targetIndex: targetIndex,
        totalCount: totalCount,
        activeWordKey: activeWordKey,
        preferActiveWord: preferActiveWord,
        topSafePadding: topSafePadding,
        bottomSafePadding: bottomSafePadding,
        remainingAttempts: remainingAttempts - 1,
        schedulePostFrame: true,
      );
    }

    if (schedulePostFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) => performScroll());
    } else {
      performScroll();
    }
  }
}
