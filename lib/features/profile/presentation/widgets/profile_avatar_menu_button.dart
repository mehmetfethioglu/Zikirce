import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../family_profiles/presentation/family_profiles_screen.dart';
import '../../../monetization/presentation/paywall_screen.dart';
import '../../../onboarding/presentation/kilerce_user_guide_screen.dart';
import '../../../settings/presentation/kilerce_settings_screen.dart';
import '../../../settings/presentation/widgets/recipe_photo_feedback_sheet.dart';
import '../../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';
import '../../domain/user_profile_service.dart';
import '../profile_screen.dart';

enum _ProfileMenuAction {
  profile,
  familyProfiles,
  taklitTagsis,
  settings,
  userGuide,
  recipePhotoFeedback,
  pro,
}

/// Top-bar profile photo button that opens a quick navigation menu for
/// account, family profiles, blacklist, settings, user guide, and feedback.
class ProfileAvatarMenuButton extends StatelessWidget {
  const ProfileAvatarMenuButton({super.key});

  void _handleAction(BuildContext context, _ProfileMenuAction action) {
    switch (action) {
      case _ProfileMenuAction.profile:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
      case _ProfileMenuAction.familyProfiles:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FamilyProfilesScreen()),
        );
        break;
      case _ProfileMenuAction.taklitTagsis:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaklitTagsisScreen()),
        );
        break;
      case _ProfileMenuAction.settings:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const KilerceSettingsScreen()),
        );
        break;
      case _ProfileMenuAction.userGuide:
        KilerceUserGuideScreen.show(context, markCompletedOnClose: false);
        break;
      case _ProfileMenuAction.recipePhotoFeedback:
        RecipePhotoFeedbackSheet.show(context);
        break;
      case _ProfileMenuAction.pro:
        PaywallScreen.show(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserProfileService.instance,
      builder: (context, _) {
        final profile = UserProfileService.instance.profile;
        final levelInfo = UserProfileService.instance.levelInfo;
        final preset = UserProfileService.presetAvatars.firstWhere(
          (p) => p.id == profile.presetAvatarId,
          orElse: () => UserProfileService.presetAvatars.first,
        );

        return Semantics(
          button: true,
          label: 'Profil ve hesap menüsü',
          child: PopupMenuButton<_ProfileMenuAction>(
            key: const Key('top_bar_profile_avatar'),
            tooltip: 'Hesap ve Ayarlar Menüsü',
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (action) => _handleAction(context, action),
            itemBuilder: (menuContext) => [
              PopupMenuItem<_ProfileMenuAction>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: menuContext.textPrimaryColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.googleEmail ??
                          'Seviye ${levelInfo.level} · ${levelInfo.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: menuContext.textSecondaryColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 8),
              _buildMenuItem(
                value: _ProfileMenuAction.profile,
                icon: Icons.person_outline_rounded,
                color: AppColors.primaryEmerald,
                label: 'Hesabım & Profil',
              ),
              _buildMenuItem(
                value: _ProfileMenuAction.familyProfiles,
                icon: Icons.family_restroom_rounded,
                color: AppColors.primaryMint,
                label: 'Aile & Beslenme Profilleri',
              ),
              _buildMenuItem(
                value: _ProfileMenuAction.taklitTagsis,
                icon: Icons.gpp_maybe_rounded,
                color: AppColors.dangerRed,
                label: 'Bakanlık Kara Listesi',
              ),
              _buildMenuItem(
                value: _ProfileMenuAction.settings,
                icon: Icons.settings_rounded,
                color: AppColors.primaryEmerald,
                label: 'Ayarlar',
              ),
              _buildMenuItem(
                value: _ProfileMenuAction.userGuide,
                icon: Icons.menu_book_rounded,
                color: AppColors.primaryMint,
                label: 'Kullanım Kılavuzu',
              ),
              _buildMenuItem(
                value: _ProfileMenuAction.recipePhotoFeedback,
                icon: Icons.add_a_photo_rounded,
                color: AppColors.primaryEmerald,
                label: 'Tarif Fotoğrafı Gönder',
              ),
              _buildMenuItem(
                value: _ProfileMenuAction.pro,
                icon: Icons.workspace_premium_rounded,
                color: AppColors.cautionGold,
                label: 'Kilerce Pro',
              ),
            ],
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.pastelSageTint,
                border: Border.all(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.65),
                  width: 1.6,
                ),
              ),
              child: ClipOval(
                child: _AvatarContent(
                  avatarPath: profile.avatarPath,
                  googlePhotoUrl: profile.googlePhotoUrl,
                  fallbackEmoji: preset.emoji,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static PopupMenuItem<_ProfileMenuAction> _buildMenuItem({
    required _ProfileMenuAction value,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return PopupMenuItem<_ProfileMenuAction>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarContent extends StatelessWidget {
  final String? avatarPath;
  final String? googlePhotoUrl;
  final String fallbackEmoji;

  const _AvatarContent({
    required this.avatarPath,
    required this.googlePhotoUrl,
    required this.fallbackEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final localPath = avatarPath?.trim();
    if (!kIsWeb &&
        localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _EmojiFallback(emoji: fallbackEmoji),
      );
    }

    final photoUrl = googlePhotoUrl?.trim();
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _EmojiFallback(emoji: fallbackEmoji),
      );
    }

    return _EmojiFallback(emoji: fallbackEmoji);
  }
}

class _EmojiFallback extends StatelessWidget {
  final String emoji;

  const _EmojiFallback({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}
