import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../speed_reading/domain/guided_flow_models.dart';

/// Akıcı Fasıl sırasında ekranın altında duran tek satırlık yüzen odak kapsülü.
class GuidedFlowCapsuleHud extends StatelessWidget {
  final GuidedFlowPhase phase;
  final int currentWpm;
  final int remainingSeconds;
  final bool isPaused;
  final bool pausedByInteraction;
  final bool isOriginalPdfMode;
  final VoidCallback onTogglePause;
  final ValueChanged<int> onAdjustWpm;
  final VoidCallback onFinishEarly;
  final VoidCallback onStop;

  const GuidedFlowCapsuleHud({
    super.key,
    required this.phase,
    required this.currentWpm,
    required this.remainingSeconds,
    required this.isPaused,
    required this.pausedByInteraction,
    required this.isOriginalPdfMode,
    required this.onTogglePause,
    required this.onAdjustWpm,
    required this.onFinishEarly,
    required this.onStop,
  });

  String _formatDuration(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = (safe ~/ 60).toString().padLeft(2, '0');
    final secs = (safe % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.inkBlack.withValues(alpha: 0.92)
        : theme.colorScheme.surface.withValues(alpha: 0.96);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pausedByInteraction)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _InteractionPauseHint(surfaceColor: surfaceColor),
            ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.amberGold.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CapsuleIconButton(
                    icon: isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    tooltip: isPaused ? 'Devam Et' : 'Duraklat',
                    color: theme.colorScheme.primary,
                    onTap: onTogglePause,
                  ),
                  const SizedBox(width: 4),
                  if (isOriginalPdfMode) ...[
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 13,
                      color: AppColors.amberGold,
                    ),
                    const SizedBox(width: 4),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 105),
                    child: Text(
                      phase.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  _CapsuleDivider(color: theme.colorScheme.outline),
                  _WpmStepButton(
                    label: '-15',
                    onTap: () => onAdjustWpm(-15),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '$currentWpm',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  _WpmStepButton(
                    label: '+15',
                    onTap: () => onAdjustWpm(15),
                  ),
                  _CapsuleDivider(color: theme.colorScheme.outline),
                  Text(
                    _formatDuration(remainingSeconds),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _CapsuleIconButton(
                    icon: Icons.verified_outlined,
                    tooltip: 'Mühürle',
                    color: AppColors.amberGold,
                    onTap: onFinishEarly,
                  ),
                  _CapsuleIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Kapat',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    onTap: onStop,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionPauseHint extends StatelessWidget {
  final Color surfaceColor;

  const _InteractionPauseHint({required this.surfaceColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.amberGold.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 13,
            color: AppColors.amberGold,
          ),
          const SizedBox(width: 6),
          Text(
            'Lügat/not için duraklatıldı',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _CapsuleIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}

class _WpmStepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _WpmStepButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _CapsuleDivider extends StatelessWidget {
  final Color color;

  const _CapsuleDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: color.withValues(alpha: 0.45),
    );
  }
}
