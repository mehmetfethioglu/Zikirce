import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/utils/quran_word_highlighter.dart';

/// Accumulates [InlineSpan]s while tracking exact UTF-16 offsets so the
/// active word can be highlighted or pointed at without swapping `TextSpan`
/// for `WidgetSpan`.
class QuranSpanAccumulator {
  final List<InlineSpan> spans = <InlineSpan>[];
  int _utf16Offset = 0;
  TextRange? activeWordRange;

  void addText(
    String text, {
    TextStyle? style,
    GestureRecognizer? recognizer,
    bool isActiveWord = false,
  }) {
    if (text.isEmpty) return;
    final int start = _utf16Offset;
    spans.add(
      TextSpan(
        text: text,
        style: style,
        recognizer: recognizer,
      ),
    );
    _utf16Offset += text.length;
    if (isActiveWord) {
      activeWordRange = TextRange(start: start, end: _utf16Offset);
    }
  }

  void addWidget(WidgetSpan span) {
    spans.add(span);
    // WidgetSpan occupies a single UTF-16 placeholder code unit (U+FFFC).
    _utf16Offset += 1;
  }
}

/// Renders an Arabic Quran paragraph with zero-reflow active word tracking.
///
/// Inactive and active words share identical text shaping inside a single
/// [RichText] (`RenderParagraph`); active word highlights and tracking arrows
/// are positioned directly from `RenderParagraph.getBoxesForSelection`.
class QuranTrackedParagraph extends StatefulWidget {
  final TextSpan textSpan;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final TextRange? activeWordRange;
  final bool isArrowMode;
  final bool isDark;
  final bool isTvMode;
  final int activeWordDurationMs;
  final double playbackSpeed;
  final bool isPlaying;
  final Object? activeWordIdentity;

  const QuranTrackedParagraph({
    super.key,
    required this.textSpan,
    required this.textAlign,
    this.textDirection = TextDirection.rtl,
    this.activeWordRange,
    required this.isArrowMode,
    required this.isDark,
    this.isTvMode = false,
    this.activeWordDurationMs = 500,
    this.playbackSpeed = 1.0,
    this.isPlaying = false,
    this.activeWordIdentity,
  });

  @override
  State<QuranTrackedParagraph> createState() => QuranTrackedParagraphState();
}

class QuranTrackedParagraphState extends State<QuranTrackedParagraph> {
  /// Returns the bounding rect of the currently active word in local
  /// paragraph coordinates (including space for the tracking pointer).
  Rect? get activeWordRect {
    if (!mounted) return null;
    final ro = context.findRenderObject();
    if (ro is _RenderTrackedParagraph) {
      return ro.activeWordRect;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool showArrow =
        widget.isArrowMode && widget.activeWordRange != null;

    return _TrackedParagraphRenderWidget(
      activeWordRange: widget.activeWordRange,
      isArrowMode: widget.isArrowMode,
      isDark: widget.isDark,
      isTvMode: widget.isTvMode,
      children: [
        RichText(
          text: widget.textSpan,
          textAlign: widget.textAlign,
          textDirection: widget.textDirection,
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        ),
        if (showArrow)
          IgnorePointer(
            child: QuranWordTrackingPointer(
              isDark: widget.isDark,
              height: widget.isTvMode ? 12.5 : 8.0,
              durationMs: widget.activeWordDurationMs,
              playbackSpeed: widget.playbackSpeed,
              isPlaying: widget.isPlaying,
              wordIdentity: widget.activeWordIdentity,
            ),
          ),
      ],
    );
  }
}

class _TrackedParagraphRenderWidget extends MultiChildRenderObjectWidget {
  final TextRange? activeWordRange;
  final bool isArrowMode;
  final bool isDark;
  final bool isTvMode;

  const _TrackedParagraphRenderWidget({
    required this.activeWordRange,
    required this.isArrowMode,
    required this.isDark,
    required this.isTvMode,
    required super.children,
  });

  @override
  _RenderTrackedParagraph createRenderObject(BuildContext context) {
    return _RenderTrackedParagraph(
      activeWordRange: activeWordRange,
      isArrowMode: isArrowMode,
      isDark: isDark,
      isTvMode: isTvMode,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTrackedParagraph renderObject,
  ) {
    renderObject
      ..activeWordRange = activeWordRange
      ..isArrowMode = isArrowMode
      ..isDark = isDark
      ..isTvMode = isTvMode;
  }
}

class _TrackedParagraphParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTrackedParagraph extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TrackedParagraphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox,
            _TrackedParagraphParentData> {
  _RenderTrackedParagraph({
    required TextRange? activeWordRange,
    required bool isArrowMode,
    required bool isDark,
    required bool isTvMode,
  })  : _activeWordRange = activeWordRange,
        _isArrowMode = isArrowMode,
        _isDark = isDark,
        _isTvMode = isTvMode;

  TextRange? _activeWordRange;
  TextRange? get activeWordRange => _activeWordRange;
  set activeWordRange(TextRange? value) {
    if (_activeWordRange == value) return;
    _activeWordRange = value;
    markNeedsLayout();
  }

  bool _isArrowMode;
  bool get isArrowMode => _isArrowMode;
  set isArrowMode(bool value) {
    if (_isArrowMode == value) return;
    _isArrowMode = value;
    markNeedsLayout();
  }

  bool _isDark;
  bool get isDark => _isDark;
  set isDark(bool value) {
    if (_isDark == value) return;
    _isDark = value;
    markNeedsPaint();
  }

  bool _isTvMode;
  bool get isTvMode => _isTvMode;
  set isTvMode(bool value) {
    if (_isTvMode == value) return;
    _isTvMode = value;
    markNeedsLayout();
  }

  List<Rect> _activeWordBoxes = const <Rect>[];
  Rect? _activeWordRect;
  Rect? get activeWordRect => _activeWordRect;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TrackedParagraphParentData) {
      child.parentData = _TrackedParagraphParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final p = firstChild;
    return p != null ? p.getMinIntrinsicWidth(height) : 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final p = firstChild;
    return p != null ? p.getMaxIntrinsicWidth(height) : 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final p = firstChild;
    return p != null ? p.getMinIntrinsicHeight(width) : 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final p = firstChild;
    return p != null ? p.getMaxIntrinsicHeight(width) : 0.0;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final p = firstChild;
    if (p == null) return constraints.smallest;
    return p.getDryLayout(constraints);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return firstChild?.getDistanceToActualBaseline(baseline);
  }

  @override
  void performLayout() {
    final RenderBox? paragraph = firstChild;
    if (paragraph == null) {
      size = constraints.smallest;
      _activeWordBoxes = const <Rect>[];
      _activeWordRect = null;
      return;
    }

    paragraph.layout(constraints, parentUsesSize: true);
    (paragraph.parentData as _TrackedParagraphParentData).offset = Offset.zero;
    size = constraints.constrain(paragraph.size);

    final range = _activeWordRange;
    if (paragraph is RenderParagraph &&
        range != null &&
        range.start >= 0 &&
        range.end > range.start) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
        boxHeightStyle: ui.BoxHeightStyle.tight,
        boxWidthStyle: ui.BoxWidthStyle.tight,
      );
      if (boxes.isNotEmpty) {
        final rects = <Rect>[];
        Rect unionRect = boxes.first.toRect();
        rects.add(unionRect);
        for (int i = 1; i < boxes.length; i++) {
          final r = boxes[i].toRect();
          rects.add(r);
          unionRect = unionRect.expandToInclude(r);
        }
        _activeWordBoxes = rects;
        _activeWordRect = Rect.fromLTRB(
          unionRect.left - 4.0,
          unionRect.top - 6.0,
          unionRect.right + 4.0,
          unionRect.bottom + (_isTvMode ? 16.0 : 12.0),
        );
      } else {
        _activeWordBoxes = const <Rect>[];
        _activeWordRect = null;
      }
    } else {
      _activeWordBoxes = const <Rect>[];
      _activeWordRect = null;
    }

    final RenderBox? pointerChild = childAfter(paragraph);
    if (pointerChild != null) {
      final pointerData =
          pointerChild.parentData as _TrackedParagraphParentData;
      if (_isArrowMode && _activeWordBoxes.isNotEmpty) {
        final Rect b = _activeWordBoxes.length == 1
            ? _activeWordBoxes.first
            : _activeWordBoxes.reduce((a, c) => a.expandToInclude(c));
        final double pointerWidth = math.max(12.0, b.width);
        final double pointerHeight = _isTvMode ? 12.5 : 8.0;
        pointerChild.layout(
          BoxConstraints.tightFor(width: pointerWidth, height: pointerHeight),
          parentUsesSize: false,
        );
        final double dxOffset = b.left - ((pointerWidth - b.width) / 2.0);
        pointerData.offset = Offset(
          dxOffset,
          b.bottom + (_isTvMode ? 1.5 : 1.0),
        );
      } else {
        pointerChild.layout(
          BoxConstraints.tight(Size.zero),
          parentUsesSize: false,
        );
        pointerData.offset = Offset.zero;
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? paragraph = firstChild;
    if (paragraph == null) return;

    if (!_isArrowMode && _activeWordBoxes.isNotEmpty) {
      final Color emeraldBg =
          _isDark ? const Color(0xFF059669) : const Color(0xFF10B981);
      final Rect b = _activeWordBoxes.length == 1
          ? _activeWordBoxes.first
          : _activeWordBoxes.reduce((a, c) => a.expandToInclude(c));
      final RRect pillRRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          b.left - 4.5,
          b.top - 2.0,
          b.right + 4.5,
          b.bottom + 2.0,
        ).shift(offset),
        const Radius.circular(8.0),
      );
      final Paint glowPaint = Paint()
        ..color = emeraldBg.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      context.canvas.drawRRect(pillRRect, glowPaint);
      final Paint bgPaint = Paint()..color = emeraldBg;
      context.canvas.drawRRect(pillRRect, bgPaint);
    }

    context.paintChild(paragraph, offset);

    final RenderBox? pointerChild = childAfter(paragraph);
    if (_isArrowMode && pointerChild != null && _activeWordBoxes.isNotEmpty) {
      final pointerData =
          pointerChild.parentData as _TrackedParagraphParentData;
      context.paintChild(pointerChild, offset + pointerData.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? paragraph = firstChild;
    if (paragraph == null) return false;
    return paragraph.hitTest(result, position: position);
  }
}
