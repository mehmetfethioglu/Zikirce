import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../monetization/domain/subscription_service.dart';
import '../../domain/bio_rpg_service.dart';
import 'pixar_3d_renderer.dart';

class OrganicPassAndViralSection extends StatelessWidget {
  final PersonalOrganicScoreState state;

  const OrganicPassAndViralSection({
    super.key,
    required this.state,
  });

  static void showBioRpgViralShareModal(
    BuildContext context,
    PersonalOrganicScoreState state,
  ) {
    final Color scoreColor = state.personalOrganicScore >= 75
        ? AppColors.primaryEmerald
        : (state.personalOrganicScore >= 50 ? AppColors.cautionGold : AppColors.dangerRed);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cardBorderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '📲 3D Pixar Karakterim & OrganicScore Hikaye Kartı',
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              AspectRatio(
                aspectRatio: 9 / 14,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF1E1B4B),
                        Color(0xFF064E3B),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scoreColor, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: AppColors.primaryEmerald, size: 22),
                          SizedBox(width: 6),
                          Text(
                            'OrganicScore: Bio-Guardians',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Pixar3DAvatarCanvas(
                            config: state.avatarConfig,
                            personalOrganicScore: state.personalOrganicScore,
                            bmi: state.bmi,
                            size: 120,
                          ),
                          Pixar3DGuardianStage(
                            guardian: state.activeGuardian,
                            size: 110,
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'KİŞİSEL ORGANICSCORE: ${state.personalOrganicScore}/100',
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '🛡️ ${state.willpowerStreak} Zararlı Ürün Reddedildi • 🏃 ${state.dailySteps} Adım',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Aktif 3D Muhafız: ${state.activeGuardian.name} (Sv.${state.activeGuardian.level})',
                              style: const TextStyle(color: AppColors.primaryMint, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'Barkodu Tara • Katkı Boss\'larını Yen • Sağlığını Oyuna Dönüştür!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                      '🧬 Kişisel OrganicScore\'um: ${state.personalOrganicScore}/100!\n'
                      '🛡️ İrade Serim: ${state.willpowerStreak} zararlı ürünü rafa bıraktım!\n'
                      '⚔️ Aktif 3D Muhafızım: ${state.activeGuardian.name} (Sv.${state.activeGuardian.level})\n'
                      '🏃 Bugün ${state.dailySteps} adım attım! Sen de OrganicScore Bio-Guardians RPG\'ye katıl!',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text(
                    'Instagram / WhatsApp\'ta Paylaş',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int passLevel = state.seasonPassLevel;
    final double passProgress = ((state.seasonPassXp % 200) / 200.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. VIRAL 3D AVATAR SHARE BANNER
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => showBioRpgViralShareModal(context, state),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMint,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.share_rounded, size: 20),
            label: const Text(
              '📲 3D Pixar Karakterimi & OrganicScore Kartımı Paylaş',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 2. SEASONAL ORGANICPASS (BATTLE PASS & PRO RPG)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E1B4B),
                AppColors.toxicPurple.withValues(alpha: 0.35),
                AppColors.cautionGold.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.cautionGold.withValues(alpha: 0.65), width: 1.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: AppColors.cautionGold, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.hasOrganicPass
                              ? '👑 ORGANICPASS PRO AKTİF (SEZON 1)'
                              : '👑 ORGANICPASS: SEZON 1 BATTLE PASS',
                          style: const TextStyle(
                            color: AppColors.cautionGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                        Text(
                          'Sezon Kademesi: Sv.$passLevel (${state.seasonPassXp % 200}/200 XP)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cautionGold.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Kademe $passLevel',
                      style: const TextStyle(
                        color: AppColors.cautionGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: passProgress,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cautionGold),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '✨ Efsanevi 3D Muhafızlar (Omega-Draco & Avokado Bilgesi), 20 Maksimum Biyo-Enerji, +300 Biyo-Kristal ve Reklamsız Tam Deneyim!',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              if (!state.hasOrganicPass)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await BioRpgService.instance.activateOrganicPass();
                          await SubscriptionService.instance.addAdFreeHours(24 * 30);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('👑 OrganicPass aktifleşti! Tüm Efsanevi 3D Muhafızlar ve +300 💎 açıldı!'),
                              backgroundColor: AppColors.primaryEmerald,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cautionGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text(
                          'OrganicPass\'i Etkinleştir',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '✅ Tüm Efsanevi 3D Pixar Muhafızları ve 20 Biyo-Enerji Kalkanı Hesabında Aktif!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primaryEmerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
