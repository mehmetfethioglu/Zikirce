import '../../../core/services/changelog_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/badge_definitions.dart';
import '../domain/user_profile_service.dart';
import '../domain/google_auth_sync_service.dart';
import '../../family_profiles/domain/family_profile_engine.dart';
import '../../family_profiles/presentation/family_profiles_screen.dart';
import '../../scoring/presentation/personal_sensitivity_modal.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  BadgeCategory? _selectedCategory;
  FamilyProfile? _activeProfile;

  @override
  void initState() {
    super.initState();
    _loadActiveProfile();
  }

  Future<void> _loadActiveProfile() async {
    final active = await FamilyProfileEngine.getActiveProfile();
    if (mounted) {
      setState(() => _activeProfile = active);
    }
  }

  String _getPresetLabel(String presetId) {
    switch (presetId) {
      case 'diabetes':
        return '🩺 Diyabet Modu';
      case 'clean_eating':
        return '🌿 Temiz & Katkısız';
      case 'heart_health':
        return '🫀 Kalp Dostu';
      case 'child_safe':
        return '👶 Çocuk Güvenli';
      case 'custom':
      default:
        return '⚙️ Özel Ayarlar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profil & Katkı Rozetleri',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          UserProfileService.instance,
          GoogleAuthSyncService.instance,
        ]),
        builder: (context, _) {
          final profile = UserProfileService.instance.profile;
          final levelInfo = UserProfileService.instance.levelInfo;

          final filteredBadges = _selectedCategory == null
              ? BadgeDefinitions.allBadges
              : BadgeDefinitions.allBadges
                  .where((b) => b.category == _selectedCategory)
                  .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. User Profile Header Card
                _buildProfileHeader(
                  context,
                  profile: profile,
                  levelInfo: levelInfo,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // 2. Contribution Statistics Grid (4 Key Metrics)
                Text(
                  'Katkı İstatistikleri',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildStatsGrid(profile, surfaceColor, borderColor, textPrimary, textSecondary),
                const SizedBox(height: 24),

                // 2.5 Nutrition & Scoring Personal Preferences Card
                _buildNutritionAndScoringCard(
                  context,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // 3. Badges & Achievements Header & Category Filters
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kazanılan Rozetler',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${profile.unlockedBadgeIds.length} / ${BadgeDefinitions.allBadges.length}',
                      style: const TextStyle(
                        color: AppColors.primaryMint,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildCategoryChips(textPrimary, textSecondary, surfaceColor),
                const SizedBox(height: 12),

                // Badges List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredBadges.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final badge = filteredBadges[index];
                    final isUnlocked = profile.unlockedBadgeIds.contains(badge.id);
                    return _buildBadgeCard(
                      badge: badge,
                      isUnlocked: isUnlocked,
                      profile: profile,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 4. Advanced Offline JSON Backup Accordion
                _buildChangelogTile(context, surfaceColor: surfaceColor, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary),
                const SizedBox(height: 16),
                _buildOfflineBackupAccordion(
                  context,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 1. Profile Header Widget ---
  Widget _buildProfileHeader(
    BuildContext context, {
    required UserProfile profile,
    required UserLevelInfo levelInfo,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final preset = UserProfileService.presetAvatars.firstWhere(
      (p) => p.id == profile.presetAvatarId,
      orElse: () => UserProfileService.presetAvatars.first,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryEmerald.withValues(alpha: isDark ? 0.4 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryEmerald.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with Edit Button
              GestureDetector(
                onTap: () => _showAvatarPickerModal(context),
                child: Stack(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryMint, width: 2.5),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryEmerald.withValues(alpha: 0.2),
                            AppColors.primaryMint.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                      child: ClipOval(
                        child: profile.avatarPath != null &&
                                File(profile.avatarPath!).existsSync()
                            ? Image.file(
                                File(profile.avatarPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Text(preset.emoji, style: const TextStyle(fontSize: 36)),
                                ),
                              )
                            : (profile.googlePhotoUrl != null && profile.googlePhotoUrl!.isNotEmpty
                                ? Image.network(
                                    profile.googlePhotoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(preset.emoji, style: const TextStyle(fontSize: 36)),
                                    ),
                                  )
                                : Center(
                                    child: Text(preset.emoji, style: const TextStyle(fontSize: 40)),
                                  )),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmerald,
                          shape: BoxShape.circle,
                          border: Border.all(color: surfaceColor, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Name & Rank
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primaryMint),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showEditNameDialog(context, profile.displayName),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${levelInfo.title} (Seviye ${levelInfo.level})',
                            style: const TextStyle(
                              color: AppColors.primaryMint,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (profile.isGoogleConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryEmerald.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_done_rounded, size: 12, color: AppColors.primaryMint),
                                SizedBox(width: 4),
                                Text(
                                  'Google Bağlı',
                                  style: TextStyle(
                                    color: AppColors.primaryMint,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // XP Progress Bar & Levels
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${profile.xp} Toplam XP',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    levelInfo.level < 5
                        ? 'Sonraki Seviye: ${levelInfo.nextLevelXp - levelInfo.currentXp} XP kaldı'
                        : 'Maksimum Seviyeye Ulaşıldı! 🏆',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: levelInfo.progress,
                  minHeight: 8,
                  backgroundColor: textSecondary.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryMint),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: borderColor.withValues(alpha: 0.6), height: 1),
          const SizedBox(height: 12),

          // Integrated Google Account & Cloud Sync Section
          if (profile.isGoogleConnected)
            _buildConnectedGoogleSection(context, profile, textPrimary, textSecondary, isDark)
          else
            _buildDisconnectedGoogleSection(context, textPrimary, textSecondary, isDark),
        ],
      ),
    );
  }

  // --- 2. Stats Grid ---
  Widget _buildStatsGrid(
    UserProfile profile,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      childAspectRatio: 2.1,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricTile(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Barkod Taraması',
          value: '${profile.totalScans}',
          color: AppColors.primaryMint,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        _buildMetricTile(
          icon: Icons.add_photo_alternate_rounded,
          label: 'Topluluk Katkısı',
          value: '${profile.totalContributions}',
          color: AppColors.cautionGold,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        _buildMetricTile(
          icon: Icons.shield_outlined,
          label: 'Boykot Doğrulaması',
          value: '${profile.totalBoycottReports}',
          color: AppColors.dangerRed,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        _buildMetricTile(
          icon: Icons.eco_rounded,
          label: 'Temiz Gıda Tercihi',
          value: '${profile.healthyChoices}',
          color: AppColors.primaryEmerald,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2.5 Nutrition & Scoring Personal Preferences Widget ---
  Widget _buildNutritionAndScoringCard(
    BuildContext context, {
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final profile = _activeProfile;
    final presetName = profile != null
        ? _getPresetLabel(profile.sensitivity.presetId)
        : 'Temiz & Katkısız';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryMint.withValues(alpha: isDark ? 0.35 : 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryMint.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryMint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.health_and_safety_outlined, color: AppColors.primaryMint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Puanlama & Sağlık Tercihlerim',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile != null
                          ? 'Aktif Profil: ${profile.profileName}'
                          : 'Kişisel sağlık hedeflerinizi belirleyin',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.25)),
                ),
                child: Text(
                  presetName,
                  style: const TextStyle(
                    color: AppColors.primaryEmerald,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ürün taramalarındaki "% Uyum Skoru" şeker, katkı, palm yağı ve tuz hassasiyetlerinize göre anlık kişiselleştirilir.',
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FamilyProfilesScreen()),
                    ).then((_) => _loadActiveProfile());
                  },
                  icon: const Icon(Icons.people_outline_rounded, size: 16),
                  label: const Text('Aile Profilleri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_activeProfile != null) {
                      PersonalSensitivityModal.show(
                        context,
                        profile: _activeProfile!,
                        onSaved: _loadActiveProfile,
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FamilyProfilesScreen()),
                      ).then((_) => _loadActiveProfile());
                    }
                  },
                  icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                  label: const Text('Hassasiyetler', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. Category Filter Chips ---
  Widget _buildCategoryChips(Color textPrimary, Color textSecondary, Color surfaceColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Tümü', null, textPrimary, textSecondary, surfaceColor),
          _buildFilterChip('Tarama', BadgeCategory.scanner, textPrimary, textSecondary, surfaceColor),
          _buildFilterChip('Topluluk', BadgeCategory.crowdsource, textPrimary, textSecondary, surfaceColor),
          _buildFilterChip('Etik & Boykot', BadgeCategory.boycott, textPrimary, textSecondary, surfaceColor),
          _buildFilterChip('Temiz Gıda', BadgeCategory.health, textPrimary, textSecondary, surfaceColor),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    BadgeCategory? cat,
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
  ) {
    final isSelected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryEmerald : surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryEmerald : textSecondary.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textPrimary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // --- 4. Badge Card Widget ---
  Widget _buildBadgeCard({
    required BadgeItem badge,
    required bool isUnlocked,
    required UserProfile profile,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    int currentCount = 0;
    switch (badge.category) {
      case BadgeCategory.scanner:
        currentCount = profile.totalScans;
        break;
      case BadgeCategory.crowdsource:
        currentCount = profile.totalContributions;
        break;
      case BadgeCategory.boycott:
        currentCount = profile.totalBoycottReports;
        break;
      case BadgeCategory.health:
        currentCount = profile.healthyChoices;
        break;
    }

    final progress = (currentCount / badge.targetCount).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? badge.tierColor.withValues(alpha: isDark ? 0.7 : 0.5)
              : borderColor,
          width: isUnlocked ? 1.5 : 1.0,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: badge.tierColor.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge Icon with Tier Ring
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? badge.tierColor.withValues(alpha: 0.15)
                  : textSecondary.withValues(alpha: 0.08),
              border: Border.all(
                color: isUnlocked ? badge.tierColor : textSecondary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: isUnlocked
                  ? Text(badge.iconEmoji, style: const TextStyle(fontSize: 22))
                  : Icon(Icons.lock_outline_rounded, color: textSecondary, size: 20),
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        badge.title,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badge.tierColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge.tierName,
                        style: TextStyle(
                          color: isUnlocked ? badge.tierColor : textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  badge.description,
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 8),

                // Progress Bar or Unlocked Tag
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: isUnlocked ? 1.0 : progress,
                          minHeight: 5,
                          backgroundColor: textSecondary.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isUnlocked ? AppColors.primaryEmerald : badge.tierColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isUnlocked
                          ? '+${badge.xpReward} XP'
                          : '$currentCount / ${badge.targetCount}',
                      style: TextStyle(
                        color: isUnlocked ? AppColors.primaryMint : textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Modals & Handlers ---

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kullanıcı Adını Değiştir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Yeni adınız...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                UserProfileService.instance.updateDisplayName(newName);
              }
              controller.dispose();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryEmerald, foregroundColor: Colors.white),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showAvatarPickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profil Fotoğrafı Seç',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPhotoSourceTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.camera, maxWidth: 400);
                      if (image != null) {
                        UserProfileService.instance.updateAvatar(customImagePath: image.path);
                      }
                    },
                  ),
                  _buildPhotoSourceTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400);
                      if (image != null) {
                        UserProfileService.instance.updateAvatar(customImagePath: image.path);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Veya Hazır Organik Avatar Seç:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: UserProfileService.presetAvatars.length,
                  itemBuilder: (_, index) {
                    final p = UserProfileService.presetAvatars[index];
                    return GestureDetector(
                      onTap: () {
                        UserProfileService.instance.updateAvatar(customImagePath: null, presetAvatarId: p.id);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmerald.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(p.emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoSourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryMint.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryEmerald, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- Integrated Google Account & Cloud Sync Controls ---

  Widget _buildConnectedGoogleSection(
    BuildContext context,
    UserProfile profile,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final isSyncing = GoogleAuthSyncService.instance.isSyncing;
    final String lastBackupText = profile.lastBackupTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(profile.lastBackupTimestamp!)
            .toLocal()
            .toString()
            .substring(0, 16)
        : 'Henüz eşitlenmedi';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryEmerald.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primaryMint, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.googleEmail ?? '',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Son Eşitleme: $lastBackupText',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: isSyncing ? null : () => _handleManualSync(context),
            icon: isSyncing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded, size: 14),
            label: Text(
              isSyncing ? '...' : 'Eşitle',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(60, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: isSyncing ? null : () => _confirmSignOut(context),
            icon: const Icon(Icons.logout_rounded, size: 17, color: AppColors.dangerRed),
            tooltip: 'Oturumu Kapat',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedGoogleSection(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final isSyncing = GoogleAuthSyncService.instance.isSyncing;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Row(
        children: [
          _buildGoogleLogoBadge(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google ile Bağlan',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rozetlerini ve seviyeni bulutta koru',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isSyncing ? null : () => _handleGoogleSignIn(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF3C4043),
              elevation: 1,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(75, 34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFDADCE0), width: 1),
              ),
            ),
            child: isSyncing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryEmerald),
                  )
                : const Text(
                    'Giriş Yap',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C4043),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleLogoBadge() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBackupAccordion(
    BuildContext context, {
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(Icons.folder_zip_outlined, size: 20, color: textSecondary),
          title: Text(
            'Çevrimdışı JSON Yedekleme',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
          ),
          subtitle: Text(
            'İnternetsiz ortamlar için manuel metin yedeği',
            style: TextStyle(fontSize: 11, color: textSecondary),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleOfflineShareBackup,
                    icon: const Icon(Icons.share_rounded, size: 14),
                    label: const Text('Yedeği Paylaş / İndir', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showOfflineRestoreDialog(context),
                    icon: const Icon(Icons.file_upload_outlined, size: 14),
                    label: const Text('Yedekten Yükle', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
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

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await GoogleAuthSyncService.instance.signIn();
    if (!mounted) return;

    if (result.isCancelled) return;

    if (!result.isSuccess) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(result.errorMessage ?? 'Giriş yapılamadı.'),
        ),
      );
      return;
    }

    if (result.cloudBackup != null && result.cloudBackup!.exists) {
      if (mounted) {
        _showCloudBackupFoundDialog(this.context, result.cloudBackup!);
      }
    } else {
      await GoogleAuthSyncService.instance.uploadToCloud();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Google hesabınız bağlandı ve verileriniz buluta yedeklendi!'),
          ),
        );
      }
    }
  }

  Future<void> _handleManualSync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await GoogleAuthSyncService.instance.uploadToCloud();
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: success ? AppColors.primaryEmerald : AppColors.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          success
              ? 'Tüm rozet ve profil verileri Google Drive ile eşitlendi.'
              : (GoogleAuthSyncService.instance.lastSyncMessage ?? 'Eşitleme sırasında bir hata oluştu.'),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Google Oturumundan Çıkılsın mı?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text(
          'Google hesabınızın bağlantısı kesilecek. Cihazınızdaki rozetler, puanlar ve verileriniz korunur.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await GoogleAuthSyncService.instance.signOut();
              messenger.showSnackBar(
                const SnackBar(content: Text('Google oturumu kapatıldı. Verileriniz yerel olarak korundu.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed, foregroundColor: Colors.white),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  void _showCloudBackupFoundDialog(BuildContext context, CloudBackupInfo backup) {
    final messenger = ScaffoldMessenger.of(context);
    final dateStr = backup.modifiedTime != null
        ? '${backup.modifiedTime!.day}.${backup.modifiedTime!.month}.${backup.modifiedTime!.year} ${backup.modifiedTime!.hour.toString().padLeft(2, '0')}:${backup.modifiedTime!.minute.toString().padLeft(2, '0')}'
        : 'Mevcut';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: AppColors.primaryMint),
            SizedBox(width: 10),
            Text('Bulut Yedeği Bulundu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Google Drive hesabınızda ($dateStr) tarihli bir OrganicScore yedeği tespit edildi.',
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cihazınızdaki profil ve rozetleri buluttaki bu yedekle geri yüklemek ister misiniz?',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await GoogleAuthSyncService.instance.uploadToCloud();
              messenger.showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.primaryEmerald,
                  content: Text('Cihazdaki güncel profil buluta kaydedildi.'),
                ),
              );
            },
            child: const Text('Cihaz Verisini Koru'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await GoogleAuthSyncService.instance.restoreFromCloud();
              messenger.showSnackBar(
                SnackBar(
                  backgroundColor: success ? AppColors.primaryEmerald : AppColors.dangerRed,
                  content: Text(
                    success
                        ? 'Profil ve rozetleriniz Google Drive\'dan başarıyla yüklendi!'
                        : 'Yedek geri yüklenirken bir hata oluştu.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Buluttan Geri Yükle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOfflineShareBackup() {
    final backupJson = UserProfileService.instance.exportBackupJson();
    Share.share(
      backupJson,
      subject: 'OrganicScore Profil & Rozet Yedeği (${DateTime.now().toString().substring(0, 10)})',
    );
  }

  void _showOfflineRestoreDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('JSON Yedeğinden Yükle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daha önce kopyaladığınız JSON yedek metnini buraya yapıştırın:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '{"app": "OrganicScore", ...}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              final jsonStr = controller.text.trim();
              if (jsonStr.isNotEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                final success = await UserProfileService.instance.importBackupJson(jsonStr);
                if (ctx.mounted) {
                  controller.dispose();
                  Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: success ? AppColors.primaryEmerald : AppColors.dangerRed,
                      content: Text(
                        success
                            ? 'Profil ve rozetleriniz başarıyla geri yüklendi!'
                            : 'Hata: Geçersiz yedekleme dosyası formatı.',
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
            ),
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
    );
  }

  Widget _buildChangelogTile(
    BuildContext context, {
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.new_releases_rounded, color: Color(0xFF4CAF50)),
        ),
        title: Text(
          'S�r�m Notlar� & Yenilikler',
          style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
        ),
        subtitle: Text(
          'v yeniliklerini ve ge�mi�i inceleyin',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => ChangelogService.showHistory(context),
      ),
    );
  }
}