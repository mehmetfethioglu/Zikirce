import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/tv_mode_provider.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/widgets/tv_focusable.dart';
import '../../providers/tv_cast_provider.dart';
import 'tv_cast_sheet.dart';

/// Zikirce TV Hub üst çubuğu için harici TV yansıtma düğmesi.
class TvCastPillButton extends ConsumerWidget {
  final bool isCompact;
  final double maxWidth;

  const TvCastPillButton({
    super.key,
    this.isCompact = false,
    this.maxWidth = 1000,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castSlice = ref.watch(
      tvCastProvider.select(
        (s) => (s.isSupported, s.isVisualMirroring, s.deviceName),
      ),
    );
    final isSupported = castSlice.$1;
    if (TvModeService.isHardwareTv || !isSupported) {
      return const SizedBox.shrink();
    }

    final isConnected = castSlice.$2;
    final deviceName = castSlice.$3;
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTr = AppLocalizations.of(context).isTurkish;
    final connectedColor =
        isDark ? const Color(0xFF34D399) : const Color(0xFF15803D);

    final String label;
    if (isConnected) {
      label = (deviceName != null && deviceName.isNotEmpty)
          ? deviceName
          : (isTr ? 'TV Bağlı' : 'TV Connected');
    } else if (maxWidth < 360) {
      label = isTr ? 'Yansıt' : 'Cast';
    } else {
      label = isTr ? "TV'ye Yansıt" : 'Cast to TV';
    }

    final activeTint = isConnected ? connectedColor : colors.accent;

    return Semantics(
      button: true,
      label: isTr ? "TV'ye Yansıt" : 'Cast to TV',
      child: TvFocusable(
        key: const Key('tv_cast_button'),
        borderRadius: 14,
        onPressed: () => TvCastSheet.show(context),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 11,
            vertical: isCompact ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: isConnected
                ? connectedColor.withValues(alpha: isDark ? 0.16 : 0.10)
                : colors.pageBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: activeTint.withValues(alpha: isConnected ? 0.72 : 0.45),
              width: isConnected ? 1.3 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isConnected
                    ? Icons.cast_connected_rounded
                    : Icons.cast_rounded,
                size: isCompact ? 15 : 17,
                color: activeTint,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 12.5,
                    fontWeight: FontWeight.w800,
                    color: isConnected ? connectedColor : colors.primaryText,
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

/// Mushaf ve Mukabele TV modu AppBar'ı için kompakt TV yansıtma ikonu.
class TvCastIconButton extends ConsumerWidget {
  final Color? iconColor;

  const TvCastIconButton({
    super.key,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castSlice = ref.watch(
      tvCastProvider.select(
        (s) => (s.isSupported, s.isVisualMirroring, s.deviceName),
      ),
    );
    final isSupported = castSlice.$1;
    if (TvModeService.isHardwareTv || !isSupported) {
      return const SizedBox.shrink();
    }

    final isConnected = castSlice.$2;
    final deviceName = castSlice.$3;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTr = AppLocalizations.of(context).isTurkish;
    final connectedColor =
        isDark ? const Color(0xFF34D399) : const Color(0xFF15803D);
    final effectiveColor = isConnected
        ? connectedColor
        : (iconColor ?? (isDark ? Colors.white70 : const Color(0xFF1E2B27)));

    return IconButton(
      key: const Key('tv_cast_appbar_button'),
      tooltip: isConnected
          ? (deviceName != null && deviceName.isNotEmpty
              ? '$deviceName • ${isTr ? 'Yansıtılıyor' : 'Mirroring'}'
              : (isTr ? "TV'ye Yansıtılıyor" : 'Mirroring to TV'))
          : (isTr ? "TV'ye Yansıt" : 'Cast to TV'),
      onPressed: () => TvCastSheet.show(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            isConnected ? Icons.cast_connected_rounded : Icons.cast_rounded,
            color: effectiveColor,
          ),
          if (isConnected)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: connectedColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
