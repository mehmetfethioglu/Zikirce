import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cue_models.dart';
import '../../providers/cuedeck_providers.dart';
import '../../screens/cuedeck_settings_screen.dart';
import '../cuetv_channel_studio_sheet.dart';
import '../modals/tv_discovery_pairing_sheets.dart';
import '../modals/voice_and_keyboard_sheets.dart';
import 'quick_launch_app_dock.dart';
import 'remote_bottom_deck.dart';
import 'tactile_dpad_touchpad.dart';

/// Google TV G10 Reference Physical Remote Control Chassis supporting True Black
/// Dark Mode and Classic White Light Mode, Universal Smart TV protocols, IR Blaster,
/// Wake-on-LAN, and the swipeable Bottom Plan / Touchpad Deck.
class G10PhysicalRemoteChassis extends ConsumerWidget {
  const G10PhysicalRemoteChassis({super.key, required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void sendKey(TvKeyCommand cmd) {
      HapticFeedback.lightImpact();
      final selected = ref.read(cueDeckProvider).selectedDevice;
      if (selected.hasValidIp &&
          selected.protocol == TvConnectionProtocol.remotePort6466 &&
          !selected.isPaired &&
          !(cmd == TvKeyCommand.power &&
              !selected.isOnline &&
              selected.hasValidMac)) {
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

    final isPlanDeckActive = ref.watch(
      cueDeckProvider.select((s) => s.isPlanDeckActive),
    );
    final upcomingPlanCount = ref.watch(
      cueDeckProvider.select(
        (s) => s.cueItems.where((e) => !e.isCompleted).length,
      ),
    );
    final isMuted = ref.watch(
      cueDeckProvider.select((s) => s.isMuted),
    );
    final chassisColor =
        isDarkMode ? const Color(0xFF000000) : const Color(0xFFF5F6F9);
    final chassisBorderColor =
        isDarkMode ? const Color(0xFF1E2028) : const Color(0xFFDCDFE6);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 316),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        decoration: BoxDecoration(
          color: chassisColor,
          borderRadius: BorderRadius.circular(44),
          border: Border.all(color: chassisBorderColor, width: 1.4),
          boxShadow: isDarkMode
              ? const <BoxShadow>[]
              : <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 28,
                    offset: const Offset(10, 14),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ROW 1: Power (Left) | TV Status Indicator (Center) | Inputs (Right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _RoundRemoteKeyButton(
                  icon: Icons.power_settings_new_rounded,
                  tooltip: 'Güç / Uyku',
                  isDarkMode: isDarkMode,
                  size: 40,
                  iconSize: 19,
                  onTap: () => sendKey(TvKeyCommand.power),
                ),
                _TvConnectionIconOnlyIndicator(
                  isDarkMode: isDarkMode,
                  onTap: () => _showSettingsModal(context),
                ),
                _RoundRemoteKeyButton(
                  icon: Icons.input_rounded,
                  tooltip: 'TV Girişleri',
                  isDarkMode: isDarkMode,
                  size: 40,
                  iconSize: 18,
                  onTap: () => sendKey(TvKeyCommand.inputs),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ROW 2: Watch Plan Toggle | Modern Mic Voice | Settings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _RoundRemoteKeyButton(
                    key: const Key('remote_plan_toggle_button'),
                    icon: Icons.event_note_rounded,
                    tooltip: 'İzleme Planı',
                    isDarkMode: isDarkMode,
                    isActive: isPlanDeckActive,
                    activeColor: const Color(0xFFE2A84B),
                    badgeCount: isPlanDeckActive ? 0 : upcomingPlanCount,
                    size: 44,
                    iconSize: 20,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(cueDeckProvider.notifier).togglePlanDeck();
                    },
                  ),
                ),
                _AssistantVoiceCenterButton(
                  key: const Key('remote_voice_button'),
                  isDarkMode: isDarkMode,
                  onTap: () => _showVoiceControlSheet(context, ref),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _RoundRemoteKeyButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Ayarlar',
                    isDarkMode: isDarkMode,
                    size: 44,
                    iconSize: 20,
                    onTap: () => _showSettingsModal(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ROW 3: Center Donut D-Pad Ring (with Keyboard & Mouse Cursor toggles)
            TactileDpadDialWidget(isDarkMode: isDarkMode),
            const SizedBox(height: 6),

            // ROW 4: Back | Home | CueTV Live Channels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _RoundRemoteKeyButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Geri',
                    isDarkMode: isDarkMode,
                    size: 44,
                    iconSize: 20,
                    onTap: () => sendKey(TvKeyCommand.back),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _DarkHomeCircleButton(
                    isDarkMode: isDarkMode,
                    onTap: () => sendKey(TvKeyCommand.home),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _RoundRemoteKeyButton(
                    icon: Icons.live_tv_rounded,
                    tooltip: 'CueTV Ulusal Kanal Stüdyosu',
                    isDarkMode: isDarkMode,
                    size: 44,
                    iconSize: 19,
                    onTap: () => showCueTvChannelStudioSheet(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ROW 5: Volume Rocker | Mute | Channel Rocker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _VerticalRockerPill(
                  isDarkMode: isDarkMode,
                  topIcon: Icons.add_rounded,
                  topTooltip: 'Ses +',
                  onTopTap: () => sendKey(TvKeyCommand.volUp),
                  centerLabel: 'SES',
                  bottomIcon: Icons.remove_rounded,
                  bottomTooltip: 'Ses -',
                  onBottomTap: () => sendKey(TvKeyCommand.volDown),
                ),
                _RoundRemoteKeyButton(
                  key: const Key('remote_mute_button'),
                  icon: isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  tooltip: isMuted ? 'Sesi Aç' : 'Sessize Al',
                  isDarkMode: isDarkMode,
                  isActive: isMuted,
                  size: 42,
                  iconSize: 19,
                  onTap: () => sendKey(TvKeyCommand.mute),
                ),
                _VerticalRockerPill(
                  isDarkMode: isDarkMode,
                  topIcon: Icons.keyboard_arrow_up_rounded,
                  topTooltip: 'Kanal +',
                  onTopTap: () => sendKey(TvKeyCommand.channelUp),
                  centerLabel: 'KNL',
                  bottomIcon: Icons.keyboard_arrow_down_rounded,
                  bottomTooltip: 'Kanal -',
                  onBottomTap: () => sendKey(TvKeyCommand.channelDown),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ROW 6: 2-Button Quick App Launch Dock (YouTube | NETFLIX)
            QuickLaunchAppDock(isDarkMode: isDarkMode),
            const SizedBox(height: 12),

            // ROW 7: Dynamic Bottom Deck (Watch Plan Cards Carousel or Touchpad)
            RemoteBottomDeck(isDarkMode: isDarkMode),
          ],
        ),
      ),
    );
  }

  void _showVoiceControlSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceControlSheet(),
    ).whenComplete(() {
      ref.read(cueDeckProvider.notifier).cancelVoiceCommandSession();
    });
  }

  void _showSettingsModal(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CueDeckSettingsScreen(),
      ),
    );
  }
}

class _TvConnectionIconOnlyIndicator extends ConsumerWidget {
  const _TvConnectionIconOnlyIndicator({
    required this.isDarkMode,
    required this.onTap,
  });

  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(cueDeckProvider.select((s) => s.selectedDevice));
    final isScanning = ref.watch(cueDeckProvider.select((s) => s.isScanning));

    final statusColor = isScanning
        ? const Color(0xFF00B0FF)
        : (device.isOnline ? const Color(0xFF00E676) : const Color(0xFFFFAB00));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 4.5,
          height: 4.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDarkMode ? const Color(0xFF3A3F4D) : const Color(0xFF23272F),
          ),
        ),
        const SizedBox(height: 5),
        Tooltip(
          message: 'TV Bağlantı Durumu',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode
                    ? const Color(0xFF111318)
                    : const Color(0xFFECEDF2),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Icon(
                    Icons.tv_rounded,
                    size: 16,
                    color: isDarkMode
                        ? const Color(0xFFF2F4F8)
                        : const Color(0xFF23272F),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundRemoteKeyButton extends StatelessWidget {
  const _RoundRemoteKeyButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isDarkMode,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
    this.badgeCount = 0,
    this.size = 44,
    this.iconSize = 20,
  });

  final IconData icon;
  final String tooltip;
  final bool isDarkMode;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;
  final int badgeCount;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final resolvedActive = activeColor ?? const Color(0xFFFF5252);
    final fillColor = isActive
        ? resolvedActive.withValues(alpha: isDarkMode ? 0.16 : 0.14)
        : (isDarkMode ? const Color(0xFF111318) : const Color(0xFFECEDF2));
    final borderColor = isActive
        ? resolvedActive
        : (isDarkMode ? const Color(0xFF252832) : const Color(0xFFCFD4DE));
    final iconColor = isActive
        ? resolvedActive
        : (isDarkMode ? const Color(0xFFF2F4F8) : const Color(0xFF23272F));

    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Material(
            color: fillColor,
            shape: CircleBorder(
              side: BorderSide(color: borderColor, width: isActive ? 1.25 : 1.1),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: iconColor, size: iconSize),
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: 2,
              right: 2,
              child: IgnorePointer(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE2A84B),
                    border: Border.all(
                      color: isDarkMode
                          ? const Color(0xFF000000)
                          : const Color(0xFFF5F6F9),
                      width: 1.2,
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

class _AssistantVoiceCenterButton extends ConsumerWidget {
  const _AssistantVoiceCenterButton({
    super.key,
    required this.isDarkMode,
    required this.onTap,
  });

  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isListening = ref.watch(
      cueDeckProvider.select((s) => s.isListeningVoice),
    );

    final circleColor = isListening
        ? const Color(0xFFD50000)
        : (isDarkMode ? const Color(0xFF181B24) : const Color(0xFF1C2026));
    final borderColor = isListening
        ? const Color(0xFFFF5252)
        : (isDarkMode ? const Color(0xFF2E3342) : const Color(0xFF1C2026));

    return Tooltip(
      message: 'Sesli Komut (Asistan)',
      child: Material(
        color: circleColor,
        shape: CircleBorder(
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        elevation: isDarkMode ? 0 : 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Center(
              child: isListening
                  ? const Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 22,
                    )
                  : const _ModernMicrophoneIcon(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernMicrophoneIcon extends StatelessWidget {
  const _ModernMicrophoneIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _ModernMicrophonePainter(),
      ),
    );
  }
}

class _ModernMicrophonePainter extends CustomPainter {
  const _ModernMicrophonePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // 1. Sleek studio microphone capsule with luminous silver-gold vertical sheen
    final capsuleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.36),
        width: 7.4,
        height: 11.4,
      ),
      const Radius.circular(3.7),
    );
    final capsulePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFFDF8EC),
          Color(0xFFE6C17A),
          Color(0xFFC89B4B),
        ],
      ).createShader(capsuleRect.outerRect);
    canvas.drawRRect(capsuleRect, capsulePaint);

    // 2. Subtle acoustic grille slits inside capsule
    final slitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF181B24).withValues(alpha: 0.35);
    canvas.drawLine(
      Offset(cx - 1.6, size.height * 0.28),
      Offset(cx + 1.6, size.height * 0.28),
      slitPaint,
    );
    canvas.drawLine(
      Offset(cx - 1.6, size.height * 0.36),
      Offset(cx + 1.6, size.height * 0.36),
      slitPaint,
    );

    // 3. Clean thin U-cradle arc & minimalist stem base
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF2F4F8);

    final cradleRect = Rect.fromCenter(
      center: Offset(cx, size.height * 0.44),
      width: 13.0,
      height: 11.5,
    );
    canvas.drawArc(cradleRect, 0.15, 2.84, false, framePaint);

    // Vertical stem
    canvas.drawLine(
      Offset(cx, size.height * 0.69),
      Offset(cx, size.height * 0.85),
      framePaint,
    );

    // Base foot
    canvas.drawLine(
      Offset(cx - 3.6, size.height * 0.86),
      Offset(cx + 3.6, size.height * 0.86),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ModernMicrophonePainter oldDelegate) => false;
}

class _DarkHomeCircleButton extends StatelessWidget {
  const _DarkHomeCircleButton({
    required this.isDarkMode,
    required this.onTap,
  });

  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final circleColor =
        isDarkMode ? const Color(0xFF181B24) : const Color(0xFF1C2026);
    final borderColor =
        isDarkMode ? const Color(0xFF2E3342) : const Color(0xFF1C2026);

    return Tooltip(
      message: 'Ana Ekran',
      child: Material(
        color: circleColor,
        shape: CircleBorder(
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        elevation: isDarkMode ? 0 : 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              Icons.home_filled,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalRockerPill extends StatelessWidget {
  const _VerticalRockerPill({
    required this.isDarkMode,
    required this.topIcon,
    required this.topTooltip,
    required this.onTopTap,
    required this.bottomIcon,
    required this.bottomTooltip,
    required this.onBottomTap,
    this.centerLabel,
  });

  final bool isDarkMode;
  final IconData topIcon;
  final String topTooltip;
  final VoidCallback onTopTap;
  final IconData bottomIcon;
  final String bottomTooltip;
  final VoidCallback onBottomTap;
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        isDarkMode ? const Color(0xFF111318) : const Color(0xFFECEDF2);
    final borderColor =
        isDarkMode ? const Color(0xFF252832) : const Color(0xFFCFD4DE);
    final iconColor =
        isDarkMode ? const Color(0xFFF2F4F8) : const Color(0xFF23272F);
    final labelColor =
        isDarkMode ? const Color(0xFF7D8598) : const Color(0xFF6B7280);

    return Container(
      width: 50,
      height: 106,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Tooltip(
              message: topTooltip,
              child: InkWell(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
                onTap: onTopTap,
                child: Center(
                  child: Icon(topIcon, color: iconColor, size: 20),
                ),
              ),
            ),
          ),
          if (centerLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                centerLabel!,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  height: 1.0,
                ),
              ),
            )
          else
            Divider(
              height: 1,
              thickness: 1,
              indent: 12,
              endIndent: 12,
              color: borderColor.withValues(alpha: 0.6),
            ),
          Expanded(
            child: Tooltip(
              message: bottomTooltip,
              child: InkWell(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(25),
                ),
                onTap: onBottomTap,
                child: Center(
                  child: Icon(bottomIcon, color: iconColor, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
