import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cue_models.dart';
import '../../providers/cuedeck_providers.dart';
import '../modals/cue_pro_paywall_sheet.dart';
import '../planner/watch_planner_widgets.dart';
import '../tactile_dpad_painter.dart';

/// Unified collapsible bottom zone on the G10 physical remote chassis hosting either
/// the horizontally-scrollable nearest-first Watch Plan cards OR the precision Touchpad.
class RemoteBottomDeck extends ConsumerWidget {
  const RemoteBottomDeck({super.key, required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      cueDeckProvider.select((s) => s.bottomDeckMode),
    );

    final Widget content;
    switch (mode) {
      case RemoteBottomDeckMode.none:
        content = const SizedBox.shrink(key: ValueKey<String>('deck_none'));
      case RemoteBottomDeckMode.plan:
        content = WatchPlanDeckCarousel(
          key: const Key('remote_plan_deck'),
          isDarkMode: isDarkMode,
        );
      case RemoteBottomDeckMode.touchpad:
        content = RemoteTouchpadDeck(
          key: const Key('remote_touchpad_deck'),
          isDarkMode: isDarkMode,
        );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: content,
      ),
    );
  }
}

/// Horizontally swipeable watch plan cards sorted strictly nearest-to-farthest.
class WatchPlanDeckCarousel extends ConsumerStatefulWidget {
  const WatchPlanDeckCarousel({super.key, required this.isDarkMode});

  final bool isDarkMode;

  @override
  ConsumerState<WatchPlanDeckCarousel> createState() =>
      _WatchPlanDeckCarouselState();
}

class _WatchPlanDeckCarouselState extends ConsumerState<WatchPlanDeckCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openAddPlanSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    final notifier = ref.read(cueDeckProvider.notifier);
    if (!notifier.canAddMoreWatchPlans) {
      showCueProPaywallSheet(
        context,
        reasonMessage:
            'Ücretsiz sürümde en fazla ${CueProProductCatalog.maxFreeWatchPlans} özel izleme planı ekleyebilirsiniz.',
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWatchCueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cueItems = ref.watch(cueDeckProvider.select((s) => s.cueItems));
    final activePlayingId = ref.watch(
      cueDeckProvider.select((s) => s.activePlayingCueId),
    );
    final sortedItems = WatchCueItem.sortNearestFirst(cueItems);
    final isDarkMode = widget.isDarkMode;

    final goldColor =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final mutedText =
        isDarkMode ? const Color(0xFF8B95A7) : const Color(0xFF64748B);
    final chipBg =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFECEDF2);
    final chipBorder =
        isDarkMode ? const Color(0xFF252A38) : const Color(0xFFD0D6E2);

    final safePage = sortedItems.isEmpty
        ? 0
        : _currentPage.clamp(0, sortedItems.length - 1);
    final visibleDots = sortedItems.length.clamp(0, 6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 26,
          child: Row(
            children: <Widget>[
              Text(
                'İZLEME PLANI',
                style: TextStyle(
                  color: goldColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sortedItems.length}',
                  style: TextStyle(
                    color: goldColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                key: const Key('deck_add_plan_button'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openAddPlanSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: chipBorder, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.add_rounded, size: 13, color: goldColor),
                      const SizedBox(width: 2),
                      Text(
                        'Ekle',
                        style: TextStyle(
                          color: isDarkMode
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF1E293B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (sortedItems.isEmpty)
          _EmptyPlanDeckCard(
            isDarkMode: isDarkMode,
            goldColor: goldColor,
            mutedText: mutedText,
            onAddTap: () => _openAddPlanSheet(context),
          )
        else
          SizedBox(
            height: 120,
            child: PageView.builder(
              controller: _pageController,
              padEnds: false,
              itemCount: sortedItems.length,
              onPageChanged: (index) {
                if (mounted) {
                  setState(() => _currentPage = index);
                }
              },
              itemBuilder: (context, index) {
                final item = sortedItems[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == sortedItems.length - 1 ? 0 : 8,
                  ),
                  child: _ModernCompactPlanCard(
                    key: Key('plan_deck_card_${item.id}'),
                    item: item,
                    isDarkMode: isDarkMode,
                    isHighlighted: index == 0 || item.id == activePlayingId,
                    onTapCard: () {
                      HapticFeedback.selectionClick();
                      showWatchPlanDetailSheet(context, item);
                    },
                    onPlayTap: () {
                      HapticFeedback.mediumImpact();
                      ref.read(cueDeckProvider.notifier).beamCueToTv(item);
                    },
                  ),
                );
              },
            ),
          ),
        if (sortedItems.length > 1) ...<Widget>[
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(visibleDots, (idx) {
              final active = idx == safePage.clamp(0, visibleDots - 1);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: active ? 14 : 5,
                height: 4,
                decoration: BoxDecoration(
                  color: active
                      ? goldColor
                      : mutedText.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _EmptyPlanDeckCard extends StatelessWidget {
  const _EmptyPlanDeckCard({
    required this.isDarkMode,
    required this.goldColor,
    required this.mutedText,
    required this.onAddTap,
  });

  final bool isDarkMode;
  final Color goldColor;
  final Color mutedText;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? const Color(0xFF0E1119) : Colors.white;
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFD7DDE8);
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);

    return Container(
      height: 118,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Henüz izleme planı yok',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'YouTube\'dan Paylaş → CueDeck veya + Ekle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mutedText,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: goldColor.withValues(alpha: 0.18),
              foregroundColor: goldColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onAddTap,
            child: const Text(
              'Plan Ekle',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernCompactPlanCard extends StatelessWidget {
  const _ModernCompactPlanCard({
    super.key,
    required this.item,
    required this.isDarkMode,
    required this.isHighlighted,
    required this.onTapCard,
    required this.onPlayTap,
  });

  final WatchCueItem item;
  final bool isDarkMode;
  final bool isHighlighted;
  final VoidCallback onTapCard;
  final VoidCallback onPlayTap;

  @override
  Widget build(BuildContext context) {
    final brandColor = item.platform.brandColor;
    final goldColor =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final cardBg = isDarkMode ? const Color(0xFF0E111A) : Colors.white;
    final borderColor = isHighlighted
        ? goldColor.withValues(alpha: isDarkMode ? 0.45 : 0.65)
        : (isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFD7DDE8));
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final subtitleText = item.totalEpisodes > 1
        ? '${item.platform.unitLabel} ${item.currentEpisode}/${item.totalEpisodes} • %${item.progressPercent}'
        : '${item.formattedClock} • %${item.progressPercent}';

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTapCard,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: isHighlighted ? 1.2 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: brandColor.withValues(
                          alpha: isDarkMode ? 0.16 : 0.11,
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            item.platform.icon,
                            color: brandColor,
                            size: 11.5,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              item.platform.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: brandColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: goldColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        item.relativeScheduleLabel(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: goldColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.2,
                      height: 1.22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progressRatio,
                  minHeight: 3,
                  backgroundColor: isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.07),
                  valueColor: AlwaysStoppedAnimation<Color>(brandColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.more_horiz_rounded,
                    size: 16,
                    color: secondaryText,
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'TV\'de Başlat',
                    child: Material(
                      color: brandColor,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: Key('plan_card_play_${item.id}'),
                        customBorder: const CircleBorder(),
                        onTap: onPlayTap,
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// High-precision glassmorphic Touchpad + Scroll Strip occupying the bottom deck.
class RemoteTouchpadDeck extends ConsumerStatefulWidget {
  const RemoteTouchpadDeck({super.key, required this.isDarkMode});

  final bool isDarkMode;

  @override
  ConsumerState<RemoteTouchpadDeck> createState() => _RemoteTouchpadDeckState();
}

class _RemoteTouchpadDeckState extends ConsumerState<RemoteTouchpadDeck> {
  final Map<int, Offset> _activePointers = <int, Offset>{};
  final List<Offset> _trailPoints = <Offset>[];
  Offset? _touchPosition;
  Offset? _gestureDownOrigin;
  Duration _gestureDownTimestamp = Duration.zero;
  int _maxPointersInGesture = 0;
  bool _isTouching = false;
  bool _longPressTriggered = false;
  Timer? _longPressTimer;

  double _wheelVisualOffset = 0.0;
  double _wheelHapticAccumulator = 0.0;
  bool _isWheelScrolling = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length > _maxPointersInGesture) {
      _maxPointersInGesture = _activePointers.length;
    }

    if (_activePointers.length == 1) {
      _gestureDownOrigin = event.localPosition;
      _gestureDownTimestamp = event.timeStamp;
      _maxPointersInGesture = 1;
      _longPressTriggered = false;
      _longPressTimer?.cancel();
      _longPressTimer = Timer(const Duration(milliseconds: 420), () {
        if (!mounted ||
            _activePointers.length != 1 ||
            _longPressTriggered) {
          return;
        }
        _longPressTriggered = true;
        HapticFeedback.mediumImpact();
        ref.read(cueDeckProvider.notifier).clickTouchpadCursor(rightClick: true);
      });
    } else {
      _longPressTimer?.cancel();
    }

    setState(() {
      _isTouching = true;
      _touchPosition = event.localPosition;
      _trailPoints
        ..clear()
        ..add(event.localPosition);
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final prevPos = _activePointers[event.pointer];
    _activePointers[event.pointer] = event.localPosition;
    if (prevPos == null) return;

    final delta = event.localPosition - prevPos;
    if (_activePointers.length == 1) {
      if (_gestureDownOrigin != null &&
          (event.localPosition - _gestureDownOrigin!).distance > 10.0) {
        _longPressTimer?.cancel();
      }
      setState(() {
        _touchPosition = event.localPosition;
        _trailPoints.add(event.localPosition);
        if (_trailPoints.length > 10) {
          _trailPoints.removeAt(0);
        }
      });
      ref
          .read(cueDeckProvider.notifier)
          .moveTouchpadCursor(delta.dx, delta.dy);
    } else if (_activePointers.length >= 2) {
      _longPressTimer?.cancel();
      setState(() {
        _touchPosition = event.localPosition;
      });
      ref.read(cueDeckProvider.notifier).scrollTouchpadWheelByDelta(delta.dy);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    _longPressTimer?.cancel();

    if (_activePointers.isEmpty) {
      final origin = _gestureDownOrigin;
      final elapsedMs = (event.timeStamp - _gestureDownTimestamp).inMilliseconds;
      final travel =
          origin == null ? 999.0 : (event.localPosition - origin).distance;
      final isInstantTap = _maxPointersInGesture == 1 &&
          !_longPressTriggered &&
          travel < 10.0 &&
          elapsedMs < 350;

      if (isInstantTap) {
        HapticFeedback.lightImpact();
        ref.read(cueDeckProvider.notifier).clickTouchpadCursor();
      }
      _resetGestureVisuals();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    _longPressTimer?.cancel();
    if (_activePointers.isEmpty) {
      _resetGestureVisuals();
    }
  }

  void _resetGestureVisuals() {
    if (!mounted) return;
    setState(() {
      _isTouching = false;
      _touchPosition = null;
      _trailPoints.clear();
      _gestureDownOrigin = null;
      _maxPointersInGesture = 0;
    });
  }

  void _handleWheelDragUpdate(DragUpdateDetails details) {
    final dy = details.delta.dy;
    setState(() {
      _isWheelScrolling = true;
      _wheelVisualOffset = (_wheelVisualOffset + dy) % 360.0;
    });
    _wheelHapticAccumulator += dy.abs();
    if (_wheelHapticAccumulator >= 14.0) {
      _wheelHapticAccumulator %= 14.0;
      HapticFeedback.selectionClick();
    }
    ref.read(cueDeckProvider.notifier).scrollTouchpadWheelByDelta(dy);
  }

  void _handleWheelDragEnd() {
    if (_isWheelScrolling && mounted) {
      setState(() {
        _isWheelScrolling = false;
      });
    }
    _wheelHapticAccumulator = 0.0;
  }

  void _stepWheel(int clicks) {
    HapticFeedback.selectionClick();
    setState(() {
      _wheelVisualOffset = (_wheelVisualOffset - (clicks * 12.0)) % 360.0;
    });
    ref.read(cueDeckProvider.notifier).scrollTouchpadWheelSteps(clicks);
  }

  String _sensitivityLabel(double s) {
    if (s <= 0.95) return 'Hassas';
    if (s <= 1.5) return 'Normal';
    return 'Hızlı';
  }

  @override
  Widget build(BuildContext context) {
    final sensitivity = ref.watch(
      cueDeckProvider.select((s) => s.touchpadSensitivity),
    );
    final isDarkMode = widget.isDarkMode;
    final goldColor =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final mutedText =
        isDarkMode ? const Color(0xFF8B95A7) : const Color(0xFF64748B);
    final pillBg =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFECEDF2);
    final pillBorder =
        isDarkMode ? const Color(0xFF252A38) : const Color(0xFFD0D6E2);
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 24,
          child: Row(
            children: <Widget>[
              MouseCursorArrowIcon(size: 12, color: goldColor),
              const SizedBox(width: 5),
              Text(
                'TOUCHPAD',
                style: TextStyle(
                  color: goldColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
              const Spacer(),
              InkWell(
                key: const Key('touchpad_sensitivity_chip'),
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(cueDeckProvider.notifier).cycleTouchpadSensitivity();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pillBorder),
                  ),
                  child: Text(
                    _sensitivityLabel(sensitivity),
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'İzleme Planına Dön',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(cueDeckProvider.notifier).openPlanDeck();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: mutedText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 112,
          child: Row(
            children: <Widget>[
              Expanded(
                child: RawGestureDetector(
                  gestures: <Type, GestureRecognizerFactory>{
                    _EagerTouchpadArenaRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _EagerTouchpadArenaRecognizer
                        >(
                          () => _EagerTouchpadArenaRecognizer(),
                          (_EagerTouchpadArenaRecognizer instance) {},
                        ),
                  },
                  child: Listener(
                    key: const Key('dpad_touchpad_surface'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerCancel,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ModernTouchpadPainter(
                              isDarkMode: isDarkMode,
                              accentColor: const Color(0xFFE2A84B),
                              touchPosition: _touchPosition,
                              trailPoints: List<Offset>.unmodifiable(
                                _trailPoints,
                              ),
                              isTouching: _isTouching,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 140),
                            opacity: _isTouching ? 0.0 : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  MouseCursorArrowIcon(
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.36),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Kaydır • Dokun: Tıkla',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.42,
                                        ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 32,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF0E1119)
                        : const Color(0xFF1F242E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isWheelScrolling
                          ? goldColor
                          : goldColor.withValues(alpha: 0.38),
                      width: _isWheelScrolling ? 1.3 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      InkWell(
                        key: const Key('touchpad_wheel_up_button'),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(13),
                        ),
                        onTap: () => _stepWheel(2),
                        child: SizedBox(
                          width: double.infinity,
                          height: 22,
                          child: Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 15,
                            color: goldColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
                            key: const Key('touchpad_scroll_wheel'),
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _isWheelScrolling = true);
                            },
                            onVerticalDragUpdate: _handleWheelDragUpdate,
                            onVerticalDragEnd: (_) => _handleWheelDragEnd(),
                            onVerticalDragCancel: _handleWheelDragEnd,
                            child: CustomPaint(
                              painter: TactileScrollWheelPainter(
                                scrollOffset: _wheelVisualOffset,
                                accentColor: const Color(0xFFE2A84B),
                                isDarkMode: isDarkMode,
                                isScrolling: _isWheelScrolling,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        key: const Key('touchpad_wheel_down_button'),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(13),
                        ),
                        onTap: () => _stepWheel(-2),
                        child: SizedBox(
                          width: double.infinity,
                          height: 22,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: goldColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Material(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    key: const Key('touchpad_left_click_button'),
                    borderRadius: BorderRadius.circular(11),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(cueDeckProvider.notifier).clickTouchpadCursor();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: goldColor.withValues(alpha: 0.42),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Sol Tık',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Material(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    key: const Key('touchpad_right_click_button'),
                    borderRadius: BorderRadius.circular(11),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref
                          .read(cueDeckProvider.notifier)
                          .clickTouchpadCursor(rightClick: true);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: pillBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Sağ Tık',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedText,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Immediately wins the gesture arena for touchpad pointer gestures so ancestor
/// scroll views never hijack vertical drags on small viewports.
class _EagerTouchpadArenaRecognizer extends OneSequenceGestureRecognizer {
  @override
  String get debugDescription => 'eagerTouchpadArena';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }
}
