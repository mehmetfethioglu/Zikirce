import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/tv_mode_provider.dart';

/// Android TV Kumandası (D-Pad + OK/Select) Odaklanabilir Sarmalayıcı Bileşen
/// - Ali Kuşçu Standardı: Odak durumu yerel [ValueNotifier] ile izole edilir, üst ağacı rebuild etmez.
/// - 10-Foot UI Standardı: Odaklandığında 1.04x büyüme + 2.5px Altın (#D4AF37) çerçeve ve parlama.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onFocusChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final double borderRadius;
  final double focusScale;
  final Color focusBorderColor;
  final EdgeInsetsGeometry? padding;

  const TvFocusable({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.onFocusChanged,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius = 18.0,
    this.focusScale = 1.035,
    this.focusBorderColor = const Color(0xFFD4AF37),
    this.padding,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  final ValueNotifier<bool> _isFocusedNotifier = ValueNotifier<bool>(false);
  FocusNode? _internalFocusNode;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    _isFocusedNotifier.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.gameButtonA) {
        if (widget.onPressed != null) {
          HapticFeedback.selectionClick();
          widget.onPressed!();
          return KeyEventResult.handled;
        }
      } else if (key == LogicalKeyboardKey.contextMenu ||
          key == LogicalKeyboardKey.gameButtonX) {
        if (widget.onLongPress != null) {
          HapticFeedback.mediumImpact();
          widget.onLongPress!();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tvActive = TvModeService.isTvModeActive;
    return Focus(
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus && tvActive,
      onFocusChange: (focused) {
        _isFocusedNotifier.value = focused && TvModeService.isTvModeActive;
        widget.onFocusChanged?.call(focused);
      },
      onKeyEvent: _handleKeyEvent,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isFocusedNotifier,
        builder: (context, isFocused, child) {
          final showFocusFrame = isFocused && TvModeService.isTvModeActive;
          return AnimatedScale(
            scale: showFocusFrame ? widget.focusScale : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: showFocusFrame
                      ? widget.focusBorderColor
                      : Colors.transparent,
                  width: showFocusFrame ? 2.6 : 0.0,
                ),
                boxShadow: showFocusFrame
                    ? [
                        BoxShadow(
                          color: widget.focusBorderColor.withValues(alpha: 0.42),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : const [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  canRequestFocus: false,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  onTap: widget.onPressed,
                  onLongPress: widget.onLongPress,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Kumanda Üzerindeki Rakam Tuşlarıyla (0-9) Doğrudan Sayfaya Atlama Dinleyicisi
class TvRemoteNumberJumpWrapper extends StatefulWidget {
  final Widget child;
  final int maxPage;
  final ValueChanged<int> onJumpToPage;

  const TvRemoteNumberJumpWrapper({
    super.key,
    required this.child,
    required this.maxPage,
    required this.onJumpToPage,
  });

  @override
  State<TvRemoteNumberJumpWrapper> createState() =>
      _TvRemoteNumberJumpWrapperState();
}

class _TvRemoteNumberJumpWrapperState extends State<TvRemoteNumberJumpWrapper> {
  final ValueNotifier<String> _digitBuffer = ValueNotifier<String>('');
  Timer? _commitTimer;

  static final Map<LogicalKeyboardKey, String> _digitKeyMap = {
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  @override
  void dispose() {
    _commitTimer?.cancel();
    _digitBuffer.dispose();
    super.dispose();
  }

  void _commitPageJump() {
    _commitTimer?.cancel();
    final raw = _digitBuffer.value;
    if (raw.isEmpty) return;
    _digitBuffer.value = '';
    final parsed = int.tryParse(raw);
    if (parsed != null && parsed >= 1) {
      final target = parsed.clamp(1, widget.maxPage);
      widget.onJumpToPage(target);
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final digit = _digitKeyMap[event.logicalKey];
    if (digit != null) {
      if (_digitBuffer.value.isEmpty && digit == '0') {
        return KeyEventResult.handled;
      }
      if (_digitBuffer.value.length < 4) {
        _digitBuffer.value = '${_digitBuffer.value}$digit';
      }
      _commitTimer?.cancel();
      _commitTimer = Timer(const Duration(milliseconds: 1150), _commitPageJump);
      return KeyEventResult.handled;
    }

    if (_digitBuffer.value.isNotEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _commitPageJump();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        _commitTimer?.cancel();
        _digitBuffer.value = '';
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _onKeyEvent,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 24,
            right: 28,
            child: ValueListenableBuilder<String>(
              valueListenable: _digitBuffer,
              builder: (context, buffer, _) {
                if (buffer.isEmpty) return const SizedBox.shrink();
                return Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E2920).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.dialpad_rounded,
                          color: Color(0xFFD4AF37),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Sayfaya Git: $buffer',
                          style: const TextStyle(
                            color: Color(0xFFFDF8EE),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
