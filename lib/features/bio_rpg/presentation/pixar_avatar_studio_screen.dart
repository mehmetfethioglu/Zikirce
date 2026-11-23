import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../family_profiles/domain/family_profile_engine.dart';
import '../../family_profiles/presentation/family_profiles_screen.dart';
import '../../scoring/domain/organic_score_calculator.dart';
import '../domain/bio_rhythm_telemetry_service.dart';
import '../domain/bio_rpg_service.dart';

class PixarAvatarStudioScreen extends StatefulWidget {
  const PixarAvatarStudioScreen({super.key});

  @override
  State<PixarAvatarStudioScreen> createState() =>
      _PixarAvatarStudioScreenState();
}

class _PixarAvatarStudioScreenState extends State<PixarAvatarStudioScreen> {
  FamilyProfile? _activeProfile;
  bool _isLoadingProfile = true;

  static const List<(String code, String title, String subtitle, IconData icon)>
      _dietaryRules = [
    (
      'HALAL',
      'Helal Beslenme Hassasiyeti',
      'Domuz türevi, etil alkol, E120 karmin ve şüpheli jelatin/emülgatör (E441/E471) denetimi',
      Icons.verified_user_rounded,
    ),
    (
      'SYNTHETIC_COLORS',
      'Sıfır Sentetik Boya & Koruyucu',
      'E102, E110, E129 azo boyalar, E250 nitrit ve E621 MSG (Çin tuzu) kısıtlaması',
      Icons.science_outlined,
    ),
    (
      'PALM_OIL',
      'Palmiye (Palm) Yağsız',
      'İçindekilerde palm / palmiye yağı bulunan ürünleri işaretle',
      Icons.eco_outlined,
    ),
    (
      'HIGH_SUGAR',
      'Düşük Şeker & Şurup Koruması',
      'Yüksek şeker ve glikoz/fruktoz mısır şurubu (NBŞ) içeren ürünlerde uyar',
      Icons.monitor_heart_outlined,
    ),
    (
      'GLUTEN',
      'Glutensiz / Çölyak Koruması',
      'Buğday, arpa, çavdar ve gluten proteini içeren ürünlerde kritik uyarı ver',
      Icons.grain_rounded,
    ),
    (
      'LACTOSE',
      'Laktozsuz Beslenme',
      'Süt, süt tozu, peynir altı suyu ve laktoz bileşenlerini denetle',
      Icons.water_drop_outlined,
    ),
    (
      'HIGH_SODIUM',
      'Düşük Tuz / Tansiyon Koruması',
      'Yüksek sodyum (>0.4g/100g) içeren gıdalarda uyar',
      Icons.favorite_border_rounded,
    ),
    (
      'VEGAN',
      'Vegan / Bitkisel Beslenme',
      'Et, süt, yumurta, bal ve hayvansal jelatin içeren ürünleri filtrele',
      Icons.spa_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ensureAndLoadActiveProfile();
  }

  Future<void> _ensureAndLoadActiveProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      FamilyProfile? profile = await FamilyProfileEngine.getActiveProfile();
      if (profile == null) {
        final db = await DatabaseHelper().database;
        final rows = await db.query('family_profiles', limit: 1);
        if (rows.isNotEmpty) {
          final int firstId = rows.first['id'] as int;
          await db.update('family_profiles', {'is_active': 1}, where: 'id = ?', whereArgs: [firstId]);
        } else {
          await db.insert('family_profiles', {
            'profile_name': 'Helal & Temiz Beslenme',
            'is_active': 1,
            'restrictions_json': '["HALAL","SYNTHETIC_COLORS","PALM_OIL"]',
          });
        }
        profile = await FamilyProfileEngine.getActiveProfile();
      }
      if (mounted) {
        setState(() {
          _activeProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _toggleRule(String ruleCode) async {
    final profile = _activeProfile;
    if (profile == null) return;

    final List<String> updatedRules = List<String>.from(profile.restrictions);
    if (updatedRules.contains(ruleCode)) {
      updatedRules.remove(ruleCode);
    } else {
      updatedRules.add(ruleCode);
    }

    final PersonalSensitivityConfig updatedSensitivity =
        profile.sensitivity.copyWith(
      avoidPalmOil: updatedRules.contains('PALM_OIL'),
      sugarStrictness:
          updatedRules.contains('HIGH_SUGAR') ? 'strict' : 'normal',
      additiveStrictness:
          updatedRules.contains('SYNTHETIC_COLORS') ? 'strict' : 'normal',
      sodiumStrictness:
          updatedRules.contains('HIGH_SODIUM') ? 'strict' : 'normal',
    );

    await FamilyProfileEngine.updateProfile(
      profileId: profile.id,
      profileName: profile.profileName,
      restrictions: updatedRules,
      sensitivity: updatedSensitivity,
    );
    await _ensureAndLoadActiveProfile();
  }

  Future<void> _toggleAvoidNova4(bool value) async {
    final profile = _activeProfile;
    if (profile == null) return;

    final updatedSensitivity = profile.sensitivity.copyWith(avoidNova4: value);
    await FamilyProfileEngine.updateProfile(
      profileId: profile.id,
      profileName: profile.profileName,
      restrictions: profile.restrictions,
      sensitivity: updatedSensitivity,
    );
    await _ensureAndLoadActiveProfile();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    return ValueListenableBuilder<PersonalOrganicScoreState>(
      valueListenable: BioRpgService.instance,
      builder: (context, state, _) {
        final double heightM = (state.heightCm / 100.0).clamp(1.0, 2.3);
        final double bmi = state.bmi;
        final double idealMinKg = 18.5 * heightM * heightM;
        final double idealMaxKg = 24.9 * heightM * heightM;
        final int bmr = BioRhythmTelemetryService.calculateEstimatedBmr(
          heightCm: state.heightCm,
          weightKg: state.weightKg,
        );
        final double dailyWaterLiters = (state.weightKg * 0.033);
        final int maxDailyFreeSugarGrams = ((bmr * 0.05) / 4.0).round();

        Color bmiColor = AppColors.primaryEmerald;
        if (bmi < 18.5 || (bmi >= 25.0 && bmi < 30.0)) {
          bmiColor = AppColors.cautionGold;
        } else if (bmi >= 30.0) {
          bmiColor = AppColors.dangerRed;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BioMinimalUi.sectionHeader(
                context,
                overline: 'KİŞİSEL SAĞLIK & HELAL FİLTRELERİ',
                title: 'Sağlık Profilim',
                trailing: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FamilyProfilesScreen(),
                      ),
                    );
                    _ensureAndLoadActiveProfile();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.subtleSurfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.cardBorderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.family_restroom_rounded,
                          size: 14,
                          color: AppColors.primaryEmerald,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Aile Profilleri',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // =========================================================================
              // 1. REAL HALAL, ALLERGEN & CLEAN LABEL FILTER SWITCHES
              // =========================================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BioMinimalUi.cardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryEmerald.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppColors.primaryEmerald,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kırmızı Çizgilerim & Hassasiyetlerim',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Seçtiğiniz kurallar barkod ve içindekiler analizinde otomatik olarak denetlenir.',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_isLoadingProfile)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryEmerald,
                          ),
                        ),
                      )
                    else ...[
                      ..._dietaryRules.map((rule) {
                        final String code = rule.$1;
                        final String title = rule.$2;
                        final String subtitle = rule.$3;
                        final IconData icon = rule.$4;
                        final bool isEnabled =
                            _activeProfile?.restrictions.contains(code) ?? false;

                        return Column(
                          children: [
                            Divider(height: 1, color: context.cardBorderColor),
                            SwitchListTile.adaptive(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 2,
                              ),
                              activeThumbColor: AppColors.primaryEmerald,
                              value: isEnabled,
                              onChanged: (_) => _toggleRule(code),
                              secondary: Icon(
                                icon,
                                color: isEnabled
                                    ? AppColors.primaryEmerald
                                    : textSecondary,
                                size: 21,
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                subtitle,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      Divider(height: 1, color: context.cardBorderColor),
                      SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        activeThumbColor: AppColors.primaryEmerald,
                        value: _activeProfile?.sensitivity.avoidNova4 ?? true,
                        onChanged: _toggleAvoidNova4,
                        secondary: Icon(
                          Icons.factory_outlined,
                          color: (_activeProfile?.sensitivity.avoidNova4 ?? true)
                              ? AppColors.primaryEmerald
                              : textSecondary,
                          size: 21,
                        ),
                        title: Text(
                          'Ultra-İşlenmiş Gıda (NOVA 4) Uyarısı',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Çoklu endüstriyel katkı içeren NOVA 4 ürünlerde kişisel uyum puanını düşür',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // =========================================================================
              // 2. SCIENTIFIC BODY METRICS & DAILY NUTRITIONAL CEILINGS (WHO & MIFFLIN)
              // =========================================================================
              Text(
                'Vücut Analizi & Günlük Beslenme Referansı',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Boy ve kilo değerlerinize göre Dünya Sağlık Örgütü (DSÖ) referans aralıkları ve günlük su/enerji ihtiyacınız gerçek formüllerle hesaplanır.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BioMinimalUi.cardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Height Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Boy Uzunluğu',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${state.heightCm.round()} cm',
                          style: const TextStyle(
                            color: AppColors.primaryEmerald,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: state.heightCm.clamp(120.0, 220.0),
                      min: 120.0,
                      max: 220.0,
                      divisions: 100,
                      activeColor: AppColors.primaryEmerald,
                      onChanged: (v) {
                        BioRpgService.instance.updateBodyMetrics(
                          heightCm: v,
                          weightKg: state.weightKg,
                        );
                      },
                    ),

                    // Weight Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vücut Ağırlığı',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${state.weightKg.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            color: AppColors.primaryEmerald,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: state.weightKg.clamp(35.0, 180.0),
                      min: 35.0,
                      max: 180.0,
                      divisions: 145,
                      activeColor: AppColors.primaryEmerald,
                      onChanged: (v) {
                        BioRpgService.instance.updateBodyMetrics(
                          heightCm: state.heightCm,
                          weightKg: v,
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Calculated Scientific Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            title: 'VKİ (BMI)',
                            value: bmi.toStringAsFixed(1),
                            subtitle: state.bmiCategory,
                            color: bmiColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            title: 'İdeal Kilo Aralığı',
                            value:
                                '${idealMinKg.round()}–${idealMaxKg.round()} kg',
                            subtitle: 'DSÖ 18.5–24.9 VKİ',
                            color: AppColors.primaryEmerald,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            title: 'Bazal Metabolizma',
                            value: '$bmr kcal',
                            subtitle: 'Mifflin-St Jeor / gün',
                            color: AppColors.primaryEmerald,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            title: 'Günlük Su İhtiyacı',
                            value: '${dailyWaterLiters.toStringAsFixed(1)} L',
                            subtitle: 'Kilo × 33 ml standardı',
                            color: AppColors.primaryMint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.subtleSurfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.cardBorderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.cautionGold,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'DSÖ Günlük Tavan: Paketli gıdalardan alınan ilave şeker günde $maxDailyFreeSugarGrams gramı (~${(maxDailyFreeSugarGrams / 4).round()} küp şeker), toplam tuz ise 5 gramı aşmamalıdır.',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
