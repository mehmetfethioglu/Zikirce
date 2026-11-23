import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../scoring/domain/organic_score_calculator.dart';
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
  State<ScanEncounterDecisionCard> createState() =>
      _ScanEncounterDecisionCardState();
}

class _ScanEncounterDecisionCardState extends State<ScanEncounterDecisionCard> {
  late EncounterSpawnResult _encounter;
  late HalalEvaluationResult _halalEvaluation;
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
    _halalEvaluation =
        OrganicScoreCalculator.evaluateHalalAndCleanStatus(
      rawIngredients:
          '${widget.ingredientsText} ${widget.additiveNames.join(" ")}',
      matchedAdditives: const [],
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
    Color primaryAccent = AppColors.primaryEmerald;
    IconData statusIcon = Icons.verified_user_rounded;

    if (_halalEvaluation.status == HalalStatusLevel.haramRisk) {
      primaryAccent = AppColors.dangerRed;
      statusIcon = Icons.gpp_bad_rounded;
    } else if (_halalEvaluation.status == HalalStatusLevel.doubtful ||
        widget.productScore < 50) {
      primaryAccent = AppColors.cautionGold;
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Halal & Clean Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: primaryAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HELAL & TEMİZ İÇERİK DENETİMİ',
                      style: TextStyle(
                        color: primaryAccent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _halalEvaluation.badgeLabel,
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _halalEvaluation.summary,
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),

          if (_halalEvaluation.haramFindings.isNotEmpty ||
              _halalEvaluation.doubtfulFindings.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._halalEvaluation.haramFindings.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⛔ ', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Text(
                        '${f.title}: ${f.reason}',
                        style: const TextStyle(
                          color: AppColors.dangerRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ..._halalEvaluation.doubtfulFindings.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠️ ', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Text(
                        '${f.title}: ${f.reason}',
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
            ),
          ],

          if (_halalEvaluation.cleanHighlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _halalEvaluation.cleanHighlights.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '✓ $tag',
                    style: const TextStyle(
                      color: AppColors.primaryEmerald,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),
          Divider(height: 1, color: context.cardBorderColor),
          const SizedBox(height: 14),

          // Real Nutrition Log Decision
          if (_recordedDecision == null) ...[
            Text(
              'Bu ürünü beslenme günlüğünüze nasıl kaydetmek istersiniz?',
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
                  child: OutlinedButton.icon(
                    onPressed: () => _submitDecision(ScanDecisionType.rejected),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textPrimaryColor,
                      side: BorderSide(color: context.cardBorderColor),
                      padding: const EdgeInsets.symmetric(
                        vertical: 11,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.remove_shopping_cart_outlined,
                      size: 17,
                      color: AppColors.primaryEmerald,
                    ),
                    label: const Text(
                      'Rafa Bıraktım',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _submitDecision(ScanDecisionType.consumed),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 11,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Tükettim (Kaydet)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
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
                color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryEmerald,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _recordedDecision!.decision == ScanDecisionType.consumed
                          ? 'Beslenme günlüğünüze "Tüketildi" olarak kaydedildi.'
                          : 'Beslenme günlüğünüze "Rafa Bırakıldı / Kaçınıldı" olarak kaydedildi.',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onOpenArenaRequested != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenArenaRequested,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryEmerald,
                    side: BorderSide(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text(
                    'Helal & E-Kod Rehberinde Detaylı İncele',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
