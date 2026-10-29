import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/cue_models.dart';
import '../providers/cuedeck_providers.dart';
import '../services/cue_monetization_service.dart';
import '../services/cue_release_notes_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/google_oauth_sheet.dart';
import '../widgets/tactile_dpad_painter.dart';

/// Main screen for CueDeck: Google TV G10 Reference Physical Remote Control Chassis
/// supporting True Black (`#000000`) Dark Mode and Classic White Light Mode.
/// Automatically presents the "What's New (Yenilikler & Sürüm Notları)" sheet on
/// first launch after an app update.
class CueDeckHomeScreen extends ConsumerStatefulWidget {
  const CueDeckHomeScreen({super.key});

  @override
  ConsumerState<CueDeckHomeScreen> createState() => _CueDeckHomeScreenState();
}

class _CueDeckHomeScreenState extends ConsumerState<CueDeckHomeScreen> {
  static const CueReleaseNotesService _releaseNotesService =
      CueReleaseNotesService();
  bool _checkedStartupReleaseNotes = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowStartupReleaseNotes();
    });
  }

  Future<void> _maybeShowStartupReleaseNotes() async {
    if (_checkedStartupReleaseNotes || !mounted) return;
    _checkedStartupReleaseNotes = true;
    final shouldShow = await _releaseNotesService.shouldShowWhatsNewOnStartup();
    if (!shouldShow || !mounted) return;
    await _releaseNotesService.markCurrentVersionSeen();
    if (!mounted) return;
    final isDarkMode = ref.read(cueDeckProvider).isDarkMode;
    await showCueWhatsNewModal(
      context,
      isDarkMode: isDarkMode,
      initialStartupMode: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF000000) : const Color(0xFFECEEF2),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const ReminderAlertBanner(),
                      G10PhysicalRemoteChassis(isDarkMode: isDarkMode),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _CueNonIntrusiveAdBanner(showQuickRemoveAction: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google TV G10 Reference Remote Control Chassis (exact button geometry & proportions).
class G10PhysicalRemoteChassis extends ConsumerWidget {
  const G10PhysicalRemoteChassis({super.key, required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void sendKey(TvKeyCommand cmd) {
      HapticFeedback.lightImpact();
      ref.read(cueDeckProvider.notifier).sendRemoteKey(cmd);
    }

    final chassisColor =
        isDarkMode ? const Color(0xFF000000) : const Color(0xFFF5F6F9);
    final chassisBorderColor =
        isDarkMode ? const Color(0xFF1E2028) : const Color(0xFFDCDFE6);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 316),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
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
            // ROW 1: Power (Left) | Icon-Only TV Connection Status + Mic Pinhole (Center) | Input (Right)
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
                  onTap: () => _showSettingsAndPlannerModal(context),
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

            // ROW 2: Curved 3-Button Group Above D-Pad (Bookmark/Keyboard | Google Assistant Mic | Settings)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _RoundRemoteKeyButton(
                    icon: Icons.bookmark_border_rounded,
                    tooltip: 'TV Klavye & Kısayol',
                    isDarkMode: isDarkMode,
                    size: 44,
                    iconSize: 20,
                    onTap: () => _showRemoteKeyboardSheet(context),
                  ),
                ),
                _AssistantVoiceCenterButton(
                  isDarkMode: isDarkMode,
                  onTap: () => _showVoiceControlSheet(context),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _RoundRemoteKeyButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Ayarlar & İzleme Planı',
                    isDarkMode: isDarkMode,
                    size: 44,
                    iconSize: 20,
                    onTap: () => _showSettingsAndPlannerModal(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ROW 3: Center Donut D-Pad Ring (Tap + Swipe Gesture Support)
            TactileDpadDialWidget(isDarkMode: isDarkMode),
            const SizedBox(height: 6),

            // ROW 4: Inverted Curved 3-Button Group Below D-Pad (Back | Dark Home Circle | Live TV/Menu)
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
                    tooltip: 'Canlı TV / Menü',
                    isDarkMode: isDarkMode,
                    size: 44,
                    iconSize: 19,
                    onTap: () => sendKey(TvKeyCommand.menu),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ROW 5: Vertical Volume Rocker (+) / (-) | Center Mute | Vertical Channel Rocker (^) / (v)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _VerticalRockerPill(
                  isDarkMode: isDarkMode,
                  topIcon: Icons.add_rounded,
                  topTooltip: 'Ses +',
                  onTopTap: () => sendKey(TvKeyCommand.volUp),
                  bottomIcon: Icons.remove_rounded,
                  bottomTooltip: 'Ses -',
                  onBottomTap: () => sendKey(TvKeyCommand.volDown),
                ),
                _RoundRemoteKeyButton(
                  icon: Icons.volume_off_outlined,
                  tooltip: 'Sessiz',
                  isDarkMode: isDarkMode,
                  size: 42,
                  iconSize: 19,
                  onTap: () => sendKey(TvKeyCommand.mute),
                ),
                _VerticalRockerPill(
                  isDarkMode: isDarkMode,
                  topIcon: Icons.keyboard_arrow_up_rounded,
                  topTooltip: 'Kanal +',
                  onTopTap: () => sendKey(TvKeyCommand.channelUp),
                  bottomIcon: Icons.keyboard_arrow_down_rounded,
                  bottomTooltip: 'Kanal -',
                  onBottomTap: () => sendKey(TvKeyCommand.channelDown),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ROW 6: 2-Column Pill App Launch Buttons (Reference G10 Bottom App Grid)
            QuickLaunchAppDock(isDarkMode: isDarkMode),
          ],
        ),
      ),
    );
  }

  void _showVoiceControlSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VoiceControlSheet(),
    );
  }

  void _showRemoteKeyboardSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RemoteKeyboardSheet(),
    );
  }

  void _showSettingsAndPlannerModal(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CueDeckSettingsScreen(),
      ),
    );
  }
}

/// Icon-only TV connection status indicator in the top center of the remote
/// (with tiny mic pinhole dot + TV icon + live green/amber connection badge, zero text).
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
        // Tiny microphone pinhole dot like on the physical G10 remote
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

/// Circular physical remote key button matching the G10 surface & border styling.
class _RoundRemoteKeyButton extends StatelessWidget {
  const _RoundRemoteKeyButton({
    required this.icon,
    required this.tooltip,
    required this.isDarkMode,
    required this.onTap,
    this.size = 44,
    this.iconSize = 20,
  });

  final IconData icon;
  final String tooltip;
  final bool isDarkMode;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        isDarkMode ? const Color(0xFF111318) : const Color(0xFFECEDF2);
    final borderColor =
        isDarkMode ? const Color(0xFF252832) : const Color(0xFFCFD4DE);
    final iconColor =
        isDarkMode ? const Color(0xFFF2F4F8) : const Color(0xFF23272F);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: fillColor,
        shape: CircleBorder(
          side: BorderSide(color: borderColor, width: 1.1),
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
    );
  }
}

/// Prominent dark circle Google Assistant / Voice Mic button in the top-center arc.
class _AssistantVoiceCenterButton extends ConsumerWidget {
  const _AssistantVoiceCenterButton({
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
                  : const _GoogleAssistantDotsGraphic(),
            ),
          ),
        ),
      ),
    );
  }
}

/// 4-dot iconic Google Assistant cluster graphic matching the G10 reference remote.
class _GoogleAssistantDotsGraphic extends StatelessWidget {
  const _GoogleAssistantDotsGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 22,
      child: Stack(
        children: <Widget>[
          // Large Blue dot (top-left)
          Positioned(
            left: 1,
            top: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF4285F4),
              ),
            ),
          ),
          // Red dot (bottom-left/center)
          Positioned(
            left: 11,
            top: 10,
            child: Container(
              width: 5.5,
              height: 5.5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEA4335),
              ),
            ),
          ),
          // Yellow dot (bottom)
          Positioned(
            left: 11,
            top: 16.5,
            child: Container(
              width: 6.5,
              height: 6.5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFBBC05),
              ),
            ),
          ),
          // Small Green dot (top-right)
          Positioned(
            left: 17.5,
            top: 6,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF34A853),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark filled circular Home button below the D-Pad matching the G10 reference remote.
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

/// Vertical pill rocker for Volume (+ / -) and Channel (^ / v).
class _VerticalRockerPill extends StatelessWidget {
  const _VerticalRockerPill({
    required this.isDarkMode,
    required this.topIcon,
    required this.topTooltip,
    required this.onTopTap,
    required this.bottomIcon,
    required this.bottomTooltip,
    required this.onBottomTap,
  });

  final bool isDarkMode;
  final IconData topIcon;
  final String topTooltip;
  final VoidCallback onTopTap;
  final IconData bottomIcon;
  final String bottomTooltip;
  final VoidCallback onBottomTap;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        isDarkMode ? const Color(0xFF111318) : const Color(0xFFECEDF2);
    final borderColor =
        isDarkMode ? const Color(0xFF252832) : const Color(0xFFCFD4DE);
    final iconColor =
        isDarkMode ? const Color(0xFFF2F4F8) : const Color(0xFF23272F);

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

/// Google TV G10 Reference Donut D-Pad Ring (`204x204`) with both 4-way + OK tap
/// targets and swipe gestures (`onHorizontalDragEnd` / `onVerticalDragEnd`).
class TactileDpadDialWidget extends ConsumerWidget {
  const TactileDpadDialWidget({super.key, this.isDarkMode = true});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDirection = ref.watch(
      cueDeckProvider.select((s) => s.lastPressedDirection),
    );

    void trigger(TvKeyCommand cmd) {
      HapticFeedback.lightImpact();
      ref.read(cueDeckProvider.notifier).sendRemoteKey(cmd);
    }

    return Center(
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final vx = details.primaryVelocity ?? 0;
          if (vx > 120) {
            trigger(TvKeyCommand.right);
          } else if (vx < -120) {
            trigger(TvKeyCommand.left);
          }
        },
        onVerticalDragEnd: (details) {
          final vy = details.primaryVelocity ?? 0;
          if (vy > 120) {
            trigger(TvKeyCommand.down);
          } else if (vy < -120) {
            trigger(TvKeyCommand.up);
          }
        },
        child: SizedBox(
          width: 204,
          height: 204,
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
              // UP tap target
              Positioned(
                top: 4,
                child: Tooltip(
                  message: 'Yukarı',
                  child: InkResponse(
                    key: const Key('dpad_up'),
                    radius: 28,
                    onTap: () => trigger(TvKeyCommand.up),
                    child: const SizedBox(width: 64, height: 50),
                  ),
                ),
              ),
              // DOWN tap target
              Positioned(
                bottom: 4,
                child: Tooltip(
                  message: 'Aşağı',
                  child: InkResponse(
                    key: const Key('dpad_down'),
                    radius: 28,
                    onTap: () => trigger(TvKeyCommand.down),
                    child: const SizedBox(width: 64, height: 50),
                  ),
                ),
              ),
              // LEFT tap target
              Positioned(
                left: 4,
                child: Tooltip(
                  message: 'Sol',
                  child: InkResponse(
                    key: const Key('dpad_left'),
                    radius: 28,
                    onTap: () => trigger(TvKeyCommand.left),
                    child: const SizedBox(width: 50, height: 64),
                  ),
                ),
              ),
              // RIGHT tap target
              Positioned(
                right: 4,
                child: Tooltip(
                  message: 'Sağ',
                  child: InkResponse(
                    key: const Key('dpad_right'),
                    radius: 28,
                    onTap: () => trigger(TvKeyCommand.right),
                    child: const SizedBox(width: 50, height: 64),
                  ),
                ),
              ),
              // CENTER OK flat circle tap target
              Tooltip(
                message: 'Tamam (OK)',
                child: GestureDetector(
                  key: const Key('dpad_ok'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => trigger(TvKeyCommand.ok),
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
    );
  }
}

/// 2-Column Pill App Launch Buttons at the bottom of the G10 remote chassis.
/// Supports 1-tap TV app launch and long-press (or Settings) slot customization.
class QuickLaunchAppDock extends ConsumerWidget {
  const QuickLaunchAppDock({super.key, this.isDarkMode = true});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortcuts = ref.watch(
      cueDeckProvider.select((s) => s.remoteShortcuts),
    );
    final slots = shortcuts.length == 6
        ? shortcuts
        : StreamingPlatform.defaultRemoteShortcuts;

    void launch(StreamingPlatform p) {
      HapticFeedback.mediumImpact();
      ref.read(cueDeckProvider.notifier).launchPlatformApp(p);
    }

    void customizeSlot(int index) {
      HapticFeedback.heavyImpact();
      showRemoteShortcutPickerSheet(context, slotIndex: index);
    }

    Widget buildSlot(int index) {
      final platform = slots[index];
      final isNetflix = platform == StreamingPlatform.netflix;
      return Expanded(
        child: _AppCapsuleButton(
          key: Key('remote_shortcut_slot_$index'),
          platform: platform,
          displayLabel: isNetflix ? 'NETFLIX' : null,
          isDarkMode: isDarkMode,
          showIcon: !isNetflix,
          useBrandTextColor: isNetflix,
          onTap: () => launch(platform),
          onLongPress: () => customizeSlot(index),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            buildSlot(0),
            const SizedBox(width: 10),
            buildSlot(1),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            buildSlot(2),
            const SizedBox(width: 10),
            buildSlot(3),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            buildSlot(4),
            const SizedBox(width: 10),
            buildSlot(5),
          ],
        ),
      ],
    );
  }
}

class _AppCapsuleButton extends StatelessWidget {
  const _AppCapsuleButton({
    super.key,
    required this.platform,
    required this.isDarkMode,
    required this.showIcon,
    required this.onTap,
    this.onLongPress,
    this.displayLabel,
    this.useBrandTextColor = false,
  });

  final StreamingPlatform platform;
  final bool isDarkMode;
  final bool showIcon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? displayLabel;
  final bool useBrandTextColor;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        isDarkMode ? const Color(0xFF111318) : const Color(0xFFECEDF2);
    final borderColor =
        isDarkMode ? const Color(0xFF252832) : const Color(0xFFCFD4DE);
    final textColor = useBrandTextColor
        ? platform.brandColor
        : (isDarkMode ? const Color(0xFFF2F4F8) : const Color(0xFF1F232B));

    return Tooltip(
      message: '${platform.label} (Değiştirmek için basılı tutun)',
      child: Material(
        color: fillColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (showIcon) ...<Widget>[
                  Icon(platform.icon, color: platform.brandColor, size: 15),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    displayLabel ?? platform.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      letterSpacing: useBrandTextColor ? 0.6 : 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Smart notification banner when a scheduled watch item's time is approaching.
class ReminderAlertBanner extends ConsumerWidget {
  const ReminderAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderItem = ref.watch(
      cueDeckProvider.select((s) => s.activeReminderItem),
    );
    if (reminderItem == null) return const SizedBox.shrink();

    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final bannerBg = isDarkMode ? const Color(0xFF141722) : Colors.white;
    final titleColor = isDarkMode ? Colors.white : const Color(0xFF141821);
    final accentText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: bannerBg,
          border: Border.all(
            color: const Color(0xFFE2A84B).withValues(alpha: 0.75),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.notifications_active_rounded,
              color: accentText,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'İzleme Vakti (${reminderItem.formattedClock}) • ${reminderItem.platform.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accentText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${reminderItem.title} — ${reminderItem.checkpointSummary}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE2A84B),
                foregroundColor: const Color(0xFF090A0F),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
              ),
              onPressed: () {
                ref.read(cueDeckProvider.notifier).beamCueToTv(reminderItem);
              },
              child: const Text(
                'TV\'de Aç',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                ref.read(cueDeckProvider.notifier).dismissReminder();
              },
              icon: Icon(
                Icons.close_rounded,
                color: isDarkMode ? Colors.white70 : const Color(0xFF525B6C),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CueDeck brand badge (`assets/images/cuedeck_app_icon.png`) with
/// champagne-gold/obsidian border and vector `_CueDeckBrandEmblem` fallback.
class CueDeckBrandBadge extends StatelessWidget {
  const CueDeckBrandBadge({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0B10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE2A84B).withValues(alpha: 0.65),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          'assets/images/cuedeck_app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _CueDeckBrandEmblem(),
        ),
      ),
    );
  }
}

/// Vector fallback emblem matching `assets/icons/cuedeck_logo.svg`
/// (Obsidian well + Champagne-Gold concentric D-Pad ring + Central Play Prism + Broadcast arcs).
class _CueDeckBrandEmblem extends StatelessWidget {
  const _CueDeckBrandEmblem();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _CueDeckBrandEmblemPainter(),
    );
  }
}

class _CueDeckBrandEmblemPainter extends CustomPainter {
  const _CueDeckBrandEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.54);
    final ringRadius = math.min(size.width, size.height) * 0.30;

    final bgPaint = Paint()..color = const Color(0xFF0A0B10);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final goldGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFFF7EEDB),
        Color(0xFFE2A84B),
        Color(0xFFB86B22),
      ],
    ).createShader(Offset.zero & size);

    // Top wireless broadcast arcs
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = goldGradient;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringRadius + 4),
      -math.pi * 0.72,
      math.pi * 0.44,
      false,
      arcPaint,
    );

    // Concentric gold D-Pad/Clock ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = goldGradient;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Central golden Play/Cue prism
    final playPath = Path()
      ..moveTo(center.dx - ringRadius * 0.28, center.dy - ringRadius * 0.36)
      ..lineTo(center.dx + ringRadius * 0.42, center.dy)
      ..lineTo(center.dx - ringRadius * 0.28, center.dy + ringRadius * 0.36)
      ..close();
    final playPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = goldGradient;
    canvas.drawPath(playPath, playPaint);
  }

  @override
  bool shouldRepaint(covariant _CueDeckBrandEmblemPainter oldDelegate) => false;
}

/// Full-Screen Settings, Theme Switcher, TV Connection Details & Watch Planner Screen
/// opened via the Settings (`⚙️`) button or the Top-Center TV Status Icon.
class CueDeckSettingsScreen extends ConsumerStatefulWidget {
  const CueDeckSettingsScreen({super.key});

  @override
  ConsumerState<CueDeckSettingsScreen> createState() =>
      _CueDeckSettingsScreenState();
}

class _CueDeckSettingsScreenState
    extends ConsumerState<CueDeckSettingsScreen> {
  late final TextEditingController _ipController;
  late final FocusNode _ipFocusNode;

  @override
  void initState() {
    super.initState();
    final currentIp = ref.read(cueDeckProvider).selectedDevice.ip;
    _ipController = TextEditingController(text: currentIp);
    _ipFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _ipFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final device = ref.watch(cueDeckProvider.select((s) => s.selectedDevice));
    final discoveredDevices = ref.watch(
      cueDeckProvider.select((s) => s.discoveredDevices),
    );
    final isScanning = ref.watch(cueDeckProvider.select((s) => s.isScanning));
    final status = ref.watch(
      cueDeckProvider.select((s) => s.lastCommandStatus),
    );
    final cueItems = ref.watch(cueDeckProvider.select((s) => s.cueItems));
    final activePlayingId = ref.watch(
      cueDeckProvider.select((s) => s.activePlayingCueId),
    );
    final localWifiIp = ref.watch(
      cueDeckProvider.select((s) => s.localWifiIp),
    );
    final localNetworkPermissionDenied = ref.watch(
      cueDeckProvider.select((s) => s.localNetworkPermissionDenied),
    );

    if (!_ipFocusNode.hasFocus &&
        _ipController.text.trim() != device.ip &&
        device.ip.isNotEmpty) {
      _ipController.text = device.ip;
    }

    // True Black (#000000) in Dark Mode, Warm Alabaster in Light Mode
    final pageBg = isDarkMode ? Colors.black : const Color(0xFFF3F6FA);
    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final cardBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB07A28);
    final softAccentFill =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFD99B38);
    final inputFill =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFF1F5F9);
    final softMint =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    final softAmber =
        isDarkMode ? const Color(0xFFFCD34D) : const Color(0xFFD97706);
    final bottomSafePadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            children: <Widget>[
              // Minimalist top header bar
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Kumandaya Dön',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 19,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const CueDeckBrandBadge(size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'CueDeck',
                          style: TextStyle(
                            color: goldText,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          'Ayarlar & İzleme Planı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (device.isOnline ? softMint : softAmber)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 6.5,
                          height: 6.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: device.isOnline ? softMint : softAmber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          device.isOnline ? 'Çevrimiçi' : 'Simülasyon',
                          style: TextStyle(
                            color: device.isOnline ? softMint : softAmber,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const ReminderAlertBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bottomSafePadding + 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 1. COMPACT THEME PILL CARD
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  isDarkMode
                                      ? Icons.dark_mode_outlined
                                      : Icons.light_mode_outlined,
                                  color: goldText,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Görünüm Teması',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: primaryText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      showCueWhatsNewModal(
                                        context,
                                        isDarkMode: isDarkMode,
                                        initialStartupMode: false,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: goldText.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: goldText.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '📋 Sürüm Notları (${CueReleaseNotesCatalog.currentShortVersion})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: goldText,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    label: const Text(
                                      'Gerçek Siyah (#000000)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    selected: isDarkMode,
                                    backgroundColor: isDarkMode
                                        ? const Color(0xFF11141E)
                                        : const Color(0xFFF1F5F9),
                                    selectedColor: isDarkMode
                                        ? const Color(0xFF2D2920)
                                        : const Color(0xFFFEF3C7),
                                    checkmarkColor: goldText,
                                    side: BorderSide(
                                      color: isDarkMode
                                          ? goldText.withValues(alpha: 0.55)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                    labelStyle: TextStyle(
                                      color: isDarkMode
                                          ? const Color(0xFFF1F5F9)
                                          : const Color(0xFF2C3342),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                    onSelected: (_) {
                                      ref
                                          .read(cueDeckProvider.notifier)
                                          .setDarkMode(true);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    label: const Text(
                                      'Klasik Beyaz Kumanda',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    selected: !isDarkMode,
                                    backgroundColor: isDarkMode
                                        ? const Color(0xFF11141E)
                                        : const Color(0xFFF1F5F9),
                                    selectedColor: isDarkMode
                                        ? const Color(0xFF2D2920)
                                        : const Color(0xFFFEF3C7),
                                    checkmarkColor: goldText,
                                    side: BorderSide(
                                      color: !isDarkMode
                                          ? goldText.withValues(alpha: 0.65)
                                          : cardBorder,
                                    ),
                                    labelStyle: TextStyle(
                                      color: !isDarkMode
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFCBD5E1),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                    onSelected: (_) {
                                      ref
                                          .read(cueDeckProvider.notifier)
                                          .setDarkMode(false);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. SIMPLIFIED & GUIDED TV CONNECTION CARD
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.tv_rounded,
                                  color: device.isOnline ? softMint : goldText,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    device.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: primaryText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${device.ip}:${device.port}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _openTvSetupGuideSheet(context),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.help_outline_rounded,
                                      size: 17,
                                      color: goldText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isScanning
                                  ? '📡 Ağdaki Android TV ve Google TV cihazları aranıyor...'
                                  : status,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: device.isOnline ? softMint : secondaryText,
                                fontSize: 11.5,
                                fontWeight: device.isOnline
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            if (localWifiIp.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 3),
                              Text(
                                '📱 Telefon Wi-Fi IP: $localWifiIp',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: goldText,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (localNetworkPermissionDenied) ...<Widget>[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3F1518),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFF87171),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Text(
                                      '⚠️ iPhone "Yerel Ağ" İzni Kapalı!',
                                      style: TextStyle(
                                        color: Color(0xFFFCA5A5),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'iOS güvenlik ayarı nedeniyle CueDeck\'in Wi-Fi ağındaki TV\'ye erişimi engelleniyor. Lütfen iPhone Ayarlar > Uygulamalar > CueDeck > Yerel Ağ anahtarını açın.',
                                      style: TextStyle(
                                        color: Color(0xFFFECACA),
                                        fontSize: 10.5,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFF87171),
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(cueDeckProvider.notifier)
                                              .openIosLocalNetworkSettings();
                                        },
                                        icon: const Icon(
                                          Icons.settings_suggest_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          '📲 iPhone Ayarlarında "Yerel Ağ" İznini Aç',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // PROMINENT "AĞDAKİ CİHAZLARI ARA" BUTTON
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const Key('scan_network_devices_button'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: softAccentFill,
                                  foregroundColor: const Color(0xFF0A0C12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: isScanning
                                    ? null
                                    : () {
                                        HapticFeedback.mediumImpact();
                                        final ip = _ipController.text.trim();
                                        ref
                                            .read(cueDeckProvider.notifier)
                                            .scanNetworkForTvs(
                                              customIp:
                                                  ip.isNotEmpty ? ip : null,
                                            );
                                      },
                                icon: Icon(
                                  isScanning
                                      ? Icons.radar_rounded
                                      : Icons.wifi_find_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  isScanning
                                      ? 'Ağdaki Cihazlar Aranıyor...'
                                      : '🔍 Ağdaki Cihazları Ara',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),

                            // DISCOVERED DEVICES CHIPS
                            if (discoveredDevices.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Text(
                                'Ağda Bulunan Cihazlar (Seçmek için dokunun):',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: discoveredDevices.map((d) {
                                  final isSelected = d.ip == device.ip;
                                  return ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      '${d.isOnline ? "🟢" : "⚪"} ${d.name} (${d.ip})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    selected: isSelected,
                                    backgroundColor: inputFill,
                                    selectedColor: isDarkMode
                                        ? const Color(0xFF2D2920)
                                        : const Color(0xFFFEF3C7),
                                    checkmarkColor: goldText,
                                    side: BorderSide(
                                      color: isSelected
                                          ? goldText.withValues(alpha: 0.65)
                                          : cardBorder,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? primaryText
                                          : secondaryText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                    onSelected: (_) {
                                      HapticFeedback.selectionClick();
                                      _ipController.text = d.ip;
                                      ref
                                          .read(cueDeckProvider.notifier)
                                          .selectDevice(d);
                                    },
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 10),

                            // STEP-BY-STEP PAIRING & CONNECTION INSTRUCTIONS BOX
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: goldText.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.tips_and_updates_outlined,
                                        color: goldText,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '3 Adımda Kolay Eşleştirme & Bağlantı',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: goldText,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '1️⃣ Yukarıdan "🔍 Ağdaki Cihazları Ara"ya basın. (iPhone kullanıyorsanız: iPhone Ayarlar > Uygulamalar > CueDeck > Yerel Ağ izninin açık olduğundan emin olun).\n'
                                    '2️⃣ TV\'de Ayarlar > Cihaz Tercihleri > Hakkında > Yapı Numarası (7 kez basın) > Geliştirici Seçenekleri > USB/Ağ Hata Ayıklama (ADB) açın.\n'
                                    '3️⃣ Aşağıdaki "🔐 TV Eşleştir (RSA Onayı)" butonuna basıp TV ekranında çıkan "Her zaman izin ver -> Tamam" onayını kabul edin.',
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 11,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // MANUAL IP INPUT + DIRECT CONNECT
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: _ipController,
                                    focusNode: _ipFocusNode,
                                    style: TextStyle(
                                      color: primaryText,
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'TV IP (192.168.1.x)',
                                      hintStyle: TextStyle(
                                        color: secondaryText,
                                        fontSize: 12,
                                      ),
                                      isDense: true,
                                      filled: true,
                                      fillColor: inputFill,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide:
                                            BorderSide(color: cardBorder),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: goldText,
                                    side: BorderSide(
                                      color: goldText.withValues(alpha: 0.45),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    final ip = _ipController.text.trim();
                                    ref
                                        .read(cueDeckProvider.notifier)
                                        .scanNetworkForTvs(customIp: ip);
                                  },
                                  child: const Text(
                                    'Tara ve Bağlan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: goldText,
                                      backgroundColor:
                                          goldText.withValues(alpha: 0.10),
                                      side: BorderSide(
                                        color: goldText.withValues(alpha: 0.45),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 9,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: isScanning
                                        ? null
                                        : () {
                                            HapticFeedback.mediumImpact();
                                            final ip =
                                                _ipController.text.trim();
                                            ref
                                                .read(cueDeckProvider.notifier)
                                                .pairWithSelectedTv(
                                                  customIp: ip,
                                                );
                                          },
                                    child: const Text(
                                      '🔐 TV Eşleştir (RSA Onayı)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryText,
                                      side: BorderSide(color: cardBorder),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 9,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: isScanning
                                        ? null
                                        : () {
                                            final ip =
                                                _ipController.text.trim();
                                            _openPin6466Dialog(context, ip);
                                          },
                                    child: const Text(
                                      '🔢 PIN Eşleştir (6466)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2.15. CUSTOMIZABLE REMOTE APP BUTTONS CARD (6 SLOTS)
                      const _RemoteShortcutCustomizationCard(),
                      const SizedBox(height: 12),

                      // 2.25. CUEDECK PRO & 24H PASS (COMPACT & SOFT)
                      const _CueDeckProPassAndUpgradeSection(),
                      const SizedBox(height: 12),

                      // 2.5. GOOGLE DRIVE & LOCAL BACKUP SECTION
                      const _GoogleDriveBackupSection(),
                      const SizedBox(height: 14),

                      // 3. WATCH PLANNER & REMINDERS SECTION
                      const WatchPlanMasteryHeader(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'İzleme Planı (${cueItems.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: softAccentFill,
                              foregroundColor: const Color(0xFF141824),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _openAddCueModal(context),
                            icon: const Icon(Icons.add_rounded, size: 17),
                            label: const Text(
                              'Plan Ekle',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final item in cueItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: WatchCueCard(
                            item: item,
                            isPlayingOnTv: item.id == activePlayingId,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Pinned bottom AdMob Banner (always visible in Settings on Free tier, hidden on Pro/24h Pass)
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 8),
                child: _CueNonIntrusiveAdBanner(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddCueModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWatchCueSheet(),
    );
  }

  void _openPin6466Dialog(BuildContext context, String targetIp) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Pin6466PairingSheet(targetIp: targetIp),
    );
  }

  void _openTvSetupGuideSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TvSetupGuideSheet(),
    );
  }
}

/// Opens the bottom sheet to change which streaming app is assigned to [slotIndex] (0..5)
/// on the G10 physical remote chassis.
void showRemoteShortcutPickerSheet(
  BuildContext context, {
  required int slotIndex,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RemoteShortcutPickerSheet(slotIndex: slotIndex),
  );
}

/// Settings card allowing users to customize all 6 app shortcut buttons on the G10 remote.
class _RemoteShortcutCustomizationCard extends ConsumerWidget {
  const _RemoteShortcutCustomizationCard();

  static const List<String> _slotPositionLabels = <String>[
    '1. Sol Üst',
    '2. Sağ Üst',
    '3. Sol Orta',
    '4. Sağ Orta',
    '5. Sol Alt',
    '6. Sağ Alt',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final shortcuts = ref.watch(
      cueDeckProvider.select((s) => s.remoteShortcuts),
    );
    final slots = shortcuts.length == 6
        ? shortcuts
        : StreamingPlatform.defaultRemoteShortcuts;

    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final subSurfaceBg =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);

    Widget buildEditableSlot(int index) {
      final platform = slots[index];
      return Expanded(
        child: InkWell(
          key: Key('settings_shortcut_slot_$index'),
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            showRemoteShortcutPickerSheet(context, slotIndex: index);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: subSurfaceBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: <Widget>[
                Icon(platform.icon, color: platform.brandColor, size: 16),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _slotPositionLabels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        platform.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.swap_horiz_rounded,
                  color: goldText,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.apps_rounded, color: goldText, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kumanda Uygulama Tuşları (6 Yuva)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: goldText,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(cueDeckProvider.notifier)
                      .resetRemoteShortcutsToDefault();
                },
                child: const Text(
                  'Sıfırla',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Değiştirmek istediğiniz tuşa dokunun (veya kumandada tuşa basılı tutun).',
            style: TextStyle(color: secondaryText, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              buildEditableSlot(0),
              const SizedBox(width: 8),
              buildEditableSlot(1),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              buildEditableSlot(2),
              const SizedBox(width: 8),
              buildEditableSlot(3),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              buildEditableSlot(4),
              const SizedBox(width: 8),
              buildEditableSlot(5),
            ],
          ),
        ],
      ),
    );
  }
}

class _RemoteShortcutPickerSheet extends ConsumerWidget {
  const _RemoteShortcutPickerSheet({required this.slotIndex});

  final int slotIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final shortcuts = ref.watch(
      cueDeckProvider.select((s) => s.remoteShortcuts),
    );
    final currentPlatform = (slotIndex >= 0 && slotIndex < shortcuts.length)
        ? shortcuts[slotIndex]
        : StreamingPlatform.youtube;

    final sheetBg =
        isDarkMode ? const Color(0xFF0A0C12) : const Color(0xFFF3F6FA);
    final itemBg = isDarkMode ? const Color(0xFF11141E) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.tune_rounded, color: goldText, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${slotIndex + 1}. Kumanda Tuşunu Değiştir',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: secondaryText),
                  ),
                ],
              ),
              Text(
                'Bu tuşa bastığınızda TV\'de açılacak uygulamayı seçin:',
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: StreamingPlatform.values.map((platform) {
                      final isSelected = platform == currentPlatform;
                      return ChoiceChip(
                        avatar: Icon(
                          platform.icon,
                          color: platform.brandColor,
                          size: 16,
                        ),
                        label: Text(platform.label),
                        selected: isSelected,
                        backgroundColor: itemBg,
                        selectedColor: isDarkMode
                            ? const Color(0xFF2D2920)
                            : const Color(0xFFFEF3C7),
                        checkmarkColor: goldText,
                        side: BorderSide(
                          color: isSelected
                              ? goldText.withValues(alpha: 0.75)
                              : borderColor,
                        ),
                        labelStyle: TextStyle(
                          color: primaryText,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(cueDeckProvider.notifier)
                              .updateRemoteShortcutSlot(slotIndex, platform);
                          Navigator.of(context).pop();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase 1: CueDeck Pro (One-Time Lifetime Purchase) + 24-Hour Rewarded Pro Pass
/// + 10-Day 40% Loyalty Discount Card inside `CueDeckSettingsScreen`.
class _CueDeckProPassAndUpgradeSection extends ConsumerWidget {
  const _CueDeckProPassAndUpgradeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final entitlement = ref.watch(cueDeckProvider.select((s) => s.entitlement));

    final isProLifetime = entitlement.isProLifetime;
    final isPassActive = entitlement.isProPassActive();
    final rewardedDays = entitlement.rewardedDaysCount;
    final isLoyaltyUnlocked = entitlement.isLoyaltyDiscountUnlocked;

    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final mintText =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    final subSurfaceBg =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);

    void showToast(String message) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0A0C12),
            content: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isProLifetime
                    ? Icons.verified_rounded
                    : Icons.workspace_premium_rounded,
                color: isProLifetime ? mintText : goldText,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isProLifetime ? 'CueDeck Pro' : 'CueDeck Pro & 24s Pass',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isProLifetime || isPassActive)
                      ? mintText.withValues(alpha: 0.14)
                      : goldText.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isProLifetime
                      ? 'ÖMÜR BOYU'
                      : (isPassActive
                          ? 'PASS (${entitlement.formattedRemainingProPass()})'
                          : 'ÜCRETSİZ'),
                  style: TextStyle(
                    color: (isProLifetime || isPassActive) ? mintText : goldText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isProLifetime) ...<Widget>[
            Text(
              'Reklamsız kullanım, sınırsız izleme planı ve bulut yedekleme aktif.',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
          ] else ...<Widget>[
            Text(
              'Abonelik yok • Tek seferlik ödeme veya 1 reklamla 24 saat ücretsiz Pro.',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: subSurfaceBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isLoyaltyUnlocked
                        ? '🎉 %40 Sadakat İndirimi Açıldı (${CueProProductCatalog.priceLoyalty40Tr})'
                        : '🎁 Sadakat İndirimi: $rewardedDays/${CueProProductCatalog.loyaltyDiscountTargetDays} Gün (%40 İndirim)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: goldText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: entitlement.loyaltyProgressRatio,
                      minHeight: 4,
                      backgroundColor: isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(goldText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: goldText,
                      foregroundColor: const Color(0xFF0A0C12),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final res = await ref
                          .read(cueDeckProvider.notifier)
                          .purchaseLifetimePro();
                      showToast(res.message);
                    },
                    child: Text(
                      isLoyaltyUnlocked
                          ? '💎 Pro Al (${CueProProductCatalog.priceLoyalty40Tr})'
                          : '💎 Pro Al (${CueProProductCatalog.priceLaunchTr})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryText,
                      side: BorderSide(color: borderColor),
                      backgroundColor: subSurfaceBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      final res = await ref
                          .read(cueDeckProvider.notifier)
                          .unlockProPassWithRewardedAd();
                      showToast(res.message);
                    },
                    child: const Text(
                      '🎬 24 Saat Ücretsiz Aç',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isProLifetime || isPassActive) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: secondaryText,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  final res = await ref
                      .read(cueDeckProvider.notifier)
                      .resetProPassToFree();
                  showToast(res.message);
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 15),
                label: Text(
                  isProLifetime
                      ? 'Ücretsiz Sürüme Dön (Test Pro Sıfırla)'
                      : 'Ücretsiz Sürüme Dön (Pass Sıfırla)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Non-intrusive Adaptive Banner Ad slot pinned at the bottom of `CueDeckHomeScreen`
/// (outside the G10 physical remote chassis border) and `CueDeckSettingsScreen`,
/// automatically hidden when Pro / 24h Pass is active.
/// Renders a real Google AdMob `BannerAd` (`AdWidget`) on Android (Test Unit) and iOS (Prod Unit).
class _CueNonIntrusiveAdBanner extends ConsumerStatefulWidget {
  const _CueNonIntrusiveAdBanner({this.showQuickRemoveAction = false});

  final bool showQuickRemoveAction;

  @override
  ConsumerState<_CueNonIntrusiveAdBanner> createState() =>
      _CueNonIntrusiveAdBannerState();
}

class _CueNonIntrusiveAdBannerState
    extends ConsumerState<_CueNonIntrusiveAdBanner> {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _initAndLoadBanner();
  }

  Future<void> _initAndLoadBanner() async {
    if (!CueAdMobConfig.isNativeMobileAdsSupported) return;
    final monetization = ref.read(cueMonetizationServiceProvider);
    await monetization.ensureAdsInitialized();
    if (!mounted) return;

    final banner = BannerAd(
      adUnitId: CueAdMobConfig.activeBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isBannerLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isBannerLoaded = false;
          });
        },
      ),
    );
    await banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPro = ref.watch(cueDeckProvider.select((s) => s.hasProAccess));
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    if (hasPro) return const SizedBox.shrink();

    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: goldText.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'REKLAM',
                    style: TextStyle(
                      color: goldText,
                      fontWeight: FontWeight.w700,
                      fontSize: 9.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CueDeck Ücretsiz • Reklamsız deneyim için Pro\'ya geçin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                if (widget.showQuickRemoveAction) ...<Widget>[
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      final res = await ref
                          .read(cueDeckProvider.notifier)
                          .unlockProPassWithRewardedAd();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF0A0C12),
                            content: Text(
                              res.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: goldText.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🎬 24s Kaldır',
                        style: TextStyle(
                          color: goldText,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_isBannerLoaded && _bannerAd != null) ...<Widget>[
              const SizedBox(height: 5),
              SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Phase 2: 6-Digit PIN Pairing Sheet for Port 6466/6467 (`Android TV Remote Protocol v2`).
class _Pin6466PairingSheet extends ConsumerStatefulWidget {
  const _Pin6466PairingSheet({required this.targetIp});

  final String targetIp;

  @override
  ConsumerState<_Pin6466PairingSheet> createState() =>
      _Pin6466PairingSheetState();
}

class _Pin6466PairingSheetState extends ConsumerState<_Pin6466PairingSheet> {
  late final TextEditingController _pinController;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg =
        isDarkMode ? const Color(0xFF0A0C12) : const Color(0xFFF3F5F9);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? Colors.white70 : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '🔢 Standart TV PIN Eşleştirme (Port 6466)',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Geliştirici Seçenekleri kapalı olan standart Google TV / Android TV cihazlarında ekranda beliren 6 haneli PIN kodunu girin.',
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              labelText: '6 Haneli TV PIN Kodu (Örn: 123456)',
              labelStyle: TextStyle(color: goldText, fontSize: 12),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE2A84B),
                foregroundColor: const Color(0xFF090A0F),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () async {
                final pin = _pinController.text.trim();
                final nav = Navigator.of(context);
                await ref
                    .read(cueDeckProvider.notifier)
                    .pairWithSelectedTvPin6466(pin, customIp: widget.targetIp);
                if (mounted) nav.pop();
              },
              child: const Text(
                'PIN ile Eşleştir ve Bağlan',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phase 2: Step-by-Step Visual TV Setup Guide Sheet explaining Mode 1 (Port 6466 Zero-Config)
/// vs. Mode 2 (Port 5555 ADB Turbo & YouTube Playlist Instant Beam).
class _TvSetupGuideSheet extends ConsumerWidget {
  const _TvSetupGuideSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final sheetBg =
        isDarkMode ? const Color(0xFF0A0C12) : const Color(0xFFF3F5F9);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? Colors.white70 : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '📖 Adım Adım TV Eşleştirme & Bağlantı Rehberi',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '1️⃣ ADB Turbo & Tek Dokunuşla Uygulama Açma Modu (Önerilen):',
            style: TextStyle(
              color: goldText,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• Adım 1: Telefon ve TV aynı Wi-Fi ağında olsun. iPhone kullanıyorsanız Ayarlar > Uygulamalar > CueDeck > Yerel Ağ izninin açık olduğundan emin olun.\n'
            '• Adım 2: TV\'de Ayarlar > Cihaz Tercihleri > Hakkında > Yapı Numarası üzerine 7 kez basın.\n'
            '• Adım 3: TV\'de Geliştirici Seçenekleri > USB / Kablosuz Ağ Hata Ayıklama (ADB) seçeneğini açın.\n'
            '• Adım 4: CueDeck\'te "🔍 Ağdaki Cihazları Ara"ya basıp TV\'nizi seçin, ardından "🔐 TV Eşleştir" butonuna basıp TV ekranında çıkan "Her zaman izin ver -> Tamam" onayını kabul edin.',
            style: TextStyle(color: secondaryText, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            '2️⃣ Standart Kumanda Modu (Port 6466 • 6 Haneli PIN):',
            style: TextStyle(
              color: goldText,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• Geliştirici Seçenekleri olmayan standart Google TV cihazlarında "🔢 PIN Eşleştir (6466)" butonuna basıp TV ekranında beliren 6 haneli kodu girmeniz yeterlidir.',
            style: TextStyle(color: secondaryText, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Google Drive Cloud Backup, Multi-Device Sync & Local (.json) Backup Card
/// inside `CueDeckSettingsScreen` (120 FPS isolated selects).
class _GoogleDriveBackupSection extends ConsumerWidget {
  const _GoogleDriveBackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final isSignedIn = ref.watch(
      cueDeckProvider.select((s) => s.isGoogleSignedIn),
    );
    final userEmail = ref.watch(
      cueDeckProvider.select((s) => s.googleUserEmail),
    );
    final userName = ref.watch(
      cueDeckProvider.select((s) => s.googleUserName),
    );
    final lastBackupFormatted = ref.watch(
      cueDeckProvider.select((s) => s.lastBackupTimeFormatted),
    );
    final isAutoEnabled = ref.watch(
      cueDeckProvider.select((s) => s.isAutoCloudBackupEnabled),
    );
    final isProcessing = ref.watch(
      cueDeckProvider.select((s) => s.isProcessingBackup),
    );

    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final mintText =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    final subSurfaceBg =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFF8FAFC);
    final buttonBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);

    void showMessage(String msg) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0A0C12),
            content: Text(
              msg,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              Icon(
                isSignedIn
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_upload_rounded,
                color: isSignedIn ? mintText : goldText,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bulut & Yerel Yedekleme',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isProcessing)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: goldText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // STATE A: Not signed in to Google Drive
          if (!isSignedIn) ...<Widget>[
            Text(
              'Planlarınızı Google Drive veya yerel dosyaya yedekleyin.',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: goldText,
                  foregroundColor: const Color(0xFF141824),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        final ok = await GoogleOAuthSheet.startOAuth(context);
                        if (!context.mounted) return;
                        if (ok) {
                          final notifier = ref.read(cueDeckProvider.notifier);
                          await notifier.refreshGoogleDriveStatus();
                          final syncRes =
                              await notifier.syncDevicesWithCloud();
                          showMessage(syncRes.message);
                        }
                      },
                child: const Text(
                  '🔑 Google Hesabını Bağla',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ),
          ] else ...<Widget>[
            // STATE B: Signed in to Google Drive (Consolidated clean container)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: subSurfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mintText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userEmail.isNotEmpty
                              ? '${userName.isNotEmpty ? userName : "Google Drive"} ($userEmail)'
                              : (userName.isNotEmpty
                                  ? userName
                                  : 'Google Drive Bağlı'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Google Hesabından Çıkış Yap',
                        visualDensity: VisualDensity.compact,
                        onPressed: isProcessing
                            ? null
                            : () async {
                                final res = await ref
                                    .read(cueDeckProvider.notifier)
                                    .signOutGoogleDrive();
                                showMessage(res.message);
                              },
                        icon: Icon(
                          Icons.close_rounded,
                          color: secondaryText,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Otomatik yedekleme • Son: $lastBackupFormatted',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.82,
                        child: Switch(
                          value: isAutoEnabled,
                          activeThumbColor: mintText,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: isProcessing
                              ? null
                              : (val) {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(cueDeckProvider.notifier)
                                      .toggleAutoCloudBackup(val);
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Side-by-side Cloud Sync / Backup / Restore buttons
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: mintText,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () async {
                            HapticFeedback.mediumImpact();
                            final res = await ref
                                .read(cueDeckProvider.notifier)
                                .syncDevicesWithCloud();
                            showMessage(res.message);
                          },
                    child: const Text(
                      '🔄 Eşitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldText,
                      side: BorderSide(color: buttonBorder),
                      backgroundColor: subSurfaceBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () async {
                            HapticFeedback.mediumImpact();
                            final res = await ref
                                .read(cueDeckProvider.notifier)
                                .backupNowToCloud();
                            showMessage(res.message);
                          },
                    child: const Text(
                      '☁️ Yedekle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryText,
                      side: BorderSide(color: buttonBorder),
                      backgroundColor: subSurfaceBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () async {
                            HapticFeedback.selectionClick();
                            final notifier =
                                ref.read(cueDeckProvider.notifier);
                            final backups =
                                await notifier.fetchAvailableBackups();
                            if (!context.mounted) return;
                            if (backups.isEmpty) {
                              showMessage(
                                'Bulutta veya cihazda kayıtlı yedek bulunamadı.',
                              );
                              return;
                            }
                            _showCloudBackupPickerSheet(
                              context,
                              ref,
                              backups,
                              showMessage,
                            );
                          },
                    child: const Text(
                      '☁️ Yükle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // Always-visible Local Backup (.json) buttons
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(color: buttonBorder),
                    backgroundColor: subSurfaceBg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          HapticFeedback.selectionClick();
                          final res = await ref
                              .read(cueDeckProvider.notifier)
                              .exportLocalBackupFile();
                          showMessage(res.message);
                        },
                  child: const Text(
                    '💾 Dosyaya Yedekle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(color: buttonBorder),
                    backgroundColor: subSurfaceBg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          HapticFeedback.selectionClick();
                          final res = await ref
                              .read(cueDeckProvider.notifier)
                              .importLocalBackupFile();
                          showMessage(res.message);
                        },
                  child: const Text(
                    '📂 Dosyadan Yükle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCloudBackupPickerSheet(
    BuildContext context,
    WidgetRef ref,
    List<CloudBackupInfo> backups,
    void Function(String) showMessage,
  ) {
    final isDarkMode = ref.read(cueDeckProvider).isDarkMode;
    final sheetBg =
        isDarkMode ? const Color(0xFF10131C) : const Color(0xFFF3F5F9);
    final itemBg = isDarkMode ? const Color(0xFF161A26) : Colors.white;
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText = isDarkMode
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '☁️ Bulut Yedeği Seçin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: backups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = backups[index];
                        final isNewest = index == 0;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            Navigator.of(sheetCtx).pop();
                            final res = await ref
                                .read(cueDeckProvider.notifier)
                                .restoreFromBackup(fileId: item.fileId);
                            showMessage(res.message);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: itemBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isNewest
                                    ? const Color(0xFFE2A84B)
                                        .withValues(alpha: 0.65)
                                    : (isDarkMode
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : const Color(0xFFD8DEE8)),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  item.isLocal ? '💾' : '☁️',
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Flexible(
                                            child: Text(
                                              item.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: primaryText,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          if (isNewest) ...<Widget>[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE2A84B)
                                                    .withValues(alpha: 0.22),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '⭐ EN YENİ',
                                                style: TextStyle(
                                                  color: goldText,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 9.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '📅 ${item.formattedDate} • 📱 ${item.deviceName}'
                                        '${item.planCount != null ? ' • 🎬 Plan: ${item.planCount}' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: secondaryText,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.download_rounded,
                                  color: goldText,
                                  size: 18,
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
            ),
          ),
        );
      },
    );
  }
}

/// Microphone & Voice Command Bottom Sheet with phone mic trigger,
/// native TV Voice Assistant trigger, quick voice command chips, and manual voice input.
class _VoiceControlSheet extends ConsumerStatefulWidget {
  const _VoiceControlSheet();

  @override
  ConsumerState<_VoiceControlSheet> createState() => _VoiceControlSheetState();
}

class _VoiceControlSheetState extends ConsumerState<_VoiceControlSheet> {
  static const List<String> _quickVoicePrompts = <String>[
    'Sesi Aç',
    'Sesi Kıs',
    'Sessize Al',
    'beIN CONNECT Aç',
    'tabii Aç',
    'YouTube\'da Haberler',
    'Ana Ekran',
  ];

  late final TextEditingController _voiceInputController;
  late final FocusNode _voiceInputFocusNode;

  @override
  void initState() {
    super.initState();
    _voiceInputController = TextEditingController();
    _voiceInputFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _voiceInputController.dispose();
    _voiceInputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final isListening = ref.watch(
      cueDeckProvider.select((s) => s.isListeningVoice),
    );
    final lastTranscript = ref.watch(
      cueDeckProvider.select((s) => s.lastVoiceTranscript),
    );
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final sheetBg =
        isDarkMode ? const Color(0xFF0E1017) : const Color(0xFFF3F5F9);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText = isDarkMode
        ? Colors.white.withValues(alpha: 0.58)
        : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);
    final subSurfaceBg = isDarkMode ? const Color(0xFF090A0F) : Colors.white;
    final chipBg = isDarkMode ? const Color(0xFF1A1E2D) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.mic_external_on_rounded,
                  color: goldText,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sesli Komut & Akıllı TV Arama',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldText,
                    side: BorderSide(
                      color: const Color(0xFFE2A84B).withValues(alpha: 0.55),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(cueDeckProvider.notifier)
                        .triggerTvNativeVoiceAssistant();
                  },
                  icon: const Icon(Icons.assistant_rounded, size: 15),
                  label: const Text(
                    'TV Asistanını Aç',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isListening
                      ? const Color(0xFFFF5252)
                      : const Color(0xFFE2A84B),
                  foregroundColor:
                      isListening ? Colors.white : const Color(0xFF090A0F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.read(cueDeckProvider.notifier).startVoiceCommandSession();
                },
                icon: Icon(
                  isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  size: 22,
                ),
                label: Text(
                  isListening
                      ? 'Dinleniyor... TV komutu veya aranacak içeriği söyleyin'
                      : 'Telefon Mikrofonuyla Konuş',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            if (lastTranscript.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: subSurfaceBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE2A84B).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.record_voice_over_rounded,
                      color: goldText,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Son Algılanan: "$lastTranscript"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'HIZLI SESLİ KOMUTLAR (TEK DOKUNUŞ)',
              style: TextStyle(
                color: secondaryText,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickVoicePrompts.map((prompt) {
                return ActionChip(
                  backgroundColor: chipBg,
                  side: BorderSide(
                    color: const Color(0xFFE2A84B).withValues(alpha: 0.45),
                  ),
                  label: Text(
                    prompt,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(cueDeckProvider.notifier)
                        .runVoiceTranscript(prompt);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _voiceInputController,
                    focusNode: _voiceInputFocusNode,
                    style: TextStyle(color: primaryText, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Sesli komut veya arama metni yazın...',
                      hintStyle: TextStyle(
                        color: secondaryText,
                        fontSize: 12.5,
                      ),
                      filled: true,
                      fillColor: subSurfaceBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: _submitCustomTranscript,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE2A84B),
                    foregroundColor: const Color(0xFF090A0F),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () =>
                      _submitCustomTranscript(_voiceInputController.text),
                  child: const Text(
                    'Çalıştır',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submitCustomTranscript(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    ref.read(cueDeckProvider.notifier).runVoiceTranscript(text);
    _voiceInputController.clear();
  }
}

class _RemoteKeyboardSheet extends ConsumerStatefulWidget {
  const _RemoteKeyboardSheet();

  @override
  ConsumerState<_RemoteKeyboardSheet> createState() =>
      _RemoteKeyboardSheetState();
}

class _RemoteKeyboardSheetState extends ConsumerState<_RemoteKeyboardSheet> {
  late final TextEditingController _textController;
  late final FocusNode _textFocusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg =
        isDarkMode ? const Color(0xFF0E1017) : const Color(0xFFF3F5F9);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText = isDarkMode
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF525B6C);
    final inputFill = isDarkMode ? const Color(0xFF090A0F) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TV Arama & Giriş Alanına Metin Gönder',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _textFocusNode,
                  autofocus: true,
                  style: TextStyle(color: primaryText),
                  decoration: InputDecoration(
                    hintText: 'YouTube, tabii veya beIN arama metni...',
                    hintStyle: TextStyle(color: secondaryText),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE2A84B),
                  foregroundColor: const Color(0xFF090A0F),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
                onPressed: () {
                  final text = _textController.text.trim();
                  if (text.isNotEmpty) {
                    ref.read(cueDeckProvider.notifier).sendKeyboardText(text);
                  }
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Gönder',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Overall Watch Plan completion mastery ring + watched/total minutes metrics.
class WatchPlanMasteryHeader extends ConsumerWidget {
  const WatchPlanMasteryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final overallPercent = ref.watch(
      cueDeckProvider.select((s) => s.overallCompletionPercent),
    );
    final watchedMins = ref.watch(
      cueDeckProvider.select((s) => s.totalWatchedMinutes),
    );
    final totalMins = ref.watch(
      cueDeckProvider.select((s) => s.totalPlannedMinutes),
    );
    final completedCount = ref.watch(
      cueDeckProvider.select((s) => s.completedCount),
    );
    final totalCount = ref.watch(
      cueDeckProvider.select((s) => s.cueItems.length),
    );

    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDarkMode ? const Color(0xFF0A0C12) : Colors.white,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: CircularProgressRingPainter(
                      progress: overallPercent / 100.0,
                      primaryColor: const Color(0xFFE6C17A),
                      secondaryColor: const Color(0xFF818CF8),
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ),
                Text(
                  '%$overallPercent',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'GÜNLÜK İZLEME PLANI TAMAMLAMA',
                  style: TextStyle(
                    color: goldText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$watchedMins / $totalMins dakika izlendi',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$completedCount / $totalCount içerik tamamlandı',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Detailed card for each scheduled watch item with recurrence/session badge,
/// YouTube Playlist & deep-link status badges, progress slider, +Seans/+10m/+1Unit,
/// Edit modal trigger, reminder test trigger, and 1-tap "TV'de Başlat".
class WatchCueCard extends ConsumerWidget {
  const WatchCueCard({
    super.key,
    required this.item,
    required this.isPlayingOnTv,
  });

  final WatchCueItem item;
  final bool isPlayingOnTv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final brandColor = item.platform.brandColor;
    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final mintText =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    final subSurfaceBg =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFF8FAFC);
    final buttonBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final borderColor = isPlayingOnTv
        ? goldText.withValues(alpha: 0.50)
        : (isDarkMode
            ? Colors.white.withValues(alpha: 0.09)
            : const Color(0xFFE2E8F0));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: isPlayingOnTv ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: isDarkMode ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(item.platform.icon, color: brandColor, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      item.platform.label,
                      style: TextStyle(
                        color: brandColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: subSurfaceBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.scheduleBadgeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '%${item.progressPercent}',
                style: TextStyle(
                  color: goldText,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          if (item.isYoutubePlaylist || item.deepLinkUrl.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                if (item.isYoutubePlaylist)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: subSurfaceBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: buttonBorder),
                    ),
                    child: Text(
                      'YouTube Playlist (${item.totalEpisodes} Video)',
                      style: TextStyle(
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                if (item.deepLinkUrl.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: mintText.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Bağlantı Aktif',
                      style: TextStyle(
                        color: mintText,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            item.title,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.checkpointSummary,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
              activeTrackColor: brandColor.withValues(alpha: 0.85),
              inactiveTrackColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
              thumbColor: goldText,
            ),
            child: Slider(
              value: item.watchedMinutes.toDouble().clamp(
                    0,
                    item.totalMinutes.toDouble(),
                  ),
              max: item.totalMinutes.toDouble(),
              onChanged: (val) {
                ref.read(cueDeckProvider.notifier).updateProgress(
                      item.id,
                      watchedMinutes: val.round(),
                    );
              },
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: goldText,
                  side: BorderSide(color: buttonBorder),
                  backgroundColor: subSurfaceBg,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref
                      .read(cueDeckProvider.notifier)
                      .completeSessionStep(item.id);
                },
                child: Text(
                  '+Seans (${item.sessionMinutes}dk)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryText,
                  side: BorderSide(color: buttonBorder),
                  backgroundColor: subSurfaceBg,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref.read(cueDeckProvider.notifier).stepProgress(item.id, 10);
                },
                child: const Text('+10 dk', style: TextStyle(fontSize: 11)),
              ),
              if (item.totalEpisodes > 1)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(color: buttonBorder),
                    backgroundColor: subSurfaceBg,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    ref.read(cueDeckProvider.notifier).updateProgress(
                          item.id,
                          currentEpisode: item.currentEpisode + 1,
                        );
                  },
                  child: Text(
                    '+1 ${item.platform.unitLabel}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Planı Düzenle',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _openEditCueModal(context, item),
                icon: Icon(
                  Icons.edit_outlined,
                  color: secondaryText,
                  size: 17,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Hatırlatma Bildirimini Test Et',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref.read(cueDeckProvider.notifier).triggerTestReminder(item);
                },
                icon: Icon(
                  Icons.notifications_active_outlined,
                  color: goldText,
                  size: 17,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Planı Sil',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref.read(cueDeckProvider.notifier).deleteWatchCue(item.id);
                },
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: secondaryText,
                  size: 17,
                ),
              ),
              const Spacer(),
              Flexible(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(cueDeckProvider.notifier).beamCueToTv(item);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 15),
                  label: const Text(
                    'TV\'de Başlat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openEditCueModal(BuildContext context, WatchCueItem existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddWatchCueSheet(existingItem: existing),
    );
  }
}

/// Advanced Bottom Sheet form for adding or editing a scheduled watch plan item
/// with YouTube Playlist / deep-link support, clipboard paste, recurrence period,
/// weekday selector, exact clock time, session duration, and multi-video/episode tracking.
class AddWatchCueSheet extends ConsumerStatefulWidget {
  const AddWatchCueSheet({super.key, this.existingItem});

  final WatchCueItem? existingItem;

  @override
  ConsumerState<AddWatchCueSheet> createState() => _AddWatchCueSheetState();
}

class _AddWatchCueSheetState extends ConsumerState<AddWatchCueSheet> {
  static const List<String> _quickClockPresets = <String>[
    '20:00',
    '21:00',
    '21:30',
    '22:30',
  ];

  static const List<int> _sessionDurationPresets = <int>[30, 45, 60, 90];
  static const List<int> _reminderLeadPresets = <int>[5, 10, 15, 30];

  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _urlController;
  late final TextEditingController _durationController;
  late final TextEditingController _sessionDurationController;
  late final TextEditingController _currentEpisodeController;
  late final TextEditingController _totalEpisodesController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _urlFocusNode;

  late StreamingPlatform _selectedPlatform;
  late WatchRecurrence _selectedRecurrence;
  late List<int> _selectedWeekdays;
  late int _selectedHour;
  late int _selectedMinute;
  late int _selectedReminderMinutes;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    final defaultTime =
        existing?.scheduledTime ?? DateTime.now().add(const Duration(minutes: 30));

    _selectedPlatform = existing?.platform ?? StreamingPlatform.youtube;
    _selectedRecurrence = existing?.recurrence ?? WatchRecurrence.daily;
    _selectedWeekdays = existing != null
        ? List<int>.from(existing.activeWeekdays)
        : List<int>.from(_selectedRecurrence.defaultDays);
    _selectedHour = defaultTime.hour;
    _selectedMinute = defaultTime.minute;
    _selectedReminderMinutes = existing?.reminderMinutesBefore ?? 15;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _subtitleController = TextEditingController(
      text: existing?.subtitle ?? 'Oynatma Listesi • Kaldığın Yerden Devam',
    );
    _urlController = TextEditingController(text: existing?.deepLinkUrl ?? '');
    _durationController = TextEditingController(
      text: (existing?.totalMinutes ?? 180).toString(),
    );
    _sessionDurationController = TextEditingController(
      text: (existing?.sessionMinutes ?? 45).toString(),
    );
    _currentEpisodeController = TextEditingController(
      text: (existing?.currentEpisode ?? 1).toString(),
    );
    _totalEpisodesController = TextEditingController(
      text: (existing?.totalEpisodes ?? 8).toString(),
    );
    _titleFocusNode = FocusNode();
    _urlFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _urlController.dispose();
    _durationController.dispose();
    _sessionDurationController.dispose();
    _currentEpisodeController.dispose();
    _totalEpisodesController.dispose();
    _titleFocusNode.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  String get _formattedSelectedClock {
    final h = _selectedHour.toString().padLeft(2, '0');
    final m = _selectedMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool get _isYoutubePlaylistDetected {
    if (_selectedPlatform != StreamingPlatform.youtube) return false;
    final raw = _urlController.text.trim();
    if (raw.isEmpty) return false;
    final normalized = WatchCueItem.normalizeContentLink(_selectedPlatform, raw);
    return normalized.contains('list=') ||
        RegExp(r'^(PL|UU|FL|RD|OL)[a-zA-Z0-9_-]{8,}$').hasMatch(raw);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existingItem != null;
    final unit = _selectedPlatform.unitLabel;
    final normalizedUrl = WatchCueItem.normalizeContentLink(
      _selectedPlatform,
      _urlController.text,
    );

    final sheetBg =
        isDarkMode ? const Color(0xFF141722) : const Color(0xFFF3F5F9);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? Colors.white70 : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);
    final subSurfaceBg = isDarkMode ? const Color(0xFF0E1018) : Colors.white;
    final chipBg =
        isDarkMode ? const Color(0xFF1A1E2D) : const Color(0xFFEDEFF5);
    final chipSelectedBg =
        isDarkMode ? const Color(0xFF3A2E1B) : const Color(0xFFF9E6C0);
    final subtleBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFCFD6E2);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    isEditing
                        ? 'İzleme Planını Düzenle'
                        : 'Yeni Kişisel İzleme Planı Ekle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 1. Platform Selector
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: StreamingPlatform.values.map((p) {
                final selected = p == _selectedPlatform;
                return ChoiceChip(
                  label: Text(p.label),
                  selected: selected,
                  backgroundColor: chipBg,
                  selectedColor:
                      p.brandColor.withValues(alpha: isDarkMode ? 0.35 : 0.22),
                  checkmarkColor: isDarkMode ? Colors.white : p.brandColor,
                  side: BorderSide(
                    color: selected ? p.brandColor : subtleBorder,
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? (isDarkMode ? Colors.white : const Color(0xFF141821))
                        : secondaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                  onSelected: (_) => setState(() => _selectedPlatform = p),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // 2. Title Field with dynamic platform hint
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              style: TextStyle(color: primaryText, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'İçerik / Oynatma Listesi Adı',
                labelStyle: TextStyle(color: secondaryText),
                hintText: _selectedPlatform.titleHint,
                hintStyle: TextStyle(color: secondaryText),
                filled: !isDarkMode,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            // 3. YouTube Playlist / Content Link Field + Paste Button + Smart Detection Badge
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    style: TextStyle(color: primaryText, fontSize: 12.5),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _selectedPlatform == StreamingPlatform.youtube
                          ? 'YouTube Playlist / Video Linki'
                          : '${_selectedPlatform.label} İçerik Linki (Opsiyonel)',
                      labelStyle: TextStyle(color: secondaryText),
                      hintText: _selectedPlatform.linkHint,
                      hintStyle: TextStyle(color: secondaryText),
                      filled: !isDarkMode,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldText,
                    side: BorderSide(
                      color: const Color(0xFFE2A84B).withValues(alpha: 0.55),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded, size: 15),
                  label: const Text(
                    'Yapıştır',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isYoutubePlaylistDetected
                    ? const Color(0xFF00C853).withValues(alpha: 0.14)
                    : subSurfaceBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isYoutubePlaylistDetected
                      ? const Color(0xFF00C853).withValues(alpha: 0.45)
                      : subtleBorder,
                ),
              ),
              child: Text(
                _isYoutubePlaylistDetected
                    ? '✓ YouTube Oynatma Listesi (Playlist) algılandı — TV\'de doğrudan liste açılacak'
                    : (normalizedUrl.isNotEmpty
                        ? '✓ Doğrudan içerik bağlantısı aktif'
                        : '⚡ TV\'de uygulama/arama ile doğrudan başlatılacak'),
                style: TextStyle(
                  color: _isYoutubePlaylistDetected
                      ? (isDarkMode
                          ? const Color(0xFF00E676)
                          : const Color(0xFF008E3B))
                      : secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 4. Watch Recurrence Period & Weekday Selector
            Text(
              'İzleme Periyodu & Günler',
              style: TextStyle(
                color: goldText,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: WatchRecurrence.values.map((r) {
                final selected = r == _selectedRecurrence;
                return ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(r.label),
                  selected: selected,
                  backgroundColor: chipBg,
                  selectedColor: chipSelectedBg,
                  checkmarkColor: goldText,
                  side: BorderSide(
                    color: selected ? const Color(0xFFE2A84B) : subtleBorder,
                  ),
                  labelStyle: TextStyle(
                    color: selected ? primaryText : secondaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedRecurrence = r;
                      _selectedWeekdays = List<int>.from(r.defaultDays);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: List<Widget>.generate(7, (index) {
                final dayNum = index + 1;
                final dayLabel = WatchCueItem.weekdayShortLabels[index];
                final isDayActive = _selectedWeekdays.contains(dayNum);
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      if (isDayActive && _selectedWeekdays.length > 1) {
                        _selectedWeekdays.remove(dayNum);
                      } else if (!isDayActive) {
                        _selectedWeekdays.add(dayNum);
                      }
                      _selectedRecurrence = WatchRecurrence.customDays;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDayActive ? chipSelectedBg : subSurfaceBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDayActive
                            ? const Color(0xFFE2A84B)
                            : subtleBorder,
                      ),
                    ),
                    child: Text(
                      dayLabel,
                      style: TextStyle(
                        color: isDayActive ? goldText : secondaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // 5. Clock Time Picker + Quick Time Chips
            Text(
              'Planlanan Saat',
              style: TextStyle(
                color: goldText,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldText,
                    side: const BorderSide(color: Color(0xFFE2A84B)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  onPressed: _pickClockTime,
                  icon: const Icon(Icons.access_time_filled_rounded, size: 16),
                  label: Text(
                    '⏰ $_formattedSelectedClock',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                for (final preset in _quickClockPresets)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: _formattedSelectedClock == preset
                        ? chipSelectedBg
                        : subSurfaceBg,
                    side: BorderSide(
                      color: _formattedSelectedClock == preset
                          ? const Color(0xFFE2A84B)
                          : subtleBorder,
                    ),
                    label: Text(
                      preset,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      final parts = preset.split(':');
                      setState(() {
                        _selectedHour = int.parse(parts[0]);
                        _selectedMinute = int.parse(parts[1]);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 6. Session Duration, Total Duration & Video/Episode Counters
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'Seans Hızlı Seçim:',
                  style: TextStyle(color: secondaryText, fontSize: 11.5),
                ),
                for (final mins in _sessionDurationPresets)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        _sessionDurationController.text.trim() == '$mins'
                            ? chipSelectedBg
                            : subSurfaceBg,
                    side: BorderSide(
                      color: _sessionDurationController.text.trim() == '$mins'
                          ? const Color(0xFFE2A84B)
                          : subtleBorder,
                    ),
                    label: Text(
                      '$mins dk',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _sessionDurationController.text = '$mins';
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _sessionDurationController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: primaryText, fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Seans Süresi (Dk)',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: !isDarkMode,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: primaryText, fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Toplam Süre (Dk)',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: !isDarkMode,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _currentEpisodeController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: primaryText, fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Kaçıncı $unit',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: !isDarkMode,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _totalEpisodesController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: primaryText, fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Toplam $unit Sayısı',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: !isDarkMode,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subtitleController,
              style: TextStyle(color: primaryText, fontSize: 12.5),
              decoration: InputDecoration(
                labelText: 'Bölüm / Liste Notu',
                labelStyle: TextStyle(color: secondaryText),
                filled: !isDarkMode,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // 7. Reminder Lead Time & Save Action
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'Hatırlatıcı:',
                  style: TextStyle(color: secondaryText, fontSize: 11.5),
                ),
                for (final rem in _reminderLeadPresets)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('$rem dk önce'),
                    selected: _selectedReminderMinutes == rem,
                    backgroundColor: chipBg,
                    selectedColor: chipSelectedBg,
                    checkmarkColor: goldText,
                    side: BorderSide(
                      color: _selectedReminderMinutes == rem
                          ? const Color(0xFFE2A84B)
                          : subtleBorder,
                    ),
                    labelStyle: TextStyle(
                      color: _selectedReminderMinutes == rem
                          ? primaryText
                          : secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedReminderMinutes = rem);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE2A84B),
                  foregroundColor: const Color(0xFF090A0F),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _saveCue,
                icon: Icon(
                  isEditing ? Icons.save_rounded : Icons.add_task_rounded,
                  size: 18,
                ),
                label: Text(
                  isEditing ? 'Değişiklikleri Kaydet' : 'Plana Ekle',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text?.trim() ?? '';
    if (pasted.isEmpty || !mounted) return;
    setState(() {
      _urlController.text = pasted;
    });
  }

  Future<void> _pickClockTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedHour = picked.hour;
      _selectedMinute = picked.minute;
    });
  }

  void _saveCue() {
    final existing = widget.existingItem;
    final title = _titleController.text.trim().isEmpty
        ? '${_selectedPlatform.label} İzleme Planı'
        : _titleController.text.trim();
    final totalMins =
        (int.tryParse(_durationController.text.trim()) ?? 60).clamp(5, 1200);
    final sessionMins =
        (int.tryParse(_sessionDurationController.text.trim()) ?? 45)
            .clamp(5, totalMins);
    final totalEps =
        (int.tryParse(_totalEpisodesController.text.trim()) ?? 1).clamp(1, 500);
    final currentEp =
        (int.tryParse(_currentEpisodeController.text.trim()) ?? 1)
            .clamp(1, totalEps);
    final normalizedLink = WatchCueItem.normalizeContentLink(
      _selectedPlatform,
      _urlController.text,
    );

    final now = DateTime.now();
    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedHour,
      _selectedMinute,
    );

    final item = WatchCueItem(
      id: existing?.id ?? 'cue_${now.millisecondsSinceEpoch}',
      title: title,
      subtitle: _subtitleController.text.trim(),
      platform: _selectedPlatform,
      scheduledTime: scheduledDateTime,
      totalMinutes: totalMins,
      watchedMinutes: existing != null
          ? existing.watchedMinutes.clamp(0, totalMins)
          : 0,
      sessionMinutes: sessionMins,
      currentEpisode: currentEp,
      totalEpisodes: totalEps,
      deepLinkUrl: normalizedLink,
      recurrence: _selectedRecurrence,
      activeWeekdays: List<int>.from(_selectedWeekdays)..sort(),
      reminderMinutesBefore: _selectedReminderMinutes,
    );

    if (existing != null) {
      ref.read(cueDeckProvider.notifier).updateWatchCue(item);
    } else {
      ref.read(cueDeckProvider.notifier).addWatchCue(item);
    }
    Navigator.of(context).pop();
  }
}

/// Opens the CueDeck "What's New & Release Notes" modal sheet.
/// When [initialStartupMode] is `true` (first launch after an update), it highlights
/// the latest version (`CueReleaseNotesCatalog.latest`) with an option to expand
/// past version history.
Future<void> showCueWhatsNewModal(
  BuildContext context, {
  required bool isDarkMode,
  bool initialStartupMode = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      return _CueWhatsNewModalSheet(
        isDarkMode: isDarkMode,
        initialStartupMode: initialStartupMode,
      );
    },
  );
}

class _CueWhatsNewModalSheet extends StatefulWidget {
  const _CueWhatsNewModalSheet({
    required this.isDarkMode,
    required this.initialStartupMode,
  });

  final bool isDarkMode;
  final bool initialStartupMode;

  @override
  State<_CueWhatsNewModalSheet> createState() => _CueWhatsNewModalSheetState();
}

class _CueWhatsNewModalSheetState extends State<_CueWhatsNewModalSheet> {
  late bool _showAllHistory;

  @override
  void initState() {
    super.initState();
    _showAllHistory = !widget.initialStartupMode;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final sheetBg = isDark ? const Color(0xFF141824) : const Color(0xFFF3F6FA);
    final cardBg = isDark ? const Color(0xFF1E2433) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final primaryText =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText = isDark ? const Color(0xFFE6C17A) : const Color(0xFFB07A28);
    final mintText = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);

    final visibleEntries = _showAllHistory
        ? CueReleaseNotesCatalog.versions
        : <CueReleaseVersionEntry>[CueReleaseNotesCatalog.latest];

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: borderColor),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: secondaryText.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    const CueDeckBrandBadge(size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.initialStartupMode
                                ? '🎉 CueDeck Güncellendi!'
                                : '📋 CueDeck Sürüm Notları',
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Bu sürümde neler değişti • ${CueReleaseNotesCatalog.latest.versionLabel}',
                            style: TextStyle(
                              color: goldText,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: visibleEntries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final entry = visibleEntries[index];
                      final isLatest = index == 0;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isLatest
                                ? goldText.withValues(alpha: 0.35)
                                : borderColor,
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
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (isLatest ? mintText : goldText)
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isLatest
                                          ? 'AKTİF SÜRÜM • ${entry.versionLabel}'
                                          : entry.versionLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isLatest ? mintText : goldText,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.releaseDate,
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.headline,
                              style: TextStyle(
                                color: primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...entry.highlights.map(
                              (CueReleaseNoteItem item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: goldText.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.badge,
                                        style: TextStyle(
                                          color: goldText,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              color: primaryText,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.description,
                                            style: TextStyle(
                                              color: secondaryText,
                                              fontSize: 11.5,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    if (!_showAllHistory &&
                        CueReleaseNotesCatalog.versions.length > 1) ...<Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryText,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _showAllHistory = true;
                            });
                          },
                          icon: const Icon(Icons.history_rounded, size: 17),
                          label: const Text(
                            'Önceki Sürümler',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: goldText,
                          foregroundColor: const Color(0xFF141824),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Harika, Devam Et',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
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
      ),
    );
  }
}
