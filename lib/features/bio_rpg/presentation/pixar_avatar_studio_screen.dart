import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../family_profiles/presentation/family_profiles_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../domain/bio_rpg_models.dart';
import '../domain/bio_rpg_service.dart';
import 'widgets/organic_pass_viral_card.dart';
import 'widgets/pixar_3d_renderer.dart';

class PixarAvatarStudioScreen extends StatelessWidget {
  const PixarAvatarStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PersonalOrganicScoreState>(
      valueListenable: BioRpgService.instance,
      builder: (context, state, _) {
        final config = state.avatarConfig;
        final Color scoreColor = state.personalOrganicScore >= 75
            ? AppColors.primaryEmerald
            : (state.personalOrganicScore >= 50 ? AppColors.cautionGold : AppColors.dangerRed);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header + Quick Profile & Family Restrictions Access
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🧬 3D PIXAR KARAKTERİM & BİYOLOJİK SKOR',
                          style: TextStyle(
                            color: AppColors.primaryEmerald,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Animoji Stüdyosu & Metabolik Kalkan',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aile & Yasaklı Madde Profilleri',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FamilyProfilesScreen()),
                      );
                    },
                    icon: const Icon(Icons.family_restroom_rounded, color: AppColors.primaryMint),
                  ),
                  IconButton(
                    tooltip: 'Rozetler & Bulut Hesap',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                    icon: const Icon(Icons.military_tech_rounded, color: AppColors.cautionGold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3D ANIMOJI TURNTABLE STAGE + LIVING PERSONAL ORGANICSCORE
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0F172A),
                      scoreColor.withValues(alpha: 0.25),
                      const Color(0xFF1E293B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.6), width: 1.6),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // 3D Pixar Avatar Canvas (Interactive 3D Tilt)
                        Pixar3DAvatarCanvas(
                          config: config,
                          personalOrganicScore: state.personalOrganicScore,
                          bmi: state.bmi,
                          size: 155,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: scoreColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: scoreColor),
                                ),
                                child: Text(
                                  'KİŞİSEL ORGANICSCORE: ${state.personalOrganicScore}/100',
                                  style: TextStyle(
                                    color: scoreColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                state.bmiCategory,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Boy: ${state.heightCm.round()} cm • Kilo: ${state.weightKg.toStringAsFixed(1)} kg (BMI: ${state.bmi.toStringAsFixed(1)})',
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '🔥 İrade Serisi: ${state.willpowerStreak} Reddedilen Zararlı Ürün',
                                style: const TextStyle(
                                  color: AppColors.cautionGold,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '💡 Karakterini 3D döndürmek için parmağınla sürükle • Boy/Kilo ve OrganicScore değerine göre zırh aurası evrimleşir!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              OrganicPassAndViralSection(state: state),
              const SizedBox(height: 18),

              // 3D ANIMOJI CUSTOMIZATION STUDIO
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.cardBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎨 3D Pixar Animoji Özelleştirme Stüdyosu',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOptionSelectorRow(
                      context,
                      label: 'Ten Tonu',
                      currentIndex: config.skinToneIndex,
                      count: 5,
                      onChanged: (idx) => BioRpgService.instance.updateAvatarConfig(
                        config.copyWith(skinToneIndex: idx),
                      ),
                    ),
                    _buildOptionSelectorRow(
                      context,
                      label: '3D Saç Stili',
                      currentIndex: config.hairStyleIndex,
                      count: 3,
                      onChanged: (idx) => BioRpgService.instance.updateAvatarConfig(
                        config.copyWith(hairStyleIndex: idx),
                      ),
                    ),
                    _buildOptionSelectorRow(
                      context,
                      label: 'Saç Rengi',
                      currentIndex: config.hairColorIndex,
                      count: 5,
                      onChanged: (idx) => BioRpgService.instance.updateAvatarConfig(
                        config.copyWith(hairColorIndex: idx),
                      ),
                    ),
                    _buildOptionSelectorRow(
                      context,
                      label: 'Göz Rengi',
                      currentIndex: config.eyeColorIndex,
                      count: 4,
                      onChanged: (idx) => BioRpgService.instance.updateAvatarConfig(
                        config.copyWith(eyeColorIndex: idx),
                      ),
                    ),
                    _buildOptionSelectorRow(
                      context,
                      label: 'Biyo-Zırh',
                      currentIndex: config.armorStyleIndex,
                      count: 4,
                      onChanged: (idx) => BioRpgService.instance.updateAvatarConfig(
                        config.copyWith(armorStyleIndex: idx),
                      ),
                    ),
                    _buildOptionSelectorRow(
                      context,
                      label: 'Holo-Vizör',
                      currentIndex: config.companionVisorIndex,
                      count: 2,
                      onChanged: (idx) => BioRpgService.instance.updateAvatarConfig(
                        config.copyWith(companionVisorIndex: idx),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // CONSUMED vs REJECTED METABOLIC LOG
              Text(
                '📊 Tüketilen & Reddedilen Gıdalar (Metabolik Karar Günlüğü)',
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Barkodu taranan ürünlerde verdiğin "Aldım / Almadım" kararlarının Kişisel OrganicScore üzerindeki etkisi:',
                style: TextStyle(color: context.textSecondaryColor, fontSize: 12),
              ),
              const SizedBox(height: 12),

              if (state.scanHistory.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.cardBorderColor),
                  ),
                  child: Text(
                    'Henüz "Aldım / Almadım" geri bildirimi yapılmış ürün yok. Biyo-Radar sekmesinden bir ürün taratıp kararını kaydet!',
                    style: TextStyle(color: context.textSecondaryColor, fontSize: 12.5),
                  ),
                )
              else
                ...state.scanHistory.take(8).map((rec) {
                  final bool isPositive = rec.personalScoreDelta >= 0;
                  final Color badgeColor = isPositive ? AppColors.primaryEmerald : AppColors.dangerRed;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            rec.decision == ScanDecisionType.rejected
                                ? Icons.shield_rounded
                                : Icons.shopping_bag_rounded,
                            color: badgeColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.productName,
                                style: TextStyle(
                                  color: context.textPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${rec.decision == ScanDecisionType.rejected ? "🛡️ Rafa Bırakıldı" : "🛒 Tüketildi"} • ${rec.spawnedEntityName}',
                                style: TextStyle(color: context.textSecondaryColor, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${isPositive ? "+" : ""}${rec.personalScoreDelta} Skor',
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionSelectorRow(
    BuildContext context, {
    required String label,
    required int currentIndex,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: List.generate(count, (idx) {
                final bool selected = currentIndex == idx;
                return ChoiceChip(
                  label: Text('#${idx + 1}'),
                  selected: selected,
                  selectedColor: AppColors.primaryEmerald,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : context.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                  onSelected: (_) => onChanged(idx),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
