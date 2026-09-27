import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/models/badge_models.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../gamification/services/custom_badge_service.dart';
import '../../../kuran/presentation/widgets/add_custom_quran_badge_sheet.dart';
import 'badge_detail_modal.dart';

class BadgeGalleryCards extends ConsumerWidget {
  final VoidCallback? onAddQuranBadge;

  const BadgeGalleryCards({
    super.key,
    this.onAddQuranBadge,
  });

  void _showCustomBadgeDialog(BuildContext context, WidgetRef ref, CustomQuranBadge badge) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        final status = badge.isUnlocked ? '✓ Kazanıldı' : 'İlerleme: ${badge.progressText}';

        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Text(badge.iconEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  badge.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.primaryText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kapsam: ${badge.scopeDisplayName}', style: TextStyle(fontSize: 13, color: colors.primaryText)),
              const SizedBox(height: 4),
              Text('Hedef: ${badge.targetDays} Gün', style: TextStyle(fontSize: 13, color: colors.primaryText)),
              const SizedBox(height: 4),
              Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: badge.glowColor)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await CustomBadgeService.deleteCustomBadge(badge.id);
                ref.read(badgeRefreshTriggerProvider.notifier).state++;
              },
              child: const Text('Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final badgesAsync = ref.watch(allBadgesProvider);
    final customBadgesAsync = ref.watch(customBadgesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // 1. ZİKİR BAŞARI ROZETLERİ SECTION
        // ==========================================
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_rounded,
                size: 16,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Zikir Başarı Rozetleri',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 156,
          child: badgesAsync.when(
            data: (badges) {
              final zikirBadges = badges.where((b) => b.category == 'Zikir').toList();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                itemCount: zikirBadges.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final badge = zikirBadges[index];
                  return _buildZikirBadgeCard(context, badge, colors);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 24),

        // ==========================================
        // 2. KURAN OKUMA ROZETLERİ SECTION
        // ==========================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 16,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Kuran Okuma Rozetleri',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
              ],
            ),
            // + Rozet Ekle Button in Header
            GestureDetector(
              onTap: () => onAddQuranBadge != null
                  ? onAddQuranBadge!()
                  : AddCustomQuranBadgeSheet.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 13, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'Rozet Ekle',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 156,
          child: badgesAsync.when(
            data: (badges) {
              final defaultQuranBadges = badges.where((b) => b.category == 'Kuran').toList();
              final customBadges = customBadgesAsync.value ?? [];

              final totalItems = defaultQuranBadges.length + customBadges.length + 1; // +1 for "Yeni Rozet Ekle" card

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                itemCount: totalItems,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (index < defaultQuranBadges.length) {
                    final badge = defaultQuranBadges[index];
                    return _buildQuranBadgeCard(context, badge, colors);
                  } else if (index < defaultQuranBadges.length + customBadges.length) {
                    final customBadge = customBadges[index - defaultQuranBadges.length];
                    return _buildCustomQuranBadgeCard(context, ref, customBadge, colors);
                  } else {
                    // + Yeni Rozet Ekle Card at the end
                    return _buildAddBadgeCard(context, colors);
                  }
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildZikirBadgeCard(BuildContext context, Badge badge, AppThemeColors colors) {
    final isUnlocked = badge.isUnlocked;

    return GestureDetector(
      onTap: () => BadgeDetailModal.show(context, badge),
      child: Container(
        width: 116,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isUnlocked ? badge.glowColor : colors.borderStroke,
            width: isUnlocked ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isUnlocked
                  ? badge.glowColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Circular Lottie Container + Checkmark
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? badge.glowColor.withValues(alpha: 0.14)
                        : colors.cardBackgroundAlt.withValues(alpha: 0.5),
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: isUnlocked ? 1.0 : 0.4,
                    child: badge.iconPath.endsWith('.json')
                        ? Lottie.asset(
                            badge.iconPath,
                            width: 36,
                            height: 36,
                            repeat: true,
                          )
                        : Text(badge.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                if (isUnlocked)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: badge.glowColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '✓',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Badge Name
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? colors.primaryText : colors.secondaryTextAlt,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Criteria
            Text(
              badge.criteria,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isUnlocked ? FontWeight.bold : FontWeight.w500,
                color: isUnlocked ? badge.glowColor : colors.secondaryTextAlt,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuranBadgeCard(BuildContext context, Badge badge, AppThemeColors colors) {
    final isUnlocked = badge.isUnlocked;

    return GestureDetector(
      onTap: () => BadgeDetailModal.show(context, badge),
      child: Container(
        width: 116,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isUnlocked ? badge.glowColor : colors.borderStroke,
            width: isUnlocked ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isUnlocked
                  ? badge.glowColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Circular Emoji Icon Container + Checkmark
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? badge.glowColor.withValues(alpha: 0.14)
                        : colors.cardBackgroundAlt.withValues(alpha: 0.5),
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: isUnlocked ? 1.0 : 0.4,
                    child: Text(badge.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                if (isUnlocked)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: badge.glowColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '✓',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Badge Name
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? colors.primaryText : colors.secondaryTextAlt,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Criteria & Streak Progress
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  badge.criteria,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isUnlocked ? FontWeight.bold : FontWeight.w500,
                    color: isUnlocked ? badge.glowColor : colors.secondaryTextAlt,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (badge.hasStreakProgress) ...[
                  const SizedBox(height: 1),
                  Text(
                    badge.progressText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: badge.glowColor,
                    ),
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomQuranBadgeCard(BuildContext context, WidgetRef ref, CustomQuranBadge badge, AppThemeColors colors) {
    return GestureDetector(
      onTap: () => _showCustomBadgeDialog(context, ref, badge),
      child: Container(
        width: 116,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: badge.glowColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: badge.glowColor.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Circular Emoji Icon Container + Checkmark
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badge.glowColor.withValues(alpha: 0.12),
                  ),
                  alignment: Alignment.center,
                  child: Text(badge.iconEmoji, style: const TextStyle(fontSize: 24)),
                ),
                if (badge.isUnlocked)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: badge.glowColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '✓',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Badge Title
            Text(
              badge.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Scope & Progress
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  badge.scopeDisplayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: colors.secondaryTextAlt,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  badge.progressText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: badge.glowColor,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddBadgeCard(BuildContext context, AppThemeColors colors) {
    return GestureDetector(
      onTap: () => onAddQuranBadge != null
          ? onAddQuranBadge!()
          : AddCustomQuranBadgeSheet.show(context),
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: colors.accent,
          strokeWidth: 1.5,
          radius: 24,
        ),
        child: Container(
          width: 116,
          decoration: BoxDecoration(
            color: colors.cardBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add_rounded, size: 24, color: colors.accent),
              ),
              const SizedBox(height: 10),
              Text(
                'Yeni Rozet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                'Oluştur',
                style: TextStyle(
                  fontSize: 10,
                  color: colors.secondaryTextAlt,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? 6.0 : 4.0;
        if (draw) {
          final extractPath = metric.extractPath(distance, distance + length);
          canvas.drawPath(extractPath, paint);
        }
        distance += length;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}
