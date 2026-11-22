import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cue_models.dart';
import '../../providers/cuedeck_providers.dart';
import '../cuetv_channel_studio_sheet.dart';
import 'remote_shortcut_picker_sheet.dart';

/// Quick-launch 6-slot streaming app dock on the G10 physical remote chassis.
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
      if (p == StreamingPlatform.cueTv) {
        showCueTvChannelStudioSheet(context);
        return;
      }
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

    return Row(
      children: <Widget>[
        buildSlot(0),
        const SizedBox(width: 10),
        buildSlot(1),
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

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = goldGradient;
    canvas.drawCircle(center, ringRadius, ringPaint);

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
