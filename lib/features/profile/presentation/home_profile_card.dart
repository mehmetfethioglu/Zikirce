import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/badge_definitions.dart';
import '../domain/user_profile_service.dart';
import 'profile_screen.dart';

import '../../family_profiles/domain/family_profile_engine.dart';
import '../../family_profiles/presentation/family_profiles_screen.dart';

class HomeProfileCard extends StatelessWidget {
  final FamilyProfile? activeProfile;
  final VoidCallback? onActiveProfileTap;
  final VoidCallback? onCardTap;

  const HomeProfileCard({
    super.key,
    this.activeProfile,
    this.onActiveProfileTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: UserProfileService.instance,
      builder: (context, _) {
        final profile = UserProfileService.instance.profile;
        final levelInfo = UserProfileService.instance.levelInfo;

        // Find unlocked badge items
        final unlockedBadges = profile.unlockedBadgeIds
            .map((id) => BadgeDefinitions.findById(id))
            .whereType<BadgeItem>()
            .toList();

        // Get preset avatar emoji
        final preset = UserProfileService.presetAvatars.firstWhere(
          (p) => p.id == profile.presetAvatarId,
          orElse: () => UserProfileService.presetAvatars.first,
        );

        return GestureDetector(
          onTap: onCardTap ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryEmerald.withValues(alpha: isDark ? 0.35 : 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryEmerald.withValues(alpha: isDark ? 0.12 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar, User Details, Chevron
                Row(
                  children: [
                    // Avatar with Level indicator
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryEmerald.withValues(alpha: 0.25),
                                AppColors.primaryMint.withValues(alpha: 0.15),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: AppColors.primaryMint,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: profile.avatarPath != null &&
                                    File(profile.avatarPath!).existsSync()
                                ? Image.file(
                                    File(profile.avatarPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(preset.emoji, style: const TextStyle(fontSize: 24)),
                                    ),
                                  )
                                : (profile.googlePhotoUrl != null && profile.googlePhotoUrl!.isNotEmpty
                                    ? Image.network(
                                        profile.googlePhotoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Center(
                                          child: Text(preset.emoji, style: const TextStyle(fontSize: 24)),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          preset.emoji,
                                          style: const TextStyle(fontSize: 26),
                                        ),
                                      )),
                          ),
                        ),
                        // Level Tag
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: surfaceColor, width: 1.5),
                            ),
                            child: Text(
                              'Lvl ${levelInfo.level}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // User Name, Title & XP Bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: User Name + Active Profile Badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile.displayName,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildActiveProfileBadge(
                                context: context,
                                activeProfile: activeProfile,
                                isDark: isDark,
                                onTap: onActiveProfileTap,
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),

                          // Bottom Row: Rank Title Pill + XP Bar + XP Text
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMint.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.primaryMint.withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  levelInfo.title,
                                  style: const TextStyle(
                                    color: AppColors.primaryMint,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: levelInfo.progress,
                                    minHeight: 5,
                                    backgroundColor: textSecondary.withValues(alpha: 0.15),
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryMint),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${profile.xp} XP',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Middle Divider
                Divider(
                  height: 1,
                  color: borderColor.withValues(alpha: isDark ? 0.3 : 0.6),
                ),
                const SizedBox(height: 12),

                // Bottom Row: 3 Stats Pills + Mini Badge Previews
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatPill(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Tarama',
                      value: '${profile.totalScans}',
                      color: AppColors.primaryMint,
                      textColor: textPrimary,
                      subColor: textSecondary,
                    ),
                    _buildStatPill(
                      icon: Icons.volunteer_activism_rounded,
                      label: 'Katkı',
                      value: '${profile.totalContributions + profile.totalBoycottReports}',
                      color: AppColors.cautionGold,
                      textColor: textPrimary,
                      subColor: textSecondary,
                    ),
                    _buildStatPill(
                      icon: Icons.emoji_events_rounded,
                      label: 'Rozet',
                      value: '${unlockedBadges.length} / ${BadgeDefinitions.allBadges.length}',
                      color: const Color(0xFFFFD700),
                      textColor: textPrimary,
                      subColor: textSecondary,
                    ),
                  ],
                ),

                // Optional: Unlocked Badges Preview Strip
                if (unlockedBadges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Kazanılan Rozetler: ',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: unlockedBadges.take(4).map((badge) {
                              return Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badge.tierColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: badge.tierColor.withValues(alpha: 0.5), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(badge.iconEmoji, style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text(
                                      badge.title,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color textColor,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: subColor,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveProfileBadge({
    required BuildContext context,
    required FamilyProfile? activeProfile,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    final String label = activeProfile != null ? activeProfile.profileName : 'Varsayılan';
    final bool hasCustomProfile = activeProfile != null;

    return Tooltip(
      message: hasCustomProfile ? 'Aktif Profil: $label (Değiştirmek için dokunun)' : 'Profil Seç (Aile Profilleri)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FamilyProfilesScreen()),
                );
              },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryEmerald.withValues(alpha: isDark ? 0.25 : 0.14),
                  AppColors.primaryMint.withValues(alpha: isDark ? 0.15 : 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryMint.withValues(alpha: isDark ? 0.5 : 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryEmerald.withValues(alpha: isDark ? 0.15 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasCustomProfile ? Icons.shield_rounded : Icons.shield_outlined,
                  size: 13,
                  color: AppColors.primaryMint,
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.primaryMint,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more_rounded,
                  size: 14,
                  color: AppColors.primaryMint.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

