import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cue_models.dart';
import '../../providers/cuedeck_providers.dart';
import '../modals/tv_discovery_pairing_sheets.dart';
import '../modals/voice_and_keyboard_sheets.dart';
import '../tactile_dpad_painter.dart';

export '../tactile_dpad_painter.dart' show MouseCursorArrowIcon;

/// Google TV G10 Reference Donut D-Pad Ring (`204x204`) with corner
/// toggle buttons for TV Keyboard (`remote_keyboard_toggle_button`) and
/// Mouse / Touchpad (`remote_touchpad_toggle_button`).
class TactileDpadDialWidget extends ConsumerWidget {
  const TactileDpadDialWidget({super.key, this.isDarkMode = true});

  final bool isDarkMode;

  void _trigger(BuildContext context, WidgetRef ref, TvKeyCommand cmd) {
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

  void _openRemoteKeyboardSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RemoteKeyboardSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDirection = ref.watch(
      cueDeckProvider.select((s) => s.lastPressedDirection),
    );
    final isTouchpadMode = ref.watch(
      cueDeckProvider.select((s) => s.isTouchpadMode),
    );
    final goldColor =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);

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
                  _trigger(context, ref, TvKeyCommand.right);
                } else if (vx < -120) {
                  _trigger(context, ref, TvKeyCommand.left);
                }
              },
              onVerticalDragEnd: (details) {
                final vy = details.primaryVelocity ?? 0;
                if (vy > 120) {
                  _trigger(context, ref, TvKeyCommand.down);
                } else if (vy < -120) {
                  _trigger(context, ref, TvKeyCommand.up);
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
                        onTap: () => _trigger(context, ref, TvKeyCommand.up),
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
                        onTap: () => _trigger(context, ref, TvKeyCommand.down),
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
                        onTap: () => _trigger(context, ref, TvKeyCommand.left),
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
                        onTap: () => _trigger(context, ref, TvKeyCommand.right),
                        child: const SizedBox(width: 50, height: 64),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Tamam (OK)',
                    child: GestureDetector(
                      key: const Key('dpad_ok'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _trigger(context, ref, TvKeyCommand.ok),
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
                  onTap: () => _openRemoteKeyboardSheet(context),
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
              message: isTouchpadMode
                  ? 'Mouse Yüzeyini Kapat'
                  : 'Mouse / Touchpad Modu',
              child: Material(
                color: isTouchpadMode
                    ? goldColor.withValues(alpha: isDarkMode ? 0.18 : 0.14)
                    : (isDarkMode
                          ? const Color(0xFF111318)
                          : const Color(0xFFECEDF2)),
                shape: CircleBorder(
                  side: BorderSide(
                    color: isTouchpadMode
                        ? goldColor
                        : (isDarkMode
                              ? const Color(0xFF252832)
                              : const Color(0xFFCFD4DE)),
                    width: isTouchpadMode ? 1.2 : 1.0,
                  ),
                ),
                child: InkWell(
                  key: const Key('remote_touchpad_toggle_button'),
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(cueDeckProvider.notifier).toggleTouchpadMode();
                  },
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Center(
                      child: MouseCursorArrowIcon(
                        size: 14,
                        color: isTouchpadMode
                            ? goldColor
                            : (isDarkMode
                                  ? const Color(0xFFB8C0CE)
                                  : const Color(0xFF3E4656)),
                      ),
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
