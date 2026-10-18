import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/bio_rhythm_telemetry_service.dart';
import '../domain/bio_rpg_service.dart';

class BioRhythmScreen extends StatefulWidget {
  const BioRhythmScreen({super.key});

  @override
  State<BioRhythmScreen> createState() => _BioRhythmScreenState();
}

class _BioRhythmScreenState extends State<BioRhythmScreen> {
  bool _isSyncingWatch = false;

  Future<void> _syncWearable(WearableDeviceProfile device) async {
    setState(() => _isSyncingWatch = true);
    final int addedSteps = await BioRhythmTelemetryService.instance.syncWearableTelemetry(device);
    if (!mounted) return;
    setState(() => _isSyncingWatch = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${device.iconLabel} ${device.name} senkronize edildi! +$addedSteps Adım ve Biyo-Enerji aktarıldı.',
        ),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PersonalOrganicScoreState>(
      valueListenable: BioRpgService.instance,
      builder: (context, state, _) {
        final double stepProgress = state.dailyStepGoal > 0
            ? (state.dailySteps / state.dailyStepGoal).clamp(0.0, 1.0)
            : 0.0;
        final int stepsToNextEnergy = 1000 - (state.dailySteps % 1000);
        final int bmr = BioRhythmTelemetryService.calculateEstimatedBmr(
          heightCm: state.heightCm,
          weightKg: state.weightKg,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                '🏃‍♂️ BİYO-RİTİM, ADIMSAYAR & AKILLI SAAT KÖPRÜSÜ',
                style: TextStyle(
                  color: AppColors.cautionGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Adımlarını Biyo-Enerjiye Dönüştür',
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              // STEP REACTOR & STAMINA GENERATOR CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0F172A),
                      AppColors.cautionGold.withValues(alpha: 0.22),
                      AppColors.primaryEmerald.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cautionGold.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Circular Step Gauge
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 102,
                                height: 102,
                                child: CircularProgressIndicator(
                                  value: stepProgress,
                                  strokeWidth: 10,
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cautionGold),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.directions_walk_rounded, color: AppColors.cautionGold, size: 22),
                                  Text(
                                    '${state.dailySteps}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '/ ${state.dailyStepGoal} adım',
                                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryEmerald.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  state.smartwatchConnected
                                      ? '⌚ Bağlı: ${state.smartwatchName}'
                                      : '📱 Kaynak: ${state.smartwatchName}',
                                  style: const TextStyle(
                                    color: AppColors.primaryEmerald,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '🔥 Aktif Yakılan: ${state.activeCaloriesBurned} kcal',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '⚡ Sonraki +1 Biyo-Enerji ve +10 💎 için $stepsToNextEnergy adım kaldı!',
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => BioRpgService.instance.addSteps(500),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.cautionGold,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.add_road_rounded, size: 16),
                                      label: const Text(
                                        '+500 Adım',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => BioRpgService.instance.addSteps(1000),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryEmerald,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.bolt_rounded, size: 16),
                                      label: const Text(
                                        '+1.000 Adım',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ACTIVE DETOX QUEST BANNER (IF ANY)
              if (state.hasActiveDetoxQuest) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.dangerRed, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cleaning_services_rounded, color: AppColors.dangerRed, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '☠️ AKTİF METABOLİK DETOKS GÖREVİ',
                              style: TextStyle(
                                color: AppColors.dangerRed,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tükettiğin katkı maddeli ürünün toksik sisini temizlemek ve +5 Kişisel OrganicScore geri kazanmak için adım hedefini tamamla!',
                        style: TextStyle(color: context.textPrimaryColor, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: state.detoxProgress,
                          minHeight: 10,
                          backgroundColor: Colors.black26,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryEmerald),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'İlerleme: ${state.detoxCurrentSteps} / ${state.activeDetoxTargetSteps} Adım',
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // BODY METRICS (BOY / KİLO / BMI / BMR) CONFIGURATOR
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📏 Boy, Kilo & Metabolik Profil',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryEmerald.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'BMI: ${state.bmi.toStringAsFixed(1)} • BMR: $bmr kcal',
                            style: const TextStyle(
                              color: AppColors.primaryEmerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Boy: ${state.heightCm.round()} cm',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Slider(
                      value: state.heightCm.clamp(120.0, 220.0),
                      min: 120.0,
                      max: 220.0,
                      divisions: 100,
                      activeColor: AppColors.primaryEmerald,
                      label: '${state.heightCm.round()} cm',
                      onChanged: (val) {
                        BioRpgService.instance.updateBodyMetrics(
                          heightCm: val,
                          weightKg: state.weightKg,
                        );
                      },
                    ),
                    Text(
                      'Kilo: ${state.weightKg.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Slider(
                      value: state.weightKg.clamp(35.0, 160.0),
                      min: 35.0,
                      max: 160.0,
                      divisions: 250,
                      activeColor: AppColors.cautionGold,
                      label: '${state.weightKg.toStringAsFixed(1)} kg',
                      onChanged: (val) {
                        BioRpgService.instance.updateBodyMetrics(
                          heightCm: state.heightCm,
                          weightKg: val,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // SMARTWATCH & HEALTH CONNECT / HEALTHKIT BRIDGE
              Text(
                '⌚ Akıllı Saat & Sağlık Servisleri Senkronizasyonu',
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Akıllı saatinden veya Health Connect / Apple HealthKit üzerinden adım ve kalori verilerini çek:',
                style: TextStyle(color: context.textSecondaryColor, fontSize: 12),
              ),
              const SizedBox(height: 12),

              ...BioRhythmTelemetryService.supportedWearables.map((device) {
                final bool isCurrent = state.smartwatchName == device.name;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent ? AppColors.primaryEmerald : context.cardBorderColor,
                      width: isCurrent ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(device.iconLabel, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: TextStyle(
                                color: context.textPrimaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              device.protocol,
                              style: TextStyle(color: context.textSecondaryColor, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isSyncingWatch ? null : () => _syncWearable(device),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCurrent ? AppColors.primaryEmerald : AppColors.amoledCardBorder,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isCurrent ? 'Senkronize Et' : 'Bağla & Çek',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
}
