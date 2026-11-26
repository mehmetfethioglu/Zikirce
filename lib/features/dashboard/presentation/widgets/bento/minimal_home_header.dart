import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/haptic_service.dart';
import '../../../../../core/session/session_providers.dart';
import '../../../../../core/theme/app_theme_colors.dart';
import '../../../../../core/widgets/cloud_sync_app_bar_badge.dart';
import '../../../../gamification/providers/gamification_providers.dart';
import '../../../../settings/providers/settings_provider.dart';
import '../account_switcher_sheet.dart';
import '../rank_info_bottom_sheet.dart';

class MinimalHomeHeader extends ConsumerWidget {
  final bool hasShareBadge;
  final Color badgePrimaryColor;
  final Color badgeSecondaryColor;
  final VoidCallback onOpenShareReminder;

  const MinimalHomeHeader({
    super.key,
    required this.hasShareBadge,
    required this.badgePrimaryColor,
    required this.badgeSecondaryColor,
    required this.onOpenShareReminder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sessionInfo = ref.watch(
      activeSessionProvider.select(
        (s) => (displayName: s.displayName, avatar: s.avatar, isCloud: s.isCloud),
      ),
    );
    final dbUserName = ref.watch(
      userProfileStreamProvider.select((a) => a.valueOrNull?.userName),
    );
    final settingsAvatar = ref.watch(
      userSettingsProvider.select((s) => s.userProfileImage),
    );
    final userRank = ref.watch(currentUserRankProvider);

    final userName = sessionInfo.displayName.isNotEmpty
        ? sessionInfo.displayName
        : ((dbUserName != null && dbUserName.isNotEmpty)
            ? dbUserName
            : (l10n.isTurkish ? 'Zâkir' : 'User'));
    final userAvatar = sessionInfo.avatar.isNotEmpty
        ? sessionInfo.avatar
        : settingsAvatar;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasBoundedHeight = constraints.hasBoundedHeight;
            final isCompact = hasBoundedHeight && constraints.maxHeight < 86;
            final verticalPad = isCompact ? 6.0 : 9.0;
            final avatarSize = hasBoundedHeight
                ? (constraints.maxHeight - (verticalPad * 2) - 4.0)
                    .clamp(46.0, isCompact ? 54.0 : 60.0)
                : 56.0;
            final actionSize = isCompact ? 34.0 : 36.0;

            return Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ProfileCardOrnamentPainter(
                        accentColor: colors.accent.withValues(alpha: isDark ? 0.12 : 0.07),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: verticalPad,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ProfileAvatarBadge(
                          size: avatarSize,
                          userAvatar: userAvatar,
                          isCloud: sessionInfo.isCloud,
                          hasShareBadge: hasShareBadge,
                          badgePrimaryColor: badgePrimaryColor,
                          badgeSecondaryColor: badgeSecondaryColor,
                          onOpenShareReminder: onOpenShareReminder,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => AccountSwitcherSheet.show(context),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l10n.isTurkish
                                          ? 'Selamün Aleyküm'
                                          : 'Peace be upon you',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isCompact ? 11.5 : 12.0,
                                        fontWeight: FontWeight.w300,
                                        color: colors.secondaryText,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isCompact ? 16.5 : 18.0,
                                        fontWeight: FontWeight.w800,
                                        color: colors.primaryText,
                                        height: 1.15,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              InkWell(
                                onTap: () => RankInfoBottomSheet.show(context),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 1),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        userRank.badge,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          userRank.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: colors.secondaryText,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.keyboard_arrow_right_rounded,
                                        size: 15,
                                        color: colors.secondaryTextAlt,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const CloudSyncAppBarBadge(),
                        _HeaderCircleActionButton(
                          size: actionSize,
                          icon: Icons.insights_rounded,
                          tooltip: l10n.isTurkish
                              ? 'Detaylı İstatistikler ve Rozetler'
                              : 'Detailed Statistics & Badges',
                          onTap: () {
                            HapticService.selectionClick();
                            context.push('/stats');
                          },
                        ),
                        const SizedBox(width: 6),
                        _HeaderCircleActionButton(
                          size: actionSize,
                          icon: Icons.settings_outlined,
                          tooltip: l10n.isTurkish ? 'Ayarlar' : 'Settings',
                          onTap: () {
                            HapticService.selectionClick();
                            context.push('/settings');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileAvatarBadge extends StatelessWidget {
  final double size;
  final String userAvatar;
  final bool isCloud;
  final bool hasShareBadge;
  final Color badgePrimaryColor;
  final Color badgeSecondaryColor;
  final VoidCallback onOpenShareReminder;

  const _ProfileAvatarBadge({
    this.size = 50.0,
    required this.userAvatar,
    required this.isCloud,
    required this.hasShareBadge,
    required this.badgePrimaryColor,
    required this.badgeSecondaryColor,
    required this.onOpenShareReminder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: hasShareBadge
          ? onOpenShareReminder
          : () => AccountSwitcherSheet.show(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.cardBackground,
              border: Border.all(
                color: hasShareBadge ? badgePrimaryColor : colors.accent,
                width: hasShareBadge ? 2.5 : 2.0,
              ),
              boxShadow: hasShareBadge
                  ? [
                      BoxShadow(
                        color: badgePrimaryColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: ClipOval(
              child: _AvatarThumb(imagePath: userAvatar),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: () => AccountSwitcherSheet.show(context),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.cardBackground, width: 1.5),
                ),
                child: Icon(
                  isCloud ? Icons.cloud_done_rounded : Icons.swap_horiz_rounded,
                  size: 11,
                  color: colors.activeNavIconColor == const Color(0xFF000000)
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
          ),
          if (hasShareBadge)
            Positioned(
              top: -4,
              right: -5,
              child: GestureDetector(
                onTap: onOpenShareReminder,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [badgePrimaryColor, badgeSecondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.cardBackground, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCircleActionButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderCircleActionButton({
    this.size = 36.0,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colors.cardBackgroundAlt,
              shape: BoxShape.circle,
              border: Border.all(color: colors.borderStroke),
            ),
            child: Icon(
              icon,
              size: size < 35 ? 17 : 18,
              color: colors.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCardOrnamentPainter extends CustomPainter {
  final Color accentColor;

  const _ProfileCardOrnamentPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final center = Offset(size.width - 18, 22);
    for (final radius in const [38.0, 56.0]) {
      final path = Path();
      const points = 8;
      for (int i = 0; i < points; i++) {
        final angle = (i * math.pi * 2 / points);
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileCardOrnamentPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

class _AvatarThumb extends StatelessWidget {
  final String imagePath;

  const _AvatarThumb({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final isLocalFile = imagePath.startsWith('/') ||
        imagePath.contains(':\\') ||
        (!imagePath.startsWith('assets/') && File(imagePath).existsSync());

    if (isLocalFile) {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        cacheWidth: 160,
        cacheHeight: 160,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('👤', style: TextStyle(fontSize: 22)),
        ),
      );
    }

    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      cacheWidth: 160,
      cacheHeight: 160,
      errorBuilder: (_, __, ___) => const Center(
        child: Text('👤', style: TextStyle(fontSize: 22)),
      ),
    );
  }
}
