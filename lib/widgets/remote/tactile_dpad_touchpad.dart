import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cue_models.dart';
import '../../providers/cuedeck_providers.dart';
import '../modals/tv_discovery_pairing_sheets.dart';
import '../modals/voice_and_keyboard_sheets.dart';
import '../tactile_dpad_painter.dart';

/// Google TV G10 Reference Donut D-Pad Ring (`204x204`) with a corner
/// toggle button (`remote_touchpad_toggle_button`) switching into interactive
/// Mouse / Touchpad + Rotary Scroll Wheel cockpit mode.
class TactileDpadDialWidget extends ConsumerStatefulWidget {
  const TactileDpadDialWidget({super.key, this.isDarkMode = true});

  final bool isDarkMode;

  @override
  ConsumerState<TactileDpadDialWidget> createState() =>
      _TactileDpadDialWidgetState();
}

class _TactileDpadDialWidgetState extends ConsumerState<TactileDpadDialWidget> {
  Offset? _touchPosition;
  double _wheelVisualOffset = 0.0;
  double _wheelHapticAccumulator = 0.0;
  bool _isWheelScrolling = false;

  void _trigger(TvKeyCommand cmd) {
    HapticFeedback.lightImpact();
    final selected = ref.read(cueDeckProvider).selectedDevice;
    if (selected.hasValidIp &&
        selected.protocol == TvConnectionProtocol.remotePort6466 &&
        !selected.isPaired) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Pin6466PairingSheet(targetIp: selected.ip),
      );
      return;
    }
    ref.read(cueDeckProvider.notifier).sendRemoteKey(cmd);
  }

  void _handleTouchpadPanUpdate(DragUpdateDetails details) {
    setState(() {
      _touchPosition = details.localPosition;
    });
    ref
        .read(cueDeckProvider.notifier)
        .moveTouchpadCursor(details.delta.dx, details.delta.dy);
  }

  void _clearTouchpadPosition() {
    if (_touchPosition != null) {
      setState(() {
        _touchPosition = null;
      });
    }
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
    if (_isWheelScrolling) {
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

  void _openRemoteKeyboardSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RemoteKeyboardSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeDirection = ref.watch(
      cueDeckProvider.select((s) => s.lastPressedDirection),
    );
    final isTouchpadMode = ref.watch(
      cueDeckProvider.select((s) => s.isTouchpadMode),
    );
    final isDarkMode = widget.isDarkMode;
    final goldColor =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);

    if (isTouchpadMode) {
      return SizedBox(
        width: double.infinity,
        height: 286,
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 32,
              child: Row(
                children: <Widget>[
                  Tooltip(
                    message: 'TV Klavyesini Aç (Telefon Klavyesiyle Yaz)',
                    child: Material(
                      color: isDarkMode
                          ? const Color(0xFF12151E)
                          : const Color(0xFFE9ECF2),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: const Key('remote_keyboard_toggle_button'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: _openRemoteKeyboardSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF262A36)
                                  : const Color(0xFFCFD4DE),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.keyboard_alt_outlined,
                                size: 14,
                                color: isDarkMode
                                    ? const Color(0xFFD0D7E4)
                                    : const Color(0xFF2D3545),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Klavye',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? const Color(0xFFD0D7E4)
                                      : const Color(0xFF2D3545),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: goldColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: goldColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.mouse_rounded,
                            size: 13,
                            color: goldColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'TOUCHPAD',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: goldColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Klasik Yön Tuşlarına (D-Pad) Dön',
                    child: Material(
                      color: goldColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: const Key('remote_touchpad_toggle_button'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _clearTouchpadPosition();
                          ref.read(cueDeckProvider.notifier).toggleTouchpadMode();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: goldColor,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.control_camera_rounded,
                                size: 14,
                                color: goldColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'D-Pad',
                                style: TextStyle(
                                  color: goldColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: GestureDetector(
                      key: const Key('dpad_touchpad_surface'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(cueDeckProvider.notifier)
                            .clickTouchpadCursor();
                      },
                      onDoubleTap: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(cueDeckProvider.notifier)
                            .clickTouchpadCursor(rightClick: true);
                      },
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(cueDeckProvider.notifier)
                            .clickTouchpadCursor(rightClick: true);
                      },
                      onPanStart: (details) {
                        setState(() {
                          _touchPosition = details.localPosition;
                        });
                      },
                      onPanUpdate: _handleTouchpadPanUpdate,
                      onPanEnd: (_) => _clearTouchpadPosition(),
                      onPanCancel: _clearTouchpadPosition,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Positioned.fill(
                            child: CustomPaint(
                              painter: TactileDpadPainter(
                                activeDirection: activeDirection,
                                accentColor: const Color(0xFFE2A84B),
                                isDarkMode: isDarkMode,
                                isTouchpadMode: true,
                                touchPosition: _touchPosition,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            left: 12,
                            right: 12,
                            child: IgnorePointer(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Kaydır: TV Mouse Oku • Dokun: Sol Tık',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.50),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 8.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  SizedBox(
                    width: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF10131C)
                            : const Color(0xFF20242E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _isWheelScrolling
                              ? goldColor
                              : goldColor.withValues(alpha: 0.42),
                          width: _isWheelScrolling ? 1.4 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          Tooltip(
                            message: 'Tekerlek Yukarı Kaydır',
                            child: InkWell(
                              key: const Key('touchpad_wheel_up_button'),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(17),
                              ),
                              onTap: () => _stepWheel(2),
                              child: SizedBox(
                                width: double.infinity,
                                height: 28,
                                child: Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 18,
                                  color: goldColor.withValues(alpha: 0.90),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                key: const Key('touchpad_scroll_wheel'),
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _isWheelScrolling = true;
                                  });
                                },
                                onVerticalDragUpdate: _handleWheelDragUpdate,
                                onVerticalDragEnd: (_) => _handleWheelDragEnd(),
                                onVerticalDragCancel: _handleWheelDragEnd,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(cueDeckProvider.notifier)
                                      .clickTouchpadCursor();
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: TactileScrollWheelPainter(
                                          scrollOffset: _wheelVisualOffset,
                                          accentColor: const Color(0xFFE2A84B),
                                          isDarkMode: isDarkMode,
                                          isScrolling: _isWheelScrolling,
                                        ),
                                      ),
                                    ),
                                    IgnorePointer(
                                      child: RotatedBox(
                                        quarterTurns: 3,
                                        child: Text(
                                          'TEKERLEK',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: _isWheelScrolling
                                                  ? 0.85
                                                  : 0.45,
                                            ),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 7.5,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Tooltip(
                            message: 'Tekerlek Aşağı Kaydır',
                            child: InkWell(
                              key: const Key('touchpad_wheel_down_button'),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(17),
                              ),
                              onTap: () => _stepWheel(-2),
                              child: SizedBox(
                                width: double.infinity,
                                height: 28,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: goldColor.withValues(alpha: 0.90),
                                ),
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
              height: 36,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Material(
                      color: isDarkMode
                          ? const Color(0xFF12151E)
                          : const Color(0xFFE9ECF2),
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        key: const Key('touchpad_left_click_button'),
                        borderRadius: BorderRadius.circular(13),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(cueDeckProvider.notifier)
                              .clickTouchpadCursor();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: goldColor.withValues(alpha: 0.42),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.ads_click_rounded,
                                size: 13,
                                color: goldColor,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Sol Tık (Seç)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.88)
                                        : const Color(0xFF1E2430),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      color: isDarkMode
                          ? const Color(0xFF12151E)
                          : const Color(0xFFE9ECF2),
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        key: const Key('touchpad_right_click_button'),
                        borderRadius: BorderRadius.circular(13),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(cueDeckProvider.notifier)
                              .clickTouchpadCursor(rightClick: true);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF252832)
                                  : const Color(0xFFCFD4DE),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.undo_rounded,
                                size: 13,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.72)
                                    : const Color(0xFF3E4656),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Sağ Tık (Geri)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.76)
                                        : const Color(0xFF3E4656),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 204,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 204,
            height: 204,
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final vx = details.primaryVelocity ?? 0;
                if (vx > 120) {
                  _trigger(TvKeyCommand.right);
                } else if (vx < -120) {
                  _trigger(TvKeyCommand.left);
                }
              },
              onVerticalDragEnd: (details) {
                final vy = details.primaryVelocity ?? 0;
                if (vy > 120) {
                  _trigger(TvKeyCommand.down);
                } else if (vy < -120) {
                  _trigger(TvKeyCommand.up);
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: TactileDpadPainter(
                        activeDirection: activeDirection,
                        accentColor: const Color(0xFFE2A84B),
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    child: Tooltip(
                      message: 'Yukarı',
                      child: InkResponse(
                        key: const Key('dpad_up'),
                        radius: 28,
                        onTap: () => _trigger(TvKeyCommand.up),
                        child: const SizedBox(width: 64, height: 50),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    child: Tooltip(
                      message: 'Aşağı',
                      child: InkResponse(
                        key: const Key('dpad_down'),
                        radius: 28,
                        onTap: () => _trigger(TvKeyCommand.down),
                        child: const SizedBox(width: 64, height: 50),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    child: Tooltip(
                      message: 'Sol',
                      child: InkResponse(
                        key: const Key('dpad_left'),
                        radius: 28,
                        onTap: () => _trigger(TvKeyCommand.left),
                        child: const SizedBox(width: 50, height: 64),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    child: Tooltip(
                      message: 'Sağ',
                      child: InkResponse(
                        key: const Key('dpad_right'),
                        radius: 28,
                        onTap: () => _trigger(TvKeyCommand.right),
                        child: const SizedBox(width: 50, height: 64),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Tamam (OK)',
                    child: GestureDetector(
                      key: const Key('dpad_ok'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _trigger(TvKeyCommand.ok),
                      child: const SizedBox(
                        width: 80,
                        height: 80,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 2,
            left: 2,
            child: Tooltip(
              message: 'TV Klavyesini Aç (Telefon Klavyesiyle Yaz)',
              child: Material(
                color: isDarkMode
                    ? const Color(0xFF111318)
                    : const Color(0xFFECEDF2),
                shape: CircleBorder(
                  side: BorderSide(
                    color: isDarkMode
                        ? const Color(0xFF252832)
                        : const Color(0xFFCFD4DE),
                    width: 1.0,
                  ),
                ),
                child: InkWell(
                  key: const Key('remote_keyboard_toggle_button'),
                  customBorder: const CircleBorder(),
                  onTap: _openRemoteKeyboardSheet,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      Icons.keyboard_alt_outlined,
                      size: 15,
                      color: isDarkMode
                          ? const Color(0xFFB8C0CE)
                          : const Color(0xFF3E4656),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 2,
            right: 2,
            child: Tooltip(
              message: 'Mouse / Touchpad Moduna Geç',
              child: Material(
                color: isDarkMode
                    ? const Color(0xFF111318)
                    : const Color(0xFFECEDF2),
                shape: CircleBorder(
                  side: BorderSide(
                    color: isDarkMode
                        ? const Color(0xFF252832)
                        : const Color(0xFFCFD4DE),
                    width: 1.0,
                  ),
                ),
                child: InkWell(
                  key: const Key('remote_touchpad_toggle_button'),
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _clearTouchpadPosition();
                    ref.read(cueDeckProvider.notifier).toggleTouchpadMode();
                  },
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      Icons.mouse_outlined,
                      size: 15,
                      color: isDarkMode
                          ? const Color(0xFFB8C0CE)
                          : const Color(0xFF3E4656),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
