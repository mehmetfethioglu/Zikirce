import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../family_profiles/presentation/family_profiles_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../domain/bio_rhythm_telemetry_service.dart';
import '../domain/bio_rpg_models.dart';
import '../domain/bio_rpg_service.dart';
import 'widgets/organic_pass_viral_card.dart';
import 'widgets/pixar_3d_renderer.dart';

class PixarAvatarStudioScreen extends StatefulWidget {
  const PixarAvatarStudioScreen({super.key});

  @override
  State<PixarAvatarStudioScreen> createState() =>
      _PixarAvatarStudioScreenState();
}

class _PixarAvatarStudioScreenState extends State<PixarAvatarStudioScreen> {
  // 0: 3D Walking Mode, 1: Heroic Stand Mode, 2: Close-up Animoji Bust
  int _stageCameraMode = 0;

  // 0: 3D Customizer, 1: Metabolic Log, 2: OrganicPass & Share
  int _activeBottomSection = 0;

  // 0: Skin & Mood, 1: Hair, 2: Eyes & Visor, 3: Bio-Suit, 4: Body (Height/Weight)
  int _selectedCustomizeCategory = 0;

  static const List<String> _hairStyleNames = [
    'Pixar Hero İbiği',
    'Neo Dalga Stil',
    'Cyber İkili Topuz',
  ];

  static const List<String> _armorNames = [
    'Zümrüt Biyo-Suit',
    'Siber Kalkan Zırhı',
    'Altın Paladin',
    'Kuantum Mor Zırh',
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PersonalOrganicScoreState>(
      valueListenable: BioRpgService.instance,
      builder: (context, state, _) {
        final config = state.avatarConfig;
        final Color scoreColor = state.personalOrganicScore >= 75
            ? AppColors.primaryEmerald
            : (state.personalOrganicScore >= 50
                ? AppColors.cautionGold
                : AppColors.dangerRed);
        final double stepRatio = state.dailyStepGoal > 0
            ? (state.dailySteps / state.dailyStepGoal).clamp(0.0, 1.0)
            : 0.0;
        final int bmr = BioRhythmTelemetryService.calculateEstimatedBmr(
          heightCm: state.heightCm,
          weightKg: state.weightKg,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Title + Quick Access Icons
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BİYOLOJİK PERFORMANS & 3D AVATAR',
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Canlı 3D Karakter & Sağlık Radarı',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '3D Hikaye Kartı Paylaş',
                    onPressed: () =>
                        OrganicPassAndViralSection.showBioRpgViralShareModal(
                      context,
                      state,
                    ),
                    icon: const Icon(
                      Icons.ios_share_rounded,
                      color: AppColors.primaryEmerald,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aile & Yasaklı Madde Profilleri',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FamilyProfilesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.family_restroom_rounded,
                      color: AppColors.primaryMint,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rozetler & Bulut Hesap',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.military_tech_rounded,
                      color: AppColors.cautionGold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // =========================================================================
              // "THE WALKING MAN" (HVFTkE5_SHA) SPLIT-STAGE 3D HERO SHOWCASE
              // =========================================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0B1120),
                      const Color(0xFF111827),
                      scoreColor.withValues(alpha: 0.24),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: scoreColor.withValues(alpha: 0.55),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scoreColor.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // LEFT COLUMN: EDITORIAL TELEMETRY METRICS STACK
                        Expanded(
                          flex: 11,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. HEALTH / ORGANIC SCORE HERO METRIC
                              _buildWalkingManMetricBlock(
                                label: 'SAĞLIK SKORU',
                                valueText: '${state.personalOrganicScore}',
                                unitText: '/ 100',
                                accentColor: scoreColor,
                                icon: Icons.shield_moon_rounded,
                                progress: state.personalOrganicScore / 100.0,
                                subtitle: state.hasActiveDetoxQuest
                                    ? '☠️ Detoks Görevi Aktif'
                                    : '✨ ${state.bmiCategory}',
                              ),
                              const SizedBox(height: 14),

                              // 2. DAILY STEPS HERO METRIC
                              _buildWalkingManMetricBlock(
                                label: 'ADIM SAYISI',
                                valueText: '${state.dailySteps}',
                                unitText: 'adım',
                                accentColor: AppColors.cautionGold,
                                icon: Icons.directions_walk_rounded,
                                progress: stepRatio,
                                subtitle:
                                    'Hedef: ${state.dailyStepGoal} (%${(stepRatio * 100).round()})',
                                trailingAction: InkWell(
                                  onTap: () =>
                                      BioRpgService.instance.addSteps(250),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.cautionGold
                                          .withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.cautionGold,
                                      ),
                                    ),
                                    child: const Text(
                                      '+250',
                                      style: TextStyle(
                                        color: AppColors.cautionGold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // 3. BURNED ENERGY & BIO-STAMINA METRIC
                              _buildWalkingManMetricBlock(
                                label: 'HARCANAN ENERJİ',
                                valueText: '${state.activeCaloriesBurned}',
                                unitText: 'kcal',
                                accentColor: const Color(0xFF06B6D4),
                                icon: Icons.local_fire_department_rounded,
                                progress:
                                    (state.bioEnergy / state.maxBioEnergy)
                                        .clamp(0.0, 1.0),
                                subtitle:
                                    '⚡ ${state.bioEnergy}/${state.maxBioEnergy} Şarj • BMR $bmr',
                              ),
                              const SizedBox(height: 12),

                              // 4. COMPACT BODY & WILLPOWER PILL
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.monitor_weight_outlined,
                                      color: Colors.white70,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${state.heightCm.round()}cm • ${state.weightKg.toStringAsFixed(0)}kg • 🔥${state.willpowerStreak}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 6),

                        // RIGHT COLUMN: 3D ANIMATED WALKING MAN / ANIMOJI STAGE
                        Expanded(
                          flex: 12,
                          child: Column(
                            children: [
                              SizedBox(
                                height: 285,
                                child: Center(
                                  child: _stageCameraMode == 2
                                      ? Pixar3DAvatarCanvas(
                                          config: config,
                                          personalOrganicScore:
                                              state.personalOrganicScore,
                                          bmi: state.bmi,
                                          size: 200,
                                        )
                                      : Pixar3DFullBodyWalkingStage(
                                          config: config,
                                          personalOrganicScore:
                                              state.personalOrganicScore,
                                          bmi: state.bmi,
                                          isWalking: _stageCameraMode == 0,
                                          width: 195,
                                          height: 280,
                                        ),
                                ),
                              ),
                              // 360° Touch Hint & Camera Mode Pills
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildCameraModeChip(
                                      index: 0,
                                      icon: Icons.directions_run_rounded,
                                      label: 'Yürüyüş',
                                    ),
                                    _buildCameraModeChip(
                                      index: 1,
                                      icon: Icons.accessibility_new_rounded,
                                      label: 'Duruş',
                                    ),
                                    _buildCameraModeChip(
                                      index: 2,
                                      icon: Icons.face_retouching_natural,
                                      label: 'Portre',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '🔄 3D Karakteri 360° döndürmek için parmağınla sürükle • Çift dokunarak merkeze hizala',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 10.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // =========================================================================
              // MODERN SEGMENTED CONTROL BAR
              // =========================================================================
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.cardBorderColor),
                ),
                child: Row(
                  children: [
                    _buildSectionTabButton(
                      context,
                      index: 0,
                      icon: Icons.auto_fix_high_rounded,
                      label: '3D Özelleştir',
                    ),
                    _buildSectionTabButton(
                      context,
                      index: 1,
                      icon: Icons.timeline_rounded,
                      label: 'Metabolik Günlük',
                    ),
                    _buildSectionTabButton(
                      context,
                      index: 2,
                      icon: Icons.workspace_premium_rounded,
                      label: 'OrganicPass',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // =========================================================================
              // SECTION 0: MODERN 3D WARDROBE & BODY CUSTOMIZER
              // =========================================================================
              if (_activeBottomSection == 0)
                _buildModern3DCustomizerCard(context, state, config)
              else if (_activeBottomSection == 1)
                _buildMetabolicTimelineCard(context, state)
              else
                OrganicPassAndViralSection(state: state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWalkingManMetricBlock({
    required String label,
    required String valueText,
    required String unitText,
    required Color accentColor,
    required IconData icon,
    required double progress,
    required String subtitle,
    Widget? trailingAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accentColor, size: 14),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
            ),
            ?trailingAction,
          ],
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              valueText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unitText,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraModeChip({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _stageCameraMode == index;
    return GestureDetector(
      onTap: () => setState(() => _stageCameraMode = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryEmerald : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTabButton(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _activeBottomSection == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeBottomSection = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryEmerald
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : context.textSecondaryColor,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : context.textSecondaryColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModern3DCustomizerCard(
    BuildContext context,
    PersonalOrganicScoreState state,
    PixarAvatarConfig config,
  ) {
    final List<(IconData, String)> categories = [
      (Icons.palette_rounded, 'Ten & İfade'),
      (Icons.content_cut_rounded, '3D Saç'),
      (Icons.visibility_rounded, 'Göz & Vizör'),
      (Icons.shield_rounded, 'Biyo-Zırh'),
      (Icons.straighten_rounded, 'Boy & Kilo'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal Category Dock
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(categories.length, (idx) {
                final bool active = _selectedCustomizeCategory == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCustomizeCategory = idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primaryEmerald.withValues(alpha: 0.18)
                            : context.glassSurfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: active
                              ? AppColors.primaryEmerald
                              : context.cardBorderColor,
                          width: active ? 1.6 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            categories[idx].$1,
                            size: 16,
                            color: active
                                ? AppColors.primaryEmerald
                                : context.textSecondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            categories[idx].$2,
                            style: TextStyle(
                              color: active
                                  ? context.textPrimaryColor
                                  : context.textSecondaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 18),

          // Category 0: Skin Tone Swatches & Facial Expression Mood
          if (_selectedCustomizeCategory == 0) ...[
            Text(
              '3D Subsurface Ten Tonu',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 10),
            _buildColorOrbRow(
              colors: PixarAvatarPalettes.skinTones,
              selectedIndex: config.skinToneIndex,
              onSelect: (idx) => BioRpgService.instance.updateAvatarConfig(
                config.copyWith(skinToneIndex: idx),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Karakter Duygu & Enerji Aurası',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStyleCard(
                  context,
                  title: '🦸 Kahraman',
                  subtitle: 'Kararlı & Dinamik',
                  isSelected: config.expressionMood == 'heroic',
                  accent: AppColors.primaryEmerald,
                  onTap: () => BioRpgService.instance.updateAvatarConfig(
                    config.copyWith(expressionMood: 'heroic'),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStyleCard(
                  context,
                  title: '⚡ Enerjik',
                  subtitle: 'Yüksek Biyo-Ritim',
                  isSelected: config.expressionMood == 'energized',
                  accent: AppColors.cautionGold,
                  onTap: () => BioRpgService.instance.updateAvatarConfig(
                    config.copyWith(expressionMood: 'energized'),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStyleCard(
                  context,
                  title: '☠️ Detoks Sisi',
                  subtitle: 'Yorgun Aura',
                  isSelected: config.expressionMood == 'detox_fog',
                  accent: AppColors.toxicPurple,
                  onTap: () => BioRpgService.instance.updateAvatarConfig(
                    config.copyWith(expressionMood: 'detox_fog'),
                  ),
                ),
              ],
            ),
          ]

          // Category 1: 3D Hair Style & Hair Color Swatches
          else if (_selectedCustomizeCategory == 1) ...[
            Text(
              '3D Pixar Saç Geometrisi',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(_hairStyleNames.length, (idx) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: idx < 2 ? 8 : 0),
                    child: _buildStyleCard(
                      context,
                      title: _hairStyleNames[idx],
                      subtitle: 'Model #${idx + 1}',
                      isSelected: config.hairStyleIndex == idx,
                      accent: AppColors.primaryEmerald,
                      onTap: () => BioRpgService.instance.updateAvatarConfig(
                        config.copyWith(hairStyleIndex: idx),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Text(
              'Saç Rengi Paleti',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 10),
            _buildColorOrbRow(
              colors: PixarAvatarPalettes.hairColors,
              selectedIndex: config.hairColorIndex,
              onSelect: (idx) => BioRpgService.instance.updateAvatarConfig(
                config.copyWith(hairColorIndex: idx),
              ),
            ),
          ]

          // Category 2: Eye Iris Color & Cyber Holo-Visor
          else if (_selectedCustomizeCategory == 2) ...[
            Text(
              '3D Göz İris Rengi',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 10),
            _buildColorOrbRow(
              colors: PixarAvatarPalettes.eyeColors,
              selectedIndex: config.eyeColorIndex,
              onSelect: (idx) => BioRpgService.instance.updateAvatarConfig(
                config.copyWith(eyeColorIndex: idx),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Biyo-Optik Vizör Aksesuarı',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStyleCard(
                    context,
                    title: '👁️ Doğal Gözler',
                    subtitle: 'Çift Yansımalı Pixar Göz',
                    isSelected: config.companionVisorIndex == 0,
                    accent: AppColors.primaryEmerald,
                    onTap: () => BioRpgService.instance.updateAvatarConfig(
                      config.copyWith(companionVisorIndex: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStyleCard(
                    context,
                    title: '🥽 Siber Holo-Vizör',
                    subtitle: 'Barkod & Katkı Radarı',
                    isSelected: config.companionVisorIndex == 1,
                    accent: const Color(0xFF06B6D4),
                    onTap: () => BioRpgService.instance.updateAvatarConfig(
                      config.copyWith(companionVisorIndex: 1),
                    ),
                  ),
                ),
              ],
            ),
          ]

          // Category 3: 3D Bio-Suit / Armor & Sneakers
          else if (_selectedCustomizeCategory == 3) ...[
            Text(
              '3D Biyo-Zırh & Yürüyüş Ekipmanı',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _armorNames.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.3,
              ),
              itemBuilder: (context, idx) {
                final Color suitColor = PixarAvatarPalettes.armorColors[idx];
                final bool selected = config.armorStyleIndex == idx;
                return GestureDetector(
                  onTap: () => BioRpgService.instance.updateAvatarConfig(
                    config.copyWith(armorStyleIndex: idx),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: suitColor.withValues(alpha: selected ? 0.22 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? suitColor : context.cardBorderColor,
                        width: selected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: suitColor,
                            shape: BoxShape.circle,
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 15,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _armorNames[idx],
                            style: TextStyle(
                              color: context.textPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ]

          // Category 4: Live Body Proportions (Height & Weight -> 3D Rig Morph)
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Canlı 3D Vücut Oranı & BMI Kalibrasyonu',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'BMI: ${state.bmi.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: AppColors.primaryEmerald,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Boy: ${state.heightCm.round()} cm',
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Slider(
              value: state.heightCm.clamp(120.0, 220.0),
              min: 120.0,
              max: 220.0,
              divisions: 100,
              activeColor: AppColors.primaryEmerald,
              onChanged: (val) => BioRpgService.instance.updateBodyMetrics(
                heightCm: val,
                weightKg: state.weightKg,
              ),
            ),
            Text(
              'Kilo: ${state.weightKg.toStringAsFixed(1)} kg',
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Slider(
              value: state.weightKg.clamp(35.0, 160.0),
              min: 35.0,
              max: 160.0,
              divisions: 250,
              activeColor: AppColors.cautionGold,
              onChanged: (val) => BioRpgService.instance.updateBodyMetrics(
                heightCm: state.heightCm,
                weightKg: val,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorOrbRow({
    required List<Color> colors,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    return Row(
      children: List.generate(colors.length, (idx) {
        final bool selected = (selectedIndex % colors.length) == idx;
        final Color c = colors[idx];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => onSelect(idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 44 : 38,
              height: selected ? 44 : 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  colors: [
                    Color.lerp(c, Colors.white, 0.35)!,
                    c,
                    Color.lerp(c, Colors.black, 0.3)!,
                  ],
                ),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryEmerald
                      : Colors.white24,
                  width: selected ? 3.0 : 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: c.withValues(alpha: 0.55),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStyleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.18)
                : context.glassSurfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accent : context.cardBorderColor,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetabolicTimelineCard(
    BuildContext context,
    PersonalOrganicScoreState state,
  ) {
    if (state.scanHistory.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.cardBorderColor),
        ),
        child: Text(
          'Henüz "Aldım / Rafa Bıraktım" geri bildirimi yapılmış ürün yok. Biyo-Radar sekmesinden barkod taratarak kişisel sağlık skorunu yükselt!',
          style: TextStyle(color: context.textSecondaryColor, fontSize: 12.5),
        ),
      );
    }

    return Column(
      children: state.scanHistory.take(10).map((rec) {
        final bool isPositive = rec.personalScoreDelta >= 0;
        final Color badgeColor =
            isPositive ? AppColors.primaryEmerald : AppColors.dangerRed;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: badgeColor.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
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
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 11.5,
                      ),
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
      }).toList(),
    );
  }
}
