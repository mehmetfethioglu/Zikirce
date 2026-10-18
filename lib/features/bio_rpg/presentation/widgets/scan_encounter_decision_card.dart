import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/bio_rpg_models.dart';
import '../../domain/bio_rpg_service.dart';

class ScanEncounterDecisionCard extends StatefulWidget {
  final String barcode;
  final String productName;
  final int productScore;
  final String ingredientsText;
  final List<String> violationTitles;
  final List<String> additiveNames;
  final VoidCallback? onOpenArenaRequested;

  const ScanEncounterDecisionCard({
    super.key,
    required this.barcode,
    required this.productName,
    required this.productScore,
    required this.ingredientsText,
    required this.violationTitles,
    required this.additiveNames,
    this.onOpenArenaRequested,
  });

  @override
  State<ScanEncounterDecisionCard> createState() => _ScanEncounterDecisionCardState();
}

class _ScanEncounterDecisionCardState extends State<ScanEncounterDecisionCard> {
  late EncounterSpawnResult _encounter;
  MetabolicScanRecord? _recordedDecision;

  @override
  void initState() {
    super.initState();
    _encounter = BioRpgService.instance.evaluateProductEncounter(
      barcode: widget.barcode,
      productName: widget.productName,
      productScore: widget.productScore,
      ingredientsText: widget.ingredientsText,
      violationTitles: widget.violationTitles,
      additiveNames: widget.additiveNames,
    );
  }

  Future<void> _submitDecision(ScanDecisionType decision) async {
    final record = await BioRpgService.instance.recordProductDecision(
      barcode: widget.barcode,
      productName: widget.productName,
      productScore: widget.productScore,
      decision: decision,
      encounter: _encounter,
    );
    if (!mounted) return;
    setState(() {
      _recordedDecision = record;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isBoss = _encounter.isBossEncounter;
    final Color primaryAccent = isBoss ? AppColors.toxicPurple : AppColors.primaryEmerald;
    final Color secondaryAccent = isBoss ? AppColors.dangerRed : AppColors.primaryMint;

    return ValueListenableBuilder<PersonalOrganicScoreState>(
      valueListenable: BioRpgService.instance,
      builder: (context, rpgState, _) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryAccent.withValues(alpha: 0.22),
                secondaryAccent.withValues(alpha: 0.12),
                context.surfaceColor,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryAccent.withValues(alpha: 0.65), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: primaryAccent.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // RPG Encounter Header Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [primaryAccent, secondaryAccent]),
                    ),
                    child: Icon(
                      isBoss ? Icons.pest_control_rodent_rounded : Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBoss ? '⚔️ BIO-ARENA TEHDİT TESPİTİ' : '🌱 BİYO-MUHAFIZ SİNERJİSİ',
                          style: TextStyle(
                            color: primaryAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _encounter.headline,
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Kişisel Skor',
                          style: TextStyle(color: AppColors.primaryMint, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${rpgState.personalOrganicScore}/100',
                          style: const TextStyle(
                            color: AppColors.primaryEmerald,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _encounter.subtitle,
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              if (_recordedDecision == null) ...[
                Text(
                  'Bu ürünü satın aldın mı yoksa rafa mı bıraktın? (Kişisel OrganicScore\'unu etkiler)',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _submitDecision(ScanDecisionType.rejected),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBoss ? AppColors.primaryEmerald : AppColors.amoledCardBorder,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.shield_rounded, size: 18),
                        label: Text(
                          isBoss ? '🛡️ Almadım (+6 Skor & 2x Krit)' : 'Rafa Bıraktım',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _submitDecision(ScanDecisionType.consumed),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBoss ? AppColors.dangerRed : AppColors.primaryEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                        label: Text(
                          isBoss ? '🍔 Aldım (-8 Skor & Detoks)' : '🛒 Aldım (+7 Skor & Buff)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_recordedDecision!.personalScoreDelta >= 0
                            ? AppColors.primaryEmerald
                            : AppColors.dangerRed)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (_recordedDecision!.personalScoreDelta >= 0
                              ? AppColors.primaryEmerald
                              : AppColors.dangerRed)
                          .withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _recordedDecision!.personalScoreDelta >= 0
                            ? Icons.verified_rounded
                            : Icons.directions_walk_rounded,
                        color: _recordedDecision!.personalScoreDelta >= 0
                            ? AppColors.primaryEmerald
                            : AppColors.cautionGold,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _recordedDecision!.personalScoreDelta >= 0
                              ? '⚡ Karar Kaydedildi! Kişisel OrganicScore +${_recordedDecision!.personalScoreDelta} yükseldi. ${isBoss ? "Boss'un canı İrade Kalkanı ile yarıya indirildi!" : "Muhafızın güçlendi!"}'
                              : '⚠️ Toksik yük kaydedildi (${_recordedDecision!.personalScoreDelta} Skor). Vücudunu temizlemek için 3.000 Adım Detoks Görevi başlatıldı!',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onOpenArenaRequested != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onOpenArenaRequested,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.toxicPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.sports_mma_rounded, size: 20),
                      label: Text(
                        isBoss
                            ? '⚔️ ${_encounter.spawnedBoss?.name ?? "Toksik Boss"} İle 3D Düelloya Gir!'
                            : '🧬 3D Muhafız Arenasına Git',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
